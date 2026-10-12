# 独立符合性与差分质量实验室

W1 使用原创合成数据，固定 DICOM 2025e、pydicom 3.0.1 和已审查策略预期。原始预期在 `conformance/expectations.json`，生成器不导入 MedSeal 转换实现，也不根据运行结果创建预期。所有文件均不含患者数据，按本仓库 Apache-2.0 许可提供。

## 运行与失败门禁

安装 `requirements-qa.txt` 与 `requirements-enterprise.txt`，构建 Native 后运行：

```sh
./tools/moon-local build --target native --deny-warn
python tools/verify_conformance.py --dciodvfy /path/to/dciodvfy --record tmp/w1-conformance.json
```

CI 上安装的 `moon` 可以替代本地工具链入口。`--dciodvfy` 指定独立 IOD 工具；缺少它的运行只验证四后端和独立编解码，不属于有独立 IOD 诊断的验收范围。版本、实际可执行文件摘要与未过滤诊断进入记录。选定工具的本机记录见 [W1 证据](evidence/w1-conformance.json)。

`conformance/manifest.json` 列出每例目的、类别、来源/许可、实际字节摘要、配置及预期。每例必需：缺失、字节修改、预期文件改变均失败。生成漂移也失败。单元测试包含内嵌字节，运行器仍逐个读取仓库夹具，因此内嵌副本不会掩盖缺失文件。报告分别列出实际 executed/passed/failed/skipped；零次执行不可能通过。

`python tools/generate_conformance_corpus.py --check` 核对固定制品；修改用例时先独立编写预期，再生成并运行。不要把失败结果复制到预期中。QA 命令会展示合成源值，其能力边界与生产公开解释 API 不同，不向 QA 工具输入真实患者数据。

## 四条检查链

| 检查 | 实际执行 | 能证明的范围 |
| --- | --- | --- |
| 编解码 | 每个成功例实际写出 DICOM，pydicom 重新读取并规范化比对 | 字段/Sequence、数值、多值、写回语义；像素字节不变、Meta 身份一致 |
| 字典/IOD | 120 属性的正确/错误 VR；VM、必需字段、值边界；标记的 SC 示例执行 dciodvfy 前后诊断 | 属性检查与选定完整 SC 样例；不等于全部 SC/CT/MR IOD |
| 策略 | 独立动作表、固定 UID 分配和日期模型，与真实转换结果比较 | 保留/清空/删除/替换/映射/平移/递归及条件优先级 |
| 关系/用途 | 闭合、自引用、未解决引用、跨患者、错误 Class、重复实例、Study/Series 所有权和角色冲突 | 闭合集合关系保持；W3 之前不声明 CT 体素/HU/空间用途已通过 |

四个核心后端都执行同一字节语料、独立预期和现有规则模型测试。私有系统适配仍只在实际支持的 POSIX Native 平台运行。

规则矩阵链接机器 Rulebook 的每项正负例、实际测试文件，并附字节案例。三值 Unknown、伪造模型、公开报告/HTML 恶意输入等不能由合法 DICOM 文件表达，保留 W0 的真实测试作为补充。公开边界、人工复核与签名验收还单独执行 `tools/verify_rulebook.py`，不从编解码成功推断授权。

## 独立诊断与已解释差异

pydicom 是宽松读取器，可读到未知属性、非支持 Profile 或部分无效文件；MedSeal 还实施严格字典、身份、字符集、资源和 Profile 限制。每个阻断例保留参考读取的接受/拒绝与原始警告，并解释范围。参考工具接受不覆盖独立严格预期。

dciodvfy 仅对标记为 IOD 示例的 SC 案例执行，属性单位样例可能故意在 SC 中加入 MR 字段，不把它们冒充完整 SC IOD。每个独立 Error 或非零退出均使运行失败。Warning 保留原文并逐类解释：

- DICOMDIR 需要 Study Time/Study ID：策略清空身份字段，研究目录接收器不构建 DICOMDIR，因此 DICOMDIR 用途不在本档范围。
- Laterality：合成输入没有定义成对解剖部位，空条件字段是输入限制，不声称可用于解剖侧别分析。

任何新 Warning 没有明确处置说明就失败。CT 仍为实验性已有字段子集，完整所选 CT Profile 与接收用途进入 W3；这里的零 Error 不扩张成完整标准或像素隐私认证。

## 本轮兼容修正

独立语料暴露并修复了标签 `FFFC,FFFC` 格式化时部分字符未大写的问题。尾部填充字段继续按严格策略删除，公开字段路径现在能通过相同允许列表。

公共验证工厂现在核对文件头 Media Storage SOP Class/Instance 与对象内身份。以前不一致输入可能通过该工厂，现在按 `file-meta-identity` 返回 `MEDSEAL-E530`。目录批处理也复用同一检查器；其此类错误由旧 `MEDSEAL-E520` 收敛为结构化规则错误。调用方应按代码和规则 ID 处理，不依赖原异常文字。
