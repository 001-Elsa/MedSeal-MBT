# MedSeal-MBT 项目提交指引

本页将本机 SUBMISSION_GUIDE.md 的示例账号和 MoonL10n 名称替换为韩桢的实际项目，不要求重建仓库、重注册账号或改写历史。适用方向优先为“继续维护已开启的项目／季度优秀社区项目评选”，最终方向按主办方实际入口和本人确认填写。新版[章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)优先于旧示例；不把新项目专属条件无差别套给旧项目。

## 0. 项目和本人信息

| 字段 | 已准备内容 | 提交操作 |
| --- | --- | --- |
| 姓名 | 韩桢（本人已确认） | 按真实证件信息核对 |
| 项目 | MedSeal-MBT：面向关联医学影像数据集的一致性脱敏与验证工具 | 使用既有项目，不重新命名制造“新项目” |
| GitHub | https://github.com/001-Elsa/MedSeal-MBT | 粘贴公开仓库地址 |
| GitLink | https://gitlink.org.cn/Hzhhhh/MedSeal-MBT | 粘贴现有镜像地址 |
| Mooncakes | https://mooncakes.io/docs/001-Elsa/medseal | 粘贴模块首页；版本证据见发行记录 |
| 项目事实 | [PROJECT_APPLICATION.md](../PROJECT_APPLICATION.md) | 姓名已修正，联系方式由本人最终核对 |
| 新增贡献/边界 | [提交材料参考](SUBMISSION_MATERIALS.zh-CN.md)、[贡献说明](CONTRIBUTION.md) | 不重复计算 bb7e895 旧成果；如实说明 AI 辅助 |
| 联系方式/证件/银行卡/开户行/单位 | 只有本人能确认的正式信息 | 仅在官方要求的私有表单填写；不要放公共仓库 |

旧申报 PDF 和过时生成器已从当前提交材料移出，原件在 Git 历史和本机“MedSeal参赛核验/历史申报材料”保留；不要将旧候选版说明作为当前申报上传。

申报事实页和参考材料经过 AI 辅助整理，不冒称本人手写 Proposal。若适用入口要求本人一页人工 Markdown，由本人理解实现后自行撰写；参考材料列出所需事实和问题，不提供伪造的人工声明。主要贡献者、授权来源、历史奖励、一人一项目/团队人数和协议同意，也由本人按真实情况确认。

## 1. GitHub 对照原指南

既有公开仓库使用 001-Elsa，默认分支 master，README.mbt.md、Apache-2.0 LICENSE、ACCEPTANCE.md、CI、源码和完整历史均已具备。不要新建空仓库或改写已有作者历史。

提交前查看 [Actions](https://github.com/001-Elsa/MedSeal-MBT/actions)：最新材料对应的源码检查应成功。[发布与镜像记录](COMPETITION_REMEDIATION.zh-CN.md)区分当前 master 与冻结 Release。

## 2. GitLink 对照原指南

既有仓库使用 Hzhhhh，默认分支 master。同步须保持完整历史且回读实际 HEAD，不用重新导入覆盖旧仓库。公开页面应能看到当前 README、LICENSE、源码与提交历史。

## 3. Mooncakes 对照原指南

发布账号为 001-Elsa，模块名为 001-Elsa/medseal；指南中的 Zhouz-z/moon_l10n 均为示例。历史 0.2.1 已实际发布，并通过真实 registry 消费者核验；0.2.0 原版保留。官方包不可覆盖，同版本归档是冻结快照；后续文档发布必须使用新的补丁版本并重新核验。

检查与安装说明见 [README](../README.zh-CN.md)，真实发布记录见 [整改记录](COMPETITION_REMEDIATION.zh-CN.md)，公开消费者见 [CONSUMER](CONSUMER.zh-CN.md)。准备材料不需要再次注册或在聊天里发送账号凭据。

## 4. 本人完成正式申报

飞书原指南入口：[项目申报表](https://bxup9uklfcb.feishu.cn/share/base/form/shrcn2duseEVtk3e4sTRA8z5Qyf)。官网还链接了[黑客松入口](https://bxup9uklfcb.feishu.cn/share/base/form/shrcnfItHeB1viw56y3cGNGMqub)。本次观察两个表单均显示“该问卷不在填写有效期内，无法提交”，提交按钮禁用；未输入或提交个人资料。由本人选择主办方实际开放、适用的入口完成提交。

“未核实完成”仅表示没有服务端成功回执，发布代码与准备材料不会自动产生报名。本人已明确自行提交，因此这里将状态记为“项目材料准备，正式申报由本人完成”，不宣称已经报名成功。保留提交成功页面/编号或邮件回执，才能将官方提交状态更新为完成。

若赛事实际要求 GitLink 单独提交，在[大赛页面](https://www.gitlink.org.cn/competitions/track1_2026MoonBit)使用现有仓库地址和适用的项目材料；不要将 GitLink 仓库导入成功视为参赛作品提交回执。

## 最后核对

- [x] 实际项目和平台账号一致，姓名为韩桢。
- [x] 安装、用法、示例、能力/风险边界、第三方许可及新增贡献材料有对应文件。
- [x] 项目具备四后端核心与 POSIX 宿主验收、三平台成功 CI、Mooncakes 0.2.1 和独立消费者证据。
- [x] 已保留原项目历史，旧/新贡献与合成/现场证据分别说明。
- [ ] 本人核对联系方式、申报方向、主要贡献者/授权/历史奖励及适用协议。
- [ ] 若该入口要求人工一页 Markdown，本人按规定撰写并上传。
- [ ] 本人填写官方要求的私有证件/金融字段，提交并保存成功回执。

后三项是本人正式申报动作，不是可以通过修改代码自动完成的工程事项。W7 医疗现场验收属于项目后续生产目标，未将其强加为通用参赛门槛。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

当前源码版本为 0.2.2；三平台完整源码同步完成与否以[同步协议](PLATFORM_SYNC.zh-CN.md)所述外置回读报告为准。0.2.1 的消费者与 CI 链接只证明历史版本；本轮回执不追加进已冻结源码。正式申报选择已成功回读的版本。
