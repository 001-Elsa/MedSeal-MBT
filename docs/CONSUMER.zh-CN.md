# W6 仓库外消费者与候选发行

`examples/consumer` 只导入 `001-Elsa/medseal/api/policy` 公共门面，不依赖
`src/` 实现路径。`tools/verify_consumer.py` 会先生成当前 MoonBit 包，再把
归档解压到临时目录的模块根，复制消费者包并单独复制第三方依赖缓存，在与源码
仓库无关的目录中执行 `moon check`、Native 构建和运行。运行结果只输出策略
名称和摘要，不读写患者或影像值。

这条验收链证明消费者能从归档编译和调用公共策略门面，不证明候选包已经发布到 Mooncakes
registry，也不扩大 DICOM IOD、隐私或临床用途承诺。版本仍以 `moon.mod` 为单一
来源，0.2.0 是工程预览候选；只有 W7 有限场景材料完成后才考虑 1.0。

```sh
python3 tools/verify_consumer.py tmp/w6-consumer.json
```

候选发行继续使用现有 `tools/build_distribution.py` 和离线安装门禁。归档、
Mooncakes、GitLink 与 GitHub 的真实平台回读仍需在发布时分别记录，不能把本地
归档构建当成远端发布成功。

W6 的可审计候选清单由 [`tools/release_readiness.py`](../tools/release_readiness.py)
生成，步骤和平台观察文件格式见[候选发行与平台回读](RELEASE_READINESS.zh-CN.md)。
