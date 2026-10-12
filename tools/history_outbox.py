"""Authenticated local receiver/outbox and verified historical witnesses.

DICOM semantics remain in MoonBit. Historical targets are taken only from a
reviewed, signed and acknowledged job, then their current byte/trust bindings
are checked again. A JSON boolean is never a release grant.
"""
from pathlib import Path
import contextlib
import fcntl
import hashlib
import json
import os
import re
import secrets
import shutil

from private_store import PrivateStore, StoreError, canonical, private_file, validate_directory, write_exclusive, sync_directory
from local_fs import digest, copy_file_new, rename_new
from verify_delivery import verify_package, read_file, parse_json
from ledger_cache import request_scope, validate_binding


def initialize_destination(root, receiver_id):
    root = validate_directory(Path(root))
    if not isinstance(receiver_id, str) or not re.fullmatch('[A-Za-z0-9_-]{1,64}', receiver_id):
        raise StoreError('invalid-receiver-id')
    marker = {'schema': 1, 'id': secrets.token_hex(32), 'receiver_id': receiver_id}
    write_exclusive(root / 'destination.json', canonical(marker))
    for name in ['objects', 'packages', 'receipts']:
        (root / name).mkdir(mode=0o700)
    write_exclusive(root / 'receiver.lock', b'')
    sync_directory(root)
    return marker


def destination(config):
    if not isinstance(config, dict) or set(config) != {'schema', 'root', 'id', 'receiver_id', 'trust', 'reviewers', 'allow_synthetic'} or config['schema'] != 1 or type(config['allow_synthetic']) is not bool:
        raise StoreError('invalid-destination-config')
    root = validate_directory(Path(config['root']))
    marker = parse_json(private_file(root / 'destination.json', 4096))
    if marker != {'schema': 1, 'id': config['id'], 'receiver_id': config['receiver_id']}:
        raise StoreError('destination-identity-changed')
    for name in ['objects', 'packages', 'receipts']:
        validate_directory(root / name)
    return root


def destination_binding(config):
    root = destination(config)
    return {'id': config['id'], 'root': str(root), 'receiver_id': config['receiver_id'], 'trust_sha256': digest(config['trust']), 'allow_synthetic': config['allow_synthetic']}


@contextlib.contextmanager
def receiver_lock(root):
    private_file(root / 'receiver.lock', 0)
    fd = os.open(root / 'receiver.lock', os.O_RDWR | os.O_NOFOLLOW)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def identities(job, plan, manifest):
    request = parse_json(private_file(job / 'working.checkpoints/identities.checkpoint.json', 32 * 1024 * 1024))
    request_scope(request, plan['source_domain'])
    if len(request['objects']) != len(manifest['objects']):
        raise StoreError('private-identity-count-mismatch')
    return request


