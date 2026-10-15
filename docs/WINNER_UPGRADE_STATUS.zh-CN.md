# W0–W7 升级实施账本

当前源码为 0.5.0 发行源码，C/V 社区能力及数据处理五项增量已实现。当前验收、九个公共包和性能见[数据升级账本](DATA_UPGRADE_STATUS.zh-CN.md)；本页 W0–W7 的计数、CI、归档 SHA 保留原阶段归属，不能作为本轮远端发布结果。

执行依据：[完整方案](WINNER_DRIVEN_ROADMAP.zh-CN.md)与[13 项对标研究](WINNER_RESEARCH.zh-CN.md)。本账本记录实现与实际验收，方案本身不改写为完成报告。原 P0–P7 的范围和未完成项继续保留。

按在线最新版赛事章程的逐条核验见[赛事章程审核](COMPETITION_CHARTER_AUDIT.zh-CN.md)。该审核固定 `2b088d4`，确认工程范围与发布/材料缺口；其中 W6 当时发行清单漏记三项依赖，后续已修复；旧记录仍不视为完整依赖证据。后续修复与平台发布见[整改记录](COMPETITION_REMEDIATION.zh-CN.md)。审核结论不等于报名、官方验收或现场生产认证。

| 阶段 | 当前状态 | 已形成的证据与剩余门槛 |
| --- | --- | --- |
| W0 | 实现、本机验收与三平台远端 CI 通过 | 141 项规则索引、固定官方事实、三值条件、公开解释／Schema／四案例、公共门面与受控状态；Native 115，JS/wasm/wasm-gc 各 62；恢复／审核／签名回归；不扩张为完整 IOD 认证 |
| W1 | 实现、本机 M1/M2 合成验收与三平台 CI 通过 | 初始 473、当前 475 实际案例，六类，零失败/跳过；四后端一致；pydicom 实际写回，选定 SC 的 dciodvfy 原始诊断，闭集合正反例；限定 CT 由 W3 单独验收 |
| W2 | 实现、本机与远端 CI 通过 | 私有缓存／迁移、已交付历史引用、时间精度、outbox 与计数守恒；证据见 `evidence/w2-incremental.json`、`evidence/w2-destination.json`、`evidence/w2-conformance.json`、`evidence/w2-rulebook.json`；[CI 38251118417](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38251118417) |
| W3 | 修正实现、本机独立 CT 验收与核心远端 CI 通过 | `ct-classic-research-v1` 限定矩阵、CT 模块/条件门禁、三组各 50 切片、独立体素／HU／几何接收；证据见 `evidence/w3-ct-research.json`；[CI 38257617635](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38257617635) |
| W4 | 实现、本机与三平台远端 CI 通过 | 独立状态模型、100 个 seed×200 事件、原生策略解析器 100,000 次 fuzz、POSIX 故障与恢复回归；证据见 `evidence/w4-state-model.json`；[CI 38263490405](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38263490405) |
| W5 | 实现、本机静态验收与三平台远端 CI 通过 | 回环本地工作台、精确 Host/Origin、会话 capability 与 CSRF、分页对象清单、受限解释摘要、取消请求闭环；证据见 `WORKBENCH.zh-CN.md`、`evidence/w5-workbench.json`；[CI 38263490405](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38263490405) |
| W6 | 归档与真实 registry 消费者、Mooncakes 0.2.0/0.2.1、GitLink 镜像、最终离线安装与三平台 CI 通过 | 冻结源码 bc5b25c，官方包摘要一致，镜像保留历史快进；[发布源码 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38343632892) 与[发布回读](COMPETITION_REMEDIATION.zh-CN.md) |
| W7 | 软件演练与三平台远端 CI 通过；现场主体材料仍待完成 | 新操作者、真实授权来源、研究接收、独立审查和灾备均有不含敏感数据的结构化模板及验证门禁；模板不能代替现场证据；[CI 38267450046](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38267450046) |

## 历史维护基线（0.2.x）

0.2.1 文档补丁冻结 3e62926，54份 Markdown 已核对；[最终源码三平台 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38363013106)全部成功，实际 registry 消费者通过。0.2.0 及以下各阶段记录保留原 SHA；正式申报由韩桢本人完成。


2c9a49e：Native 117 / JS、wasm、wasm-gc 各 64（309 后端执行）；475 固定案例、141 索引。后文各阶段计数是历史记录。[该基线 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38349000368)三平台通过。最新文档与提交材料见[文档索引](DOCUMENTATION_STATUS.zh-CN.md)和[提交清单](SUBMISSION_GUIDE.zh-CN.md)。

## W0 验收记录

