# 三平台完整源码同步

当前模块版本：0.4.0。参赛者：韩桢。同步范围经本人确认：现行 MedSeal 源码、自有辅助脚本和相关维护文档。

GitHub：<https://github.com/001-Elsa/MedSeal-MBT>；GitLink：<https://gitlink.org.cn/Hzhhhh/MedSeal-MBT>；Mooncakes：<https://mooncakes.io/docs/001-Elsa/medseal@0.4.0>。

## 文件范围

以本仓库的 Git 跟踪文件为唯一完整清单，包括源码、公共 API、测试、合成夹具、资源、文档、已有历史证据、自有脚本，以及 `.github`、`.githooks`、`.gitattributes`、`.gitignore`、`.moonignore`。三个平台的源码文件路径和内容须完全相同；Git 服务的提交历史、网页、数据库与 ZIP 容器本身不属于文件对比范围。

父目录旧方案与研究报告的现行维护版本已分别收录在 `docs/ITERATION_PLAN.md`、`docs/WINNER_RESEARCH.zh-CN.md`、`docs/WINNER_DRIVEN_ROADMAP.zh-CN.md` 和企业路线图；不再上传陈旧的重复副本。自有研究辅助脚本见[使用说明](RESEARCH_TOOLS.zh-CN.md)。

不纳入：`满意度数据波动` 及指向它的 `outputs/skills` 符号链接；第三方研究源码、旧 MedSeal 副本、历史申报生成器；GitHub/GitLink/MoonBit 登录凭据与开发工具二进制；依赖缓存、构建输出、临时作业、私有映射和真实影像。离线安装包、申报 ZIP、发布后的平台回执另存父目录版本产物，不冒充模块源码。

## 发布与冻结

`.moonignore` 使用默认拒绝、逐文件允许，补齐 Mooncakes 默认忽略的隐藏文件，并排除未受审查的本地文件。新增、删除文件后先审查并加入 Git 索引，再重新生成：

```sh
python tools/verify_platform_snapshot.py --write-allowlist
git add .moonignore
```

完成版本、文档、测试和 CI 修改后提交并冻结。随后构建并核验：

```sh
moon package --frozen
python tools/verify_platform_snapshot.py \
  --archive _build/publish/001-Elsa-medseal-0.4.0.zip \
  --record tmp/source-snapshot.json
```

核验必须达到：缺失文件 0、额外文件 0、内容差异 0。CI 同样运行该检查。允许清单过期、归档含非跟踪成员、符号链接或路径越界时失败。

同步冻结提交至 GitHub 和 GitLink 的 master 与 v0.4.0 标签；发布同一包至 Mooncakes。再从两家 Git 服务读取该提交和源码，从 Mooncakes 官方下载 ZIP，与本地 Git 快照逐文件、逐字节对比。对官方包重新运行真实 registry 消费者，不能回退本地源码。

发布后的提交号、平台返回、完整摘要清单、CI、消费者和安装证据写到源码树外，例如父目录 `MedSeal参赛核验/release-0.4.0/`。本页描述协议和候选内容，发布前不伪造成功；核验结果以该外置报告为准。冻结后不再单独追加“发布成功”文档，否则最新仓库又会领先固定包。任何下一次变更需新版本整体重新发布。

0.2.0、0.2.1 的固定证据保留原值；本轮增加已列明的 JSON 子集、集合 SDK 与本地适配器，不代表 W7 真实医疗现场验收或正式申报成功。版本升级会改变运行时指纹，已固定作业继续使用原运行时。

验收脚本的默认运行证据均写入临时目录；持久身份与 W4 可用 `--record` 显式指定外置记录。CI 打包后再次检查 Git 工作区，发现任何受跟踪文件变化即失败，不自动恢复或隐藏差异。
