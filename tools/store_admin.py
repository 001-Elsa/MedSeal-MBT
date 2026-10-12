#!/usr/bin/env python3
"""Private SQLite snapshot/restore and crash-safe wrapping key generation switch."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import sqlite3
import sys
from private_store import (PrivateStore, StoreError, canonical, private_file,
                           write_exclusive, write_generation, sync_directory, validate_directory)


def rotate(root):
    store = PrivateStore(root)
    try:
        generation = write_generation(store.root, store.master)
        pending = store.root / ('CURRENT-' + generation)
        write_exclusive(pending, generation.encode())
        # Immutable generations make both sides of this crash window readable.
        os.replace(pending, store.root / 'CURRENT')
        sync_directory(store.root)
    finally:
        store.close()
    return {'schema': 1, 'status': 'wrapping-key-rotated', 'mapping_changed': False}


def backup_open_store(store, destination):
    destination = Path(destination)
    destination.mkdir(mode=0o700)
    destination = validate_directory(destination)
    generation = private_file(store.root / 'CURRENT', 64).decode()
    folder = destination / generation
    folder.mkdir(mode=0o700)
    for name in ('wrapping.key', 'envelope'):
        write_exclusive(folder / name, private_file(store.root / generation / name, 128))
    write_exclusive(destination / 'CURRENT', generation.encode())
    write_exclusive(destination / 'store.lock', b'')
    write_exclusive(destination / 'identity.sqlite', b'')
    snapshot = sqlite3.connect(destination / 'identity.sqlite')
    try:
        store.db.backup(snapshot)
        if snapshot.execute('PRAGMA integrity_check').fetchone() != ('ok',):
            raise StoreError('backup-integrity-failed')
    finally:
        snapshot.close()
    with (destination / 'identity.sqlite').open('rb') as stream:
        os.fsync(stream.fileno())
    files = ['CURRENT', 'identity.sqlite', generation + '/wrapping.key', generation + '/envelope']
    record = {'schema': 1, 'files': {name: hashlib.sha256(private_file(destination / name, 128 * 1024 * 1024)).hexdigest() for name in files}}
    write_exclusive(destination / 'backup.json', canonical(record))
    sync_directory(destination)
    return {'schema': 1, 'status': 'snapshot-complete', 'contains_private_keys': True}


def backup(root, destination):
    store = PrivateStore(root)
    try:
        return backup_open_store(store, destination)
    finally:
        store.close()


def migrate(root, backup_destination, checkpoint=lambda event: None):
    store = PrivateStore(root)
    try:
        if store.ledger_version() == 2:
            return {'schema': 1, 'status': 'already-current', 'ledger_schema': 2}
        # Snapshot and schema transition share the store's exclusive lock.
        backup_open_store(store, backup_destination)
        checkpoint('migration-backup-durable')
        store.db.execute('BEGIN IMMEDIATE')
        try:
            store.db.execute('CREATE TABLE ledger(kind TEXT NOT NULL, lookup BLOB NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(kind,lookup))')
            store.db.execute('INSERT INTO meta VALUES (?,?)', ('ledger-version', store.encrypt('meta', b'ledger-version', {'schema': 2})))
            checkpoint('migration-before-commit')
            store.db.execute('COMMIT')
        except BaseException:
            store.db.execute('ROLLBACK')
            raise
        checkpoint('migration-after-commit')
        if store.db.execute('PRAGMA integrity_check').fetchone() != ('ok',):
            raise StoreError('migration-integrity-failed')
        return {'schema': 1, 'status': 'migrated', 'ledger_schema': 2, 'mapping_changed': False, 'rollback': 'restore pre-migration snapshot into a new controlled directory'}
    finally:
        store.close()


def restore(source, destination):
    source = validate_directory(Path(source))
    record = json.loads(private_file(source / 'backup.json', 4096))
    generation = private_file(source / 'CURRENT', 64).decode()
    expected = {'CURRENT', 'identity.sqlite', generation + '/wrapping.key', generation + '/envelope'}
    if any(c not in '0123456789abcdef' for c in generation) or len(generation) != 32 or record.get('schema') != 1 or set(record.get('files', {})) != expected:
        raise StoreError('invalid-backup-manifest')
    data = {}
    for name in expected:
        data[name] = private_file(source / name, 128 * 1024 * 1024)
        if hashlib.sha256(data[name]).hexdigest() != record['files'][name]:
            raise StoreError('backup-hash-mismatch')
    destination = Path(destination)
    destination.mkdir(mode=0o700)
    destination = validate_directory(destination)
    (destination / generation).mkdir(mode=0o700)
    for name, value in data.items():
        write_exclusive(destination / name, value)
    write_exclusive(destination / 'store.lock', b'')
    store = PrivateStore(destination)
    try:
        if store.db.execute('PRAGMA integrity_check').fetchone() != ('ok',):
            raise StoreError('restore-integrity-failed')
    finally:
        store.close()
    sync_directory(destination)
    return {'schema': 1, 'status': 'restored', 'mapping_changed': False}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['rotate', 'backup', 'restore', 'migrate'])
    parser.add_argument('--store', type=Path, required=True)
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'rotate':
            result = rotate(args.store)
        elif args.operation == 'migrate':
            result = migrate(args.store, args.destination)
        elif args.operation == 'backup':
            result = backup(args.store, args.destination)
        else:
            result = restore(args.store, args.destination)
        print(json.dumps(result))
        return 0
    except Exception:
        print('{"status":"failed","code":"private-store-maintenance-failed"}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
