#!/usr/bin/env python3
"""Narrow private storage/crypto adapter. No DICOM parsing or transformation.

Protocol data travels on stdin/stdout, never command arguments or public logs.
SQLite transactions, cryptography HKDF/HMAC/AESGCM, and OS entropy provide the
primitive operations. The directory/key-file provider targets a controlled
single-user POSIX deployment; it is not a KMS or administrator threat defense.
"""
from pathlib import Path
import argparse
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import stat
import sys
import uuid
import fcntl
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class StoreError(Exception):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def private_file(path, maximum):
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_mode & 0o077 or info.st_uid != os.geteuid() or info.st_size > maximum:
            raise StoreError("unsafe-private-file")
        data = bytearray()
        while len(data) <= maximum:
            part = os.read(fd, min(65536, maximum + 1 - len(data)))
            if not part:
                break
            data.extend(part)
        if len(data) > maximum:
            raise StoreError("private-file-budget")
        return bytes(data)
    finally:
        os.close(fd)


def write_exclusive(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        view = memoryview(data)
        while view:
            count = os.write(fd, view)
            if not count:
                raise StoreError("short-private-write")
            view = view[count:]
        os.fsync(fd)
    finally:
        os.close(fd)
    sync_directory(path.parent)


def validate_directory(path):
    if os.name != "posix":
        raise StoreError("private-store-platform-not-certified")
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_mode & 0o077 or info.st_uid != os.geteuid():
        raise StoreError("unsafe-private-directory")
    return path.resolve(strict=True)


class PrivateStore:
    def __init__(self, root):
        self.root = validate_directory(Path(root))
        self.lock = os.open(self.root / "store.lock", os.O_RDWR | os.O_NOFOLLOW)
        info = os.fstat(self.lock)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_mode & 0o077 or info.st_uid != os.geteuid():
            os.close(self.lock)
            raise StoreError("unsafe-store-lock")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        try:
            self._open_records()
        except BaseException:
            if hasattr(self, 'db'):
                self.db.close()
            os.close(self.lock)
            raise

    def _open_records(self):
        generation = private_file(self.root / "CURRENT", 64).decode()
        if not generation or any(c not in "0123456789abcdef" for c in generation):
            raise StoreError("invalid-key-generation")
        key_root = validate_directory(self.root / generation)
        wrapping = private_file(key_root / "wrapping.key", 32)
        envelope = private_file(key_root / "envelope", 128)
        try:
            self.master = AESGCM(wrapping).decrypt(envelope[:12], envelope[12:], b"MedSeal-v1-store-root")
        except Exception:
            raise StoreError("key-envelope-authentication-failed") from None
        if len(self.master) != 32:
            raise StoreError("invalid-master-key")
        self.encryption = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"MedSeal-v1-record-encryption").derive(self.master)
        self.lookup_key = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"MedSeal-v1-lookup").derive(self.master)
        self.cipher = AESGCM(self.encryption)
        database = self.root / "identity.sqlite"
        info = database.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_mode & 0o077 or info.st_uid != os.geteuid() or info.st_size > 128 * 1024 * 1024:
            raise StoreError("unsafe-private-database")
        self.db = sqlite3.connect(database, timeout=10, isolation_level=None)
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        check = self.db.execute("SELECT value FROM meta WHERE name='key-check'").fetchone()
        if not check or self.decrypt("meta", b"key-check", check[0]) != {"schema": 1}:
            raise StoreError("key-or-schema-mismatch")
        self.ledger_version()  # Never silently open an unknown future schema.

    def close(self):
        self.db.close()
        fcntl.flock(self.lock, fcntl.LOCK_UN)
        os.close(self.lock)

    def lookup(self, kind, scope, source):
        return hmac.new(self.lookup_key, canonical([1, kind, scope, source]), hashlib.sha256).digest()

    def encrypt(self, kind, lookup, value):
        nonce = os.urandom(12)
        return nonce + self.cipher.encrypt(nonce, canonical(value), canonical([1, kind, lookup.hex()]))

    def decrypt(self, kind, lookup, data):
        try:
            return json.loads(self.cipher.decrypt(data[:12], data[12:], canonical([1, kind, lookup.hex()])))
        except Exception:
            raise StoreError("private-record-authentication-failed") from None

    def ledger_version(self):
        row = self.db.execute("SELECT value FROM meta WHERE name='ledger-version'").fetchone()
        if row is None:
            return 1
        value = self.decrypt('meta', b'ledger-version', row[0])
        if value != {'schema': 2}:
            raise StoreError('unsupported-ledger-schema')
        return 2

    def require_ledger(self):
        if self.ledger_version() != 2:
            raise StoreError('ledger-migration-required')

    def ledger_get(self, kind, scope, source):
        self.require_ledger()
        key = self.lookup('ledger-' + kind, scope, source)
        row = self.db.execute('SELECT payload FROM ledger WHERE kind=? AND lookup=?', (kind, key)).fetchone()
        return None if row is None else self.decrypt('ledger-' + kind, key, row[0])

    def ledger_put(self, kind, scope, source, value):
        self.require_ledger()
        key = self.lookup('ledger-' + kind, scope, source)
        self.db.execute('INSERT INTO ledger VALUES(?,?,?) ON CONFLICT(kind,lookup) DO UPDATE SET payload=excluded.payload',
                        (kind, key, self.encrypt('ledger-' + kind, key, value)))

    def reserve(self, request, source_domain):
        if set(request) != {"schema", "namespace", "date_shift_days", "patients", "uids", "objects", "owners"} or request["schema"] != 2:
            raise StoreError("invalid-binding-request")
        if not isinstance(source_domain, str) or not source_domain or len(source_domain) > 128:
            raise StoreError("invalid-source-domain")
        scope_name, bound = request["namespace"], request["date_shift_days"]
        if not isinstance(scope_name, str) or not 1 <= len(scope_name) <= 128 or type(bound) is not int or not 0 < abs(bound) <= 3650:
            raise StoreError("invalid-project-policy")
        patients, uids = request["patients"], request["uids"]
        if not isinstance(patients, list) or not isinstance(uids, list) or len(patients) > 10000 or len(uids) > 100000:
            raise StoreError("identity-budget")
        scope = [scope_name, source_domain]
        result = {"schema": 1, "patients": [], "uids": []}
        self.db.execute("BEGIN IMMEDIATE")
        try:
            if len(request["objects"]) > 10000 or len(request["owners"]) > 40000:
                raise StoreError("private-registry-budget")
            for kind, records in [("object", request["objects"]), ("owner", request["owners"])]:
                for record in records:
                    if not isinstance(record, list) or len(record) != (2 if kind == "object" else 4) or not all(isinstance(v, str) and len(v) <= 4096 for v in record):
                        raise StoreError("invalid-private-registry-record")
                    if record[0] not in uids or (kind == "object" and (len(record[1]) != 64 or any(c not in "0123456789abcdef" for c in record[1]))) or (kind == "owner" and (record[1] not in {"instance", "study", "series", "frame"} or record[2] not in {p.get("key") for p in patients if isinstance(p, dict)} or (record[3] and record[3] not in uids))):
                        raise StoreError("invalid-private-registry-link")
                    key = self.lookup(kind, scope, record[0])
                    value = record[1:]
                    previous = self.db.execute("SELECT payload FROM registry WHERE kind=? AND lookup=?", (kind, key)).fetchone()
                    if previous:
                        if self.decrypt(kind, key, previous[0]) != value:
                            raise StoreError("object-content-conflict" if kind == "object" else "historical-uid-owner-conflict")
                    else:
                        self.db.execute("INSERT INTO registry VALUES (?,?,?)", (kind, key, self.encrypt(kind, key, value)))
            policy_key = self.lookup("policy", [scope_name], "date-bound")
            previous = self.db.execute("SELECT payload FROM policies WHERE lookup=?", (policy_key,)).fetchone()
            if previous:
                if self.decrypt("policy", policy_key, previous[0]) != {"date_shift_days": bound}:
                    raise StoreError("date-policy-migration-required")
            else:
                self.db.execute("INSERT INTO policies VALUES (?,?)", (policy_key, self.encrypt("policy", policy_key, {"date_shift_days": bound})))
            seen = set()
            for patient in patients:
                if not isinstance(patient, dict) or set(patient) != {"key", "name", "birth_date"} or not all(isinstance(v, str) and len(v) <= 4096 for v in patient.values()) or patient["key"] in seen:
                    raise StoreError("invalid-patient-request")
                seen.add(patient["key"])
                key = self.lookup("patient", scope, patient["key"])
                row = self.db.execute("SELECT payload FROM patients WHERE lookup=?", (key,)).fetchone()
                signature = [patient["name"], patient["birth_date"]]
                if row:
                    value = self.decrypt("patient", key, row[0])
                    if value["signature"] != signature:
                        raise StoreError("patient-signature-conflict")
                else:
                    value = {"alias": "P" + secrets.token_hex(16).upper(), "offset": (secrets.randbelow(abs(bound)) + 1) * (1 if bound > 0 else -1), "signature": signature}
                    self.db.execute("INSERT INTO patients VALUES (?,?,?)", (key, self.lookup("alias", [], value["alias"]), self.encrypt("patient", key, value)))
                result["patients"].append({"key": patient["key"], "alias": value["alias"], "offset": value["offset"]})
            if len(set(uids)) != len(uids):
                raise StoreError("duplicate-uid-request")
            for uid in uids:
                if not isinstance(uid, str) or not 1 <= len(uid) <= 64 or any(c not in "0123456789." for c in uid):
                    raise StoreError("invalid-uid-request")
                key = self.lookup("uid", scope, uid)
                row = self.db.execute("SELECT payload FROM uids WHERE lookup=?", (key,)).fetchone()
                if row:
                    value = self.decrypt("uid", key, row[0])
                else:
                    value = {"mapped": "2.25." + str(uuid.uuid4().int)}
                    if value["mapped"] in uids:
                        raise StoreError("source-uid-collision")
                    self.db.execute("INSERT INTO uids VALUES (?,?,?)", (key, self.lookup("mapped", [], value["mapped"]), self.encrypt("uid", key, value)))
                result["uids"].append({"source": uid, "mapped": value["mapped"]})
            self.db.execute("COMMIT")
            return result
        except BaseException:
            self.db.execute("ROLLBACK")
            raise


