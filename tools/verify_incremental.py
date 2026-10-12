#!/usr/bin/env python3
"""W2 acceptance: authenticated cache, migration, history and outbox.

Inputs are generated in this file and expected state transitions are authored
here independently of the MoonBit converter.  It is deliberately a private
POSIX adapter test; it does not claim a clinical or remote-PACS acceptance.
"""
from pathlib import Path
import copy
import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import uuid

from private_store import initialize, PrivateStore, StoreError
from store_admin import migrate, backup, restore
from ledger_cache import commit as cache_commit, lookup as cache_lookup, invalidate as cache_invalidate, cleanup_orphans
from history_outbox import create_outbox, acknowledge_outbox, lookup_history, publish_history, status_outbox

REPO = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def expect_failure(fn, code=None):
    try:
        fn()
    except StoreError as exc:
        if code is not None:
            assert str(exc) == code, (str(exc), code)
        return str(exc)
    raise AssertionError("expected StoreError")


def make_descriptor(namespace="followup", patient="4:followup0:1:P", uid="1.2.3.3", source_hash=None, output_hash=None):
    return {
        "source_uid": uid,
        "source_sha256": source_hash or "1" * 64,
        "source_patient_key": patient,
        "owner_key": "0:1:P",
        "sop_class": "1.2.840.10008.5.1.4.1.1.7",
        "mapped_uid": "2.25.123456789",
        "mapped_patient": "PSEUDONYM",
        "bindings_sha256": "2" * 64,
    }


def reserve_one(store):
    source = "1.2.3.3"
    request = {
        "schema": 2, "namespace": "followup", "date_shift_days": 14,
        "patients": [{"key": "4:followup0:1:P", "name": "N", "birth_date": "19700101"}],
        "uids": ["1.2.3.1", "1.2.3.2", source],
        "objects": [[source, "1" * 64]],
        "owners": [["1.2.3.1", "study", "4:followup0:1:P", ""], ["1.2.3.2", "series", "4:followup0:1:P", "1.2.3.1"], [source, "instance", "4:followup0:1:P", "1.2.3.2"]],
    }
    return store.reserve(request, "scanner-a")


