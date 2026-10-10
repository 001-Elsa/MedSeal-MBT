#!/usr/bin/env python3
"""Measure the native process on synthetic large payloads; no clinical claim."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import statistics
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO.parent / "moonbit工具链/python-packages"))
from verify_with_pydicom import generate
import pydicom


def measured_run(binary, args, root):
    if not hasattr(os, "wait4"):
        raise RuntimeError("Per-process RSS measurement requires a supported POSIX platform")
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        start = time.monotonic()
        process = subprocess.Popen([str(binary), *map(str, args)], cwd=REPO, stdout=stdout, stderr=stderr)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        elapsed = time.monotonic() - start
        stdout.seek(0)
        stderr.seek(0)
        if process.returncode:
            raise RuntimeError(f"Synthetic benchmark failed: {stdout.read().decode()} {stderr.read().decode()}")
        rss = usage.ru_maxrss if sys.platform == "darwin" else usage.ru_maxrss * 1024
        return {"seconds": round(elapsed, 6), "peak_rss_bytes": rss,
                "published_bytes": sum(p.stat().st_size for p in root.rglob("*") if p.is_file())}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sizes-mib", type=int, nargs="+", default=[1, 16, 64, 120])
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--binary", type=Path, default=REPO / "_build/native/debug/build/cmd/main/main.exe")
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.repeats <= 30 or any(not 1 <= n <= 120 for n in args.sizes_mib):
        parser.error("repeats 1..30 and sizes 1..120 MiB are required")
    (REPO / "tmp").mkdir(exist_ok=True)
    rows = []
    with tempfile.TemporaryDirectory(prefix="resources-", dir=REPO / "tmp") as temporary:
        root = Path(temporary)
        for mib in args.sizes_mib:
            source = root / f"input-{mib}"
            generate(source, 2)
            # One synthetic SC object, with dimensions matching an uncompressed 16-bit image.
            files = sorted(source.glob("*.dcm"))
            files[1].unlink()
            ds = pydicom.dcmread(files[0])
            length = mib * 1024 * 1024
            ds.Rows, ds.Columns = length // (8192 * 2), 8192
            ds.BitsAllocated = ds.BitsStored = 16
            ds.HighBit = 15
            ds.PixelData = bytes((0, 1, 2, 3)) * (length // 4)
            payload_hash = hashlib.sha256(ds.PixelData).hexdigest()
            ds.save_as(files[0], enforce_file_format=True)
            del ds
            measurements = []
            for repeat in range(args.repeats):
                output = root / f"output-{mib}-{repeat}"
                sample = measured_run(args.binary, ["batch", source, "--output", output], output)
                dst = pydicom.dcmread(output / "object-1.dcm")
                assert hashlib.sha256(dst.PixelData).hexdigest() == payload_hash
                del dst
                measurements.append(sample)
                print(json.dumps({"payload_mib": mib, "repeat": repeat, **sample}), flush=True)
            rows.append({"payload_mib": mib, "objects": 1, "runs": measurements,
                         "median_seconds": statistics.median(x["seconds"] for x in measurements),
                         "max_rss_bytes": max(x["peak_rss_bytes"] for x in measurements)})
    source_digest = hashlib.sha256()
    for path in sorted(REPO.glob("src/**/*")):
        if path.is_file() and path.suffix in (".mbt", ".c", ".pkg"):
            source_digest.update(str(path.relative_to(REPO)).encode())
            source_digest.update(path.read_bytes())
    record = {"platform": platform.platform(), "machine": platform.machine(),
              "filesystem_scope": "workspace local filesystem; not power-loss certification",
              "binary_sha256": hashlib.sha256(args.binary.read_bytes()).hexdigest(),
              "source_tree_sha256": source_digest.hexdigest(), "repeats": args.repeats,
              "note": "Synthetic single-object payloads; native process RSS, excluding fixture generation and independent pydicom check; no clinical throughput claim",
              "workloads": rows}
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
