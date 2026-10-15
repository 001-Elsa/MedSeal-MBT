# Changelog

## Unreleased — application V3

- Add a loopback-only, fixed-version Orthanc REST adapter for reverified signed
  packages; explicit partial retry semantics and no remote credentials.
- Run actual Orthanc1.13.0 with signed synthetic CT, identity-matched voxel/HU/geometry
  readback, duplicates, malformed input, disconnect/restart/retry and tamper refusal.

## Unreleased — application V2

- Add bounded POSIX dataset preflight reusing sealed discovery, actual MoonBit
  per-object explanations and whole-collection planning; actionable fixed
  diagnostics and no private values in public output.

## Unreleased — community C3a

- Add public DICOM JSON interchange for a documented 25-VR subset, bounded
  duplicate-aware parsing, exact DS/IS tokens, and private Part 10 reconstruction.
- Reject unsupported VRs, remote bulk references, ambiguous representations and
  rounded fractional integers; normalize pydicom's empty SQ explicitly.
- Exercise real pydicom JSON and binary inputs in both directions; extend the
  archive consumer through JSON before strict linked-object conversion.
- Record a task-based application plan for dataset preflight, independent
  reception, measured workloads, usability and a separately frozen release.

## Unreleased — community C2

- Build a self-contained offline rule lab using the compiled MoonBit SDK;
  synthetic scenarios, structure/decision views, policy action comparisons and
  public explanation export run without a server or external assets.
- Add bounded JSON/hex bridge, public-error boundary and two four-backend tests.
- Add Node/DOM event acceptance and three-OS CI; explicitly keep rendered-browser
  and CSP-enforcement acceptance pending.

## Unreleased — community C1

- Add public, portable closed-collection conversion with bounded inputs,
  all-output validation and a private result type; retain legacy APIs.
- Replace the policy-only source consumer with actual linked-object conversion
  on four backends; validate serialized outputs independently with pydicom.
- Preserve an explicit policy-only registry contract for published <=0.2.3.
- Record the C1–C6 community roadmap separately from historical W0–W7 evidence.


All notable changes to MedSeal-MBT are documented here.

## 0.2.3 - 2026-10-13 (Complete source snapshot)

- The 0.2.2 Git candidate exposed evidence files being overwritten during POSIX CI; it was not published to Mooncakes. Its existing commit/tag remain unchanged, and 0.2.3 is the corrected release candidate.
- Include every reviewed Git-tracked file in the Mooncakes package, including workflows, hooks, Git attributes and earlier publication evidence.
- Add a default-deny publishing allowlist and an exact file/content verification gate to prevent repository/package divergence.
- Preserve the author's public research helper scripts with explicit local input/output directories; third-party research sources and old working copies remain outside the maintained module.
- Write persistent-identity and W4 rerun results to temporary paths instead of overwriting frozen evidence; CI retains the new records as artifacts.
- Keep post-publication receipts outside the frozen source tree. Bump module/CLI version together; existing pinned jobs must use their original runtime.

## 0.2.1 - 2026-10-13 (Documentation patch)

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
