# Bounded native-pixel path (P4)

> 0.5.0发行源码新增查询/质量/计划/Native SDK及固定字典Implicit VR LE；本页旧阶段记录保留其原版本，当前增量见[数据处理指南](DATA_PROCESSING.zh-CN.md)。

The strict private-host entry and public Native `api/native.plan_directory`
use streaming-v1. The public job uses OS entropy and per-job identities without
Python, persistent identity, private-host recovery, human review or signing. Core parsing, rules, UID mapping,
writer construction and structural checks remain in MoonBit. The parser reads at
most a 2MiB prefix; terminal finite OB/OW Pixel Data is represented by an offset,
length and VR. Metadata is transformed once through the existing identity engine.
The writer builds only the new metadata/pixel header and copies the sealed source
span with 1MiB chunks. File hashes are incremental. Output metadata is independently
reparsed and source/output pixel-span hashes compared. Checkpoint reuse recomputes
the expected complete output digest; tampered/partial files are rebuilt.

Accepted scope: Part10, Explicit VR LE or pinned-dictionary Implicit VR LE, declared strict CT/MR/SC subset,
monochrome8/16bit,single frame,finite native Pixel Data at the end. Metadata after
Pixel Data, encapsulated/undefined pixels, unknown/private implicit tags, enhanced SOPs, color,
multiframe and unreviewed character sets are rejected. Implicit support resolves VR through the fixed dictionary and normalizes writes
to Explicit VR LE; skipping bytes alone does not establish format support. Requiring terminal pixels is
an explicit narrower enterprise-path contract; the original buffered API remains
available for its documented scope. Full CT/MR IOD/source certification remains a
P1/P7 gate. Source span copying does not inspect visual privacy or decode pixels.

Limits remain256MiB/file,128MiB/pixel value,2MiB metadata prefix,64MiB collection
metadata estimate,10,000objects. This change does not remove those protections.
Sealing/copying use a single worker; file descriptors close per object. The identity
adapter's response budget is checked after collection; it is trusted administrator
code, not a general untrusted subprocess interface. Total memory contains metadata,
mappings, runtime and IPC in addition to the copy buffer; measured RSS is the
capacity evidence, not the buffer size alone.

Public scanning uses full bounded parsing for files up to 2 MiB and removes
pixels from its detached metadata; larger files require the terminal-pixel prefix
path. Scan quality is metadata-only (`pixels_checked:false`). Public execution is
single-use, checks source bytes and stages a complete new directory. Cooperative
cancellation occurs at planning/object/commit boundaries, not within a copy.
See [data APIs and limits](DATA_PROCESSING.zh-CN.md).

`tools/benchmark_streaming.py` measures the native child, performs independent
pydicom pixel readback and records binary/platform digests. See
`evidence/p4-streaming-resources.json` against the P0 baseline. Count workloads use
small synthetic pixels; they do not certify32GiB workloads, recipient usability,
concurrent disk reservations, filesystem quotas or real-vendor compatibility.
Physical power-loss and network-filesystem guarantees remain out of scope.

Public conversion manifests have an8MiB read/write budget, sized for10,000 objects
including per-object risk IDs. Signed release inventories retain a4MiB budget;
audits retain16MiB. Producers and independent consumers enforce the same bounds.

> 文档核对：本文说明已与当前维护代码和实际入口核对；不扩大医疗/生产保证。见[文档账本](DOCUMENTATION_STATUS.zh-CN.md)；正式申报由韩桢本人完成。
