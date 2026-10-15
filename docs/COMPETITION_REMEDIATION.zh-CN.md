# 赛事章程整改与发布记录

依据 [逐条审核](COMPETITION_CHARTER_AUDIT.zh-CN.md) 的 F01–F07；原审核固定 `2b088d4`，作为历史证据保留。本页记录后续修复，不能把源码无法证明的个人/现场事实改成满足。

| 项目 | 当前整改 | 验证与剩余条件 |
| --- | --- | --- |
| F01 新版公开交付 | GitHub、GitLink 源码与 Mooncakes 0.2.0 已公开；真实 registry 消费者通过 | 官方下载包与冻结归档一致；GitLink 保留历史快进同步，公开远端已回读 |
| F02 文档落后 | 全部受控 Markdown 逐文件核对；当前能力、入口差异、schema/预算/测试与发布事实更新，设计/审计保留历史基线；README 和材料统一 | 安装/公共 API 示例、集合演示与对应验收实际执行；本人手写材料不由自动文档代替 |
| F03 发行清单 | 修复带逗号依赖解析，拒绝缺失/畸形/重复，绑定归档每成员与来源提交 | 正反例通过；旧空依赖清单仅保留历史，替代证据为 `evidence/release-0.2.0-source.json`，平台结果单独记录 |
| F04 场景完整度 | 三个角色的输入、步骤、输出、失败与边界完整说明 | `USE_CASES.zh-CN.md`；预期用途与合成验证，不声明客户采用 |
| F05 第三方记录 | 13 项研究逐项许可/链接/范围、QA 完整依赖许可、标准事实版权边界补充并移除 PS3.15 批量动作表摘录 | `THIRD_PARTY.md`、研究记录和 `resources/licenses`；不把标准公开访问解释成 Apache 授权 |
| F06 个人参赛事实 | 姓名已确认韩桢，飞书由本人提交；项目材料已整理 | 报名、人数/一人一项目、主要贡献者身份、原创贡献说明、历史奖励与本人同意不能由仓库修改证明 |
| F07 现场生产验收 | 保留 requires_field | 真实来源授权、研究接收、新操作者、独立审核/灾备不代填；它们不被章程统一规定为参赛前医院认证 |

## 0.3.0 完整源码同步（V1–V6）

当前源码候选为 0.4.0，纳入 V1–V6 的实现、文档修订和核验记录，并用明确允许清单包含全部仓库文件。详见[同步范围、冻结与回读](PLATFORM_SYNC.zh-CN.md)。实际发布结果写在源码树外，不使用旧版本证据替代本轮确认。DICOM 能力和生产边界不扩张。

## 0.2.1 文档补丁与提交材料（历史已核验）

