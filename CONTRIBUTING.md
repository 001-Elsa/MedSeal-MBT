# Contributing

Maintain the declared 0.2.0 scope: public MoonBit libraries, compatible CLI,
controlled POSIX private adapters and loopback workbench. Database transactions,
review/signing and local UI are existing components. Changes to compressed pixels,
PACS/network services, diagnosis or full IOD/Profile claims need explicit scope,
independent fixtures and acceptance criteria before those claims enter the README.

Repository issues/PRs are the maintenance channel; the repository owner reviews
behavior and source provenance. No support SLA or production certification is promised.
Record breaking API/schema/tool fingerprints and migration/recovery consequences.
Keep README.md and README.mbt.md synchronized, update the Chinese guide, changelog,
support matrix and executable examples in the same change.

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

Run python3.12 tools/check_documentation.py after updating all affected docs.
The [document index](docs/DOCUMENTATION_STATUS.zh-CN.md) distinguishes current
contracts, original plans and fixed evidence. Keep private-host guarantees out
of compatibility/basic claims. Never overwrite immutable published archives.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
