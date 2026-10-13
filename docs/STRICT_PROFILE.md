# Strict-v1：实现范围与验收

`examples/strict-policy.json` 使用版本 2 / strict 配置。
与保留兼容的 research-v1 不同，未知公共字段直接拒绝，不能无声保留。
严格配置禁止 keep、身份/结构覆盖、未知条件、冲突优先级和重复 JSON 键。

```sh
tools/moon-local run --target native cmd/main -- explain examples/strict-policy.json
tools/moon-local run --target native cmd/main -- batch INPUT --output NEW_OUTPUT --policy examples/strict-policy.json
```

## 规则与字典

- 固定 pydicom 3.0.1 字典数据，120 个显式分类属性，生成器和数据在仓库内。
  实际条目数/摘要以 `resources/rules/strict-v1.json` 和生成接口为准。
- 本项目自行实现规则执行；字典数据不是复制的 parser 或脱敏实现。
- 固定标准参考 DICOM 2025e；当前实现的是声明字段/模块子集，非全部 IOD 或 Annex E。
- 公共字段逐项记录 keep/empty/remove/remap/shift，未知字段阻断。
- 自由文本清空，厂商身份清空，原始属性/签名/MAC、覆盖层和不支持的身份结构移除；像素仍未检查。
- 路径为 `dataset/00081030` 或 `dataset/00081140[*]/00204000`，使用大写八位标签。
  祖先仅支持已分类 Sequence；条件为 primary SOP 与本层标签存在。
- 高优先级覆盖低优先级；同优先级潜在重叠在编译时拒绝。不同 JSON 顺序得到同一策略摘要。
- 规则仅可操作所列描述字段；不能将必要字段删掉或将风险改成已检查。
- 策略、字典摘要进入清单；原配置及替换值不进入公开 explain/审计。

## 字段与像素契约

检查固定字典 VR/VM、声明 Type 1/2 字段、数值字符串、High Bit、位深、维度和未压缩载荷长度。
目前严格像素契约限单帧、单样本、8/16 bit、MONOCHROME1/2。
CT/MR 还检查所列空间字段及 CT 的 Rescale 字段；所有 CT/MR IOD 条件并未完整实现。
其余组合明确拒绝，不能从接受的 SOP 名称推断支持完整临床语料。

脱敏输出递归按标签排序，避免继承输入的非标准顺序。
普通 round-trip API 仍保留其历史排序行为；语义比较按标签和 Sequence 项比较。

## 独立验收

官方 dicom3tools `1.00.snapshot.20260927113651` 的 arm64 可执行文件安装于隔离工具链。
原始 archive SHA-256 为 `29148a79ed793af4c664a6eb3247cb8a4d41b80c0f738f28c6b55930defd2b15`。
不将该可执行文件打包进 Mooncakes 或源码发行物。

`tools/verify_strict_profile.py` 生成四个合成单色 SC 对象，转换后经 pydicom
和 dciodvfy 检查，没有未处置 Error。证据为 `docs/evidence/p1-strict-iod.json`。

记录中保留三类 Warning：清空 Study Time/Study ID 导致不能直接构建 DICOMDIR；
Laterality 在合成来源中未知，保留为空，真实来源需要核对单侧/双侧/不适用条件。
没有把这些 Warning 删除或当成完整 Profile 认证。

独立检查不能替代像素风险审核，所有当前输出仍 `release_authorized=false`。
W0 已补 141 项规则条文/实现/正反例索引，W3 已补限定经典 CT 的独立体素/HU/几何验收。其他完整 CT/MR IOD、真实来源、接收者认证和像素隐私审查仍未声明完成。转换 manifest 始终不授予发布；最终签名放行属于独立的私有宿主流程。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
