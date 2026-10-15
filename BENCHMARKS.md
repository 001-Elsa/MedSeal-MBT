# Synthetic collection measurements

Independent pydicom 3.0.1 checks on the local Apple Silicon Mac, MoonBit
0.1.20260920 / moonc 0.10.14+7d59c7ec9. The script is
`tools/verify_with_pydicom.py`; machine-readable records are in `docs/evidence`.

| Objects | Patients | References | Input bytes | Cached CLI batch duration |
| ---: | ---: | ---: | ---: | ---: |
| 16 | 2 | 14 | 17,838 | 0.168 s |
| 100 | 2 | 98 | 112,942 | 0.216 s |
| 1,000 | 2 | 998 | 1,133,546 | 1.433 s |

These are small synthetic files, not clinical image workloads. Timings include
the cached MoonBit CLI runner and cover planning, rewriting, output checks,
reports and publication. They are single observations, not a statistical
performance claim. Later source changes and fixture additions can change the
recorded sizes and times; use the JSON records from the latest run as evidence.

The table is the initial small-fixture baseline, not the current streaming
implementation. Current large-pixel/RSS observations are listed below; bounded
metadata design alone does not prove a universal memory ceiling. Reproduce
small-fixture checks without overwriting committed historical evidence:

```sh
python3.12 tools/verify_with_pydicom.py --count 100 --record tmp/pydicom-100.json
python3.12 tools/verify_with_pydicom.py --count 1000 --record tmp/pydicom-1000.json
```

## P0 large-payload baseline

`tools/benchmark_resources.py` now records native child-process RSS for synthetic
1/16/64/120 MiB single-object payloads, five repetitions each, in
`docs/evidence/p0-resources.json`. This measures the existing whole-file path;
fixture generation and the independent pydicom payload check run outside the
measured process. A 120 MiB payload reached about 491 MiB RSS in the recorded
run. This is a baseline for streaming work, not clinical throughput or an
IOD-conformance claim. The earlier no-RSS statement describes the 0.2.0 baseline.

## Current streaming observations

P4 measured about 29 MiB RSS for a 120 MiB native pixel payload, compared
with about 491 MiB on the P0 whole-file path. The later risk-aware 10,000
small-object run measured about 187 MiB / 94 s. These are historical observed
workloads, not a newly rerun benchmark or clinical throughput promise. See
[streaming contract](docs/STREAMING.md), docs/evidence/p4-streaming-resources.json
and docs/evidence/final-streaming-resources.json. Counts, hardware, binary
fingerprint and fixture size in each JSON take precedence over rounded prose.

> 文档核对：本文阶段计数、测量和发行摘要各自绑定原提交；当前状态已核对。见[文档账本](docs/DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。

V4当前实测与固定外部数学幻影来源见[应用负载与资源基线](docs/APPLICATION_BENCHMARKS.zh-CN.md)。保留本文件旧测量的原始版本，不把不同路径/机器数字混成提速结论。
