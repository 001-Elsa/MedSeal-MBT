#!/usr/bin/env python3
"""Full+two new-object followups through CLI; synthetic exercise, never field signoff."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from verify_with_pydicom import REPO, pydicom
from verify_strict_profile import generate_strict
from verify_risk_gate import synthetic_review
from private_store import canonical, write_exclusive


def main():
    os.umask(0o077)
    parser=argparse.ArgumentParser()
    parser.add_argument('--runtime-root',type=Path,default=REPO)
    parser.add_argument('--python',type=Path,default=Path(sys.executable))
    parser.add_argument('--record',type=Path,default=REPO/'docs/evidence/p7-synthetic-pilot.json')
    args=parser.parse_args()
    runtime=args.runtime_root.resolve(strict=True)
    python=args.python.resolve(strict=True)
    # Keep the venv entry (rather than dereferencing it) to preserve isolation.
    python=args.python.absolute()
    checks=[]
    rows=[]
    (REPO/'tmp').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=REPO/'tmp',prefix='p7-') as temp:
        root=Path(temp)
        workspace=root/'jobs';workspace.mkdir(mode=0o700)
        exports=root/'exports';exports.mkdir(mode=0o700)
        inbox=root/'inbox';inbox.mkdir(mode=0o700)
        store=root/'store'
        def command(script,*values,ok=True):
            run=subprocess.run([str(python),str(runtime/'tools'/script),*map(str,values)],cwd=runtime,capture_output=True,text=True,timeout=120)
            assert (run.returncode==0)==ok,run.stdout+run.stderr
            return json.loads(run.stdout) if ok else None
        def job_command(operation,*values,ok=True):
            return command('enterprise_job.py',operation,'--workspace',workspace,*values,ok=ok)
        command('private_store.py','init','--store',store)
        doctor=job_command('doctor')
        assert doctor['cryptography']=='50.0.2'
        signer,trust=root/'signer',root/'trust.json'
        job_command('signer-init','--signer',signer,'--trust',trust)
        registry=root/'reviewers.json'
        write_exclusive(registry,canonical({'schema':1,'reviewers':[{'id':'synthetic-test-reviewer','contexts':['synthetic'],'roles':['pixel-review','metadata-scope']}]}))
        patients,offsets,instances,studies={}, {},set(),{}
        for batch in range(3):
            source=root/('source-'+str(batch));generate_strict(source,2*(batch+1))
            for path in source.glob('*.dcm'):
                ds=pydicom.dcmread(path)
                ordinal=int.from_bytes(ds.PixelData[:4],'little')
                if ordinal<2*batch:
                    path.unlink();continue
                if 'ReferencedImageSequence' in ds:
                    del ds.ReferencedImageSequence
                ds.save_as(path,enforce_file_format=True)
            if batch==2:
                command('store_admin.py','rotate','--store',store)
                snapshot,restored=root/'backup',root/'restored'
                command('store_admin.py','backup','--store',store,'--destination',snapshot)
                command('store_admin.py','restore','--store',snapshot,'--destination',restored)
                store=restored
                checks.append('wrapping-rotation-and-backup-restore-before-new-followup')
            created=job_command('create','--input',source,'--policy',runtime/'examples/strict-policy.json','--store',store,'--source-domain','synthetic-lab')
            job_id=created['job_id'];job=workspace/job_id
            if batch==1:
                code='import sys;sys.path.insert(0,sys.argv[1]);from enterprise_job import run_job;run_job(sys.argv[2],sys.argv[3],lambda e:(print("CRASH",flush=True),sys.stdin.read(1)) if e=="after-conversion-before-journal" else None)'
                process=subprocess.Popen([str(python),'-c',code,str(runtime/'tools'),str(workspace),job_id],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
                line=process.stdout.readline().strip();assert line=='CRASH',(line,process.stderr.read())
                process.kill();process.wait(timeout=10)
                assert process.returncode<0
                result=job_command('resume','--job',job_id)
                checks.append('installed-runtime-SIGKILL-and-resume')
            else:
                result=job_command('run','--job',job_id)
            assert result['state']=='AWAITING_REVIEW'
            # Bind the synthetic fixture with the installed interpreter/provider,
            # not the QA interpreter's possibly different crypto wheel build.
            binding_code='import sys,json;from pathlib import Path;sys.path.insert(0,sys.argv[1]);from risk_gate import review_binding;print(json.dumps(review_binding(Path(sys.argv[2]))))'
            binding=json.loads(subprocess.run([str(python),'-c',binding_code,str(runtime/'tools'),str(job)],cwd=runtime,check=True,capture_output=True,text=True).stdout)
            record=root/('review-'+str(batch)+'.json');write_exclusive(record,canonical(synthetic_review(job,binding=binding)))
            job_command('review','--job',job_id,'--record',record,'--reviewers',registry)
            signed=exports/('batch-'+str(batch))
            published=job_command('publish','--job',job_id,'--output',signed,'--reviewers',registry,'--signer',signer,'--trust',trust)
            assert published['context']=='synthetic'
            command('verify_delivery.py',signed,'--trust',trust,ok=False)
            verified=command('verify_delivery.py',signed,'--trust',trust,'--allow-synthetic')
            receipt=job_command('deliver','--package',signed,'--inbox',inbox,'--trust',trust,'--receiver-id','synthetic-receiver','--allow-synthetic')
            assert receipt['objects_verified']==2
            assert job_command('deliver','--package',signed,'--inbox',inbox,'--trust',trust,'--receiver-id','synthetic-receiver','--allow-synthetic')==receipt
            for output in signed.glob('*.dcm'):
                ds=pydicom.dcmread(output)
                ordinal=int.from_bytes(ds.PixelData[:4],'little');patient=ordinal%2
                original=next(path for path in source.glob('*.dcm') if int.from_bytes(pydicom.dcmread(path).PixelData[:4],'little')==ordinal)
                src=pydicom.dcmread(original)
                alias=str(ds.PatientID)
                assert patients.setdefault(patient,alias)==alias
                shift=(datetime.date.fromisoformat(str(ds.StudyDate)[:4]+'-'+str(ds.StudyDate)[4:6]+'-'+str(ds.StudyDate)[6:8])-datetime.date.fromisoformat(str(src.StudyDate)[:4]+'-'+str(src.StudyDate)[4:6]+'-'+str(src.StudyDate)[6:8])).days
                assert offsets.setdefault(patient,shift)==shift and shift!=0
                assert studies.setdefault(patient,str(ds.StudyInstanceUID))==str(ds.StudyInstanceUID)
                assert str(ds.SOPInstanceUID) not in instances;instances.add(str(ds.SOPInstanceUID))
            rows.append({'batch':batch+1,'new_objects':2,'delivered_objects':verified['objects'],'receipt_complete':receipt['status']=='complete'})
        checks.append('full-and-two-new-object-incremental-cohorts-stable-patients-study-and-dates')
        checks.append('six-unique-instance-uids-and-idempotent-package-receipts')
        bad=root/'conflict';shutil.copytree(source,bad)
        target=next(bad.glob('*.dcm'));ds=pydicom.dcmread(target);ds.PixelData=b'\xFF'*len(ds.PixelData);ds.save_as(target,enforce_file_format=True)
        conflict=job_command('create','--input',bad,'--policy',runtime/'examples/strict-policy.json','--store',store,'--source-domain','synthetic-lab')['job_id']
        job_command('run','--job',conflict,ok=False)
        assert not (workspace/conflict/'converted').exists()
        checks.append('historical-SOP-content-conflict-blocks-without-publication')
        assert len(list(inbox.glob('*/object-*.dcm')))==6
    distribution=runtime/'distribution.json'
    result={'schema':1,'context':'synthetic','field_acceptance_complete':False,'runtime':'isolated-offline-install' if distribution.exists() else 'source-checkout',
            'distribution_manifest_sha256':hashlib.sha256(distribution.read_bytes()).hexdigest() if distribution.exists() else None,'checks':checks,'batches':rows,
            'limitations':['synthetic monochrome SC only','new cohorts have no outside-batch instance references','exact reimport still reconverts','no real user/PACS/CT-MR usability or independent security signoff']}
    args.record.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':'passed','context':'synthetic','checks':len(checks),'objects':6,'field_acceptance_complete':False}))


if __name__=='__main__':
    main()
