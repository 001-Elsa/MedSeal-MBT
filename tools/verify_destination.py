#!/usr/bin/env python3
"""W2 end-to-end destination binding and historical witness regression."""
from pathlib import Path
import json
import tempfile
from verify_strict_profile import generate_strict
from private_store import initialize, canonical, write_exclusive, StoreError
from enterprise_job import create_job, run_job
from verify_risk_gate import synthetic_review, REPO
from risk_gate import review_job
from attestation import initialize_signer, publish_job
from history_outbox import initialize_destination, deliver_job, resolve_history


def main():
    checks = []
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='w2-destination-') as folder:
        root = Path(folder)
        workspace = root / 'jobs'; workspace.mkdir(mode=0o700)
        source = root / 'source'; generate_strict(source, 1)
        store = root / 'store'; initialize(store)
        destination = root / 'destination'; destination.mkdir(mode=0o700)
        marker = initialize_destination(destination, 'synthetic-receiver')
        signer, trust = root / 'signer', root / 'trust.json'
        initialize_signer(signer, trust)
        reviewers = root / 'reviewers.json'
        write_exclusive(reviewers, canonical({'schema': 1, 'reviewers': [{'id': 'synthetic-test-reviewer', 'contexts': ['synthetic'], 'roles': ['pixel-review', 'metadata-scope']}]}))
        config = {'schema': 1, 'root': str(destination), 'id': marker['id'], 'receiver_id': 'synthetic-receiver', 'trust': str(trust), 'reviewers': str(reviewers), 'allow_synthetic': True}
        job_id = create_job(workspace, source, REPO / 'examples/strict-policy.json', store, 'synthetic-lab', destination_config=config)
        run_job(workspace, job_id)
        job = workspace / job_id
        record = root / 'review.json'
        write_exclusive(record, canonical(synthetic_review(job)))
        review_job(workspace, job_id, record, reviewers)
        package = root / 'package'
        publish_job(workspace, job_id, package, reviewers, signer, trust)
        first = deliver_job(workspace, job_id, package)
        assert first['status'] == 'complete'
        second = deliver_job(workspace, job_id, package)
        assert second['status'] == 'complete'
        checks.append('destination-identity-signed-review-bound-and-idempotently-delivered')
        identities = json.loads((job / 'working.checkpoints/identities.checkpoint.json').read_text())
        descriptor = identities['objects'][0]
        request = {'schema': 1, 'namespace': identities['namespace'], 'policy_sha256': identities['policy_sha256'], 'rulebook_sha256': identities['rulebook_sha256'], 'program_sha256': identities['program_sha256'], 'destination': config, 'references': [{'source_uid': descriptor['source_uid'], 'owner_key': descriptor['owner_key'], 'sop_class': descriptor['sop_class']}]}
        resolved = resolve_history(store, request, 'synthetic-lab')
        assert resolved['entries'][0]['mapped_uid']
        checks.append('historical-reference-resolves-only-after-acknowledged-target-revalidation')
        blob = next((destination / 'objects').glob('*.dcm'))
        blob.write_bytes(b'tampered')
        try:
            deliver_job(workspace, job_id, package)
            raise AssertionError('tampered acknowledged object accepted')
        except StoreError:
            pass
        checks.append('tampered-deduplicated-target-rejected-even-with-acknowledged-ledger-state')
        blob.write_bytes(next(package.glob('*.dcm')).read_bytes())
        receipt = next((destination / 'receipts').glob('*.json'))
        receipt.unlink()
        assert deliver_job(workspace, job_id, package)['status'] == 'complete'
        checks.append('missing-receipt-rebuilt-after-byte-reverification')
    record = {'schema': 1, 'stage': 'W2', 'status': 'passed', 'checks': checks, 'release_authorized': False, 'limitations': ['synthetic source and reviewer only', 'controlled local POSIX destination', 'remote PACS exactly-once and clinical acceptance remain separate field gates']}
    (REPO / 'docs/evidence/w2-destination.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'status': 'passed', 'checks': len(checks)}))


if __name__ == '__main__':
    main()
