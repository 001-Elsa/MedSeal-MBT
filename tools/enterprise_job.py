#!/usr/bin/env python3
"""Private durable job coordinator. DICOM work remains in the MoonBit binary."""
from pathlib import Path
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import secrets
import shutil
import sqlite3
import stat
import subprocess
import sys
import time
from private_store import StoreError, canonical, private_file, validate_directory, write_exclusive, sync_directory
from local_fs import atomic_private, digest, signature

REPO = Path(__file__).resolve().parents[1]
DEFAULT_BINARY = REPO / '_build/native/debug/build/cmd/enterprise/enterprise.exe'
DEFAULT_VERIFY = REPO / '_build/native/debug/build/cmd/main/main.exe'


def scan(root):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise StoreError('input-directory-required')
    records = []
    def visit(folder, depth):
        if depth > 16:
            raise StoreError('input-depth-budget')
        for path in sorted(folder.iterdir()):
            info = path.lstat()
            if len(records) >= 20000:
                raise StoreError('input-entry-budget')
            if stat.S_ISDIR(info.st_mode):
                records.append((path, signature(info), False, 'directory'))
                visit(path, depth + 1)
            elif stat.S_ISREG(info.st_mode) and info.st_nlink == 1:
                descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
                try:
                    if signature(os.fstat(descriptor)) != signature(info):
                        raise StoreError('input-changed-during-discovery')
                    prefix = os.read(descriptor, 132)
                    if signature(os.fstat(descriptor)) != signature(info):
                        raise StoreError('input-changed-during-discovery')
                finally:
                    os.close(descriptor)
                candidate = path.suffix.lower() == '.dcm' or prefix[128:132] == b'DICM'
                records.append((path, signature(info), candidate, 'part10-candidate' if candidate else 'non-part10'))
            else:
                raise StoreError('input-link-or-special-entry')
    visit(root, 0)
    if sum(item[2] for item in records) > 10000:
        raise StoreError('object-count-budget')
    return records


def seal(source, destination, checkpoint=lambda event: None):
    records = scan(source)
    candidates = [item for item in records if item[2]]
    if not candidates:
        raise StoreError('empty-candidate-set')
    total = sum(item[1][2] for item in candidates)
    if total > 32 * 1024 ** 3 or shutil.disk_usage(destination).free < total * 2 + 64 * 1024 ** 2:
        raise StoreError('private-space-budget')
    sealed = []
    for number, (path, before, _, _) in enumerate(candidates, 1):
        if before[2] > 256 * 1024 ** 2:
            raise StoreError('single-object-budget')
        target = destination / ('input-%05d.dcm' % number)
        source_fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        target_fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            if signature(os.fstat(source_fd)) != before:
                raise StoreError('input-changed-before-sealing')
            checksum = hashlib.sha256()
            while True:
                part = os.read(source_fd, 1024 * 1024)
                if not part:
                    break
                checksum.update(part)
                view = memoryview(part)
                while view:
                    count = os.write(target_fd, view)
                    if not count:
                        raise StoreError('short-sealing-write')
                    view = view[count:]
            if signature(os.fstat(source_fd)) != before or signature(path.lstat()) != before:
                raise StoreError('input-changed-during-sealing')
            os.fsync(target_fd)
            os.fchmod(target_fd, 0o400)
        finally:
            os.close(target_fd)
            os.close(source_fd)
        sealed.append({'file': target.name, 'sha256': checksum.hexdigest(), 'size': before[2]})
        checkpoint('sealed-object')
    if scan(source) != records:
        raise StoreError('input-set-changed-during-sealing')
    sync_directory(destination)
    return {'schema': 1, 'objects': sealed, 'discovered_files': sum(item[3] != 'directory' for item in records),
            'excluded_non_part10': sum(item[3] == 'non-part10' for item in records), 'bytes': total}


