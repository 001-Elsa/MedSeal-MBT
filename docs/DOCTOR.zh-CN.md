# 环境诊断

本工具诊断的是维护/既有私有宿主的完整 Python 环境；0.5.0 Native 数据二进制的 summary/quality/export/convert 运行本身无需 Python。缺少 QA/宿主依赖不应被解释为该二进制必需这些依赖。

`tools/doctor.py` 在执行前检查 固定 MoonBit/Python 3.12、两份 requirements 的全部固定依赖版本和模块版本，输出可分享的匿名 JSON。它不会读取患者文件、密钥或环境变量值。

```sh
python3.12 tools/doctor.py
python3.12 tools/doctor.py --json > tmp/doctor.json
```

诊断通过只表示本地工具链满足运行前提，不表示数据合规、审核完成或交付授权。缺失依赖会给出可操作的安装/升级建议并以非零状态退出。
