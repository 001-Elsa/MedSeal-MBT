# MoonBit 七月获奖项目逐项研究与 MedSeal 对标

研究日期：2026-10-12。对象：官网名单全部 13 项；MedSeal 基线：`6800741`。

结论：继续深化 MedSeal，比换题或堆叠功能更合理。下一轮应把它做成**可解释、可验证、保持研究可用性的 DICOM 数据准备工具库与本地工作台**。核心差异是“规则依据 → 字段动作 → 研究可用性 → 审核 → 可验证交付”的完整证据链。这里是研究建议，尚未实现新一轮功能。

## 研究范围与证据方法

- 名单依据[官方开源大赛页面](https://moonbitlang.github.io/OSC2026/#winners)。对应七月验收的开源大赛；不是另一个七月月度黑客松排行榜。
- 官网前四项仅标“晋级决赛、争夺一二等奖”，其余九项三等奖。没有查到前四项最终名次及逐项目评委评分，因此不编造“为什么拿一等奖”。
- 官网提出完成度、MoonBit 生态贡献、工程质量和展示表现等维度；本地 ZIP 章程也强调复用、文档、开源与维护。未见数值评分权重。
- 所有项目保存了当前与历史固定提交。历史取当前默认分支在 `2026-07-17T15:59:59Z` 之前最近可达提交，只是历史近似，**不是官方申报 SHA 或确定的获奖评审版本**。当前演示的能力不得倒推到历史。
- 13 项均阅读说明与选定的核心源码、测试、协议或 CI；这是有证据的逐项对标，不是全库安全审计。没有安装/运行获奖项目代码，也没有重跑它们的测试。性能、覆盖率和“production ready”声明保留为作者陈述。
- 下载归档和展开有大小限制；拒绝路径越界，跳过符号链接；资料存于工作区 `research/七月获奖项目对标/`，不并入 MedSeal 源码发行。
- 证据分三类：**作者声明**（README/状态文件）、**源码可见**（本报告固定 SHA 链接）、**本次操作观察**（四个当前演示页）。MedSeal 既有测试结果引用项目内证据，本轮没有重新执行功能测试。

## 13 项对照总表

| 官方状态 | 项目 | 最值得借鉴 | 对应升级 |
| --- | --- | --- | --- |
| 晋级决赛 | [MoUI](https://github.com/wzzc-dev/MoUI) | 能力证据矩阵、仓库外消费者 | W0 / W6 |
| 晋级决赛 | [aitne](https://github.com/Arcelyth/aitne) | 响应式状态与失效清理 | W5 |
| 晋级决赛 | [MoonFrame](https://github.com/ihb2032/MoonFrame) | 差分性质测试、计数语义 | W1 / W4 / W5 |
| 晋级决赛 | [Frontier Lab](https://github.com/shop1111/FrontierLab) | 首次错误、状态差异、可解释轨迹 | W0 / W5 |
| 三等奖 | [tokenizers-moonbit](https://github.com/howtomakeaname/tokenizers-moonbit) | 独立兼容对照、必需夹具门禁 | W1 |
| 三等奖 | [markitdown](https://github.com/ZSeanYves/markitdown) | 质量与性能共同验收 | W1 / W3 / W4 |
| 三等奖 | [moon_graphql](https://github.com/Eisem/moon_graphql) | 规范覆盖矩阵与部分支持声明 | W0 / W1 / W3 |
| 三等奖 | [MoonBit Hex Editor](https://github.com/R00TK17/moonbit-HexEditor) | 结构树与字节位置联动 | W5 |
| 三等奖 | [moonsic](https://github.com/hyl-star/moonsic) | 领域类型与分级结果 | W0 / W6 |
| 三等奖 | [linear-algebra](https://github.com/Luna-Flow/linear-algebra) | 不变量与 provider 分离 | W3 / W4 |
| 三等奖 | [MoonCharts](https://github.com/pxgt/mooncharts) | 可移植匿名 SVG 报告 | W5 |
| 三等奖 | [raft-moonbit](https://github.com/Lfan-ke/raft-moonbit) | 确定性故障事件与提交顺序 | W4 |
| 三等奖 | [MoonMarkMind](https://github.com/Xiao-li-He/MoonMarkMind) | 同一核心的库、应用和离线导出 | W5 / W6 / W7 |

## 逐项研究

### 1. MoUI：多平台声明式 GUI 与显式渲染管线

历史快照：`5bb64bbdb43e7e58ee8f4518741d82720da9762e`。

**核对到的做法。** 把代码路径可用、真实平台运行证据、产品完整承诺分开；外部消费者脚本把样例复制到仓库外，检查解析出的依赖不来自 monorepo，再编译和测试。源码证明该检查机制存在，本轮没有验证其远端 CI 运行。

**可借鉴。** 成熟度应当由能力与证据矩阵表达；库必须能被仓库外的新项目使用。

**对 MedSeal 的具体动作。** MedSeal 增加按 Profile、平台、安装、接收用途划分的能力声明；从真实发行归档和 Mooncakes 各建立独立消费者，检查不能偷偷引用本地 src。

**边界。** 不照搬六端平台承诺，也不为了一个审核工作台引入整个原生 GUI/渲染栈。

固定源码证据：

- [README.mbt.md · 1–45 行](https://github.com/wzzc-dev/MoUI/blob/5bb64bbdb43e7e58ee8f4518741d82720da9762e/README.mbt.md#L1-L45)
- [docs/platform-readiness-declaration.md · 8–47 行](https://github.com/wzzc-dev/MoUI/blob/5bb64bbdb43e7e58ee8f4518741d82720da9762e/docs/platform-readiness-declaration.md#L8-L47)
- [scripts/external-consumer-ci.mjs · 135–173 行](https://github.com/wzzc-dev/MoUI/blob/5bb64bbdb43e7e58ee8f4518741d82720da9762e/scripts/external-consumer-ci.mjs#L135-L173)
- [.github/workflows/external-consumer.yml · 10–35 行](https://github.com/wzzc-dev/MoUI/blob/5bb64bbdb43e7e58ee8f4518741d82720da9762e/.github/workflows/external-consumer.yml#L10-L35)

### 2. aitne：MoonBit 响应式 Web 组件、Router 与开发 CLI

历史快照：`b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399`。

**核对到的做法。** Memo 保存上下游订阅、失效状态及清理 owner；测试覆盖菱形依赖和动态分支切换。README 明确 WIP，历史 CLI 支持面与 CI 主要为 Linux/macOS。

**可借鉴。** 交互应用需要明确的数据依赖和失效机制；状态变化不能靠界面猜测。

**对 MedSeal 的具体动作。** 工作台订阅同一个作业状态和规则报告，策略、输出或授权变化立即使旧审核失效。先用小型 MoonBit Web 视图完成体验，再评估是否引入 aitne。

**边界。** 不把框架成熟度当成 MedSeal 安全保证；不在浏览器另外实现脱敏算法。

固定源码证据：

- [README.mbt.md · 1–100 行](https://github.com/Arcelyth/aitne/blob/b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399/README.mbt.md#L1-L100)
- [src/reactive/memo.mbt · 12–91 行](https://github.com/Arcelyth/aitne/blob/b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399/src/reactive/memo.mbt#L12-L91)
- [src/reactive/memo_test.mbt · 34–111 行](https://github.com/Arcelyth/aitne/blob/b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399/src/reactive/memo_test.mbt#L34-L111)
- [.github/workflows/ci.yml · 13–73 行](https://github.com/Arcelyth/aitne/blob/b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399/.github/workflows/ci.yml#L13-L73)

### 3. MoonFrame：DataFrame、表达式与延迟查询的数据处理库

历史快照：`0285e6041cc9d216e5297e7de3189bb862fe43d9`。

**核对到的做法。** 列投影采用显式工作栈；优化器的差分性质测试把 lazy 与 eager 比较，域包含 null、NaN、正负零，并收缩反例；join 测试明确未匹配行和 null 的语义。README 说明 collect 仍物化，不能等同流式引擎。

**可借鉴。** 结果可比性、缺失值语义和非空洞性质验证比增加统计函数更有价值。

**对 MedSeal 的具体动作。** 建立导入/复用/拒绝/待审核/交付计数账本及一致性检查，输出匿名质量统计；采用生成式测试检查有界流式与既有内存路径的语义一致。

**边界。** 不把 MoonFrame 接到像素主链路，也不为简单计数强制引入 DataFrame。

固定源码证据：

- [README.md · 115–150 行](https://github.com/ihb2032/MoonFrame/blob/0285e6041cc9d216e5297e7de3189bb862fe43d9/README.md#L115-L150)
- [lazy/optimize_projection.mbt · 1–75 行](https://github.com/ihb2032/MoonFrame/blob/0285e6041cc9d216e5297e7de3189bb862fe43d9/lazy/optimize_projection.mbt#L1-L75)
- [lazy/optimize_fuzz_test.mbt · 1–82 行](https://github.com/ihb2032/MoonFrame/blob/0285e6041cc9d216e5297e7de3189bb862fe43d9/lazy/optimize_fuzz_test.mbt#L1-L82)
- [frame/join_test.mbt · 39–84 行](https://github.com/ihb2032/MoonFrame/blob/0285e6041cc9d216e5297e7de3189bb862fe43d9/frame/join_test.mbt#L39-L84)

### 4. Frontier Lab：语义轨迹、契约检查与时间回溯调试

历史快照：`26814a6abed16bee040cdd8b0c097708a1b58988`。

**核对到的做法。** TraceViolation 带契约、代码、步骤、目标和证据；ContractReport 带首次错误与截取窗口；测试给出 compare 非法改变顺序的具体反例。当前在线演示也能比较 expected/actual 并定位 step 10，但这是后续部署，不能当作历史版本验收。

**可借鉴。** 把“检查失败”变成能够定位、复现和理解的因果证据。

**对 MedSeal 的具体动作。** 规则执行轨迹记录字段路径、规则 ID、标准出处、条件判定、动作与验证结果；一键定位首个阻断，生成不含原始患者值的解释报告。

**边界。** 不把病例原值、原始 UID、日期偏移、输入摘要或本机路径塞进公开 trace；局部窗口不冒称最小反例。

固定源码证据：

- [trace_contracts.mbt · 1–121 行](https://github.com/shop1111/FrontierLab/blob/26814a6abed16bee040cdd8b0c097708a1b58988/trace_contracts.mbt#L1-L121)
- [trace_debugger_test.mbt · 104–159 行](https://github.com/shop1111/FrontierLab/blob/26814a6abed16bee040cdd8b0c097708a1b58988/trace_debugger_test.mbt#L104-L159)
- [ACCEPTANCE.md · 5–44 行](https://github.com/shop1111/FrontierLab/blob/26814a6abed16bee040cdd8b0c097708a1b58988/ACCEPTANCE.md#L5-L44)

### 5. tokenizers-moonbit：兼容 Hugging Face 配置的 MoonBit tokenizer

历史快照：`2046a45ef93ac769b4dc9e7482b6091afbf08fbd`。

**核对到的做法。** 差分测试由 Python tokenizers 生成期望，MoonBit 逐 token 对比；源码列表有 39 个模型，但夹具缺失会返回 ran=false，普通测试可跳过。CI 另抓取 gpt2/bert/t5 做 smoke。本轮没有重跑全模型，也没有把 README 的兼容声明当作验证结果。

**可借鉴。** 兼容性需要独立参考实现和固定语料；必需夹具缺失不得形成绿色假象。

**对 MedSeal 的具体动作。** DICOM 实验室分开 parser/writer 差分、标准符合性、脱敏策略预期和像素/几何不变量；发布门禁核对必需夹具清单，缺失即失败。

**边界。** 不用 pydicom 可读取代替脱敏合规；不把“39 模型”类比成 MedSeal 支持 39 种影像。

固定源码证据：

- [README.md · 1–95 行](https://github.com/howtomakeaname/tokenizers-moonbit/blob/2046a45ef93ac769b4dc9e7482b6091afbf08fbd/README.md#L1-L95)
- [src/integration/parity_test.mbt · 1–58 行](https://github.com/howtomakeaname/tokenizers-moonbit/blob/2046a45ef93ac769b4dc9e7482b6091afbf08fbd/src/integration/parity_test.mbt#L1-L58)
- [scripts/gen_parity.py · 53–79 行](https://github.com/howtomakeaname/tokenizers-moonbit/blob/2046a45ef93ac769b4dc9e7482b6091afbf08fbd/scripts/gen_parity.py#L53-L79)
- [.github/workflows/ci.yml · 109–145 行](https://github.com/howtomakeaname/tokenizers-moonbit/blob/2046a45ef93ac769b4dc9e7482b6091afbf08fbd/.github/workflows/ci.yml#L109-L145)

### 6. markitdown：多文档格式到 Markdown 的原创转换与质量实验室

历史快照：`7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4`。

**核对到的做法。** 路由测试明确拒绝不支持的 accurate/stream 组合；基准选择器统计被 limit 排除的项；报告分别表达 trust/gate、comparable、fidelity mismatch、CLI/engine geomean。大规模语料与速度数字仍是仓库报告，本轮未复测。

**可借鉴。** 转换器必须同时证明语义质量、资源使用和测试覆盖范围，不能只讲速度。

**对 MedSeal 的具体动作。** 每次 MedSeal 质量运行固定语料、依赖、策略、二进制和来源级别；分别报告像素/几何/时间/引用质量，以及 RSS、吞吐、临时空间和失败恢复。

**边界。** 不从合成小对象基准推出真实 CT 容量；不为了格式数量扩张到所有 DICOM SOP。

固定源码证据：

- [README.md · 1–115 行](https://github.com/ZSeanYves/markitdown/blob/7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4/README.md#L1-L115)
- [convert/route_probe_wbtest.mbt · 46–117 行](https://github.com/ZSeanYves/markitdown/blob/7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4/convert/route_probe_wbtest.mbt#L46-L117)
- [bench/runner/manifest/selector_gate_wbtest.mbt · 13–44 行](https://github.com/ZSeanYves/markitdown/blob/7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4/bench/runner/manifest/selector_gate_wbtest.mbt#L13-L44)
- [bench/runner/report.mbt · 69–172 行](https://github.com/ZSeanYves/markitdown/blob/7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4/bench/runner/report.mbt#L69-L172)

### 7. moon_graphql：基于固定规范的 parse/validate/print 语言工具库

历史快照：`0923ce52c28af4022f17485496b6af1a4653d2d6`。

**核对到的做法。** 把语法、语义和 runtime 范围分开，列 Supported/Partial/Not implemented，并提供按规则组织的正反例。ValidationError 当前是 message+ty，不能说它已实现丰富的字段位置证据。

**可借鉴。** 固定标准版本、公开部分支持范围、按条款组织测试，是可信标准库的基础。

**对 MedSeal 的具体动作。** 生成 DICOM Rulebook：标准章节/表行→条件→实现→正反例→运行证据；SC 与 CT 分开认证，针对 Type 1/2/1C/2C、VR/VM 与 Sequence 上下文检查。

**边界。** 不把固定字典里的属性条数写成完整 IOD/Annex E 认证；不照搬 GraphQL 的规则来判断医学字段。

固定源码证据：

- [CONFORMANCE.md · 1–54 行](https://github.com/Eisem/moon_graphql/blob/0923ce52c28af4022f17485496b6af1a4653d2d6/CONFORMANCE.md#L1-L54)
- [validation/validation.mbt · 1–36 行](https://github.com/Eisem/moon_graphql/blob/0923ce52c28af4022f17485496b6af1a4653d2d6/validation/validation.mbt#L1-L36)
- [validation/conformance_test.mbt · 6–64 行](https://github.com/Eisem/moon_graphql/blob/0923ce52c28af4022f17485496b6af1a4653d2d6/validation/conformance_test.mbt#L6-L64)
- [lexer/conformance_test.mbt · 10–32 行](https://github.com/Eisem/moon_graphql/blob/0923ce52c28af4022f17485496b6af1a4653d2d6/lexer/conformance_test.mbt#L10-L32)

### 8. MoonBit Hex Editor：字节编辑、结构解析与 Native TUI

历史快照：`7a3e9d5d38c1a16f45b30b6dbea72aee869b23b2`。

**核对到的做法。** 结构节点携带 offset、size、name、value、children，并按文件 magic 路由；测试检查修改、插入、删除、复合粘贴的 undo/redo。Native TUI 和库的能力边界明确。

**可借鉴。** 结构树与字节位置联动能让二进制工具可解释、可排错。

**对 MedSeal 的具体动作。** 为只读 DICOM 检查器提供 Sequence 路径、VR/VM、长度、受限字节位置及错误定位；大像素显示跨度信息，避免整文件加载。

**边界。** 不提供直接修改原始封存影像的入口；私有 hex 视图不可出现在公开 demo 或离线公开报告。

固定源码证据：

- [README.md · 1–100 行](https://github.com/R00TK17/moonbit-HexEditor/blob/7a3e9d5d38c1a16f45b30b6dbea72aee869b23b2/README.md#L1-L100)
- [hex_struct.mbt · 1–46 行](https://github.com/R00TK17/moonbit-HexEditor/blob/7a3e9d5d38c1a16f45b30b6dbea72aee869b23b2/hex_struct.mbt#L1-L46)
- [cmd/main/tui_edit_wbtest.mbt · 73–147 行](https://github.com/R00TK17/moonbit-HexEditor/blob/7a3e9d5d38c1a16f45b30b6dbea72aee869b23b2/cmd/main/tui_edit_wbtest.mbt#L73-L147)

### 9. moonsic：领域类型、音乐 IR、校验与多资产导出

历史快照：`ae98a436f85e9c7c0b878c18bc5bd26c401f368d`。

**核对到的做法。** ValidationIssue 以 severity/code/path/message 表达领域错误，不同 profile 使用明确选项；流水线可把某个导出失败记为 warning，同时保留其他可用资产。

**可借鉴。** 域模型和结果状态应当进入类型；失败不能被一个布尔“成功”抹平。

**对 MedSeal 的具体动作。** MedSeal 公共 API 引入 ValidatedObject、ConvertedObject、ReviewEvidence、AuthorizedPackage 等受控类型；报告区分可查看、可转换、可审核和可交付。

**边界。** 不照搬音乐流水线“有任一可用资产就成功”的放宽原则；医学交付缺必需对象/审核时仍整体阻断。

固定源码证据：

- [packages/validation/validation_types.mbt · 5–50 行](https://github.com/hyl-star/moonsic/blob/ae98a436f85e9c7c0b878c18bc5bd26c401f368d/packages/validation/validation_types.mbt#L5-L50)
- [packages/validation/validation_options.mbt · 5–63 行](https://github.com/hyl-star/moonsic/blob/ae98a436f85e9c7c0b878c18bc5bd26c401f368d/packages/validation/validation_options.mbt#L5-L63)
- [packages/demo/demo_pipeline.mbt · 6–94 行](https://github.com/hyl-star/moonsic/blob/ae98a436f85e9c7c0b878c18bc5bd26c401f368d/packages/demo/demo_pipeline.mbt#L6-L94)
- [packages/demo/demo_test.mbt · 6–40 行](https://github.com/hyl-star/moonsic/blob/ae98a436f85e9c7c0b878c18bc5bd26c401f368d/packages/demo/demo_test.mbt#L6-L40)

### 10. linear-algebra：代数能力接口、可变/不可变容器与后端分离

历史快照：`a85b6ba32bee07f8b942ef1bc26b4fc3d8f15f64`。

**核对到的做法。** 可变与不可变实现有跨包一致性测试，检查空矩阵、维度和操作语义；checked 运算返回 Result，unchecked 为显式入口；通用算法通过读/构建能力参数适配容器。

**可借鉴。** 用不变量和显式能力边界验证算法，不依赖几个漂亮样例。

**对 MedSeal 的具体动作。** 性质测试涵盖同域身份稳定、跨域隔离、合法时间间隔、像素不变、引用完整和几何一致；密码/数据库/文件系统保留 provider 边界。

**边界。** 不为 CT 的少量向量计算引入 OpenBLAS；不重写 AES/Ed25519 以追求纯语言占比。

固定源码证据：

- [src/consistency/core_wbtest.mbt · 1–117 行](https://github.com/Luna-Flow/linear-algebra/blob/a85b6ba32bee07f8b942ef1bc26b4fc3d8f15f64/src/consistency/core_wbtest.mbt#L1-L117)
- [src/immut/matrix.mbt · 402–434 行](https://github.com/Luna-Flow/linear-algebra/blob/a85b6ba32bee07f8b942ef1bc26b4fc3d8f15f64/src/immut/matrix.mbt#L402-L434)
- [src/container/generic_algorithms_wbtest.mbt · 15–67 行](https://github.com/Luna-Flow/linear-algebra/blob/a85b6ba32bee07f8b942ef1bc26b4fc3d8f15f64/src/container/generic_algorithms_wbtest.mbt#L15-L67)

### 11. MoonCharts：纯 MoonBit 数据到 SVG 图表

历史快照：`b11795eea77bf5f5d2293103f1b54f0f4edc322b`。

**核对到的做法。** 刻度代码处理退化范围并按索引生成刻度，避免连续浮点累积；边界测试覆盖空、单点、同值和不等长系列。不过 valid_svg 只检查首尾标签，不能把它当作完整 XML/渲染验证。当前在线 SVG 首屏可见。

**可借鉴。** 可移植输出和边界处理有价值，但图表正确性仍需要独立校验。

**对 MedSeal 的具体动作。** 质量报告优先采用无需外网的 SVG：批次处置计数、阻断类别、资源趋势；文本计数与图表共用同一个账本。

**边界。** 不公开小群体病人统计；不增加与脱敏决策无关的图表。包名以实际 registry 为准，当前网页已使用 Xpeng/mooncharts。

固定源码证据：

- [ticks.mbt · 1–58 行](https://github.com/pxgt/mooncharts/blob/b11795eea77bf5f5d2293103f1b54f0f4edc322b/ticks.mbt#L1-L58)
- [edge_cases_test.mbt · 1–106 行](https://github.com/pxgt/mooncharts/blob/b11795eea77bf5f5d2293103f1b54f0f4edc322b/edge_cases_test.mbt#L1-L106)
- [docs/api.md · 1–70 行](https://github.com/pxgt/mooncharts/blob/b11795eea77bf5f5d2293103f1b54f0f4edc322b/docs/api.md#L1-L70)

### 12. raft-moonbit：etcd Raft 移植、确定性模拟与故障不变量

历史快照：`31221c15d61b7c1910d0633271e4e5c17559152e`。

**核对到的做法。** 移植台账说明测试来源与 N/A；非测试入口明确 persist→apply→advance 顺序；seeded chaos 在崩溃、重启、分区后逐步检查安全谓词。README 的测试数、覆盖率和差分缺陷数没有在本轮复测；当前在线 demo 链接为 404。

**可借鉴。** 持久化协议要用可复现事件序列和逐步不变量验证，覆盖率不能代替正确性。

**对 MedSeal 的具体动作。** 为 MedSeal 作业/发布/回执建立 MoonBit 状态机与参考模型，枚举提交前后窗口；保存失败 seed 和事件序列，辅以真实进程终止及空间不足验证。

**边界。** 不引入 Raft 集群；不把内存模拟、SIGKILL 成功说成 APFS 断电持久性认证。

固定源码证据：

- [PORTING.md · 1–25 行](https://github.com/Lfan-ke/raft-moonbit/blob/31221c15d61b7c1910d0633271e4e5c17559152e/PORTING.md#L1-L25)
- [core/rawnode_driver.mbt · 17–45 行](https://github.com/Lfan-ke/raft-moonbit/blob/31221c15d61b7c1910d0633271e4e5c17559152e/core/rawnode_driver.mbt#L17-L45)
- [core/chaos_wbtest.mbt · 1–87 行](https://github.com/Lfan-ke/raft-moonbit/blob/31221c15d61b7c1910d0633271e4e5c17559152e/core/chaos_wbtest.mbt#L1-L87)
- [core/sim_check.mbt · 1–84 行](https://github.com/Lfan-ke/raft-moonbit/blob/31221c15d61b7c1910d0633271e4e5c17559152e/core/sim_check.mbt#L1-L84)

### 13. MoonMarkMind：Markdown 模型、可复用渲染包与浏览器应用

历史快照：`fe2568132baf76bab7a3cdfc9d9f0740e0d29044`。

**核对到的做法。** 模型/渲染/应用/CLI 共用规则；验收列出用户能照做的完整路径。导出 HTML 使用 SafeHtml/转义及链接检查，测试包含 script/onerror/javascript 输入。当前网页编辑区和脑图首屏可见，未测试导出。

**可借鉴。** 库和面向实际用户的应用可以同时交付；离线导出也属于安全边界。

**对 MedSeal 的具体动作。** 同一 MoonBit 核心驱动 CLI、本地工作台和自包含审核报告；新操作者根据手册完成转换、复核、签名、独立接收。

**边界。** 不照搬脑图外观；不为了 PNG 导出把浏览器依赖带进服务端发布链路；不允许报告加载远程图片。

固定源码证据：

- [docs/SPEC.md · 5–18 行](https://github.com/Xiao-li-He/MoonMarkMind/blob/fe2568132baf76bab7a3cdfc9d9f0740e0d29044/docs/SPEC.md#L5-L18)
- [docs/ACCEPTANCE.md · 24–41 行](https://github.com/Xiao-li-He/MoonMarkMind/blob/fe2568132baf76bab7a3cdfc9d9f0740e0d29044/docs/ACCEPTANCE.md#L24-L41)
- [lib/markdown_render/markdown_render.mbt · 124–184 行](https://github.com/Xiao-li-He/MoonMarkMind/blob/fe2568132baf76bab7a3cdfc9d9f0740e0d29044/lib/markdown_render/markdown_render.mbt#L124-L184)
- [packages/markdown_to_html/markdown_to_html_test.mbt · 55–65 行](https://github.com/Xiao-li-He/MoonMarkMind/blob/fe2568132baf76bab7a3cdfc9d9f0740e0d29044/packages/markdown_to_html/markdown_to_html_test.mbt#L55-L65)

## 这些项目共同提示了什么

第一，生态价值来自可复用能力。MoUI、MoonFrame、GraphQL、moonsic、MoonMarkMind 的应用或示例都围绕库组织。MedSeal 应让外部项目直接调用解析、规则、验证、解释与统计，而不是只能运行一套复杂私有脚本。

第二，成熟度来自明确且可检验的承诺。支持矩阵、迁移台账、固定规范、负例与差分测试可以复核；代码行数、测试数量、漂亮演示或覆盖率单独都不能证明标准符合或真实落地。

第三，展示需要让人直接理解核心能力。Frontier 的错误定位、Hex Editor 的结构导航、Charts 的实时图形、MoonMarkMind 的编辑首屏都有具体动作。MedSeal 的演示应呈现一组影像的规则处理、风险阻断、修正后重新审核、签名与独立接收，不能只展示终端通过日志。

第四，值得学的不是所有功能。获奖状态并不抹去边界：可选夹具跳过、图表的浅层 SVG 检查、框架 WIP、网页 404，都提示我们建立自己更明确的验收门槛。

这是对工程做法的归纳，不是对评委实际评分原因的推断。这 13 项没有同题的 DICOM 脱敏工程；它也不能证明整个 Mooncakes 或所有新参赛项目都没有类似方向。

## MedSeal 当前能力与差距

以项目内 `docs/ENTERPRISE_STATUS.md` 和 `docs/evidence/enterprise-acceptance.json` 为当前依据：P0–P7 已实现许多核心，但原计划完整验收仍未全达成。

| 能力 | 已有基础 | 本轮定位出的下一步 |
| --- | --- | --- |
| 严格策略 | 未知字段阻断、路径条件与优先级、固定字典、策略摘要 | 条款/条件/实现/测试逐项关联；丰富条件与完整限定 Profile |
| 审计解释 | 字段 path/rule/action 事件、公开配置摘要 | 类型化条件推导、规则出处、首个失败、可分享且无原值的报告 |
| 跨批身份 | 私有 SQLite、认证加密、来源/项目隔离、内容/归属冲突 | 转换缓存与交付去重、已交付历史引用闭环、日期时间精度语义 |
| 格式与容量 | 单帧单色未压缩 8/16 bit、Native 像素流式 | 经典 CT 系列限定 Profile、HU/几何/用途验收、代表性体积 |
| 恢复与交付 | 封存输入、私有检查点、SIGKILL 恢复、审核绑定、签名和目录回执 | 状态机模型、提交全窗口故障、不变量/模糊测试、真实接收用途 |
| 可用性与发布 | CLI、离线工程预览及安装后合成演练 | 本地工作台、稳定公共 API、外部消费者、版本/镜像/包同步 |

本轮额外核对的基线源码：

- `src/conformance/profile.mbt:174` 明说所列字段/模块子集；CT/MR 仅硬编码部分必需字段，不是完整 IOD。
- `src/policy/compiler.mbt:2` 的 PathRule 目前为 id/path/action/priority/sop/present；不具备完整标准条款元数据与条件证明。
- `src/identity/transform.mbt:95` 有 UID 与完整 DA 变换事件；`src/date/date.mbt:16` 只解析完整八位日期。
- `tools/private_store.py:156` 的 registry 检查重复内容及历史归属，没有表示“已转换/已审核/已交付”的完整历史对象账本。
- `src/verification/collection.mbt:45` 的 allow_external 接受并计数未在本批的引用；没有据此核实该目标在历史交付域存在。
- `tools/enterprise_job.py:137` 以字符串状态记录转移；已有恢复防护仍值得保留，下一轮增加显式状态模型与合法转移契约。
- README 公开包路径仍包含 `/src/`；目前没有 Web 工作台。源码候选 0.2.0，而公共发布状态文件仍记录 Mooncakes 0.1.1。

既有证据记录 Native 103 项、另外三个后端各 53 项；120 MiB 合成像素 Native 峰值 RSS 约 29 MiB，最终 10,000 小对象约 187 MiB / 94 秒。它们证明限定版本与合成负载的结果，不能替代真实 CT 来源、研究可用性或生产验收。本轮未重跑这些数字。

## 建议的项目定位

一句话：**MedSeal 在本地把 DICOM 研究数据准备成可追踪规则、保持纵向关系和影像用途、经责任审核并可独立验收的交付包。**

主用户：研究数据管理员、脱敏审核者、接收数据的研究工程师。优先场景：受控目录中的经典单帧 CT 系列，去除身份信息并保持像素、HU、空间几何和允许的随访间隔；已有 SC 工程预览继续保留，MR 扩展等独立阶段认证。

主实现继续是 MoonBit：DICOM 解析、规则编译/执行、身份语义、验证、轨迹和状态模型。密码、SQLite、系统安装和进程协调使用成熟适配器。稳定假名及私有映射意味着仍需按受控研究数据处理，不能自动等同不可逆匿名化或任何机构认证。

完整执行顺序、产物、提交批次和量化验收见 [获奖项目对标升级方案](WINNER_DRIVEN_ROADMAP.zh-CN.md)。

## 资料索引

- [官方名单](https://moonbitlang.github.io/OSC2026/#winners)；在线演示观察说明见下文。
- [机器可读逐项结论与精选源码哈希](evidence/winner-research.json)
- 双版本 SHA 与全体已提取文件哈希清单：工作区 `research/七月获奖项目对标/inventory.json`。
- 本地 ZIP 章程提取文本：工作区 `research/七月获奖项目对标/local-charter.md`；[官网章程入口](https://moonbitlang.github.io/OSC2026/)。

所有第三方源代码只作为研究资料保存。若未来实际采用代码/依赖，应固定版本并保留许可证和来源说明；本轮没有复制它们的实现进入 MedSeal。

在线演示观察：2026-10-12，Frontier 当前 Trace Clinic 完成内置错误诊断；MoonCharts 的 SVG 与示例调用可见；MoonMarkMind 的编辑区和脑图首屏可见；raft-moonbit README 提供的 GitHub Pages demo 链接返回 404。未验证所有交互和导出，未将当前部署当作历史评审证据。详细原始观察保存在工作区 `research/七月获奖项目对标/official-observation.md`。原始归档与完整文件清单不随本仓库发布。

## 逐项研究参考许可

许可证来自研究证据固定的 july17 快照根 LICENSE，链接绑定同一 SHA；该表不是运行依赖表，不把研究借鉴当作移植。

| 项目 | 固定来源/许可文本 | 许可 | 参考范围 |
| --- | --- | --- | --- |
| MoUI | [wzzc-dev/MoUI](https://github.com/wzzc-dev/MoUI/blob/5bb64bbdb43e7e58ee8f4518741d82720da9762e/LICENSE) | Apache-2.0 | 仅研究 W0, W6 工程方法；不复制实现 |
| aitne | [Arcelyth/aitne](https://github.com/Arcelyth/aitne/blob/b1ab95444fcbedccb3ab2ca382d8c7ec01ad4399/LICENSE) | MIT | 仅研究 W5 工程方法；不复制实现 |
| MoonFrame | [ihb2032/MoonFrame](https://github.com/ihb2032/MoonFrame/blob/0285e6041cc9d216e5297e7de3189bb862fe43d9/LICENSE) | Apache-2.0 | 仅研究 W1, W4, W5 工程方法；不复制实现 |
| Frontier Lab | [shop1111/FrontierLab](https://github.com/shop1111/FrontierLab/blob/26814a6abed16bee040cdd8b0c097708a1b58988/LICENSE) | MIT | 仅研究 W0, W5 工程方法；不复制实现 |
| tokenizers-moonbit | [howtomakeaname/tokenizers-moonbit](https://github.com/howtomakeaname/tokenizers-moonbit/blob/2046a45ef93ac769b4dc9e7482b6091afbf08fbd/LICENSE) | Apache-2.0 | 仅研究 W1 工程方法；不复制实现 |
| markitdown | [ZSeanYves/markitdown](https://github.com/ZSeanYves/markitdown/blob/7e6e1c89fdbcdd87ed7dcb508f051b16e5c4e3d4/LICENSE) | Apache-2.0 | 仅研究 W1, W3, W4 工程方法；不复制实现 |
| moon_graphql | [Eisem/moon_graphql](https://github.com/Eisem/moon_graphql/blob/0923ce52c28af4022f17485496b6af1a4653d2d6/LICENSE) | Apache-2.0 | 仅研究 W0, W1, W3 工程方法；不复制实现 |
| MoonBit Hex Editor | [R00TK17/moonbit-HexEditor](https://github.com/R00TK17/moonbit-HexEditor/blob/7a3e9d5d38c1a16f45b30b6dbea72aee869b23b2/LICENSE) | Apache-2.0 | 仅研究 W5 工程方法；不复制实现 |
| moonsic | [hyl-star/moonsic](https://github.com/hyl-star/moonsic/blob/ae98a436f85e9c7c0b878c18bc5bd26c401f368d/LICENSE) | Apache-2.0 | 仅研究 W0, W6 工程方法；不复制实现 |
| linear-algebra | [Luna-Flow/linear-algebra](https://github.com/Luna-Flow/linear-algebra/blob/a85b6ba32bee07f8b942ef1bc26b4fc3d8f15f64/LICENSE) | Apache-2.0 | 仅研究 W3, W4 工程方法；不复制实现 |
| MoonCharts | [pxgt/mooncharts](https://github.com/pxgt/mooncharts/blob/b11795eea77bf5f5d2293103f1b54f0f4edc322b/LICENSE) | Apache-2.0 | 仅研究 W5 工程方法；不复制实现 |
| raft-moonbit | [Lfan-ke/raft-moonbit](https://github.com/Lfan-ke/raft-moonbit/blob/31221c15d61b7c1910d0633271e4e5c17559152e/LICENSE) | Apache-2.0 | 仅研究 W4 工程方法；不复制实现 |
| MoonMarkMind | [Xiao-li-He/MoonMarkMind](https://github.com/Xiao-li-He/MoonMarkMind/blob/fe2568132baf76bab7a3cdfc9d9f0740e0d29044/LICENSE) | Apache-2.0 | 仅研究 W5, W6, W7 工程方法；不复制实现 |