@contextlib.contextmanager
def locked_job(workspace, job_id):
    workspace = validate_directory(Path(workspace))
    if len(job_id) != 32 or any(c not in '0123456789abcdef' for c in job_id):
        raise StoreError('invalid-job-id')
    job = validate_directory(workspace / job_id)
    if private_file(job / 'owner', 64).decode() != job_id:
        raise StoreError('job-ownership-mismatch')
    descriptor = os.open(job / 'job.lock', os.O_RDWR | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_mode & 0o077:
            raise StoreError('unsafe-job-lock')
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield job
    finally:
        os.close(descriptor)


def journal(job):
    private_file(job / 'job.sqlite', 4 * 1024 * 1024)
    db = sqlite3.connect(job / 'job.sqlite', isolation_level=None)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA synchronous=FULL')
    return db


def state(db):
    return db.execute('SELECT state FROM current WHERE id=1').fetchone()[0]


def transition(db, target, code='ok'):
    db.execute('BEGIN IMMEDIATE')
    try:
        db.execute('INSERT INTO events(state,code,time_ns) VALUES (?,?,?)', (target, code, time.time_ns()))
        db.execute('UPDATE current SET state=? WHERE id=1', (target,))
        db.execute('COMMIT')
    except BaseException:
        db.execute('ROLLBACK')
        raise


def create_job(workspace, source, policy, store, source_domain, binary=DEFAULT_BINARY, verifier=DEFAULT_VERIFY, checkpoint=lambda event: None):
    workspace = validate_directory(Path(workspace))
    store = validate_directory(Path(store))
    job_id = secrets.token_hex(16)
    job = workspace / job_id
    job.mkdir(mode=0o700)
    write_exclusive(job / 'owner', job_id.encode())
    write_exclusive(job / 'job.lock', b'')
    write_exclusive(job / 'job.sqlite', b'')
    db = journal(job)
    try:
        db.executescript('CREATE TABLE current(id INTEGER PRIMARY KEY,state TEXT NOT NULL); CREATE TABLE events(sequence INTEGER PRIMARY KEY,state TEXT NOT NULL,code TEXT NOT NULL,time_ns INTEGER NOT NULL); INSERT INTO current VALUES(1,"CREATED");')
        transition(db, 'CREATED')
        (job / 'sealed').mkdir(mode=0o700)
        inventory = seal(source, job / 'sealed', checkpoint)
        policy_bytes = Path(policy).read_bytes()
        if len(policy_bytes) > 1024 * 1024:
            raise StoreError('policy-size-budget')
        write_exclusive(job / 'policy.json', policy_bytes)
        os.chmod(job / 'policy.json', 0o400)
        adapter = REPO / 'tools/private_store.py'
        plan = {'schema': 1, 'job_id': job_id, 'inventory': inventory, 'store': str(store), 'source_domain': source_domain,
                'policy_sha256': hashlib.sha256(policy_bytes).hexdigest(), 'binary': str(Path(binary).resolve()), 'binary_sha256': digest(binary),
                'verifier': str(Path(verifier).resolve()), 'verifier_sha256': digest(verifier), 'adapter': str(adapter), 'adapter_sha256': digest(adapter),
                'python': sys.executable, 'python_sha256': digest(Path(sys.executable).resolve()), 'stage_token': secrets.token_hex(32),
                'resources': {'workers': 1, 'max_objects': 10000, 'copy_chunk_bytes': 1024 * 1024, 'max_input_bytes': 32 * 1024 ** 3}}
        write_exclusive(job / 'plan.json', canonical(plan))
        transition(db, 'INGESTED')
        checkpoint('ingested')
        return job_id
    except Exception:
        transition(db, 'FAILED', 'ingest-failed')
        raise
    finally:
        db.close()


def load_plan(job):
    plan = json.loads(private_file(job / 'plan.json', 32 * 1024 * 1024))
    if plan.get('schema') != 1 or plan.get('job_id') != job.name:
        raise StoreError('invalid-job-plan')
    for name in ('binary', 'verifier', 'adapter', 'python'):
        if digest(Path(plan[name]).resolve()) != plan[name + '_sha256']:
            raise StoreError('pinned-runtime-changed')
    if digest(job / 'policy.json') != plan['policy_sha256']:
        raise StoreError('pinned-policy-changed')
    if {p.name for p in (job / 'sealed').iterdir()} != {obj['file'] for obj in plan['inventory']['objects']}:
        raise StoreError('sealed-input-set-changed')
    for obj in plan['inventory']['objects']:
        if digest(job / 'sealed' / obj['file']) != obj['sha256']:
            raise StoreError('sealed-input-hash-changed')
    return plan


def verify_converted(job, plan):
    checked = subprocess.run([plan['verifier'], 'verify', str(job / 'converted')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if checked.returncode:
        raise StoreError('converted-verification-failed')
    manifest = json.loads(private_file(job / 'converted/manifest.json', 32 * 1024 * 1024))
    if len(manifest['objects']) != len(plan['inventory']['objects']) or manifest.get('release_authorized') is not False:
        raise StoreError('converted-contract-mismatch')
    return digest(job / 'converted/manifest.json')


def run_job(workspace, job_id, checkpoint=lambda event: None):
    with locked_job(workspace, job_id) as job:
        db = journal(job)
        try:
            if state(db) in {'CANCELLED', 'PUBLISHED'}:
                raise StoreError('job-state-does-not-allow-execution')
            plan = load_plan(job)
            if (job / 'cancel-request').exists():
                transition(db, 'CANCELLED')
                return {'schema': 1, 'job_id': job_id, 'state': 'CANCELLED'}
            transition(db, 'PLANNED')
            checkpoint('planned')
            if not (job / 'converted').exists():
                stage = job / 'working'
                if not stage.exists():
                    stage.mkdir(mode=0o700)
                    checkpoints = job / 'working.checkpoints'
                    checkpoints.mkdir(mode=0o700)
                    write_exclusive(checkpoints / 'owner', plan['stage_token'].encode())
                transition(db, 'RUNNING')
                command = [plan['binary'], str(job / 'sealed'), str(job / 'converted'), str(job / 'policy.json'), plan['python'], plan['adapter'], plan['store'], plan['source_domain'], str(stage), plan['stage_token']]
                checkpoint('before-conversion')
                result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if result.returncode:
                    raise StoreError('conversion-failed-recoverable')
                checkpoint('after-conversion-before-journal')
            transition(db, 'VALIDATING')
            manifest_hash = verify_converted(job, plan)
            atomic_private(job / 'conversion.json', canonical({'schema': 1, 'manifest_sha256': manifest_hash}))
            checkpoint('validated-before-journal')
            target = 'CANCELLED' if (job / 'cancel-request').exists() else 'AWAITING_REVIEW'
            transition(db, target)
            return {'schema': 1, 'job_id': job_id, 'state': target, 'objects': len(plan['inventory']['objects']), 'release_authorized': False}
        except Exception:
            transition(db, 'FAILED', 'execution-failed')
            raise
        finally:
            db.close()


def status_job(workspace, job_id):
    with locked_job(workspace, job_id) as job:
        db = journal(job)
        try:
            return {'schema': 1, 'job_id': job_id, 'state': state(db), 'events': db.execute('SELECT count(*) FROM events').fetchone()[0], 'release_authorized': False}
        finally:
            db.close()


def cancel_job(workspace, job_id):
    # Separate request; an executing process checks it before and after conversion.
    root = validate_directory(Path(workspace))
    if len(job_id) != 32 or any(c not in '0123456789abcdef' for c in job_id):
        raise StoreError('invalid-job-id')
    job = validate_directory(root / job_id)
    if private_file(job / 'owner', 64).decode() != job_id:
        raise StoreError('job-ownership-mismatch')
    atomic_private(job / 'cancel-request', b'cancel')
    return {'schema': 1, 'job_id': job_id, 'status': 'cancellation-requested'}


def cleanup_job(workspace, job_id):
    with locked_job(workspace, job_id) as job:
        db = journal(job)
        try:
            if state(db) not in {'CANCELLED', 'FAILED'}:
                raise StoreError('cleanup-state-rejected')
            for name in ('working', 'working.checkpoints', 'sealed'):
                folder = job / name
                if folder.exists():
                    validate_directory(folder)
                    shutil.rmtree(folder)
            transition(db, 'CANCELLED', 'owned-private-inputs-cleaned')
            return {'schema': 1, 'job_id': job_id, 'status': 'cleaned', 'physical_erasure': False}
        finally:
            db.close()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['create', 'run', 'resume', 'status', 'cancel', 'cleanup', 'review', 'risks'])
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--job')
    parser.add_argument('--record', type=Path)
    parser.add_argument('--reviewers', type=Path)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--policy', type=Path)
    parser.add_argument('--store', type=Path)
    parser.add_argument('--source-domain')
    parser.add_argument('--binary', type=Path, default=DEFAULT_BINARY)
    parser.add_argument('--verifier', type=Path, default=DEFAULT_VERIFY)
    args = parser.parse_args()
    try:
        if args.operation == 'create':
            result = {'schema': 1, 'job_id': create_job(args.workspace, args.input, args.policy, args.store, args.source_domain, args.binary, args.verifier), 'state': 'INGESTED'}
        elif args.operation in {'run', 'resume'}:
            result = run_job(args.workspace, args.job)
        elif args.operation == 'review':
            from risk_gate import review_job
            result = review_job(args.workspace, args.job, args.record, args.reviewers)
        elif args.operation == 'risks':
            from risk_gate import risk_inventory
            with locked_job(args.workspace, args.job) as job:
                result = {'schema': 1, 'job_id': args.job, 'release_authorized': False, 'objects': risk_inventory(job)[1]}
        else:
            result = {'status': status_job, 'cancel': cancel_job, 'cleanup': cleanup_job}[args.operation](args.workspace, args.job)
        print(json.dumps(result))
        return 0
    except StoreError as error:
        print(json.dumps({'schema': 1, 'status': 'failed', 'code': str(error)}), file=sys.stderr)
        return 5
    except Exception:
        print('{"schema":1,"status":"failed","code":"private-job-operation-failed"}', file=sys.stderr)
        return 5


if __name__ == '__main__':
    raise SystemExit(main())
