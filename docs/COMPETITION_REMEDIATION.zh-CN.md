# 赛事章程整改与发布记录

依据 [逐条审核](COMPETITION_CHARTER_AUDIT.zh-CN.md) 的 F01–F07；原审核固定 `2b088d4`，作为历史证据保留。本页记录后续修复，不能把源码无法证明的个人/现场事实改成满足。

| 项目 | 当前整改 | 验证与剩余条件 |
| --- | --- | --- |
| F01 新版公开交付 | GitHub 源码、Mooncakes 0.2.0 已公开；真实 registry 消费者通过 | 官方下载包与冻结归档一致；GitLink 网页已登录，仍待 Git 推送凭据与快进回读 |
| F02 文档落后 | README 英文/中文/Mooncakes 包文档统一；申报事实、维护指南、变更/贡献更新，旧记录标历史 | 安装/公共 API 示例、集合演示与对应验收实际执行；本人手写材料不由自动文档代替 |
| F03 发行清单 | 修复带逗号依赖解析，拒绝缺失/畸形/重复，绑定归档每成员与来源提交 | 正反例通过；旧空依赖清单仅保留历史，替代证据为 `evidence/release-0.2.0-source.json`，平台结果单独记录 |
| F04 场景完整度 | 三个角色的输入、步骤、输出、失败与边界完整说明 | `USE_CASES.zh-CN.md`；预期用途与合成验证，不声明客户采用 |
| F05 第三方记录 | 13 项研究逐项许可/链接/范围、QA 完整依赖许可、标准事实版权边界补充并移除 PS3.15 批量动作表摘录 | `THIRD_PARTY.md`、研究记录和 `resources/licenses`；不把标准公开访问解释成 Apache 授权 |
| F06 个人参赛事实 | 本人提交前核实 | 报名、人数/一人一项目、主要贡献者身份、原创贡献说明、历史奖励与本人同意不能由仓库修改证明 |
| F07 现场生产验收 | 保留 requires_field | 真实来源授权、研究接收、新操作者、独立审核/灾备不代填；它们不被章程统一规定为参赛前医院认证 |

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
- GitLink 已确认账号 Hzhhhh 登录及 owner 权限，既有 master `bb7e895900dbaf55e13651460906044df50b12fe` 是发布源码祖先；网页没有既有仓库同步入口，Git 推送仍缺凭据，暂不声明镜像已更新。

先前 CI 的 CT 缺 NumPy、离线演练密码库指纹不一致、规则报告未刷新三个失败已修复；未降低原验收门禁。F06 个人事实、F07 真实现场证据继续待本人/现场完成。

包内本文是构建时快照；发布后的持续回读记录位于 [GitHub 当前记录](https://github.com/001-Elsa/MedSeal-MBT/blob/master/docs/COMPETITION_REMEDIATION.zh-CN.md)，不会改写已经发布版本的归档字节。
