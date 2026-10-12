#!/usr/bin/env python3
"""Exercise the built offline distribution, not the source runtime."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from build_distribution import REPO, build
from install_enterprise import install


def rejected(source, destination, python, checksum):
    try:
        install(source, destination, python, checksum)
    except (ValueError, FileExistsError):
        assert not destination.exists()
        return
    raise AssertionError('untrusted distribution was installed')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--wheels', type=Path, required=True)
    parser.add_argument('--python', type=Path, default=Path(sys.executable))
    parser.add_argument('--record', type=Path, required=True)
    args = parser.parse_args()
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='offline-distribution-') as temp:
        root = Path(temp)
        source = root / 'distribution'
        preview = build(source, args.wheels.resolve(strict=True))
        checksum = preview['manifest_sha256']
        rejected(source, root / 'wrong-checksum', args.python, '0' * 64)
        altered = root / 'altered'
        shutil.copytree(source, altered)
        (altered / 'LICENSE').write_text('ALTERED')
        rejected(altered, root / 'tampered-install', args.python, checksum)
        extra = root / 'extra'
        shutil.copytree(source, extra)
        (extra / 'unexpected-file').write_bytes(b'UNEXPECTED')
        rejected(extra, root / 'extra-install', args.python, checksum)
        installed = root / 'installed'
        result = install(source, installed, args.python, checksum)
        pilot_record = root / 'pilot.json'
        subprocess.run([str(args.python), str(REPO / 'tools/verify_pilot.py'), '--runtime-root', str(installed), '--python', str(installed / '.venv/bin/python'), '--record', str(pilot_record)], cwd=REPO, check=True)
        pilot = json.loads(pilot_record.read_bytes())
        assert pilot['runtime'] == 'isolated-offline-install' and pilot['distribution_manifest_sha256'] == checksum
        record = {'schema': 1, 'status': 'passed', 'scope': 'host-specific isolated offline engineering preview', 'distribution': preview, 'installation': result,
                  'checks': ['wrong-trusted-manifest-refused-before-install', 'tampered-payload-refused-before-install', 'unexpected-content-refused-before-install', 'new-isolated-offline-install', 'installed-full-two-increments-and-recovery-pilot'],
                  'pilot': pilot, 'field_acceptance_complete': False}
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'status': 'passed', 'checks': len(record['checks']), 'field_acceptance_complete': False}))


if __name__ == '__main__':
    main()