def initialize(root):
    root = Path(root)
    root.mkdir(mode=0o700)
    root = validate_directory(root)
    master = os.urandom(32)
    generation = write_generation(root, master)
    write_exclusive(root / "CURRENT", generation.encode())
    write_exclusive(root / "store.lock", b"")
    write_exclusive(root / "identity.sqlite", b"")
    db = sqlite3.connect(root / "identity.sqlite", isolation_level=None)
    try:
        db.executescript("""
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=FULL;
            CREATE TABLE meta(name TEXT PRIMARY KEY, value BLOB NOT NULL);
            CREATE TABLE policies(lookup BLOB PRIMARY KEY, payload BLOB NOT NULL);
            CREATE TABLE patients(lookup BLOB PRIMARY KEY, alias_key BLOB UNIQUE NOT NULL, payload BLOB NOT NULL);
            CREATE TABLE uids(lookup BLOB PRIMARY KEY, mapped_key BLOB UNIQUE NOT NULL, payload BLOB NOT NULL);
            CREATE TABLE registry(kind TEXT NOT NULL, lookup BLOB NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(kind,lookup));
            CREATE TABLE ledger(kind TEXT NOT NULL, lookup BLOB NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(kind,lookup));
        """)
        key = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"MedSeal-v1-record-encryption").derive(master)
        nonce = os.urandom(12)
        check = nonce + AESGCM(key).encrypt(nonce, canonical({"schema": 1}), canonical([1, "meta", b"key-check".hex()]))
        db.execute("INSERT INTO meta VALUES (?,?)", ("key-check", check))
        nonce = os.urandom(12)
        version = nonce + AESGCM(key).encrypt(nonce, canonical({'schema': 2}), canonical([1, 'meta', b'ledger-version'.hex()]))
        db.execute('INSERT INTO meta VALUES (?,?)', ('ledger-version', version))
        db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    finally:
        db.close()
    sync_directory(root)


