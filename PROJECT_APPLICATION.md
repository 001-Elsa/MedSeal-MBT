# MedSeal-MBT 项目申报书

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 项目名称 | MedSeal-MBT（面向关联医学影像数据集的一致性脱敏与验证工具） |
| 参赛者 | 韩枕 |
| 邮箱 | 766903826@qq.com |
| 手机号 | 17889572851 |
| GitHub 仓库链接 | https://github.com/001-Elsa/MedSeal-MBT |
| Gitlink 仓库链接 | https://gitlink.org.cn/Hzhhhh/MedSeal-MBT |
| Mooncakes 包 | https://mooncakes.io/docs/001-Elsa/medseal |
| 项目方向 | MoonBit 医学影像生态库 / 关联数据处理与验证 |
| 项目类型 | 围绕实际开发需求制作的开发工具（原创 MoonBit 项目） |

## 项目简介
MedSeal-MBT 使用 MoonBit 处理 DICOM 元数据。本次在既有 0.1.1 的 Part 10 解析、嵌套 Sequence、基础脱敏和二进制写回能力上，新增面向关联影像数据集的患者假名、身份 UID 一致映射、完整日期偏移、跨文件引用校验和作业验证。转换后保持患者分组、所选日期间隔和已支持对象引用，交付可复用库 API 与原生命令行。

## 场景与独立贡献
用于合成影像整理、教学、研发联调和受控的元数据转换。生态已有基础 DICOM 解析和字段脱敏项目，本次独立贡献集中在跨文件一致性与可验证的二进制集合输出。RELATED_WORK 与 docs/CONTRIBUTION 明确区分原有基础和新增成果。

## 已实现的核心能力
- Part 10 / Explicit VR Little Endian、ASCII / ISO_IR 192、定义和支持的未定义长度 Sequence。
- 基于来源命名空间、Issuer 和 Patient ID 分组，检查冲突，生成作业内一致假名。
- 分类映射 SOP、Study、Series、Frame 和引用身份 UID；保留标准 Class UID，并同步 File Meta。
- 每患者独立随机偏移所选完整 DA 字段，保持时间间隔；出生日期清空，重复处理被拒绝。
- 检查重复实例、Study/Series 归属、跨患者引用、Class 不匹配与未授权外部引用。
- 重建文件元信息、清零前导区、移除私有元素，保留像素及未修改文本的字节。
- plan / batch / verify：有上限的读取、输入变化检查、暂存输出与审计、清单校验和新目录发布。

## 开源与验证
原创 MoonBit 实现，Apache-2.0；第三方依赖、标准参考与合成数据来源已注明。0.2.0 候选版源码已按功能更新到 GitHub，远程 CI 证据单独记录；GitLink 与 Mooncakes 链接仍为原有基础成果，新版镜像和包发布尚未执行。原深化方案的已完成与未完成项在 docs/PLAN_AUDIT.md 逐项列出。

本地验证包括四后端测试、纯 MoonBit 集合演示，以及 pydicom 独立生成/读取的 16、100、1,000 文件集合。具体计数和实测记录见 ACCEPTANCE.md 与 docs/evidence，不将 CI 配置存在当作远程执行已成功。

## 支持范围
research-v1 限定 CT/MR/Secondary Capture 的已列元数据规则，不实现完整 IOD 或脱敏 Profile。像素内容未被识别或涂抹，未知公共元数据仍需复核；不保证完全匿名化，不提供医疗诊断。跨作业映射、持久化密钥、自动恢复和压缩格式留待独立版本。
