#!/usr/bin/env python3
"""Measure the public metadata scanner and Native SDK on identical synthetic inputs."""
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
from verify_data_processing import REPO, make, independent_outputs
from evidence import code_identity


def measure(binary,args):
    if os.name!='posix':raise RuntimeError('POSIX wait4 measurement required')
    with tempfile.TemporaryFile() as stdout,tempfile.TemporaryFile() as stderr:
        start=time.perf_counter()
        process=subprocess.Popen([str(binary),*map(str,args)],stdout=stdout,stderr=stderr)
        _,status,usage=os.wait4(process.pid,0)
        code=os.waitstatus_to_exitcode(status);process.returncode=code
        elapsed=time.perf_counter()-start
        stdout.seek(0);stderr.seek(0)
        output=stdout.read().decode();errors=stderr.read().decode()
        if code:raise AssertionError((code,output,errors))
    return {'seconds':round(elapsed,6),'peak_rss_bytes':usage.ru_maxrss*(1 if sys.platform=='darwin' else 1024)},output


def run(record,sizes,counts,repeats):
    if not 1<=repeats<=5 or any(n<1 or n>64 for n in sizes) or any(n<1 or n>10000 for n in counts):raise ValueError('bounded workload required')
    subprocess.run([str(REPO/'tools/moon-local'),'build','--target','native'],cwd=REPO,check=True)
    binary=REPO/'_build/native/debug/build/cmd/data/data.exe'
    workloads=[]
    with tempfile.TemporaryDirectory(dir=REPO/'tmp',prefix='data-benchmark-') as temp:
        root=Path(temp)
        definitions=[(f'payload-{n}',1,n) for n in sizes]+[(f'objects-{n}',n,None) for n in counts]
        for name,count,mib in definitions:
            source=root/name;make(source,count=count,bits=16,payload_mib=mib)
            for operation in ['summary','convert']:
                samples=[]
                for repeat in range(repeats):
                    output=root/f'{name}-{operation}-{repeat}'
                    args=[operation,source]+(['--output',output] if operation=='convert' else [])
                    sample,text=measure(binary,args)
                    if operation=='convert':independent_outputs(source,output)
                    else:assert json.loads(text)['objects']==count
                    samples.append(sample)
                row={'workload':name,'operation':operation,'objects':count,'pixel_mib':mib,'runs':samples,'median_seconds':statistics.median(s['seconds'] for s in samples),'max_rss_bytes':max(s['peak_rss_bytes'] for s in samples)}
                workloads.append(row);print(json.dumps(row),flush=True)
    cpu=subprocess.run(['sysctl','-n','machdep.cpu.brand_string'],capture_output=True,text=True).stdout.strip() if sys.platform=='darwin' else platform.processor()
    result={'schema':1,'status':'passed','platform':platform.platform(),'processor':cpu,'machine':platform.machine(),'measurement':'POSIX wait4 peak Native child RSS; generation and independent pydicom readback excluded; filesystem cache not flushed','binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'workloads':workloads,'threshold_policy':'measured baseline; no unmeasured performance promise','limitations':['synthetic uncompressed SC objects','scanner omits pixel values; conversion verifies full byte fidelity','each operation measured separately, not a speed-equivalence claim'],**code_identity(REPO)}
    record.parent.mkdir(parents=True,exist_ok=True);record.write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--record',type=Path,default=REPO/'tmp/data-benchmark.json');p.add_argument('--sizes',nargs='*',type=int,default=[1,16,64]);p.add_argument('--counts',nargs='*',type=int,default=[100,1000]);p.add_argument('--repeats',type=int,default=3);a=p.parse_args();run(a.record,a.sizes,a.counts,a.repeats)
