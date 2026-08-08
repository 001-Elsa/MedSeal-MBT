# Synthetic DICOM samples

Every file in this directory is generated locally by
`tools/generate_samples/main.mbt`. No file is derived from a patient, clinical
system, public clinical dataset, or real medical image. Names and identifiers
such as `TEST^PATIENT` and `SYNTHETIC-001` are deliberate synthetic fixtures.

Regenerate the files with:

```bash
moon run --target native tools/generate_samples
```

Valid fixtures:

- `minimal-valid.dcm`: minimal image metadata, no patient fields.
- `patient-fields.dcm`: synthetic direct identity fields.
- `private-tags.dcm`: one synthetic odd-group Private Tag.
- `nested-sequence.dcm`: a Sequence containing synthetic patient fields.
- `pixel-data.dcm`: four uncompressed synthetic Pixel Data bytes.

Invalid fixtures:

- `unsupported-transfer-syntax.dcm`: Implicit VR Little Endian UID.
- `truncated-element.dcm`: declared value length exceeds remaining bytes.
- `invalid-vr.dcm`: uses the illegal VR `ZZ`.
- `invalid-sequence.dcm`: missing Item and Sequence delimiters.

Demo fixtures:

- `input.dcm`: synthetic patient, private, and pixel fields.
- `output.dcm`: generated basic-de-identification result.
- `report.json`: privacy-safe audit report for the generated result.

