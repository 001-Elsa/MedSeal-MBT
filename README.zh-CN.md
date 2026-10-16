# MedSeal-MBT

MedSeal-MBT 是一个用于**可验证数据变换证据**的 MoonBit 库。它把一次变换收据绑定到输入摘要、规则计划摘要和输出摘要，记录逐条来源关系，并让独立验证者发现输入过期、计划变化、输出变化和来源记录不完整。

当前公开方向与数据格式、业务领域无关。证据核心不替调用方清洗、匿名化、生成、同步或发布数据。变换由调用方负责；本库负责记录已声明的内容、输出记录来自哪里，以及结果是否仍然可以被独立核验。

## 0.6.0 公共 API

在 MoonBit 模块中导入 `001-Elsa/medseal/api/evidence`：

```moonbit
import {
  "001-Elsa/medseal/api/evidence" @evidence_api,
}
```

创建计划，为输出记录附加来源，生成收据，然后在另一处验证。完整示例见 `examples/evidence`。

```sh
./tools/moon-local run --target native examples/evidence
```

示例会输出 JSON 收据和独立验证结果。公共 API 保持小而明确：不会自动推断身份、静默修复来源记录，也不会把摘要当成隐私证明。

## 范围与边界

核心支持声明、来源记录、收据序列化和独立绑定检查。CSV、JSONL 及其他格式可以由调用方实现适配器。核心不声称输出已经匿名化、业务上正确、合规或可以公开发布；验证通过只说明输入摘要、计划绑定、输出摘要和来源记录彼此一致。

仓库中的 DICOM 解析、校验和转换代码作为历史成果及可选兼容面保留。它不再是 0.6.0 的默认项目叙事，也不计入新的证据核心功能。详见[公共 API 合同](docs/PUBLIC_API.zh-CN.md)和[迁移说明](docs/MIGRATION_0.6.zh-CN.md)。

## 开发与验证

仓库提供固定的本地 MoonBit 工具入口 `tools/moon-local`：

```sh
./tools/moon-local info
./tools/moon-local fmt
./tools/moon-local check --target native --deny-warn
./tools/moon-local test --target native --deny-warn
```

当前测试覆盖收据绑定、过期输入拒绝、输出变化拒绝和计划不匹配拒绝。旧版 DICOM、应用和赛事证据仍按原版本归属，不会被改写成 0.6.0 的新实测证据。


## 公共入口清单

兼容公共入口：`api/authorization`, `api/dicom`, `api/dicom_json`, `api/evidence`, `api/explain`, `api/native`, `api/policy`, `api/quality`, `api/query`, `api/validation`。其中 `api/evidence` 是 0.6.0 新的默认入口，其他入口保留各自的历史或平台边界。
