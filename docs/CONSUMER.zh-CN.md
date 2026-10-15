# 仓库外消费者与公开包

C1 的 `examples/consumer` 仅导入 `api/dicom`、C3a `api/dicom_json`、`api/policy`、`api/validation` 和 MoonBit 标准库。合成夹具也使用公开读写类型构建，不使用 MedSeal `src/`。

## 当前源码的完整任务

```moonbit nocheck
let result = @validation.convert_collection(
  inputs, @policy.strict(), uid_seed, date_offsets,
)
let first_private_dicom = result.private_bytes(0)
let shareable_report = result.public_report()
```

宿主负责读取 `inputs : Array[Bytes]` 并提供 seed/偏移；固定示例值只用于合成测试。结果按输入顺序排列，整批重新核验成功才返回。数量与内存预算见[API 契约](PUBLIC_API.zh-CN.md)。

```sh
moon run --target native examples/consumer
moon run --target js examples/consumer
python3.12 tools/verify_consumer.py tmp/c1-consumer.json
```

示例实际生成两份有关联的 SC 影像，经二进制解析、DICOM JSON 编码与 Part 10 重建后执行严格转换、重新验证、像素检查，末行输出 `public-collection-ok`。中间的 `synthetic-output-N:` 是**仅用于独立验证的合成 DICOM 十六进制字节**，不是通用公开日志入口；实际患者数据不得使用这种输出方式。公开报告不含身份、原日期、UID、seed 或偏移。

## 两类证据不能混用

- `verify_consumer.py` 构建当前工作区模块归档，在临时目录解包并覆盖一个外部消费者包，仅另行复制第三方依赖。原 checkout 不在搜索路径。四个后端逐一 check/test/run，独立 pydicom 读取实际字节，检查日期、像素、标识移除、File Meta、Study/Series 和跨对象 SOP 引用，并比较四后端字节摘要。它证明归档隔离消费，不证明 registry 已发布或真实第三方采用。
- `verify_registry_consumer.py` 创建独立模块，实际 `moon add` 并拒绝本地回退。默认检验当前完整集合示例，新接口发布前不能对旧包宣称通过。
- `--contract policy` 显式选择历史的仅策略契约，用于重验已发布 0.2.3 等旧版本。不会在集合编译失败后静默降级。

```sh
# 0.3.0 完整集合消费者；真实 registry 安装，不能回退本地源码
python3.12 tools/verify_registry_consumer.py --version 0.3.0 --record tmp/registry-collection.json
# 仅在重验旧版时显式选择 --version 0.2.3 --contract policy
```

[0.2.1 归档](evidence/release-0.2.1-archive-consumer.json)、[0.2.1 registry](evidence/release-0.2.1-registry-consumer.json)、[0.2.0 归档](evidence/release-0.2.0-archive-consumer.json)、[0.2.0 registry](evidence/release-0.2.0-registry-consumer.json)仍是对应旧版本的策略契约记录，不能用于证明 C1。当前证据默认写入忽略的 `tmp/`；发布回读写入源码外的版本目录。见[三平台同步](PLATFORM_SYNC.zh-CN.md)和[社区升级方案](COMMUNITY_ROADMAP.zh-CN.md)。

C3a 格式桥的支持矩阵、ESM 宿主与独立双向验收见[DICOM JSON](DICOM_JSON.zh-CN.md)；`tools/verify_dicom_json.py` 额外测试 pydicom 生成的输入，不能只靠库自产自读证明兼容。
