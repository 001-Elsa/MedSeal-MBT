# Durable private jobs (P3)

`python tools/enterprise_job.py` coordinates a controlled local POSIX job. The
operator supplies an existing 0700 `--workspace` and initialized private identity
store. `create --input SOURCE --policy POLICY --store PRIVATE --source-domain DOMAIN`
returns an opaque job ID. `run --job ID`, `resume --job ID`, `status --job ID`,
`cancel --job ID` and `cleanup --job ID` operate only on an ownership-checked job.
All commands also require `--workspace`.

Ingest enumerates every ordinary file and rejects links/special entries. It copies
Part 10 candidates (including extensionless objects) into 0400 private sealed
files, checking open-handle identity, size/time/change metadata and SHA-256. Source
changes during ingest fail. Later changes to the original do not affect sealed
inputs. Counts/exclusion reasons remain in the private plan. Limits: depth16,
20,000 entries,10,000 candidates,256MiB/object,32GiB input,one conversion worker,
1MiB sealing chunks; free-space checks reserve input/output plus a margin. These
are local policy checks, not filesystem quotas or concurrent-space guarantees.

The immutable plan pins policy bytes, sealed hashes, runtime/binary/adapter hashes,
resource settings, source domain and store location. The compiled binary binds
dictionary semantics. Replacing tools/policy/sealed bytes refuses resume. SQLite
FULL/WAL journal and OS job lock serialize operations. Mapping reservations commit
before outputs are written and persist across retries.

Each object file/audit is fsynced before its private checkpoint. Resume re-derives
expected output from sealed source and stable mapping, re-reads existing bytes and
compares them; a presence check or a checkpoint JSON digest alone is insufficient.
Owned incomplete files are rebuilt. Checkpoints live outside conversion output.
All objects and collection relationships are verified before no-replace rename;
POSIX directory and parent sync are requested. A renamed conversion whose journal
was not committed is re-verified and reconciled. Conversion ends at
AWAITING_REVIEW with release_authorized=false. P5/P6 supply final publication.

Cancellation is a durable request checked before/after conversion, not immediate
interruption of an in-flight object. Accepted cancellation blocks publication from starting. After an explicit signed
publication begins, cancellation is rejected; finish/recover that operation and
follow the receiving organization recall procedure if needed. Cleanup requires CANCELLED/FAILED and removes only this job's owned sealed
and working directories; conversion evidence remains. Deletion does not imply
physical erasure on SSD. Use encrypted volumes and retention policies.

Scope: controlled single-owner local filesystem. No network filesystem, Windows
ACL/durability certification, hostile administrator defense or physical power-loss
claim. Process-kill tests are recorded in `evidence/p3-recovery.json`. Remaining
full P3 gates include exhaustive crash-window/system certification and migration
of pinned runtimes. Checkpoint reuse currently recomputes output; P4 addresses
large-payload memory. Failed ingest needs a fresh job. Public delivery is a distinct
state transition and cannot be obtained from this tool's conversion result alone.
