#!/usr/bin/env python3
"""Idempotent controlled directory delivery and explicit local receipt."""
from pathlib import Path
import fcntl
import hashlib
import json
import os
from private_store import StoreError, canonical, validate_directory, private_file, write_exclusive
from local_fs import digest, copy_file_new, rename_new, atomic_private
from verify_delivery import verify_package, parse_json, read_file


def deliver(package, inbox, trust, receiver_id, allow_synthetic=False, checkpoint=lambda event: None):
    if not isinstance(receiver_id, str) or not receiver_id or len(receiver_id) > 64 or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_' for c in receiver_id):
        raise StoreError('invalid-receiver-id')
    inbox = validate_directory(Path(inbox))
    checked = verify_package(package, trust, allow_synthetic)
    package = Path(package).resolve(strict=True)
    delivery_id = checked['release_sha256']
    lock = inbox / ('.delivery-' + delivery_id + '.lock')
    if not lock.exists():
        try:
            write_exclusive(lock, b'')
        except FileExistsError:
            pass
    private_file(lock, 0)
    descriptor = os.open(lock, os.O_RDWR | os.O_NOFOLLOW)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        destination = inbox / delivery_id
        if not destination.exists():
            stage = inbox / ('.incoming-' + delivery_id)
            if not stage.exists():
                stage.mkdir(mode=0o700)
            validate_directory(stage)
            entries = parse_json(read_file(package / 'release.json', 4 * 1024 * 1024, True))['files']
            entries = entries + [{'file': name, 'sha256': digest(package / name)} for name in ('release.json', 'signature.json')]
            allowed = {entry['file'] for entry in entries}
            if any(path.name not in allowed and not path.name.startswith('.copy-') for path in stage.iterdir()):
                raise StoreError('unexpected-incoming-file')
            for entry in entries:
                target = stage / entry['file']
                if target.exists():
                    if digest(target) != entry['sha256']:
                        target.unlink()
                    else:
                        checkpoint('file-reverified')
                        continue
                temporary = stage / ('.copy-' + entry['file'])
                if temporary.exists():
                    # Only this exact owned staging filename; never recursive removal.
                    private_file(temporary, 256 * 1024 * 1024)
                    temporary.unlink()
                copy_file_new(package / entry['file'], temporary, entry['sha256'])
                rename_new(temporary, target)
                checkpoint('file-verified')
            result = verify_package(stage, trust, allow_synthetic)
            if result['release_sha256'] != delivery_id:
                raise StoreError('incoming-package-binding-mismatch')
            checkpoint('before-delivery-rename')
            rename_new(stage, destination)
            checkpoint('after-delivery-before-receipt')
        result = verify_package(destination, trust, allow_synthetic)
        if result['release_sha256'] != delivery_id:
            raise StoreError('delivered-package-id-mismatch')
        receipt = {'schema': 1, 'receiver_id': receiver_id, 'delivery_id': delivery_id, 'key_id': result['key_id'], 'objects_verified': result['objects'], 'status': 'complete', 'acknowledgment_scope': 'local-directory-and-trusted-byte-verification'}
        receipt_path = inbox / ('receipt-' + delivery_id + '.json')
        if receipt_path.exists():
            if json.loads(private_file(receipt_path, 4096)) != receipt:
                raise StoreError('existing-receipt-mismatch')
        else:
            write_exclusive(receipt_path, canonical(receipt))
        return receipt
    finally:
        os.close(descriptor)
