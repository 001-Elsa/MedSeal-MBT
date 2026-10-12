#!/usr/bin/env python3
"""Required, independently authored synthetic corpus, actual writer and IOD gate.

QA models can contain synthetic values. This tool is never a production/public
explanation endpoint, and rejects a corpus not matching the committed recipes.
"""
from pathlib import Path
import argparse
from collections import Counter
import hashlib
import importlib.metadata
import io
import json
import os
import platform
import re
import subprocess
import sys
import tempfile
import warnings

import pydicom
from generate_conformance_corpus import normalized
from evidence import code_identity
from verify_rulebook import catalog_check
from moon_tokens import semantic_tokens

REPO = Path(__file__).resolve().parents[1]
CATEGORIES = {'valid', 'malformed', 'unsupported', 'resource-limit', 'privacy-risk', 'conditional'}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def integrity(root, manifest):
    assert manifest['schema'] == 1 and manifest['pydicom'] == '3.0.1'
    assert manifest['expectations_sha256'] == digest(root / 'expectations.json'), 'expectation drift'
    entries = manifest['entries']
    assert len(entries) >= 120 and len({e['id'] for e in entries}) == len(entries)
    assert CATEGORIES == {e['category'] for e in entries}
    members = entries + [m for c in manifest['collections'] for m in c['members']]
    for member in members:
        relative = Path(member['file'])
        assert not relative.is_absolute() and '..' not in relative.parts and relative.parts[0] == 'fixtures'
        path = root / relative
        assert path.is_file() and not path.is_symlink(), 'required fixture missing'
        assert path.stat().st_size == member['bytes'] and digest(path) == member['sha256'], 'fixture tampered'
    assert all(e['required'] and e['license'] == 'Apache-2.0' for e in entries)
    assert all(c['required'] and c['license'] == 'Apache-2.0' for c in manifest['collections'])


def check_integrity_negatives(root, manifest):
    """Exercise the real gate, without changing repository fixtures."""
    import shutil
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='w1-integrity-') as folder:
        isolated = Path(folder) / 'conformance'
        shutil.copytree(root, isolated)
        first = isolated / manifest['entries'][0]['file']
        original = first.read_bytes()
        mutations = [lambda: first.unlink(), lambda: first.write_bytes(original + b'X'),
                     lambda: (isolated / 'expectations.json').write_text('{}')]
        checked = []
        for label, mutate in zip(['required-missing', 'required-tampered', 'expectation-tampered'], mutations):
            first.write_bytes(original)
            mutate()
            try:
                integrity(isolated, manifest)
            except AssertionError:
                checked.append(label)
            else:
                raise AssertionError('integrity negative accepted: ' + label)
        assert semantic_tokens('f("A B", )') == semantic_tokens('f( "A B")')
        assert semantic_tokens('f("A B")') != semantic_tokens('f("AB")')
        checked.append('literal-whitespace-preserved-by-drift-gate')
        return checked


def dependency_records():
    result = []
    for line in (REPO / 'requirements-qa.txt').read_text().splitlines():
        name, expected = line.split('==')
        dist = importlib.metadata.distribution(name)
        assert dist.version == expected, (name, expected, dist.version)
        # Hash actual installed code, not just the declared version string.
        files = []
        for item in dist.files or []:
            if item.suffix in {'.py', '.so', '.pyd', '.dll', '.dylib'}:
                files.append([str(item), digest(dist.locate_file(item))])
        result.append({'name': name, 'version': expected, 'files': len(files),
                       'installed_code_sha256': hashlib.sha256(json.dumps(sorted(files)).encode()).hexdigest()})
    return result


def independently_read(path):
    with warnings.catch_warnings(record=True) as messages:
        warnings.simplefilter('always')
        ds = pydicom.dcmread(path)
        model = normalized(ds)  # forces lazy VR/value conversion and warnings
    return ds, model, [str(m.message) for m in messages]


