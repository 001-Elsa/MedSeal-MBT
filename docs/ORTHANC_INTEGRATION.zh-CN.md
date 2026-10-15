# 独立 Orthanc 接收验收（V3）

`tools/verify_orthanc_integration.py` 使用官方 macOS universal 固定包，在临时目录创建配置和存储；仅本机回环访问，关闭DICOM网络服务。不是生产PACS配置。

生成三层CT合成序列 → MedSeal严格转换 → 启动Orthanc → 上传、查询、重复上传 → 取回DICOM → 独立pydicom核对像素/HU/几何/身份 → 断连、重启、重试。错误及返回不拼接私有内容，不授予发布。

```sh
python3.12 tools/verify_orthanc_integration.py --orthanc ../moonbit工具链/orthanc/26.9.1/Orthanc-MacOS-26.9.1-stable/Orthanc --version 1.13.0 --record tmp/v3-orthanc-ci.json
```

运行时必须真实存在，缺失直接失败。官方包与数据库留在源码外；报告绑定版本与程序摘要。实际完成情况见[计划账本](APPLICATION_VALUE_PLAN.zh-CN.md)。此阶段仅本地合成REST集成，不代表完整DICOMweb、DICOM网络协会、医院PACS或真实患者数据验收。

已实际通过10项检查，运行程序SHA-256为 `1b796df8be573450c738dec29edd4177079421c291b1835b8c73b16a47372739`，官方26.9.1发行ZIP为 `5bcc14501e8846296966e03fdec10608d6f8558d3a3d841e68db05f7b01e4617`，两者固定并不混淆包版本与Orthanc版本。

实际使用适配器：`python3.12 tools/orthanc_receiver.py PACKAGE --trust TRUST --base http://127.0.0.1:PORT --version 1.13.0`。只接收重新独立验证的签名包，256对象/64MiB单对象/128MiB合计，拒绝非回环地址、代理与重定向；先验证完整包，再逐对象验证签名摘要、上传并确认可取回。合成验收额外显式 `--allow-synthetic`；不允许它替代真实审核。

Orthanc上传不是整批事务：中断返回 `partial-retry-required`、已完成数量和固定错误码，下一次重跑先完整验签再上传，接收端去重。`receiver-stored` 只说明接收存储成功，语义验收由独立读取器完成，不伪造原签名包的发布权限或医院回执。远端可复现入口为手动触发的 `.github/workflows/orthanc.yml`，缺少固定下载或摘要不符直接失败。
