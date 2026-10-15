#!/usr/bin/env python3
"""Diagnose local prerequisites without reading data, secrets or environment values."""
from pathlib import Path
import argparse
import importlib.metadata
import json
import platform
import re
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]


def version_of(command, pattern):
    try:
        result = subprocess.run(command, cwd=REPO, capture_output=True, text=True,
                                timeout=15, check=False)
        match = re.search(pattern, result.stdout + result.stderr)
        # Return only parsed versions: moon prints a local binary path as well.
        return match.group(1) if result.returncode == 0 and match else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def diagnose():
    moon = shutil.which('moon') or str(REPO / 'tools/moon-local')
    moon_version = version_of([moon, 'version', '--all'], r'moon ([0-9.]+)')
    compiler = version_of([moon, 'version', '--all'], r'moonc (\S+)')
    checks = {
        'python': {'passed': sys.version_info[:2] == (3, 12),
                   'version': platform.python_version(),
                   'advice': 'Run with Python 3.12; install requirements-qa.txt and requirements-enterprise.txt.'},
        'moon': {'passed': moon_version == '0.1.20260920' and compiler == 'v0.10.14+7d59c7ec9',
                 'version': moon_version, 'compiler': compiler,
                 'advice': 'Use moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9 and run moon update.'},
    }
    for requirement in ('requirements-qa.txt', 'requirements-enterprise.txt'):
        for line in (REPO / requirement).read_text().splitlines():
            match = re.fullmatch(r'([A-Za-z0-9_-]+)==([^\s]+)', line.strip())
            if not match:
                continue
            package, expected = match.groups()
            try:
                actual = importlib.metadata.version(package)
            except importlib.metadata.PackageNotFoundError:
                actual = None
            checks[package] = {'passed': actual == expected, 'version': actual,
                               'expected': expected, 'advice': 'Install ' + requirement + ' with Python 3.12.'}
    version = re.search(r'^version\s*=\s*"([^"]+)"', (REPO / 'moon.mod').read_text(), re.M).group(1)
    return {'schema': 1, 'status': 'passed' if all(c['passed'] for c in checks.values()) else 'action-required',
            'module': '001-Elsa/medseal', 'version': version,
            'platform': platform.system().lower() + '-' + platform.machine().lower(),
            'checks': checks, 'secrets_inspected': False, 'patient_files_inspected': False,
            'node_browser_dependencies': 'Check separately with web/pnpm-lock.yaml and verify_lab_browser.mjs.'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    result = diagnose()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print('MedSeal ' + result['version'] + ': ' + result['status'])
        for key, value in result['checks'].items():
            if not value['passed']:
                print(key + ': ' + value['advice'])
    raise SystemExit(0 if result['status'] == 'passed' else 1)


if __name__ == '__main__':
    main()
