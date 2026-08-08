# MedSeal-MBT

MedSeal-MBT is a small DICOM metadata validation and basic
de-identification tool written in MoonBit.

It supports DICOM Part 10 files encoded with Explicit VR Little Endian,
validates basic structures, replaces or empties common direct identifiers,
optionally removes private elements, preserves Pixel Data, and writes a new
DICOM file with a privacy-safe JSON audit report.

## Quick start

```bash
moon run cmd/main inspect samples/input.dcm
moon run cmd/main validate samples/input.dcm
moon run cmd/main anonymize samples/input.dcm \
  --output samples/output.dcm \
  --report samples/report.json \
  --remove-private --force
```

## Verification

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
moon package
```

## Important limitations

MedSeal-MBT performs basic metadata de-identification only. It does not
inspect Pixel Data for burned-in personal information, does not provide
medical diagnosis, and does not guarantee complete anonymization. Version
0.1.1 rejects every Transfer Syntax except Explicit VR Little Endian.

See [README.md](README.md) for the complete feature list, policy, usage,
security boundaries, error behavior, and sample documentation.

Licensed under Apache-2.0.
