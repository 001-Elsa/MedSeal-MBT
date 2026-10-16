# 公共 API 合同

当前 0.6.0 的新公共入口是 `001-Elsa/medseal/api/evidence`。它提供变换计划、来源记录、收据和独立验证，不提供通用数据清洗或匿名发布授权。

## `Plan`

`Plan::new` 接收调用方的计划标识、输入摘要、规则摘要、工具版本和有序步骤。步骤只记录声明，不会被库自动执行。

## `OutputRecord` 与 `SourceRef`

`OutputRecord` 包含输出记录标识、输入来源数组和发生变化的字段。`SourceRef` 包含来源文件或数据集名称、来源记录标识和步骤标识。空的输出记录标识在验证时会失败。

## `Receipt`

`Receipt::new` 将输出摘要、输入记录数、输出记录、被丢弃记录和警告绑定到计划。`Receipt::to_json` 输出 `medseal-evidence-receipt-v1` 结构。

## `Receipt::verify`

验证器重新比较计划标识、规则摘要、输入摘要和输出摘要，并检查来源记录的基本完整性。可能的错误码包括：

- `SCHEMA`：收据版本不支持；
- `PLAN_MISMATCH`：收据与验证计划不一致；
- `INPUT_CHANGED`：输入摘要变化；
- `OUTPUT_CHANGED`：输出摘要变化；
- `PROVENANCE`：来源记录不完整。

验证成功的 `OK` 只证明收据中的绑定和来源结构一致。它不是隐私、业务正确性、合规性或发布许可证明。

## 旧兼容面

仓库仍包含 DICOM、DICOM JSON、策略和旧数据处理入口。它们属于历史或可选兼容面，使用者必须按对应文档和版本单独验证，不能把旧能力自动算作 0.6.0 证据核心功能。


## 公共入口清单

兼容公共入口：`api/authorization`, `api/dicom`, `api/dicom_json`, `api/evidence`, `api/explain`, `api/native`, `api/policy`, `api/quality`, `api/query`, `api/validation`。其中 `api/evidence` 是 0.6.0 新的默认入口，其他入口保留各自的历史或平台边界。
