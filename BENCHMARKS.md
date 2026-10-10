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

No peak-memory or large-pixel benchmark is claimed yet. The architecture retains
bounded metadata while processing full file bytes one at a time; that design
does not by itself prove a measured memory ceiling. Reproduce with:

```sh
python tools/verify_with_pydicom.py --count 100 --record docs/evidence/pydicom-100.json
python tools/verify_with_pydicom.py --count 1000 --record docs/evidence/pydicom-1000.json
```