def write_generation(root, master):
    """Immutable key pair; only CURRENT changes after both files are durable."""
    generation = secrets.token_hex(16)
    folder = root / generation
    folder.mkdir(mode=0o700)
    wrapping, nonce = os.urandom(32), os.urandom(12)
    write_exclusive(folder / "wrapping.key", wrapping)
    write_exclusive(folder / "envelope", nonce + AESGCM(wrapping).encrypt(nonce, master, b"MedSeal-v1-store-root"))
    sync_directory(root)
    return generation


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["init", "reserve", "cache-get", "cache-put", "cache-invalidate", "cache-cleanup-orphans", "runtime-fingerprint", "history-get"])
    parser.add_argument("--store", type=Path, required=True)
    parser.add_argument("--source-domain")
    parser.add_argument("--root", type=Path)
    parser.add_argument("--destination-domain")
    parser.add_argument("--outbox-id")
    args = parser.parse_args()
    try:
        if args.operation == "init":
            initialize(args.store)
            print('{"schema":1,"status":"initialized"}')
        else:
            data = sys.stdin.buffer.read(32 * 1024 * 1024 + 1)
            if len(data) > 32 * 1024 * 1024:
                raise StoreError("request-budget")
            def no_duplicates(pairs):
                out = {}
                for key, value in pairs:
                    if key in out:
                        raise StoreError("duplicate-request-key")
                    out[key] = value
                return out
            request = json.loads(data, object_pairs_hook=no_duplicates)
            if args.operation == 'runtime-fingerprint':
                if request != {'schema': 1}:
                    raise StoreError('invalid-runtime-request')
                from ledger_cache import provider_runtime
                print(canonical({'schema': 1, 'fingerprint': provider_runtime()}).decode())
                return 0
            if args.operation == 'history-get':
                from history_outbox import resolve_history
                print(canonical(resolve_history(args.store, request, args.source_domain)).decode())
                return 0
            store = PrivateStore(args.store)
            try:
                if args.operation == 'reserve':
                    result = store.reserve(request, args.source_domain)
                elif args.operation == 'cache-get':
                    from ledger_cache import lookup
                    result = lookup(store, request, args.source_domain)
                elif args.operation == 'cache-put':
                    from ledger_cache import commit
                    if not isinstance(request, dict) or set(request) != {'request', 'output'}:
                        raise StoreError('invalid-cache-commit-envelope')
                    result = commit(store, request['request'], request['output'], args.source_domain)
                elif args.operation == 'cache-invalidate':
                    from ledger_cache import invalidate
                    result = invalidate(store, request, args.source_domain)
                elif args.operation == 'cache-cleanup-orphans':
                    from ledger_cache import cleanup_orphans
                    result = cleanup_orphans(store)
                print(canonical(result).decode())
            finally:
                store.close()
    except StoreError as error:
        print(json.dumps({"status": "failed", "code": str(error)}), file=sys.stderr)
        return 1
    except Exception:
        print('{"status":"failed","code":"private-store-operation-failed"}', file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