def deliver_job(workspace, job_id, package, checkpoint=lambda event: None):
    from enterprise_job import locked_job, journal, state, transition
    from risk_gate import gate
    with locked_job(workspace, job_id) as job:
        config = parse_json(private_file(job / 'destination.json', 4096))
        root = destination(config)
        plan, manifest, _, review, review_hash = gate(job, config['reviewers'])
        if state_db(job) not in {'PUBLISHED', 'ACKNOWLEDGED'}:
            raise StoreError('job-not-published-for-delivery')
        checked = verify_package(package, config['trust'], config['allow_synthetic'])
        release = parse_json(read_file(Path(package) / 'release.json', 4 * 1024 * 1024, True))
        if release['review_sha256'] != review_hash or release['conversion_manifest_sha256'] != digest(job / 'converted/manifest.json'):
            raise StoreError('delivery-not-this-reviewed-job')
        if release.get('destination_binding') != destination_binding(config):
            raise StoreError('signed-destination-binding-mismatch')
        request = identities(job, plan, manifest)
        package_id = checked['release_sha256']
        scope = [config['id']]
        with receiver_lock(root):
            store = PrivateStore(plan['store'])
            try:
                for obj in request['objects']:
                    validate_binding(store, [request['namespace'], plan['source_domain']], obj)
                previous = store.ledger_get('outbox', scope, package_id)
                binding = {'schema': 1, 'job': str(job), 'package_id': package_id, 'destination': destination_binding(config), 'review_sha256': review_hash, 'objects': manifest['objects']}
                if previous is None:
                    reused = 0
                    for descriptor, output in zip(request['objects'], manifest['objects']):
                        known = store.ledger_get('receiver-object', scope, descriptor['mapped_uid'])
                        if known is not None:
                            if known['sha256'] != output['sha256']:
                                raise StoreError('delivered-uid-content-conflict')
                            if digest(root / 'objects' / (output['sha256'] + '.dcm')) != output['sha256']:
                                raise StoreError('acknowledged-object-missing-or-tampered')
                            reused += 1
                    previous = {'schema': 1, 'state': 'Pending', 'binding': binding, 'counts': {'authorized': len(manifest['objects']), 'newly_delivered': len(manifest['objects']) - reused, 'verified_already_delivered': reused}}
                    store.ledger_put('outbox', scope, package_id, previous)
                elif previous['binding'] != binding:
                    raise StoreError('immutable-outbox-conflict')
            finally:
                store.close()
            checkpoint('outbox-intent-durable')
            target = root / 'packages' / package_id
            # Acknowledged entries must never hide deletion by re-copying.
            if previous['state'] == 'Acknowledged' and not target.exists():
                raise StoreError('acknowledged-package-missing')
            for output in manifest['objects']:
                blob = root / 'objects' / (output['sha256'] + '.dcm')
                if blob.exists():
                    if digest(blob) != output['sha256']:
                        raise StoreError('receiver-object-tampered')
                elif previous['state'] == 'Acknowledged':
                    raise StoreError('acknowledged-object-missing')
                else:
                    partial = root / 'objects' / ('.pending-' + output['sha256'])
                    if partial.exists():
                        private_file(partial, 256 * 1024 * 1024)
                        partial.unlink()
                    copy_file_new(Path(package) / output['file'], partial, output['sha256'])
                    rename_new(partial, blob)
                checkpoint('receiver-object-durable')
            if not target.exists():
                stage = root / 'packages' / ('.pending-' + package_id)
                if not stage.exists():
                    stage.mkdir(mode=0o700)
                validate_directory(stage)
                entries = [e for e in release['files'] if not e['file'].endswith('.dcm')]
                entries += [{'file': n, 'sha256': digest(Path(package) / n)} for n in ['release.json', 'signature.json']]
                if {p.name for p in stage.iterdir()} - {e['file'] for e in entries}:
                    raise StoreError('unexpected-receiver-stage-file')
                for entry in entries:
                    path = stage / entry['file']
                    if path.exists():
                        if digest(path) != entry['sha256']:
                            raise StoreError('receiver-stage-tampered')
                    else:
                        copy_file_new(Path(package) / entry['file'], path, entry['sha256'])
                verify_package(stage, config['trust'], config['allow_synthetic'], object_root=root / 'objects')
                rename_new(stage, target)
            verified = verify_package(target, config['trust'], config['allow_synthetic'], object_root=root / 'objects')
            if verified['release_sha256'] != package_id:
                raise StoreError('receiver-package-binding-mismatch')
            # Re-evaluate current reviewer/trust authority before acknowledgement.
            if gate(job, config['reviewers'])[4] != review_hash:
                raise StoreError('delivery-review-changed')
            receipt = {'schema': 2, 'package_id': package_id, 'destination_id': config['id'], 'receiver_id': config['receiver_id'], 'key_id': verified['key_id'], 'counts': previous['counts'], 'status': 'complete', 'scope': 'local-directory-verified-bytes'}
            path = root / 'receipts' / (package_id + '.json')
            if path.exists():
                if parse_json(private_file(path, 16384)) != receipt:
                    raise StoreError('receiver-receipt-tampered')
            else:
                write_exclusive(path, canonical(receipt))
            checkpoint('receipt-durable-before-ledger')
            store = PrivateStore(plan['store'])
            try:
                store.db.execute('BEGIN IMMEDIATE')
                for descriptor, output in zip(request['objects'], manifest['objects']):
                    store.ledger_put('receiver-object', scope, descriptor['mapped_uid'], {'schema': 1, 'sha256': output['sha256']})
                    hscope = [request['namespace'], plan['source_domain'], config['id']]
                    record = {'schema': 1, 'state': 'Acknowledged', 'descriptor': descriptor, 'semantic_key': {k: request[k] for k in ['policy_sha256', 'rulebook_sha256', 'program_sha256']}, 'job': str(job), 'package_id': package_id, 'output': output, 'receipt_sha256': digest(path), 'destination': destination_binding(config), 'review_sha256': review_hash}
                    store.ledger_put('history', hscope, descriptor['source_uid'], record)
                store.ledger_put('outbox', scope, package_id, {**previous, 'state': 'Acknowledged', 'receipt_sha256': digest(path)})
                checkpoint('ack-before-commit')
                store.db.execute('COMMIT')
            except BaseException:
                store.db.execute('ROLLBACK')
                raise
            finally:
                store.close()
            checkpoint('ack-after-commit')
            db = journal(job)
            try:
                transition(db, 'ACKNOWLEDGED')
            finally:
                db.close()
            return receipt


