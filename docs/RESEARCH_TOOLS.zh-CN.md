# 自有研究辅助脚本

`tools/research/collect_sources.py` 和 `tools/research/build_review.py` 来自本人先前的七月项目研究工作。本轮保留研究算法与固定历史结论，增加显式输入/输出目录，防止重新生成历史报告时覆盖现行维护文档。

```sh
python tools/research/collect_sources.py --output-dir tmp/winner-research
python tools/research/build_review.py \
  --input-dir tmp/winner-research --output-dir tmp/winner-research-report
```

收集脚本读取官方公开名单与 GitHub 固定源码；需要网络，不执行第三方项目代码。输出包括来源、许可证信息、当前与截止日近似 SHA、受限大小的归档与文件哈希。它不是主办方提交版本的证明。历史生成器依赖这些下载素材，输出只表示当时研究基线；第三方仓库变动或行号不再满足断言时需人工重新研究，不能强行跳过。

第三方完整源码、下载 ZIP 和旧 MedSeal 阶段副本不随模块发布。当前项目的真实状态以现行 [获奖项目研究](WINNER_RESEARCH.zh-CN.md)、[升级状态](WINNER_UPGRADE_STATUS.zh-CN.md)和版本证据为准。其他本地一次性分批推送、历史申报生成器不属于当前辅助工具。
