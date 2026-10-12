"""Authenticated private conversion cache. No DICOM semantics or release grant.

Only the pinned MoonBit producer supplies descriptors and validated outputs.
Each reuse checks the encrypted record, payload, audit, binding and runtime key.
"""
from pathlib import Path
import os
import re
import secrets
import stat
import hashlib
import importlib.metadata
import sys
import json
import shutil
from private_store import StoreError, validate_directory, sync_directory
from local_fs import digest, copy_file_new

DESCRIPTOR = {'source_uid', 'source_sha256', 'source_patient_key', 'owner_key', 'sop_class', 'mapped_uid', 'mapped_patient', 'bindings_sha256'}
CACHE_BYTES_BUDGET = 32 * 1024 ** 3


def provider_runtime():
    """Actual interpreter, adapter code and installed cryptographic dependencies."""
    folder = Path(__file__).resolve().parent
    files = [[name, digest(folder / name)] for name in ['private_store.py', 'ledger_cache.py', 'history_outbox.py', 'local_fs.py']]
    files.append(['python', digest(Path(sys.executable).resolve())])
    dependencies = []
    for name in ['cryptography', 'cffi', 'pycparser']:
        dist = importlib.metadata.distribution(name)
        code = sorted([str(item), digest(dist.locate_file(item))] for item in dist.files or []
                      if item.suffix in {'.py', '.so', '.pyd', '.dll', '.dylib'})
        dependencies.append([name, dist.version, code])
    return hashlib.sha256(json.dumps([files, dependencies], sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def sha(value):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value) is not None


def request_scope(request, domain):
    if not isinstance(request, dict) or set(request) != {'schema', 'namespace', 'policy_sha256', 'rulebook_sha256', 'program_sha256', 'objects'} or request['schema'] != 1:
        raise StoreError('invalid-cache-request')
    namespace = request['namespace']
    if not isinstance(namespace, str) or not 1 <= len(namespace) <= 128 or not isinstance(domain, str) or not 1 <= len(domain) <= 128:
        raise StoreError('invalid-cache-scope')
    if not all(sha(request[key]) for key in ('policy_sha256', 'rulebook_sha256', 'program_sha256')):
        raise StoreError('invalid-cache-version')
    if not isinstance(request['objects'], list) or not 1 <= len(request['objects']) <= 10000:
        raise StoreError('cache-object-budget')
    seen = set()
    for obj in request['objects']:
        if not isinstance(obj, dict) or set(obj) != DESCRIPTOR or not all(isinstance(value, str) and 0 < len(value) <= 4096 for value in obj.values()) or not sha(obj['source_sha256']) or not sha(obj['bindings_sha256']):
            raise StoreError('invalid-cache-object')
        utf16_length = len(namespace.encode('utf-16-le')) // 2
        if obj['source_patient_key'] != str(utf16_length) + ':' + namespace + obj['owner_key']:
            raise StoreError('cache-owner-key-mismatch')
        if obj['source_uid'] in seen:
            raise StoreError('duplicate-cache-object')
        seen.add(obj['source_uid'])
    return [namespace, domain]


def execution_key(request, obj):
    return [2, obj['source_uid'], obj['source_sha256'], obj['bindings_sha256'], request['policy_sha256'], request['rulebook_sha256'], request['program_sha256']]


def validate_binding(store, scope, obj):
    for kind, expected in [('object', [obj['source_sha256']])]:
        key = store.lookup(kind, scope, obj['source_uid'])
        row = store.db.execute('SELECT payload FROM registry WHERE kind=? AND lookup=?', (kind, key)).fetchone()
        if row is None or store.decrypt(kind, key, row[0]) != expected:
            raise StoreError('cache-source-not-reserved-or-conflicting')
    key = store.lookup('owner', scope, obj['source_uid'])
    owner = store.db.execute('SELECT payload FROM registry WHERE kind=? AND lookup=?', ('owner', key)).fetchone()
    if owner is None:
        raise StoreError('cache-owner-not-reserved')
    value = store.decrypt('owner', key, owner[0])
    if value[0] != 'instance' or value[1] != obj['source_patient_key']:
        raise StoreError('cache-owner-conflict')
    key = store.lookup('uid', scope, obj['source_uid'])
    row = store.db.execute('SELECT payload FROM uids WHERE lookup=?', (key,)).fetchone()
    if row is None or store.decrypt('uid', key, row[0]) != {'mapped': obj['mapped_uid']}:
        raise StoreError('cache-mapped-uid-conflict')
    key = store.lookup('patient', scope, obj['source_patient_key'])
    row = store.db.execute('SELECT payload FROM patients WHERE lookup=?', (key,)).fetchone()
    if row is None or store.decrypt('patient', key, row[0])['alias'] != obj['mapped_patient']:
        raise StoreError('cache-mapped-patient-conflict')


def payload_path(store, token, suffix):
    if not isinstance(token, str) or not re.fullmatch('[0-9a-f]{32}', token):
        raise StoreError('invalid-cache-payload-token')
    if not (store.root / 'cache').exists():
        raise StoreError('cache-payload-missing')
    root = validate_directory(store.root / 'cache')
    return root / (token + suffix)


def verify_payload(path, expected, maximum):
    try:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or info.st_mode & 0o077 or info.st_size > maximum:
            raise StoreError('unsafe-cache-payload')
        if not sha(expected) or digest(path) != expected:
            raise StoreError('cache-payload-tampered')
    except FileNotFoundError:
        raise StoreError('cache-payload-missing') from None


def lookup_one(store, scope, request, obj):
    validate_binding(store, scope, obj)
    record = store.ledger_get('cache', scope, execution_key(request, obj))
    if record is None:
        return None
    if record.get('schema') != 1 or record.get('state') != 'Converted' or record.get('descriptor') != obj or record.get('release_authorized') is not False:
        raise StoreError('cache-contract-conflict')
    path = payload_path(store, record['token'], '.dcm')
    audit = payload_path(store, record['token'], '.audit.json')
    verify_payload(path, record['sha256'], 256 * 1024 * 1024)
    verify_payload(audit, record['audit_sha256'], 16 * 1024 * 1024)
    return {'file': str(path), 'sha256': record['sha256'], 'audit_file': str(audit), 'audit_sha256': record['audit_sha256']}


def lookup(store, request, domain):
    scope = request_scope(request, domain)
    store.require_ledger()
    return {'schema': 1, 'entries': [lookup_one(store, scope, request, obj) for obj in request['objects']]}


def commit(store, request, output, domain, checkpoint=lambda event: None):
    scope = request_scope(request, domain)
    if len(request['objects']) != 1 or not isinstance(output, dict) or set(output) != {'file', 'sha256', 'audit_file', 'audit_sha256'} or not sha(output['sha256']) or not sha(output['audit_sha256']):
        raise StoreError('invalid-cache-commit')
    obj = request['objects'][0]
    current = lookup_one(store, scope, request, obj)
    if current is not None:
        if current['sha256'] != output['sha256'] or current['audit_sha256'] != output['audit_sha256']:
            # Audit includes batch-local object names. Rebinding does not alter
            # converter events, but different payloads never replace old bytes.
            if current['sha256'] != output['sha256']:
                raise StoreError('immutable-cache-output-conflict')
        return {'schema': 1, 'status': 'already-cached'}
    folder = store.root / 'cache'
    if not folder.exists():
        folder.mkdir(mode=0o700)
        sync_directory(store.root)
    validate_directory(folder)
    token = secrets.token_hex(16)
    path, audit = folder / (token + '.dcm'), folder / (token + '.audit.json')
    current_bytes = sum(item.stat().st_size for item in folder.iterdir() if item.is_file() and item.name.endswith(('.dcm', '.audit.json')))
    incoming_bytes = Path(output['file']).stat().st_size + Path(output['audit_file']).stat().st_size
    if current_bytes + incoming_bytes > CACHE_BYTES_BUDGET or shutil.disk_usage(folder).free < incoming_bytes + 64 * 1024 ** 2:
        raise StoreError('cache-disk-budget')
    copy_file_new(output['file'], path, output['sha256'])
    copy_file_new(output['audit_file'], audit, output['audit_sha256'], maximum=16 * 1024 * 1024)
    checkpoint('cache-payload-durable')
    record = {'schema': 1, 'state': 'Converted', 'descriptor': obj, 'token': token,
              'sha256': output['sha256'], 'audit_sha256': output['audit_sha256'], 'release_authorized': False}
    store.db.execute('BEGIN IMMEDIATE')
    try:
        store.ledger_put('cache', scope, execution_key(request, obj), record)
        checkpoint('cache-before-commit')
        store.db.execute('COMMIT')
    except BaseException:
        store.db.execute('ROLLBACK')
        raise
    checkpoint('cache-after-commit')
    return {'schema': 1, 'status': 'cache-committed'}


def invalidate(store, request, domain):
    """Explicitly remove selected Converted cache entries; never automatic."""
    scope = request_scope(request, domain)
    removed = 0
    store.db.execute('BEGIN IMMEDIATE')
    try:
        for obj in request['objects']:
            key = store.lookup('ledger-cache', scope, execution_key(request, obj))
            row = store.db.execute('SELECT payload FROM ledger WHERE kind=? AND lookup=?', ('cache', key)).fetchone()
            if row is None:
                continue
            record = store.decrypt('ledger-cache', key, row[0])
            if record.get('state') != 'Converted':
                raise StoreError('cache-state-not-invalidatable')
            token = record.get('token')
            if not isinstance(token, str) or not re.fullmatch('[0-9a-f]{32}', token):
                raise StoreError('invalid-cache-payload-token')
            for suffix in ('.dcm', '.audit.json'):
                path = payload_path(store, token, suffix)
                try:
                    path.unlink()
                except FileNotFoundError:
                    pass
            store.db.execute('DELETE FROM ledger WHERE kind=? AND lookup=?', ('cache', key))
            removed += 1
        store.db.execute('COMMIT')
    except BaseException:
        store.db.execute('ROLLBACK')
        raise
    return {'schema': 1, 'status': 'cache-invalidated', 'removed': removed}


def cleanup_orphans(store):
    """Delete only cache payloads no longer referenced by authenticated rows."""
    folder = store.root / 'cache'
    if not folder.exists():
        return {'schema': 1, 'status': 'cache-orphans-cleaned', 'removed': 0}
    referenced = set()
    for kind, lookup, payload in store.db.execute('SELECT kind,lookup,payload FROM ledger WHERE kind=?', ('cache',)):
        value = store.decrypt('ledger-cache', lookup, payload)
        if value.get('state') == 'Converted':
            referenced.add(value.get('token'))
    removed = 0
    for path in folder.iterdir():
        if path.is_file() and (path.name.endswith('.dcm') or path.name.endswith('.audit.json')):
            token = path.name.split('.', 1)[0]
            if token not in referenced:
                path.unlink()
                removed += 1
    sync_directory(folder)
    return {'schema': 1, 'status': 'cache-orphans-cleaned', 'removed': removed}
