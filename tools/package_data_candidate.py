#!/usr/bin/env python3
"""Create and read back a local working-tree module candidate, never a release receipt."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import zipfile
from verify_platform_snapshot import allowlist
from verify_with_pydicom import REPO
from evidence import code_identity


def run(output):
    names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=REPO,text=True).splitlines()
    names=sorted(set(names))
    for name in names:
        if (REPO/name).is_symlink():raise ValueError('symlink in local source candidate')
    (REPO/'.moonignore').write_text(allowlist(names))
    subprocess.run([str(REPO/'tools/moon-local'),'package'],cwd=REPO,check=True)
    module=REPO/'_build/publish/001-Elsa-medseal-0.5.0.zip'
    sources={name:hashlib.sha256((REPO/name).read_bytes()).hexdigest() for name in names}
    with zipfile.ZipFile(module) as archive:
        files=[entry for entry in archive.infolist() if not entry.is_dir()]
        assert len(files)==len(sources) and {e.filename for e in files}==set(sources)
        for entry in files:
            assert hashlib.sha256(archive.read(entry)).hexdigest()==sources[entry.filename],entry.filename
    output.mkdir(parents=True,exist_ok=True)
    shutil.copy2(module,output/module.name)
    record={'schema':1,'status':'passed','state':'local-working-tree candidate, uncommitted; not registry publication or contest receipt','module':module.name,'archive_sha256':hashlib.sha256(module.read_bytes()).hexdigest(),'files':sources,**code_identity(REPO)}
    (output/'source-candidate.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'status':'passed','source_files':len(sources),'output':str(output)}))
    return record


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=REPO.parent/'MedSeal发布产物/0.5.0-local');args=parser.parse_args();run(args.output)
