#!/usr/bin/env python3
"""Independent synthetic pydicom <-> MoonBit DICOM JSON acceptance.

Uses the real exported MoonBit JS API, never a Python reimplementation of it.
Only the fixed synthetic datasets below may enter this verifier's diagnostics.
"""
from pathlib import Path
from decimal import Decimal
import argparse
import hashlib
import io
import json
import os
import shutil
import subprocess

import pydicom
from pydicom.dataset import Dataset, FileDataset, FileMetaDataset
from pydicom.sequence import Sequence
from pydicom.uid import ExplicitVRLittleEndian, SecondaryCaptureImageStorage
from verify_consumer import REPO, moon_binary


def fixture():
    ds = Dataset()
    ds.SpecificCharacterSet = "ISO_IR 192"
    ds.SOPClassUID = SecondaryCaptureImageStorage
    ds.SOPInstanceUID = "1.2.826.0.1.999.345"
    ds.PatientName = "SYNTHETIC^JSON=合成^测试=HECHENG^CESHI"
    ds.PatientID = ["SYNTHETIC-A", "", "SYNTHETIC-B", ""]
    ds.PixelData = bytes([1, 2, 3, 4])
    ds[0x7FE00010].VR = "OB"
    values = {
        "AE": ["SYNTHETIC", "TEST"], "AS": "023Y", "CS": ["A", "B"],
        "DA": "20240229", "DS": ["1.2300", "-0.125"],
        "DT": "20240229123000.123456+0800", "IS": ["-1", "2147483647"],
        "LO": ["ONE", "", "TWO"], "LT": "one\\two", "PN": "=汉^字=HAN^ZI",
        "SH": ["ONE", "TWO"], "ST": "one\\two", "TM": "123000.123456",
        "UC": ["长文本", "NEXT"], "UI": "1.2.826.0.1.999.4",
        "UR": "https://example.invalid/synthetic", "UT": "long\\text",
        "US": [0, 65535], "SS": [-32768, 32767],
        "UL": [0, 4294967295], "SL": [-2147483648, 2147483647],
        "OB": b"\x00\x01\x02\x03", "OW": b"\x01\x00\xff\x7f", "UN": b"\x02\x03",
    }
    for index, (vr, value) in enumerate(values.items()):
        ds.add_new(0x00111000 + index, vr, value)
    item = Dataset()
    item.ReferencedSOPClassUID = SecondaryCaptureImageStorage
    item.ReferencedSOPInstanceUID = "1.2.826.0.1.999.346"
    ds.ReferencedImageSequence = Sequence([Dataset(), item])
    ds.add_new(0x00112000, "SQ", Sequence([]))
    ds.add_new(0x00112001, "LO", "")
    ds.add_new(0x00112002, "US", None)
    return ds


def signature(ds):
    result = []
    for element in ds:
        value = element.value
        if element.VR == "SQ":
            normalized = tuple(signature(item) for item in value)
        elif isinstance(value, bytes):
            normalized = value.hex()
        elif value is None or value == "":
            normalized = ()
        else:
            parts = list(value) if element.VM > 1 else [value]
            if element.VR == "DS":
                normalized = tuple(Decimal(str(v)) for v in parts)
            elif element.VR in ("IS", "US", "SS", "UL", "SL"):
                normalized = tuple(int(v) for v in parts)
            else:
                normalized = tuple(str(v) for v in parts)
        result.append((int(element.tag), element.VR, normalized))
    return tuple(result)


