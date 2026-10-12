#!/usr/bin/env python3
"""Offline installer for a checksum-pinned distribution directory (stdlib only)."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import os
import platform
import shutil
import stat
import subprocess
import sys


def install(source, destination, python, expected_manifest):
    source = Path(source).resolve(strict=True)
    manifest_data = (source / 'distribution.json').read_bytes()
    if hashlib.sha256(manifest_data).hexdigest() != expected_manifest:
        raise ValueError('distribution-manifest-trust-mismatch')
    manifest = json.loads(manifest_data)
    if manifest.get('schema') != 1 or manifest.get('platform') != platform.system() or manifest.get('machine') != platform.machine():
        raise ValueError('unsupported-distribution-platform')
    expected = {'distribution.json'}
    for item in manifest['files']:
        name = item['file']
        parsed = PurePosixPath(name)
        if parsed.is_absolute() or '..' in parsed.parts or name in expected or str(parsed) != name or '\\' in name:
            raise ValueError('invalid-distribution-path')
        path = source / name
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
            raise ValueError('distribution-file-integrity-failed')
        expected.add(name)
    actual = {str(path.relative_to(source)) for path in source.rglob('*') if not path.is_dir()}
    if actual != expected or any(path.is_symlink() for path in source.rglob('*')):
        raise ValueError('unexpected-distribution-content')
    python = Path(python).resolve(strict=True)
    checked = subprocess.run([str(python), '-I', '-c', 'import sys;raise SystemExit(0 if sys.version_info[:2]==(3,12) else 1)'], capture_output=True)
    if checked.returncode or os.name != 'posix':
        raise ValueError('Python-3.12-on-POSIX-required')
    destination = Path(destination)
    destination.mkdir(mode=0o700)
    try:
        for name in expected:
            target = destination / name
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            shutil.copyfile(source / name, target, follow_symlinks=False)
            os.chmod(target, 0o700 if name.startswith('bin/') else 0o600)
        subprocess.run([str(python), '-I', '-m', 'venv', str(destination / '.venv')], check=True, stdout=subprocess.DEVNULL)
        runtime = destination / '.venv/bin/python'
        subprocess.run([str(runtime), '-I', '-m', 'pip', 'install', '--no-cache-dir', '--no-index', '--find-links', str(destination / 'wheels'), '--require-hashes', '-r', str(destination / 'requirements-enterprise.txt')], check=True, stdout=subprocess.DEVNULL)
        subprocess.run([str(runtime), '-I', '-c', 'import cryptography;assert cryptography.__version__=="50.0.2"'], check=True)
        return {'schema': 1, 'status': 'offline-installed', 'manifest_sha256': expected_manifest, 'platform': manifest['platform'], 'machine': manifest['machine']}
    except Exception:
        # Preserve a diagnosable private failed install; never delete an arbitrary destination.
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--python', type=Path, required=True)
    parser.add_argument('--expected-manifest-sha256', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(install(args.source, args.destination, args.python, args.expected_manifest_sha256)))
        return 0
    except Exception:
        print('{"schema":1,"status":"failed","code":"offline-install-preflight-or-install-failed"}', file=sys.stderr)
        return 7


if __name__ == '__main__':
    raise SystemExit(main())
