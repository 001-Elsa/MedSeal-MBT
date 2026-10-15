# Support matrix

Applies to the 0.5.0 source release, inheriting the 0.4.1 baseline except the explicitly expanded input syntax. This is a tested subset, not a full DICOM
conformance statement. Do not transfer private-host guarantees to basic commands.

| Area | Supported behavior | Boundary |
| --- | --- | --- |
| Format | Part 10, Explicit VR LE and pinned-dictionary Implicit VR LE input; Explicit VR LE output | Unknown/private implicit tags rejected; no compression, BigEndian or complete standard claim |
| Character sets | Default ASCII, ISO_IR 6, ISO_IR 192 | Other/multivalued character sets rejected; no transcoding |
| Sequences | Supported defined/undefined item and Sequence lengths | Depth 32; supported strict Sequence contexts only |
| Basic single file | Metadata editing, optional private-tag removal | Retains identity UIDs; report and DICOM destinations are not one atomic pair |
| Research-v1 collection | Per-job patient aliases, UID mapping, full DA intervals, reference/hash checks | No persistent maps or signing in this entry; unknown public non-UID metadata can remain |
| Strict-v1 | 120 classified attributes, VR/VM/selected Type rules, path/condition/priority compilation | Unknown public fields rejected; not all IODs, VR semantics or Annex E |
| Patient identity | Namespace + Issuer + Patient ID; conflict rejection | No name-similarity matching or automatic cross-source reconciliation |
| UID roles | Supported SOP/Study/Series/Frame/reference mappings; standard Classes retained | Unsupported public UID roles rejected; no arbitrary reference graph support |
| Persistent identity | Private encrypted store, source/project separation, backups and wrapping-key rotation | Requires Native + Python 3.12 on controlled POSIX; compatibility batch remains per-job |
| References | Closed current collection; private host can use reverified Acknowledged history | History must match project/source/destination; permissive research external mode is weaker |
| Incremental reuse | Bound private Converted cache and source-content/ownership checks | Cache hit never grants review/publish permission; no remote exactly-once claim |
| Dates/times | Full DA; strict opt-in DT precision policy; standalone TM not shifted | Incomplete DT cleared; unsupported leap-second shifting blocked; no timezone inference |
| Pixel path | Buffered public API; public Native SDK and private strict streaming with terminal finite OB/OW pixels | Single frame/sample, monochrome 8/16 bit; no pixel inspection or editing |
| Classic CT research | Single-frame native 16-bit MONOCHROME2, selected CT matrix and independent voxel/HU/geometry checks | Only ct-classic-research-v1; no complete MR/SC/CT IOD or clinical claim |
| Recovery | Private sealed inputs, immutable schema2 plan, SQLite journal/checkpoints and revalidation | Compatibility batch retries need new plans; no power-loss/network filesystem certification |
| Review and delivery | Review schema2, signed release schema2, independent verifier and local directory receipts | Human evidence quality and clinical acceptance remain separate; no PACS/DICOMweb |
| Public reports | Anonymous IDs, structural paths, registered actions/issues | No original patient values/paths, mapping state, offsets or secrets |
| Workbench | Loopback pagination/explanations/cancel with Host/Origin/session/CSRF gates | Single-owner local tool; no organizational login or release authority |

## Community additions included in 0.4.1

C1 adds public `convert_collection`: 1–256 objects, 64 MiB/object, 128 MiB total,
strict closed references and all-output verification, on four backends. C2 adds
an offline rule lab compiled from the same SDK. 0.4.1 adds a separate local
read-only file mode (16 objects, 8 MiB each, 16 MiB total, 15s deadline),
Worker isolation, explicit private-text reveal and anonymous summary export.
No browser conversion, server or release authority. Its transport/structure limits and actual Chromium browser
validation are documented in [lab contracts](COMMUNITY_LAB.zh-CN.md). These are
0.4.1 additions, capabilities installed by `moon add ...@0.4.1`.

C3a adds private DICOM JSON interchange for 25 VRs, exact DS/IS token
preservation and Part 10 reconstruction. Rejects unsupported VRs and remote
BulkDataURI. JSON 8 MiB, InlineBinary 1 MiB, SQ depth 16, 20,000 counted nodes;
conservative escaping allocations may reject earlier. See the explicit
[JSON matrix, normalization and oracle](DICOM_JSON.zh-CN.md). This
addition is separate from binary parsing, strict IOD checks and public reports.

V2 adds [dataset preflight](DATASET_PREFLIGHT.zh-CN.md); V3 adds a [loopback Orthanc REST adapter](ORTHANC_INTEGRATION.zh-CN.md) for reverified signed packages. Actual Orthanc 1.13.0 synthetic reception passed; no complete DICOMweb/PACS claim.

## Resource budgets

- 256 MiB/file; 128 MiB/encoded value or pixel span; 100,000 elements/file; depth 32.
- 10,000 objects/job; 100,000 mapped UIDs; indexed metadata estimate 2 MiB/source,
  64 MiB/collection. Streaming additionally caps its metadata prefix at 2 MiB.
- Discovery depth 16 and 20,000 entries; reject links/special files/hardlinked inputs.
  Extensionless Part 10 files are included; non-DICOM exclusions are counted.
- Private sealing total 32 GiB, one worker and 1 MiB copy chunks. Free-space checks
  are not quotas or concurrent reservations.
- Policy JSON 1 MiB; conversion manifest 8 MiB; signed release 4 MiB; audit 16 MiB.

## Publication and trust

Compatibility collection uses exclusive sibling staging and an absent target.
Its SHA-256 manifest is unsigned. Strict private conversion stops at
AWAITING_REVIEW and release_authorized:false; final publish independently checks
review, creates an Ed25519 package and uses no-replace local publication.
Runtime/policy/input changes refuse recovery; existing unknown targets fail.
Only complete, reverified packages enter the receiver directory.

Local POSIX process recovery is tested. Physical power loss, network filesystem
durability, Windows enterprise providers and real clinical acceptance are outside
the current claim. See [operations](OPERATIONS.zh-CN.md),
[security](../SECURITY.md) and [field evidence](W7_FIELD_EVIDENCE.zh-CN.md).

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

## 0.5.0 source release additions

Public metadata queries, private CSV/JSONL, anonymous inventory, quality reports, named patient-date plans and Native scanning/streaming are described with exact budgets in the [data-processing guide](DATA_PROCESSING.zh-CN.md). Existing 0.4.1 registry examples install only that historical baseline. No 0.5.0 registry publication is claimed.
