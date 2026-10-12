#!/usr/bin/env python3
"""Run the scripted W7 operator rehearsal and keep field evidence explicit."""
from pathlib import Path
import argparse
import json
import subprocess
import sys


REPO = Path(__file__).resolve().parents[1]
REQUIRED_SOFTWARE_CHECKS = {
    "full-and-two-new-object-incremental-cohorts-stable-patients-study-and-dates",
    "six-unique-instance-uids-and-idempotent-package-receipts",
    "installed-runtime-SIGKILL-and-resume",
    "historical-SOP-content-conflict-blocks-without-publication",
    "wrapping-rotation-and-backup-restore-before-new-followup",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    pilot_record = args.record.with_name(args.record.stem + ".pilot.json")
    command = [sys.executable, str(REPO / "tools" / "verify_pilot.py"), "--runtime-root", str(REPO), "--python", sys.executable, "--record", str(pilot_record)]
    run = subprocess.run(command, cwd=REPO, capture_output=True, text=True, timeout=600)
    if run.returncode:
        print(run.stdout, end="")
        print(run.stderr, end="", file=sys.stderr)
        return run.returncode
    pilot = json.loads(pilot_record.read_text(encoding="utf-8"))
    checks = set(pilot.get("checks", []))
    missing = sorted(REQUIRED_SOFTWARE_CHECKS - checks)
    if missing or pilot.get("field_acceptance_complete") is not False:
        raise AssertionError("software-rehearsal-contract:" + ",".join(missing))
    field_items = [
        {"item": "representative-authorized-source", "status": "requires_field", "owner": "data-controller", "evidence": "source authorization and provenance record"},
        {"item": "independent-research-receiver", "status": "requires_field", "owner": "receiver-owner", "evidence": "receiver import and semantic confirmation"},
        {"item": "new-operator", "status": "requires_field", "owner": "operations", "evidence": "first-use observation and signed checklist"},
        {"item": "independent-privacy-and-utility-review", "status": "requires_field", "owner": "independent-reviewer", "evidence": "separate privacy and research-use conclusions"},
        {"item": "persistent-storage-and-backup-platform", "status": "requires_field", "owner": "platform-operations", "evidence": "site filesystem and disaster-recovery record"},
    ]
    record = {
        "schema": 1,
        "stage": "W7",
        "status": "software-rehearsal-passed",
        "context": "synthetic",
        "pilot": pilot,
        "software_checks": sorted(REQUIRED_SOFTWARE_CHECKS),
        "field_items": field_items,
        "field_acceptance_complete": False,
        "release_authorized": False,
        "limitations": [
            "synthetic SC fixtures only",
            "the scripted runner is not a new human operator",
            "no hospital/PACS/receiver acceptance",
            "no independent privacy or research-utility signoff",
        ],
    }
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": record["status"], "software_checks": len(REQUIRED_SOFTWARE_CHECKS), "field_items": len(field_items), "field_acceptance_complete": False}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
