#!/usr/bin/env python3
"""Synthetic review fixtures are tests, never clinical authorization."""
from pathlib import Path
import copy
import datetime
import hashlib
import json
import os
import tempfile
from verify_with_pydicom import REPO
from verify_strict_profile import generate_strict
from private_store import initialize, canonical, StoreError, write_exclusive
from enterprise_job import create_job, run_job, status_job
from risk_gate import risk_inventory, review_job, gate, VISUAL_RISKS, review_binding


def synthetic_review(job, reviewer='synthetic-test-reviewer', binding=None):
    _, inventory = risk_inventory(job)
    return {'schema': 2, 'context': 'synthetic', 'reviewer': reviewer, 'reviewed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'recipient_accepts_declared_subset': True, 'bindings': review_binding(job) if binding is None else binding,
            'records': [{'file': entry['file'], 'sha256': entry['sha256'], 'policy_sha256': entry['policy_sha256'], 'decisions': [
                {'risk': risk, 'action': 'human-reviewed-clear' if risk in VISUAL_RISKS else 'recipient-accepted-subset', 'evidence_sha256': hashlib.sha256(b'SYNTHETIC TEST REVIEW ONLY').hexdigest()} for risk in entry['risks']]} for entry in inventory]}


def setup(root, count=4):
    workspace = root / 'jobs'
    workspace.mkdir(mode=0o700)
    store, source = root / 'store', root / 'source'
    initialize(store)
    generate_strict(source, count)
    job_id = create_job(workspace, source, REPO / 'examples/strict-policy.json', store, 'synthetic-lab')
    run_job(workspace, job_id)
    registry = root / 'reviewers.json'
    write_exclusive(registry, canonical({'schema': 1, 'reviewers': [{'id': 'synthetic-test-reviewer', 'contexts': ['synthetic'], 'roles': ['pixel-review', 'metadata-scope']}]}))
    record = root / 'record.json'
    write_exclusive(record, canonical(synthetic_review(workspace / job_id)))
    return workspace, store, source, job_id, registry, record


def main():
    os.umask(0o077)
    checks = []
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='p5-') as temp:
        root = Path(temp)
        workspace, _, _, job_id, registry, record = setup(root)
        job = workspace / job_id
        try:
            gate(job, registry)
            raise AssertionError('unreviewed data authorized')
        except (StoreError, FileNotFoundError):
            pass
        checks.append('unreviewed-output-blocked')
        original = json.loads(record.read_bytes())
        def reject(review):
            record.write_bytes(canonical(review))
            try:
                review_job(workspace, job_id, record, registry)
                raise AssertionError('invalid review accepted')
            except StoreError:
                pass
            assert status_job(workspace, job_id)['state'] == 'AWAITING_REVIEW'
        missing = copy.deepcopy(original)
        missing['records'][0]['decisions'].pop()
        reject(missing)
        unauthorized = copy.deepcopy(original)
        unauthorized['reviewer'] = 'not-authorized'
        reject(unauthorized)
        ocr = copy.deepcopy(original)
        ocr['records'][0]['decisions'][0]['action'] = 'ocr-negative'
        reject(ocr)
        wrong = copy.deepcopy(original)
        wrong['records'][0]['sha256'] = '0' * 64
        reject(wrong)
        checks.append('coverage-authority-OCR-negative-and-output-binding-rejected')
        record.write_bytes(canonical(original))
        assert review_job(workspace, job_id, record, registry)['state'] == 'READY'
        assert gate(job, registry)[3]['record']['context'] == 'synthetic'
        checks.append('complete-synthetic-record-only-enables-ready-state')
        registry.write_bytes(canonical({'schema': 1, 'reviewers': []}))
        try:
            gate(job, registry)
            raise AssertionError('revoked registry accepted')
        except StoreError:
            pass
        checks.append('review-authority-change-invalidates-gate')
    result = {'schema': 1, 'fixture': 'synthetic test records; no real patient visual review performed', 'checks': checks,
              'limitations': ['local single-owner reviewer registry, not multi-user identity authentication', 'external human evidence authenticity and image usability require field responsibility', 'no pixel rewriting or automatic OCR clearance']}
    (REPO / 'docs/evidence/p5-risk-gate.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'status': 'passed', 'checks': len(checks)}))


if __name__ == '__main__':
    main()
