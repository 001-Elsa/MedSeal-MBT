#!/usr/bin/env python3
"""Synthetic multi-batch enterprise and transactional store regression."""
from pathlib import Path
import argparse
import concurrent.futures
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from verify_strict_profile import generate_strict
from verify_with_pydicom import REPO
import pydicom
from private_store import initialize
from store_admin import backup, restore, rotate

PYTHON = sys.executable
ADAPTER = REPO / 'tools/private_store.py'
BINARY = REPO / '_build/native/debug/build/cmd/enterprise/enterprise.exe'
POLICY = REPO / 'examples/strict-policy.json'


def reserve(store, request, domain='synthetic-lab', ok=True):
    result = subprocess.run([PYTHON, str(ADAPTER), 'reserve', '--store', str(store), '--source-domain', domain], input=json.dumps(request), capture_output=True, text=True)
    assert (result.returncode == 0) == ok, result.stderr
    if not ok:
        assert 'SECRET' not in result.stderr
        return result.stderr
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', type=Path, default=REPO / 'tmp/p2-persistent-identity.json')
    args = parser.parse_args()
    os.umask(0o077)
    checks = []
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='p2-') as temporary:
        root = Path(temporary)
        store = root / 'private'
        initialize(store)
        source = root / 'input'
        generate_strict(source, 4)
        previous = None
        for batch in range(3):
            output = root / ('out-' + str(batch))
            result = subprocess.run([str(BINARY), str(source), str(output), str(POLICY), PYTHON, str(ADAPTER), str(store), 'synthetic-lab'], capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            rows = [(str(ds.PatientID), str(ds.SOPInstanceUID), str(ds.StudyInstanceUID), str(ds.SeriesInstanceUID), str(ds.StudyDate)) for ds in map(pydicom.dcmread, sorted(output.glob('*.dcm')))]
            assert previous is None or rows == previous
            previous = rows
        checks.append('three-MoonBit-batches-stable-identities-uids-dates')
        request = {'schema': 2, 'namespace': 'isolated-project', 'date_shift_days': 30,
                   'patients': [{'key': 'SECRET-PATIENT', 'name': 'SECRET-NAME', 'birth_date': '19700101'}],
                   'uids': ['1.2.3.1', '1.2.3.2', '1.2.3.3'], 'objects': [['1.2.3.3', 'a' * 64]],
                   'owners': [['1.2.3.1', 'study', 'SECRET-PATIENT', ''], ['1.2.3.2', 'series', 'SECRET-PATIENT', '1.2.3.1'], ['1.2.3.3', 'instance', 'SECRET-PATIENT', '1.2.3.2']]}
        first = reserve(store, request)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            assert all(item == first for item in pool.map(lambda _: reserve(store, request), range(8)))
        checks.append('eight-parallel-reservations-consistent')
        other_domain = reserve(store, request, 'other-source')
        another_project = copy.deepcopy(request)
        another_project['namespace'] = 'another-project'
        other_project = reserve(store, another_project)
        assert len({first['patients'][0]['alias'], other_domain['patients'][0]['alias'], other_project['patients'][0]['alias']}) == 3
        checks.append('source-and-project-isolation')
        for field, change in [('objects', lambda value: value[0].__setitem__(1, 'b' * 64)), ('owners', lambda value: value[2].__setitem__(3, '1.2.3.1')), ('patients', lambda value: value[0].__setitem__('name', 'DIFFERENT'))]:
            altered = copy.deepcopy(request)
            change(altered[field])
            reserve(store, altered, ok=False)
        assert reserve(store, request) == first
        checks.append('content-owner-patient-conflicts-rollback')
        rotate(store)
        assert reserve(store, request) == first
        snapshot, restored = root / 'backup', root / 'restored'
        backup(store, snapshot)
        restore(snapshot, restored)
        assert reserve(restored, request) == first
        checks.append('wrapping-rotation-and-SQLite-backup-restore-stable')
        current = (store / 'CURRENT').read_text()
        key = store / current / 'wrapping.key'
        original = key.read_bytes()
        key.write_bytes(bytes(32))
        reserve(store, request, ok=False)
        key.write_bytes(original)
        key.unlink()
        reserve(store, request, ok=False)
        checks.append('wrong-and-missing-key-fail-closed')
        for private in root.glob('**/identity.sqlite*'):
            assert b'SECRET' not in private.read_bytes()
        checks.append('no-source-markers-in-database-and-WAL')
    record = {'schema': 1, 'fixture': 'synthetic only', 'checks': checks,
              'enterprise_binary_sha256': hashlib.sha256(BINARY.read_bytes()).hexdigest(),
              'cryptography': __import__('cryptography').__version__, 'sqlite': __import__('sqlite3').sqlite_version,
              'limitations': ['exact duplicates reuse identities but are still converted', 'closed batch references only', 'local POSIX key provider; backup contains keys', 'no physical power-loss certification']}
    path = args.record
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'passed', 'checks': len(checks)}))


if __name__ == '__main__':
    main()
