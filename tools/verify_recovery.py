#!/usr/bin/env python3
"""Real SIGKILL and sealed-source recovery; synthetic inputs only."""
from pathlib import Path
import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
from verify_strict_profile import generate_strict
from verify_with_pydicom import REPO
from private_store import initialize, StoreError
from enterprise_job import create_job, run_job, load_plan, cancel_job, cleanup_job, status_job


def main():
    os.umask(0o077)
    checks = []
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='p3-') as temp:
        root = Path(temp)
        workspace = root / 'jobs'
        workspace.mkdir(mode=0o700)
        store = root / 'store'
        initialize(store)
        source = root / 'source'
        generate_strict(source, 32)
        job_id = create_job(workspace, source, REPO / 'examples/strict-policy.json', store, 'synthetic-lab')
        job = workspace / job_id
        plan = load_plan(job)
        # Start native execution, kill its process group at an actual object checkpoint.
        stage = job / 'working'
        stage.mkdir(mode=0o700)
        checkpoints = job / 'working.checkpoints'
        checkpoints.mkdir(mode=0o700)
        (checkpoints / 'owner').write_text(plan['stage_token'])
        command = [plan['binary'], str(job / 'sealed'), str(job / 'converted'), str(job / 'policy.json'), plan['python'], plan['adapter'], plan['store'], plan['source_domain'], str(stage), plan['stage_token']]
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, start_new_session=True)
        for line in process.stdout:
            if 'object-verified' in line:
                process.kill()
                break
        process.wait(timeout=10)
        assert process.returncode < 0 and not (job / 'converted').exists()
        assert list(checkpoints.glob('*.checkpoint.json'))
        # A corrupt owned partial object is recomputed, never blindly skipped.
        next_file = stage / 'object-32.dcm'
        next_file.write_bytes(b'PARTIAL')
        # Alter original input after sealing; only sealed bytes are consumed.
        next(source.glob('*.dcm')).write_bytes(b'CHANGED ORIGINAL')
        result = run_job(workspace, job_id)
        assert result['state'] == 'AWAITING_REVIEW' and not result['release_authorized']
        checks.append('SIGKILL-object-checkpoint-revalidates-and-rebuilds-partial')
        checks.append('sealed-input-independent-of-subsequent-original-change')
        original_manifest = hashlib.sha256((job / 'converted/manifest.json').read_bytes()).hexdigest()
        assert run_job(workspace, job_id)['state'] == 'AWAITING_REVIEW'
        assert hashlib.sha256((job / 'converted/manifest.json').read_bytes()).hexdigest() == original_manifest
        checks.append('completed-filesystem-state-reconciled-with-journal-idempotently')
        # Kill coordinator after rename, before its conversion journal checkpoint.
        source2 = root / 'source2'
        generate_strict(source2, 4)
        second = create_job(workspace, source2, REPO / 'examples/strict-policy.json', store, 'second-domain')
        code = 'import sys;sys.path.insert(0,"tools");from enterprise_job import run_job;run_job(sys.argv[1],sys.argv[2],lambda e: (print("CRASH-WINDOW",flush=True),sys.stdin.read(1)) if e=="after-conversion-before-journal" else None)'
        killed = subprocess.Popen([sys.executable, '-c', code, str(workspace), second], cwd=REPO, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        assert killed.stdout.readline().strip() == 'CRASH-WINDOW'
        killed.kill()
        killed.wait(timeout=10)
        assert killed.returncode < 0 and (workspace / second / 'converted').is_dir()
        assert run_job(workspace, second)['state'] == 'AWAITING_REVIEW'
        checks.append('SIGKILL-after-directory-rename-before-journal-recovers')
        os.chmod(job / 'policy.json', 0o600)
        (job / 'policy.json').write_bytes(b'{}')
        try:
            run_job(workspace, job_id)
            raise AssertionError('changed policy accepted')
        except StoreError:
            pass
        checks.append('pinned-policy-change-refuses-resume')
        cancel_job(workspace, second)
        assert run_job(workspace, second)['state'] == 'CANCELLED'
        cleanup_job(workspace, second)
        assert not (workspace / second / 'sealed').exists()
        assert (workspace / second / 'converted').exists()
        checks.append('cancel-blocks-release-and-owned-cleanup-keeps-result-evidence')
        assert status_job(workspace, second)['state'] == 'CANCELLED'
        third = create_job(workspace, source2, REPO / 'examples/strict-policy.json', store, 'third-domain')
        run_job(workspace, third)
        converted = workspace / third / 'converted'
        pixel_file = converted / 'object-1.dcm'
        damaged = bytearray(pixel_file.read_bytes()); damaged[-1] ^= 1; pixel_file.write_bytes(damaged)
        manifest = json.loads((converted / 'manifest.json').read_bytes())
        manifest['objects'][0]['sha256'] = hashlib.sha256(damaged).hexdigest()
        (converted / 'manifest.json').write_text(json.dumps(manifest, indent=2))
        (workspace / third / 'conversion.json').unlink()
        try:
            run_job(workspace, third)
            raise AssertionError('tampered pixels plus public manifest accepted as recovered conversion')
        except StoreError:
            pass
        checks.append('tampered-result-plus-public-manifest-refuses-private-checkpoint-reconciliation')
    record = {'schema': 1, 'fixture': 'synthetic only', 'checks': checks,
              'limitations': ['process termination, not physical power loss', 'single-owner local POSIX filesystem', 'bounded native-pixel streaming profile only', 'publication to external delivery area requires P5/P6 gate']}
    (REPO / 'docs/evidence/p3-recovery.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'status': 'passed', 'checks': len(checks)}))


if __name__ == '__main__':
    main()
