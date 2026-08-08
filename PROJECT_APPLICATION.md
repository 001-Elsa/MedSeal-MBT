# MedSeal-MBT 项目申报书

- 项目名称：MedSeal-MBT（MoonBit DICOM 医学影像元数据清理工具）
- 参赛账号：001-Elsa；联系方式：766903826@qq.com
- 项目方向：MoonBit 医学影像文件处理工具 / 格式解析与安全写回
- GitHub：https://github.com/001-Elsa/MedSeal-MBT
- Mooncakes：https://mooncakes.io/docs/001-Elsa/medseal
- 项目性质：原创实现，未移植或复制其他开源项目

## 项目简介与适用场景
MedSeal-MBT 是 MoonBit 编写的轻量级 DICOM Part 10 解析、结构校验和基础元数据脱敏工具，面向开发测试、教学演示和数据交付前的直接身份字段清理。它仅接受 Explicit VR Little Endian，不支持的格式会明确拒绝，避免猜测解析医疗文件。

## 核心功能与技术路线
- 安全解析 File Meta、常用 VR、定义/未定义长度 Sequence，并对文件、元素、数量和嵌套深度设硬限制。
- 检查截断、长度越界、非法 VR/UI/文本字段和基础图像元数据，输出稳定错误码。
- 替换或清空患者、机构、医生等直接身份字段，递归处理 Sequence，可选删除 Private Tag。
- Pixel Data 和 UID 原样保留；审计 JSON 不记录任何原始敏感值。
- 写入临时文件后重新解析校验，再原子替换目标；提供 inspect、validate、anonymize CLI。

## 交付与质量
交付公开源码、Apache-2.0 许可证、合成 DICOM 样本、可运行 CLI、JSON 审计示例、三平台 CI、全后端检查与核心回归测试，并发布 `001-Elsa/medseal@0.1.1`。项目不提供诊断，不检查像素中烧录文字，也不宣称完全匿名化或医疗法规合规。
