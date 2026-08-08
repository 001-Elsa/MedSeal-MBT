# 项目申报书

## 正式信息

- 项目名称：MedSeal-MBT
- 中文名称：MoonBit DICOM 医学影像元数据清理工具
- 参赛者姓名／账号：001-Elsa
- 赛事联系方式：766903826@qq.com
- GitHub 仓库：https://github.com/001-Elsa/MedSeal-MBT
- Gitlink 仓库：导入 GitHub 仓库后填写实际公开链接
- Mooncakes 模块：001-Elsa/medseal

## 项目简介

MedSeal-MBT 是一个使用 MoonBit 编写的轻量级 DICOM Part 10 文件解析、
结构校验和基础元数据脱敏工具。项目仅支持 Explicit VR Little Endian，
能够识别并处理常见直接身份字段、递归处理基础 Sequence、选择性删除
Private Tag、保持 Pixel Data 原始字节，并输出不包含原始敏感值的 JSON
审计报告。

项目不解码压缩图像，不检查 Pixel Data 中烧录的文字，不提供医学诊断，
也不宣称完全匿名化或医疗法规合规。

## 技术与安全特点

- 使用有界 ByteReader，在读取前检查剩余长度。
- 文件、元素、元素数量和 Sequence 深度均有硬限制。
- 不支持的 Transfer Syntax 明确拒绝，不猜测解析。
- 写回采用临时文件、重新解析校验和原子替换。
- CLI 和审计报告均不输出原始患者姓名或编号。
- 测试样本全部由仓库内生成器构造，不包含真实患者数据。

## 本地验收

项目通过 `moon fmt --check`、`moon check --target all --deny-warn`、
`moon test --target all --deny-warn`、`moon info` 和 `moon package`。

