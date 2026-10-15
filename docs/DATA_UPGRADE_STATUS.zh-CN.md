# 数据处理与工具库升级实施账本

版本：0.5.0发行源码；上一公开基线0.4.1。仅列实际实现与本轮验收；registry/GitLink/GitHub公开发布和正式申报是不同状态。

| 用户规划 | 实现入口 | 验收方式 |
| --- | --- | --- |
| 元数据提取、筛选、汇总与导出 | `api/query`、`cmd/data` | 类型化路径、整数边界、AND过滤、VM/缺失、CSV引号/公式与JSONL读回、匿名清单 |
| 公共数据质量检查库 | `api/quality` | 对象/集合检查、required_fields、Series差异提示、重复身份/断引用/坏对象、unsupported/not-checked状态 |
| SDK易用性与转换计划 | `api/validation/plan.mbt` | 命名患者日期、预算下调、数组快照、映射完整性、计划后复验、旧接口回归 |
| 扫描与Native大集合SDK | `api/native`、`examples/native_pipeline` | 无Python处理、低内存元数据索引、整批引用、源变化、单次Job、取消及暂存清理 |
| Implicit VR LE子集 | `src/parser/implicit.mbt`及共用解析/写回 | pydicom独立8/16位与Sequence输入、原值/像素保留、FileMeta规范化、未知字段/截断拒绝 |

可复跑脚本：`tools/verify_data_processing.py`、`tools/verify_data_consumer.py`、`tools/benchmark_data_processing.py`。命令与契约见[数据处理指南](DATA_PROCESSING.zh-CN.md)。脚本实际执行结果保存在本轮外置验收/本地交付目录；临时运行记录在tmp，不与已冻结发行证据混淆。

本地工作树打包必须回读所有新增包，不能只验证作者目录；保持旧消费者四后端兼容，增加新数据处理消费者的归档隔离验收。本轮性能是同机合成负载基线，不预设提速倍数或临床容量。


## 本轮实际验收结果（2026-10-15，macOS arm64）

- 四后端完整测试：Native152，JS/wasm/wasm-gc各99，全部通过；计数表示各后端执行的测试数。
- 固定独立语料475例全部通过、0跳过；旧预检11组通过。
- 新数据处理独立验收18组通过；旧接口与新数据处理消费者分别从归档隔离目录在四后端check/test/run，通过pydicom独立输出及关系验证，新报告另经JSON Schema检查。
- 本机1/16/64MiB及100/1000对象负载：扫描与转换各重复3次。下表是中位耗时和最大子进程RSS；未清空缓存，不作为跨机器保证。

| 负载 | 扫描秒 | 扫描峰值MiB | 转换秒 | 转换峰值MiB |
| --- | ---: | ---: | ---: | ---: |
| payload-1 | 0.005046 | 5.38 | 0.151842 | 5.98 |
| payload-16 | 0.005698 | 5.36 | 2.284216 | 7.97 |
| payload-64 | 0.005217 | 5.36 | 8.650228 | 8.00 |
| objects-100 | 0.055227 | 4.25 | 0.564495 | 6.11 |
| objects-1000 | 0.544126 | 11.81 | 4.705223 | 20.03 |

本轮最终交付目录为工作区外的`MedSeal发布产物/0.5.0-local`，包含源码模块ZIP、macOS arm64原生命令行、合成演示、文档和验收原始JSON。本机验收不代表远端三平台CI或registry已经发布。
