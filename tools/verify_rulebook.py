#!/usr/bin/env python3
"""W0 index, execution, public output and native evidence API acceptance."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import os
import platform
import subprocess
import sys
import tempfile
import pydicom
from jsonschema import Draft202012Validator
from generate_rulebook import products
from verify_with_pydicom import REPO
from verify_strict_profile import generate_strict
from explanation_report import render
from evidence import code_identity
from moon_tokens import semantic_tokens


def catalog_check():
    catalog = json.loads((REPO / 'resources/rules/rulebook-v1.json').read_text(encoding='utf-8'))
    schema = json.loads((REPO / 'resources/rules/rulebook-v1.schema.json').read_text(encoding='utf-8'))
    Draft202012Validator(schema).validate(catalog)
    assert len({rule['id'] for rule in catalog['rules']}) == len(catalog['rules'])
    for rule in catalog['rules']:
        assert all((REPO / path).is_file() for path in rule['implementation'])
        text = (REPO / rule['test']).read_text(encoding='utf-8')
        assert rule['positive_case'] in text and rule['negative_case'] in text, rule['id']
    # Format is owned by moon fmt; semantic tokens are owned by the generator.
    normalize = semantic_tokens
    for path, expected in products().items():
        actual = path.read_text(encoding='utf-8')
        assert actual == expected if path.suffix == '.json' else normalize(actual) == normalize(expected), path
    return catalog


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--record', type=Path, default=REPO / 'tmp/w0-rulebook.json')
    parser.add_argument('--index-only', action='store_true')
    args = parser.parse_args()
    catalog = catalog_check()
    if args.index_only:
        print(json.dumps({'status': 'passed', 'catalog_rules': len(catalog['rules'])}))
        return
    # POSIX adapters are deliberately outside the portable catalog gate.
    from verify_risk_gate import setup
    from risk_gate import review_job
    from attestation import initialize_signer, publish_job
    binary = REPO / '_build/native/debug/build/cmd/main/main.exe'
    probe = REPO / '_build/native/debug/build/examples/authorization/authorization.exe'
    schema = json.loads((REPO / 'resources/rules/explanation-v1.schema.json').read_text(encoding='utf-8'))
    validator = Draft202012Validator(schema)
    checks, examples = [], []
    canaries = ['CANARY-NAME', 'CANARY-ID', 'CANARY-DESCRIPTION', 'CANARY-REPLACE',
                'CANARY-RULE', 'CANARY-SCOPE', 'CANARY-SOURCE', '20240228', '9.8.7.6.555666777']
    os.umask(0o077)
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='w0-') as temporary:
        root = Path(temporary)
        source = root / 'CANARY-SOURCE'
        generate_strict(source, 1)
        path = next(source.glob('*.dcm'))
        ds = pydicom.dcmread(path)
        ds.PatientName, ds.PatientID = 'CANARY-NAME^PRIVATE', 'CANARY-ID'
        ds.StudyDescription, ds.StudyDate = 'CANARY-DESCRIPTION', '20240228'
        ds.SOPInstanceUID = ds.file_meta.MediaStorageSOPInstanceUID = '9.8.7.6.555666777'
        ds.save_as(path, enforce_file_format=True)
        canaries += [str(path), hashlib.sha256(path.read_bytes()).hexdigest()]
        policy = {'version': 2, 'mode': 'strict', 'namespace': 'CANARY-SCOPE', 'date_shift_days': 30,
                  'path_rules': [{'id': 'CANARY-RULE', 'path': 'dataset/00081030', 'priority': 5,
                             'action': 'replace', 'value': 'CANARY-REPLACE',
                             'when_sop': '1.2.840.10008.5.1.4.1.1.7', 'when_present': '00280010'}]}
        # The public report renderer consumes only structural allowlisted fields.
        def explain(case, data, config, accepted):
            config_path = root / 'policy.json'
            config_path.write_text(json.dumps(config))
            data.save_as(path, enforce_file_format=True)
            proc = subprocess.run([str(binary), 'explain-object', str(path), '--policy', str(config_path)], capture_output=True, text=True, encoding='utf-8')
            report = json.loads(proc.stdout)
            assert (proc.returncode == 0) == accepted, (case, proc.stdout, proc.stderr)
            assert report['status'] == ('converted-explanation' if accepted else 'blocked')
            validator.validate(report)
            document, svg = render(report, catalog)
            public = proc.stdout + proc.stderr + document + svg
            assert not any(value in public for value in canaries), case
            assert '<script' not in document.lower() and 'javascript:' not in document.lower()
            assert not any(value in document for value in ('<img', '<iframe', 'onerror=', 'https://', 'http://'))
            examples.append({'id': case, 'report': report, 'html': document, 'svg': svg})
            return report
        # structure-remove-valid / structure-remove-invalid are covered by the
        # real converter and by refusal to emit an unsafe public decision.
        met = explain('condition-met', ds, policy, True)
        assert met['conditions'][0]['result'] == 'met'
        assert any(e['action'] == 'remove' for e in met['decisions'])
        not_met = copy.deepcopy(policy)
        not_met['path_rules'][0]['when_sop'] = '1.2.840.10008.5.1.4.1.1.4'
        absent = explain('condition-not-met', ds, not_met, True)
        assert absent['conditions'][0]['result'] == 'not-met'
        changed = copy.deepcopy(ds)
        changed.add_new(0x77760001, 'LO', 'CANARY-NAME')
        unknown = explain('unknown-field', changed, policy, False)
        assert unknown['issue']['rule_id'] == 'known-public-attribute'
        # policy-priority-valid / policy-priority-invalid: actual compiler rejects
        # equal-priority overlapping actions; replacement strings stay private.
        conflict = copy.deepcopy(policy)
        conflict['path_rules'].append({**conflict['path_rules'][0], 'id': 'other-rule', 'action': 'empty'})
        conflict['path_rules'][1].pop('value')
        explain('conflicting-configuration', ds, conflict, False)
        checks.extend(['four-schema-validated-examples', 'structure-remove-valid', 'structure-remove-invalid',
                       'policy-priority-valid', 'policy-priority-invalid', 'public-error-boundary-valid', 'public-error-boundary-invalid'])
        bad = copy.deepcopy(met)
        bad['decisions'][0]['path'] = 'dataset/<script onerror="CANARY-NAME">'
        try:
            render(bad, catalog)
            raise AssertionError('unsafe HTML input accepted')
        except ValueError:
            pass
        # Force a read error before parsing. CLI must not expose its local path.
        proc = subprocess.run([str(binary), 'explain-object', str(root / 'CANARY-SOURCE/missing.dcm')], capture_output=True, text=True, encoding='utf-8')
        assert proc.returncode != 0 and 'CANARY-SOURCE' not in proc.stdout + proc.stderr
        validator.validate(json.loads(proc.stdout))
        checks.append('public-json-html-svg-errors-logs-zero-canaries')
        (root / 'evidence-api').mkdir()
        workspace, _, _, job, registry, record = setup(root / 'evidence-api', 1)
        def evidence(mode, selected_root, identity, trust, expected):
            run = subprocess.run([str(probe), sys.executable, str(REPO / 'tools'), mode, str(selected_root), identity, str(trust)], capture_output=True, text=True, encoding='utf-8')
            assert (run.returncode == 0) == expected, (mode, run.stdout, run.stderr)
            assert not any(value in run.stdout + run.stderr for value in canaries)
        evidence('review', workspace, job, registry, False)
        review_job(workspace, job, record, registry)
        evidence('review', workspace, job, registry, True)
        signer, trust, published = root / 'signer', root / 'trust.json', root / 'published'
        initialize_signer(signer, trust)
        publish_job(workspace, job, published, registry, signer, trust)
        evidence('package', published, 'controlled', trust, False)
        evidence('package', published, 'synthetic-test', trust, True)
        (published / 'object-1.dcm').write_bytes(b'TAMPERED')
        evidence('package', published, 'synthetic-test', trust, False)
        registry.write_text('{"schema":1,"reviewers":[]}')
        evidence('review', workspace, job, registry, False)
        checks.append('native-types-revalidate-review-authority-synthetic-context-signature-and-payload')
    examples_root = REPO / 'docs/examples/rule-explanation'
    examples_root.mkdir(parents=True, exist_ok=True)
    for case in examples:
        for extension, contents in [('json', json.dumps(case['report'], ensure_ascii=False, indent=2) + '\n'), ('html', case['html']), ('svg', case['svg'])]:
            (examples_root / (case['id'] + '.' + extension)).write_text(contents, encoding='utf-8', newline='\n')
    record = {'schema': 1, 'stage': 'W0', 'scope': 'declared strict attribute and existing constraint subset; synthetic data only',
              **code_identity(REPO),
              'platform': platform.platform(), 'python': platform.python_version(), 'pydicom': pydicom.__version__,
              'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
              'rulebook_sha256': hashlib.sha256((REPO / 'resources/rules/rulebook-v1.json').read_bytes()).hexdigest(),
              'rules': len(catalog['rules']), 'checks': checks, 'examples_executed': len(examples), 'canary_occurrences': 0,
              'limitations': ['not complete SC/CT/MR IOD or Annex E', 'native evidence provider is trusted administrator configuration', 'no real source, pixel clearance or field acceptance'],
              'release_authorized': False}
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'status': 'passed', 'rules': record['rules'], 'examples': len(examples), 'checks': len(checks)}))


if __name__ == '__main__':
    main()