def run(record):
    moon = moon_binary()
    env = dict(os.environ, MOON_HOME=str(moon.parent.parent))
    node_dir = Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin"
    env["PATH"] = str(node_dir) + os.pathsep + env.get("PATH", "")
    node = shutil.which("node", path=env["PATH"])
    if not node:
        raise RuntimeError("Node.js required; no skipped oracle")
    subprocess.run([str(moon), "build", "--target", "js", "--deny-warn", "examples/dicom-json"],
                   cwd=REPO, env=env, check=True)
    engine = REPO / "_build/js/debug/build/examples/dicom-json/dicom-json.js"

    def exchange(cases):
        output = subprocess.run([node, str(REPO / "tools/dicom_json_bridge.mjs"), str(engine)],
                                input=json.dumps(cases), text=True, encoding="utf-8",
                                capture_output=True, check=True, env=env)
        return json.loads(output.stdout)

    def accepted(mode, value):
        result, = exchange([{"mode": mode, "input": value}])
        if result.get("ok") is not True or not isinstance(result.get("value"), str):
            raise AssertionError("expected synthetic exchange success: " + mode)
        return result["value"]

    ds = fixture()
    source = ds.to_json(bulk_data_threshold=1024 * 1024)
    canonical = accepted("canonical", source)
    if signature(Dataset.from_json(canonical)) != signature(ds):
        raise AssertionError("pydicom JSON -> MoonBit -> pydicom semantics")
    if accepted("canonical", canonical) != canonical:
        raise AssertionError("canonical JSON not idempotent")
    tags = list(json.loads(canonical))
    if tags != sorted(tags):
        raise AssertionError("nonascending output tags")

    binary = bytes.fromhex(accepted("to_part10", source))
    restored = pydicom.dcmread(io.BytesIO(binary))
    if (signature(restored) != signature(ds)
            or restored.file_meta.MediaStorageSOPInstanceUID != ds.SOPInstanceUID
            or restored.file_meta.MediaStorageSOPClassUID != ds.SOPClassUID
            or restored.file_meta.TransferSyntaxUID != ExplicitVRLittleEndian):
        raise AssertionError("MoonBit Part10 -> independent pydicom semantics")
    meta = FileMetaDataset()
    meta.TransferSyntaxUID = ExplicitVRLittleEndian
    meta.MediaStorageSOPClassUID = ds.SOPClassUID
    meta.MediaStorageSOPInstanceUID = ds.SOPInstanceUID
    external = FileDataset(None, ds, file_meta=meta, preamble=bytes(128))
    stream = io.BytesIO()
    external.save_as(stream, enforce_file_format=True)
    external_json = accepted("from_part10", stream.getvalue().hex())
    if signature(Dataset.from_json(external_json)) != signature(ds):
        raise AssertionError("pydicom Part10 -> MoonBit JSON -> pydicom semantics")

    # pydicom uses float for numeric DS JSON by default, so an additional raw
    # lexeme oracle checks exact decimal preservation BEFORE any float reader.
    exact = ["9007199254740993", "1.2300", "1e-003", "-0", "0.12345678901234"]
    for token in exact:
        text = '{"00281053":{"vr":"DS","Value":[' + token + ']}}'
        result = json.loads(accepted("canonical", text))
        if result["00281053"]["Value"] != [token]:
            raise AssertionError("numeric DS lexeme changed")

    negatives = [
        '{"00280010":{"vr":"US","Value":[65536]}}',
        '{"00280010":{"vr":"US","Value":[1.0]}}',
        '{"00280010":{"vr":"US","Value":[1e0]}}',
        '{"00280010":{"vr":"UL","Value":[4294967295.0000001]}}',
        '{"00281053":{"vr":"DS","Value":[{"__medseal_exact_number__":"123"}]}}',
        '{"00100020":{"vr":"LO","v\\u0072":"LO"}}',
        '{"00100020":{"vr":"LO"},"00100020":{"vr":"LO"}}',
        '{"7FE00010":{"vr":"OB","BulkDataURI":"https://example.invalid/private"}}',
        '{"7FE00010":{"vr":"OB","InlineBinary":"AA=="}}',
        '{"00020010":{"vr":"UI","Value":["1.2.840.10008.1.2.1"]}}',
    ]
    negatives += ['{"00111000":{"vr":"' + vr + '"}}'
                  for vr in ("SV", "UV", "FD", "FL", "AT", "OD", "OF", "OL", "OV")]
    results = exchange([{"mode": "canonical", "input": text} for text in negatives])
    if results != [{"ok": False}] * len(negatives):
        raise AssertionError("unsupported/malformed input accepted or private error leaked")
    # UTF-8 JSON does not implicitly select the binary SpecificCharacterSet.
    no_charset = json.loads(source)
    del no_charset["00080005"]
    bad_ids = json.loads(source)
    bad_ids["00080018"]["Value"] = ["1.02.3"]
    refusals = exchange([{"mode": "to_part10", "input": text}
                         for text in ("{}", json.dumps(no_charset), json.dumps(bad_ids))])
    if refusals != [{"ok": False}] * 3:
        raise AssertionError("missing charset or invalid identity accepted for Part10")

    result = {
        "schema": 1, "status": "passed", "oracle": {"name": "pydicom", "version": pydicom.__version__},
        "backend": "actual-MoonBit-JS-ESM", "supported_vrs_exercised": 25,
        "checks": ["external-json-to-MoonBit-to-pydicom", "MoonBit-Part10-read-by-pydicom",
                   "external-Part10-to-MoonBit-json-to-pydicom", "PN-three-representations-UTF8",
                   "integer-boundaries", "decimal-lexeme-before-float", "single-text-backslash",
                   "multivalue-empty-positions", "nested-and-empty-SQ", "binary-exact-octets",
                   "canonical-idempotence-tag-order", "missing-charset-and-identity-refusal"],
        "precision_lexemes": len(exact), "negative_cases": len(negatives) + 3,
        "fixture_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "output_part10_sha256": hashlib.sha256(binary).hexdigest(),
        "source_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "source_files_sha256": {str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for base in ("api/dicom_json", "examples/dicom-json")
                                for p in sorted((REPO / base).glob("*")) if p.is_file()},
        "source_state": "local-working-tree; not registry publication",
        "release_authorized": False,
        "limits": ["synthetic data only", "independent oracle executed on JS; unit/consumer tests cover four backends",
                   "codec subset, not full DICOMweb/IOD/de-identification approval"],
    }
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=REPO / "tmp/c3-dicom-json-ci.json")
    args = parser.parse_args()
    print(json.dumps(run(args.record), ensure_ascii=False))
