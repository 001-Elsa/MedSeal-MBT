#!/usr/bin/env python3
"""Run a real local Orthanc REST round-trip against synthetic CT output."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import signal
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

from verify_ct_research import make_series, read_series, REPO
from orthanc_receiver import Orthanc, ReceiverError, deliver


def wait_ready(receiver, process):
    for _ in range(100):
        if process.poll() is not None:
            raise RuntimeError("owned Orthanc exited before ready")
        try:
            system = receiver.check()
            if system.get("Name") != "MedSeal V3 synthetic receiver":
                raise RuntimeError("unexpected receiver identity")
            return system
        except ReceiverError:
            time.sleep(0.1)
    raise RuntimeError("Orthanc did not become ready")


def semantics(left, right):
    import numpy
    assert str(left.SOPInstanceUID) == str(right.SOPInstanceUID)
    assert str(left.StudyInstanceUID) == str(right.StudyInstanceUID)
    assert str(left.SeriesInstanceUID) == str(right.SeriesInstanceUID)
    assert bytes(left.PixelData) == bytes(right.PixelData)
    assert numpy.array_equal(left.pixel_array, right.pixel_array)
    assert tuple(left.ImagePositionPatient) == tuple(right.ImagePositionPatient)
    assert tuple(left.ImageOrientationPatient) == tuple(right.ImageOrientationPatient)
    assert tuple(left.PixelSpacing) == tuple(right.PixelSpacing)
    assert numpy.array_equal(left.pixel_array.astype('float64') * float(left.RescaleSlope) + float(left.RescaleIntercept), right.pixel_array.astype('float64') * float(right.RescaleSlope) + float(right.RescaleIntercept))


def run(record, orthanc, version):
    import socket
    import pydicom
    from enterprise_job import create_job, run_job
    from private_store import initialize, canonical, write_exclusive
    from verify_risk_gate import synthetic_review
    from risk_gate import review_job
    from attestation import initialize_signer, publish_job
    with tempfile.TemporaryDirectory(prefix="medseal-v3-") as folder:
        root = Path(folder).resolve()
        source = make_series(root, 7, (1, 0, 0, 0, 1, 0), 1.0, count=3)
        workspace = root / 'jobs'; workspace.mkdir(mode=0o700)
        store = root / 'store'; initialize(store)
        job_id = create_job(workspace, source, REPO / 'examples/strict-policy.json', store, 'synthetic-v3')
        run_job(workspace, job_id)
        job = workspace / job_id
        output = job / 'converted'
        reviewers = root / 'reviewers.json'
        write_exclusive(reviewers, canonical({'schema':1,'reviewers':[{'id':'synthetic-test-reviewer','contexts':['synthetic'],'roles':['pixel-review','metadata-scope']}]}))
        review = root / 'review.json'; write_exclusive(review, canonical(synthetic_review(job)))
        review_job(workspace, job_id, review, reviewers)
        signer = root / 'signer'; trust = root / 'trust.json'
        initialize_signer(signer, trust)
        package = root / 'signed-synthetic'
        publish_job(workspace, job_id, package, reviewers, signer, trust)
        # Reserve an unused loopback port. Never connect to or overwrite a user's
        # pre-existing Orthanc. The owned process and unique Name are checked.
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            port = listener.getsockname()[1]
        base = f'http://127.0.0.1:{port}'
        receiver = Orthanc(base, version)
        config = root / "orthanc.json"
        config.write_text(json.dumps({"Name":"MedSeal V3 synthetic receiver", "StorageDirectory":str(root/'storage'),
            "RemoteAccessAllowed":False,"AuthenticationEnabled":False,"HttpPort":port,
            "HttpBindAddress":"127.0.0.1", "DicomServerEnabled":False,"Plugins":[],"LuaScripts":[],"OverwriteInstances":False}))
        process = None
        def start():
            nonlocal process
            process = subprocess.Popen([str(orthanc), str(config)], cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return wait_ready(receiver, process)
        def stop():
            if process is not None and process.poll() is None:
                process.terminate(); process.wait(timeout=10)
        try:
            system = start()
            first = deliver(package, trust, base, version, True)
            assert first['status'] == 'receiver-stored' and first['objects'] == 3
            second = deliver(package, trust, base, version, True)
            assert second['status'] == 'receiver-stored' and second['already_stored'] == 3
            assert len(receiver.json('GET','/studies')) == 1
            instances = receiver.json('GET','/instances'); assert len(instances) == 3
            try:
                receiver.upload(b'not-a-dicom')
            except ReceiverError as error:
                assert str(error) == 'receiver-rejected'
            else:
                raise AssertionError('malformed DICOM stored')
            assert len(receiver.json('GET','/instances')) == 3
            roundtrip = root / 'roundtrip'; roundtrip.mkdir()
            for number, identity in enumerate(instances):
                (roundtrip / f'object-{number:03d}.dcm').write_bytes(receiver.file(identity))
            before = read_series(output); after = read_series(roundtrip)
            by_uid = {str(ds.SOPInstanceUID):ds for ds in after['datasets']}
            for left in before['datasets']:
                semantics(left, by_uid[str(left.SOPInstanceUID)])
            stop()
            try:
                receiver.check()
            except ReceiverError as error:
                assert str(error) == 'transport-retryable'
            else:
                raise AssertionError('disconnected transport claimed success')
            start()
            retried = deliver(package, trust, base, version, True)
            assert retried['status'] == 'receiver-stored' and retried['already_stored'] == 3
            assert len(receiver.json('GET','/instances')) == 3
            # Receiver refuses a signed package modified after approval.
            target = next(package.glob('*.dcm')); target.chmod(0o600); target.write_bytes(b'tampered')
            try:
                deliver(package, trust, base, version, True)
            except Exception:
                pass
            else:
                raise AssertionError('tampered signed package accepted')
            assert len(receiver.json('GET','/instances')) == 3
            result = {'schema':1,'status':'passed','stage':'V3','orthanc_version':system['Version'],
                'orthanc_sha256':hashlib.sha256(orthanc.read_bytes()).hexdigest(), 'objects':3,
                'checks':['actual-owned-Orthanc','signed-package-before-upload','duplicate-idempotence',
                    'study-and-instance-query','retrieval-by-SOP-identity','pixel-voxel-HU-geometry-preserved',
                    'malformed-upload-refused','disconnect-retryable','restart-persistence-and-retry',
                    'tampered-package-before-upload-refused'], 'release_authorized':False,'synthetic_only':True,
                'limitations':['loopback REST only; not complete DICOMweb','not clinical/PACS/real-source acceptance',
                    'upload batch is not atomic; retries reverify signed source']}
            record.parent.mkdir(parents=True,exist_ok=True)
            record.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
            print(json.dumps(result,ensure_ascii=False))
        finally:
            stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--orthanc", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--record", type=Path, default=REPO / "tmp/v3-orthanc-ci.json")
    args = parser.parse_args()
    run(args.record, args.orthanc.resolve(strict=True), args.version)
