# 数据集预检（V2）

0.5.0 另提供无需 Python 的 `api/quality` / `tools/medseal-data quality INPUT_DIR`，目录接口检查元数据，保留坏对象计数与集合 not-checked；它不执行本页 Python 封存/策略影响流程。两者预算和像素检查不同，不能混用 ready；详见[数据指南](DATA_PROCESSING.zh-CN.md)。

入口：`python3.12 tools/dataset_preflight.py INPUT --policy examples/strict-policy.json`，先构建 `moon build --target native cmd/main`。成功退出0，阻断退出1；输出可分享的JSON，不产生转换影像、不授予交付许可。

预检复用 `enterprise_job.scan/seal`：拒绝链接/特殊文件，深度16、目录条目20,000；识别扩展名.dcm或含DICM标记的文件，单独统计非DICOM排除项。当前预检限制256对象、64MiB/对象、合计128MiB；封存到自动清理的0700临时目录，读取前后检查源稳定性，策略至多1MiB并固定副本。失败不会丢弃对象后继续宣称整批可用。

DICOM决策全部调用现有MoonBit命令：逐对象 `explain-object`；全部对象成功后执行完整封闭集合 `plan`，核对重复身份与断引用。结果 `ready-for-planning` 仅表示此次快照通过预检，实际转换仍须重新固定和验证输入。不是完整IOD、像素隐私、研究方验收或发布授权。

报告包含匿名对象序号、检查数量、失败分类、固定下一步建议及成功对象的策略动作统计，不包含路径、文件名、原值、UID、输入摘要、策略原文或私有命令输出。分类包括文件系统、预算、格式、字符编码、策略、引用、元数据和运行环境。`policy_action_scope` 明确仅统计成功对象；并非失败对象也得到策略批准。

本工具面向受控POSIX本机；复用现有封存的空间检查（候选输入两倍加64MiB），60秒/子命令超时。临时封存会在退出清理，进程强制终止留下的临时文件仍需本机管理员处理；没有物理擦除保证。源稳定性是边界检查，不保证恶意管理员无法替换系统或还原元数据。

验收：`python3.12 tools/verify_dataset_preflight.py --record tmp/v2-preflight-ci.json`。实际运行正常集、非DICOM计数、坏文件不漏检、传输语法拒绝、重复身份、断引用、符号链接、硬链接、提前大小限制、错误策略与缺运行时，并检查公开金丝雀。使用固定合成样例；真实数据来源/许可另行登记。[总计划](APPLICATION_VALUE_PLAN.zh-CN.md)。
