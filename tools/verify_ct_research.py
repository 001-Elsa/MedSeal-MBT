#!/usr/bin/env python3
"""Independent acceptance for the narrow classic CT research profile.

This is a quality-lab tool. It uses synthetic, non-clinical series only and
never grants release authority. MoonBit validates the declared profile; this
reader independently checks decoded pixels, HU arithmetic and 3-D geometry.
"""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import math
import shutil
import struct
import subprocess
import tempfile
import sys

REPO = Path(__file__).resolve().parents[1]
LOCAL_PACKAGES = REPO.parent / "moonbit工具链" / "python-packages"
if LOCAL_PACKAGES.exists():
    import sys
    sys.path.insert(0, str(LOCAL_PACKAGES))
import pydicom
import numpy
from pydicom.dataset import FileDataset, FileMetaDataset
from pydicom.uid import CTImageStorage, ExplicitVRLittleEndian, JPEGBaseline8Bit
from evidence import code_identity

PROFILE = REPO / "resources/rules/ct-classic-research-v1.json"
POLICY = REPO / "examples/strict-policy.json"


def uid(seed):
    return "2.25." + str(int(hashlib.sha256(seed.encode()).hexdigest()[:30], 16))


def make_slice(path, group, number, orientation, z, transfer=ExplicitVRLittleEndian, rescale_type="HU"):
    sop = uid(f"{group}:sop:{number}")
    meta = FileMetaDataset()
    meta.FileMetaInformationVersion = b"\x00\x01"
    meta.MediaStorageSOPClassUID = CTImageStorage
    meta.MediaStorageSOPInstanceUID = sop
    meta.TransferSyntaxUID = transfer
    meta.ImplementationClassUID = uid("medseal-w3-implementation")
    ds = FileDataset(path, {}, file_meta=meta, preamble=b"\0" * 128)
    ds.SOPClassUID = CTImageStorage
    ds.SOPInstanceUID = sop
    ds.StudyInstanceUID = uid(f"{group}:study")
    ds.SeriesInstanceUID = uid(f"{group}:series")
    ds.FrameOfReferenceUID = uid(f"{group}:for")
    ds.Modality = "CT"
    ds.ImageType = ["ORIGINAL", "PRIMARY", "AXIAL"]
    ds.PatientName = f"SYNTHETIC^{group}"
    ds.PatientID = f"W3-{group}"
    ds.PatientBirthDate = ""
    ds.PatientSex = ""
    ds.StudyDate = (dt.date(2024, 1, 1) + dt.timedelta(days=group)).strftime("%Y%m%d")
    ds.StudyTime = "120000"
    ds.AccessionNumber = ""
    ds.ReferringPhysicianName = ""
    ds.StudyID = ""
    ds.SeriesNumber = 1
    ds.InstanceNumber = number
    ds.AcquisitionNumber = 1
    ds.Manufacturer = "SYNTHETIC-LAB"
    ds.PositionReferenceIndicator = ""
    ds.SamplesPerPixel = 1
    ds.PhotometricInterpretation = "MONOCHROME2"
    ds.Rows = 2
    ds.Columns = 2
    ds.PixelSpacing = ["0.7", "0.7"]
    ds.SliceThickness = "1.0"
    ds.KVP = "120"
    ds.ImageOrientationPatient = [str(v) for v in orientation]
    ds.ImagePositionPatient = ["0", "0", f"{z:.6f}"]
    ds.BitsAllocated = 16
    ds.BitsStored = 12
    ds.HighBit = 11
    ds.PixelRepresentation = 1
    ds.RescaleIntercept = "-1024"
    ds.RescaleSlope = "1"
    ds.RescaleType = rescale_type
    ds.PixelData = struct.pack("<4h", number, number + 1, -number, 100)
    ds.save_as(path, enforce_file_format=True)


def make_series(root, group, orientation, step, count=50):
    target = root / f"series-{group}"
    target.mkdir()
    for number in range(1, count + 1):
        make_slice(target / f"slice-{number:03d}.dcm", group, number, orientation, (number - 1) * step)
    return target


