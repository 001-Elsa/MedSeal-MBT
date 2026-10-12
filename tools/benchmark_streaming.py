#!/usr/bin/env python3
"""Child-process RSS and payload fidelity on the bounded enterprise path."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import statistics
import sys
import tempfile
from benchmark_resources import measured_run
from verify_strict_profile import generate_strict
from verify_with_pydicom import REPO
from private_store import initialize
import pydicom


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--counts', type=int, nargs='*', default=[1000, 10000])
    parser.add_argument('--sizes', type=int, nargs='*', default=[1,16,64,120])
    args = parser.parse_args()
    if args.repeats < 1 or args.repeats > 10 or any(count < 1 or count > 10000 for count in args.counts) or any(size < 1 or size > 120 for size in args.sizes):
        parser.error('bounded benchmark parameters required')
    binary = REPO / '_build/native/debug/build/cmd/enterprise/enterprise.exe'
    rows = []
    (REPO / 'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO / 'tmp', prefix='streaming-') as temp:
        root = Path(temp)
        def run(source, output, store):
            return measured_run(binary, [source, output, REPO / 'examples/strict-policy.json', sys.executable, REPO / 'tools/private_store.py', store, 'synthetic-lab'], output)
        for mib in args.sizes:
            source = root / ('input-' + str(mib))
            generate_strict(source, 1)
            path = next(source.glob('*.dcm'))
            ds = pydicom.dcmread(path)
            size = mib * 1024 * 1024
            ds.Rows, ds.Columns = size // (8192 * 2), 8192
            ds.BitsAllocated = ds.BitsStored = 16
            ds.HighBit = 15
            ds.PixelData = b'\x00\x01\x02\x03' * (size // 4)
            ds['PixelData'].VR = 'OW'
            expected = hashlib.sha256(ds.PixelData).hexdigest()
            ds.save_as(path, enforce_file_format=True)
            del ds
            store = root / ('private-' + str(mib))
            initialize(store)
            samples = []
            for repeat in range(args.repeats):
                output = root / ('out-%s-%s' % (mib, repeat))
                sample = run(source, output, store)
                actual = pydicom.dcmread(output / 'object-1.dcm')
                assert hashlib.sha256(actual.PixelData).hexdigest() == expected
                del actual
                samples.append(sample)
                print(json.dumps({'payload_mib': mib, 'repeat': repeat, **sample}), flush=True)
            rows.append({'payload_mib': mib, 'objects': 1, 'runs': samples, 'max_rss_bytes': max(item['peak_rss_bytes'] for item in samples), 'median_seconds': statistics.median(item['seconds'] for item in samples)})
        for count in args.counts:
            source = root / ('many-' + str(count))
            generate_strict(source, count)
            store = root / ('many-store-' + str(count))
            initialize(store)
            output = root / ('many-output-' + str(count))
            sample = run(source, output, store)
            manifest = json.loads((output / 'manifest.json').read_text())
            assert len(manifest['objects']) == count and not manifest['release_authorized']
            rows.append({'objects': count, 'payload_mib': None, 'runs': [sample]})
            print(json.dumps({'objects': count, **sample}), flush=True)
    record = {'schema': 1, 'platform': platform.platform(), 'machine': platform.machine(), 'fixture': 'synthetic monochrome SC, terminal native Pixel Data',
              'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'execution_path': 'streaming-v1',
              'copy_chunk_bytes': 1024 * 1024, 'metadata_prefix_bytes': 2 * 1024 * 1024, 'workloads': rows,
              'note': 'Native child peak RSS (includes adapter child high-water report where OS does); Python generation and independent readback excluded. Count workloads use small pixels, not 32GiB real data; no recipient/power-loss certification.'}
    (REPO / 'docs/evidence/p4-streaming-resources.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
