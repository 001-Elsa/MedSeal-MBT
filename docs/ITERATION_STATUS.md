> 历史阶段记录：以下结论保留当时提交的范围与证据；当前能力以 [README](../README.zh-CN.md)、[W0–W7 账本](WINNER_UPGRADE_STATUS.zh-CN.md)和[整改记录](COMPETITION_REMEDIATION.zh-CN.md)为准。

# Iteration status

Baseline: bb7e895 / 0.1.1. Current local candidate: 0.2.0.

The original plan is not fully completed. The checkboxes below describe the
implemented research-v1 subset, not every requirement in phases A–D.
See [the item-by-item audit](PLAN_AUDIT.md) for partial and missing work.

- [x] A: Baseline reproduced, headers/text/report privacy repaired, bounded
  exclusive I/O and writer model checks implemented.
- [ ] A (full plan): Complete alias/race tests, selected SOP Type constraints
  and VR semantics matrix; single-file two-destination publication remains limited.
- [x] B: Limited versioned research policy, patient grouping, shared UID context
  and per-patient date offsets implemented.
- [ ] B (full plan): General Sequence path rules, priority/conditions and a
  machine-readable provenance/test mapping are not implemented.
- [x] C: Two-pass collection plan/execute, supported references, DA shifting,
  File Meta synchronization and manifest verification implemented.
- [ ] C (full plan): Recovery is not implemented; retry requires a new plan.
- [x] D: Core mutation/path/publication regression tests and independent
  pydicom interoperability checks implemented and locally exercised.
- [ ] D (full plan): Execution-time fault injection, hard-termination and
  concurrent-target tests; variable-pixel workloads and peak-memory measurements.
- [x] E (local): Runnable MoonBit example, Chinese guide, support/policy/related
  work documents, measurements and submission text prepared.
- [x] E (GitHub): Candidate source pushed in functional commits on master.
- [x] E (remote CI): All four source/test commits passed GitHub CI. The latest
  source commit `9cbd292` passed Linux/macOS/Windows checks, tests, builds,
  interface consistency, the collection example, pydicom verification and packaging.
  Exact run/job evidence is in [github-verification.json](evidence/github-verification.json).
- [ ] E (GitLink): New candidate has not been synchronized to the mirror.
- [ ] E (Mooncakes): 0.2.0 has not been published; public-package consumer
  verification remains pending.

The toolchain is isolated in ../moonbit工具链. tools/moon-local runs it without
changing shell configuration. Test/measurement evidence is in docs/evidence.
The GitHub record identifies its verified source commit; the documentation
commit follows that snapshot and does not retroactively change earlier results.

Scope was narrowed to a coherent research-v1 subset: three descriptive tag
customizations, CT/MR/Secondary Capture metadata, full DA fields and per-job
mapping. General path-expression policies, DT/TM semantics, automatic recovery,
cross-job encrypted state and peak-memory/large-pixel benchmarks remain follow-up
work. No extra code is added solely to meet a reference line-count range.
