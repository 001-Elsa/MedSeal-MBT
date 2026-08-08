# Contributing

Contributions must remain inside the documented 0.1.x scope. Do not add
diagnosis, networking, PACS, databases, web interfaces, OCR, or compressed
pixel decoding without a separately reviewed scope change.

Before submitting a change:

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native
moon info
moon package
```

Every parser branch and bug fix needs a focused regression test. Expected
failures must use stable `MEDSEAL-E...` or `MEDSEAL-W...` codes and include
safe context such as offset and tag where available. Never log or place an
original patient value in an assertion, snapshot, report, or issue.

Only public, synthetic, or confirmed de-identified DICOM files may be added.
Document every sample's source or generator in `samples/README.md`.
