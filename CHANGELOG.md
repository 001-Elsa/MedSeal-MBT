# Changelog

All notable changes to MedSeal-MBT are documented here.

## 0.2.0 - Release candidate

- Add research-v1 policies, per-job patient pseudonyms and identity UID mapping.
- Preserve supported cross-file references and per-patient full-date intervals.
- Add plan/batch/verify commands and a runnable MoonBit collection example.
- Stage complete jobs with exclusive files and publish a new output directory.
- Detect source changes and verify DICOM/audit SHA-256 manifest checksums.
- Rebuild de-identifying File Meta and clear the source preamble.
- Preserve unmodified text bytes; explicitly support ASCII and ISO_IR 192.
- Validate calendar dates, UID components, duplicate identities and writer limits.
- Replace source paths in public reports with anonymous object identifiers.
- Update the toolchain and fixed dependencies; add independent pydicom checks.
- API changes: file inspection/validation are async, writer functions raise
  structured errors, and DataElement includes an optional original-byte cache.
- Cross-job mapping, persisted secrets, automatic resume and pixel redaction
  remain outside this version. No remote 0.2.0 publication is claimed.

## 0.1.1 - 2026-08-08

- Validate required File Meta elements and declared group length.
- Add stricter semantic validation for common text VRs.
- Make de-identification auditing idempotent and exact.
- Expand malformed Sequence, writer padding, CLI, and round-trip coverage.
- Verify all targets on Linux, macOS, and Windows CI.
- Add architecture, provenance, and one-page competition proposal artifacts.

## 0.1.0 - 2026-08-08

- Added bounded DICOM Part 10 and Explicit VR Little Endian parsing.
- Added common VR, nested Sequence, and undefined-length Sequence support.
- Added structural and basic image-metadata validation with stable codes.
- Added direct-identifier replacement/emptying and optional Private Tag removal.
- Added Pixel Data preservation, staged write-back, and round-trip verification.
- Added `inspect`, `validate`, and `anonymize` native CLI commands.
- Added privacy-safe JSON audit reports and synthetic test samples.
