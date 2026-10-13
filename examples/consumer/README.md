# External consumer example

This executable imports only `001-Elsa/medseal/api/policy`. It does not import
any `src/` implementation package. The W6 verifier extracts the local package archive at a temporary module root, overlays an
external-consumer package and copies third-party dependencies. This checks the
archive, not registry publication. `tools/verify_registry_consumer.py` instead
creates an independent module, runs `moon add` and checks the downloaded version
without copying MedSeal source or the local dependency directory.

```sh
moon run --target native examples/consumer
```

Policy compilation is a public API operation. It does not grant IOD, privacy,
pixel or release approval; those remain explicit MedSeal validation and review
gates.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](../../docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
