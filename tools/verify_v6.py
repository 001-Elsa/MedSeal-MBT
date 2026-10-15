#!/usr/bin/env python3
"""Run the source-only V6 gate on a clean checkout; no publication side effects."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import sys
from verify_consumer import moon_binary
from release_readiness import module_metadata

REPO = Path(__file__).resolve().parents[1]


def check(name, command, env):
    print('V6: ' + name, flush=True)
    try:
        completed = subprocess.run(command, cwd=REPO, env=env, capture_output=True,
                                   text=True, timeout=1800)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(name + ': timed out; no successful release gate') from exc
    if completed.returncode:
        # All executed fixtures are synthetic. The detailed local diagnostic is
        # intentionally excluded from the public result record.
        raise RuntimeError(name + ' failed:\n' + (completed.stdout + completed.stderr)[-3000:])
    return {'name': name, 'status': 'passed'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--record', type=Path, required=True)
    args = parser.parse_args()
    moon = moon_binary()
    env = dict(os.environ, MOON_HOME=str(moon.parent.parent))
    env['PATH'] = str(moon.parent) + os.pathsep + env.get('PATH', '')
    node = shutil.which('node', path=env['PATH'])
    if not node:
        parser.error('Node.js is required; install the documented web dependencies first')
    version = module_metadata()['version']
    record_dir = REPO / 'tmp/v6'
    record_dir.mkdir(parents=True, exist_ok=True)
    commands = [
        ('clean-source', ['git', 'diff', '--exit-code', 'HEAD']),
        ('doctor', [sys.executable, 'tools/doctor.py', '--json']),
        ('documentation', [sys.executable, 'tools/check_documentation.py']),
        ('moon-info', [str(moon), 'info']),
        ('moon-format', [str(moon), 'fmt', '--check']),
        ('moon-all-check', [str(moon), 'check', '--target', 'all', '--deny-warn']),
        ('moon-all-test', [str(moon), 'test', '--target', 'all', '--deny-warn']),
        ('moon-native-build', [str(moon), 'build', '--target', 'native']),
        ('dicom-json-oracle', [sys.executable, 'tools/verify_dicom_json.py', '--record', 'tmp/v6/json.json']),
        ('dataset-preflight', [sys.executable, 'tools/verify_dataset_preflight.py', '--record', 'tmp/v6/preflight.json']),
        ('licensed-phantom', [sys.executable, 'tools/verify_phantom.py', '--record', 'tmp/v6/phantom.json']),
        ('lab-build', [sys.executable, 'tools/build_community_lab.py']),
        ('lab-dom', [node, 'tools/verify_community_lab.mjs']),
        ('lab-browser', [node, 'tools/verify_lab_browser.mjs']),
        ('private-files-browser', [node, 'tools/verify_private_browser.mjs']),
        ('archive-public-consumer-four-backends', [sys.executable, 'tools/verify_consumer.py', 'tmp/v6/consumer.json']),
        ('moon-package', [str(moon), 'package', '--frozen']),
        ('exact-source-package', [sys.executable, 'tools/verify_platform_snapshot.py', '--archive',
                                 '_build/publish/001-Elsa-medseal-' + version + '.zip',
                                 '--record', 'tmp/v6/snapshot.json']),
        ('source-unchanged', ['git', 'diff', '--exit-code', 'HEAD']),
    ]
    checks = [check(name, command, env) for name, command in commands]
    result = {'schema': 1, 'status': 'passed', 'module': '001-Elsa/medseal',
              'version': version, 'checks': checks,
              'registry_consumer': 'run separately after publication; never local fallback',
              'orthanc': 'separate fixed receiver workflow; not inferred from this gate',
              'field_acceptance_complete': False,
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()}
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
