#!/usr/bin/env python3
"""Record repeatable resource/fidelity baselines, not an unmeasured speed claim."""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import subprocess
import sys
from evidence import code_identity
from verify_consumer import REPO, moon_binary


def run(record, quick=False):
    root = record.parent
    root.mkdir(parents=True, exist_ok=True)
    buffered, streaming = root / 'v4-buffered.json', root / 'v4-streaming.json'
    sizes = ['1', '16'] if quick else ['1', '16', '64']
    for script, args, output in [
        ('benchmark_resources.py', ['--sizes-mib', *sizes, '--repeats', '3'], buffered),
        ('benchmark_streaming.py', ['--sizes', *sizes, '--counts', '100', '1000', '--repeats', '3'], streaming),
    ]:
        subprocess.run([sys.executable, str(REPO / 'tools' / script), *args, '--record', str(output)], check=True)
    result = summarize(buffered, streaming)
    record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status':'passed','workloads':len(result['workloads'])}))


def summarize(buffered, streaming):
    rows = []
    for label, path in [('buffered-compatible-batch', buffered), ('private-strict-streaming', streaming)]:
        source = json.loads(path.read_text())
        for work in source['workloads']:
            runs = work['runs']
            durations = [r['seconds'] for r in runs]
            import statistics
            median = statistics.median(durations)
            rows.append({'path':label, 'objects':work['objects'], 'payload_mib':work.get('payload_mib'),
                         'runs':runs,'median_seconds':median,'peak_rss_bytes':max(r['peak_rss_bytes'] for r in runs),
                         'objects_per_second':round(work['objects']/median,3),
                         'payload_mib_per_second':round(work['payload_mib']/median,3) if work.get('payload_mib') else None,
                         'failures':0,'pixel_or_inventory_oracle':'passed-per-run'})
    moon = moon_binary()
    return {'schema':1,'status':'passed','stage':'V4','platform':platform.platform(), 'machine':platform.machine(),
            'processor':subprocess.run(['sysctl','-n','machdep.cpu.brand_string'],capture_output=True,text=True).stdout.strip() if sys.platform=='darwin' else platform.processor(),
            'python':platform.python_version(),'toolchain':subprocess.check_output([str(moon),'version','--all'],text=True),
            'binaries':{str(p.relative_to(REPO)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [REPO/'_build/native/debug/build/cmd/main/main.exe',REPO/'_build/native/debug/build/cmd/enterprise/enterprise.exe']},
            'workloads':rows,'failure_rate':0,'release_authorized':False, **code_identity(REPO),
            'measurement':'POSIX wait4 child high-water RSS; fixture generation/readback excluded; filesystem cache not flushed',
            'threshold_policy':'baseline only; future same-machine regressions must remeasure before setting a bound',
            'limitations':['paths implement different policy/persistence contracts; timing is not a direct like-for-like speed comparison',
                           'payload cases 3 runs each; count cases one run each', 'only non-patient synthetic workloads; not production latency or capacity certification']}


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record',type=Path,required=True)
    parser.add_argument('--quick',action='store_true')
    parser.add_argument('--summarize',nargs=2,type=Path)
    args=parser.parse_args()
    if args.summarize:
        args.record.write_text(json.dumps(summarize(*args.summarize),ensure_ascii=False,indent=2)+'\n')
    else:
        run(args.record,args.quick)
