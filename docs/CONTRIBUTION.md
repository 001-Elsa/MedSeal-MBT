# Contribution from the existing baseline

Baseline commit: `bb7e895` (0.1.1). Its 19 commits are preserved.

| Existing foundation | New implementation |
| --- | --- |
| Bounded Explicit VR parser | Character-set boundary, original text bytes, even value lengths |
| Basic recursive de-identification | Research policies, per-job patient keys and aliases |
| Binary DICOM writer | Reconstructed File Meta, zero preamble, checked model/size limits |
| Single-file validation | Study/Series/Frame ownership and cross-file SOP references |
| Fixed identity replacement | Role-aware UID mapping and independent patient date offsets |
| Individual staged file | Exclusive bounded I/O, private staged job, manifest publication |
| Synthetic samples and tests | Independent pydicom generation, checksum and mutation tests |

Meaningful new code is in policy, identity, date, verification, storage, batch
and checksum packages, with a native CLI and a reusable collection example.
The native C shim obtains OS entropy only; all DICOM, policy, identity, graph and
publication orchestration logic is MoonBit.

Local source census: 49 implementation/example/generator MoonBit files contain
4,840 lines, or 4,329 after removing blank and full-line comment lines. Fourteen
test files contain 2,125 lines (1,931 by the same filtered count). Generated
interfaces, dependencies, C/Python code and build products are excluded. This is
a transparent local count, not an official contest effective-code measurement.

Correctness evidence is in ACCEPTANCE.md and docs/evidence. Related functionality
in MoonDICOM is acknowledged in RELATED_WORK.md; basic parsing is not presented
as a unique new capability. The repository's existing history is not rewritten,
and no empty or artificially split commits are required for this iteration.