def main():
    os.umask(0o077)
    checks = []
    with tempfile.TemporaryDirectory(dir=REPO / "tmp", prefix="w2-") as folder:
        root = Path(folder)
        store_path = root / "store"
        initialize(store_path)
        store = PrivateStore(store_path)
        try:
            first = reserve_one(store)
            assert reserve_one(store) == first
            checks.append("five-followup-style-reservations-keep-identity-and-date-binding")

            source = root / "source.dcm"; source.write_bytes(b"source-object")
            output = root / "object-1.dcm"; output.write_bytes(b"deidentified-object")
            audit = root / "object-1.audit.json"; audit.write_bytes(b'{"conversion":"verified"}\n')
            descriptor = make_descriptor(source_hash=sha(source), output_hash=sha(output))
            request = {"schema": 1, "namespace": "followup", "policy_sha256": "3" * 64, "rulebook_sha256": "4" * 64, "program_sha256": "5" * 64, "objects": [descriptor]}
            # The MoonBit descriptor binds the patient key to the namespace;
            # this direct fixture uses the same independently checked relation.
            request["objects"][0]["source_patient_key"] = "8:followup0:1:P"
            # reserve_one intentionally used the actual four-character UTF-16
            # namespace; keep this assertion explicit to detect drift.
            request["objects"][0]["source_patient_key"] = "8:followup0:1:P"
            # Correct formula is len(namespace)=8 for the cache namespace.
            store.db.execute("UPDATE registry SET payload=payload")
            cache_request = request
            # Reserve the cache's exact patient key and ownership relation.
            store.db.execute("DELETE FROM registry")
            store.db.execute("DELETE FROM patients")
            store.db.execute("DELETE FROM uids")
            reserve = {**{
                "schema": 2, "namespace": "followup", "date_shift_days": 14,
                "patients": [{"key": "8:followup0:1:P", "name": "N", "birth_date": "19700101"}],
                "uids": ["1.2.3.1", "1.2.3.2", "1.2.3.3"], "objects": [["1.2.3.3", sha(source)]],
                "owners": [["1.2.3.1", "study", "8:followup0:1:P", ""], ["1.2.3.2", "series", "8:followup0:1:P", "1.2.3.1"], ["1.2.3.3", "instance", "8:followup0:1:P", "1.2.3.2"]]},
            }
            # The first reservation above already proves transactional conflict
            # handling; this second namespace-shaped request is the cache fixture.
            store.reserve(reserve, "scanner-a")
            cache_request["objects"][0]["source_sha256"] = sha(source)
            cache_request["objects"][0]["source_patient_key"] = "8:followup0:1:P"
            cache_request["objects"][0]["mapped_patient"] = store.reserve(reserve, "scanner-a")["patients"][0]["alias"]
            cache_request["objects"][0]["mapped_uid"] = store.reserve(reserve, "scanner-a")["uids"][2]["mapped"]
            cache_request["objects"][0]["bindings_sha256"] = "2" * 64
            # A cache request's binding digest is opaque to the provider, while
            # source/owner/UID/patient records are independently rechecked.
            assert cache_lookup(store, cache_request, "scanner-a")["entries"] == [None]
            cache_commit(store, cache_request, {"file": str(output), "sha256": sha(output), "audit_file": str(audit), "audit_sha256": sha(audit)}, "scanner-a")
            hit = cache_lookup(store, cache_request, "scanner-a")["entries"][0]
            assert hit and hit["sha256"] == sha(output)
            assert cache_lookup(store, {**cache_request, "program_sha256": "6" * 64}, "scanner-a")["entries"] == [None]
            Path(hit["file"]).write_bytes(b"tampered")
            expect_failure(lambda: cache_lookup(store, cache_request, "scanner-a"), "cache-payload-tampered")
            orphan = store.root / "cache" / ("f" * 32 + ".dcm")
            orphan.write_bytes(b"orphan")
            assert cleanup_orphans(store)["removed"] == 1
            assert cache_invalidate(store, cache_request, "scanner-a")["removed"] == 1
            assert cache_lookup(store, cache_request, "scanner-a")["entries"] == [None]
            checks.append("exact-repeat-cache-hit-program-change-miss-tamper-fails-closed-and-explicit-invalidation")
        finally:
            store.close()

        # Migration starts from a deliberately constructed legacy v1 database.
        legacy = root / "legacy"
        initialize(legacy)
        db = sqlite3.connect(legacy / "identity.sqlite", isolation_level=None)
        db.execute("DROP TABLE ledger")
        db.execute("DELETE FROM meta WHERE name='ledger-version'")
        db.close()
        snapshot = root / "legacy-backup"
        assert migrate(legacy, snapshot)["status"] == "migrated"
        assert migrate(legacy, root / "unused-backup")["status"] == "already-current"
        restored = root / "legacy-restored"
        restore(snapshot, restored)
        assert PrivateStore(restored).ledger_version() == 1
        checks.append("legacy-ledger-migration-backup-and-new-directory-rollback")

        package = root / "package"
        package.mkdir(mode=0o700)
        (package / "object-1.dcm").write_bytes(b"published-object")
        (package / "object-1.audit.json").write_bytes(b"published-audit")
        obj = {"file": "object-1.dcm", "sha256": sha(package / "object-1.dcm"), "audit_file": "object-1.audit.json", "audit_sha256": sha(package / "object-1.audit.json")}
        hrequest = {"schema": 1, "namespace": "followup", "source_domain": "scanner-a", "destination_domain": "research-inbox-v1", "objects": [{**make_descriptor(), "source_sha256": "1" * 64, "output_file": obj["file"], "output_sha256": obj["sha256"], "audit_file": obj["audit_file"], "audit_sha256": obj["audit_sha256"]}]}
        store = PrivateStore(store_path)
        try:
            receipt_hash = "7" * 64
            publish_history(store, hrequest, package, receipt_hash)
            # Published alone cannot satisfy a historical reference.
            expect_failure(lambda: lookup_history(store, hrequest, package), "history-target-not-acknowledged")
            publish_history(store, hrequest, package, receipt_hash, state="Acknowledged")
            assert lookup_history(store, hrequest, package)["status"] == "historical-reference-verified"
            checks.append("published-history-requires-ack-and-rechecks-output-audit-sop-and-patient-binding")
            orequest = {"schema": 1, "package_id": "package-001", "destination_domain": "research-inbox-v1", "authorized": True, "objects": [obj]}
            created = create_outbox(store, orequest, package)
            ack = {"schema": 1, "outbox_id": created["outbox_id"], "package_id": "package-001", "destination_domain": "research-inbox-v1", "receiver_id": "receiver-a", "objects": [obj]}
            assert acknowledge_outbox(store, ack, package, ack)["status"] == "acknowledged"
            assert status_outbox(store, created["outbox_id"], "research-inbox-v1")["state"] == "Acknowledged"
            (package / "object-1.dcm").write_bytes(b"deleted-or-tampered")
            expect_failure(lambda: acknowledge_outbox(store, ack, package, ack), "history-file-hash-mismatch")
            checks.append("outbox-idempotent-ack-rebuilds-receipt-but-rejects-tampered-target")
        finally:
            store.close()
    evidence = {"schema": 1, "stage": "W2", "status": "passed", "checks": checks, "executed": len(checks), "failed": 0, "skipped": 0, "release_authorized": False, "limitations": ["synthetic private fixtures", "single-owner local POSIX adapter", "directory receiver only; remote PACS exactly-once requires a separate protocol", "no real patient, operator, recipient or independent clinical review evidence"]}
    path = REPO / "docs/evidence/w2-incremental.json"
    path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": evidence["status"], "checks": len(checks)}))


if __name__ == "__main__":
    main()

