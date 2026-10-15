# Policies and library APIs

## Choose the correct policy contract

| Configuration | Behavior | Runnable example |
| --- | --- | --- |
| version 1 / research | Compatibility per-job mapping, full DA shifting, three description-tag overrides | examples/research-policy.json |
| version 2 / strict | Unknown public attributes blocked; compiled path, condition and priority rules | examples/strict-policy.json |

Both reject invalid or unknown configuration rather than guessing. Strict
configuration additionally rejects duplicate JSON keys, keep overrides,
identity/structure changes and conflicting priorities. Rules operate only on
classified descriptive fields, including supported nested Sequence paths; they
cannot bypass identity, pixel or required-field constraints. Paths use uppercase
eight-digit tags and supported Sequence ancestors. Higher priority wins; possible
same-priority overlap fails compilation. Canonical policy digests ignore ordering.
See [strict profile](STRICT_PROFILE.md) and [rulebook](RULEBOOK_INDEX.zh-CN.md).

`namespace` partitions source patient IDs; patient keys include Issuer and ID.
Names/birth dates detect conflicts rather than serving as fuzzy identity keys.
Do not mix unrelated source systems in the same domain.

`date_shift_days` is an integer nonzero magnitude bound of 1–3650 days.
Compatibility Native jobs draw independent per-patient nonzero offsets and fresh
UID seeds from OS entropy. Private-host stores persist mappings/offsets within a
project/source domain. Neither exposes offsets in public reports.

Research `allow_external_references=true` permits unresolved references with an
explicit unverified count; it is not proof that those targets were delivered.
Strict private-host historical references require reverified Acknowledged targets
in the same destination domain. Cross-patient and wrong-Class references fail.

Strict temporal behavior has two named policies: metadata-safe-v1 and opt-in
retain-dt-precision-v1. The latter shifts only complete DT date components while
preserving original time precision/fraction/timezone, clears incomplete DT and
does not shift standalone TM. Unsupported leap-second shifting blocks.
See [temporal semantics](TEMPORAL_SEMANTICS.zh-CN.md).

## Public consumers and private orchestration

Prefer the nine public facades: `api/dicom`, `api/dicom_json`, `api/policy`,
`api/validation`, `api/explain`, `api/query`, `api/quality` and Native
`api/authorization` / `api/native`, under module `001-Elsa/medseal`. The older `/src/*` imports remain compatible but
expose lower-level implementation contracts. [Public API](PUBLIC_API.zh-CN.md)
and [consumer example](../examples/consumer/README.md) explain factories and trust.

The compatibility Native flow remains plan → preview → execute → verify. It is a
single-use per-job context without persistent resume. Private execution uses
tools/enterprise_job.py and separate create/run/resume/review/publish/deliver
states, sealed inputs and private identity/cache/history stores.

New in-memory callers can use `ConversionOptions.for_patients` and
`plan_collection`; `convert_collection` remains compatible. Lower-level callers
may prepare the Context with fresh private UID seed/offsets,
transform original datasets, then use write_deidentified and revalidate converted
relationships. Ordinary write_bytes preserves headers for Explicit VR inputs and normalizes
Implicit VR File Meta to Explicit VR LE; it does not de-identify metadata. Never serialize source keys/offsets into public reports.
Repeated processing markers reject accidental second date shifts.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
