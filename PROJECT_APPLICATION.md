# MedSeal-MBT 项目申报书

面向关联医学影像数据的数据处理库与本地工具集

| 项目 | 内容 |
| --- | --- |
| 参赛者 | 韩桢 |
| 联系方式 | 766903826@qq.com · 17889572851 |
| 项目性质 | 参赛者韩桢的原创项目；本次在本人原有原创项目基础上继续深化迭代 |
| 项目方向 | MoonBit 数据处理与工具库；医学影像元数据场景；既有原创项目深化迭代 |
| 对应版本 | 0.5.0 发行源码；Apache-2.0；0.4.1 为此前公开基线 |
| 材料状态 | 已按当前源码更新的申报事实稿；平台发布状态见本版本外置回读报告；正式申报回执单独记录 |

## 需求与实际价值

研究影像通常是一组相互引用的 DICOM 文件。开发者既要提取字段、筛选、统计和导出，也要检查缺失值、重复实例、患者归属及跨文件引用。逐文件替换姓名可能破坏 Study/Series/SOP 关系和随访日期；自行拼接脚本又容易混淆原值表格与匿名报告。MedSeal 将这些共性处理能力封装为可嵌入的 MoonBit 库，并提供可直接运行的本地工具，服务影像开发者、研究数据管理员和工具作者。

## 当前已实现能力

1. **元数据查询与导出。** `api/query` 支持字段与嵌套 Sequence 路径、严格整数读取、多个条件合取、字段投影、分组计数、CSV/JSONL 和匿名清单。CSV 处理引号、换行与公式前缀；JSONL 区分缺失、空值和多值。表格包含私有原值，不能当作匿名报告分享。
2. **独立质量检查。** `api/quality` 检查对象和集合关系，支持调用方必需字段及同 Series 模态/尺寸/位深差异提示。报告保留原对象编号、稳定代码、位置与建议，并区分 passed、failed、unsupported、not-checked；坏对象不会被丢弃后把剩余子集标为通过。
3. **可配置的集合 SDK。** `api/validation` 保留原集合接口，新增预算下调、按 PatientID+Issuer 绑定日期偏移、不可变字节快照及先计划后执行。执行重新验证整个集合，失败不返回部分结果。
4. **Native 扫描与流式转换。** `api/native` 和 `cmd/data` 提供 summary、quality、export、convert。使用元数据索引、全局身份/引用检查及分块像素复制；新工具无需 Python，作业身份仅限本次处理。源变化、重复执行、已存在或嵌套的输出目录会拒绝；支持对象及提交前边界取消。
5. **格式互操作。** 二进制输入支持 Explicit VR LE 和固定字典内可确定 VR 的 Implicit VR LE 子集，输出规范化为 Explicit VR LE；未知/私有 implicit 字段及歧义拒绝。原有 DICOM JSON 交换支持所列 25 种 VR、PN/多值/Sequence 与精确 DS/IS token，并由独立 pydicom 双向验证。

既有能力继续提供：严格路径/条件/优先级规则、跨批持久身份与增量历史、封存恢复、逐对象审核、Ed25519 签名和本地目录回执、固定 Orthanc 本地接收适配，以及运行同一 MoonBit 核心的离线浏览器只读实验室。这些入口各自有明确保证，不能把私有宿主的审核/签名能力直接归给普通查询或转换。

## 技术实现与生态贡献

九个公共 API 包为 `api/dicom`、`api/dicom_json`、`api/policy`、`api/validation`、`api/explain`、`api/authorization`、`api/query`、`api/quality`、`api/native`。查询、质量与内存集合处理支持 Native、JS、wasm、wasm-gc；目录 I/O 和授权提供方要求 Native。核心格式、规则、身份/时间和关系算法由 MoonBit 实现；Python 3.12 仅用于既有受控 POSIX 私有数据库/密码库/作业协调及开发验收。浏览器运行编译后的同一核心。