def iod_diagnostics(tool, path):
    proc = subprocess.run([str(tool), str(path)], capture_output=True, text=True, timeout=20)
    raw = proc.stdout + proc.stderr
    errors = [line for line in raw.splitlines() if line.startswith('Error')]
    warning_lines = [line for line in raw.splitlines() if line.startswith('Warning')]
    explanations = []
    for line in warning_lines:
        if 'DICOMDIR' in line:
            explanation = 'Research directory receiver does not build DICOMDIR; intentionally emptied identifying Study ID/Time. DICOMDIR use is outside scope.'
        elif 'Laterality' in line:
            explanation = 'Synthetic SC does not identify a paired anatomical body part; empty conditional value is an input limitation. No anatomical laterality use is claimed.'
        elif 'de-identification' in line.lower() or 'Deidentification' in line:
            explanation = 'Metadata subset with pixels unchecked does not claim complete PS3.15 conformance or release authority.'
        else:
            raise AssertionError('Unexplained IOD warning: ' + line)
        explanations.append({'diagnostic': line, 'disposition': explanation})
    assert proc.returncode == 0 and not errors, {'exit': proc.returncode, 'raw': raw}
    return {'exit': proc.returncode, 'raw': raw, 'errors': errors, 'warnings': explanations}


def reference_difference(entry, path):
    try:
        _, _, messages = independently_read(path)
        status = 'accepted'
    except Exception as error:
        status, messages = 'rejected', [type(error).__name__ + ': ' + str(error)]
    # Reference reader is deliberately permissive: strict profile/privacy,
    # ownership, budgets and transfer syntax restrictions are extra contracts.
    explanation = ('pydicom is a permissive data reader; MedSeal additionally enforces length/encoding, profile, dictionary, ownership, identity and resource contracts. Reference acceptance never overrides independently authored strict expectations.'
                   if status == 'accepted' else 'Both reject; error shapes differ by reader architecture.')
    return {'reader': status, 'raw_diagnostics': messages, 'disposition': explanation}


