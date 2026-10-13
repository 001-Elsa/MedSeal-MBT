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
The native C shim obtains OS entropy only. MoonBit implements parsing,
metadata/policy conversion, relationship checks, writer and public explanations.
Python 3.12 implements private SQLite transactions, sealed-job coordination,
cryptography provider integration, review/signing/delivery and loopback hosting.
The host is substantial runtime code; the enterprise platform is not described as
pure MoonBit.

P0–P7 and W0–W7 add persistent identities, streaming, recovery, review/signatures,
incremental reuse and history, CT research constraints, public APIs and fixed
quality experiments. See the stage ledger for verified behavior and boundaries.

The source census at audited commit `2b088d4` excludes blank/full-line comments:
71 handwritten MoonBit runtime files / 7,482 lines; 4 examples/tools / 379;
23 test files / 2,858; 6 generated MoonBit files / 8,686 (reported separately);
13 Python runtime host files / 2,241; 33 Python development/QA files / 3,588;
2 C shim files / 57. This is a reproducible local count, not an official effective
contribution assessment. Generated interfaces, dependencies and build products
are excluded. Subsequent documentation/tool fixes do not reuse this census as a
new count.

Baseline history and authors are preserved. Human contributor identity,
registration and previous awards require the participant's own declarations.
Related work/source records describe reference scope and do not claim ecosystem
uniqueness. No empty or artificially split commits are used to meet a count.
