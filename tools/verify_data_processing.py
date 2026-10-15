#!/usr/bin/env python3
"""Independent synthetic data-processing, Native failures and implicit-VR acceptance."""
from pathlib import Path
import argparse
import csv
import io
import json
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import copy
from verify_with_pydicom import REPO  # also discovers isolated QA packages
import pydicom
from pydicom.sequence import Sequence
from pydicom.dataset import Dataset
from pydicom.uid import ImplicitVRLittleEndian
from generate_conformance_corpus import base
from evidence import code_identity


def make(root, count=2, implicit=False, bits=8, undefined=False, payload_mib=None):
    root.mkdir()
    for i in range(count):
        ds = base()
        ds.SOPInstanceUID = f'1.2.3.30.{i+1}'
        ds.file_meta.MediaStorageSOPInstanceUID = ds.SOPInstanceUID
        ds.InstanceNumber = i+1
        ds.PatientName = 'UPGRADECANARY^SYNTHETIC'
        ds.PixelData = bytes([i % 256, 64, 128, 255]) * (bits // 8)
        ds.BitsAllocated = ds.BitsStored = bits
        ds.HighBit = bits-1
        ds.PixelRepresentation = int(bits == 16)
        ds['PixelData'].VR = 'OW' if bits == 16 else 'OB'
        if payload_mib:
            size = payload_mib*1024*1024
            ds.Rows, ds.Columns = size // (8192*(bits//8)), 8192
            ds.PixelData = bytes([i % 256,64,128,255]) * (size//4)
        if i > 0:
            item = Dataset()
            item.ReferencedSOPClassUID = ds.SOPClassUID
            item.ReferencedSOPInstanceUID = f'1.2.3.30.{i}'
            item.is_undefined_length_sequence_item = undefined
            ds.ReferencedImageSequence = Sequence([item])
            ds['ReferencedImageSequence'].is_undefined_length = undefined
        if implicit:
            ds.file_meta.TransferSyntaxUID = ImplicitVRLittleEndian
        ds.save_as(root / f'object-{i+1}.dcm', enforce_file_format=True)


def independent_outputs(source, output):
    originals_by_number = {int(ds.InstanceNumber): ds for ds in (pydicom.dcmread(p) for p in source.glob('*.dcm'))}
    originals = list(originals_by_number.values())
    manifest = json.loads((output/'manifest.json').read_text())
    results = [pydicom.dcmread(output/e['file']) for e in manifest['objects']]
    assert len(results) == len(originals) and manifest['status'] == 'complete'
    assert manifest['release_authorized'] is False
    originals = [originals_by_number[int(ds.InstanceNumber)] for ds in results]
    assert len({int(ds.InstanceNumber) for ds in results}) == len(originals_by_number)
    mappings = {}
    dates = set()
    for old,new,entry in zip(originals, results, manifest['objects']):
        assert new.PixelData == old.PixelData
        assert new.Rows == old.Rows and new.Columns == old.Columns
        assert new.BitsAllocated == old.BitsAllocated and new.PixelRepresentation == old.PixelRepresentation
        assert str(new.file_meta.TransferSyntaxUID) == '1.2.840.10008.1.2.1'
        assert new.file_meta.MediaStorageSOPInstanceUID == new.SOPInstanceUID
        assert 'UPGRADECANARY' not in str(new.PatientName)
        assert str(new.PatientID) == 'P1'
        assert str(old.SOPInstanceUID) != str(new.SOPInstanceUID)
        assert hashlib.sha256((output/entry['file']).read_bytes()).hexdigest() == entry['sha256']
        mappings[str(old.SOPInstanceUID)] = str(new.SOPInstanceUID)
        dates.add(str(new.StudyDate))
    assert len(dates) == 1 and dates != {'20240229'}
    for old,new in zip(originals,results):
        if 'ReferencedImageSequence' in old:
            assert new.ReferencedImageSequence[0].ReferencedSOPInstanceUID == mappings[str(old.ReferencedImageSequence[0].ReferencedSOPInstanceUID)]
    return {'objects':len(results),'references':sum('ReferencedImageSequence' in d for d in results),'pixels':'independent-byte-equality','normalized_syntax':'explicit-vr-le'}


def run(record, build=True):
    os.umask(0o077)
    if build:
        subprocess.run([str(REPO/'tools/moon-local'),'build','--target','native'],cwd=REPO,check=True)
    data = REPO/'_build/native/debug/build/cmd/data/data.exe'
    consumer = REPO/'_build/native/debug/build/examples/native_pipeline/native_pipeline.exe'
    lab = REPO/'_build/native/debug/build/cmd/lab/lab.exe'
    checks = []
    oracle = []
    def call(binary,*args,ok=True):
        proc = subprocess.run([str(binary),*map(str,args)],cwd=REPO,capture_output=True,text=True,timeout=120)
        if (proc.returncode == 0) != ok:
            raise AssertionError({'binary':binary.name,'args':list(map(str,args)),'returncode':proc.returncode,'stdout':proc.stdout,'stderr':proc.stderr})
        return proc.stdout
    (REPO/'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='data-acceptance-',dir=REPO/'tmp') as temp:
        root=Path(temp)
        source=root/'explicit';make(source)
        summary=json.loads(call(data,'summary',source))
        assert (summary['objects'],summary['studies'],summary['series'])==(2,1,1)
        assert 'UPGRADECANARY' not in json.dumps(summary) and '1.2.3' not in json.dumps(summary)
        report=json.loads(call(data,'quality',source));assert report['quality']['ready']
        checks.append('anonymous-inventory-and-quality')
        for fmt in ['csv','jsonl']:
            target=root/f'table.{fmt}'
            call(data,'export',source,'--output',target,'--format',fmt,'--fields','00080060,00280010,00100010','--equals','00080060=OT')
            text=target.read_text()
            if fmt=='csv':
                rows=list(csv.DictReader(io.StringIO(text)));assert len(rows)==2 and rows[0]['00280010']=='2' and rows[0]['00100010']=='UPGRADECANARY^SYNTHETIC'
            else:
                rows=[json.loads(line) for line in text.splitlines()];assert len(rows)==2 and rows[0]['00280010']==['2']
            original=target.read_bytes()
            call(data,'export',source,'--output',target,'--format',fmt,ok=False)
            assert target.read_bytes()==original
        checks.extend(['csv-and-jsonl-independent-readback','no-overwrite-private-export'])
        formula=root/'formula';make(formula,count=1)
        f=next(formula.glob('*.dcm'));ds=pydicom.dcmread(f);ds.PatientName='=HYPERLINK("x")';ds.save_as(f,enforce_file_format=True)
        target=root/'formula.csv';call(data,'export',formula,'--output',target,'--fields','00100010')
        assert list(csv.DictReader(io.StringIO(target.read_text())))[0]['00100010'].startswith("'=")
        checks.append('spreadsheet-formula-guard')
        for implicit,bits,undefined in [(False,8,False),(True,8,False),(True,16,False),(True,8,True)]:
            src=root/f'case-{implicit}-{bits}-{undefined}';make(src,implicit=implicit,bits=bits,undefined=undefined)
            out=root/(src.name+'-out')
            call(data,'convert',src,'--output',out)
            oracle.append(independent_outputs(src,out))
            # Public parser/writer normalizes implicit syntax without deidentification.
            one=sorted(src.glob('*.dcm'))[-1];roundtrip=root/(src.name+'-roundtrip.dcm')
            actual=json.loads(call(lab,'field',one,'00280010','-',roundtrip))
            assert actual['status']=='passed'
            before,after=pydicom.dcmread(one),pydicom.dcmread(roundtrip)
            assert before.PatientName==after.PatientName and before.PixelData==after.PixelData
            assert before.get('ReferencedImageSequence')==after.get('ReferencedImageSequence')
        checks.extend(['implicit-8-and-signed16-normalized-output','defined-and-undefined-sequence-items','public-parser-writer-roundtrip'])
        for mode in ['cancel-plan','cancel-scan','cancel-execute','cancel-commit','scan-copy','reuse','changed-input']:
            src=root/mode;make(src,count=1 if mode=='cancel-commit' else 2)
            out=root/(mode+'-out')
            call(consumer,mode,src,out)
            if mode!='reuse':assert not out.exists()
            assert not list(root.glob(out.name+'.medseal-*')),mode
        checks.extend(['public-native-consumer-detached-data','cancel-plan-scan-mid-execution-and-before-commit','single-use-job','input-set-change-rejected','failure-stage-cleanup'])
        # Failed parse cannot be dropped from the original collection.
        broken=root/'broken';make(broken);(broken/'bad.dcm').write_bytes(b'bad')
        report=json.loads(call(data,'quality',broken,ok=False));assert report['quality']['objects']==3 and report['quality']['collection_checks']=='not-checked' and report['quality']['issues']
        out=root/'broken-out';call(data,'convert',broken,'--output',out,ok=False);assert not out.exists()
        checks.append('bad-object-never-silently-dropped')
        duplicate=root/'duplicate';make(duplicate)
        files=sorted(duplicate.glob('*.dcm'));files[1].write_bytes(files[0].read_bytes())
        r=json.loads(call(data,'quality',duplicate,ok=False));assert not r['quality']['ready']
        checks.append('duplicate-identity-blocked')
        for kind in ['unknown','private']:
            src=root/kind;make(src,count=1,implicit=True)
            path=next(src.glob('*.dcm'));ds=pydicom.dcmread(path)
            ds.add_new(0x77760001 if kind=='unknown' else 0x00111010,'LO','UPGRADECANARY')
            ds.save_as(path,enforce_file_format=True)
            result=json.loads(call(lab,'field',path,'00280010','-','-'))
            assert result=={'status':'blocked','code':'MEDSEAL-E110'},result
            out=root/(kind+'-out');call(data,'convert',src,'--output',out,ok=False);assert not out.exists()
        checks.append('unknown-and-private-implicit-tags-rejected-with-stable-code')
        # Source field VR is genuinely ambiguous; no dictionary guess can resolve it.
        src=root/'truncated';make(src,count=1,implicit=True)
        p=next(src.glob('*.dcm'));p.write_bytes(p.read_bytes()[:-1])
        call(data,'convert',src,'--output',root/'truncated-out',ok=False)
        checks.append('truncated-implicit-pixels-rejected')
        if sys.platform!='win32':
            links=root/'links';links.mkdir();(links/'link.dcm').symlink_to(next(source.glob('*.dcm')))
            call(data,'summary',links,ok=False)
            checks.append('symlink-source-rejected')
        # CLI arguments fail before an export is created.
        for suffix,options in [('format',['--format','bad']),('duplicate',['--format','csv','--format','jsonl']),('tag',['--fields','oops']),('group',['--group','oops'])]:
            path=root/(suffix+'.csv');call(data,'export',source,'--output',path,*options,ok=False);assert not path.exists()
        checks.append('invalid-options-have-no-output')
    result={'schema':1,'status':'passed','checks':checks,'oracle':{'name':'pydicom','version':pydicom.__version__,'workflows':oracle},'release_authorized':False,'source_state':'local-working-tree; not registry publication',**code_identity(REPO)}
    record.parent.mkdir(parents=True,exist_ok=True);record.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'status':'passed','checks':len(checks),'record':str(record)}))
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--record',type=Path,default=REPO/'tmp/data-processing-ci.json');parser.add_argument('--no-build',action='store_true');args=parser.parse_args()
    run(args.record,build=not args.no_build)
