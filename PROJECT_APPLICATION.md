# MedSeal-MBT 项目申报书

关联医学影像的一致性转换、标准交换与本地验证工具

| 项目 | 内容 |
| --- | --- |
| 参赛者 | 韩桢 |
| 联系方式 | 766903826@qq.com · 17889572851 |
| 项目方向 | MoonBit 医学影像生态库与开发工具；既有项目深化迭代 |
| 对应版本 | 0.4.0 社区发行快照；Apache-2.0 |

## 需求与实际价值

研究数据常由一组相互引用的 DICOM 文件组成。逐文件替换姓名可能破坏患者分组、Study/Series/SOP、跨文件引用和随访日期关系。MedSeal 面向影像开发者与研究管理员，提供可嵌入的 MoonBit 库、批量预检和可验证交付流程，降低自行实现医疗二进制格式、标准 JSON 交换与关联一致性的成本。

## 已实现能力

① 公共封闭集合 SDK：整批预算、患者/UID/日期一致转换和输出复验，失败不返回部分集合；② DICOM JSON：25 种 VR、PN/多值/Sequence、精确 DS/IS token 和 Part 10 重建，双向 pydicom 验证；③ 数据集预检：匿名错误分类、修复建议和策略影响；④ 持久身份、增量缓存、封存恢复、逐对象审核、Ed25519 签名与幂等目录接收；⑤ 固定 Orthanc 本地适配，真实上传/查询/取回及断连重试；⑥ 离线浏览器实验室与本机私有文件只读检查，Worker 预算/取消/超时、显式原值区域与匿名导出分离。

## MoonBit 生态贡献与技术实现

六个公共 api 包覆盖 DICOM、DICOM JSON、策略、验证、公开解释与 Native 授权提供方。MoonBit 实现格式、规则、身份/时间和集合关系；Python 3.12 承担私有 SQLite、密码库与本机作业协调；页面运行编译后的同一 MoonBit 核心。提供独立消费者、稳定 API/迁移契约、环境诊断、问题模板和可重跑门禁，支持其他社区项目复用。

## 可复核的工程证据

120 个已分类属性、141 个 Rulebook 索引、475 个固定案例；四后端测试 Native139、JS/wasm/wasm-gc 各86。独立检查实际 JSON/二进制输出及像素、HU、几何；授权 BSD 数学幻影与 1/16/64 MiB、100/1000 对象负载均有实测记录。真实隔离 Chromium 验证文件选择、预算前置、Worker 清除、匿名下载、恶意文本与 CSP。三平台 CI、固定 Orthanc 接收、干净目录门禁、独立 Mooncakes 安装与离线宿主演练由发行证据分别记录，源码包按提交逐文件回读。

## 支持边界

限定 Part 10、Explicit VR Little Endian、ASCII/ISO_IR 6/ISO_IR 192 与已列元数据子集；经典 CT 研究限单帧未压缩16位 MONOCHROME2。像素保真复制，不做 OCR、像素涂抹或诊断。浏览器私有模式只检查原文件，不生成去标识影像。工程演练不冒充临床现场、完整 IOD/Annex E 或完整 DICOMweb。

## 开源与验证入口

- GitHub：https://github.com/001-Elsa/MedSeal-MBT
- GitLink：https://gitlink.org.cn/Hzhhhh/MedSeal-MBT
- Mooncakes：https://mooncakes.io/docs/001-Elsa/medseal@0.4.0
- CI与发行证据：https://github.com/001-Elsa/MedSeal-MBT/actions

本稿经 AI 辅助整理；事实以0.4.0源码和发行验收记录为准，正式申报由韩桢本人完成。
