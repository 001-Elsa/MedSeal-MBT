# Git hooks

The optional pre-commit hook runs format, all-target checks and tests, then the
documentation contract check. It uses tools/moon-local if the sibling isolated
toolchain exists; otherwise it uses moon from PATH. Python 3.12 is required for
the documentation checker. CI repeats these checks independently.

```sh
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

Installation is local opt-in; the existence of this file does not prove the hook
is enabled. Run git config --get core.hooksPath to inspect your configuration.
Do not disable validation to commit a failing runtime/interface/Markdown change.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](../docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
