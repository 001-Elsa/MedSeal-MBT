# 0.4.1 → 0.5.0 发行源码迁移

本页对应新增能力的0.5.0源码版本。既有0.4.1发行包、历史证据和registry安装入口保留；0.5.0实际公开状态以源码树外的同版本回读报告为准。

## 保留与新增

`api/dicom.parse/write`、原`api/validation.convert_collection`及其他公共函数原参数/返回值保留。新增`api/query`、`api/quality`、Native `api/native`以及命名配置与计划工厂。旧消费者继续独立验收；新消费者仅导入api包。API完整示例、预算、错误码、私有输出与取消语义见[数据处理指南](DATA_PROCESSING.zh-CN.md)。

## 有意改变的解析行为

原来一律拒绝的Implicit VR LE现在仅在固定字典内接受；未知或私有字段不猜测VR，继续拒绝。PixelData按Implicit VR规范读取为OW，8位内容也可使用OW。普通二进制写回将该输入规范化为Explicit VR LE，并更新FileMeta，不保持原传输语法编码；数据值和像素内容必须保真。原Explicit VR输出不因本次升级切换编码。`parse_dataset_bytes`没有传输语法参数，仍仅解析Explicit VR裸数据集。

固定语料中的implicit-vr案例由独立pydicom生成器改为成功预期；不以当前库输出生成预期。原unsupported-transfer-syntax样例改用仍不支持的BigEndian UID，样例说明与生成器同步。历史发行包不改写。

## 预算与状态

缓冲SDK继续保持1–256个对象、64MiB/对象、合计128MiB，可通过Budget下调。Native流式SDK复用原10000对象、64MiB元数据估算等限制，不依赖增大缓冲上限。计划预览、quality.ready和校验成功均不授予交付许可。原私有宿主的持久映射、审核/签名与历史引用功能继续由原流程承担。

升级改变程序指纹，旧封存作业/审核/缓存继续使用其原固定运行包；不可把旧身份映射、旧审核或已处理影像直接重放为新作业。
