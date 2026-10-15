#!/usr/bin/env python3
"""Run the new public data pipeline from an isolated package archive on four backends."""
from pathlib import Path
import argparse
import json
import jsonschema
from verify_with_pydicom import REPO
from verify_consumer import run_consumer, verify_output


def verify_pipeline(output):
    lines=output.strip().splitlines()
    assert lines[-1]=='data-pipeline-ok'
    reports=[json.loads(s) for s in lines if s.startswith('{')]
    inventory=next(r for r in reports if r.get('schema')=='medseal-inventory-v1')
    quality=next(r for r in reports if r.get('schema')=='medseal-quality-v1')
    plan=next(r for r in reports if r.get('schema')=='medseal-plan-v1')
    assert inventory['objects']==2 and inventory['studies']==1 and inventory['series']==1
    assert quality['ready'] and plan['patients']==1
    assert '"modality","rows"' in output
    assert len([r for r in reports if r.get('rows')==['2']])==2
    for report,contract in [(inventory,'inventory-v1'),(quality,'quality-v1'),(plan,'plan-v1')]:
        jsonschema.Draft202012Validator(json.loads((REPO/'resources/data'/(contract+'.schema.json')).read_text())).validate(report)
        assert report['release_authorized'] is False
        for private in ['SDKCANARY','987654321','20240229','1.2.826']:
            assert private not in json.dumps(report)
    existing='\n'.join([s for s in lines if s.startswith('synthetic-output-')]+[json.dumps(plan),'public-collection-ok'])
    return {**verify_output(existing),'data_processing':'query-quality-plan-export-verified'}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--record',type=Path,default=REPO/'tmp/data-consumer-ci.json');a=p.parse_args()
    result=run_consumer(a.record,consumer_name='data_pipeline',verifier=verify_pipeline)
    result['output']='data-pipeline-ok'
    result['checks'].extend(['query-filter-and-csv-jsonl-export','quality-and-plan-public-canaries','typed-query-errors-and-config-budget-tests'])
    a.record.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'status':'passed','backends':list(result['backends']),'record':str(a.record)}))
