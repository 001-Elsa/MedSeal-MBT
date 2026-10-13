# `ct-classic-research-v1` 研究可用性契约

W3 固定一个可复核的经典 CT 范围：CT Image Storage、单帧、Explicit VR Little Endian、未压缩 16 位 `MONOCHROME2`，用于解码体素数组、声明为 HU 的强度统计和三维空间计算。完整字段矩阵在 [`ct-classic-research-v1.json`](../resources/rules/ct-classic-research-v1.json)；实现入口是 [`check_classic_ct`](../src/conformance/ct_profile.mbt)。矩阵通过后还要运行独立的 pydicom 读取器，MoonBit 通过不能替代独立接收。

契约分成四个可单独失败的部分：

- **像素**：读取前后 Pixel Data 字节相同，独立解码后的体素数组逐项相同；`SamplesPerPixel=1`、`BitsAllocated=16`、`HighBit=BitsStored-1`、`PixelRepresentation` 和单帧约束必须成立。
- **强度**：只有 `RescaleType=HU` 且 `RescaleSlope`、`RescaleIntercept` 可解释时才报告 HU；接收器以 `stored * slope + intercept` 独立重算，差异不超过 `1e-6 HU`。其他单位不获得 HU 用途声明。
- **空间**：独立接收器检查方向向量、Pixel Spacing、Image Position、Frame of Reference 和切片排序。方向分量误差目标为 `1e-6`，物理坐标误差目标为 `1e-4 mm`；重复位置、缺片、方向混合、间距异常直接阻断该系列。
- **纵向关系**：系列清单记录项目、私有患者键、Study/Series/SOP UID 关系和日期偏移；原始日期与患者映射只留在私有验收记录中。

验收脚本 [`tools/verify_ct_research.py`](../tools/verify_ct_research.py) 创建三组不同形成方式的合成系列，每组 50 个切片，并加入缺片、重复位置、方向混合、非 HU 和压缩传输语法负例。它运行实际批处理、逐对象重新读取、排序成数组并计算 HU/坐标，再检查所有负例是否阻断。合成系列用于可分享回归，不能冒称三台真实设备或临床认证；真实来源、授权、独立研究接收方和现场责任仍是 `requires_field`。

烧录文字、识别性像素、增强 CT、多帧、压缩像素、厂商私有字段和完整 Annex E 不在本 Profile 内。`release_authorized` 永远保持 `false`，直到独立像素/隐私审查与实际用途验收分别完成。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
