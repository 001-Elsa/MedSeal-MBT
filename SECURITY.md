# Security Policy

## Supported version

The published baseline is 0.1.1; 0.2.0 is a locally verified candidate.

## Reporting a vulnerability

Use the repository's private security-advisory reporting feature. Do not open
a public issue containing a malicious DICOM sample, patient data, credentials,
or a detailed exploit before a fix is available.

Include the affected version, error code, minimal reproduction steps, and a
synthetic or fully de-identified sample. Never submit real patient data.

## Safety scope

MedSeal-MBT performs metadata de-identification. Pixel Data is not inspected
for burned-in identifying text. The compatibility basic mode retains identity
UIDs and only removes private elements when `--remove-private` is selected.
Research-v1 always removes private elements and maps its supported identity
UIDs across the collection. The tool does not guarantee complete anonymization
or regulatory compliance and is not medical diagnostic software.

The parser enforces explicit size, element-count, and nesting limits. Files
using unsupported transfer syntaxes are rejected rather than guessed.

Research-v1 only maps identities within one job and reports remaining metadata
and pixel risks. Reverse maps and date offsets are not persisted or exposed.
Unknown public UID roles fail, private elements are removed, and supported
identities/references are checked. Keep inputs stable during processing;
file-set, size/mtime and hash checks do not provide an atomic filesystem snapshot
against hostile concurrent mutation.

Jobs use new directories, private staging and exclusive file creation. Handled
errors remove staging; a hard-killed process may leave it for local review.
The checksum manifest is unsigned and cannot authenticate simultaneous edits to
data and manifest. Power-loss durability and network filesystems are not certified.
