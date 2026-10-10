#!/usr/bin/env python3
"""Independent strict-profile fixture and full-IOD checks on synthetic SC data."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile
from verify_with_pydicom import REPO, generate
import pydicom


def generate_strict(root, count=4):
    generate(root, count)
    for number, path in enumerate(sorted(root.glob("*.dcm")), 1):
        ds = pydicom.dcmread(path)
        ds.StudyTime = "123456"
        ds.ReferringPhysicianName = "SYNTHETIC^REFERRER"
        ds.StudyID = "SYNTHETIC"
        ds.AccessionNumber = "SYNTHETIC-ACCESS"
        ds.SeriesNumber = 1
        ds.InstanceNumber = number
        ds.PatientOrientation = ""
        ds.Laterality = ""
        ds.ConversionType = "WSD"
        ds.Manufacturer = "SYNTHETIC-MANUFACTURER"
        ds.LossyImageCompression = "00"
        # SC does not need the Frame of Reference module in this fixture.
        del ds.FrameOfReferenceUID
        ds.save_as(path, enforce_file_format=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, default=REPO / "_build/native/debug/build/cmd/main/main.exe")
    parser.add_argument("--validator", type=Path, default=REPO.parent / "moonbit工具链/dicom3tools-20260927/dciodvfy")
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    records = []
    (REPO / "tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="strict-profile-", dir=REPO / "tmp") as temporary:
        root = Path(temporary)
        source, output = root / "input", root / "output"
        generate_strict(source)
        def invoke(*command):
            result = subprocess.run([str(args.binary), *map(str, command)], cwd=REPO, capture_output=True, text=True)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            return result
        invoke("batch", source, "--output", output, "--policy", REPO / "examples/strict-policy.json")
        invoke("verify", output)
        for path in sorted(output.glob("*.dcm")):
            ds = pydicom.dcmread(path)
            assert not str(ds.ImageComments)
            assert "RequestAttributesSequence" not in ds
            assert not str(ds.PatientSex)
            assert not str(ds.StudyTime)
            assert not str(ds.ReferringPhysicianName)
            assert not any("SECRET" in str(e.value) for e in ds.iterall() if e.VR not in ("SQ", "OB", "OW"))
            assert list(ds.keys()) == sorted(ds.keys())
            checked = subprocess.run([str(args.validator), str(path)], capture_output=True, text=True)
            text = checked.stdout + checked.stderr
            errors = [line for line in text.splitlines() if line.startswith("Error")]
            warnings = [line for line in text.splitlines() if line.startswith("Warning")]
            records.append({"object": path.name, "exit_code": checked.returncode, "errors": errors, "warnings": warnings})
            if errors or checked.returncode:
                raise AssertionError(text)
        record = {"profile": "strict-v1", "fixture": "synthetic monochrome Secondary Capture; no CT/MR full-IOD claim",
                  "validator_sha256": hashlib.sha256(args.validator.read_bytes()).hexdigest(),
                  "manifest_sha256": hashlib.sha256((output / "manifest.json").read_bytes()).hexdigest(),
                  "objects": records, "release_authorized": False,
                  "note": "Passing declared synthetic IOD fixtures does not certify all inputs or pixel privacy"}
        args.record.parent.mkdir(parents=True, exist_ok=True)
        args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps(record, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