- [公共契约与迁移](PUBLIC_API.zh-CN.md)、[逐规则索引](RULEBOOK_INDEX.zh-CN.md)、[机器账本](../resources/rules/rulebook-v1.json)。
- [本机执行证据](evidence/w0-rulebook.json)包含程序／规则／代码内容指纹、实际四例和九项验收；使用 source_base_commit 明确提交前的基线，内容指纹覆盖变更后的代码。
- 字典比对与条件测试可在四个后端执行；私有审核提供方只承诺已有受控 POSIX Native 范围，Windows 不运行该提供方验收。
- 原审核、签名、独立验签与恢复门禁继续复用；没有新增自动像素放行，没有实际研究交付。
- 修复提交 `4ec37cf67ddd1132bed403f1b51b780fa8a5cb55` 三平台 CI 已读回成功：[不可变运行](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38221826399)，[记录](evidence/w0-ci.json)。
- 首次 W0 提交 `17f3ac4` 的 Linux/macOS 检查通过，Windows 检出的 CRLF 改变规则事实文件摘要，生成漂移检查失败；已加入固定 LF 的仓库属性，保留原摘要门禁；修复提交三平台均通过。

## W1 验收记录

- [运行与范围说明](CONFORMANCE_LAB.zh-CN.md)、[固定语料清单](../conformance/manifest.json)、[本机证据与逐规则矩阵](evidence/w1-conformance.json)。
- 464 个单对象案例与 9 个闭集合案例，共 473 个实际执行，失败 0、跳过 0；480 个必需字节夹具包括集合成员。Native 全套 114 项，JS/wasm/wasm-gc 各 61 项，内嵌语料内逐例计数。
- 140 项规则保留来源与正反例；其中新增文件头身份一致性检查。标记 SC 样例各执行转换前/后独立 IOD 检查，保留全部 Warning 与用途说明。
- 必需文件缺失、字节篡改、预期文件篡改均由实际门禁拒绝；W0 公开边界/提供方九项、持久身份七项、恢复七项回归通过。
- 本机证据绑定变更代码树/二进制/规则/语料/实际依赖指纹，source_base_commit 明确为提交前基线；提交后的最终 SHA 由远端 CI 制品绑定。
- 两项兼容修正：高位标签统一大写；不一致 File Meta 身份按 `file-meta-identity` 结构化拒绝。没有自动像素授权，没有真实来源验收，也未声称完整 CT/MR。

- W1 首次推送 `874caaa` 的 Windows 在规则索引读取中文源文件时采用 CP1252，门禁失败。修复为显式 UTF-8 读写与子进程解码，同时固定集合路径列表为 LF；保留所有核心/差分检查。修复提交 `a7dd6af73b6edf5ad5cc12c1bd7b6393f0a6b480` 三平台均已读回成功：[运行](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38228352839)，[记录](evidence/w1-ci.json)。

## W2 验收记录

- 日期时间解析、对象级缓存与账本迁移已实现。新增 2 个独立字节语料后，475 个案例通过四后端核心检查，失败与跳过均为 0。
- 目的地身份已绑定计划、审核、签名包和本地接收目录；实际端到端演练验证重复交付、逐对象内容寻址、历史引用、目标篡改拒绝和丢失回执重建。
- `tools/verify_incremental.py`、`tools/verify_destination.py`、四后端 conformance、rulebook、持久身份、恢复、风险门和签名接收回归均通过。材料全部为合成私有输入；真实患者、真实操作者、真实接收方、独立审查和远程 PACS 仍保留为现场证据。

## W3 验收记录

- [`ct-classic-research-v1` 矩阵](../resources/rules/ct-classic-research-v1.json) 固定经典 CT、单帧、Explicit VR Little Endian、未压缩 16 位 `MONOCHROME2` 范围；MoonBit 入口 [`check_classic_ct`](../src/conformance/ct_profile.mbt) 逐层检查模块字段、CT 条件、像素位语义、HU 单位和几何向量。
- [`tools/verify_ct_research.py`](../tools/verify_ct_research.py) 实际生成三组各 50 个切片，运行真实批处理后由独立 pydicom 接收器检查排序、解码体素、HU 重算和空间坐标；体素差异为 0，HU 最大绝对误差为 0，几何误差为 0。
- 缺片、重复位置、方向混合、非 HU 单位和压缩传输语法五类负例由独立系列接收器明确阻断；每个对象的 CT 字段也由 MoonBit 批处理路径阻断。证据绑定提交前源码树、Profile、工具和原生二进制指纹；全部数据为合成非临床数据。
- 真实扫描设备、真实来源授权、烧录文字/识别性像素审查、独立研究接收方和临床用途仍保留为 `requires_field`；增强 CT、多帧、压缩像素和任意厂商扩展不在该 Profile 内。

