# Markdown 文档与代码同步账本

核对范围：项目自有、受 Git 管理的全部 Markdown（含隐藏 .githooks）；不修改依赖缓存、构建目录或固定 JSON 证据。核对运行基线 2c9a49e / 已发布 0.2.0；本轮文档补丁版本为 0.2.1，发布结果单独回读。后续文档提交不改写 bc5b25c 冻结发行物。

实质修正包括：入口保证、strict 规则/时间语义、持久映射/缓存/历史引用、恢复/审核 schema2、作业十适配器与授权八文件闭包的区别、manifest 8MiB/release 4MiB/audit 16MiB、CT/质量实验室、测试与平台发布事实、姓名和实际账号。原方案补当前实施对照，旧计数/外部研究 SHA/测量保留历史。

本轮 0.2.1 不扩张 DICOM 算法/医疗范围；模块、CLI、安装示例及 SBOM 版本来源已同步，版本更新会改变运行时指纹，旧固定作业需使用原包。

代码可重验事实：`classified_attributes=120`、`rulebook_entries=141`、`corpus_cases=475`（466 单对象 + 9 集合）。维护基线 Native117 / JS、wasm、wasm-gc 各64，309后端执行，不是309个独立场景。

`python3.12 tools/check_documentation.py` 检查所有文档列入本表、相对文件链接、README字节一致、姓名、模块/CLI版本以及三个代码事实；CI独立执行。它不能自动验证自然语言全部准确、外链永久有效或人工现场证据，人工契约核对和原始记录仍需保留。

| 文档 | 角色与本轮核对结果 |
| --- | --- |
| `.githooks/README.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `ACCEPTANCE.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `AGENTS.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `ARCHITECTURE.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `BENCHMARKS.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `CHANGELOG.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `CONTRIBUTING.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `PROJECT_APPLICATION.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `README.mbt.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `README.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `README.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `SECURITY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `THIRD_PARTY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/COMPETITION_CHARTER_AUDIT.zh-CN.md` | 历史设计/逐条研究，已补当前对照，原基线保留 |
| `docs/COMPETITION_REMEDIATION.zh-CN.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `docs/CONFORMANCE_LAB.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/CONSUMER.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/CONTRIBUTION.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `docs/CT_CLASSIC_RESEARCH.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/DOCUMENTATION_STATUS.zh-CN.md` | 本表，覆盖全部项目 Markdown |
| `docs/ENTERPRISE_ROADMAP.zh-CN.md` | 历史设计/逐条研究，已补当前对照，原基线保留 |
| `docs/ENTERPRISE_STATUS.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `docs/FIELD_ACCEPTANCE.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/INCREMENTAL_LEDGER.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/ITERATION_PLAN.md` | 历史设计/逐条研究，已补当前对照，原基线保留 |
| `docs/ITERATION_STATUS.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/OPERATIONS.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/P0_CONTRACT.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/PERSISTENT_IDENTITY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/PLAN_AUDIT.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/POLICY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/PUBLIC_API.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/RECOVERY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/REHEARSAL.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/RELATED_WORK.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/RELEASE_READINESS.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/RISK_REVIEW.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/RULEBOOK_INDEX.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/STATE_MODEL.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/STREAMING.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/STRICT_PROFILE.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/SUBMISSION_GUIDE.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/SUBMISSION_MATERIALS.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/SUPPORT_MATRIX.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/TEMPORAL_SEMANTICS.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/TRUSTED_DELIVERY.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/USE_CASES.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/W7_FIELD_EVIDENCE.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `docs/WINNER_DRIVEN_ROADMAP.zh-CN.md` | 历史设计/逐条研究，已补当前对照，原基线保留 |
| `docs/WINNER_RESEARCH.zh-CN.md` | 历史设计/逐条研究，已补当前对照，原基线保留 |
| `docs/WINNER_UPGRADE_STATUS.zh-CN.md` | 阶段/测量/来源/发布账本，当前摘要与固定历史分别说明 |
| `docs/WORKBENCH.zh-CN.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `examples/consumer/README.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |
| `samples/README.md` | 当前契约/操作/材料，代码入口与字段/限制核对 |

## 提交准备状态

项目工程材料可按[提交指南](SUBMISSION_GUIDE.zh-CN.md)使用。姓名确认韩桢；GitHub001-Elsa、GitLinkHzhhhh、模块001-Elsa/medseal已固定。本人核对私人字段、适用的人工Proposal和个人声明，并在官方入口保存成功回执；仓库不伪造这些结果。W7真实医疗现场证据仍是独立的后续生产目标。
