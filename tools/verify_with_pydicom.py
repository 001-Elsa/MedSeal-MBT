#!/usr/bin/env python3
"""Independent interoperability and privacy-subset regression checks.

Only synthetic data is generated. pydicom is a development dependency.
Run with Python 3.10+ and pydicom==3.0.1; the workspace-local package directory
is discovered automatically when present.
"""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
LOCAL_PACKAGES = REPO.parent / "moonbit工具链" / "python-packages"
if LOCAL_PACKAGES.exists():
    sys.path.insert(0, str(LOCAL_PACKAGES))
import pydicom
from pydicom.dataset import Dataset, FileDataset, FileMetaDataset
from pydicom.sequence import Sequence
from pydicom.uid import ExplicitVRLittleEndian, SecondaryCaptureImageStorage


def invoke(*args, expect_success=True):
    local = REPO.parent / "moonbit工具链" / "bin" / "moon"
    launcher = str(REPO / "tools/moon-local") if local.exists() and sys.platform != "win32" else shutil.which("moon")
    if not launcher:
        raise RuntimeError("MoonBit is required; use the workspace toolchain or put moon on PATH")
    result = subprocess.run(
        [launcher, "run", "--target", "native", "cmd/main", "--", *map(str, args)],
        cwd=REPO, text=True, capture_output=True,
    )
    if expect_success and result.returncode:
        raise AssertionError(f"CLI failed: {result.stdout}\n{result.stderr}")
    if not expect_success:
        assert result.returncode != 0, "invalid operation unexpectedly succeeded"
    return result


def generate(root, count=16):
    root.mkdir()
    for i in range(count):
        patient = i % 2
        ordinal = i // 2
        study = ordinal // 4
        series = ordinal // 2
        sop = f"1.2.826.0.1.3680043.10.543.1.{i + 1}"
        meta = FileMetaDataset()
        meta.TransferSyntaxUID = ExplicitVRLittleEndian
        meta.MediaStorageSOPClassUID = SecondaryCaptureImageStorage
        meta.MediaStorageSOPInstanceUID = sop
        meta.ImplementationClassUID = "1.2.826.0.1.3680043.10.543.99"
        meta.SourceApplicationEntityTitle = "SOURCESECRET"
        meta.PrivateInformationCreatorUID = "1.2.826.0.1.3680043.10.543.98"
        meta.PrivateInformation = b"HEADER-SECRET"
        path = root / f"SECRET-patient-{patient}-{i}.dcm"
        ds = FileDataset(path, {}, file_meta=meta, preamble=b"S" * 128)
        ds.SpecificCharacterSet = "ISO_IR 192"
        ds.SOPClassUID = SecondaryCaptureImageStorage
        ds.SOPInstanceUID = sop
        ds.PatientName = f"合成^SECRET{patient}"
        ds.PatientID = f"SECRET-ID-{patient}"
        ds.IssuerOfPatientID = "SYNTHETIC-LAB"
        ds.PatientBirthDate = "19700101"
        ds.PatientSex = "O"
        ds.StudyInstanceUID = f"1.2.826.0.1.3680043.10.543.2.{patient + 1}.{study + 1}"
        ds.SeriesInstanceUID = f"1.2.826.0.1.3680043.10.543.3.{patient + 1}.{series + 1}"
        ds.FrameOfReferenceUID = f"1.2.826.0.1.3680043.10.543.4.{patient + 1}"
        date = dt.date(2024, 2, 28) + dt.timedelta(days=14 * ordinal)
        ds.StudyDate = date.strftime("%Y%m%d")
        ds.AcquisitionDate = ds.StudyDate
        ds.StudyDescription = f"SECRET-STUDY-{patient}"
        ds.SeriesDescription = "SECRET-SERIES"
        ds.InstitutionName = "SECRET-HOSPITAL"
        ds.Modality = "OT"
        ds.ImageComments = "合成编码验证"
        ds.Rows, ds.Columns = 2, 4
        ds.SamplesPerPixel = 1
        ds.PhotometricInterpretation = "MONOCHROME2"
        ds.BitsAllocated = ds.BitsStored = 8
        ds.HighBit = 7
        ds.PixelRepresentation = 0
        ds.PixelData = i.to_bytes(4, "little") + bytes((64, 128, 255, 0))
        ds.add_new((0x0011, 0x0010), "LO", "SECRET-CREATOR")
        ds.add_new((0x0011, 0x1010), "LO", "SECRET-PRIVATE")
        if ordinal:
            ref = Dataset()
            ref.ReferencedSOPClassUID = SecondaryCaptureImageStorage
            ref.ReferencedSOPInstanceUID = f"1.2.826.0.1.3680043.10.543.1.{i - 1}"
            ds.ReferencedImageSequence = Sequence([ref])
        nested = Dataset()
        nested.PatientName = "SECRET-NESTED"
        ds.RequestAttributesSequence = Sequence([nested])
        ds.save_as(path, enforce_file_format=True)


