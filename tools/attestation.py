#!/usr/bin/env python3
"""Separated signing key provider and review-gated local no-replace publication."""
from pathlib import Path
import base64
import hashlib
import json
import os
import shutil
import secrets
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
from private_store import StoreError, canonical, private_file, validate_directory, write_exclusive, sync_directory
from local_fs import atomic_private, digest, rename_new, copy_file_new
from enterprise_job import locked_job, journal, state, transition
from risk_gate import gate, json_document
from verify_delivery import verify_package


def initialize_signer(root, trust_output):
    root = Path(root)
    root.mkdir(mode=0o700)
    root = validate_directory(root)
    private = Ed25519PrivateKey.generate()
    raw = private.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption())
    public = private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    write_exclusive(root / 'signing.key', raw)
    key_id = hashlib.sha256(public).hexdigest()
    write_exclusive(Path(trust_output), canonical({'schema': 1, 'keys': {key_id: public.hex()}}))
    return {'schema': 1, 'status': 'signer-initialized', 'key_id': key_id}


def signing_key(root):
    root = validate_directory(Path(root))
    private = Ed25519PrivateKey.from_private_bytes(private_file(root / 'signing.key', 32))
    public = private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return private, hashlib.sha256(public).hexdigest()


def publish_job(workspace, job_id, destination, registry, signer, trust, checkpoint=lambda event: None):
    with locked_job(workspace, job_id) as job:
        db = journal(job)
        try:
            if state(db) not in {'READY', 'PUBLISHING', 'PUBLISHED'}:
                raise StoreError('review-gate-not-ready')
            plan, manifest, inventory, review, review_hash = gate(job, registry)
            destination = Path(destination).absolute()
            parent = validate_directory(destination.parent)
            if parent != destination.parent or destination.name in {'', '.', '..'} or job == parent or job in parent.parents or parent == job.parent:
                raise StoreError('invalid-publication-target')
            if parent.stat().st_dev != job.stat().st_dev:
                raise StoreError('publication-cross-filesystem-unsupported')
            files = [{'file': 'manifest.json', 'sha256': review['manifest_sha256']}]
            for obj in manifest['objects']:
                files.extend([{'file': obj['file'], 'sha256': obj['sha256']}, {'file': obj['file'][:-4] + '.audit.json', 'sha256': obj['audit_sha256']}])
            runtime_fingerprint = hashlib.sha256(canonical({'binary': plan['binary_sha256'], 'verifier': plan['verifier_sha256'], 'python': plan['python_sha256'], 'tools': [{ 'name': item['name'], 'sha256': item['sha256']} for item in plan['runtime_files']]})).hexdigest()
            release = {'schema': 2, 'producer_runtime_sha256': runtime_fingerprint, 'release_authorized': True, 'context': review['record']['context'], 'tool_version': manifest['tool_version'],
                       'policy_sha256': manifest['policy_sha256'], 'dictionary_sha256': manifest['dictionary_sha256'], 'conversion_manifest_sha256': review['manifest_sha256'],
                       'review_sha256': review_hash, 'files': files,
                       'risk_summary': {'blocking_unresolved': 0, 'pixel_review': 'human-reviewed-clear', 'metadata_scope': 'recipient-accepted-subset'},
                       'inventory': {'candidate_objects': len(inventory), 'discovered_files': plan['inventory']['discovered_files'], 'excluded_non_part10': plan['inventory']['excluded_non_part10']}}
            encoded = canonical(release)
            release_hash = hashlib.sha256(encoded).hexdigest()
            private, key_id = signing_key(signer)
            intent = {'schema': 1, 'destination': str(destination), 'release_sha256': release_hash, 'key_id': key_id}
            if (job / 'publication.json').exists():
                if json_document(private_file(job / 'publication.json', 4096)) != intent:
                    raise StoreError('immutable-publication-intent-mismatch')
            else:
                write_exclusive(job / 'publication.json', canonical(intent))
            def may_start_publication():
                if (job / 'cancel-request').exists():
                    raise StoreError('publication-cancelled')
            transition(db, 'PUBLISHING', precondition=may_start_publication)
            if destination.exists():
                checked = verify_package(destination, trust, allow_synthetic=release['context'] == 'synthetic')
                if checked['release_sha256'] != release_hash or checked['key_id'] != key_id:
                    raise StoreError('existing-publication-not-this-job')
                transition(db, 'PUBLISHED', 'publication-reconciled')
                return {**checked, 'job_id': job_id, 'state': 'PUBLISHED'}
            stage = parent / ('.medseal-' + secrets.token_hex(16))
            stage.mkdir(mode=0o700)
            try:
                for entry in files:
                    source = job / 'converted' / entry['file']
                    target = stage / entry['file']
                    copy_file_new(source, target, entry['sha256'])
                write_exclusive(stage / 'release.json', encoded)
                envelope = {'schema': 1, 'algorithm': 'Ed25519', 'key_id': key_id, 'signature': base64.b64encode(private.sign(encoded)).decode('ascii')}
                write_exclusive(stage / 'signature.json', canonical(envelope))
                # Re-evaluate the gate after copying; a concurrent edit invalidates it.
                if gate(job, registry)[4] != review_hash:
                    raise StoreError('review-changed-during-publication')
                checked = verify_package(stage, trust, allow_synthetic=release['context'] == 'synthetic')
                sync_directory(stage)
                checkpoint('before-publication-rename')
                if (job / 'cancel-request').exists():
                    raise StoreError('publication-cancelled')
                rename_new(stage, destination)
                checkpoint('after-publication-before-journal')
                transition(db, 'PUBLISHED')
                return {**checked, 'job_id': job_id, 'state': 'PUBLISHED'}
            finally:
                if stage.exists():
                    shutil.rmtree(stage)
        finally:
            db.close()