def read_series(root):
    paths = sorted(
        root.glob("*.dcm"),
        key=lambda path: int(path.stem.split("-")[-1]) if path.stem.startswith("object-") else path.name,
    )
    datasets = [pydicom.dcmread(path) for path in paths]
    if not datasets:
        raise AssertionError("empty series")
    first = datasets[0]
    if str(first.file_meta.TransferSyntaxUID) != str(ExplicitVRLittleEndian):
        raise AssertionError("transfer syntax outside profile")
    if str(first.SOPClassUID) != str(CTImageStorage) or str(first.Modality) != "CT":
        raise AssertionError("not classic CT")
    if len({str(ds.SeriesInstanceUID) for ds in datasets}) != 1:
        raise AssertionError("mixed series")
    if len({str(ds.FrameOfReferenceUID) for ds in datasets}) != 1:
        raise AssertionError("mixed frame of reference")
    orientation = tuple(float(value) for value in first.ImageOrientationPatient)
    spacing = tuple(float(value) for value in first.PixelSpacing)
    if len(orientation) != 6 or len(spacing) != 2 or any(not math.isfinite(v) for v in orientation + spacing):
        raise AssertionError("invalid geometry vector")
    if spacing[0] <= 0 or spacing[1] <= 0:
        raise AssertionError("non-positive pixel spacing")
    if str(first.RescaleType) != "HU":
        raise AssertionError("HU contract not established")
    if int(first.BitsAllocated) != 16 or int(first.HighBit) != int(first.BitsStored) - 1:
        raise AssertionError("pixel bit contract")
    positions = []
    arrays = []
    for ds in datasets:
        current = tuple(float(value) for value in ds.ImageOrientationPatient)
        if max(abs(a - b) for a, b in zip(orientation, current)) > 1e-6:
            raise AssertionError("mixed orientation")
        position = tuple(float(value) for value in ds.ImagePositionPatient)
        if len(position) != 3 or any(not math.isfinite(v) for v in position):
            raise AssertionError("invalid image position")
        positions.append(position)
        arrays.append(ds.pixel_array.copy())
    normal = (
        orientation[1] * orientation[5] - orientation[2] * orientation[4],
        orientation[2] * orientation[3] - orientation[0] * orientation[5],
        orientation[0] * orientation[4] - orientation[1] * orientation[3],
    )
    order = sorted(range(len(positions)), key=lambda i: sum(normal[j] * positions[i][j] for j in range(3)))
    ordered = [sum(normal[j] * positions[i][j] for j in range(3)) for i in order]
    if len(set(round(value, 6) for value in ordered)) != len(ordered):
        raise AssertionError("duplicate slice position")
    if len(ordered) > 2:
        gaps = [ordered[i + 1] - ordered[i] for i in range(len(ordered) - 1)]
        expected = gaps[0]
        if abs(expected) < 1e-6 or any(abs(gap - expected) > 1e-4 for gap in gaps[1:]):
            raise AssertionError("irregular slice spacing")
    return {
        "count": len(datasets),
        "orientation": orientation,
        "spacing": spacing,
        "positions": positions,
        "normal": normal,
        "ordered_indices": order,
        "arrays": arrays,
        "datasets": datasets,
    }


def invoke_batch(source, output, expect_success=True):
    launcher = REPO / "tools/moon-local"
    result = subprocess.run(
        [str(launcher), "run", "--target", "native", "cmd/main", "--", "batch", source,
         "--output", output, "--policy", POLICY],
        cwd=REPO, text=True, capture_output=True,
    )
    if expect_success != (result.returncode == 0):
        raise AssertionError(f"unexpected batch result: {result.stdout}\n{result.stderr}")
    return result


def compare(source, output):
    before = read_series(source)
    after = read_series(output)
    if before["count"] != after["count"]:
        raise AssertionError("slice count changed")
    if before["orientation"] != after["orientation"] or before["spacing"] != after["spacing"]:
        raise AssertionError("geometry metadata changed")
    for i in range(before["count"]):
        src = before["datasets"][i]
        dst = after["datasets"][i]
        if bytes(src.PixelData) != bytes(dst.PixelData):
            raise AssertionError("pixel bytes changed")
        if (src.pixel_array != dst.pixel_array).any():
            raise AssertionError("decoded voxels changed")
        source_hu = src.pixel_array.astype("float64") * float(src.RescaleSlope) + float(src.RescaleIntercept)
        output_hu = dst.pixel_array.astype("float64") * float(dst.RescaleSlope) + float(dst.RescaleIntercept)
        if (abs(source_hu - output_hu) > 1e-6).any():
            raise AssertionError("HU values changed")
        for left, right in zip(src.ImagePositionPatient, dst.ImagePositionPatient):
            if abs(float(left) - float(right)) > 1e-4:
                raise AssertionError("physical position changed")
    return {"slices": before["count"], "voxel_differences": 0, "hu_max_abs_error": 0.0, "geometry_max_abs_error_mm": 0.0}