def check_outputs(source, output):
    inputs = {str(ds.SOPInstanceUID): ds for ds in map(pydicom.dcmread, sorted(source.glob("*.dcm")))}
    originals = sorted(source.glob("*.dcm"))
    manifest = json.loads((output / "manifest.json").read_text())
    assert manifest["status"] == "complete"
    assert manifest["pixels_inspected"] is False
    assert len(manifest["objects"]) == len(originals)
    uid_map, patient_map, patient_offsets = {}, {}, {}
    outputs = {}
    matched = set()
    for entry in manifest["objects"]:
        path = output / entry["file"]
        dst = pydicom.dcmread(path)
        # The generated pixel payload has a unique synthetic instance number.
        # Numbered output names deliberately do not encode source paths.
        ordinal = int.from_bytes(dst.PixelData[:4], "little")
        original = source / f"SECRET-patient-{ordinal % 2}-{ordinal}.dcm"
        assert original.exists() and ordinal not in matched
        matched.add(ordinal)
        src = pydicom.dcmread(original)
        outputs[str(dst.SOPInstanceUID)] = dst
        assert path.name.startswith("object-") and "SECRET" not in path.name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]
        audit = path.with_suffix(".audit.json").read_bytes()
        assert hashlib.sha256(audit).hexdigest() == entry["audit_sha256"]
        assert b"SECRET" not in audit and b"SECRET" not in (output / "manifest.json").read_bytes()
        assert dst.preamble == bytes(128)
        assert "SourceApplicationEntityTitle" not in dst.file_meta
        assert "PrivateInformation" not in dst.file_meta
        assert str(dst.file_meta.MediaStorageSOPInstanceUID) == str(dst.SOPInstanceUID)
        assert dst.SOPClassUID == src.SOPClassUID
        assert dst.ImageComments == src.ImageComments
        assert dst.file_meta.TransferSyntaxUID == ExplicitVRLittleEndian
        assert dst.PixelData == src.PixelData
        assert dst.PatientName == dst.PatientID
        assert not str(dst.PatientBirthDate)
        assert not str(dst.InstitutionName)
        assert not str(dst.StudyDescription) and not str(dst.SeriesDescription)
        assert not any(el.tag.is_private for el in dst.iterall())
        assert not any("SECRET" in str(el.value) for el in dst.iterall() if el.VR not in ("SQ", "OB", "OW"))
        original_patient, new_patient = str(src.PatientID), str(dst.PatientID)
        assert patient_map.setdefault(original_patient, new_patient) == new_patient
        delta = (dt.datetime.strptime(str(dst.StudyDate), "%Y%m%d") - dt.datetime.strptime(str(src.StudyDate), "%Y%m%d")).days
        assert 1 <= delta <= 30
        assert patient_offsets.setdefault(original_patient, delta) == delta
        assert dst.AcquisitionDate == dst.StudyDate
        for field in ("SOPInstanceUID", "StudyInstanceUID", "SeriesInstanceUID", "FrameOfReferenceUID"):
            old, new = str(getattr(src, field)), str(getattr(dst, field))
            assert new != old and new.startswith("2.25.") and len(new) <= 64
            assert uid_map.setdefault(old, new) == new
    assert len(set(patient_map.values())) == len(patient_map)
    assert len(matched) == len(originals)
    for ds in outputs.values():
        original_number = int.from_bytes(ds.PixelData[:4], "little")
        source_object = pydicom.dcmread(source / f"SECRET-patient-{original_number % 2}-{original_number}.dcm")
        source_refs = getattr(source_object, "ReferencedImageSequence", [])
        for ref in getattr(ds, "ReferencedImageSequence", []):
            target = outputs[str(ref.ReferencedSOPInstanceUID)]
            assert target.PatientID == ds.PatientID
            assert target.SOPClassUID == ref.ReferencedSOPClassUID
            assert str(ref.ReferencedSOPInstanceUID) == uid_map[str(source_refs[0].ReferencedSOPInstanceUID)]
    return {"objects": len(inputs), "patients": len(patient_map), "references": manifest["references"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=16)
    parser.add_argument("--record", type=Path)
    args = parser.parse_args()
    assert 2 <= args.count <= 10000
    (REPO / "tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pydicom-", dir=REPO / "tmp") as temporary:
        root = Path(temporary)
        source, output = root / "input", root / "output"
        generate(source, args.count)
        before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob("*.dcm")}
        preview = invoke("plan", source)
        assert "SECRET" not in preview.stdout
        start = time.monotonic()
        run = invoke("batch", source, "--output", output)
        elapsed = time.monotonic() - start
        assert "SECRET" not in run.stdout
        result = check_outputs(source, output)
        verified = invoke("verify", output)
        assert "integrity-and-structure-verified" in verified.stdout
        assert before == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob("*.dcm")}
        # Publication and checksum failure behavior through the actual CLI.
        invoke("batch", source, "--output", output, expect_success=False)
        manifest = json.loads((output / "manifest.json").read_text())
        path = output / manifest["objects"][0]["file"]
        altered = bytearray(path.read_bytes())
        altered[-1] ^= 1
        path.write_bytes(altered)
        invoke("verify", output, expect_success=False)
        result.update(pydicom=pydicom.__version__, cli_batch_seconds=round(elapsed, 4), synthetic_input_bytes=sum(p.stat().st_size for p in source.glob("*.dcm")), note="CLI duration includes cached MoonBit runner overhead; small synthetic pixels")
        if args.record:
            args.record.parent.mkdir(parents=True, exist_ok=True)
            args.record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
