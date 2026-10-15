#!/usr/bin/env python3
"""Produce a host-specific preview archive/SBOM; never includes private stores."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import tarfile
import zipfile
from private_store import canonical
from release_readiness import module_metadata

REPO = Path(__file__).resolve().parents[1]
RUNTIME_TOOLS = ['private_store.py', 'store_admin.py', 'ledger_cache.py', 'history_outbox.py', 'local_fs.py', 'enterprise_job.py', 'risk_gate.py', 'attestation.py', 'verify_delivery.py', 'deliver_local.py', 'install_enterprise.py', 'workbench.py']


def build(destination, wheels):
    destination, wheels = Path(destination), Path(wheels)
    if subprocess.run(['git','diff','--quiet'],cwd=REPO).returncode or subprocess.run(['git','diff','--cached','--quiet'],cwd=REPO).returncode:
        raise ValueError('clean-tracked-source-required-for-distribution')
    destination.mkdir(mode=0o700)
    (destination / 'bin').mkdir()
    for source, name in [(REPO / '_build/native/debug/build/cmd/main/main.exe', 'medseal'), (REPO / '_build/native/debug/build/cmd/enterprise/enterprise.exe', 'medseal-enterprise')]:
        shutil.copyfile(source, destination / 'bin' / name)
        os.chmod(destination / 'bin' / name, 0o755)
    (destination / 'tools').mkdir()
    for name in RUNTIME_TOOLS:
        shutil.copyfile(REPO / 'tools' / name, destination / 'tools' / name)
    for name in ('LICENSE', 'THIRD_PARTY.md'):
        shutil.copyfile(REPO / name, destination / name)
    shutil.copytree(REPO / 'docs', destination / 'docs', ignore=shutil.ignore_patterns('evidence'))
    shutil.copytree(REPO / 'examples', destination / 'examples', ignore=shutil.ignore_patterns('*.mbt', '*.mbti', 'moon.pkg'))
    shutil.copytree(REPO / 'resources/licenses', destination / 'licenses')
    shutil.copytree(REPO / 'resources/rules', destination / 'rules')
    core_licenses = [REPO.parent / 'moonbit工具链/lib/core/LICENSE', Path(os.environ.get('MOON_HOME', str(Path.home() / '.moon'))) / 'lib/core/LICENSE']
    core_license = next((path for path in core_licenses if path.is_file()), None)
    if core_license is None:
        raise ValueError('installed-MoonBit-core-license-required')
    shutil.copyfile(core_license, destination / 'licenses/moonbit-core-runtime-LICENSE')
    for source, name in [(REPO / '.mooncakes/moonbitlang/async/LICENSE', 'moonbit-async-LICENSE'), (REPO / '.mooncakes/gmlewis/sha256/LICENSE', 'gmlewis-sha256-LICENSE'), (REPO / '.mooncakes/gmlewis/base64/LICENSE', 'gmlewis-base64-LICENSE')]:
        shutil.copyfile(source, destination / 'licenses' / name)
    # x 0.5.5 ships license headers rather than a root LICENSE. Retain the complete
    # Apache-2.0 terms shared by these dependencies and an explicit attribution.
    (destination / 'licenses/NOTICE.dependencies.md').write_text('moonbitlang/x 0.5.5: Copyright International Digital Economy Academy. Apache-2.0; full terms in moonbit-async-LICENSE. Source: https://github.com/moonbitlang/x\n')
    shutil.copytree(wheels, destination / 'wheels')
    versions = {'cryptography': '50.0.2', 'cffi': '2.1.1', 'pycparser': '3.0'}
    requirement_lines, components = [], []
    for name, version in versions.items():
        found = list((destination / 'wheels').glob(name + '-' + version + '-*.whl'))
        if len(found) != 1:
            raise ValueError('one-pinned-platform-wheel-required')
        wheel = found[0]
        checksum = hashlib.sha256(wheel.read_bytes()).hexdigest()
        requirement_lines.append(name + '==' + version + ' --hash=sha256:' + checksum)
        with zipfile.ZipFile(wheel) as archive:
            for item in archive.namelist():
                if '.dist-info/' in item and ('licenses/' in item or item.endswith('/LICENSE')):
                    target = destination / 'licenses' / (name + '-' + Path(item).name)
                    target.write_bytes(archive.read(item))
        components.append({'type': 'library', 'name': name, 'version': version, 'purl': 'pkg:pypi/' + name + '@' + version, 'hashes': [{'alg': 'SHA-256', 'content': checksum}]})
    (destination / 'requirements-enterprise.txt').write_text('\n'.join(requirement_lines) + '\n')
    for name, version in [('moonbitlang/async','0.22.4'),('moonbitlang/x','0.5.5'),('gmlewis/sha256','0.18.0'),('gmlewis/base64','0.16.13'),('moonbit-runtime','0.10.14+7d59c7ec9')]:
        components.append({'type': 'library', 'name': name, 'version': version, 'scope': 'required'})
    revision = subprocess.run(['git','rev-parse','HEAD'], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip()
    (destination / 'sbom.cdx.json').write_bytes(canonical({'bomFormat': 'CycloneDX', 'specVersion': '1.6', 'version': 1, 'metadata': {'component': {'type': 'application','name': 'MedSeal-MBT enterprise preview','version': module_metadata()['version'] + '+preview.' + revision[:7]}}, 'components': components}))
    (destination / 'README.md').write_text('# MedSeal enterprise engineering preview\n\nVerify the archive and distribution manifest digests from a trusted channel before extraction/execution. Python3.12 is required. Run tools/install_enterprise.py with --source, --destination (new directory), --python and --expected-manifest-sha256. The installer uses pinned wheels offline.\n\nStart with docs/OPERATIONS.zh-CN.md and docs/ENTERPRISE_STATUS.md. Signed data packages are verified independently by tools/verify_delivery.py with an out-of-band trusted key. This preview has synthetic acceptance evidence and is not a clinical production1.0 release.\n')
    manifest = {'schema': 1, 'platform': platform.system(), 'machine': platform.machine(), 'tested_host': platform.platform(), 'git_base_revision': revision, 'release_status': 'engineering-preview',
                'python_required': '3.12', 'files': [{'file': str(path.relative_to(destination)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(destination.rglob('*')) if path.is_file()]}
    encoded = canonical(manifest)
    (destination / 'distribution.json').write_bytes(encoded)
    archive_path = destination.parent / (destination.name + '.tar.gz')
    with tarfile.open(archive_path, 'w:gz') as archive:
        for path in sorted(destination.rglob('*')):
            if path.is_file():
                archive.add(path, arcname=str(Path(destination.name) / path.relative_to(destination)), recursive=False)
    result = {'schema': 1, 'status': 'preview-built', 'archive_sha256': hashlib.sha256(archive_path.read_bytes()).hexdigest(), 'manifest_sha256': hashlib.sha256(encoded).hexdigest(), 'platform': manifest['platform'], 'machine': manifest['machine']}
    (destination.parent / (destination.name + '.checksums.json')).write_bytes(canonical(result))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--wheels', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.destination,args.wheels)))


if __name__ == '__main__':
    main()
