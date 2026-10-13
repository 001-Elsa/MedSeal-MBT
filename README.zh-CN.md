# MedSeal-MBT

面向关联 DICOM 数据的 MoonBit 元数据转换、一致性检查与可验证交付工具。当前模块版本为 **0.2.2 工程预览**；真实发布结果以[整改与发布记录](https://github.com/001-Elsa/MedSeal-MBT/blob/master/docs/COMPETITION_REMEDIATION.zh-CN.md)为准。

## 当前已实现的范围

| 入口 | 能力 | 适用范围 |
| --- | --- | --- |
| MoonBit 公共库 | 策略编译、DICOM 读取/写回、验证、隐私安全的解释及受控授权类型 | 公共门面 `api/*`；文件和授权提供方要求 Native |
| 兼容集合 CLI | 作业内患者假名、身份 UID 映射、完整日期间隔、跨文件引用、清单与摘要 | 映射仅限本次作业，不使用持久身份库 |
| 私有工程宿主 | 跨批持久身份、增量缓存和去重、已交付历史引用、时间精度、封存恢复、逐对象审核、Ed25519 签名及幂等目录接收 | MoonBit Native + Python 3.12；受控 POSIX 本机部署 |
| 经典 CT 研究 Profile | 单帧、未压缩 16 位 MONOCHROME2；独立体素/HU/几何核验 | 限定 `ct-classic-research-v1`，三组合成系列验证 |
| 本地工作台 | 作业状态、解释摘要、分页对象和取消 | 回环地址、会话 capability/CSRF；单机工具 |

历史引用、重复转换/交付控制和恢复已实现；它们通过工程宿主使用。[W0–W7 账本](docs/WINNER_UPGRADE_STATUS.zh-CN.md)保存分阶段证据，旧 P/迭代核对表是对应提交的历史快照。实现完成、合成验证、真实现场验收是不同状态。

## 安装公共库并运行第一个例子

按[官方说明](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html)安装 MoonBit。已验证基线为 moon `0.1.20260920` / moonc `0.10.14+7d59c7ec9`。在自己的独立 MoonBit 模块执行：

```sh
moon add 001-Elsa/medseal@0.2.2
```

创建 `app/moon.pkg`：

```moonbit
import {
  "001-Elsa/medseal/api/policy",
}
pkgtype(kind: "executable")
supported_targets = "+native"
```

创建 `app/main.mbt`：

```moonbit
///|
fn main {
  try {
    let policy = @policy.strict()
    ignore(policy)
    println("public-policy-ok")
  } catch {
    _ => println("public-policy-rejected")
  }
}
```

执行 `moon run --target native app`，预期输出 `public-policy-ok`。这个例子只编译严格策略，不生成审核或放行许可。[公共 API](docs/PUBLIC_API.zh-CN.md)覆盖 `api/dicom`、`api/policy`、`api/validation`、`api/explain` 和 Native `api/authorization`。旧 `src/` 导入继续兼容。

## 安装源码命令行与完整演示

```sh
git clone https://github.com/001-Elsa/MedSeal-MBT.git
cd MedSeal-MBT
moon update
moon run --target native examples/collection
```

示例生成两个合成患者、四个文件和两条引用，执行转换及清单验证，打印新建的 `tmp/demo-...` 目录；样例没有真实患者数据。当前工作区可把 `moon` 换成 `tools/moon-local`，使用 `../moonbit工具链`，不修改系统配置。

```sh
moon run --target native cmd/main -- plan INPUT_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- batch INPUT_DIR --output NEW_JOB_DIR --policy examples/research-policy.json
moon run --target native cmd/main -- verify NEW_JOB_DIR
moon run --target native cmd/main -- inspect samples/input.dcm --json
moon run --target native cmd/main -- validate samples/input.dcm --json
mkdir -p tmp
moon run --target native cmd/main -- anonymize samples/input.dcm --output tmp/single.dcm --report tmp/single.json --remove-private
```

`plan` 检查患者分组、身份、引用和策略；`batch` 在私有暂存中形成匿名编号 DICOM、逐对象审计和 SHA-256 清单，再发布全新目录。输入/输出不得嵌套，输出目录必须不存在；源内容变化、身份冲突和未授权断裂引用会失败。`verify` 复核完整性及支持的结构，不代表隐私全面合格。

集合模式每位患者使用同一假名和独立非零日期偏移；同一身份 UID 在 File Meta、主体及受支持引用中一致。basic `anonymize` 保留 UID、使用固定别名，DICOM 与独立报告不能作为同一目录事务发布。具体限制见[策略](docs/POLICY.md)与[支持矩阵](docs/SUPPORT_MATRIX.md)。

## 跨批、审核和交付

工程宿主需要 Python 3.12，按[部署与恢复手册](docs/OPERATIONS.zh-CN.md)安装受控离线包，初始化身份库，执行 create/run/resume、review/publish/deliver 和备份轮换。严格策略、运行程序、封存内容或审核变动时重新核验；不能通过修改记录绕过失败。

[增量账本](docs/INCREMENTAL_LEDGER.zh-CN.md)解释来源域、同内容复用、相同 SOP 内容冲突及历史引用边界。[工作台](docs/WORKBENCH.zh-CN.md)复用上述流程。[三类完整场景](docs/USE_CASES.zh-CN.md)覆盖影像开发者批处理、纵向研究增量导入和工具作者嵌入公共库；场景为预期用途与合成验证，不冒称医院采用。

## 验证与维护

```sh
moon info
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native
moon package
python3.12 -m pip install -r requirements-qa.txt -r requirements-enterprise.txt
python3.12 tools/verify_with_pydicom.py
python3.12 tools/verify_ct_research.py --record tmp/ct-research.json
python3.12 tools/verify_release_readiness.py
```

CI 覆盖 Linux/macOS/Windows 核心；POSIX 工程宿主与离线安装验收在 Linux/macOS 执行，Windows 不属于企业部署认证范围。固定语料、生成漂移、失败门禁与独立读取分别验证；证据标明源码版本，不能把配置存在当成执行成功。[贡献指南](CONTRIBUTING.md) · [变更记录](CHANGELOG.md) · [新增贡献与语言边界](docs/CONTRIBUTION.md)。

## 支持与隐私边界

支持 Part 10、Explicit VR Little Endian、ASCII / ISO_IR 192 和已列 Sequence/元数据规则。经典 CT 是限定研究 Profile，MR/SC 元数据检查不等于完整 IOD。压缩传输语法、未知公共 UID 角色、编码和身份冲突明确拒绝。

保留像素字节，不做 OCR、像素涂抹或医疗诊断；未知公共字段与烧录文字仍需人工审查。不声明完整 Annex E 匿名化、PACS/DICOMweb 或真实现场生产验收。合成审核始终标记 synthetic，不能用于患者数据。[安全](SECURITY.md) · [流式上限](docs/STREAMING.md) · [现场门槛](docs/W7_FIELD_EVIDENCE.zh-CN.md)。

Apache-2.0；[依赖、标准与样例来源](THIRD_PARTY.md)。[GitHub](https://github.com/001-Elsa/MedSeal-MBT) · [GitLink](https://gitlink.org.cn/Hzhhhh/MedSeal-MBT) · [Mooncakes](https://mooncakes.io/docs/001-Elsa/medseal)。

## 文档与提交材料

[全部文档索引 / document audit](docs/DOCUMENTATION_STATUS.zh-CN.md) · [项目提交指南](docs/SUBMISSION_GUIDE.zh-CN.md) · [申报事实与答辩提纲](docs/SUBMISSION_MATERIALS.zh-CN.md)。姓名：韩桢。正式表单由本人提交；项目发布不代表已经取得报名回执。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