def run(args):
    root = REPO / 'conformance'
    manifest = json.loads((root / 'manifest.json').read_text())
    (REPO / 'tmp').mkdir(exist_ok=True)
    integrity(root, manifest)
    negatives = check_integrity_negatives(root, manifest)
    subprocess.run([sys.executable, str(REPO / 'tools/generate_conformance_corpus.py'), '--check'], cwd=REPO, check=True)
    catalog = catalog_check()
    dependencies = dependency_records()
    moon = REPO / 'tools/moon-local' if (REPO / 'tools/moon-local').exists() and os.name != 'nt' else Path('moon')
    toolchain = subprocess.check_output([str(moon), 'version', '--all'], cwd=REPO, text=True)
    backends = []
    for target in args.backends.split(','):
        proc = subprocess.run([str(moon), 'test', '--target', target, '--deny-warn'], cwd=REPO, capture_output=True, text=True, timeout=600)
        assert proc.returncode == 0, proc.stdout + proc.stderr
        summary = re.search(r'Total tests: (\d+), passed: (\d+), failed: (\d+)', proc.stdout + proc.stderr)
        assert summary and int(summary[1]) > 0 and summary[1] == summary[2] and summary[3] == '0'
        backends.append({'target': target, 'suite_tests': int(summary[1]), 'corpus_executed': len(manifest['entries']) + len(manifest['collections']), 'failed': 0, 'skipped': 0})
        print('Backend acceptance:', target, summary.group(0), flush=True)
    binary = REPO / '_build/native/debug/build/cmd/lab/lab.exe'
    assert binary.is_file(), 'build native QA driver first'
    results, collections = [], []
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='w1-lab-') as folder:
        temporary = Path(folder)
        for entry in manifest['entries']:
            source = root / entry['file']
            output, config = temporary / 'output.dcm', temporary / 'policy.json'
            output.unlink(missing_ok=True)
            config.write_text(entry['configuration'])
            accepted = entry['expected']['status'] == 'passed'
            command = [str(binary), entry['purpose'], str(source), entry['tag'], str(config), str(output) if accepted else '-']
            proc = subprocess.run(command, capture_output=True, text=True, timeout=20)
            assert proc.returncode == 0, (entry['id'], proc.stdout, proc.stderr)
            actual = json.loads(proc.stdout)
            assert actual == entry['expected'], entry['id']
            item = {'id': entry['id'], 'category': entry['category'], 'status': 'passed', 'expected': 'accepted' if accepted else 'blocked', 'fixture_sha256': entry['sha256']}
            if accepted:
                ds, observed, messages = independently_read(output)
                expected_model = entry['expected']['after' if entry['purpose'] == 'pipeline' else 'roundtrip']
                assert observed == expected_model, 'independent output values: ' + entry['id']
                assert ds.file_meta.MediaStorageSOPClassUID == ds.SOPClassUID and ds.file_meta.MediaStorageSOPInstanceUID == ds.SOPInstanceUID
                source_ds = pydicom.dcmread(source)
                assert ds.PixelData == source_ds.PixelData, 'pixel bytes changed'
                item.update(independent_writer_read=True, pixel_bytes_equal=True, file_meta_equal=True, pydicom_diagnostics=messages)
                if entry['iod_validator'] and args.dciodvfy:
                    item['iod_before'] = iod_diagnostics(args.dciodvfy, source)
                    item['iod_after'] = iod_diagnostics(args.dciodvfy, output)
            else:
                item['reference_difference'] = reference_difference(entry, source)
            results.append(item)
        for collection in manifest['collections']:
            inputs = temporary / 'members.txt'
            inputs.write_text('\n'.join(str(root / member['file']) for member in collection['members']))
            proc = subprocess.run([str(binary), 'collection', str(inputs), '-', '-', '-'], capture_output=True, text=True, timeout=20)
            assert proc.returncode == 0 and json.loads(proc.stdout) == collection['expected'], (collection['id'], proc.stdout, proc.stderr)
            collections.append({'id': collection['id'], 'status': 'passed', 'expected': collection['expected']})
    # Every rule gets executable positive/negative evidence; existing W0 model
    # and privacy tests supplement byte-level cases where byte files cannot
    # express a forged model or an unsafe report object.
    matrix = []
    for rule in catalog['rules']:
        related = [e for e in manifest['entries'] if rule['id'] in e['rules']]
        matrix.append({'rule_id': rule['id'], 'positive': [e['id'] for e in related if e['expected']['status'] == 'passed'],
                       'negative': [e['id'] for e in related if e['expected']['status'] == 'blocked'],
                       'supplemental_test': rule['test'], 'positive_case': rule['positive_case'], 'negative_case': rule['negative_case']})
    assert len(matrix) == len(catalog['rules'])
    executed = len(results) + len(collections)
    return {'schema': 1, 'stage': 'W1', 'status': 'passed', **code_identity(REPO),
            'scope': manifest['scope'], 'manifest_sha256': digest(root / 'manifest.json'), 'binary_sha256': digest(binary),
            'platform': platform.platform(), 'python': platform.python_version(), 'toolchain': toolchain,
            'dependencies': dependencies, 'executed': executed, 'passed': executed, 'failed': 0, 'skipped': 0,
            'categories': dict(Counter(e['category'] for e in manifest['entries'])), 'backends': backends,
            'integrity_negatives': negatives, 'results': results, 'collections': collections, 'rule_coverage': matrix,
            'iod_tool': {'status': 'executed', 'sha256': digest(args.dciodvfy), 'version_raw': subprocess.run([str(args.dciodvfy), '-version'], capture_output=True, text=True).stderr,
                         'executed': 2 * sum(e['iod_validator'] for e in manifest['entries'])} if args.dciodvfy else {'status': 'not-in-this-platform-scope'},
            'limitations': ['Synthetic data only; field acceptance pending', 'Attribute units and selected SC IOD diagnostics do not establish complete SC/CT/MR IOD or Annex E', 'Process adapters and independent IOD tool run only in the recorded platform scope'],
            'release_authorized': False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--record', type=Path, default=REPO / 'tmp/w1-conformance.json')
    parser.add_argument('--backends', default='native,js,wasm,wasm-gc')
    parser.add_argument('--dciodvfy', type=Path)
    args = parser.parse_args()
    record = run(args)
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: record[k] for k in ['status', 'executed', 'passed', 'failed', 'skipped', 'categories']}))


if __name__ == '__main__':
    main()
