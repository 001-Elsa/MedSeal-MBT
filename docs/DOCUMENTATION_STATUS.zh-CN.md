# Markdown 文档与代码同步账本

核对日期：2026-10-16。当前源码模块 **0.6.0 发行源码**；此前公开基线0.4.1。0.5.0远端CI及GitHub/GitLink/Mooncakes同步结果按[同步协议](PLATFORM_SYNC.zh-CN.md)写入源码树外的同版本回读报告，旧版证据保留原版本；正式申报单独记录。申报书已按当前代码重写，原有姓名韩桢、联系方式和原创项目性质保留。

## 范围与依据

逐文件核对本仓库全部 **72 份 Markdown**，包含跟踪文件、未忽略的新文档、`.githooks` 和示例。以十个公共包的生成接口、实际CLI分支、解析/写回代码、报告Schema、固定语料和本轮运行记录为依据。对受影响正文作实质修正；历史计划中的“当前”仅指其明确标注的原基线，不改写原研究、测量或回执。

外部 `MedSeal发布产物/0.5.0-local` 及其文档副本属于历史快照；本次 0.6.0 当前入口只以本仓库为准。父目录旧深化方案、获奖研究、历史逐条核验和预览入口共4份说明另补历史范围与当前申报书指引；`MedSeal-MBT提交材料-韩桢`、旧发行包和预览归档仍为历史快照，不修改其已冻结字节和清单。第三方研究源码、工具链依赖、构建/缓存与无关业务Markdown不属于本项目维护文档。当前入口以本仓库 0.6.0 为准，避免把旧副本当作新版申报书。

## 当前代码事实与验收归属

- `classified_attributes=120`、`rulebook_entries=141`、`corpus_cases=475`（466单对象+9集合）、`public_api_packages=10`、`data_report_schemas=3`。
- 十个公共包：dicom、dicom_json、policy、validation、explain、authorization、query、quality、native。Evidence 是可移植新入口；Native目录作业与授权提供方仍有平台限制；可移植查询/质量/内存计划在四后端验收。
- 当前本机完整测试Native154，JS/wasm/wasm-gc各101；475固定案例、18组新数据验收、11组预检及新旧四后端归档消费者通过。原始记录位置、当前实测和重跑命令见[本轮实施账本](DATA_UPGRADE_STATUS.zh-CN.md)。这些结果来自此前本轮代码验收，本次文档修订不会把历史CI或浏览器验收冒充重新执行。
- Part10接受Explicit VR LE和固定字典Implicit VR LE；未知/私有implicit字段或歧义拒绝，写出Explicit VR LE。`parse_dataset_bytes`继续仅Explicit VR裸数据集。临床、完整IOD/Annex E及像素隐私保证不扩张。
- 256对象/64MiB每对象/128MiB合计是内存集合入口；10000对象/256MiB文件/128MiB像素/2MiB前缀/64MiB元数据估算是Native入口。浏览器、JSON桥、Python预检和Orthanc保留各自更小预算，不能跨入口套用。
- 原117/64、137/84、139/86和各P/W/C/V性能、SHA及平台结果明确为历史。0.5.0的性能只引用本机新入口合成实测，不计算跨语义路径提速倍数。

## 逐文件核对结果

