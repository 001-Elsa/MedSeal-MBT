#!/usr/bin/env python3
"""Explicit per-object review gate. No OCR-negative or automatic pixel clearance."""
import datetime
import hashlib
import json
import re
from pathlib import Path
from private_store import StoreError, canonical, private_file
from local_fs import atomic_private, digest
from enterprise_job import locked_job, journal, load_plan, verify_converted, state, transition

VISUAL_RISKS = {'pixel-content-unchecked', 'secondary-capture-visual-review', 'burned-in-annotation-unresolved', 'recognizable-features-unresolved', 'overlay-source-unresolved'}
METADATA_RISK = 'public-metadata-subset-only'


def json_document(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise StoreError('duplicate-json-key')
            result[key] = value
        return result
    try:
        return json.loads(data, object_pairs_hook=unique, parse_constant=lambda _: (_ for _ in ()).throw(StoreError('invalid-json-number')))
    except StoreError:
        raise
    except Exception:
        raise StoreError('invalid-json-document') from None


def hex_digest(value):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value) is not None


def risk_inventory(job):
    manifest = json_document(private_file(job / 'converted/manifest.json', 8 * 1024 * 1024))
    records = []
    for entry in manifest['objects']:
        risks = entry.get('risks', ['pixel-content-unchecked', METADATA_RISK])
        if not isinstance(risks, list) or not risks or len(set(risks)) != len(risks) or any(value not in VISUAL_RISKS | {METADATA_RISK} for value in risks):
            raise StoreError('unrecognized-risk-model')
        if 'pixel-content-unchecked' not in risks or METADATA_RISK not in risks:
            raise StoreError('risk-model-cannot-remove-hard-gates')
        records.append({'file': entry['file'], 'sha256': entry['sha256'], 'policy_sha256': manifest['policy_sha256'], 'risks': sorted(risks)})
    return manifest, records


def validate_review(job, review, registry):
    if set(registry) != {'schema', 'reviewers'} or registry['schema'] != 1 or not isinstance(registry['reviewers'], list):
        raise StoreError('invalid-reviewer-registry')
    if not isinstance(review, dict) or set(review) != {'schema', 'context', 'reviewer', 'reviewed_at', 'recipient_accepts_declared_subset', 'records'} or review['schema'] != 1:
        raise StoreError('invalid-review-record-schema')
    if review['context'] not in {'synthetic', 'controlled'} or review['recipient_accepts_declared_subset'] is not True:
        raise StoreError('review-scope-not-approved')
    if not isinstance(review['reviewer'], str) or not re.fullmatch('[A-Za-z0-9_-]{1,64}', review['reviewer']):
        raise StoreError('invalid-reviewer-id')
    allowed = [row for row in registry['reviewers'] if row.get('id') == review['reviewer']]
    if len(allowed) != 1 or review['context'] not in allowed[0].get('contexts', []) or not {'pixel-review', 'metadata-scope'} <= set(allowed[0].get('roles', [])):
        raise StoreError('reviewer-not-authorized-for-scope')
    try:
        moment = datetime.datetime.fromisoformat(review['reviewed_at'].replace('Z', '+00:00'))
        if moment.utcoffset() != datetime.timedelta(0) or moment > datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=5):
            raise ValueError()
    except Exception:
        raise StoreError('invalid-review-time') from None
    manifest, inventory = risk_inventory(job)
    if not isinstance(review['records'], list) or len(review['records']) != len(inventory):
        raise StoreError('review-coverage-incomplete')
    entries = {entry['file']: entry for entry in review['records'] if isinstance(entry, dict)}
    if len(entries) != len(inventory):
        raise StoreError('duplicate-or-invalid-review-object')
    for expected in inventory:
        record = entries.get(expected['file'])
        if record is None or set(record) != {'file', 'sha256', 'policy_sha256', 'decisions'} or any(record[key] != expected[key] for key in ('file', 'sha256', 'policy_sha256')):
            raise StoreError('review-object-or-policy-binding-mismatch')
        decisions = record['decisions']
        if not isinstance(decisions, list) or len(decisions) != len(expected['risks']):
            raise StoreError('unresolved-blocking-risk')
        by_risk = {row.get('risk'): row for row in decisions if isinstance(row, dict)}
        if set(by_risk) != set(expected['risks']):
            raise StoreError('unresolved-blocking-risk')
        for risk, decision in by_risk.items():
            action = 'human-reviewed-clear' if risk in VISUAL_RISKS else 'recipient-accepted-subset'
            if set(decision) != {'risk', 'action', 'evidence_sha256'} or decision['action'] != action or not hex_digest(decision['evidence_sha256']):
                raise StoreError('review-evidence-or-action-invalid')
    return manifest, inventory


def review_job(workspace, job_id, record_path, registry_path):
    with locked_job(workspace, job_id) as job:
        db = journal(job)
        try:
            if state(db) not in {'AWAITING_REVIEW', 'READY'} or (job / 'cancel-request').exists():
                raise StoreError('job-not-reviewable')
            plan = load_plan(job)
            manifest_hash = verify_converted(job, plan)
            registry_data = private_file(Path(registry_path), 1024 * 1024)
            review = json_document(private_file(Path(record_path), 16 * 1024 * 1024))
            _, inventory = validate_review(job, review, json_document(registry_data))
            envelope = {'schema': 1, 'manifest_sha256': manifest_hash, 'registry_sha256': hashlib.sha256(registry_data).hexdigest(), 'record': review}
            atomic_private(job / 'review.json', canonical(envelope))
            transition(db, 'READY')
            return {'schema': 1, 'job_id': job_id, 'state': 'READY', 'objects': len(inventory), 'release_authorized': False, 'context': review['context']}
        finally:
            db.close()


def gate(job, registry_path):
    if (job / 'cancel-request').exists():
        raise StoreError('publication-cancelled')
    plan = load_plan(job)
    manifest_hash = verify_converted(job, plan)
    review = json_document(private_file(job / 'review.json', 16 * 1024 * 1024))
    registry_data = private_file(Path(registry_path), 1024 * 1024)
    if review.get('schema') != 1 or review.get('manifest_sha256') != manifest_hash or review.get('registry_sha256') != hashlib.sha256(registry_data).hexdigest():
        raise StoreError('review-stale-or-authority-changed')
    manifest, inventory = validate_review(job, review['record'], json_document(registry_data))
    return plan, manifest, inventory, review, digest(job / 'review.json')
