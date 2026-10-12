# 公共 API 与解释契约 v1

W0 建立公共门面，旧 `src/` 导入和已有命令继续可用。所有类型状态表示工厂在指定时刻完成过相应核验，不自动授予以后一次文件操作的许可。

| 导入路径（模块前缀 `001-Elsa/medseal/`） | 用途与边界 |
| --- | --- |
| `api/dicom` | 读取和写入 Explicit VR Little Endian；单独解析不代表 IOD 合格或允许交付 |
| `api/policy` | 严格策略编译、规范摘要；身份、日期、结构字段不能被描述字段规则覆盖 |
| `api/validation` | `validate(Bytes)` 创建不受调用方数组修改影响的 `ValidatedObject`；`convert` 使用已准备的严格 Context，重新验证输出和写回值，返回 `ConvertedObject` |
| `api/explain` | 配置／对象／当前集合关系的公开解释，及版本化 `ValidationIssue`；原值、原 UID／日期、输入摘要、本机路径、偏移、替换内容与管理员规则 ID 不进入公开出口 |
| `api/authorization` | Native 受信任提供方；重新核验当前审核门禁或 Ed25519 包，创建 `ReviewEvidence`／`AuthorizedPackage`；输入 JSON 中的 true 不能创建这些状态 |

`private_dataset`、`private_bytes` 返回私有内容，只可用于受控处理和交付。解释类型没有这些内容的序列化出口。Bytes 在当前工具链不可变；每次读取 Dataset 都重新解析成独立数组。状态类型构造器为包内私有，没有“已审核=true”工厂，也没有未经核验的反序列化工厂。

Native Verifier 由受信任管理员配置，固定解释器和完整的八文件已审计运行时闭包的指纹，每次调用前后检查，并使用参数数组执行。它复用原审核门禁和独立签名验证器，合成上下文必须显式选择 `SyntheticTest`。这不防御恶意管理员、被替换的系统解释器依赖或本机存储管理员。审核、签名、发布与接收的实际操作仍在执行前重新检查；先前创建的类型实例不能跳过这些门禁。

新增入口：`medseal explain-object INPUT [--policy POLICY]`。它在内存中复用严格转换决定并输出 `explanation-v1.schema.json` 对应 JSON，不写入交付影像，不产生放行。读取、策略编译与验证错误也使用同一公开错误边界。旧 inspect、validate、explain 的诊断接口保留原私有语义，分享时使用新的公共接口和报告。

条件为 `met`、`not-met`、`unknown`，支持 Kleene 合取／析取。缺失的完整对象字段可判不成立；不完整对象中的缺失字段为 Unknown。SOP 缺失或不可解释为 Unknown。`require_condition` 对 Unknown 阻断，生产 SOP 模块分支调用此求值。现有模块必需性仍为部分集合，完整 Type 1C/2C 矩阵属于 W3，不能从三值求值推出所有条件均已实现。

Rulebook 固定 DICOM 2025e：120 个属性的 VR/VM 已逐项比对官方 PS3.6 与固定 pydicom 字典；PS3.15 表动作单独作为事实记录；MedSeal 选择的保留／替换／平移动作有独立策略说明。21 项现有约束另行列出，必需字段类型、SOP 分支、文件头身份和时间精度不混入属性字典。141 个索引项均有实现与正反例入口。属性用例证明 VR/VM 分类接口；它们不是完整去标识动作、IOD 或 Annex E 的证据，W1/W3 将补独立预期和用途验证。

四个[合成解释案例](examples/rule-explanation/condition-met.html)提供 JSON、无外部资源的 HTML 和 SVG。报告渲染器只读取结构路径、已登记规则和动作，丢弃其他输入；不显示患者假名或映射 UID，也不把所有诊断字段原样转成 HTML。

## 兼容与迁移

W0 把已有严格拒绝转为 `RuleViolation`，公开错误码为 `MEDSEAL-E530`；旧异常类型仍存在，异常消息不应当作稳定 API。Sequence 执行事件由含糊的 keep 改为 recurse，影像内容不因此改变。新增 `(0012,0063)` 方法标记的字典事实供输出重新验证；原有重复处理拒绝继续生效。

字典、规则与程序指纹变化会使旧运行计划、审核与缓存失效。这是预期行为。需要恢复旧作业时使用其原固定运行包；重新转换时从封存的原输入建立新作业，不能把已处理影像再次平移日期，也不能把旧审核改成当前摘要。

核验：`tools/verify_rulebook.py` 校验规则索引、生成漂移、Schema、实际解释、原值金丝雀和 Native 证据工厂；四后端测试覆盖规则条件及生产字段检查。结果记录代码范围的内容指纹和程序／规则指纹，提交前的运行明确记为 source_base_commit；远端 CI 制品由 GitHub 运行绑定提交 SHA。
