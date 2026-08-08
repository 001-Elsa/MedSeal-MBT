# Security Policy

## Supported version

Security fixes are provided for the latest 0.1.x release.

## Reporting a vulnerability

Use the repository's private security-advisory reporting feature. Do not open
a public issue containing a malicious DICOM sample, patient data, credentials,
or a detailed exploit before a fix is available.

Include the affected version, error code, minimal reproduction steps, and a
synthetic or fully de-identified sample. Never submit real patient data.

## Safety scope

MedSeal-MBT performs basic metadata de-identification only. Pixel Data is not
inspected for burned-in identifying text. Private elements can contain
identifying information unless `--remove-private` is used. UID values are
retained in version 0.1.1. The tool does not guarantee complete anonymization
or regulatory compliance and is not medical diagnostic software.

The parser enforces explicit size, element-count, and nesting limits. Files
using unsupported transfer syntaxes are rejected rather than guessed.
