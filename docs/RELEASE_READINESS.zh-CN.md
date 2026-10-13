# W6 候选发行与平台回读

本阶段把“本地候选包已经构建”与“公开平台已经发布”分成两个可核对的事实。
`tools/release_readiness.py` 不登录、不上传、不替代平台发布按钮；它固定模块版本、
来源提交、归档内容清单、依赖、SHA-256 和 CI 链接，并可读取发布人从 Mooncakes、
GitLink 页面导出的最小观察 JSON。

## 生成候选发行证据

在干净的 Git 提交上先构建包，再运行：

```sh
python3.12 tools/release_readiness.py \
  --archive _build/publish/001-Elsa-medseal-0.2.0.zip \
  --record tmp/release-readiness.json \
  --ci-url https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38349000368
```

记录中的 `candidate-ready-for-platform-publish` 只表示归档可交给发布人，
`publication_authorized` 固定为 `false`。归档成员不得含有 `.git`、`.mooncakes`、
`tmp`、私有映射或密钥目录；归档中必须有 `moon.mod`、README、许可证和第三方声明。

## 平台观察文件

发布人完成平台登录或页面操作后，把页面事实保存为单独 JSON，再用相同命令增加：

```sh
--mooncakes-observation tmp/mooncakes-observation.json \
--gitlink-observation tmp/gitlink-observation.json
```

最小格式如下，`source` 要写清楚是页面、平台 API 还是平台导出的记录：

```json
{
  "platform": "mooncakes",
  "source": "manual browser observation",
  "observed_at": "2026-10-13T12:00:00+08:00",
  "url": "https://mooncakes.io/docs/001-Elsa/medseal",
  "status": "published",
  "observed_version": "0.2.0",
  "observed_commit": "optional-platform-value",
  "notes": "页面显示版本、下载数和包摘要"
}
```

只有 `status=published` 且 `observed_version=0.2.0` 才会把该平台标成
`candidate_visible=true`。GitHub CI、Mooncakes、GitLink、Git tag 和 Release
分别记录，任何一项都不能从另一项推断。平台页面显示旧版或没有可验证版本时，
保持 `pending`，不要修改成成功。

## 发布前后核对表

1. 核对 `moon.mod` 的模块名、版本和依赖；确认候选提交与 CI 运行号一致。
2. 记录归档 SHA-256 和 manifest 成员摘要，发布前保存一份只读副本。
3. 按平台流程发布或同步，保存平台返回的版本、提交、包摘要、时间和操作者。
4. 重新运行回读工具，确认公开版本确实是 `0.2.0`；失败时保留旧版，不重试未知状态。
5. 从公开包做一次仓库外消费者验收，确认消费者没有偷偷解析本地 `src/`。
6. 只在真实操作者、真实数据来源、接收方和独立审查材料齐全后，推进 W7 的现场状态。

0.2.0 已实际发布；本页说明发行核验工具，不代表发布仍待完成。旧 w6-release-readiness.json 是早期历史记录（曾漏依赖），完整替代证据见 release-0.2.0-source.json 与[发布后回读](COMPETITION_REMEDIATION.zh-CN.md)。后续文档提交不能冒充 0.2.0 的冻结源码 bc5b25c。新版本必须从自己的干净源码、归档与 CI 重新核验。

本工具不证明临床适用性、像素隐私通过、真实 PACS 接收或生产 1.0。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
