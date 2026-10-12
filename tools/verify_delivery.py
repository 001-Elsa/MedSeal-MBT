#!/usr/bin/env python3
"""Independent offline recipient. Needs cryptography; no identity store/MoonBit.

Canonical release contract: schema2, UTF-8 JSON, sorted keys, compact separators, no NaN,
no duplicate keys, integer-only numeric fields. Public keys arrive out of band.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import os
import re
import stat
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey


class DeliveryError(Exception):
    pass


def canonical_bytes(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')


def parse_json(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise DeliveryError('duplicate-json-key')
            result[key] = value
        return result
    try:
        return json.loads(data, object_pairs_hook=unique, parse_constant=lambda _: (_ for _ in ()).throw(DeliveryError('invalid-json-number')))
    except DeliveryError:
        raise
    except Exception:
        raise DeliveryError('invalid-json') from None


def read_file(path, limit, retain=False):
    path = Path(path)
    if path.is_symlink():
        raise DeliveryError('linked-file')
    descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size > limit:
            raise DeliveryError('invalid-file-or-budget')
        checksum, parts = hashlib.sha256(), []
        while True:
            data = os.read(descriptor, 1024 * 1024)
            if not data:
                break
            checksum.update(data)
            if retain:
                parts.append(data)
        after, named = os.fstat(descriptor), path.lstat()
        if (before.st_size, before.st_mtime_ns, before.st_ctime_ns, before.st_ino, before.st_dev) != (after.st_size, after.st_mtime_ns, after.st_ctime_ns, after.st_ino, after.st_dev) or (after.st_ino, after.st_dev) != (named.st_ino, named.st_dev):
            raise DeliveryError('file-changed')
        return b''.join(parts) if retain else checksum.hexdigest()
    finally:
        os.close(descriptor)


def verify_package(root, trust_path, allow_synthetic=False, object_root=None):
    root = Path(root).absolute()
    if root.is_symlink() or not root.is_dir() or root.resolve() != root:
        raise DeliveryError('invalid-package-root')
    trust = parse_json(read_file(trust_path, 1024 * 1024, True))
    if set(trust) != {'schema', 'keys'} or trust['schema'] != 1 or not isinstance(trust['keys'], dict):
        raise DeliveryError('unsupported-trust-schema')
    envelope = parse_json(read_file(root / 'signature.json', 4096, True))
    if set(envelope) != {'schema', 'algorithm', 'key_id', 'signature'} or envelope['schema'] != 1 or envelope['algorithm'] != 'Ed25519' or envelope['key_id'] not in trust['keys']:
        raise DeliveryError('unknown-signing-key-or-schema')
    try:
        key = bytes.fromhex(trust['keys'][envelope['key_id']])
        if len(key) != 32 or hashlib.sha256(key).hexdigest() != envelope['key_id']:
            raise ValueError()
        signature = base64.b64decode(envelope['signature'], validate=True)
        encoded = read_file(root / 'release.json', 4 * 1024 * 1024, True)
        Ed25519PublicKey.from_public_bytes(key).verify(signature, encoded)
    except Exception:
        raise DeliveryError('trusted-signature-verification-failed') from None
    release = parse_json(encoded)
    fields = {'schema', 'producer_runtime_sha256', 'release_authorized', 'context', 'tool_version', 'policy_sha256', 'dictionary_sha256', 'conversion_manifest_sha256', 'review_sha256', 'files', 'risk_summary', 'inventory'}
    if set(release) not in [fields, fields | {'destination_binding'}] or type(release['schema']) is not int or release['schema'] != 2 or release['release_authorized'] is not True or release['context'] not in {'controlled', 'synthetic'} or canonical_bytes(release) != encoded:
        raise DeliveryError('unsupported-or-noncanonical-release')
    if release['context'] == 'synthetic' and not allow_synthetic:
        raise DeliveryError('synthetic-package-not-a-controlled-release')
    for name in ('producer_runtime_sha256', 'policy_sha256', 'dictionary_sha256', 'conversion_manifest_sha256', 'review_sha256'):
        if not isinstance(release[name], str) or not re.fullmatch('[0-9a-f]{64}', release[name]):
            raise DeliveryError('invalid-release-binding')
    if not isinstance(release['files'], list) or not 3 <= len(release['files']) <= 20001:
        raise DeliveryError('invalid-file-inventory')
    if release['risk_summary'] != {'blocking_unresolved': 0, 'pixel_review': 'human-reviewed-clear', 'metadata_scope': 'recipient-accepted-subset'}:
        raise DeliveryError('unresolved-or-unsupported-risk-gate')
    expected = {'release.json', 'signature.json'}
    dcms, audits = set(), set()
    for entry in release['files']:
        if not isinstance(entry, dict) or set(entry) != {'file', 'sha256'} or not isinstance(entry['file'], str) or not isinstance(entry['sha256'], str) or not re.fullmatch('[0-9a-f]{64}', entry['sha256']):
            raise DeliveryError('invalid-file-entry')
        filename = entry['file']
        if not re.fullmatch(r'manifest\.json|object-[1-9][0-9]*\.(dcm|audit\.json)', filename) or filename in expected:
            raise DeliveryError('noncanonical-or-duplicate-file-name')
        if filename.endswith('.dcm'):
            dcms.add(filename[:-4])
        elif filename.endswith('.audit.json'):
            audits.add(filename[:-11])
        maximum = 256 * 1024 * 1024 if filename.endswith('.dcm') else 16 * 1024 * 1024
        if object_root is not None and filename.endswith('.dcm'):
            blob_root = Path(object_root).absolute()
            if blob_root.is_symlink() or not blob_root.is_dir() or blob_root.resolve() != blob_root:
                raise DeliveryError('invalid-explicit-object-root')
            filepath = blob_root / (entry['sha256'] + '.dcm')
        else:
            filepath = root / filename
        if read_file(filepath, maximum) != entry['sha256']:
            raise DeliveryError('signed-file-hash-mismatch')
        expected.add(filename)
    if not dcms or dcms != audits or 'manifest.json' not in expected or dcms != {'object-' + str(i) for i in range(1, len(dcms) + 1)} or {path.name for path in root.iterdir()} != (expected - {entry + '.dcm' for entry in dcms} if object_root is not None else expected):
        raise DeliveryError('signed-collection-inventory-mismatch')
    if read_file(root / 'manifest.json', 8 * 1024 * 1024) != release['conversion_manifest_sha256']:
        raise DeliveryError('conversion-manifest-binding-mismatch')
    manifest = parse_json(read_file(root / 'manifest.json', 8 * 1024 * 1024, True))
    if manifest.get('policy_sha256') != release['policy_sha256'] or manifest.get('dictionary_sha256') != release['dictionary_sha256'] or manifest.get('tool_version') != release['tool_version'] or {entry['file'] for entry in manifest.get('objects', [])} != {entry + '.dcm' for entry in dcms}:
        raise DeliveryError('conversion-semantics-binding-mismatch')
    return {'schema': 1, 'status': 'trusted-package-verified', 'context': release['context'], 'objects': len(dcms), 'key_id': envelope['key_id'], 'release_sha256': hashlib.sha256(encoded).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('package', type=Path)
    parser.add_argument('--trust', type=Path, required=True)
    parser.add_argument('--allow-synthetic', action='store_true')
    parser.add_argument('--object-root', type=Path, help='Explicit trusted content-addressed object directory for the deduplicating receiver')
    args = parser.parse_args()
    try:
        print(json.dumps(verify_package(args.package, args.trust, args.allow_synthetic, args.object_root)))
        return 0
    except DeliveryError as error:
        print(json.dumps({'schema': 1, 'status': 'rejected', 'code': str(error)}), file=sys.stderr)
        return 6
    except Exception:
        print('{"schema":1,"status":"rejected","code":"package-read-or-trust-failure"}', file=sys.stderr)
        return 6


if __name__ == '__main__':
    raise SystemExit(main())
