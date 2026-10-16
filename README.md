# MedSeal-MBT

MedSeal-MBT is a MoonBit library for **verifiable data-transformation evidence**. It binds a transformation receipt to an input digest, a rule-plan digest and an output digest, records per-record provenance, and lets an independent verifier detect stale inputs, changed plans, changed outputs and incomplete provenance.

The current public direction is format- and domain-neutral. The evidence core does not clean, anonymize, generate, synchronize or publish data on behalf of the caller. A caller owns the transformation; this library records what was declared, where output records came from, and whether the resulting artifact can still be independently checked.

## 0.6.0 public API

Import `001-Elsa/medseal/api/evidence` in a MoonBit module:

```moonbit nocheck
///|
import {
  "001-Elsa/medseal/api/evidence" @evidence_api,
}
```

Create a plan, attach source references to output records, create a receipt, and verify it later:

```moonbit nocheck
///|
let plan = @evidence_api.Plan::new(
  plan_id="rename-v1",
  input_digest="sha256:input",
  rule_digest="sha256:rules",
  tool_version="0.6.0",
  steps=[{ id: "rename", description: "caller-owned field rename", }],
)

///|
let receipt = @evidence_api.Receipt::new(
  plan,
  output_digest="sha256:output",
  input_records=2,
  output_records=[
    {
      id: "out-1",
      sources: [{ source: "input.jsonl", record: "1", step: "rename", }],
      changed_fields: ["display_name"],
    },
  ],
)

///|
let result = receipt.verify(plan, "sha256:input", "sha256:output")
```

Run the executable example from the source checkout:

```sh
./tools/moon-local run --target native examples/evidence
```

The example prints a JSON receipt and an independent verification result. The public API is intentionally small: it does not infer identities, silently repair provenance, or treat a checksum as proof of privacy.

## Scope and boundaries

The core supports declaration, provenance, receipt serialization and independent binding checks. CSV, JSONL and other formats can be implemented by caller-owned adapters. The core does not claim that an output is anonymous, correct for a business domain, compliant, or safe to publish. A valid receipt proves only that the supplied digests, plan binding and recorded provenance are consistent.

The former DICOM parser, validator and conversion code remains in the repository as a historical and optional compatibility surface. It is not the default 0.6.0 project story and it is not counted as new evidence-core functionality. See [the Chinese project guide](README.zh-CN.md), [the public API contract](docs/PUBLIC_API.zh-CN.md), and [the migration note](docs/MIGRATION_0.6.zh-CN.md).

## Development

The repository includes a pinned local MoonBit tool entry point at `tools/moon-local`:

```sh
./tools/moon-local info
./tools/moon-local fmt
./tools/moon-local check --target native --deny-warn
./tools/moon-local test --target native --deny-warn
```

The current test suite includes receipt binding, stale-input rejection, changed-output rejection and plan-mismatch rejection. Historical DICOM, application and competition evidence remains attributed to its original release and is not silently rewritten as 0.6.0 evidence.

## Public API inventory

The public package paths are `api/authorization`, `api/dicom`, `api/dicom_json`, `api/evidence`, `api/explain`, `api/native`, `api/policy`, `api/quality`, `api/query`, and `api/validation`. The new default entry is `api/evidence`; the remaining entries retain their historical or platform-specific boundaries.
