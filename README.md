# MedSeal-MBT

A MoonBit DICOM metadata library with collection-consistent patient pseudonyms,
identity UID remapping, full-date interval preservation and verified binary
rewriting. [中文说明和完整操作指南](README.zh-CN.md).

## Status and scope

0.2.0 is a locally verified release candidate. The published Mooncakes baseline
remains [001-Elsa/medseal@0.1.1](https://mooncakes.io/docs/001-Elsa/medseal).
The candidate source is available on GitHub. GitLink synchronization and
Mooncakes 0.2.0 publication remain pending. The original iteration plan is not
fully completed; see [the item-by-item audit](docs/PLAN_AUDIT.md).

The enterprise engineering preview now adds persistent project/source identities,
sealed resumable jobs, bounded native-pixel streaming, per-object review gates,
Ed25519 releases, independent offline verification and controlled-directory receipts.
It retains the original MoonBit core and history. Python 3.12 adapters provide
private transactions, established cryptography and local system integration.
An isolated macOS ARM64 offline installation has passed a synthetic full batch,
two incremental batches, process recovery and backup/rotation exercise.
Linux/macOS CI also tests the actual offline distribution before release.
See [enterprise implementation and remaining gates](docs/ENTERPRISE_STATUS.md),
[operations](docs/OPERATIONS.zh-CN.md) and [streaming scope](docs/STREAMING.md).
This is an engineering preview: full CT/MR IOD validation, historical references,
exact-repeat conversion/delivery deduplication and real field acceptance remain open.

The core parses Part 10 Explicit VR Little Endian, supported Sequence structures,
common text/integer VRs and raw pixel bytes. Research-v1 supports a documented
CT/MR/Secondary Capture metadata subset, ASCII and ISO_IR 192. It checks patient,
Study/Series/SOP identity relationships and supported references across files.

It does not inspect or redact pixels, implement all IOD requirements, guarantee
complete anonymization, or provide medical diagnosis. Unknown public metadata
may retain identity. Unsupported public UID roles, transfer syntaxes, encodings
and conflicting identities fail explicitly. See [SUPPORT_MATRIX](docs/SUPPORT_MATRIX.md).

## Run a complete example

```sh
moon run --target native examples/collection
```

This creates two synthetic patients, four files and two references, runs a job,
verifies it, and prints the saved demonstration directory. In the supplied local
workspace, replace `moon` with `tools/moon-local` to use the sibling toolchain.
The wrapper does not modify shell configuration and falls back to PATH elsewhere.

## CLI

```sh
moon run --target native cmd/main -- plan INPUT_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- batch INPUT_DIR --output NEW_JOB_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- verify NEW_JOB_DIR
moon run --target native cmd/main -- inspect samples/input.dcm --json
moon run --target native cmd/main -- validate samples/input.dcm --json
```

Collection output uses anonymous object filenames, per-object action audits and
a SHA-256 manifest. Input/output must not be nested; the job target must not
exist. All outputs and reports are staged before directory publication. Source
file-set, size/mtime and byte hashes are checked against the plan. Handled errors
clean staging; a hard-killed process can leave a private staging directory.

In the compatible collection CLI, patient aliases, UID mappings and random per-patient date offsets are shared
inside one job only. Reports do not expose reverse maps, source names or actual
offsets. `verify` checks integrity and structure relative to the manifest;
it is not a complete privacy check or a signature-authentication mechanism.

The compatible `anonymize` basic mode retains UID values, replaces Patient Name
with ANONYMOUS and Patient ID with MEDSEAL-ID, and can remove private elements:

```sh
mkdir -p tmp
moon run --target native cmd/main -- anonymize samples/input.dcm --output tmp/single.dcm --report tmp/single.json --remove-private
```

It now rebuilds File Meta and clears the preamble. A separate report and DICOM
cannot be atomically committed together; its report says `verified`, and command
success confirms completion. Use `batch` for coordinated job output. Existing
outputs require `--force` in basic mode; input paths cannot be overwritten.

## Library and validation

Public packages include `/src/parser`, `/src/policy`, `/src/identity`,
`/src/dicom_writer`, `/src/verification`, and Native `/src/batch` under
`001-Elsa/medseal`. API flows and policy rules are in [POLICY](docs/POLICY.md).

Verified toolchain: moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9.

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native
moon info
moon package
```

Independent checks use Python 3.10+ and pydicom==3.0.1:

```sh
python -m pip install pydicom==3.0.1
python tools/verify_with_pydicom.py
```

CI configures Linux/macOS/Windows checks and independent verification. Local
results are in [ACCEPTANCE](ACCEPTANCE.md) and [BENCHMARKS](BENCHMARKS.md);
remote results are recorded separately in [iteration status](docs/ITERATION_STATUS.md).

Sources: [GitHub](https://github.com/001-Elsa/MedSeal-MBT),
[GitLink](https://gitlink.org.cn/Hzhhhh/MedSeal-MBT).

Apache-2.0. See [THIRD_PARTY](THIRD_PARTY.md), [SECURITY](SECURITY.md),
[RELATED_WORK](docs/RELATED_WORK.md) and [iteration status](docs/ITERATION_STATUS.md).

独立质量实验室：见 [固定语料、差分与诊断](docs/CONFORMANCE_LAB.zh-CN.md)。按阶段升级的当前证据见 [W0–W7 实施账本](docs/WINNER_UPGRADE_STATUS.zh-CN.md)。
