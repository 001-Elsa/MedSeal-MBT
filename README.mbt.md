# MedSeal-MBT

MoonBit libraries and native tools for DICOM metadata conversion, linked-object
consistency and independent output verification. [中文指南](README.zh-CN.md).


## 0.5.0 data-processing libraries and tools

Add public `api/query` (typed paths, filters, grouping, CSV/JSONL and anonymous
inventory), `api/quality` (object/collection diagnostics and caller-required fields),
`api/validation` named configuration and immutable conversion plans, and Native
`api/native` metadata scans and streaming closed-collection jobs without Python.
The parser additionally accepts a pinned-dictionary Implicit VR Little Endian
subset; binary output is normalized to Explicit VR Little Endian.

```sh
moon run --target native examples/data_pipeline
moon run --target native cmd/data -- summary INPUT_DIR
moon run --target native cmd/data -- quality INPUT_DIR
moon run --target native cmd/data -- export INPUT_DIR --output NEW.csv --format csv --fields 00080060,00280010,00280011
moon run --target native cmd/data -- convert INPUT_DIR --output NEW_DIR
```

Read the [data-processing guide](docs/DATA_PROCESSING.zh-CN.md),
[0.5 migration and boundaries](docs/MIGRATION_0.5.zh-CN.md), and
[implementation/acceptance ledger](docs/DATA_UPGRADE_STATUS.zh-CN.md).
The installation example below targets 0.5.0. Verify registry availability and
the frozen source snapshot using the external release readback report described
in the [synchronization protocol](docs/PLATFORM_SYNC.zh-CN.md).
The following sections describe capabilities retained in the current candidate; historical release and measurement references keep their original versions.


## Community upgrade in source / 社区升级源码

C1 adds a complete portable public collection SDK: strict closed-batch
conversion, bounded inputs, revalidated relationships and privacy-safe reports.
The source consumer runs on Native, JS, wasm and wasm-gc; an independent pydicom
oracle checks its actual output. These additions are included in the 0.4.1 community release.
Run `moon run --target js examples/consumer` from the source checkout.
See [SDK usage and verification](docs/CONSUMER.zh-CN.md) and
[六阶段社区升级方案](docs/COMMUNITY_ROADMAP.zh-CN.md).

C2 adds an offline rule lab powered by the compiled MoonBit core. Build with
`python3.12 tools/build_community_lab.py`, then open
`tmp/community-lab/index.html` in a regular browser. It uses bundled synthetic
objects and provides rule/structure views, failure experiments and public JSON
export. [使用与验收边界](docs/COMMUNITY_LAB.zh-CN.md): Node/DOM contracts pass;
V5 also verifies actual Chromium rendering, CSP enforcement, downloads, keyboard
activation and a 390px layout. 0.4.1 adds local read-only file inspection with an isolated Worker, explicit private text reveal, anonymous export and cancellation; no image conversion or release authority.


C3a adds public DICOM JSON interchange for 25 VRs, exact decimal token
preservation, bounded parsing, and Part 10 reconstruction. A bidirectional
pydicom oracle checks actual output. The full consumer now passes through JSON
before strict collection conversion. [支持范围与示例](docs/DICOM_JSON.zh-CN.md).
The [实际应用升级计划](docs/APPLICATION_VALUE_PLAN.zh-CN.md) records the implementation of
dataset preflight, independent reception, measured workloads and usability.
V3–V5 now include actual loopback Orthanc reception, licensed phantom fidelity,
measured application costs and rendered-browser checks; see the linked plan.
V2 adds a bounded dataset preflight with actionable, privacy-safe diagnostics:
`python3.12 tools/dataset_preflight.py INPUT`. [操作说明](docs/DATASET_PREFLIGHT.zh-CN.md).
These additions are included in the 0.4.1 community release.


## Current scope: 0.5.0 source release