提供仅使用公共 API 的完整示例、仓库外归档消费者、稳定错误码、版本化报告 Schema、迁移文档和可重跑门禁。内存集合上限为 256 对象、64 MiB/对象、128 MiB 合计；Native 扫描/计划上限为 10,000 对象、256 MiB/文件、128 MiB/像素、2 MiB 元数据前缀及 64 MiB 元数据索引估算。查询投影至多 10,000 行、64 列及 16 MiB 值文本。限制按入口实施，不以复制缓冲大小承诺总内存。

## 当前可复核的验收证据

2026-10-15 本机 macOS arm64 完整测试：Native 152，JS、wasm、wasm-gc 各 99，全部通过；这些是各后端执行数，不是独立场景总数。固定独立语料 475 例通过、0 跳过；120 个已分类属性、141 个 Rulebook 索引。数据处理独立验收 18 组、既有预检回归 11 组通过；新旧公共消费者分别从归档隔离目录在四后端完成检查、测试和运行，实际二进制由 pydicom 复核，新报告另经 JSON Schema 验证。

Native 新入口对 1/16/64 MiB 像素及 100/1,000 对象分别重复测量三次。64 MiB 转换中位 8.650228 秒、最大子进程 RSS 8.00 MiB；1,000 对象转换中位 4.705223 秒、RSS 20.03 MiB。夹具均为合成数据，未清空缓存，生成和独立读回不计时，不能据此推算临床容量或与不同语义路径计算提速倍数。详细入口、原始记录位置和测量表见[实施与验收账本](docs/DATA_UPGRADE_STATUS.zh-CN.md)。

此前三平台 CI、Orthanc 接收、CT 体素/HU/几何、浏览器与离线安装证据各自绑定其历史版本。本轮 0.5.0 的本地验收及打包核对见实施账本；配置了 CI 不代表远端已运行，新版远端 CI、三平台发布回读与官方申报分别以各自真实回执为准，发布结果写在源码树外。

## 支持边界与后续工作

支持所列 Part 10、字符集 ASCII/ISO_IR 6/ISO_IR 192、Sequence 与元数据子集。经典 CT 研究契约仍限定单帧未压缩 16 位 MONOCHROME2 的既定验证范围；基础解析新增语法不自动扩张 CT 的独立认证。像素保真复制，不做 OCR、像素涂抹或诊断。浏览器私有模式只检查原文件。质量 ready、转换成功或签名有效均不等于像素隐私、完整 IOD/Annex E、完整 DICOMweb 或临床生产通过。真实来源授权、独立研究接收和现场审查保持待取得。

后续优先基于实际输入扩展字典/格式与独立预期、取得真实工具使用反馈，并在冻结源码和对应 CI 完成后分别执行公开发布及正式申报。

## 开源与复现入口

- [GitHub 仓库](https://github.com/001-Elsa/MedSeal-MBT)、[GitLink 镜像](https://gitlink.org.cn/Hzhhhh/MedSeal-MBT)；远端不据本地改动自动视为更新。
- [Mooncakes 0.5.0 入口](https://mooncakes.io/docs/001-Elsa/medseal@0.5.0)；实际可用状态与源码一致性按[同步协议](docs/PLATFORM_SYNC.zh-CN.md)在源码树外核验，旧版不含新增接口。
- 当前源码运行 `tools/moon-local run --target native examples/data_pipeline`，或 `tools/medseal-data summary INPUT_DIR`；完整命令与预算见[数据处理指南](docs/DATA_PROCESSING.zh-CN.md)。
- [迁移说明](docs/MIGRATION_0.5.zh-CN.md)、[公共 API](docs/PUBLIC_API.zh-CN.md)、[支持矩阵](docs/SUPPORT_MATRIX.md)、[文档同步账本](docs/DOCUMENTATION_STATUS.zh-CN.md)、[第三方许可](THIRD_PARTY.md)。

本稿经 AI 辅助整理；事实以当前 0.5.0 本地源码与对应实际记录为准。正式申报由韩桢本人完成，不以本稿替代适用入口要求的本人一页人工 Proposal，也不将材料准备或项目发布写成官方申报成功。
