# MedSeal-MBT

MoonBit libraries and native tools for DICOM metadata conversion, linked-object
consistency and independent output verification. [中文指南](README.zh-CN.md).

## Current scope: 0.2.0 engineering preview

| Entry | Implemented behavior | Platform / boundary |
| --- | --- | --- |
| Public library | Policy compilation, DICOM read/write, validation and privacy-safe explanation | Portable core; file I/O and authorization providers require Native |
| Collection CLI | Patient pseudonyms, identity UID mapping, full-date intervals, references and SHA-256 manifests | Per-job mappings; no persisted secrets in this compatible entry |
| Private host | Persistent project/source identities, incremental cache/dedup, delivered-history references, precise time handling, resumable sealed jobs, object review, Ed25519 packages and idempotent directory receipts | Python 3.12 + MoonBit Native, controlled POSIX deployment |
| Classic CT research | Single-frame uncompressed 16-bit MONOCHROME2, independent voxel/HU/geometry checks | Narrow `ct-classic-research-v1`; synthetic series tested |
| Local workbench | Loopback job/status/explanation and cancellation interface | Single-host capability/CSRF protection; no multi-user network service |

Publication state and the contest remediation ledger are recorded in
[COMPETITION_REMEDIATION](docs/COMPETITION_REMEDIATION.zh-CN.md).
[W0–W7 evidence](docs/WINNER_UPGRADE_STATUS.zh-CN.md) separates implementation,
synthetic verification and remaining field evidence. Earlier P/iteration audits
are historical snapshots, not the current capability list.

## Install the library

Install MoonBit using the [official instructions](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html).
Verified baseline: moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9.
In an existing independent MoonBit module:

```sh
moon add 001-Elsa/medseal@0.2.0
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
`api/policy`, `api/validation`, `api/explain`, and Native `api/authorization`.
See [API contracts](docs/PUBLIC_API.zh-CN.md); existing `src/` imports remain
compatible. This package install supplies the library, not a certified enterprise deployment.

## Install and run the source CLI

```sh
git clone https://github.com/001-Elsa/MedSeal-MBT.git
cd MedSeal-MBT
moon update
moon run --target native examples/collection
```

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
[Three complete scenarios](docs/USE_CASES.zh-CN.md) describe batch integration,
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

Only Part 10 Explicit VR Little Endian, ASCII / ISO_IR 192 and documented
Sequence/metadata rules are supported. Classic CT has a limited research profile;
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
