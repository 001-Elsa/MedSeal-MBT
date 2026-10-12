# MedSeal-MBT

获奖项目对标后的 W0 新增[规则账本与公共 API](docs/PUBLIC_API.zh-CN.md)、安全对象解释和合成报告；[W0–W7 升级状态](docs/WINNER_UPGRADE_STATUS.zh-CN.md)逐阶段记录实际完成情况。

MedSeal-MBT 使用 MoonBit 处理 DICOM 元数据。0.2.0 在原有单文件解析、校验、脱敏和二进制写回基础上，新增**多文件患者假名、身份 UID 一致映射、日期间隔保留、引用校验和作业验证**。

目前为验证过的 0.2.0 候选版本，源码已按功能更新到 GitHub。Mooncakes 公共版本仍是 0.1.1，GitLink 同步与新版包发布尚未执行。原深化方案尚未逐项全部完成，已完成范围和差距见[逐项核对表](docs/PLAN_AUDIT.md)。

## 企业工程预览

P0–P7 已推进到离线安装和合成闭环演练。企业入口提供持久化身份、封存恢复、原生像素流式处理、逐对象审核、签名及独立接收验证；合成120MiB载荷峰值约29MiB，包含风险记录的10,000小对象最新复测约187MiB。核心转换仍由 MoonBit 实现，私有事务/密码适配使用 Python3.12。

当前不是生产1.0，完整CT/MR语义、历史外部引用、重复对象去重以及真实来源/接收方验收仍有未完成门槛。[实施与证据](docs/ENTERPRISE_STATUS.md) · [操作恢复手册](docs/OPERATIONS.zh-CN.md) · [现场验收表](docs/FIELD_ACCEPTANCE.zh-CN.md) · [流式支持范围](docs/STREAMING.md)。原库/CLI兼容路径继续保留；企业预览的受控部署目前是POSIX，本机离线安装认证为macOS ARM64。

## 直接运行

当前工作区已安装独立工具链。在项目目录执行：

```sh
tools/moon-local run --target native examples/collection
```

这个纯 MoonBit 示例创建两个合成患者、四个影像文件和两条引用，执行预检、转换和输出验证，并打印结果所在的 `tmp/demo-...` 目录。合成文件可以直接查看，不包含真实患者数据。

工具链在项目外的 `../moonbit工具链`，启动脚本不会修改系统配置；没有该目录时，脚本使用 PATH 上的 MoonBit。

## 处理一个数据集

```sh
tools/moon-local run --target native cmd/main -- plan INPUT_DIR --policy examples/research-policy.json
tools/moon-local run --target native cmd/main -- batch INPUT_DIR --output NEW_JOB_DIR --policy examples/research-policy.json
tools/moon-local run --target native cmd/main -- verify NEW_JOB_DIR
```

- `plan` 检查患者分组、UID、引用、日期和规则，不创建输出目录。
- `batch` 使用整个作业共享的映射逐文件处理；所有检查成功后发布新的结果目录。输入和输出不得嵌套，输出目录必须不存在。
- `verify` 重新检查清单中的 DICOM/审计 SHA-256、文件头、私有元素和跨文件引用。它验证完整性和结构，不能证明全部隐私均已清除。

输出目录包含 `object-1.dcm` 等匿名编号文件、各文件的动作审计和 `manifest.json`。审计包含元素路径与规则编号，不含原患者值、原文件名、原 UID 映射表或实际日期偏移量。

同一患者的多个影像保持一个假名；不同患者不会统一变成 MEDSEAL-ID。同一身份 UID 在主体、File Meta 和引用中保持同一映射。每位患者随机获得一个非零日期偏移，同一患者所选完整 DA 字段的时间间隔不变。

`date_shift_days: 30` 表示随机偏移的最大正向天数，不表示所有患者统一偏移 30 天；负数表示负向范围。实际偏移和映射仅存在于本次进程内。默认闭合集合不允许断裂引用，可显式允许外部引用，但未解析部分始终保留为未验证计数。

## 兼容的单文件入口

```sh
tools/moon-local run --target native cmd/main -- inspect samples/input.dcm --json
tools/moon-local run --target native cmd/main -- validate samples/input.dcm --json
tools/moon-local run --target native cmd/main -- anonymize samples/input.dcm --output tmp/single.dcm --report tmp/single.json --remove-private
```

先创建 `tmp` 目录。原 basic 模式保留固定字段替换、UID 保留和私有元素选项；它不具备 research 模式的患者分组及引用验证。单文件 DICOM 和报告位于两个不同位置，不能作为一个原子事务发布；报告状态为 `verified`，以命令退出成功确认操作完成。需要完整作业交付时使用 `batch`。

## 验证工程

```sh
tools/moon-local fmt --check
tools/moon-local check --target all --deny-warn
tools/moon-local test --target all --deny-warn
tools/moon-local build --target native
tools/moon-local info
tools/moon-local package
```

工具链基线：moon `0.1.20260920`、moonc `0.10.14+7d59c7ec9`。CI 固定相同编译器和标准库版本；最新源码已通过 Linux/macOS/Windows 检查、构建、测试、示例和独立 pydicom 验证。Apple Silicon Mac 本地记录与[远程 CI 证据](docs/evidence/github-verification.json)分别保存，证据均注明对应源码版本。

开发对照检查：Python 3.10+ 安装 `pydicom==3.0.1`，运行 `python tools/verify_with_pydicom.py`。工作区已把它安装在独立工具链的 `python-packages` 目录。测试生成支持范围内的合成文件，再由 pydicom 检查输出，验证患者分组、日期间隔、引用、像素字节及清单摘要。

## 范围与失败行为

支持 Part 10、Explicit VR Little Endian、ASCII / ISO_IR 192、定义/未定义长度 Sequence。research 集合只接受 CT Image Storage、MR Image Storage 和 Secondary Capture 的已列元数据规则，不检查完整 IOD。未知公共 UID 角色、患者键冲突、重复 SOP Instance、错误 File Meta、非法日期、未授权外部引用和不支持编码会明确失败。

像素数据不被解码、识别或涂抹；未知公共描述字段可能含身份信息，报告始终保留剩余风险。此版本不提供完整 DICOM 脱敏 Profile 的合规声明，不自动设置完全身份移除标记，不保证完全匿名化。

上述兼容库/CLI 的映射仅限本次作业，失败后重新预检；进程硬中断可能遗留私有暂存目录。企业入口另提供跨批身份、密钥持久化和显式 resume 恢复，具体操作见企业手册。当前两种入口都未支持压缩传输语法、PACS/DICOMweb 或医疗诊断。

详情：[支持矩阵](docs/SUPPORT_MATRIX.md)、[策略与库 API](docs/POLICY.md)、[验收证据](ACCEPTANCE.md)、[性能记录](BENCHMARKS.md)、[同类对照](docs/RELATED_WORK.md)、[迭代进度](docs/ITERATION_STATUS.md)。

升级目标与完整验收门槛见[企业级深化升级方案](docs/ENTERPRISE_ROADMAP.zh-CN.md)；已落实能力和未完成条件以[企业实施记录](docs/ENTERPRISE_STATUS.md)为准，方案中的拟议版本号不表示已经发布。

Apache-2.0。第三方依赖和合成数据来源见 [THIRD_PARTY.md](THIRD_PARTY.md)。
