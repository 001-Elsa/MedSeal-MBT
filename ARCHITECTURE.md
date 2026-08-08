# Architecture and safety model

MedSeal-MBT keeps parsing, validation, policy, writing, and CLI concerns in
separate MoonBit packages. The command entry point only forwards arguments to
`src/app`; it does not contain DICOM algorithms.

```text
DICOM bytes
  -> bounded ByteReader
  -> Part 10 / File Meta parser
  -> ordered DataSet + nested Sequence values
  -> structural and semantic validator
  -> basic de-identification policy + value-free audit events
  -> Explicit VR Little Endian writer
  -> parse-after-write verification
  -> atomic destination replacement + JSON report
```

## Package responsibilities

| Package | Responsibility |
| --- | --- |
| `src/byteio` | Checked little-endian reads and deterministic byte writes |
| `src/model` | Tags, VRs, values, ordered datasets, and structured errors |
| `src/parser` | Part 10, File Meta, ordinary elements, and nested Sequences |
| `src/dictionary` | Small common/sensitive tag tables; no full DICOM dictionary |
| `src/validator` | Stable Error/Warning issues and basic image metadata rules |
| `src/deid` | Built-in actions, recursive policy application, and safe audit JSON |
| `src/dicom_writer` | Length/padding recomputation and Explicit VR LE serialization |
| `src/app` | Native file workflow, CLI output, exit codes, and atomic replacement |

## Safety invariants

1. A file without a 128-byte preamble and `DICM` marker is rejected.
2. Required File Meta elements and group length are checked before the dataset.
3. Only Transfer Syntax `1.2.840.10008.1.2.1` is accepted.
4. Reads are bounds-checked before indexing; parser limits are 256 MiB per
   file, 128 MiB per element, 100,000 elements, and 32 Sequence levels.
5. Pixel Data is stored and written as raw bytes. It is never decoded or edited.
6. Audit events contain only tag, dictionary name, and action - never old values.
7. The input path can never be the output path. Output is staged and reparsed
   before replacement, and existing targets require an explicit `--force`.

## Round-trip policy

The writer emits defined-length Sequences even when the input used undefined
lengths. This is valid for the supported scope: tag order, VR, nested item
structure, retained values, and Pixel Data bytes are preserved, while element
and Sequence lengths are recalculated from the serialized values.

## Non-goals

Version 0.1.0 does not implement compressed pixel decoding, other transfer
syntaxes, DICOM networking, PACS/DICOMweb, OCR, pixel redaction, a complete
DICOM dictionary, diagnosis, or a guarantee of complete anonymization.
