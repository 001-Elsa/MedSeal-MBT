# Persistent identity provider (P2)

The native enterprise entry uses MoonBit for DICOM parsing, rule application,
UID ownership checks, transformation and output verification. A narrow trusted
Python adapter supplies SQLite transactions and mature cryptographic primitives;
it receives private records on stdin, returns bindings on stdout and never uses
patient identifiers as process arguments.

Supported deployment: a controlled single-user POSIX host, private local storage,
Python 3.12 (tested) with cryptography==50.0.2. Windows private-store operations fail
closed. This provider is not an institution KMS, multi-user authorization service
or defense against an administrator reading the process/key directory.

Initialize a NEW store with `python tools/private_store.py init --store PRIVATE`.
The directory is 0700 and files are 0600. Never commit, publish or move this store
into a delivery directory. An OS file lock serializes transactions/maintenance;
SQLite WAL + FULL synchronous and unique indexes guard stable allocations.
HMAC-SHA256 lookup keys and AES-256-GCM encrypted records use separate HKDF keys.
Random patient aliases, date offsets and UUID-based 2.25 UIDs persist by project
and explicitly configured source domain. Changing the date bound for an existing
project requires migration. Patient name/birth, original SOP bytes and historical
UID ownership/parent conflicts abort the whole reservation transaction.

`cmd/enterprise` accepts INPUT OUTPUT POLICY PYTHON ADAPTER PRIVATE_STORE
SOURCE_DOMAIN. Only strict policies are accepted. No conversion grants release
permission; output must pass the separate review/delivery gate.

Maintenance commands (destination must not exist):

- `python tools/store_admin.py backup --store PRIVATE --destination BACKUP`
- `python tools/store_admin.py restore --store BACKUP --destination RESTORED`
- `python tools/store_admin.py rotate --store PRIVATE`
- `python tools/store_admin.py migrate --store PRIVATE --destination PRE_MIGRATION_BACKUP`

The SQLite backup API produces a consistent snapshot while the store lock is held.
Backup includes PRIVATE KEY MATERIAL; keep it in an independently controlled,
encrypted backup location. Hashes detect accidental corruption and do not provide
trust against an attacker replacing the entire backup. Restore checks hashes,
AEAD key authentication and SQLite integrity. Test restoration before relying on
retention. The local provider does not provide secure physical deletion.

Wrapping rotation creates a new immutable key/envelope generation, syncs both
files and atomically switches CURRENT. The data root, HMAC indices, encrypted
records and public identities remain unchanged. Interrupted pre-switch writes
leave the old generation usable; interrupted post-switch writes leave the new
one usable. Prior generations remain for recovery; rotation alone does not revoke
old backups or a previously compromised root. Mapping namespace rotation is a
separate migration. Physical power-loss durability is not certified.

Current limits: cache reuse is accepted only after authenticated object/output
revalidation; a cache hit is still `Converted` and never review or release
authority. Historical references require the W2 acknowledged-object witness and
directory receipt, and remote PACS exactly-once is outside this local contract.
Evidence: `evidence/p2-persistent-identity.json`, `evidence/w2-incremental.json`,
and `tools/verify_incremental.py` (synthetic multi-batch/cache/migration/history/
outbox checks). Original identities are not in the database/WAL in plaintext.
