#!/usr/bin/env python3
"""Validate the non-secret W7 field-evidence bundle.

The checked-in template is intentionally incomplete.  A real site keeps its
filled bundle outside the repository and supplies only evidence references and
scoped observations, never mappings, credentials, or patient data.
"""

from pathlib import Path
import argparse
import json
import re
import sys


REQUIRED_ITEMS = {
    "representative-authorized-source",
    "independent-research-receiver",
    "new-operator",
    "independent-privacy-and-utility-review",
    "persistent-storage-and-backup-platform",
}
ALLOWED_STATUS = {"requires_field", "in_progress", "accepted", "rejected"}
SECRET_KEY = re.compile(r"(secret|token|password|private[_-]?key|mapping|patient|dicom[_-]?path)", re.I)


def walk_keys(value, path="$"):
    if isinstance(value, dict):
        for key, child in value.items():
            yield path + "." + str(key), str(key)
            yield from walk_keys(child, path + "." + str(key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_keys(child, path + "[" + str(index) + "]")


def validate(bundle):
    if bundle.get("schema") != 1 or bundle.get("stage") != "W7-field-evidence":
        raise ValueError("unsupported-field-evidence-schema")
    if bundle.get("release_authorized") is not False:
        raise ValueError("field-bundle-cannot-authorize-release")
    items = bundle.get("items")
    if not isinstance(items, list):
        raise ValueError("field-items-array-required")
    by_id = {item.get("item"): item for item in items if isinstance(item, dict)}
    missing = sorted(REQUIRED_ITEMS - set(by_id))
    if missing:
        raise ValueError("missing-field-items:" + ",".join(missing))
    if len(by_id) != len(items):
        raise ValueError("duplicate-or-invalid-field-item")
    for item_id, item in by_id.items():
        status = item.get("status")
        if status not in ALLOWED_STATUS:
            raise ValueError("invalid-status:" + str(item_id))
        if status == "accepted":
            required = ("evidence_refs", "observed_at", "reviewer_role", "scope")
            if any(not item.get(key) for key in required):
                raise ValueError("accepted-item-needs-scoped-evidence:" + str(item_id))
    forbidden = [path for path, key in walk_keys(bundle) if SECRET_KEY.search(key)]
    if forbidden:
        raise ValueError("secret-or-sensitive-field-name:" + ",".join(forbidden))
    complete = all(by_id[item_id].get("status") == "accepted" for item_id in REQUIRED_ITEMS)
    if bundle.get("field_acceptance_complete") is not complete:
        raise ValueError("completion-flag-does-not-match-item-statuses")
    return {
        "schema": 1,
        "status": "field-evidence-complete" if complete else "field-evidence-incomplete",
        "items": len(items),
        "accepted_items": sum(item.get("status") == "accepted" for item in items),
        "field_acceptance_complete": complete,
        "release_authorized": False,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    bundle = json.loads(args.input.read_text(encoding="utf-8"))
    result = validate(bundle)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("field-evidence-error: " + str(error), file=sys.stderr)
        raise SystemExit(2)
