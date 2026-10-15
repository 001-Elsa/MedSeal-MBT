#!/usr/bin/env python3
"""Synthetic preflight acceptance including fail-closed and public canaries."""
from pathlib import Path
import argparse
import json
import shutil
import tempfile
from dataset_preflight import report, REPO
from verify_strict_profile import generate_strict
from evidence import code_identity
import pydicom


def verify(record):
    checks = []
    with tempfile.TemporaryDirectory(prefix="preflight-acceptance-") as folder:
        root = Path(folder)
        source = root / "SECRET-SOURCE-PATH"
        generate_strict(source, 2)
        def run(expected, category=None, **kwargs):
            value = report(source, **kwargs)
            assert value["status"] == expected, value
            if category:
                assert any(item["category"] == category for item in value["issues"]), value
            text = json.dumps(value)
            for private in ["SECRET", str(root), "SOURCEPATIENT", "1.2.826.0.1"]:
                assert private not in text
            assert value["release_authorized"] is False
            return value
        good = run("ready-for-planning")
        assert good["checked"] == 2 and good["collection"] == "checked" and good["policy_actions"]
        checks.append("valid-closed-set-and-policy-impact")
        (source / "notes.txt").write_text("SECRET-NOTES")
        assert run("ready-for-planning")["excluded_non_part10"] == 1
        checks.append("non-DICOM-counted")
        first = sorted(source.glob("*.dcm"))[0]
        saved = first.read_bytes()
        first.write_bytes(b"truncated")
        bad = run("blocked", "format")
        assert bad["checked"] == 2 and bad["collection"] == "not-checked"
        first.write_bytes(saved)
        checks.append("one-bad-object-blocks-entire-original-set")
        ds = pydicom.dcmread(first)
        ds.file_meta.TransferSyntaxUID = "1.2.840.10008.1.2.2"
        # Change the transfer syntax UID without rewriting data: parser must
        # refuse it before trying to interpret the unmodified little-endian body.
        first.write_bytes(saved.replace(b"1.2.840.10008.1.2.1", b"1.2.840.10008.1.2.2"))
        run("blocked", "format")
        first.write_bytes(saved)
        checks.append("unsupported-transfer-syntax")
        shutil.copyfile(first, source / "duplicate.dcm")
        run("blocked", "references")
        (source / "duplicate.dcm").unlink()
        checks.append("duplicate-identity-refuses-collection")
        ds = pydicom.dcmread(first)
        from pydicom.dataset import Dataset
        from pydicom.sequence import Sequence
        item = Dataset()
        item.ReferencedSOPClassUID = ds.SOPClassUID
        item.ReferencedSOPInstanceUID = "1.2.826.0.1.99999999"
        ds.ReferencedImageSequence = Sequence([item])
        ds.save_as(first, enforce_file_format=True)
        run("blocked", "references")
        first.write_bytes(saved)
        checks.append("unresolved-reference")
        (source / "link").symlink_to(first)
        run("blocked", "filesystem")
        (source / "link").unlink()
        checks.append("symbolic-link-refused")
        import os
        os.link(first, source / "hardlink")
        run("blocked", "filesystem")
        (source / "hardlink").unlink()
        checks.append("hardlink-refused")
        huge = source / "large.dcm"
        with huge.open("wb") as stream:
            stream.truncate(64 * 1024 * 1024 + 1)
        run("blocked", "budget")
        huge.unlink()
        checks.append("size-budget-before-sealing")
        policy = root / "policy.json"
        policy.write_text('{"SECRET-POLICY":')
        run("blocked", "policy", policy=policy)
        checks.append("malformed-policy-private-error")
        run("blocked", "runtime", binary=root / "missing")
        checks.append("missing-runtime-no-skip")
    result = {"schema": 1, "status": "passed", "stage": "V2", "checks": checks,
              "release_authorized": False, **code_identity(REPO)}
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "checks": len(checks)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=REPO / "tmp/v2-preflight-ci.json")
    verify(parser.parse_args().record)
