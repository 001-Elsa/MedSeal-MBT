# MedSeal-MBT 0.1.0 Acceptance

This document records the reproducible release and competition-submission
checks for MedSeal-MBT.

## Functional acceptance

- [x] Parses DICOM Part 10 files with Explicit VR Little Endian.
- [x] Rejects unsupported Transfer Syntax UIDs without guessing.
- [x] Parses common VRs and defined/undefined-length nested Sequences.
- [x] Detects malformed VRs, truncated values, invalid lengths, damaged
      Sequences, excessive nesting, oversized files/elements, and excessive
      element counts.
- [x] Provides `inspect`, `validate`, and `anonymize` commands plus JSON output.
- [x] Replaces Patient Name and Patient ID and empties configured identifiers.
- [x] Recursively handles sensitive fields inside Sequences.
- [x] Optionally removes odd-group Private Tags.
- [x] Preserves Pixel Data bytes and retained UIDs.
- [x] Stages output, reparses it, validates it, and atomically replaces the
      destination.
- [x] Rejects direct and normalized-path attempts to overwrite the input.
- [x] Produces a JSON report without original sensitive values.

## Test data acceptance

- [x] All committed DICOM files are generated synthetic fixtures.
- [x] Valid, unsupported-syntax, truncated, invalid-VR, invalid-Sequence,
      nested-Sequence, Private Tag, and Pixel Data cases are present.
- [x] Sample origin and regeneration instructions are documented.

## Release commands

Run from the repository root:

```bash
moon update
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
moon package
```

Expected test totals with the 2026-07-24 MoonBit toolchain or newer:

```text
wasm:    16 passed
wasm-gc: 16 passed
js:      16 passed
native:  22 passed
```

The Native-only CLI and filesystem integration tests are intentionally skipped
on non-Native backends; portable parser/model/de-identification tests run on
all backends.

## Submission artifacts

- `README.mbt.md` and `README.md`
- Apache-2.0 `LICENSE`
- `.github/workflows/ci.yml`
- source packages and generated `.mbti` interfaces
- complete synthetic samples and audit-report example
- `PROJECT_APPLICATION.md`
- reproducible Mooncakes package archive from `moon package`

