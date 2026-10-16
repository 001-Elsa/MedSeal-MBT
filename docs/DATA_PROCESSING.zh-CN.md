# MedSeal 0.5.0 数据处理与公共工具库
> **0.6.0 当前边界：** 当前默认入口是 `api/evidence`，用于可验证数据变换证据。本文其余旧版本数字、DICOM流程和历史验收结果按原版本归属，不自动代表新的证据核心。

## 报告与机器契约

`query.summary` 对应 `resources/data/inventory-v1.schema.json`（`medseal-inventory-v1`）；内存 `ConversionPlan.public_report` 对应 `plan-v1.schema.json`（`medseal-plan-v1`）；质量对应 `quality-v1.schema.json`（`medseal-quality-v1`）。Native 扫描另输出 `medseal-scan-v1` 外层（对象、排除数、metadata-only、pixels_checked:false、嵌套quality）；Native 计划输出 `medseal-native-plan-v1`（对象/引用计数）。上述三个Schema文件不能直接套到Native外层；嵌套质量仍按质量Schema验证。CLI `quality` 再包装为 `medseal-directory-quality-v1`（metadata-only、pixels_checked:false、嵌套quality）。所有这些公开出口均 `release_authorized:false`。

当前源码版本：0.5.0。既有0.4.1发行物保持原样；本页新增功能需使用0.5.0源码或通过回读核验的同版本包，不能通过安装旧registry版本获得。平台状态以源码树外的0.5.0回读报告为准。

## 完整任务与入口

```sh
tools/moon-local run --target native examples/data_pipeline
tools/medseal-data summary INPUT_DIR
tools/medseal-data quality INPUT_DIR
tools/medseal-data export INPUT_DIR --output NEW.csv --format csv --fields 00080060,00280010,00280011 --equals 00080060=CT
tools/medseal-data export INPUT_DIR --output NEW.jsonl --format jsonl --fields 00080060,00280010 --group 00080060
tools/medseal-data convert INPUT_DIR --output NEW_DIR --policy examples/strict-policy.json
```

CLI成功返回0，quality检查未ready返回1，参数/输入或执行异常返回2并输出固定的MEDSEAL-DATA-FAILED提示；库中的类型化错误由API调用方处理，CLI不回显私有异常内容。

字段采用八位十六进制Tag。导出支持一个精确值过滤条件；公共库另支持多个条件合取、存在性和整数区间。`--group` 的分组键是私有数据，只在显式请求的导出命令中输出。summary返回对象/Study/Series计数与默认字段缺失数；quality检查完整输入的元数据关系。转换始终重新读取完整目录，不隐式沿用筛选结果；仅筛选部分对象后应显式构造闭合输入集，断引用继续拒绝。

CSV与JSONL包含私有原值，不是匿名报告。所有导出要求新文件，权限0600；CSV使用CRLF、完整引号转义和公式前缀防护，数值也按安全文本处理。CSV将VM用反斜线连接，缺失/空值都显示空单元格；需要区分时使用JSONL：缺失为null，空值为[]，多值为字符串数组。私有表格文本累计16MiB、至多10000行×64列；JSON转义可能增大最终文本。匿名summary不输出字段原值、UID、路径或日期；调用方应使用固定列名，不把个人信息放进列名。

## 公共接口

| 包 | 主要接口 | 用途 |
| --- | --- | --- |
| `api/query` | `lookup`, `values`, `scalar`, `integer`, `select`, `project`, `group_counts`, `summary` | 结构化访问、查询和数据导出 |
| `api/quality` | `check`, `check_datasets`, `Report.ready`, `Report.public_json` | 字段/对象/集合质量检查 |
| `api/validation` | `Budget.new`, `ConversionOptions.new/for_patients`, `plan_collection`, `ConversionPlan.execute` | 显式配置、先计划后转换 |
| `api/native` | `scan_directory`, `quality_directory`, `plan_directory`, `Scan.private_datasets`, `DatasetJob.execute` | 本机扫描与大集合流式转换 |

`query.Step.Field(tag)`选择叶字段；嵌套路径用`Step.Item(sequence_tag, index)`后接叶字段。缺失、类型错误、VM错误、非法数字、非法路径和预算分别有类型化QueryError及稳定`QUERY-*`码。整数严格接受十进制，范围±(2^53−1)，不通过浮点数舍入小数或大整数。各后端结果一致；分组使用MoonBit确定性字符串顺序，不能假设与宿主语言词典序相同。

