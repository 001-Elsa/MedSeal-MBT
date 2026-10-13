# Changelog

All notable changes to MedSeal-MBT are documented here.

## Unreleased documentation maintenance

- Synchronize all maintained Markdown with actual API, policy, persistence, temporal,
  recovery/review schemas, runtime closures, budgets, research and publication scope.
- Correct participant name to 韩桢; prepare project-specific submission materials
  while leaving official forms and personal declarations to the participant.
- Add a document inventory/link/code-fact gate to CI and the optional pre-commit hook.
- Preserve immutable release archives and original plan/research/evidence baselines.

## 0.2.0 - 2026-10-13 (Engineering preview)

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
- Add persistent source/project identities, sealed recovery, bounded native-pixel
  streaming, per-object review gates, Ed25519 signing and independent receipts.
- Add public `api/*` facades, rulebook/explanation contracts and fixed differential corpus.
- Add incremental cache/migration, exact-repeat reuse, delivered-history references,
  date/time precision and destination-bound outbox/receipt recovery.
- Add limited classic CT research validation with independent voxel/HU/geometry checks.
- Add fault/state-model and parser fuzz regression, loopback workbench and cancellation.
- Fix release dependency inventory and source/archive binding; update install/examples,
  contribution/source records and independent registry consumer tooling.
- Production field acceptance, compressed pixels, full IOD/Annex E conformance and
  pixel redaction remain outside the declared release. Publication results are recorded
  in docs/COMPETITION_REMEDIATION.zh-CN.md.

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

> 文档核对：本文阶段计数、测量和发行摘要各自绑定原提交；当前状态已核对。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
