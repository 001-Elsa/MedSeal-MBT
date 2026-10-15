# Portable public SDK consumer

This source-only example imports MedSeal `api/dicom`, `api/policy`,
`api/validation`, `api/dicom_json` and the core hex encoder. Even fixture construction uses public
APIs. It creates two synthetic linked SC objects, converts the entire closed
collection, validates the outputs and checks pixel preservation. The last line
is `public-collection-ok`.

```sh
moon run --target native examples/consumer
moon run --target js examples/consumer
moon test --target all examples/consumer
python3.12 tools/verify_consumer.py tmp/c1-consumer.json
```

Intermediate `synthetic-output-N:` lines contain synthetic private DICOM bytes
for the independent pydicom oracle. Never adapt this logging mode to patient
files. Public reports exclude identifiers, seeds and dates. Conversion does not
authorize clinical use or release. The memory workflow is limited to 256 objects,
64 MiB per object and 128 MiB total.

This collection/JSON SDK is retained from the previously published 0.4.1 baseline.
Current source is a 0.5.0 local candidate; query/quality/plans are demonstrated
separately in `examples/data_pipeline` and Native I/O in `examples/native_pipeline`.
The archive verifier runs four backends outside the checkout; registry
verification is a separate action after a new release. The explicit legacy
`--contract policy` check remains available for 0.2.3.
See [consumer contracts](../../docs/CONSUMER.zh-CN.md).

C3a：示例新增公开 `api/dicom_json`，先经 JSON/Part 10 重建再执行严格集合转换；格式交换保留私有原值。支持子集与独立 pydicom 双向检查见[JSON 契约](../../docs/DICOM_JSON.zh-CN.md)。