def state_db(job):
    from enterprise_job import journal, state
    db = journal(job)
    try:
        return state(db)
    finally:
        db.close()


def resolve_history(store_path, request, source_domain):
    required = {'schema', 'namespace', 'policy_sha256', 'rulebook_sha256', 'program_sha256', 'destination', 'references'}
    if not isinstance(request, dict) or set(request) != required or request['schema'] != 1 or not isinstance(request['references'], list) or len(request['references']) > 10000:
        raise StoreError('invalid-history-request')
    config = request['destination']
    root = destination(config)
    scope = [request['namespace'], source_domain, config['id']]
    records = []
    store = PrivateStore(store_path)
    try:
        for ref in request['references']:
            if not isinstance(ref, dict) or set(ref) != {'source_uid', 'owner_key', 'sop_class'}:
                raise StoreError('invalid-history-reference')
            record = store.ledger_get('history', scope, ref['source_uid'])
            if record is None or record.get('state') != 'Acknowledged':
                raise StoreError('historical-reference-unresolved-complete-target-batch-first')
            obj = record['descriptor']
            if obj['owner_key'] != ref['owner_key'] or obj['sop_class'] != ref['sop_class']:
                raise StoreError('historical-reference-owner-or-sop-conflict')
            if record['semantic_key'] != {k: request[k] for k in ['policy_sha256', 'rulebook_sha256', 'program_sha256']}:
                raise StoreError('historical-reference-policy-or-program-stale')
            validate_binding(store, [request['namespace'], source_domain], obj)
            records.append(record)
    finally:
        store.close()
    result = []
    from risk_gate import validate_review, json_document
    from enterprise_job import load_plan, runtime_fingerprint
    for record in records:
        if record['destination'] != destination_binding(config):
            raise StoreError('historical-destination-or-trust-stale')
        job = Path(record['job'])
        plan = load_plan(job)
        review = json_document(private_file(job / 'review.json', 16 * 1024 * 1024))
        registry = private_file(Path(config['reviewers']), 1024 * 1024)
        if review['registry_sha256'] != hashlib.sha256(registry).hexdigest() or digest(job / 'review.json') != record['review_sha256']:
            raise StoreError('historical-review-authority-stale')
        validate_review(job, review['record'], json_document(registry), plan)
        target = root / 'packages' / record['package_id']
        checked = verify_package(target, config['trust'], config['allow_synthetic'], object_root=root / 'objects')
        release = parse_json(read_file(target / 'release.json', 4 * 1024 * 1024, True))
        if checked['release_sha256'] != record['package_id'] or release['producer_runtime_sha256'] != runtime_fingerprint(plan) or release['review_sha256'] != record['review_sha256']:
            raise StoreError('historical-package-review-binding-mismatch')
        receipt = root / 'receipts' / (record['package_id'] + '.json')
        if digest(receipt) != record['receipt_sha256']:
            raise StoreError('historical-receipt-missing-or-tampered')
        obj, output = record['descriptor'], record['output']
        result.append({'source_uid': obj['source_uid'], 'owner_key': obj['owner_key'], 'mapped_uid': obj['mapped_uid'], 'mapped_patient': obj['mapped_patient'], 'sop_class': obj['sop_class'], 'file': str(root / 'objects' / (output['sha256'] + '.dcm')), 'sha256': output['sha256']})
    return {'schema': 1, 'entries': result}

# Compact maintenance/QA helpers. The enterprise path uses deliver_job above.
def _legacy_request(request):
    required = {'schema','namespace','source_domain','destination_domain','objects'}
    if not isinstance(request, dict) or set(request) != required or request['schema'] != 1 or not request['objects']:
        raise StoreError('invalid-history-request')
    for obj in request['objects']:
        fields = {'source_uid','source_sha256','source_patient_key','owner_key','sop_class','mapped_uid','mapped_patient','bindings_sha256','output_file','output_sha256','audit_file','audit_sha256'}
        if not isinstance(obj, dict) or set(obj) != fields or obj['audit_file'] != obj['output_file'][:-4] + '.audit.json':
            raise StoreError('invalid-history-object')
    return [request['namespace'], request['source_domain'], request['destination_domain']]

