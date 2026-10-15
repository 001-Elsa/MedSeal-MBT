# Iteration status — current comparison

The original 0.1.1 baseline is bb7e895 (19 commits). Current 0.5.0 local-candidate contracts include P/W, C/V and data-processing work; [original plan](ITERATION_PLAN.md) retains
its design baseline. Earlier 91/53-per-backend and 9cbd292 CI results remain
fixed evidence, not the current test count.

| Original stage | Current implementation | Remaining boundary |
| --- | --- | --- |
| A correctness | Rebuilt headers, text-byte preservation, limits, alias/race/fault checks, strict VR/VM subset | Single-file report/DICOM are separate destinations; not every VR or filesystem certified |
| B policy/context | research-v1 plus strict paths/conditions/priorities; 141 rule references; persistent private provider | Rules limited to classified fields; no automatic patient reconciliation |
| C collection | UID/date/reference checks, private sealing/journal/resume, streaming, incremental cache/history | Compatibility batch stays per-job; no network/power-loss guarantees |
| D validation | Fixed corpus, pydicom, selected dciodvfy, CT research, fault/state/fuzz and RSS records | Synthetic evidence does not certify vendor/clinical inputs |
| E delivery | GitHub/GitLink history, CI, published Mooncakes 0.2.0, independent consumer/install | Participant completes official application and personal declarations |

Current local checks passed Native152 and JS/wasm/wasm-gc99 each,
475 corpus cases and new/old isolated archive consumers. Query/quality/plans,
Native streaming SDK and fixed-dictionary Implicit VR LE are implemented; see
[the 0.5.0 ledger](DATA_UPGRADE_STATUS.zh-CN.md). Remote publication is separate.

Historical audit source 2c9a49e passed 117 Native and 64 each JS/wasm/wasm-gc, 309 backend
executions. [Three-platform CI](https://github.com/001-Elsa/MedSeal-MBT/actions/runs/38349000368)
passed; Windows does not run the POSIX private host. New CI results bind their
own commit. [Plan audit](PLAN_AUDIT.md), [release record](COMPETITION_REMEDIATION.zh-CN.md)
and [documentation index](DOCUMENTATION_STATUS.zh-CN.md) provide current boundaries.

Original gaps in persistence, DT precision, recovery, path rules, large-pixel RSS,
signatures, registry consumption and mirrored publication have software/evidence
implementations now. Compressed pixels, networking/OCR, complete IOD/Annex E,
real field users and physical power-loss certification remain outside the claim.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
