# DICOM JSON 数据交换（C3a 源码增量）

目标：让已有 Python/影像工具的元数据进入 MoonBit 程序，并可写回二进制，不要求调用者自行解释多值、姓名、序列和十进制。`api/dicom_json` 只做私有格式交换；当前已发布的 0.2.3 不含这个新增包。

## 公共接口和实际流程

导入 `001-Elsa/medseal/api/dicom_json`，提供三个纯内存接口：

```moonbit nocheck
let dataset = @dicom_json.decode(private_json)
let normalized_private_json = @dicom_json.encode(dataset)
let private_part10 = @dicom_json.to_part10(private_json)
```

`decode` 返回公开 `api/dicom.DataSet`；`encode` 返回单个 Dataset 的 JSON 对象（不是对象数组）。`to_part10` 新建 Explicit VR Little Endian 文件头，要求单值 SOP Class/Instance UID，写回后由实际二进制解析器复核结构和字符集。非 ASCII 二进制内容必须在 Dataset 中明确指定 `ISO_IR 192`；JSON 自身使用 UTF-8 不会自动替它设置源字符集。File Meta、原 preamble 和原传输语法不由 Dataset JSON 保留。

编码输出按 Tag 升序排列，属性成员按 `vr`、值表示排列；不宣称 RFC 8785。DS/IS 统一输出字符串以保留十进制字面文本，包括末尾零、指数形式和负零。不得对含原值的这个 JSON 直接签发公开报告。

完整集合示例 [examples/consumer](../examples/consumer/main.mbt) 已经过：公开类型构造合成 SC → 二进制解析 → JSON 编码 → JSON/Part 10 写回 → 严格集合转换 → 输出验证。JSON 桥不代替最后两步。

```sh
moon run --target js examples/consumer
moon build --target js examples/dicom-json
python3.12 tools/verify_dicom_json.py --record tmp/c3-dicom-json-ci.json
python3.12 tools/verify_consumer.py tmp/c3-consumer.json
```

`examples/dicom-json` 提供 JS ESM 的 `exchange(mode, input)` 示例：`canonical` 输入私有 JSON、`to_part10` 输出私有十六进制字节、`from_part10` 反向转换。成功返回字符串 JSON `{ok:true,value:...}`，拒绝仅 `{ok:false}`；宿主负责 I/O、内存和保密。它不是浏览器 UI 或 HTTP 服务。Node 宿主见 [dicom_json_bridge.mjs](../tools/dicom_json_bridge.mjs)。

## 明确支持的子集

参考 DICOM **PS3.18 2025e F.2**，共 25 种 VR；语义范围不等于完整 IOD 或所有 VR 字段词法验证。

| 范围 | 输入、输出及规范化 |
| --- | --- |
| Dataset | 大写八位十六进制 Tag；不接受重复 Tag/属性成员，包括转义后重复；禁止 Group Length、0002 File Meta、FFFE delimiter |
| AE/AS/CS/DA/DT/LO/SH/TM/UC/UI | `Value` 字符串数组；按 DICOM 反斜杠分隔多值；单个 JSON 值不能含分隔符；不在格式桥中验证每种 VR 的全部业务词法/VM |
| LT/ST/UT/UR | 一个字符串，反斜杠作为内容保留；不按多值拆分 |
| PN | 对象数组；仅 Alphabetic/Ideographic/Phonetic 三组；可缺 Alphabetic；组内最多五个 `^` 分隔的姓名组成部分、64 个 UTF-16 码元；中文支持；不保留无意义的尾部空表示组 |
| DS/IS | 数值字符串或有限 JSON number；保留原始数值 token，不能先经过 Double 舍入再恢复；DS 长度 ≤16/合法十进制语法/有限值，IS 长度 ≤12/有符号32位整数；IS 数值 token 的小数或指数形式拒绝 |
| US/SS/UL/SL | 仅 JSON 整数 token；范围分别为无符号16/有符号16/无符号32/有符号32位；不接受字符串、null、小数或指数 token（即便数学值是整数） |
| SQ | `Value` 中每项是 Dataset；空 item `{}`；无 Value 表示空 SQ；兼容 pydicom 3.0.1 的空 SQ `Value:[]` 并规范化为省略 Value，这是明确接受的兼容形态 |
| OB/OW/UN | 仅 canonical base64 `InlineBinary`；字节逐一保留，不自动补零；要求偶数字节长度；OW 为 little endian 字节序；不转换压缩片段/网络 BulkData |
| 空值/空位置 | 空属性输出只有 `vr`；文本多值中的 null/空字符串规范化为 null；单个空文本值、空 PN 对象、空 InlineBinary 规范化为空属性；SQ 外的 `Value:[]` 拒绝 |

