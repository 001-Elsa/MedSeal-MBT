#!/usr/bin/env python3
"""Fresh native API evidence; never deserialize a boolean into authority."""
import argparse
import json
import sys
from pathlib import Path
from enterprise_job import locked_job
from risk_gate import gate
from verify_delivery import verify_package


def review(workspace, job_id, registry):
    with locked_job(workspace, job_id) as job:
        _, _, inventory, record, checksum = gate(job, registry)
        return {'schema': 1, 'kind': 'review', 'sha256': checksum,
                'objects': len(inventory), 'context': record['record']['context']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['review', 'package'])
    parser.add_argument('root', type=Path)
    parser.add_argument('identity')
    parser.add_argument('trust', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'review':
            result = review(args.root, args.identity, args.trust)
        else:
            if args.identity not in {'controlled', 'synthetic-test'}:
                raise ValueError('invalid context')
            checked = verify_package(args.root, args.trust, args.identity == 'synthetic-test')
            result = {'schema': 1, 'kind': 'package', 'sha256': checked['release_sha256'],
                      'objects': checked['objects'], 'context': checked['context']}
        print(json.dumps(result, sort_keys=True, separators=(',', ':')))
        return 0
    except Exception:
        # No paths, raw diagnostics or review values cross the public boundary.
        print('{"schema":1,"status":"rejected","code":"evidence-revalidation-failed"}', file=sys.stderr)
        return 6


if __name__ == '__main__':
    raise SystemExit(main())
