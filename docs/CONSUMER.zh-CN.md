# 仓库外消费者与公开包

`examples/consumer` 只导入 `001-Elsa/medseal/api/policy`，不依赖 `src/`。
运行成功输出唯一公共结果 `public-policy-ok`，不输出患者、映射或日期值。

## 两种验收分别证明什么

- `tools/verify_consumer.py` 构建当前模块归档，解压到临时独立模块，复制消费者和第三方依赖，检查、构建和运行。它证明归档可消费，不证明 registry 发布。
- `tools/verify_registry_consumer.py` 在独立模块实际执行 `moon add`，检查下载版本、拒绝本地源码回退并运行同一公共示例。它证明公开版本可消费。

```sh
python3.12 tools/verify_consumer.py tmp/archive-consumer.json
python3.12 tools/verify_registry_consumer.py --version 0.2.3 --record tmp/registry-consumer.json
```

历史 0.2.1 已公开发布，见[归档验收](evidence/release-0.2.1-archive-consumer.json)、[registry验收](evidence/release-0.2.1-registry-consumer.json)和[三平台CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38363013106)。

0.2.0 原版真实记录分别为 [归档验收](evidence/release-0.2.0-archive-consumer.json)和[registry 验收](evidence/release-0.2.0-registry-consumer.json)。这些记录绑定冻结版本，不冒称后续文档修订已经包含在原归档。

模块名、版本以 `moon.mod` 为准；源码、归档、CI 和平台回读分别核对，格式见[发行记录方法](RELEASE_READINESS.zh-CN.md)。工程预览不等于临床适用、像素匿名化、生产 1.0 或正式报名。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

0.2.3 的真实 registry 消费者必须在新包发布后重新运行；输出证据保存到源码目录外的版本核验目录，参见[三平台同步](PLATFORM_SYNC.zh-CN.md)。
