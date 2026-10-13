# Risk review gate (P5)

Every object retains a mandatory pixel-content review and recipient acceptance of
the declared metadata subset. MoonBit classifies SC, unresolved burned-in/visual
feature flags and source overlay presence into anonymous risk IDs in the audit and
manifest. A NO flag never clears the mandatory pixel gate. Multiframe remains an
unsupported strict input; it is rejected, not sampled and approved.

`python3.12 tools/enterprise_job.py risks --workspace PRIVATE --job ID` lists anonymous
objects, output/policy digests and required decisions. An operator must inspect the
actual images and retain appropriate private evidence, including complete frame
coverage for any future multiframe profile. This implementation does not change
pixels. Image quality/recipient usefulness and visual privacy require responsible
human review. No OCR-negative action is accepted as a clearance.

An administrator provides a private0600 reviewer registry:
`{"schema":1,"reviewers":[{"id":"reviewer-01","contexts":["controlled"],"roles":["pixel-review","metadata-scope"]}]}`.
This is local single-owner authorization configuration, not organizational login
or multi-user authentication. Protect it independently from operators who must not
approve their own work if your institution requires separated roles.

The private review JSON has schema2, context(controlled/synthetic),reviewer,
reviewed_at(UTC ISO8601),recipient_accepts_declared_subset:true, records and bindings.
Bindings exactly match the current job_id, producer_runtime_sha256,
sealed_input_commitment, policy_file_sha256 and destination_domain. Obtain these
through the trusted private review integration calling review_binding in
tools/risk_gate.py; the risks CLI currently emits object risks only, not these
private bindings. Do not reuse another job's values. The saved
review envelope and reviewer registry remain schema1; they are not the input
review schema. See tools/risk_gate.py review_binding/validate_review.
Each record contains file,sha256,policy_sha256 and decisions covering every listed
risk exactly once. Each decision contains risk,action,evidence_sha256. Visual risks
require human-reviewed-clear; public-metadata-subset-only requires
recipient-accepted-subset. Evidence digests reference private review artifacts;
the gate verifies binding/coverage and authorization, not whether a human assertion
is truthful. Keep those artifacts and responsibility records under institutional
controls. Never put patient-bearing screenshots/text in public delivery.

Submit with `review --workspace PRIVATE --job ID --record RECORD --reviewers REGISTRY`.
This produces READY, still release_authorized:false. The separate signed publisher
must re-evaluate the gate. Missing risks, duplicate objects, unauthorized reviewers,
OCR-only conclusions, changed output/policy/tool/sealed source/registry refuse the
gate. Re-review is required after any change. Synthetic test records are explicitly
context:synthetic and cannot become a controlled release by the default recipient.

Evidence: `evidence/p5-risk-gate.json`, `tools/verify_risk_gate.py`, native classifier
test. Remaining enterprise gates include real reviewers, independent assessment of
privacy/quality evidence, source SOP certification and institutional role controls.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
