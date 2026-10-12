# Bounded native-pixel path (P4)

The strict enterprise entry uses streaming-v1. Core parsing, rules, UID mapping,
writer construction and structural checks remain in MoonBit. The parser reads at
most a 2MiB prefix; terminal finite OB/OW Pixel Data is represented by an offset,
length and VR. Metadata is transformed once through the existing identity engine.
The writer builds only the new metadata/pixel header and copies the sealed source
span with 1MiB chunks. File hashes are incremental. Output metadata is independently
reparsed and source/output pixel-span hashes compared. Checkpoint reuse recomputes
the expected complete output digest; tampered/partial files are rebuilt.

Accepted scope: Part10, Explicit VR Little Endian, declared strict CT/MR/SC subset,
monochrome8/16bit,single frame,finite native Pixel Data at the end. Metadata after
Pixel Data, encapsulated/undefined pixels, Implicit VR, enhanced SOPs, color,
multiframe and unreviewed character sets are rejected. No new transfer syntax was
advertised merely because a scanner can skip bytes. Requiring terminal pixels is
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

`tools/benchmark_streaming.py` measures the native child, performs independent
pydicom pixel readback and records binary/platform digests. See
`evidence/p4-streaming-resources.json` against the P0 baseline. Count workloads use
small synthetic pixels; they do not certify32GiB workloads, recipient usability,
concurrent disk reservations, filesystem quotas or real-vendor compatibility.
Physical power-loss and network-filesystem guarantees remain out of scope.
