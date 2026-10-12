#!/usr/bin/env python3
"""Signature/tamper/crash/partial-copy regression on synthetic release context."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from verify_with_pydicom import REPO
from verify_risk_gate import setup
from risk_gate import review_job
from private_store import StoreError, canonical
from attestation import initialize_signer, publish_job
from verify_delivery import DeliveryError, verify_package
from deliver_local import deliver


def rejected(operation):
    try:
        operation()
        raise AssertionError('invalid delivery accepted')
    except (StoreError, DeliveryError):
        pass


def main():
    os.umask(0o077)
    checks = []
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='p6-') as temp:
        root = Path(temp)
        workspace, _, _, job_id, registry, record = setup(root)
        signer, trust = root / 'signer', root / 'trust.json'
        initialize_signer(signer, trust)
        output = root / 'published'
        rejected(lambda: publish_job(workspace, job_id, output, registry, signer, trust))
        assert not output.exists()
        checks.append('unreviewed-data-cannot-be-signed-or-published')
        review_job(workspace, job_id, record, registry)
        # Kill after actual no-replace release rename and before PUBLISHED journal.
        code = 'import sys;sys.path.insert(0,"tools");from attestation import publish_job;publish_job(*sys.argv[1:],checkpoint=lambda e:(print("PUBLISH-WINDOW",flush=True),sys.stdin.read(1)) if e=="after-publication-before-journal" else None)'
        process = subprocess.Popen([sys.executable, '-c', code, str(workspace), job_id, str(output), str(registry), str(signer), str(trust)], cwd=REPO, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        line = process.stdout.readline().strip()
        assert line == 'PUBLISH-WINDOW', (line, process.stderr.read())
        process.kill()
        process.wait(timeout=10)
        assert process.returncode < 0 and output.exists()
        result = publish_job(workspace, job_id, output, registry, signer, trust)
        assert result['state'] == 'PUBLISHED'
        checks.append('SIGKILL-release-rename-before-journal-reconciles')
        verified = verify_package(output, trust, True)
        assert verified['objects'] == 4 and verified['context'] == 'synthetic'
        rejected(lambda: verify_package(output, trust))
        checks.append('independent-trusted-verify-and-default-synthetic-rejection')
        wrong_signer, wrong_trust = root / 'wrong-signer', root / 'wrong-trust.json'
        initialize_signer(wrong_signer, wrong_trust)
        rejected(lambda: verify_package(output, wrong_trust, True))
        checks.append('wrong-trust-key-rejected')
        attack = root / 'attack'
        shutil.copytree(output, attack)
        data = attack / 'object-1.dcm'
        data.write_bytes(data.read_bytes() + b'ALTERED')
        manifest = json.loads((attack / 'manifest.json').read_text())
        digest = hashlib.sha256(data.read_bytes()).hexdigest()
        manifest['objects'][0]['sha256'] = digest
        (attack / 'manifest.json').write_bytes(canonical(manifest))
        release = json.loads((attack / 'release.json').read_text())
        for entry in release['files']:
            if entry['file'] == 'object-1.dcm':
                entry['sha256'] = digest
            if entry['file'] == 'manifest.json':
                entry['sha256'] = hashlib.sha256((attack / 'manifest.json').read_bytes()).hexdigest()
        release['conversion_manifest_sha256'] = hashlib.sha256((attack / 'manifest.json').read_bytes()).hexdigest()
        (attack / 'release.json').write_bytes(canonical(release))
        rejected(lambda: verify_package(attack, trust, True))
        checks.append('simultaneous-data-and-both-manifest-tamper-rejected')
        inbox = root / 'inbox'
        inbox.mkdir(mode=0o700)
        class Interrupted(Exception):
            pass
        def interrupt(event):
            if event == 'file-verified':
                raise Interrupted()
        try:
            deliver(output, inbox, trust, 'synthetic-receiver', True, interrupt)
            raise AssertionError('interruption not injected')
        except Interrupted:
            pass
        assert not (inbox / verified['release_sha256']).exists()
        assert not list(inbox.glob('receipt-*.json'))
        receipt = deliver(output, inbox, trust, 'synthetic-receiver', True)
        assert receipt['status'] == 'complete' and receipt['objects_verified'] == 4
        assert deliver(output, inbox, trust, 'synthetic-receiver', True) == receipt
        checks.append('partial-directory-copy-not-successful-and-idempotent-retry-reverified')
        receipt_path = inbox / ('receipt-' + verified['release_sha256'] + '.json')
        receipt_path.unlink()
        assert deliver(output, inbox, trust, 'synthetic-receiver', True) == receipt
        checks.append('lost-local-receipt-reconstructed-after-full-verification')
        for path in output.iterdir():
            assert b'SECRET' not in path.read_bytes()
        checks.append('no-source-identifiers-in-public-package')
    record = {'schema': 1, 'fixture': 'synthetic context only; no real clinical release', 'checks': checks,
              'limitations': ['local POSIX controlled directory adapter', 'receipt acknowledges byte/signature verification, not PACS/clinical acceptance', 'out-of-band trusted-key/role distribution required', 'no physical power-loss certification']}
    (REPO / 'docs/evidence/p6-attestation.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'status': 'passed', 'checks': len(checks)}))


if __name__ == '__main__':
    main()
