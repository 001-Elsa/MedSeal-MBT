# MedSeal 离线规则实验室（0.5.0 当前源码）

本实验室帮助 MoonBit 开发者理解：一个关联影像集合如何经过严格策略、哪些字段被处理、引用不完整时为什么阻断。它直接运行项目编译出的 MoonBit 核心；JavaScript 只连接控件、渲染表格和下载公开解释，没有另写 DICOM 转换算法。

## 构建与使用

要求已安装项目固定 MoonBit 工具链及 Python 3；页面构建不需要 Python 医疗库、Node 包、服务端、CDN 或联网。源码依赖需事先 `moon update`。在仓库根目录：

```sh
python3.12 tools/build_community_lab.py
```

当前工作区可用同级隔离工具链，构建器会自行定位。其他环境支持 `MOON_BIN` 指定 MoonBit 可执行文件。

生成的 `tmp/community-lab/index.html` 是可以复制到离线电脑的**自包含单文件页面**。在普通浏览器中打开该文件；`engine.mjs`、`samples.json` 和 `build.json` 是验收辅助文件，页面运行不依赖它们。当前 Codex 内置浏览器禁止访问 `file:`，因此没有通过该浏览器完成渲染验收；这不是用户需要重新登录的问题。

操作顺序：

1. 默认运行两份关联 SC 合成影像，查看对象数、引用数和逐字段决定。
2. 把策略切到“移除研究描述”，再次运行，查看 `(0008,1030)` 从清空到移除的动作变化。支持过滤路径/规则。
3. 切换缺失目标、重复 SOP、损坏文件，观察整组被阻断，成功数量及旧结果被清除。
4. 无效预设试图保留严格描述字段，应得到策略拒绝；高级编辑器可复现其他小型策略。
5. 导出只含受限决定或公开错误的 JSON。策略原文、影像值、原 UID、seed/偏移和本机路径不导出。

## 输入与信任边界

- 教学模式只使用固定合成样例；0.4.0另有独立本机只读文件模式，无上传入口。教学两份影像逐文件校验固定 `conformance/manifest.json` 摘要与 Apache-2.0 来源。
- `web/core.analyze(String, String)` 是 JSON/hex 桥接：输入传输文本最多 2 Mi 个字符、1–16 个对象；因此解码总量还受约 1 MiB 十六进制上限约束。策略 UTF-8 至多 16 KiB。核心 SDK 仍独立执行自己的集合预算。
- 结构展示每对象最多 512 个节点，达到上限明确标注；只显示路径和 VR，不显示原值。解析器深度/元素上限继续生效。
- 固定合成 seed 和每患者 1 天偏移不适用于真实作业；本页没有跨作业数据库、人工审核、OCR、签名、交付或医疗适用性保证。
- 页面设置 `connect-src 'none'`、默认禁止外部资源，并以实际内联模块的 SHA-256 授权脚本。无外部脚本、字体、图片、遥测、文件上传和 Service Worker。构建器拒绝额外 `</script>`，界面用 `textContent` 展示输入与报告。
- CSP摘要由Node检查；V5另用真实Chrome154完成实际强制执行、排版、下载和键盘激活检查，证据范围与Node测试分列。

## 可复现实跑

仅测试需要 Node 22+ 和固定 `linkedom` 开发依赖：

```sh
pnpm --dir web install --frozen-lockfile --ignore-scripts
python3.12 tools/build_community_lab.py
node tools/verify_community_lab.mjs
moon test --target all web/core
```

Node 运行实际编译的 `engine.mjs`，再用 linkedom 模拟页面事件，检查成功/失败、策略动作变化、筛选、状态清除、导出、预算、原值金丝雀和内联脚本摘要。linkedom 缺少浏览器的 `select.value` setter，测试只补这一项，并在结果中明确列出。没有启动浏览器或请求外网；不证明 CSS 渲染、浏览器下载行为或 CSP 强制执行。

`tmp/community-lab/build.json` 绑定源码文件摘要、固定夹具、编译核心和页面摘要；`acceptance.json` 明确 `rendered_browser_verified:false`、`csp_enforcement_verified:false`。CI 在三个 OS 上重新构建并上传这些产物；配置已存在不等于远端运行成功。

该功能最初纳入 0.3.0 社区发行版，0.4.1补齐私有视图修正；当前源码构建使用0.5.0核心。原Node/浏览器测量保留其原阶段，不冒充本轮浏览器重跑。新版 Mooncakes/GitLink 发布状态分列在[社区升级方案](COMMUNITY_ROADMAP.zh-CN.md)，不会改写旧版本证明。


## V5 真实浏览器验收和逐字段比较

新增逐字段上次/本次动作表，失败时清除旧成功结构和比较结果。`tools/verify_lab_browser.mjs` 使用隔离临时浏览器状态，实际运行编译核心、键盘Enter激活、筛选、阻断清除和恢复、真实下载及金丝雀、1280/390px排版，并实际注入未授权脚本和网络请求确认CSP拦截。后者是验收探针，不是产品网络功能；没有外部请求发出。Chrome154.0.8037.98的8项检查已本机通过；不代表全部浏览器或读屏器认证。

```sh
# 使用项目固定playwright；CI安装其固定Chromium
pnpm --dir web install --frozen-lockfile --ignore-scripts
pnpm --dir web exec playwright install chromium
python3.12 tools/build_community_lab.py
node tools/verify_lab_browser.mjs
# 本机也可显式 MEDSEAL_CHROME=/本机/Chrome可执行文件路径
```

`browser-acceptance.json`明确真实浏览器/CSP/键盘为true，`acceptance.json`继续只描述Node/DOM。两个结果不互相替代。0.4.0 已完成[私有文件模式](PRIVATE_FILE_VIEW.zh-CN.md)；教学模式与本机只读检查独立清除状态。

## 0.4.0 本机私有检查已开放

教学模式继续使用固定合成样例；新增独立的[本机私有文件模式](PRIVATE_FILE_VIEW.zh-CN.md)，原始文件在 Worker 只读验证，绝不使用教学固定 seed/偏移。匿名摘要和显式私有文本原值分离；取消、清除、超时与模式切换终止任务并清空状态。运行 `node tools/verify_private_browser.mjs` 实际验证，详细预算和边界见上述文档。
