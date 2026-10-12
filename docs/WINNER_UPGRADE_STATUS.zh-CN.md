# W0–W7 升级实施账本

执行依据：[完整方案](WINNER_DRIVEN_ROADMAP.zh-CN.md)与[13 项对标研究](WINNER_RESEARCH.zh-CN.md)。本账本记录实现与实际验收，方案本身不改写为完成报告。原 P0–P7 的范围和未完成项继续保留。

| 阶段 | 当前状态 | 已形成的证据与剩余门槛 |
| --- | --- | --- |
| W0 | 实现、本机验收与三平台远端 CI 通过 | 141 项规则索引、固定官方事实、三值条件、公开解释／Schema／四案例、公共门面与受控状态；Native 115，JS/wasm/wasm-gc 各 62；恢复／审核／签名回归；不扩张为完整 IOD 认证 |
| W1 | 实现、本机 M1/M2 合成验收与三平台 CI 通过 | 473 实际案例，六类，零失败/跳过；四后端一致；pydicom 实际写回，选定 SC 的 dciodvfy 原始诊断，闭集合正反例；完整 CT Profile 留 W3 |
| W2 | 实现、本机阶段验收通过；待提交与远端 CI | 私有缓存／迁移、已交付历史引用、时间精度、outbox 与计数守恒；证据见 `evidence/w2-incremental.json`、`evidence/w2-destination.json`、`evidence/w2-conformance.json`、`evidence/w2-rulebook.json` |
| W3 | 实现、本机合成验收通过；待提交与远端 CI | `ct-classic-research-v1` 限定矩阵、CT 模块/条件门禁、三组各 50 切片、独立体素／HU／几何接收；证据见 `evidence/w3-ct-research.json` |
| W4 | 待实施 | 作业模型／提交窗口、100,000 次 fuzz、模型 seed、1/8/32 GiB 资源档 |
| W5 | 待实施 | 受控本地工作台、权限／跨站防护、分页与操作者闭环 |
| W6 | 待实施 | 仓库外归档和 registry 消费者、候选发行、镜像一致与隔离安装 |
| W7 | 软件演练待实施；实际主体项 requires_field | 新操作者、真实授权来源与研究接收、独立审查；这些材料不能由实现者或合成测试代填 |

## W0 验收记录

- [公共契约与迁移](PUBLIC_API.zh-CN.md)、[逐规则索引](RULEBOOK_INDEX.zh-CN.md)、[机器账本](../resources/rules/rulebook-v1.json)。
- [本机执行证据](evidence/w0-rulebook.json)包含程序／规则／代码内容指纹、实际四例和九项验收；使用 source_base_commit 明确提交前的基线，内容指纹覆盖变更后的代码。
- 字典比对与条件测试可在四个后端执行；私有审核提供方只承诺已有受控 POSIX Native 范围，Windows 不运行该提供方验收。
- 原审核、签名、独立验签与恢复门禁继续复用；没有新增自动像素放行，没有实际研究交付。
- 修复提交 `4ec37cf67ddd1132bed403f1b51b780fa8a5cb55` 三平台 CI 已读回成功：[不可变运行](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38221826399)，[记录](evidence/w0-ci.json)。
- 首次 W0 提交 `17f3ac4` 的 Linux/macOS 检查通过，Windows 检出的 CRLF 改变规则事实文件摘要，生成漂移检查失败；已加入固定 LF 的仓库属性，保留原摘要门禁；修复提交三平台均通过。

## W1 验收记录

- [运行与范围说明](CONFORMANCE_LAB.zh-CN.md)、[固定语料清单](../conformance/manifest.json)、[本机证据与逐规则矩阵](evidence/w1-conformance.json)。
- 464 个单对象案例与 9 个闭集合案例，共 473 个实际执行，失败 0、跳过 0；480 个必需字节夹具包括集合成员。Native 全套 114 项，JS/wasm/wasm-gc 各 61 项，内嵌语料内逐例计数。
- 140 项规则保留来源与正反例；其中新增文件头身份一致性检查。标记 SC 样例各执行转换前/后独立 IOD 检查，保留全部 Warning 与用途说明。
- 必需文件缺失、字节篡改、预期文件篡改均由实际门禁拒绝；W0 公开边界/提供方九项、持久身份七项、恢复七项回归通过。
- 本机证据绑定变更代码树/二进制/规则/语料/实际依赖指纹，source_base_commit 明确为提交前基线；提交后的最终 SHA 由远端 CI 制品绑定。
- 两项兼容修正：高位标签统一大写；不一致 File Meta 身份按 `file-meta-identity` 结构化拒绝。没有自动像素授权，没有真实来源验收，也未声称完整 CT/MR。

- W1 首次推送 `874caaa` 的 Windows 在规则索引读取中文源文件时采用 CP1252，门禁失败。修复为显式 UTF-8 读写与子进程解码，同时固定集合路径列表为 LF；保留所有核心/差分检查。修复提交 `a7dd6af73b6edf5ad5cc12c1bd7b6393f0a6b480` 三平台均已读回成功：[运行](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38228352839)，[记录](evidence/w1-ci.json)。

## W2 验收记录

- 日期时间解析、对象级缓存与账本迁移已实现。新增 2 个独立字节语料后，475 个案例通过四后端核心检查，失败与跳过均为 0。
- 目的地身份已绑定计划、审核、签名包和本地接收目录；实际端到端演练验证重复交付、逐对象内容寻址、历史引用、目标篡改拒绝和丢失回执重建。
- `tools/verify_incremental.py`、`tools/verify_destination.py`、四后端 conformance、rulebook、持久身份、恢复、风险门和签名接收回归均通过。材料全部为合成私有输入；真实患者、真实操作者、真实接收方、独立审查和远程 PACS 仍保留为现场证据。

## W3 验收记录

- [`ct-classic-research-v1` 矩阵](../resources/rules/ct-classic-research-v1.json) 固定经典 CT、单帧、Explicit VR Little Endian、未压缩 16 位 `MONOCHROME2` 范围；MoonBit 入口 [`check_classic_ct`](../src/conformance/ct_profile.mbt) 逐层检查模块字段、CT 条件、像素位语义、HU 单位和几何向量。
- [`tools/verify_ct_research.py`](../tools/verify_ct_research.py) 实际生成三组各 50 个切片，运行真实批处理后由独立 pydicom 接收器检查排序、解码体素、HU 重算和空间坐标；体素差异为 0，HU 最大绝对误差为 0，几何误差为 0。
- 缺片、重复位置、方向混合、非 HU 单位和压缩传输语法五类负例均明确阻断。证据绑定提交前源码树、Profile、工具和原生二进制指纹；全部数据为合成非临床数据。
- 真实扫描设备、真实来源授权、烧录文字/识别性像素审查、独立研究接收方和临床用途仍保留为 `requires_field`；增强 CT、多帧、压缩像素和任意厂商扩展不在该 Profile 内。
