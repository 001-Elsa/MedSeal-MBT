# Architecture and safety model

## Current entry points and private host

The portable MoonBit public facades live in api/dicom, api/policy,
api/validation and api/explain. Native api/authorization validates evidence
through an administrator-pinned **eight-file** authorization closure. That is
separate from the private job coordinator's **ten-adapter** runtime closure.
Factories prove checks at creation time; operations recheck current evidence.

Strict rules classify 120 attributes and 21 additional contracts. The 141-entry
rulebook links implementation and positive/negative cases; the 475-case fixed
corpus provides independent expectations. Classic CT uses a separate limited
profile and independent voxel/HU/geometry acceptance.

```text
controlled source -> private sealed input + immutable plan
 -> encrypted identity reservations / bound Converted cache
 -> MoonBit bounded metadata conversion + streaming native pixels
 -> object checkpoints / full relationship verification
 -> AWAITING_REVIEW -> schema2 human review -> READY
 -> Ed25519 signed package -> no-replace PUBLISHED
 -> destination-bound outbox -> local receipt -> Acknowledged history
```

Python 3.12 provides SQLite/private filesystem coordination, vetted encryption
and signature integration, review/delivery orchestration and loopback UI.
DICOM parsing, rules, mapping application, writing and verification remain in
MoonBit. Cache reuse never grants review or publication authority. Acknowledged
history is eligible only after revalidation in the same project/source/target
scope. No PACS, remote exactly-once, full IOD or pixel-redaction claim.

The loopback workbench is a thin view/cancel host with session/CSRF/Host/Origin
checks, not another conversion engine or publication authority.

## Compatibility collection workflow added in 0.2.0

```text
input directory
  -> stable file-set scan + bounded Part 10 reads
  -> metadata index + patient/Study/Series/Frame/SOP reference checks
  -> versioned research policy + per-job identity/date context
  -> second-pass source hash check + recursive conversion
  -> rebuilt File Meta + checked binary writer
  -> reread output + value/pixel equality + collection checks
  -> per-object audit + SHA-256 manifest
  -> new-directory publication
```

`policy` validates a limited configuration schema, `identity` prepares sorted
patient/UID maps and date offsets, `verification` checks relationships and
semantic value equality, `storage` bounds I/O and obtains OS entropy, `batch`
coordinates staging/publication, and `checksum` wraps a tested SHA-256 dependency.

The following per-job description applies to the compatibility collection API.
Private host state is encrypted/persisted and recoverable as described above.
Only bounded stripped metadata is retained between compatibility passes. Full files are
processed one at a time. Contexts and plans retain private source identities
in memory and are never serialized into public reports. Job execution is
single-use; retries require a fresh plan.

The original single-file architecture below remains the basic-mode foundation.
Its ordinary serialization API preserves source headers; de-identifying writes
now rebuild them. Supported limits and caveats are in docs/SUPPORT_MATRIX.md.

MedSeal-MBT keeps parsing, validation, policy, writing, and CLI concerns in
separate MoonBit packages. The command entry point only forwards arguments to
`src/app`; it does not contain DICOM algorithms.

```text
DICOM bytes
  -> bounded ByteReader
  -> Part 10 / File Meta parser
  -> ordered DataSet + nested Sequence values
  -> structural and semantic validator
  -> basic de-identification policy + value-free audit events
  -> Explicit VR Little Endian writer
  -> parse-after-write verification
  -> report publication, then single DICOM destination replacement
```

## Package responsibilities

| Package | Responsibility |
| --- | --- |
| `src/byteio` | Checked little-endian reads and deterministic byte writes |
| `src/model` | Tags, VRs, values, ordered datasets, and structured errors |
| `src/parser` | Part 10, File Meta, ordinary elements, and nested Sequences |
| `src/dictionary` | Small common/sensitive tag tables; no full DICOM dictionary |
| `src/validator` | Stable Error/Warning issues and basic image metadata rules |
| `src/deid` | Built-in actions, recursive policy application, and safe audit JSON |
| `src/dicom_writer` | Length/padding recomputation and Explicit VR LE serialization |
| `src/date` | Full Gregorian DA validation and shifting |
| `src/policy` | Compatibility research-v1 and strict path/priority/condition compilation |
| `src/identity` | Mapping application, per-job or private-provider context and temporal policies |
| `src/verification` | Metadata equality and cross-file relationship checks |
| `src/storage` | Bounded filesystem access, exclusive staging and OS entropy |
| `src/checksum` | SHA-256 file and incremental streaming integrity hashes |
| `src/batch` | Compatibility collection planning plus strict Native streaming execution |
| `src/app` | Native CLI workflows, output and exit codes |

## Safety invariants

1. A file without a 128-byte preamble and `DICM` marker is rejected.
2. Required File Meta elements and group length are checked before the dataset.
3. Only Transfer Syntax `1.2.840.10008.1.2.1` is accepted.
4. Reads are bounds-checked before indexing; parser limits are 256 MiB per
   file, 128 MiB per element, 100,000 elements, and 32 Sequence levels.
5. Pixel Data is stored and written as raw bytes. It is never decoded or edited.
6. Audit events contain only tag, dictionary name, and action - never old values.
7. The single-file input path can never be the output path. Output is staged
   and reparsed before replacement; an existing DICOM target requires explicit
   `--force`. Report and DICOM are separate destinations and are not published
   as one atomic pair.
8. Collection outputs require a new directory outside the input tree. Staged
   contents are checked and the source file set is rechecked before publication.
   Existing collection destinations are always rejected. Filesystem/power-loss
   certification is outside the current scope.

## Round-trip policy

The writer emits defined-length Sequences even when the input used undefined
lengths. This is valid for the supported scope: tag order, VR, nested item
structure, retained values, and Pixel Data bytes are preserved, while element
and Sequence lengths are recalculated from the serialized values.

## Durable-host contracts

Private job plans and input review records use schema2; reviewer registries and
saved review envelopes use schema1. Signed release manifests use schema2.
Conversion manifests have an 8 MiB budget, signed releases 4 MiB, audits 16 MiB.
See [recovery](docs/RECOVERY.md), [incremental ledger](docs/INCREMENTAL_LEDGER.zh-CN.md)
and [review gate](docs/RISK_REVIEW.md) for exact bindings and transitions.

## Non-goals

Version 0.2.0 does not implement compressed pixel decoding, other transfer
syntaxes, DICOM networking, PACS/DICOMweb, OCR, pixel redaction, a complete
DICOM dictionary, diagnosis, or a guarantee of complete anonymization.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
