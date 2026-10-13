# W4 状态、故障窗口与性质验收

[`tools/state_model.py`](../tools/state_model.py) 是独立于 SQLite 协调器的最小参考模型。它把 `CREATED → INGESTED → PLANNED → RUNNING → VALIDATING → AWAITING_REVIEW → READY → PUBLISHING → PUBLISHED → ACKNOWLEDGED` 的合法路径，以及 `CANCELLED`、`FAILED` 的终止/清理路径固定下来。模型在发布前要求审核证据，在可见包前要求签名，在授权前要求两者同时存在；对象数不能为负。

[`tools/verify_w4.py`](../tools/verify_w4.py) 固定 100 个 seed、每个 200 个事件，记录接受/拒绝的转移数；另对有界 UTF-8/JSON 契约输入运行 100,000 次变异，未解释崩溃和超时均为 0。它还运行现有 POSIX 进程/路径故障矩阵，覆盖封存、对象检查点、目录换名、审核、发布、接收和回执窗口。

故障证据只证明本机进程终止和受控目录恢复。真实 HFS+ ENOSPC 曾单独验证（evidence/p0-real-enospc.json）；它不覆盖所有磁盘满窗口。真实断电、Windows 句柄和所有存储系统的持久性仍然是未认证范围；资源报告也不承诺任意 32 GiB 输入具有恒定 RSS。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