| 文档 | 角色与核对结果 |
| --- | --- |
| `.githooks/README.md` | 当前操作；可选hook与Python3.12入口核对，启用状态不推断 |
| `ACCEPTANCE.md` | 当前验收；更新0.5.0能力/本机结果，旧CI按原版本保留 |
| `AGENTS.md` | 当前维护约定；文档/格式/接口/测试要求核对，无须改写 |
| `ARCHITECTURE.md` | 当前架构；十个门面（含 Evidence）、examples/evidence、双输入语法与头部规范化已修正 |
| `BENCHMARKS.md` | 历史测量；P0/P4原值保留，指向0.5.0单独实测 |
| `CHANGELOG.md` | 版本历史；0.5.0条目与新增代码一致，旧记录保留 |
| `CONTRIBUTING.md` | 当前维护；0.5.0范围、迁移和QUERY错误码同步 |
| `PROJECT_APPLICATION.md` | 当前申报事实稿；重写定位/五项成果/九包/验收/预算/边界，保留身份与原创性质 |
| `README.mbt.md` | 当前入口；与README.md逐字节一致 |
| `README.md` | 当前入口；0.5.0能力、语法和目标安装版本同步，平台状态按外置回读报告确定 |
| `README.zh-CN.md` | 当前中文入口；包清单/数据命令/输入语法/旧版安装含义同步 |
| `SECURITY.md` | 当前安全边界；查询原值与匿名报告、内存计划/Native/私有宿主分别说明 |
| `THIRD_PARTY.md` | 当前来源许可；固定字典/pydicom/QA/phantom来源继续适用，无新增第三方运行依赖 |
| `docs/API_COMPATIBILITY.zh-CN.md` | 当前契约；0.5.0十包（新增 evidence）、implicit 历史兼容、QUERY错误与旧包消费分别说明 |
| `docs/APPLICATION_BENCHMARKS.zh-CN.md` | V4历史测量；保留数据、明确缺失CPU型号，链接新Native基线 |
| `docs/APPLICATION_VALUE_PLAN.zh-CN.md` | V1–V6阶段计划；历史障碍/计数与0.5.0落实分开，删除implicit未实现的当前结论 |
| `docs/COMMUNITY_LAB.zh-CN.md` | 当前构建说明；0.5.0核心、独立浏览器预算和原阶段Node/Chrome证据区分 |
| `docs/COMMUNITY_ROADMAP.zh-CN.md` | C1–C6方案及落实；制定时差距保留，implicit与数据工具当前行更新 |
| `docs/COMPETITION_CHARTER_AUDIT.zh-CN.md` | 2b088d4历史审计；来源条款/SHA/判定保留，补当前事实和回执边界 |
| `docs/COMPETITION_REMEDIATION.zh-CN.md` | 当前整改与历史发布；0.5.0本地结果与0.2.x已核验发布分开 |
| `docs/CONFORMANCE_LAB.zh-CN.md` | 当前语料操作；implicit-vr成功预期变更、475例与历史W1区分 |
| `docs/CONSUMER.zh-CN.md` | 当前消费；新增数据消费者与旧集合示例、归档/registry证据分开 |
| `docs/CONTRIBUTION.md` | 当前贡献摘要；新增五项，2b088d4行数统计保持历史 |
| `docs/CT_CLASSIC_RESEARCH.zh-CN.md` | 限定CT研究契约；原explicit验证范围保留，基础parser扩展不冒充CT用途复验 |
| `docs/DATASET_PREFLIGHT.zh-CN.md` | Python预检操作；原封存/策略预算保留，新增Native质量入口及差异说明 |
| `docs/DATA_PROCESSING.zh-CN.md` | 当前数据指南；接口/CLI/退出码/Schema/预算/原值/取消逐项核对 |
| `docs/DATA_UPGRADE_STATUS.zh-CN.md` | 0.5.0实施与实际验收；证据入口、154/101；旧数据验收 475/18/11及三次性能实测 |
| `docs/DICOM_JSON.zh-CN.md` | 当前格式桥；25VR、精度、规范化和8MiB/深度16预算仍适用 |
| `docs/DOCTOR.zh-CN.md` | 环境诊断；补全套Python维护依赖与Native运行依赖的差异 |
| `docs/DOCUMENTATION_STATUS.zh-CN.md` | 本次完整逐文件账本；当前事实、历史范围及检查能力明确 |
| `docs/ENTERPRISE_ROADMAP.zh-CN.md` | 9562904历史设计；当前对照补0.5.0，原计划/目标/行号保留 |
| `docs/ENTERPRISE_STATUS.md` | P阶段证据；已由W补齐缺口更新、十/八文件闭包区分，历史测量不重写 |
| `docs/FIELD_ACCEPTANCE.zh-CN.md` | 现场模板；所有未取得主体材料继续待验收，无须改写为通过 |
| `docs/INCREMENTAL_LEDGER.zh-CN.md` | 私有宿主契约；持久缓存/历史/outbox绑定核对，新Native不继承此能力 |
| `docs/ITERATION_PLAN.md` | 原深化设计；当前对照补0.5.0，原拟议接口/缺口/测量保留历史 |
| `docs/ITERATION_STATUS.md` | 当前实施比较；新增数据五项和当前测试，旧SHA/CI保留 |
| `docs/MIGRATION_0.3.zh-CN.md` | 0.2.x到0.3.0历史迁移；补0.5.0迁移入口，原安装版本不替换 |
| `docs/MIGRATION_0.6.zh-CN.md` | 当前迁移；证据计划、来源、收据和独立验证边界与代码核对 |
| `docs/MIGRATION_0.5.zh-CN.md` | 当前迁移；原签名保留、implicit写出变化、字节快照/源复核核对 |
| `docs/OPERATIONS.zh-CN.md` | 私有宿主操作；旧安装包明确冻结，0.5.0无Python数据工具另行说明 |
| `docs/ORTHANC_INTEGRATION.zh-CN.md` | 限定本地接收适配；实际版本/摘要及256对象预算保留，不扩张为新SDK保证 |
| `docs/P0_CONTRACT.md` | 当前发现/故障契约；深度/条目/候选预算与代码相符 |
| `docs/PERSISTENT_IDENTITY.md` | 私有身份提供方；POSIX/备份/轮换/历史限定继续适用 |
| `docs/PLAN_AUDIT.md` | 当前逐项比较；数据能力/测试/普通写回头部行为已更新 |
| `docs/PLATFORM_SYNC.zh-CN.md` | 当前同步协议；本地工作树打包与干净冻结发行分开，候选版本更新 |
| `docs/POLICY.md` | 当前策略/库用法；九门面、易用集合计划及implicit普通写回语义同步 |
| `docs/PRIVATE_FILE_VIEW.zh-CN.md` | 当前浏览器只读操作；独立预算保留，0.4.1实测不冒称本轮重跑 |
| `docs/PUBLIC_API.zh-CN.md` | 当前公共契约；九包、计划/Native差异和双输入语法同步 |
| `docs/RECOVERY.md` | 私有宿主恢复；schema2/十适配器/取消/清理契约继续适用 |
| `docs/REHEARSAL.zh-CN.md` | W7合成演练操作；现场材料保持requires_field，不推断新增生产验收 |
| `docs/RELATED_WORK.md` | 历史查重与当前贡献；外部研究日期保留，新增数据处理成果补充 |
| `docs/RELEASE_READINESS.zh-CN.md` | 当前发行流程；0.5.0候选归档/观察示例同步，平台回执外置说明 |
| `docs/RESEARCH_TOOLS.zh-CN.md` | 研究工具操作；外部源码/历史输出不作为当前项目文档覆盖 |
| `docs/RISK_REVIEW.md` | 私有审核契约；schema2输入/schema1封套及人工证据要求核对 |
| `docs/RULEBOOK_INDEX.zh-CN.md` | 当前规则索引；120属性+21约束=141，来源/实现核对，修复末尾规则脱离表头 |
| `docs/STATE_MODEL.zh-CN.md` | 私有状态/历史fuzz；终止/发布不变量与原证据范围保留 |
| `docs/STREAMING.md` | 当前流式路径；公共Native、implicit、扫描差异和取消边界更新 |
| `docs/STRICT_PROFILE.md` | 当前strict子集；字段/条件/像素限制和独立SC历史证据仍适用 |
| `docs/SUBMISSION_GUIDE.zh-CN.md` | 当前提交指南；项目定位与0.5.0材料同步，待发布/个人提交明确 |
| `docs/SUBMISSION_MATERIALS.zh-CN.md` | 当前答辩参考；十包/证据核心/154与101/语法/Native职责更新 |
| `docs/SUPPORT_MATRIX.md` | 当前支持矩阵；双输入语法、Native路径、旧版社区来源及预算核对 |
| `docs/TEMPORAL_SEMANTICS.zh-CN.md` | 当前时间规则；命名配置不改变DA/DT/TM既有处理契约 |
| `docs/TRUSTED_DELIVERY.md` | 私有签名/安装契约；schema2、预算与旧运行包边界仍适用 |
| `docs/USE_CASES.zh-CN.md` | 当前四场景；新增数据提取质量导出，修正旧安装与底层Context用法 |
| `docs/V6_ACCEPTANCE.zh-CN.md` | 当前发布门禁；增加数据验收及发布后0.5.0registry检查，不能代替完整宿主门禁 |
| `docs/W7_FIELD_EVIDENCE.zh-CN.md` | 现场证据模板；五项真实证据继续独立待取得 |
| `docs/WINNER_DRIVEN_ROADMAP.zh-CN.md` | 历史获奖对标方案；当前对照新增0.5.0，原目标和外部研究保留 |
| `docs/WINNER_RESEARCH.zh-CN.md` | 固定13项研究；SHA/行号不重写，当前MedSeal数据能力补充 |
| `docs/WINNER_UPGRADE_STATUS.zh-CN.md` | W0–W7历史实施；现行版本摘要更新，测试与CI按原阶段保留 |
| `docs/WORKBENCH.zh-CN.md` | 当前私有工作台契约；回环分页/取消API不自动获得新数据CLI权限 |
| `examples/consumer/README.md` | 旧集合消费者当前用法；JSON流程和版本状态修正，新增示例分别指明 |
| `samples/README.md` | 当前合成夹具；不支持语法样例已改BigEndian，生成器与字节相符 |

## 防止再次落后

`python3.12 tools/check_documentation.py` 检查完整清单、相对链接、表格行结构、README字节一致、姓名、模块/CLI版本、规则/语料/公共包/Schema实际数量。另强制核心现行文档声明候选版本、公共API清单及数据Schema名称，拒绝申报书旧测试数/旧版本和核心契约中已知过时的implicit说明。检查器的回归自检验证这些旧错误会失败。

自动检查不能证明每句自然语言和外部网页永远准确；逐文件的代码契约核对与原始运行记录仍为依据。新增实现时应同时更新对应正文、申报事实及本表；新公开版本必须从自己的冻结源码、CI和平台回读取得证据。

正式申报由韩桢本人完成。需要本人声明、适用人工Proposal、个人信息/授权确认与官方成功回执时按[提交指南](SUBMISSION_GUIDE.zh-CN.md)执行，不用材料准备代替这些事实。


> 当前模块版本：0.6.0。本文中的旧版本数字只表示历史基线；当前默认入口以 `api/evidence` 为准。