明确拒绝：SV/UV、AT、FL/FD、OD/OF/OL/OV、未知 VR、`BulkDataURI`、未知属性键、多种值表示并存、根数组、数值 VR 中的 null。不忽略不支持字段；需要它们时应先扩展模型与独立预期。

数字词法保护使用内部标记，原始输入任何对象中的 `__medseal_exact_number__` 键（包括转义拼写）均拒绝；合法 DICOM JSON 不需要这个键。

## 预算和错误边界

- 输入/输出 JSON UTF-8 各至多 8 MiB；单文本值 1 MiB。
- SQ 嵌套至多 16；Dataset、元素、值与条目共享 20,000 计数预算。
- 每个 InlineBinary 解码后 ≤1 MiB；编码前先检查大小和对齐。
- 原文预检深度 64、数值 token ≤20,000、容器 ≤40,002、成员 ≤80,001；在标准解析器合并键和舍入数值前拒绝重复键并保留数值原文。
- 编解码还实施 8 MiB 保守分配预算：节点开销按128字节、文本按 UTF-8 长度六倍计费；因此接近文本大小上限的高转义/多节点内容可能提前拒绝。这是边界，不保证任意 8 MiB 文本均可处理。

所有拒绝使用类型化 `MedSealError::InvalidModel`，仅固定开发者编写的原因，不拼接输入值/Tag 字符串/路径/URI。没有文件写入、网络访问、脱敏、IOD 审批或发布权限。对私人 JSON 的保护由调用方负责；对外解释继续使用 `api/explain`。

## 独立验收与边界

`tools/verify_dicom_json.py` 用固定 **pydicom 3.0.1** 生成25种VR的合成 Dataset，调用真实 MoonBit JS 编译产物：

1. pydicom JSON → MoonBit → pydicom，逐值比较。
2. MoonBit 写 Part 10 → pydicom，检查 File Meta、像素、序列和文字。
3. pydicom 写 Part 10 → MoonBit JSON → pydicom，反向独立验证。
4. 五个额外数字 token 在任何浮点读取前检查原文，防止独立读取器本身的浮点舍入掩盖错误；22个不支持/错误输入必须拒绝。

核心新增11个场景覆盖四后端；归档消费者进一步检查两份关联 SC 输出的实际字节。固定输入和源码摘要写入临时证据；这不表示真实患者数据验收、第三方实际采用、全部 DICOM JSON 或 DICOMweb 支持。

官方条款：[F.2.2 Dataset](https://dicom.nema.org/medical/dicom/2025e/output/chtml/part18/sect_F.2.2.html)、[F.2.3 Value Representation](https://dicom.nema.org/medical/dicom/2025e/output/chtml/part18/sect_F.2.3.html)、[F.2.4 Value multiplicity](https://dicom.nema.org/medical/dicom/2025e/output/chtml/part18/sect_F.2.4.html)、[F.2.5 Empty values](https://dicom.nema.org/medical/dicom/2025e/output/chtml/part18/sect_F.2.5.html)。后续实际任务见[应用价值计划](APPLICATION_VALUE_PLAN.zh-CN.md)。
