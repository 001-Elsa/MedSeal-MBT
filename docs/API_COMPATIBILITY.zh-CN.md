# 0.3.0 API 兼容契约

本页是 V6 的维护契约，面向把 MedSeal 作为依赖安装的 MoonBit 开发者。`0.3.0` 在 `0.2.3` 的公共 API 上增加能力，不改变既有函数的参数和返回类型；内部 `src/` 不是稳定导入路径。MoonBit 本身的工具链兼容另由固定编译器约束，不宣称跨任意工具链稳定。

## 稳定入口

| 模块 | 用途 | 兼容承诺 |
| --- | --- | --- |
| `api/dicom` | Explicit VR Little Endian 读写 | 既有输入拒绝规则保持；不承诺压缩传输语法 |
| `api/dicom_json` | 有界 DICOM JSON 与 Part 10 互转 | 25 种已列 VR；不下载 BulkDataURI |
| `api/policy` | 严格策略编译 | 未知规则继续拒绝 |
| `api/validation` | 单对象与封闭集合转换 | 失败不返回部分集合 |
| `api/explain` | 匿名解释与稳定错误码 | 不输出原值、路径、UID、日期或密钥 |
| `api/authorization` | Native 受信任审核提供方 | 需要宿主重新核验，不能由 JSON 布尔值替代 |

## 版本规则

- 补丁版本修复错误或文档；安全错误修复可能收紧错误接受的输入，须明确记录并补独立反例。
- 次版本可以新增模块、错误码和报告字段；调用方必须忽略未知报告字段。
- 后续破坏既有函数签名或改变既有有效输入的转换语义时提高兼容版本边界并提供迁移说明；0.x 阶段提高次版本，1.x 起提高主版本。放宽安全拒绝须单独列明边界和独立验收。
- 错误消息不是稳定接口；自动化只匹配 `MEDSEAL-E...` 和 `MEDSEAL-W...` 代码。

`0.3.0` 的包内容、工具链和规则指纹固定在发布证据中。旧作业、旧审核和旧缓存绑定其原始指纹，升级不会自动批准或重放它们。

## 消费者最小检查

```sh
moon add 001-Elsa/medseal@0.3.0
moon check --target native --deny-warn
moon run --target native app
```

以上 `app` 的完整文件见 [README](../README.md)。维护者另从源码目录运行 `python3.12 tools/verify_registry_consumer.py --version 0.3.0 --record tmp/registry-0.3.0.json`；它创建独立目录并从 Mooncakes 下载模块，不允许把当前源码当作回退。没有真实 registry 包时命令失败，不把本地成功误记为发布成功。

> 文档核对：本页只描述已实现入口和发布后核验规则；不代表临床适用或正式申报成功。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)。
