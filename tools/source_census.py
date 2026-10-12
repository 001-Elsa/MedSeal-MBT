#!/usr/bin/env python3
"""Read-only private source census; requires development pydicom, no values/logs."""
from pathlib import Path
import argparse
from collections import Counter
import json
import os
import warnings
from enterprise_job import scan
from private_store import canonical, write_exclusive
from verify_with_pydicom import pydicom


def census(root):
    inventory = scan(root)
    syntax, sop, charset, sizes = Counter(), Counter(), Counter(), []
    failures = 0
    for path, signature, candidate, reason in inventory:
        if not candidate:
            continue
        if signature[2] > 256 * 1024 * 1024:
            failures += 1
            continue
        try:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                ds = pydicom.dcmread(path, stop_before_pixels=True, specific_tags=['SOPClassUID','SpecificCharacterSet'])
            uid = str(ds.file_meta.get('TransferSyntaxUID', ''))
            syntax[uid if uid in {'1.2.840.10008.1.2','1.2.840.10008.1.2.1','1.2.840.10008.1.2.2','1.2.840.10008.1.2.4.50','1.2.840.10008.1.2.4.90','1.2.840.10008.1.2.5'} else 'unclassified'] += 1
            value = str(ds.get('SOPClassUID',''))
            sop[value if value in {'1.2.840.10008.5.1.4.1.1.2','1.2.840.10008.5.1.4.1.1.4','1.2.840.10008.5.1.4.1.1.7'} else 'unclassified'] += 1
            value = str(ds.get('SpecificCharacterSet',''))
            charset[value if value in {'','ISO_IR 6','ISO_IR 192','ISO_IR 100'} else 'unclassified'] += 1
            sizes.append(signature[2])
        except Exception:
            failures += 1
    return {'schema': 1, 'scope': 'private-source-census-not-conformance', 'files': sum(item[3] != 'directory' for item in inventory), 'candidates': sum(item[2] for item in inventory), 'excluded_non_part10': sum(item[3]=='non-part10' for item in inventory), 'unreadable_or_over_budget': failures, 'transfer_syntax_counts': dict(syntax), 'sop_class_counts': dict(sop), 'charset_counts': dict(charset), 'largest_file_bytes': max(sizes,default=0), 'total_candidate_bytes': sum(sizes), 'release_authorized': False}


def main():
    os.umask(0o077)
    parser=argparse.ArgumentParser()
    parser.add_argument('input',type=Path)
    parser.add_argument('--private-report',type=Path,required=True)
    args=parser.parse_args()
    try:
        report=census(args.input)
        write_exclusive(args.private_report,canonical(report))
        print(json.dumps({'schema':1,'status':'private-census-saved','candidates':report['candidates'],'release_authorized':False}))
        return 0
    except Exception:
        print('{"schema":1,"status":"failed","code":"source-census-failed"}')
        return 5


if __name__=='__main__':
    raise SystemExit(main())
