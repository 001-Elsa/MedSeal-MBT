# MedSeal-MBT 项目申报书

## 个人信息
- 参赛者：以官方报名问卷填写信息为准；参赛账号：001-Elsa；联系邮箱：766903826@qq.com
- GitHub 仓库：https://github.com/001-Elsa/MedSeal-MBT
- GitLink 仓库：https://gitlink.org.cn/Hzhhhh/MedSeal-MBT
- Mooncakes 包：https://mooncakes.io/docs/001-Elsa/medseal

## 项目简介
MedSeal-MBT 是一个使用 MoonBit 编写的轻量级 DICOM 医学影像元数据解析、结构校验和基础元数据脱敏工具。项目支持 DICOM Part 10 文件与 Explicit VR Little Endian 传输语法，可读取常见数据元素、基础嵌套 Sequence 和 Pixel Data，并在处理后输出新的 DICOM 文件与不包含原始敏感值的 JSON 审计报告。

## 项目方向与适用场景
项目方向属于围绕实际开发需求制作的 MoonBit 开发工具，适用于公开测试数据整理、教学演示、DICOM 文件结构学习、开发联调前的样本清理，以及 MoonBit 在医学影像文件格式解析领域的生态实践。项目避免做医疗诊断、网络服务、PACS、DICOMweb 或像素内容识别，边界清晰、可离线运行。

## 核心功能
- 解析 DICOM Part 10 头、File Meta Information、常用 VR、普通数据元素和基础嵌套 Sequence。
- 校验文件截断、非法 VR、长度越界、Sequence 损坏、不支持 Transfer Syntax 和基础图像元数据风险。
- 替换 Patient Name、Patient ID，清空出生日期、医院、医生、设备序列号等直接身份字段。
- 支持 `--remove-private` 删除 Private Tag，并递归处理 Sequence 内的敏感字段。
- Pixel Data 原样保留，UID 在 0.1.x 版本保留，并在审计报告中明确说明。
- 提供 `inspect`、`validate`、`anonymize` 命令和 JSON 审计报告。

## 项目性质与开源合规
本项目为原创 MoonBit 实现，不是对其他成熟开源项目的移植或复制。仓库采用 Apache-2.0 许可证，第三方依赖和样本来源在 `THIRD_PARTY.md` 与 `samples/README.md` 中说明；测试样本由项目工具人工生成，不包含真实患者隐私信息。项目已同步公开到 GitHub 与 GitLink，并发布至 mooncakes.io。

## 质量与边界
项目核心功能主要由 MoonBit 实现，仓库包含 README、架构说明、更新日志、安全说明、CI、可运行示例和自动化测试。当前版本通过 `moon fmt --check`、`moon check --target all --deny-warn`、`moon test --target all --deny-warn`、`moon build --target native` 与 GitHub Actions。MedSeal-MBT 只做基础元数据脱敏，不检查 Pixel Data 中烧录的个人信息，不保证完全匿名化，也不宣称医疗法规合规。