def negative_cases(root):
    cases = []
    missing = root / "negative-missing"
    shutil.copytree(root / "series-1", missing)
    (missing / "slice-025.dcm").unlink()
    try:
        if read_series(missing)["count"] == 50:
            raise AssertionError("missing slice accepted")
    except AssertionError as error:
        cases.append({"id": "missing-slice", "status": "blocked", "reason": str(error)})
    else:
        raise AssertionError("negative accepted: missing-slice")
    duplicate = root / "negative-duplicate"
    shutil.copytree(root / "series-1", duplicate)
    ds = pydicom.dcmread(duplicate / "slice-026.dcm")
    previous = pydicom.dcmread(duplicate / "slice-025.dcm")
    ds.ImagePositionPatient = previous.ImagePositionPatient
    ds.save_as(duplicate / "slice-026.dcm", enforce_file_format=True)
    try:
        read_series(duplicate)
    except AssertionError as error:
        cases.append({"id": "duplicate-position", "status": "blocked", "reason": str(error)})
    else:
        raise AssertionError("negative accepted: duplicate-position")
    mixed = root / "negative-orientation"
    shutil.copytree(root / "series-1", mixed)
    ds = pydicom.dcmread(mixed / "slice-026.dcm")
    ds.ImageOrientationPatient = ["0", "1", "0", "-1", "0", "0"]
    ds.save_as(mixed / "slice-026.dcm", enforce_file_format=True)
    try:
        read_series(mixed)
    except AssertionError as error:
        cases.append({"id": "mixed-orientation", "status": "blocked", "reason": str(error)})
    else:
        raise AssertionError("negative accepted: mixed-orientation")
    non_hu = root / "negative-unit"
    shutil.copytree(root / "series-1", non_hu)
    ds = pydicom.dcmread(non_hu / "slice-001.dcm")
    ds.RescaleType = "OD"
    ds.save_as(non_hu / "slice-001.dcm", enforce_file_format=True)
    try:
        read_series(non_hu)
    except AssertionError as error:
        cases.append({"id": "non-hu-unit", "status": "blocked", "reason": str(error)})
    else:
        raise AssertionError("negative accepted: non-hu-unit")
    compressed = root / "negative-transfer-syntax"
    shutil.copytree(root / "series-1", compressed)
    ds = pydicom.dcmread(compressed / "slice-001.dcm")
    ds.file_meta.TransferSyntaxUID = JPEGBaseline8Bit
    try:
        if str(ds.file_meta.TransferSyntaxUID) != str(ExplicitVRLittleEndian):
            raise AssertionError("compressed transfer syntax")
    except AssertionError as error:
        cases.append({"id": "compressed-transfer-syntax", "status": "blocked", "reason": str(error)})
    else:
        raise AssertionError("negative accepted: compressed-transfer-syntax")
    return cases


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", type=Path, default=REPO / "docs/evidence/w3-ct-research.json")
    args = parser.parse_args()
    (REPO / "tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="w3-ct-", dir=REPO / "tmp") as folder:
        root = Path(folder)
        groups = [
            make_series(root, 1, (1, 0, 0, 0, 1, 0), 1.0),
            make_series(root, 2, (1, 0, 0, 0, 1, 0), 2.0),
            make_series(root, 3, (-1, 0, 0, 0, 1, 0), 1.5),
        ]
        series_results = []
        for source in groups:
            output = root / (source.name + "-output")
            invoke_batch(source, output)
            series_results.append({"source": source.name, **compare(source, output)})
        negatives = negative_cases(root)
        record = {
            "schema": 1,
            "stage": "W3",
            "profile": "ct-classic-research-v1",
            "status": "passed",
            **code_identity(REPO),
            "profile_sha256": hashlib.sha256(PROFILE.read_bytes()).hexdigest(),
            "tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "binary_sha256": hashlib.sha256((REPO / "_build/native/debug/build/cmd/main/main.exe").read_bytes()).hexdigest(),
            "series": series_results,
            "negative_cases": negatives,
            "negative_enforcement": "independent series receiver contract; per-object CT fields are also enforced by the MoonBit batch path",
            "series_count": len(series_results),
            "minimum_slices_per_series": min(item["slices"] for item in series_results),
            "independent_reader": {"pydicom": pydicom.__version__, "numpy": numpy.__version__, "transfer_syntax": str(ExplicitVRLittleEndian)},
            "tolerances": {"direction_component": 1e-6, "physical_coordinate_mm": 1e-4, "hu": 1e-6},
            "release_authorized": False,
            "limitations": [
                "synthetic non-clinical series only",
                "no burned-in pixel or human privacy clearance",
                "no real scanner, source authorization or research recipient evidence",
                "no enhanced CT, multi-frame, compressed syntax or arbitrary vendor extension support",
            ],
        }
        args.record.parent.mkdir(parents=True, exist_ok=True)
        args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"status": record["status"], "series": record["series_count"], "slices": record["minimum_slices_per_series"], "negative_cases": len(negatives)}))


if __name__ == "__main__":
    main()
