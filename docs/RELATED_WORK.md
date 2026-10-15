# Related work and independent contribution

The 0.5.0 source release additionally provides reusable queries/exports, quality, immutable plans and Native directory jobs, plus a pinned-dictionary Implicit VR LE subset. These are current implementation facts; the external ecosystem census below remains dated 2026-10-10, not a new uniqueness search. See the [data ledger](DATA_UPGRADE_STATUS.zh-CN.md).

The baseline is this repository's `bb7e895` / 0.1.1, not a newly renamed project.
Its parser, recursive basic de-identification, DICOM writer and fixtures remain
the foundation. New work adds the collection workflow and correctness evidence, followed by
strict rules/public APIs, persistent incremental identities/history, streaming
recovery, review/signature delivery, classic CT research checks and a local
workbench. See [current use cases](USE_CASES.zh-CN.md) and
[stage evidence](WINNER_UPGRADE_STATUS.zh-CN.md).

On 2026-10-10 the Mooncakes index contained 2,907 published modules. Metadata and
DICOM/de-identification searches were refreshed. Relevant MoonDICOM README,
parser entry, anonymizer and CLI source were read; the complete ecosystem and
all historical source versions were not audited.

[MoonDICOM 0.1.2](https://mooncakes.io/docs/CCllff-jpg/moondicom) provides Part 10
metadata parsing, basic Implicit VR support, validation and configurable
anonymization. Its README explicitly excludes UID remapping, date shifting and
binary DICOM rewriting; its CLI writes anonymized metadata JSON. Basic parsing
and fixed field replacement therefore overlap with MedSeal and are not claimed
as unique new contributions.

The MedSeal 0.2.0 contribution is per-job patient identity grouping, classified
instance UID remapping across files and File Meta, preserved full-date intervals,
reference validation, staged binary collection output and a checksum-verified
manifest, tested with independently generated pydicom fixtures.

Clinical text PHI and FHIR libraries are adjacent domains. No assertion is made
that these algorithms or privacy principles are new outside MoonBit, or that no
future Mooncakes project can implement similar capabilities.

Standards reference: [DICOM PS3.15 Annex E](https://dicom.nema.org/medical/dicom/current/output/chtml/part15/chapter_E.html).
It specifically discusses replacing File Meta and the preamble to avoid identity
leakage. MedSeal implements a documented subset and does not claim the complete
Basic Application Confidentiality Profile.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
