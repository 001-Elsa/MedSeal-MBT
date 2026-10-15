# 0.5.0 发行源码 API 兼容契约

> 0.5.0发行源码新增查询/质量/计划/Native SDK及固定字典Implicit VR LE；本页旧阶段记录保留其原版本，当前增量见[数据处理指南](DATA_PROCESSING.zh-CN.md)。

本页是 V6 的维护契约，面向把 MedSeal 作为依赖安装的 MoonBit 开发者。`0.5.0` 在 `0.4.1` 的公共 API 上增加能力，不改变既有函数的参数和返回类型；内部 `src/` 不是稳定导入路径。MoonBit 本身的工具链兼容另由固定编译器约束，不宣称跨任意工具链稳定。

## 稳定入口

| 模块 | 用途 | 兼容承诺 |
| --- | --- | --- |
| `api/dicom` | Explicit VR LE / 固定字典 Implicit VR LE 输入，Explicit VR LE 输出 | implicit 为新增接受；未知/私有 Tag 或歧义拒绝；裸 Dataset 仍 explicit |
| `api/dicom_json` | 有界 DICOM JSON 与 Part 10 互转 | 25 种已列 VR；不下载 BulkDataURI |
| `api/policy` | 严格策略编译 | 未知规则继续拒绝 |
| `api/validation` | 单对象、封闭集合与不可变转换计划 | 原签名保留；新增命名患者偏移和只下调预算；失败不返回部分集合 |
| `api/explain` | 匿名解释与稳定错误码 | 不输出原值、路径、UID、日期或密钥 |
| `api/authorization` | Native 受信任审核提供方 | 需要宿主重新核验，不能由 JSON 布尔值替代 |
| `api/query` | 类型化路径、合取筛选、投影/分组、CSV/JSONL、匿名清单 | `QUERY-*` 稳定错误码；表格输出含私有原值 |
| `api/quality` | 对象/集合、必需字段和 Series 差异检查 | 四类检查状态；ready 不等于交付授权 |
| `api/native` | Native 扫描、质量与流式目录作业 | 无需 Python；单次作业、边界取消、新目录提交 |

## 版本规则

- 补丁版本修复错误或文档；安全错误修复可能收紧错误接受的输入，须明确记录并补独立反例。
- 次版本可以新增模块、错误码和报告字段；调用方必须忽略未知报告字段。
- 后续破坏既有函数签名或改变既有有效输入的转换语义时提高兼容版本边界并提供迁移说明；0.x 阶段提高次版本，1.x 起提高主版本。放宽安全拒绝须单独列明边界和独立验收。
- 错误消息不是稳定接口；自动化只匹配 `MEDSEAL-E...`、`MEDSEAL-W...` 和查询的 `QUERY-*` 代码。

`0.4.1` 的包内容、工具链和规则指纹固定在发布证据中。旧作业、旧审核和旧缓存绑定其原始指纹，升级不会自动批准或重放它们。

当前 0.5.0 的新增接受、写出规范化及预算见[迁移](MIGRATION_0.5.zh-CN.md)与[数据指南](DATA_PROCESSING.zh-CN.md)。没有取得本轮 registry 回执，新增 API 先按[消费者说明](CONSUMER.zh-CN.md)从候选源码归档验收。

## 此前公开 0.4.1 的消费者最小检查

```sh
moon add 001-Elsa/medseal@0.4.1
moon check --target native --deny-warn
moon run --target native app
```

以上 `app` 的完整文件见 [README](../README.md)。维护者另从源码目录运行 `python3.12 tools/verify_registry_consumer.py --version 0.4.1 --record tmp/registry-0.4.1.json`；它创建独立目录并从 Mooncakes 下载模块，不允许把当前源码当作回退。没有真实 registry 包时命令失败，不把本地成功误记为发布成功。

> 文档核对：本页只描述已实现入口和发布后核验规则；不代表临床适用或正式申报成功。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)。
