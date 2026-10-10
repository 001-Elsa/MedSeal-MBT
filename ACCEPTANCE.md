# MedSeal-MBT 0.2.0 local candidate acceptance

This accepts the documented research-v1 subset. It does not mark every item of
the original iteration plan complete; see [PLAN_AUDIT](docs/PLAN_AUDIT.md).

Baseline: bb7e895 / 0.1.1. The original 68 Native tests were reproduced on the
new toolchain after updating incompatible dependency versions; original source
behavior was tested separately before the iteration's new checks.

## Implemented and exercised

- Part 10 Explicit VR Little Endian parsing, supported Sequences and VRs.
- Explicit ASCII/ISO_IR 192 boundary and unchanged-text byte preservation.
- Rebuilt de-identifying File Meta, zero preamble and retained pixel bytes.
- Private-element removal and value/path-free public action audits.
- Versioned limited policies, patient-key conflicts and shared patient aliases.
- Classified UID mapping, File Meta consistency and cross-file reference checks.
- Independent per-patient full-DA offsets; leap years, overflow and repeat guards.
- Bounded reads, unique/exclusive staging files and new-directory publication.
- Source modification/file-set checks and DICOM/audit SHA-256 manifest checks.
- Failure checks for changed input, existing/nested output, report preflight
  failure, source symlinks, conflicting identities and unclassified public UIDs.
- Runnable Native collection example and pydicom-generated collections.

## Verification commands

```sh
tools/moon-local fmt --check
tools/moon-local check --target all --deny-warn
tools/moon-local test --target all --deny-warn
tools/moon-local build --target native
tools/moon-local info
tools/moon-local package
tools/moon-local run --target native examples/collection
python tools/verify_with_pydicom.py
```

Toolchain: moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9, Apple Silicon macOS.
The final local run passed 91 Native tests and 53 tests on each of wasm,
wasm-gc and js (250 backend test executions, with shared cases repeated across
backends). Exact commands and totals are in docs/evidence/local-verification.json.
Non-Native tests exercise the portable core; Native additionally exercises the
filesystem, CLI and collection workflow. The symlink test is Unix-specific.

Independent pydicom 3.0.1 checks verify patient groups, DA intervals, standard
UID retention, transformed references, header/private-tag removal, Unicode text,
unchanged Pixel Data, manifest hashes, overwrite rejection and tamper failure.
The synthetic 1,000-file collection has two patients and 998 references.

## Remote delivery and remaining boundaries

0.2.0 candidate source has been pushed to GitHub in functional commits. Remote
CI results are recorded separately in docs/ITERATION_STATUS.md; the original
local-verification JSON preserves the state at that earlier local run. GitLink
synchronization and Mooncakes 0.2.0 publication remain pending. Public 0.1.1
package publication does not prove that the new package has been published.

This version has no complete IOD/profile certification, pixel inspection,
persisted identity secrets, automatic resume, signed manifests, measured large
clinical-image performance, or certified network-filesystem/power-loss behavior.
See docs/SUPPORT_MATRIX.md for precise support and failure semantics.
