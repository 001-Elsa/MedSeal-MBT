# Changelog

All notable changes to MedSeal-MBT are documented here.

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