def publish_history(store, request, output_root, receipt_sha256, state='Published'):
    scope = _legacy_request(request)
    if not re.fullmatch('[0-9a-f]{64}', receipt_sha256) or state not in {'Published','Acknowledged'}:
        raise StoreError('invalid-history-state')
    root = validate_directory(Path(output_root))
    for obj in request['objects']:
        if digest(root / obj['output_file']) != obj['output_sha256'] or digest(root / obj['audit_file']) != obj['audit_sha256']:
            raise StoreError('history-file-hash-mismatch')
        key = [2, obj['source_uid'], obj['source_sha256'], obj['mapped_uid'], obj['output_sha256']]
        record = {'schema': 1, 'state': state, 'descriptor': obj, 'destination_domain': scope[2], 'receipt_sha256': receipt_sha256}
        current = store.ledger_get('history', scope, key)
        if current is not None and not (current == record or (current.get('state') == 'Published' and state == 'Acknowledged' and current.get('descriptor') == obj)):
            raise StoreError('immutable-history-conflict')
        if current != record:
            store.ledger_put('history', scope, key, record)
    return {'schema': 1, 'status': 'history-recorded', 'state': state, 'objects': len(request['objects'])}

def lookup_history(store, request, output_root):
    scope = _legacy_request(request)
    root = validate_directory(Path(output_root))
    result = []
    for obj in request['objects']:
        key = [2, obj['source_uid'], obj['source_sha256'], obj['mapped_uid'], obj['output_sha256']]
        record = store.ledger_get('history', scope, key)
        if record is None:
            raise StoreError('historical-reference-unresolved')
        if record.get('state') != 'Acknowledged':
            raise StoreError('history-target-not-acknowledged')
        if digest(root / obj['output_file']) != obj['output_sha256'] or digest(root / obj['audit_file']) != obj['audit_sha256']:
            raise StoreError('history-file-hash-mismatch')
        result.append({'source_uid': obj['source_uid'], 'mapped_uid': obj['mapped_uid'], 'sop_class': obj['sop_class'], 'output_sha256': obj['output_sha256'], 'state': record['state']})
    return {'schema': 1, 'status': 'historical-reference-verified', 'objects': result}

def create_outbox(store, request, package_root):
    required = {'schema','package_id','destination_domain','authorized','objects'}
    if not isinstance(request, dict) or set(request) != required or request['schema'] != 1 or request['authorized'] is not True:
        raise StoreError('invalid-outbox-request')
    root = validate_directory(Path(package_root))
    for obj in request['objects']:
        if set(obj) != {'file','sha256','audit_file','audit_sha256'}:
            raise StoreError('invalid-outbox-object')
        if digest(root / obj['file']) != obj['sha256'] or digest(root / obj['audit_file']) != obj['audit_sha256']:
            raise StoreError('history-file-hash-mismatch')
    outbox_id = hashlib.sha256(canonical(request)).hexdigest()[:32]
    scope = ['outbox', request['destination_domain']]
    record = {'schema': 1, 'id': outbox_id, 'state': 'Pending', 'package_id': request['package_id'], 'destination_domain': request['destination_domain'], 'authorized': True, 'objects': request['objects']}
    current = store.ledger_get('outbox', scope, outbox_id)
    if current is not None and current != record:
        raise StoreError('immutable-outbox-conflict')
    if current is None:
        store.ledger_put('outbox', scope, outbox_id, record)
    return {'schema': 1, 'status': 'outbox-created' if current is None else 'already-pending', 'outbox_id': outbox_id}

def acknowledge_outbox(store, request, destination_root, receipt):
    if receipt != request:
        raise StoreError('outbox-receipt-binding-mismatch')
    scope = ['outbox', request['destination_domain']]
    record = store.ledger_get('outbox', scope, request['outbox_id'])
    if record is None or record['package_id'] != request['package_id']:
        raise StoreError('outbox-not-authorized')
    root = validate_directory(Path(destination_root))
    for obj in record['objects']:
        if digest(root / obj['file']) != obj['sha256'] or digest(root / obj['audit_file']) != obj['audit_sha256']:
            raise StoreError('history-file-hash-mismatch')
    receipt_hash = hashlib.sha256(canonical(receipt)).hexdigest()
    if record['state'] == 'Acknowledged':
        if record.get('receipt_sha256') != receipt_hash:
            raise StoreError('immutable-outbox-receipt-conflict')
        return {'schema': 1, 'status': 'already-acknowledged', 'outbox_id': request['outbox_id']}
    store.ledger_put('outbox', scope, request['outbox_id'], {**record, 'state': 'Acknowledged', 'receipt_sha256': receipt_hash})
    return {'schema': 1, 'status': 'acknowledged', 'outbox_id': request['outbox_id'], 'receipt_sha256': receipt_hash}

def status_outbox(store, outbox_id, destination_domain):
    record = store.ledger_get('outbox', ['outbox', destination_domain], outbox_id)
    if record is None:
        raise StoreError('outbox-not-found')
    return {'schema': 1, 'outbox_id': outbox_id, 'state': record['state'], 'package_id': record['package_id'], 'destination_domain': record['destination_domain'], 'objects': len(record['objects'])}
