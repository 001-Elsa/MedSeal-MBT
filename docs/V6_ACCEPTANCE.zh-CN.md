# V6 发布验收

当前 0.5.0 发行源码的新增数据门禁需与既有 `verify_v6.py` 一起执行；本轮本地结果见[实施账本](DATA_UPGRADE_STATUS.zh-CN.md)。完整 V6 宿主/浏览器门禁与 0.5.0 远端 CI、registry 回读没有因数据门禁通过而自动完成。

V6 把源码、包、消费者和维护入口绑定到同一提交。完整验收由维护者在干净 checkout 执行。先安装固定 MoonBit、Python 3.12 与两份 requirements；运行 `moon update`，并用 `pnpm --dir web install --frozen-lockfile --ignore-scripts` 安装页面依赖、`pnpm --dir web exec playwright install chromium` 安装隔离测试浏览器（或以 `MEDSEAL_CHROME` 指定本机 Chrome）。Node.js 必须在 PATH 中：

```sh
python3.12 tools/verify_v6.py --record /path/out/v6.json
python3.12 tools/verify_data_processing.py --record /path/out/data-processing.json
python3.12 tools/verify_data_consumer.py --record /path/out/data-consumer.json
# 仅在 0.5.0 真正发布后执行，不能用旧版或本地源码代替
python3.12 tools/verify_registry_consumer.py --version 0.5.0 --record /path/out/registry.json
```

验收包括版本/文档一致性、`moon info`/格式/四后端检查和测试、公共消费者、预检、授权 phantom、浏览器实验室和精确模块快照。registry 消费者必须从 Mooncakes 独立安装；GitHub、GitLink 和 Mooncakes 的回读摘要另存源码树外，不把凭据或回执提交进仓库。

真实临床现场、PACS/DICOMweb 全协议和正式赛事申报仍需独立人工证据。
