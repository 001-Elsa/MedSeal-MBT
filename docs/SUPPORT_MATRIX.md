# Support matrix for 0.2.0

This is a tested metadata subset, not a full DICOM conformance statement.

| Area | Supported behavior | Explicit boundary |
| --- | --- | --- |
| File format | Part 10, Explicit VR Little Endian | No raw-dataset CLI, other transfer syntaxes or compression |
| Character sets | Default ASCII, ISO_IR 6, ISO_IR 192 | Other or multivalued character sets rejected; no transcoding |
| Values | Common text/integer VRs, raw binary values, Sequence | No interpretation of compressed pixels or every VR semantic |
| Sequences | Defined and supported undefined item/sequence lengths | Maximum depth 32 |
| Collection SOP classes | CT Image Storage, MR Image Storage, Secondary Capture | Class filtering does not implement full IOD Type/VM validation |
| Patient key | Namespace + Issuer of Patient ID + Patient ID | Missing ID rejected; conflicting names/birth dates rejected; no automatic reconciliation |
| Identity UIDs | SOP Instance, Study, Series, Frame of Reference, Referenced SOP Instance | Other public UI tags rejected in research mode; core identity fields are single-valued |
| Standard UIDs | SOP Class and Referenced SOP Class | Preserved; unsupported primary SOP classes rejected |
| References | Same-patient SOP references with matching SOP Class | Closed collection default; explicit external mode reports unresolved references |
| Dates | Full DA in Study/Series/Acquisition/Content Date | No DT precision/timezone handling or TM pairing; birth date emptied |
| Patient aliases | One alias per prepared job and patient key | Not stable between jobs; context preparation and job execution are single-use |
| Output | Reconstructed File Meta, zero preamble, raw pixel preservation | Public metadata subset remains; no burned-in text inspection |
| Policy overrides | Study Description, Series Description, Protocol Name | No arbitrary tag/path rules or structural overrides |
| Privacy report | Anonymous object IDs, paths within the dataset, rule/action | No original paths/values or reverse map; never declares all privacy removed |

## Resource budgets

- 256 MiB per source/output file, 128 MiB per encoded element/Sequence.
- 100,000 elements per file, 32 Sequence nesting levels.
- 10,000 objects per job, 100,000 distinct mapped UIDs.
- 2 MiB estimated indexed metadata per source; 64 MiB per collection.
- 16 directory levels; recursive scans reject symbolic links and special files.
- Discovery probes all regular files (132-byte header); extensionless Part 10
  files are included, non-Part-10 files are counted, and discovery is capped at
  20,000 entries. Hardlinked inputs are rejected.
- 1 MiB policy JSON, 4 MiB manifest, 16 MiB per audit report.

Files are opened and their sizes checked before bounded reads. Source SHA-256,
size/mtime and the selected file set are checked against the plan. Inputs should
remain stable during processing; these checks are not an atomic filesystem
snapshot and do not defend against a hostile administrator racing filesystem
operations.

## Publication and integrity

A job stages files with exclusive creation under a sibling directory with
private permissions, prepares audit and manifest files, and renames that directory
to an absent target. No automatic replacement or merging of existing jobs occurs.
Actual visibility/durability depends on filesystem rename and sync guarantees;
network filesystems and power-loss durability have not been certified.

Handled errors clean staging; hard termination can leave it for manual review.
Do not treat a leftover staging directory as a published job. No mapping state is
persisted, so retries require a new plan and new job.

SHA-256 detects modifications relative to a trusted manifest. The manifest is
not signed; changing both a file and its manifest is not authenticated tamper
protection. `verify` does not replace reviewing unclassified metadata or pixels.
