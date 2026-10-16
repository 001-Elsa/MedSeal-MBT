# Architecture

## 0.6.0 default path

The default public path is a caller-owned data transformation surrounded by evidence capture and independent verification:

```text
input snapshot + transformation plan
            |
            v
caller-owned transformation
            |
            +--> output artifact
            +--> per-record provenance
            +--> transformation receipt
                         |
                         v
              independent verifier
```

`api/evidence` contains only the portable evidence model. It does not read a database, infer entity identity, execute arbitrary code, or silently repair a receipt. Adapters and executors belong to the caller or to a separately reviewed package.

## Evidence invariants

- A receipt is bound to one input digest, one rule-plan digest and one output digest.
- Every output record has an explicit identifier and may carry one or more source references.
- A changed input, plan or output is a verification failure.
- A successful check is an integrity and provenance result; it is not a privacy, compliance or publication decision.
- The JSON shape is allowlisted and versioned as `medseal-evidence-receipt-v1`.

## Compatibility boundary

The repository still contains the former DICOM parser, validator, identity and conversion packages. They are retained for historical compatibility and regression evidence. They are not imported by `api/evidence`, are not required by the evidence example, and are not counted as new 0.6.0 evidence-core functionality.
