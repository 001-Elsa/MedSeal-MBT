#!/usr/bin/env python3
"""Real ENOSPC on a disposable disk image; never formats an existing device."""
from pathlib import Path
import errno
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from verify_with_pydicom import REPO,pydicom
from verify_strict_profile import generate_strict
from private_store import initialize


def main():
    if sys.platform!='darwin':
        raise RuntimeError('macOS-only disposable image exercise')
    os.umask(0o077)
    (REPO/'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO/'tmp',prefix='enospc-') as temp:
        root=Path(temp);image=root/'test.dmg';mount=root/'mount';mount.mkdir()
        subprocess.run(['hdiutil','create','-size','32m','-fs','HFS+','-volname','MedSealENOSPC',str(image)],check=True,capture_output=True)
        attached=subprocess.run(['hdiutil','attach','-nobrowse','-mountpoint',str(mount),'-plist',str(image)],check=True,capture_output=True)
        entities=plistlib.loads(attached.stdout)['system-entities']
        device=entities[0]['dev-entry']
        try:
            if not any(entity.get('mount-point')==str(mount) for entity in entities):
                raise RuntimeError('unexpected-disposable-mount-point')
            os.chmod(mount,0o700)
            source=root/'source';generate_strict(source,1)
            path=next(source.glob('*.dcm'));ds=pydicom.dcmread(path)
            ds.Rows,ds.Columns=1024,8192;ds.BitsAllocated=ds.BitsStored=16;ds.HighBit=15
            ds.PixelData=b'\x00\x01'*(1024*8192);ds['PixelData'].VR='OW';ds.save_as(path,enforce_file_format=True)
            store=root/'store';initialize(store)
            filler=mount/'capacity-reservation'
            leave=2*1024*1024
            with filler.open('wb') as file:
                size=max(0,shutil.disk_usage(mount).free-leave)
                while size:
                    part=b'\x00'*min(size,1024*1024);file.write(part);size-=len(part)
                file.flush();os.fsync(file.fileno())
            target=mount/'output'
            binary=REPO/'_build/native/debug/build/cmd/enterprise/enterprise.exe'
            control=subprocess.run([str(binary),str(source),str(root/'control-output'),str(REPO/'examples/strict-policy.json'),sys.executable,str(REPO/'tools/private_store.py'),str(store),'synthetic-lab'],capture_output=True,text=True)
            assert control.returncode==0
            directory_fd=os.open(mount,os.O_RDONLY|os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
            run=subprocess.run([str(binary),str(source),str(target),str(REPO/'examples/strict-policy.json'),sys.executable,str(REPO/'tools/private_store.py'),str(store),'synthetic-lab'],capture_output=True,text=True)
            assert run.returncode!=0 and not target.exists()
            observed=None
            try:
                with (mount/'kernel-probe').open('wb',buffering=0) as file:
                    while True:
                        file.write(b'\x00'*(1024*1024))
            except OSError as error:
                observed=error.errno
            assert observed==errno.ENOSPC
            record={'schema':1,'fixture':'disposable32MiB HFS+ disk image and synthetic16MiB SC','kernel_errno':'ENOSPC','control_conversion_exit_code':control.returncode,'conversion_exit_code':run.returncode,'final_output_exists':False,'scope':'actual kernel no-space rejection; not power-loss/APFS/Windows certification'}
            (REPO/'docs/evidence/p0-real-enospc.json').write_text(json.dumps(record,indent=2)+'\n')
            print(json.dumps({'status':'passed','kernel_errno':'ENOSPC','final_output_exists':False}))
        finally:
            subprocess.run(['hdiutil','detach',device],check=True,capture_output=True)


if __name__=='__main__':
    main()
