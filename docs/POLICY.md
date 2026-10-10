# Policies and library APIs

Policy version 1 supports `mode: research`. See the runnable configuration in
`examples/research-policy.json`. Unknown fields, duplicate tag rules, missing
values, non-integer/zero/out-of-range date bounds and unsupported tag overrides
are rejected rather than guessed.

`namespace` partitions Patient ID values when issuer information is absent.
Use one source namespace per job; do not mix hospitals whose identifiers overlap.
Names and birth dates are used only to detect conflicts in a patient key, never
as the primary matching key. A conflict stops processing for review.

`date_shift_days` is a signed maximum magnitude of 1–3650 days. The native CLI
chooses an independent nonzero offset for each patient using OS entropy; every
selected full DA value for that patient uses the same offset. Birth date is
emptied. Offsets are omitted from public reports.

`allow_external_references` defaults to false. True permits missing referenced
instances, keeps their consistent remapping, and reports the unverified count.
References to a present object in another patient or the wrong SOP Class always
fail.

Custom rules may `keep`, `empty`, `remove` or `replace` only Study Description
`00081030`, Series Description `0008103E`, and Protocol Name `00181030`.
Replacement values must be printable ASCII with at most 64 characters.
`keep` explicitly retains a field that may contain identity; the report still
indicates incomplete metadata coverage. Direct identifiers, UIDs, dates and
pixel bytes cannot be overridden by custom rules.

## Public package imports

Consumers use `001-Elsa/medseal/src/parser`, `/src/policy`, `/src/identity`,
`/src/dicom_writer`, `/src/verification` and Native-only `/src/batch`.
The portable core does not depend on a filesystem or the small OS-entropy shim.

Typical Native flow:

```text
policy = policy.research() or policy.from_json(json)
job = batch.plan(input_directory, policy)
job.preview()
job.execute(new_output_directory)
batch.verify(output_directory)
```

Typical in-memory flow:

```text
verification.check(datasets)
context = identity.Context::new(uid_seed, policy, per_patient_offsets)
context.prepare(datasets)
result = context.apply(dataset)
bytes = dicom_writer.write_deidentified(parsed_file, result.dataset)
verification.check(converted_datasets)
```

The caller supplies a fresh positive decimal seed of up to 29 digits and enough
offsets for all patients. Patients are ordered deterministically by MoonBit's
String comparator, not by source file iteration. The CLI obtains a 96-bit seed
and independent offsets from the operating system. Never derive offsets from
public output UIDs or put original identifiers in the seed. UID values allocate
nonoverlapping counters inside the job and are checked against source values.

Contexts retain original identity keys in memory. Do not serialize, log or share
them as public artifacts. Preparation, including a failed attempt, is single-use;
`apply` can transform the original datasets repeatedly with the prepared context
but rejects existing processing markers to prevent another date shift.

Ordinary `write_bytes` preserves source File Meta/preamble for serialization.
Use `write_deidentified` for privacy processing. Both raise structured errors
for unsupported data model encodings and resource limits.
