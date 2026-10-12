# Signed local delivery and offline install (P6)

The public package contains only converted DICOM/audits, conversion manifest,
release.json and signature.json. Ed25519 (cryptography50.0.2) signs the exact
canonical UTF-8 release bytes. Sorted keys, compact JSON separators, integer
schema/counts and no duplicate keys/NaN form release schema2; this is a fixed application
contract, not a claim to implement arbitrary RFC8785 JSON. The release binds the producer runtime fingerprint (converter/verifier/Python and
all eight runtime adapters, excluding paths/private inputs) and every file digest, policy/dictionary/tool identity, review digest and anonymous inventory.
Patient mappings, keys, source hashes, detailed private evidence and reviewer
identity are excluded. The old conversion manifest remains release_authorized:false;
the signed release decision applies only within its explicit context.

Initialize a separate private signer with `enterprise_job.py signer-init --workspace
PRIVATE --signer NEW_SIGNER --trust NEW_PUBLIC_TRUST`. Never share its private key or
reuse identity-store key material. Distribute trusted public keys out of band;
accepting a key shipped inside the untrusted package would defeat signature trust.
For rotation, distribute the new key before switching signer directories, retain
old trusted keys only for authorized prior packages, and explicitly revoke a
compromised key. Local key files are a controlled POSIX provider, not an HSM/KMS.

`publish --workspace PRIVATE --job ID --output NEW_TARGET --reviewers REGISTRY
--signer SIGNER --trust TRUST` requires READY and re-evaluates the complete gate
before and after copying. The target parent must be controlled0700, on the same
filesystem, outside job storage. Files are bounded-copied/fsynced, independently
verified, then published with no-replace rename and parent sync. Publication intent
is immutable. The PUBLISHING transition serializes with cancellation in SQLite:
accepted cancellation prevents publication from starting; after publication starts,
cancellation is rejected and completion/recovery is required (no recall claim). Resume of publish re-verifies an already renamed result and reconciles
the PUBLISHED journal. Unknown existing targets or changed intents fail.

A recipient uses `python tools/verify_delivery.py PACKAGE --trust TRUST`, requiring
only cryptography, not MoonBit, the producer's identity database or source files.
It validates trusted signature, canonical release schema2, exact file inventory and all
hashes. Synthetic context is rejected by default; --allow-synthetic is solely for
explicit exercises. Trusted bytes and attestations do not prove clinical usefulness
or that human review assertions were truthful. Those remain responsible field gates.

`enterprise_job.py deliver --workspace PRIVATE --package SIGNED --inbox CONTROLLED
--trust TRUST --receiver-id ID` is the first controlled local directory adapter.
Interrupted copies stay in .incoming staging; retry re-verifies each existing file.
Only complete trusted packages enter the named delivery directory. Receipt records
verified object count/package/key/receiver IDs after final verification; a missing
receipt is reconstructed idempotently. Receipt scope is local bytes/signature
acceptance, not network STOW, PACS acceptance or clinical validation. Consumers
ignore dot staging directories. Abandoned publisher stages require review under
retention policy; no arbitrary directory cleanup is offered.

`tools/build_distribution.py` produces a host-specific engineering preview archive,
checksums, fixed Python wheels, hash-required requirements, licenses and CycloneDX
SBOM. `tools/install_enterprise.py` checks a separately obtained expected distribution
manifest SHA256, platform, exact files/hashes before installing into a NEW directory
and creating an isolated Python3.12 environment. Pip uses --no-index and
--require-hashes; no author machine site packages are imported. The preview currently
tested locally is macOS ARM64; CI also verifies isolated installs on its Ubuntu and
macOS runners. These runs do not certify arbitrary host filesystems or power loss.
Python3.12 must already be installed; the interpreter is not
redistributed. Validate the archive checksum from a trusted channel before extraction
and executing its installer. A checksum shipped only alongside an untrusted archive
is not independent trust. An archive/build is not a published1.0 release.

Evidence: `evidence/p6-attestation.json` and offline installation record. Remaining
full gates: real receiver acceptance, independent crypto/role review, code-release
signing/trust distribution, maintained platform release assets, Windows enterprise provider,
physical power-loss and remote-protocol failure certification.

`tools/verify_distribution.py` now validates a freshly built distribution: wrong
trusted digest, changed payload and unexpected files fail before installation;
a new isolated offline install then runs the full/two-increment synthetic pilot.
CI runs this path on Linux/macOS. Actual execution records, rather than the
workflow configuration alone, determine certified platforms. The installer uses
the supported `--version` native probe; its earlier `version` probe was incorrect.

Public conversion manifests have an8MiB read/write budget, sized for10,000 objects
including per-object risk IDs. Signed release inventories retain a4MiB budget;
audits retain16MiB. Producers and independent consumers enforce the same bounds.

Private job plan schema2 pins all runtime adapters as well as binaries. Older
preview schema1 plans/releases require their original preview runtime; this reader
fails closed rather than silently migrating them. Identity-store schema is unchanged.
