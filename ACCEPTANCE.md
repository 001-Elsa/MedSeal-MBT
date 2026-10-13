# MedSeal-MBT acceptance

Current maintained contracts cover the 0.2.1 documentation patch, preserving
the DICOM behavior of the published 0.2.0 engineering preview. Publication of
each immutable version is verified independently in the release record. The original bb7e895 / 0.1.1 history
is preserved. This accepts the declared subset, not clinical production or all
DICOM IODs. See [support matrix](docs/SUPPORT_MATRIX.md) and
[documentation audit](docs/DOCUMENTATION_STATUS.zh-CN.md).

## Implemented and exercised

- Bounded Part 10 / Explicit VR Little Endian parsing and binary rewriting;
  supported ASCII/ISO_IR 6/ISO_IR 192, rebuilt File Meta and zero preamble.
- Research collection patient/UID/date consistency and closed-reference checks.
- Strict-v1 unknown-field rejection, path/condition/priority rules, 120 classified
  attributes and 141 rulebook entries with implementation/test references.
- Public api/* facades, structured explanations and checked authorization types.
- Controlled POSIX private host: encrypted persistent identities, sealed inputs,
  pinned-runtime recovery, streaming pixels, incremental cache and acknowledged
  historical references within the same project/source/destination domain.
- Private per-object review schema2, Ed25519 signed release schema2, independent
  verification, immutable outbox and idempotent local directory receipts.
- Classic CT research subset and independent synthetic voxel/HU/geometry checks;
  fixed differential corpus, state/fault/fuzz acceptance and loopback workbench.

## Reproduce the source gates

From a source checkout using the isolated local toolchain:

```sh
tools/moon-local update
tools/moon-local fmt --check
tools/moon-local check --target all --deny-warn
tools/moon-local test --target all --deny-warn
tools/moon-local info
tools/moon-local build --target native --deny-warn
tools/moon-local package
python3.12 tools/check_documentation.py
tools/moon-local run --target native examples/collection
```

Python QA commands require Python 3.12 and requirements-qa.txt plus
requirements-enterprise.txt. CI installs both and runs fixed-corpus, CT,
recovery/review/signature, state/fuzz, install, consumer and rehearsal checks.
Windows runs portable/core checks; POSIX host tests run on Ubuntu/macOS.

The source audit at 2c9a49e passed Native 117 and JS/wasm/wasm-gc 64 each,
309 backend executions with shared tests repeated. These are not 309 distinct
scenarios. [That CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38349000368)
passed all three jobs. New verification results remain bound to their own commit.

## Publication and submission

Mooncakes 001-Elsa/medseal@0.2.1 and GitHub v0.2.1 freeze 3e62926.
Its [CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38363013106) passed
all three jobs, including the document gate, CT and POSIX private-host acceptance.
0.2.0 remains frozen at bc5b25c.
The registry consumer actually installed and ran the public module; source,
archive and platform evidence are in [release record](docs/COMPETITION_REMEDIATION.zh-CN.md).
Current repository documents can evolve without overwriting immutable 0.2.0.
GitLink synchronization is independently verified, not inferred from GitHub.

Participant name is 韩桢. [Submission checklist](docs/SUBMISSION_GUIDE.zh-CN.md)
separates prepared project materials from the participant's own application.
A repository release is not a Feishu receipt. The participant submits the form.

## Remaining boundaries

Pixels are copied, not inspected/redacted. Compatibility collection manifests
are unsigned; final private-host publication requires review and a trusted signer.
No compressed/enhanced/multiframe support, full Annex E/IOD claim, PACS/DICOMweb,
Windows private host, hostile-admin defense or physical power-loss certification.
W7 synthetic rehearsal is complete; real source authorization, users, independent
privacy/usability review and storage acceptance remain requires_field. Those
production goals are not universal contest prerequisites.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