quality复用原有validator、严格研究元数据检查与集合引用检查。新增同一Series内模态、行列数及位分配差异提示；不同序列的差异不误报。调用方可用`required_fields`添加至多64个非空字段要求。`check`先检查1–256对象、64MiB/文件、合计128MiB，再解析及像素结构验证；任一失败会保留原对象数量且collection=not-checked，不把剩余子集称为通过。`check_datasets`只检查提供的元数据，不包含Part10/像素检查；限制10000对象、深度32和1000000个元素/条目。结果区分passed、failed、unsupported和not-checked。ready不授予发布/医疗许可。

## 配置与快照

下面是公共调用示意，完整可编译文件在`examples/data_pipeline`：

```moonbit nocheck
let options = @validation.ConversionOptions::for_patients(
  policy=@policy.strict(),
  uid_seed=host_generated_seed,
  patients=[{patient_id: private_patient_id, issuer: private_issuer, days: 7}],
)
let plan = @validation.plan_collection(inputs, options)
let safe_preview = plan.public_report()
let result = plan.execute()
```

`for_patients`将偏移绑定到PatientID+Issuer，拒绝重复、遗漏和多余绑定，数组顺序不影响映射。`new`保留原排序数组契约以便兼容。构造器复制偏移与输入数组；Bytes不可变，计划执行重新验证保存的完整字节快照。Budget只允许下调原SDK上限。预览仅公开对象、患者和引用数量。真实作业的seed应由宿主安全产生，示例固定seed只用于合成数据。

## Native扫描与流式作业

扫描不会解码像素：小于等于2MiB的文件用有界解析后移除像素，大文件使用前2MiB元数据和末尾有限长度原生PixelData索引；未知语法、超出前缀、截断或非末尾像素大文件拒绝。单文件256MiB、像素值128MiB、目录深度16、20000条目、10000候选对象、元数据索引估算64MiB。索引估算不是RSS承诺。扫描前后检查文件快照与完整文件集；返回的DataSet深拷贝，修改副本不影响Scan。只报告元数据质量，`pixels_checked:false`。

Native计划复用原流式引擎：全局建立身份与引用，按对象读取/转换，像素按1MiB块复制，复验后整体提交新目录。无需Python和持久身份库；每作业身份映射不用于跨批随访。Job为单次执行，输出目录不能与输入嵌套且必须不存在；源字节变化会拒绝。取消回调在规划对象、执行对象及提交前边界检查；当前单个对象内部复制不承诺即时中断。取消/错误清理私有暂存，不提交成功目录。POSIX是已实测环境，其他平台以CI结果单独记录。

## 互操作与验收

Implicit VR LE输入只支持固定字典中可明确判定VR的字段；PixelData依标准使用OW。未知/私有Tag返回MEDSEAL-E110，字典歧义返回MEDSEAL-E111；FileMeta继续显式编码。支持现有有界Sequence与Item长度，压缩、BigEndian、未经支持的字符集仍拒绝。普通write和严格转换都输出Explicit VR LE，正确更新FileMeta并重算长度；普通write不进行去标识化。

```sh
python3.12 tools/verify_data_processing.py --record tmp/data-processing-ci.json
python3.12 tools/verify_data_consumer.py --record tmp/data-consumer-ci.json
python3.12 tools/benchmark_data_processing.py --record tmp/data-benchmark.json
```

验收分别检查pydicom独立输入/输出、公开报告金丝雀、错误与取消、四后端归档隔离消费。benchmark对1/16/64MiB像素及100/1000对象分别测量扫描与转换，默认每项三次，记录Native子进程RSS/时间；生成夹具和独立读回不计入计时，缓存未清空。只用合成数据，不把本机通过写成临床采用或registry发布。

公开清单、质量报告和转换计划的JSON Schema位于`resources/data/`；新消费者验收使用独立jsonschema验证实际输出。目录quality入口逐对象记录匿名解析错误，保留输入总数，不对成功子集执行集合通过判定。


> 当前模块版本：0.6.0。本文中的旧版本数字只表示历史基线；当前默认入口以 `api/evidence` 为准。
