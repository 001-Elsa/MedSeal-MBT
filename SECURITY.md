# Security Policy

## Supported scope and reporting

The 0.5.0 local candidate adds bounded queries/quality/plans, Native directory
processing and pinned-dictionary Implicit VR input to the previous 0.4.1 baseline.
Current maintenance and immutable
release evidence are described in [release record](docs/COMPETITION_REMEDIATION.zh-CN.md).
Use GitHub private security advisories for vulnerability reports. Include version,
error code and a synthetic reproduction; never submit patient data, credentials
or private identity stores to public issues.

## Different entry points have different guarantees

| Entry | Security behavior | Boundary |
| --- | --- | --- |
| Basic single file | Metadata replacement; private tags removed only if requested | Identity UIDs retained; no collection consistency or final release authorization |
| Compatibility research-v1 collection | Shared per-job mapping, private-tag removal, relationship/hash checks | Unknown public non-UID metadata may remain; mapping not persisted; unsigned manifest |
| Strict-v1 core | Unknown public attributes rejected, classified rules and risks, stable public explanations | Partial IOD/metadata scope; no automatic pixel clearance |
| Query / private export | Typed access, bounded projection, CSV formula protection and JSONL value structure | CSV/JSONL contain original private values; only summary reports are anonymous |
| Quality / buffered plan | Preserve failing object counts; four check states; copied configuration/immutable Bytes snapshots | ready is not approval; buffered budgets differ from directory scans |
| Native directory SDK | Source rechecks, per-job identity, strict streaming, absent target and boundary cancellation | No Python; no persistent identity/recovery/signature authority; metadata scan does not inspect pixels |
| Private POSIX host | Encrypted persistent identity, sealed input, runtime-bound resume, review gate and signed publication | Single-owner controlled host; local key provider, not organizational IAM/HSM or clinical certification |

All supported workflows enforce size/count/depth/format budgets and reject
unsupported transfer syntax. File/path/hash checks on a live compatibility input
are not an atomic snapshot. Private-host ingestion seals input bytes before later
conversion; it still requires a controlled local filesystem and administrator.

Persistent cross-job maps and date offsets exist only in the private store.
Buffered plans retain private Bytes in memory; Native data jobs use ephemeral
per-job maps. `private_*` outputs and CSV/JSONL are not public reports. Protect the
0700 workspace, 0600 files, backups and keys; do not export private plans as reports.
Strict streaming copies pixels unchanged and never runs OCR or redaction.
Burned-in text, visual identity and unknown source semantics require human review.

The compatibility checksum manifest detects changes only relative to a trusted
manifest. Final private-host releases separately bind per-file hashes, runtime,
policy and review to Ed25519 signatures. Recipients need public trust keys from
an independent trusted channel. A valid signature proves bytes and attestations,
not that a human review was truthful or that the images are clinically usable.

## Recovery and operational limits

Recovery rechecks sealed bytes, policy, binaries, ten private runtime adapters,
provider and interpreter identity. Changes invalidate plans/reviews/cache.
Cancellation prevents publication starting; once publication starts, complete or
recover it and use the receiver's recall procedure if needed. No automatic recall.

Handled errors clean owned staging; hard termination can leave private staging.
Only owned terminal jobs can be cleaned. SSD deletion does not prove erasure.
Process-kill tests do not certify power-loss durability, network filesystems,
Windows ACLs or hostile administrators. Real field gates are in
[W7 field evidence](docs/W7_FIELD_EVIDENCE.zh-CN.md).

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