## W4 验收记录

- [`tools/state_model.py`](../tools/state_model.py) 固定作业状态合法转移和发布/签名/审核不变量；[`tools/verify_w4.py`](../tools/verify_w4.py) 执行 100 个 seed、每个 200 个事件，保存接受与拒绝计数及前五个可复现 seed 摘要。
- 同一脚本运行 100,000 次有界 UTF-8/JSON 变异，未解释崩溃和超时均为 0；并运行实际 POSIX 双进程竞争、SIGKILL、写入限制、路径别名、硬链接和权限故障矩阵。
- 状态模型、100,000 次原生策略解析器 fuzz、POSIX 故障矩阵以及转换/审核/发布/接收恢复回归均通过。证据限制为合成输入和本机进程终止，不升级为断电、真实磁盘耗尽或 Windows 认证。

## W5 验收记录

- [`tools/workbench.py`](../tools/workbench.py) 是只绑定 `127.0.0.1` 的薄宿主；真实转换、研究检查、人工复核、签名发布和接收继续复用已有 CLI/状态机，没有第二套转换引擎。
- API 检查精确 `Host`、可选 `Origin`、0600 capability 会话和写请求 CSRF；工作区、作业 ID、owner 文件、分页上限和 JSON 请求体均重新校验。公开响应只返回作业 ID、状态、数量、策略摘要和下一步，不返回本机路径、原始值、映射密钥或日期偏移。
- `tools/verify_workbench.py` 实际覆盖无会话、跨站、分页、对象摘要、路径穿越、错误 CSRF 和取消闭环。GitHub Actions 在 Ubuntu/macOS/Windows 三平台通过；取消端点仅在已认证 POSIX 提供方上运行，Windows 作业仍完成全部核心/静态门禁。
- 本机受限沙箱禁止 TCP 监听，因此本地记录为语法/纯函数验收；三平台回环验收由远端 CI 执行。工作台仍是 M1 合成受控工具，不是多用户网络服务、TLS 终端、真实 PACS 或 W7 现场认证。

## W6 验收记录

- [`examples/consumer`](../examples/consumer) 只导入 `api/policy` 公共门面；[`tools/verify_consumer.py`](../tools/verify_consumer.py) 在临时目录解压当前包归档，复制第三方依赖缓存，构建并运行 `external-consumer`，原始源码 checkout 不在消费者搜索路径中。
- 归档 overlay 的检查、Native 构建和执行均通过；结果只输出策略公共状态，`release_authorized` 固定为 `false`。候选归档使用 `moon.mod` 的 0.2.0 版本来源。
- [`tools/release_readiness.py`](../tools/release_readiness.py) 已记录候选归档的 SHA-256、逐成员摘要、模块/依赖、来源提交和 CI 链接；证据见 [`evidence/w6-release-readiness.json`](evidence/w6-release-readiness.json)。该早期记录的平台观察状态为 `pending-human-observation`；后续正式发布证据已取代其待观察结论。
- 本段保留 W6 当时发布状态。后续真实 Mooncakes registry 消费者、GitLink 镜像与平台回读以[整改记录](COMPETITION_REMEDIATION.zh-CN.md)为准。发布前后核对格式见 [`RELEASE_READINESS.zh-CN.md`](RELEASE_READINESS.zh-CN.md)。

## W7 验收记录

- [`tools/verify_w7_rehearsal.py`](../tools/verify_w7_rehearsal.py) 复用已有隔离运行时演练，覆盖全量、两次新增、强杀恢复、历史内容冲突、包装轮换/备份恢复和幂等接收；三平台 CI 通过，软件记录明确 `field_acceptance_complete:false`，证据见 `evidence/w7-rehearsal.json`。
- [`docs/REHEARSAL.zh-CN.md`](REHEARSAL.zh-CN.md) 提供新操作者逐步清单；[`docs/W7_FIELD_EVIDENCE.zh-CN.md`](W7_FIELD_EVIDENCE.zh-CN.md) 和 [`field-evidence/w7-field-evidence.template.json`](field-evidence/w7-field-evidence.template.json) 提供现场材料模板，`tools/verify_field_evidence.py` 强制五项现场证据、范围和完成标志一致。真实来源授权、研究接收方、新操作者观察、独立隐私/可用性审查和持久存储灾备仍为 `requires_field`，不能由脚本代填。

> 文档核对：本文阶段计数、测量和发行摘要各自绑定原提交；当前状态已核对。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

此前 0.4.1 已包含[完整快照同步](PLATFORM_SYNC.zh-CN.md)，0.2.1 及各 W 阶段固定证据保留原版本。0.2.3 平台/消费者/CI 实际结果由外置同步报告记录，不倒推历史验收。
