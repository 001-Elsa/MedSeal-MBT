# 本地工作台（W5）

`tools/workbench.py` 是一个只绑定本机回环地址的薄宿主。它读取已有企业作业账本和状态机，提供作业列表、分页对象清单、结构化解释摘要和取消请求；转换、研究检查、人工风险复核、签名发布和接收仍由已有 CLI 与独立工具执行。工作台本身没有发布权限，也不把“像素未检查”改写为通过。

## 启动

```sh
python3.12 tools/workbench.py serve \
  --root PRIVATE_WORKSPACE \
  --capability-file PRIVATE_WORKSPACE/.workbench-session \
  --port 0
```

服务只监听 `127.0.0.1`。启动输出只包含端口和 capability 文件位置，不输出 capability 内容；文件应保持 `0600`。浏览器请求必须带 `X-MedSeal-Session`，写操作还必须带相同值的 `X-MedSeal-CSRF`。服务严格检查 `Host` 与可选 `Origin`，拒绝跨站请求、未知主机、缺失会话和路径穿越。会话值不放 URL，也不写访问日志。

打开启动输出中的本机地址后，工作台会显示分页作业列表。对象列表的默认页大小为 50、最大 100；服务端不会把整个目录或像素载入内存。每个公开响应只包含作业 ID、状态、数量、规则/策略摘要和下一步提示，不包含本机路径、原始值、映射密钥、日期偏移或患者身份。

## 接口范围

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/api/v1/session` | 返回当前工作台能力范围 |
| GET | `/api/v1/jobs?offset=&limit=` | 作业分页 |
| GET | `/api/v1/jobs/{id}` | 作业状态与允许操作 |
| GET | `/api/v1/jobs/{id}/objects?offset=&limit=` | 对象分页；`pixels_inspected` 固定为 `false` 直到独立复核 |
| GET | `/api/v1/jobs/{id}/report` | 受限结构化摘要 |
| POST | `/api/v1/jobs/{id}/cancel` | 写入已有取消请求并复用状态机门禁 |

## 证据与边界

`tools/verify_workbench.py` 覆盖 Host/Origin 校验、会话和 CSRF、分页上限、公开字段允许列表、对象状态摘要、取消闭环和路径穿越。HTML 使用内联 CSP，禁止脚本访问外部资源；UI 只调用上述 API，不实现第二套转换逻辑。

这是受控本地工作台的 M1 合成验收，不是多用户网络服务、TLS 终端、真实 PACS 连接或生产现场认证。真实操作者、授权数据来源、独立像素审查和接收系统仍属于 W7 现场材料。

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