| Entry | Implemented behavior | Platform / boundary |
| --- | --- | --- |
| Public library | DICOM/JSON exchange, policy, query/filter/group/export, quality, immutable collection plans and privacy-safe explanation | Portable core; directory streaming and authorization providers require Native |
| Native data tools | Metadata summary/quality, private CSV/JSONL and strict streaming conversion | No Python required; per-job identity, new output destinations, cooperative cancellation |
| Collection CLI | Patient pseudonyms, identity UID mapping, full-date intervals, references and SHA-256 manifests | Per-job mappings; no persisted secrets in this compatible entry |
| Private host | Persistent project/source identities, incremental cache/dedup, delivered-history references, precise time handling, resumable sealed jobs, object review, Ed25519 packages and idempotent directory receipts | Python 3.12 + MoonBit Native, controlled POSIX deployment |
| Classic CT research | Single-frame uncompressed 16-bit MONOCHROME2, independent voxel/HU/geometry checks | Narrow `ct-classic-research-v1`; synthetic series tested |
| Local workbench | Loopback job/status/explanation and cancellation interface | Single-host capability/CSRF protection; no multi-user network service |

Publication state and the contest remediation ledger are recorded in
[live competition remediation record](https://github.com/001-Elsa/MedSeal-MBT/blob/master/docs/COMPETITION_REMEDIATION.zh-CN.md).
[W0–W7 evidence](docs/WINNER_UPGRADE_STATUS.zh-CN.md) separates implementation,
synthetic verification and remaining field evidence. Earlier P/iteration audits
are historical snapshots, not the current capability list.

## Install the 0.5.0 library

Install MoonBit using the [official instructions](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html).
Verified baseline: moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9.
In an existing independent MoonBit module:

```sh
moon add 001-Elsa/medseal@0.5.0
```

Create an executable package `app/moon.pkg`:

```moonbit nocheck
import {
  "001-Elsa/medseal/api/policy",
}
pkgtype(kind: "executable")
supported_targets = "+native"
```

Create `app/main.mbt`:

```moonbit nocheck
///|
fn main {
  try {
    let policy = @policy.strict()
    ignore(policy)
    println("public-policy-ok")
  } catch {
    _ => println("public-policy-rejected")
  }
}
```

```sh
moon run --target native app
```

Expected output: `public-policy-ok`. Compiling a policy does not authorize
privacy, pixel or release approval. Public import paths are `api/dicom`,
`api/dicom_json`, `api/policy`, `api/validation`, `api/explain`, `api/query`,
`api/quality`, and Native `api/authorization` / `api/native` in current 0.5.0 source.
Versions before 0.5.0 do not provide the new data-processing packages.
See [API contracts](docs/PUBLIC_API.zh-CN.md); existing `src/` imports remain
compatible. This package install supplies the library, not a certified enterprise deployment.

## Run the source CLI

```sh
cd MedSeal-MBT
moon update
moon run --target native examples/collection
```

Use this local 0.5.0 candidate checkout or its source archive for the new APIs.
The public repository URL alone does not establish that this candidate was pushed.
The demo creates two synthetic patients, four files and two references, converts
them and verifies the manifest. It prints a new `tmp/demo-...` directory. No real
patient data is included. In the supplied workspace, `tools/moon-local` replaces
`moon` using the sibling isolated toolchain without changing shell configuration.

```sh
moon run --target native cmd/main -- plan INPUT_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- batch INPUT_DIR --output NEW_JOB_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- verify NEW_JOB_DIR
moon run --target native cmd/main -- inspect samples/input.dcm --json
moon run --target native cmd/main -- validate samples/input.dcm --json
mkdir -p tmp
moon run --target native cmd/main -- anonymize samples/input.dcm --output tmp/single.dcm --report tmp/single.json --remove-private
```

`plan` checks the candidate collection without publishing outputs. `batch` stages
anonymous DICOM names, per-object audits and a manifest, then publishes a new
non-nested output directory. Source byte changes, identity conflicts and broken
unauthorized references fail. `verify` checks manifest integrity and supported
structure, not complete privacy. Basic `anonymize` keeps UIDs and fixed aliases;
its separate output/report cannot be committed as a single directory transaction.
See [policies](docs/POLICY.md) and [support matrix](docs/SUPPORT_MATRIX.md).

## Persistent workflows and realistic examples

Use [operations and offline installation](docs/OPERATIONS.zh-CN.md) for Python
3.12 private stores, create/run/resume, review/publish/deliver, backup and rotation.
[Incremental ledger](docs/INCREMENTAL_LEDGER.zh-CN.md) explains source-domain
boundaries, exact-repeat reuse and historical-reference checks. The
[workbench](docs/WORKBENCH.zh-CN.md) reuses these operations.
[Four complete scenarios](docs/USE_CASES.zh-CN.md) describe batch integration,
longitudinal research and embedding the public library, with executable evidence
and explicit failure boundaries. They are intended uses supported by synthetic
checks, not claims of hospital adoption.

## Verification and contribution

```sh
moon info
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native
moon package
python3.12 -m pip install -r requirements-qa.txt -r requirements-enterprise.txt
python3.12 tools/check_documentation.py
python3.12 tools/verify_data_processing.py --record tmp/data-processing-ci.json
python3.12 tools/verify_data_consumer.py --record tmp/data-consumer-ci.json
python3.12 tools/verify_with_pydicom.py
python3.12 tools/verify_ct_research.py --record tmp/ct-research.json
python3.12 tools/verify_release_readiness.py
```

Core CI covers Linux/macOS/Windows. POSIX host acceptance runs on Linux/macOS;
Windows is not an enterprise deployment claim. Fixed corpus, generated-rule drift,
negative cases and offline distribution verification are in CI. Records state their
source revision; a configured workflow alone is not proof of success.
See [CONTRIBUTING](CONTRIBUTING.md), [CHANGELOG](CHANGELOG.md) and
[contribution boundaries](docs/CONTRIBUTION.md).

## Privacy and limits

Part 10 Explicit VR Little Endian and pinned-dictionary Implicit VR Little Endian
inputs, ASCII / ISO_IR 6 / ISO_IR 192 and documented Sequence/metadata rules are supported.
Unknown/private implicit tags and ambiguous VRs are rejected. Binary writes
normalize to Explicit VR LE; raw dataset parsing remains Explicit VR only. Classic CT has a limited research profile;
MR/SC metadata checks do not establish full IOD conformance. Unsupported transfer
syntax, public UID role, encoding and conflicting identities fail explicitly.
Pixel bytes are preserved without OCR, redaction or diagnosis. Unknown public
metadata and burned-in identifiers require review. Full Annex E anonymization,
compressed pixels, PACS/DICOMweb and real field acceptance are not claimed.
[Security](SECURITY.md), [streaming limits](docs/STREAMING.md),
[field evidence gates](docs/W7_FIELD_EVIDENCE.zh-CN.md).

Apache-2.0. [Third-party sources and licenses](THIRD_PARTY.md).
[GitHub](https://github.com/001-Elsa/MedSeal-MBT) ·
[GitLink](https://gitlink.org.cn/Hzhhhh/MedSeal-MBT) ·
[Mooncakes](https://mooncakes.io/docs/001-Elsa/medseal).

## Documentation and submission

[全部文档索引 / document audit](docs/DOCUMENTATION_STATUS.zh-CN.md) · [项目提交指南](docs/SUBMISSION_GUIDE.zh-CN.md) · [申报事实与答辩提纲](docs/SUBMISSION_MATERIALS.zh-CN.md)。姓名：韩桢。正式表单由本人提交；项目发布不代表已经取得报名回执。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

Current candidate maintenance: [API compatibility](docs/API_COMPATIBILITY.zh-CN.md),
[0.5 migration](docs/MIGRATION_0.5.zh-CN.md), [doctor](docs/DOCTOR.zh-CN.md), and
[clean-checkout release gate](docs/V6_ACCEPTANCE.zh-CN.md).
