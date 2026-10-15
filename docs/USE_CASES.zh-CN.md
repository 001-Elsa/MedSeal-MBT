# 四个完整预期使用场景

## 4. 数据处理工具作者：目录清单、质量检查与结构化导出

**输入与步骤**：使用当前 0.5.0 候选源码，以 `tools/medseal-data summary INPUT_DIR` 获得匿名清单，`quality INPUT_DIR` 检查元数据关系；用 `export INPUT_DIR --output NEW.jsonl --format jsonl --fields 00080060,00280010 --equals 00080060=CT` 提取私有字段，再用 `convert INPUT_DIR --output NEW_DIR` 转换完整封闭集合。原有三个场景在下文保留。

**输出与验证**：清单/质量为匿名 JSON，CSV/JSONL 为私有原值；转换输出为完整新目录。`examples/data_pipeline` 演示公共库嵌入，`tools/verify_data_processing.py` / `tools/verify_data_consumer.py` 独立复核真实输出。

**失败与边界**：过滤不自动改变 convert 的输入；要转换筛选集必须另建完整闭合集合。未知格式、预算超限、断引用、源变化和已存在输出拒绝。Native 无需 Python但不持久化跨批身份，取消只在对象/提交边界生效；详情见[数据指南](DATA_PROCESSING.zh-CN.md)。

以下用途依赖已经实现的入口与合成验收，不是客户采用、真实来源授权或生产验收声明。

## 1. 影像开发者：关联集合批量联调

**问题与输入**：开发者需要把授权的 CT/MR/SC 元数据集合用于教学或软件联调，不能把每个影像分别改成相同患者号、破坏引用和日期间隔。先用仓库生成的两个合成患者、四文件两引用学习流程；真实输入必须符合 SUPPORT_MATRIX，另具授权与像素审核。

**完整步骤**：安装源码 CLI → 运行 `examples/collection` → 用 `plan INPUT_DIR --policy examples/research-policy.json` 预检 → 用 `batch INPUT_DIR --output NEW_JOB_DIR --policy examples/research-policy.json` 转换 → 用 `verify NEW_JOB_DIR` 重新核对输出。命令前缀均为 `moon run --target native cmd/main --`；集合演示为 `moon run --target native examples/collection`。

**输出与判定**：新目录内匿名编号 DICOM、逐对象审计和 SHA-256 清单；同患者假名、身份 UID 与引用一致，支持的完整 DA 间隔保持。验收入口 `tools/verify_with_pydicom.py` 使用独立解析器核对身份、引用、日期和像素字节。

**失败与范围**：错误 File Meta、重复 SOP、冲突患者归属、未授权外部引用或源内容变化拒绝；输出目录已存在/嵌套也拒绝。兼容入口映射只在单次作业内，跨批需求转场景 2。verify 的成功不授予隐私或临床许可。

## 2. 纵向研究操作者：新增随访、历史引用与重复导入

**问题与输入**：同项目、同来源系统按批次导出后续影像，需要保持身份与时间关系，避免同 SOP 不同内容被覆盖、重复转换和重复交付；随访对象可能引用此前已交付的对象。采用独立来源域、strict 策略和受控本机输入。

**完整步骤**：按 OPERATIONS 手册离线安装（Python 3.12） → 初始化私有身份库与项目/来源域 → create 封存全量来源 → run 转换 → risks/逐对象 review → publish 签名 → 独立 verify_delivery → deliver 到固定受控目录 → 在相同项目/来源/交付域 create 两次新增批次；输入相同对象时核验缓存，历史引用必须指向已重新核验的 Acknowledged 目标。进程中断后使用 resume；备份后恢复到新目录并核对稳定映射。

**输出与判定**：私有身份/缓存账本、转换/复用/拒绝计数、签名交付包、内容寻址对象及接收回执。`tools/verify_incremental.py` 验证缓存、冲突、迁移/恢复；`tools/verify_destination.py` 验证历史引用、回执重建、目的地篡改和重复交付；`tools/verify_w7_rehearsal.py` 串联全量/新增/恢复演练。

**失败与范围**：同 SOP 内容变化、跨域历史目标、目标文件/审计/回执被改写、程序/策略摘要改变均失败关闭。缓存命中只有 Converted，不能跳过审核/签名；目录回执不证明远程 PACS exactly-once。经典 CT 研究需独立体素/HU/几何验收；三组各 50 片仅为合成回归，真实视觉审核和研究接收仍需现场材料。

## 3. 工具作者：嵌入公共规则、验证与解释

**问题与输入**：教学工具或影像处理应用需要可复用的策略编译和结构解释，不应依赖 MedSeal 私有事务/数据库，也不应把患者值直接显示在可分享报告中。先从自己的独立 MoonBit 模块安装公共包。

**完整步骤**：按 README 执行 `moon add 001-Elsa/medseal@0.5.0`（目标版本；实际公开可用状态见本版本外置回读报告） → 创建仅导入 `api/policy` 的 executable → 运行 strict 策略编译示例 → 依据 PUBLIC_API 合约使用 `api/validation` 对 Bytes 创建 ValidatedObject，调用 `convert_collection` 完成封闭集合转换并重新验证（0.5.0还可用命名配置与 `plan_collection`） → 使用 `api/explain` 的条件/对象解释生成受限公开结果。需要文件读取/可信授权时使用 Native 提供方，部署审核/交付仍由宿主明确执行。

**输出与判定**：`public-policy-ok`、不可由 JSON true 伪造的验证/授权状态类型、版本化结构化错误与不包含原患者值的解释。`tools/verify_registry_consumer.py` 在独立模块安装公开版本；`tools/verify_rulebook.py` 验证 Schema、规则索引、实际解释与敏感值金丝雀。

**失败与范围**：非法策略、Unknown 必要条件和验证错误不能创建通过状态；受控提供方指纹/审核/签名不符拒绝。`private_bytes/private_dataset` 是私有内容，不能作为公开解释序列化；策略编译不等于 IOD、像素或发布审核。旧 `src/` 兼容导入可用，新应用优先使用公共门面。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
