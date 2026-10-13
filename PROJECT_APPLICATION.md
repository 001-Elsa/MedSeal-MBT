# MedSeal-MBT 项目申报书

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 项目名称 | MedSeal-MBT（面向关联医学影像数据集的一致性脱敏与验证工具） |
| 参赛者 | 韩桢 |
| 邮箱 | 766903826@qq.com |
| 手机号 | 17889572851 |
| GitHub 仓库链接 | https://github.com/001-Elsa/MedSeal-MBT |
| Gitlink 仓库链接 | https://gitlink.org.cn/Hzhhhh/MedSeal-MBT |
| Mooncakes 包 | https://mooncakes.io/docs/001-Elsa/medseal |
| 项目方向 | MoonBit 医学影像生态库 / 关联数据处理与验证 |
| 项目类型 | 围绕实际开发需求制作的开发工具（原创 MoonBit 项目） |

## 当前项目范围与申报材料性质

本页更新可核验的项目事实，不代替章程要求的本人手写 Proposal 或个人声明。既有项目 0.1.1 基线和历史保留；建议按旧项目维护/季度社区贡献路径说明新增成果。参赛者姓名已由本人确认是韩桢；联系方式、主要贡献者身份、报名方向、历史奖励和协议声明仍由本人提交时核实。正式表单由本人提交，仓库不宣称已有成功回执。按[提交清单](docs/SUBMISSION_GUIDE.zh-CN.md)使用真实账号和项目链接。

MedSeal-MBT 的新增贡献是关联 DICOM 的元数据一致转换和可验证交付：公共 MoonBit API、严格规则与解释、集合身份/日期/引用、持久跨批缓存和历史引用、恢复、逐对象审核/签名/接收、限定经典 CT 研究 Profile、固定独立质量实验室与本地工作台。MoonBit 承担 DICOM/规则/转换与公开契约；Python 3.12 承担私有事务、密码库和系统协调。

## 三个完整预期场景

[场景文档](docs/USE_CASES.zh-CN.md)逐项列出角色、输入、步骤、输出、失败与验收证据：影像开发者批量联调、纵向研究增量导入、工具作者嵌入公共规则/验证/解释 API。用途以合成测试证明实现可运行，没有虚构临床客户或医院采用。

## 验证、开源和交付

[README](README.zh-CN.md)提供安装、运行、公共 API 和完整示例；[实施账本](docs/WINNER_UPGRADE_STATUS.zh-CN.md)保存每阶段源码和验证证据；[整改记录](docs/COMPETITION_REMEDIATION.zh-CN.md)保存 GitHub/GitLink/Mooncakes 实际发布状态。[贡献说明](docs/CONTRIBUTION.md)区分历史基线、新增手写/生成代码和宿主语言；[第三方来源](THIRD_PARTY.md)列出依赖、标准与研究参考。许可证为 Apache-2.0。

## 承诺范围

仅支持所列 Part 10/Explicit VR Little Endian/字符集与元数据规则，经典 CT 单帧未压缩 16 位 Profile 有独立体素/HU/几何合成验证。MR/SC 不声明完整 IOD；像素未识别/涂抹，未知公共元数据需审查。跨批映射、密钥持久化和恢复已通过工程宿主实现；真实来源授权、独立研究接收、操作者与现场灾备仍为 requires_field。不承诺完整匿名化、医疗诊断、PACS、压缩像素或生产 1.0。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