- 姓名已统一为 **韩桢**；全部 54 份受控 Markdown 的能力、入口、schema、预算、测试和发布状态已核对。文档检查器进入 CI，Windows 默认编码问题已修复为 UTF-8。[文档账本](DOCUMENTATION_STATUS.zh-CN.md)列出全部文件。
- 0.2.1 冻结源码为 `3e6292668871a80d564e04973c2b6a2ce246a431`；[三平台 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38363013106)全部成功，Native117 / 三个其他后端各64。声明的 DICOM 行为未扩张，模块/CLI/SBOM版本来源一致。
- [Mooncakes 0.2.1](https://mooncakes.io/docs/001-Elsa/medseal@0.2.1)已发布，官方包 SHA-256 `af858f347209f8eed3f57a8a6a5119d815db17719fad0e6268d98cc9dabafcc2` 等于冻结归档（854成员）。[独立 registry 消费者](evidence/release-0.2.1-registry-consumer.json)实际下载并输出 `public-policy-ok`；[归档消费者](evidence/release-0.2.1-archive-consumer.json)分别通过。
- macOS ARM64 工程预览包摘要 `4bb032750ae8bef87f4ca71d0ed08e767da94ab71c825f7f6717449e48be51be`，安装清单摘要 `be7f73ee1954fc84bbf1745cdb4a5c6d3bd8ae04d85f190e1269a0d530ae8db8`。[最终离线安装演练](evidence/release-0.2.1-offline-install.json)5项/6对象通过，全部为合成数据。
- GitHub/GitLink 的 `v0.2.1` 同时固定上述源码；GitLink master 保留完整历史快进，公开 HTTPS 回读一致。[发行与平台证据](evidence/release-0.2.1-platforms.json)分项保存，后续文档证据提交不改写冻结包。[GitHub Release](https://github.com/001-Elsa/MedSeal-MBT/releases/tag/v0.2.1)提供模块包、宿主包、校验、CI与消费者/安装证据。
- [提交指南](SUBMISSION_GUIDE.zh-CN.md)与[本人说明参考](SUBMISSION_MATERIALS.zh-CN.md)使用实际账号和项目。旧 PDF/过时生成器已移出当前提交材料并在历史保留。正式表单由本人提交；不将 AI 辅助事实页冒称本人手写，不制造申报回执或现场证据。
- 0.2.0 保留为历史发行；0.2.1 包内文档也是构建时快照，持续平台状态及修订以本仓库 master 为准。升级改变运行时指纹，原固定作业继续使用原包。

## 当前提交范围

维护既有项目，提交公共库、关联转换与限定 POSIX 工程预览；不宣称整个原企业计划全部完成、生产 1.0、完整 IOD/Annex E 或无相似项目。新增贡献、生成代码、Python 宿主如实披露。章程新项目段的本人手写一页材料要求仍由本人负责，不把本轮自动更新事实页冒称本人手写。

## 九项基础验收重新判定

| 审核点 | 本轮结果（限定本页声明范围） | 对应证据 |
| --- | --- | --- |
| 5.1-C1 MoonBit 主要实现 | 满足核心实现与语言边界声明 | CONTRIBUTION，公共 API 与原生核心 |
| 5.1-C2 编码与可维护性 | 检查/测试已通过；不能替代独立全源码审计 | 四后端核心测试，固定语料/生成漂移/错误门禁，CI |
| 5.1-C3 结构和核心功能 | 满足已列转换/一致性/验证功能 | 可执行四对象两引用演示及 P/W 实施证据 |
| 5.1-C4 README 安装/用法/示例 | 已修正 | 三份同步 README，独立消费者、集合演示和操作指南 |
| 5.1-C5 测试 | 已补齐 CT 独立回归 | 四后端、pydicom、固定质量实验室及 CT 正反例 |
| 5.1-C6 CI | 发布源码三平台 CI 已通过 | 运行 38343632892；Windows 核心/静态门禁，POSIX 私有提供方在 Ubuntu/macOS 执行 |
| 5.1-C7 示例 | 已修正并运行 | 集合演示、公共策略示例、USE_CASES 三场景 |
| 5.1-C8 Mooncakes 新版发布 | 0.2.0 已发布并回读验证 | 官方下载摘要一致；独立项目真实 `moon add`、Native 检查/运行通过 |
| 5.1-C9 OSI 许可与来源 | 项目 Apache-2.0，许可/来源记录已补齐 | THIRD_PARTY、固定参考许可、QA 文本；未再分发标准正文或批量动作表 |

## 发布回读

2026-10-13 核验：

- 冻结源码：[`bc5b25c8dafd2fdcde147b08e357061ead14e76e`](https://github.com/001-Elsa/MedSeal-MBT/commit/bc5b25c8dafd2fdcde147b08e357061ead14e76e)。[三平台 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38343632892) 全部成功；本机 Native 117 项，JS/wasm/wasm-gc 各 64 项。Windows 跳过已明示的 POSIX 提供方步骤，不据此声明 Windows 私有宿主可用。
- [Mooncakes 0.2.0](https://mooncakes.io/docs/001-Elsa/medseal@0.2.0) 已发布；[官方包](https://download.mooncakes.io/user/001-Elsa/medseal/0.2.0.zip) SHA-256 为 `ac50fba8f74be8a2b8ee80dbc7f4cf5b29191e97cd5b6a2639d9e831c6c58fbb`，与冻结归档逐字节一致。847 个归档成员绑定上述源码。
- [真实 registry 消费者](evidence/release-0.2.0-registry-consumer.json) 在临时独立 module 中实际下载 0.2.0，检查版本、拒绝本地源码回退，Native 检查及运行输出 `public-policy-ok`。[归档消费者](evidence/release-0.2.0-archive-consumer.json) 使用同一冻结包通过。
- macOS ARM64 工程预览离线发行包 SHA-256 为 `65757654378298e2b0da6cb34bc553b4c8e95a8a8a06f97c61960e64588ac7be`；安装清单 SHA-256 为 `ed68b99add719f3bc13ca100ea02bfc105406a7880b2fb842813a7f914d797d4`。[实际隔离安装演练](evidence/release-0.2.0-offline-install.json) 通过三批、六对象、五项检查；全部为合成数据。
- [源码发行清单](evidence/release-0.2.0-source.json) 是发布前冻结证据，保留其候选状态；[发布后平台回读](evidence/release-0.2.0-platforms.json) 记录真实结果。后续证据提交不作为 0.2.0 包的源码提交，不重复发布同版本。
- [GitHub v0.2.0 工程预览发行](https://github.com/001-Elsa/MedSeal-MBT/releases/tag/v0.2.0) 固定上述源码提交，附模块包、macOS ARM64 宿主包、校验清单与独立安装/消费者证据。
- [GitLink](https://gitlink.org.cn/Hzhhhh/MedSeal-MBT) 已保留全部历史，从旧 master `bb7e895900dbaf55e13651460906044df50b12fe` 快进到发布证据提交 `56f83fb784be19e132d72f9fbe3d37e34605a881`；公开 HTTPS 远端已回读一致。`v0.2.0` 标签固定到发布源码 `bc5b25c`。本页后续镜像证据提交与冻结版本分别记录，不改变 Mooncakes 0.2.0 包。
- 发布证据提交 `56f83fb` 的[三平台 CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38344639434) 也已全部成功。

先前 CI 的 CT 缺 NumPy、离线演练密码库指纹不一致、规则报告未刷新三个失败已修复；未降低原验收门禁。F06 的姓名已确认，正式表单及剩余个人声明由本人完成，见[提交清单](SUBMISSION_GUIDE.zh-CN.md)。F07 真实现场证据保持 requires_field。

包内本文是构建时快照；发布后的持续回读记录位于 [GitHub 当前记录](https://github.com/001-Elsa/MedSeal-MBT/blob/master/docs/COMPETITION_REMEDIATION.zh-CN.md)，不会改写已经发布版本的归档字节。

> 文档核对：本文阶段计数、测量和发行摘要各自绑定原提交；当前状态已核对。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
