# MedSeal-MBT 提交材料参考
> **0.6.0 当前边界：** 当前默认入口是 `api/evidence`，用于可验证数据变换证据。本文其余旧版本数字、DICOM流程和历史验收结果按原版本归属，不自动代表新的证据核心。

本页是可核验事实及本人写作/答辩提纲，经过 AI 辅助整理；不代替适用章程要求的本人一页人工 Proposal，不自动确认知识产权、奖励史或协议。

## 可直接填写的项目字段

| 字段 | 内容 |
| --- | --- |
| 姓名 | 韩桢 |
| 项目名 | MedSeal-MBT：面向关联医学影像数据的数据处理库与本地工具集 |
| GitHub | https://github.com/001-Elsa/MedSeal-MBT |
| GitLink | https://gitlink.org.cn/Hzhhhh/MedSeal-MBT |
| Mooncakes 模块 | 001-Elsa/medseal — https://mooncakes.io/docs/001-Elsa/medseal |
| 许可证 | Apache-2.0；第三方许可和标准权利边界见 THIRD_PARTY.md |
| 推荐申报方向 | 维护既有项目、提交新的独立可验证成果；方向由本人最终确认 |

## 本人一页说明需要覆盖的事实

1. **问题和角色。** 影像开发者/研究数据管理员需要处理一组关联 DICOM，而固定字段替换容易破坏患者分组、Study/Series/SOP 引用及日期关系。项目提供查询/筛选/分组/导出、质量检查、转换计划、Native 流式处理、规则解释与可核验交付工具。
2. **已有基础与新增贡献。** bb7e895 / 0.1.1 保留 19 个历史提交。后续新增一致 UID/日期转换、strict 路径/条件/优先级、公共 api/*、持久身份与增量历史、流式恢复、审核/签名/回执、限定 CT 研究检查、独立质量实验室和本地工作台。0.5.0 另增 `api/query`、`api/quality`、`api/native`、命名患者日期及不可变计划、固定字典 Implicit VR LE 输入，共九个公共包。按具体实现与证据说明新增成果，不把全部历史行数当新贡献。
3. **技术职责。** MoonBit 实现 DICOM 解析/规则/变换/写回/关系及公开契约；新增 Native 数据扫描/流式入口无需 Python，身份仅限本作业。Python 3.12 提供既有受控 POSIX 私有数据库、密码库集成、审核/发布/接收协调及回环宿主。公开承认 AI 辅助，不宣称纯 MoonBit 企业全栈。
4. **验收与用途。** 120 属性、141 规则索引、475 固定案例；0.5.0 本机 Native 152、JS/wasm/wasm-gc 各99全部通过；固定语料475例、新数据验收18组、预检11组及新旧四后端隔离归档消费者通过。旧117/64是历史维护基线。三组合成 CT 系列分别验证体素/HU/几何；故障/恢复/签名/离线安装与公开 registry 消费者有证据。旧运行号绑定各自 SHA，不冒称本轮重跑全部测量。
5. **边界与下一步。** 支持所列 Part10/Explicit VR LE 与固定字典 Implicit VR LE 输入，输出 Explicit VR LE；字符集及限定 CT 契约保持声明范围；像素保真复制，不识别或涂抹文字。不声明完整 IOD/Annex E、PACS、压缩/多帧或临床生产。W7 软件演练完成，真实来源授权/研究接收/新操作者/独立审查/灾备仍 requires_field。

当前材料对应 0.5.0 发行源码；旧版 registry/远端 CI 不能证明本轮已发布。实际结果见[数据升级账本](DATA_UPGRADE_STATUS.zh-CN.md)，完整申报事实稿见[项目申报书](../PROJECT_APPLICATION.md)。

## 答辩核对问题

- 为什么映射键需要项目/来源/Issuer，而不能仅凭姓名？相同 SOP 内容冲突如何阻断？
- 缓存 Converted、人工 Reviewed、签名 Published 和目标 Acknowledged 为什么是不同状态？
- 恢复时如何绑定封存源、策略、程序与私有状态，防止旧审核被复用？
- 为什么像素摘要相同、dciodvfy 成功或 Ed25519 有效仍不等于隐私/临床通过？
- 查询原值表格、匿名报告、质量 ready 和转换计划分别保证什么？
- 为什么内存计划固定 Bytes，Native 目录计划还必须核对源文件？取消何时生效？
- 公共 API、无 Python Native 作业和 Python 私有宿主的保证有哪些区别？

事实出处：[场景](USE_CASES.zh-CN.md)、[支持矩阵](SUPPORT_MATRIX.md)、[公共 API](PUBLIC_API.zh-CN.md)、[实施账本](WINNER_UPGRADE_STATUS.zh-CN.md)、[贡献](CONTRIBUTION.md)、[第三方](../THIRD_PARTY.md)、[发布](COMPETITION_REMEDIATION.zh-CN.md)。本人应能按源码与演示回答这些问题，再撰写正式说明。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。


> 当前模块版本：0.6.0。本文中的旧版本数字只表示历史基线；当前默认入口以 `api/evidence` 为准。
