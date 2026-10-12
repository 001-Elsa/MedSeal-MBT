#!/usr/bin/env python3
"""Self-contained public report, rebuilt from a narrow structural allowlist."""
from collections import Counter
import html
import re

PATH = re.compile(r'^dataset(?:/[0-9A-F]{4},[0-9A-F]{4}(?:\[[0-9]{1,6}\])?){0,33}$')
ACTIONS = {'keep', 'empty', 'remove', 'replace', 'remap', 'shift', 'recurse'}


def render(report, catalog):
    known = {rule['id'] for rule in catalog['rules']}
    rows = []
    if report.get('schema') != 1 or report.get('release_authorized') is not False:
        raise ValueError('unsupported public report')
    status = report.get('status')
    if status == 'converted-explanation':
        for item in report.get('decisions', []):
            path, rule, action = item.get('path'), item.get('rule_id'), item.get('action')
            if not isinstance(path, str) or len(path) > 1024 or not PATH.fullmatch(path) or rule not in known or action not in ACTIONS:
                raise ValueError('nonpublic decision')
            rows.append((path, rule, action))
    elif status == 'blocked':
        issue = report.get('issue', {})
        path, rule = issue.get('path'), issue.get('rule_id')
        if not isinstance(path, str) or len(path) > 1024 or not PATH.fullmatch(path) or rule not in known:
            raise ValueError('nonpublic issue')
        rows.append((path, rule, 'blocked'))
    else:
        raise ValueError('unsupported public status')
    counts = Counter(action for _, _, action in rows)
    escaped = lambda text: html.escape(text, quote=True)
    table = ''.join('<tr>' + ''.join('<td>' + escaped(value) + '</td>' for value in row) + '</tr>' for row in rows)
    document = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'"><title>MedSeal 规则解释</title><style>body{font:16px system-ui;margin:2rem;max-width:1000px}td,th{padding:8px;border:1px solid #ccc}table{border-collapse:collapse}</style><h1>MedSeal 规则解释</h1><p>公开结构报告；像素未获自动放行。</p><p>' + escaped(status) + '</p><table><thead><tr><th>字段路径</th><th>规则</th><th>动作</th></tr></thead><tbody>' + table + '</tbody></table></html>'
    labels = ''.join('<text x="16" y="' + str(52 + i * 24) + '">' + escaped(action) + ': ' + str(counts[action]) + '</text>' for i, action in enumerate(sorted(counts)))
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="360" height="260" role="img" aria-label="MedSeal rule action counts"><rect width="360" height="260" fill="white"/><text x="16" y="24">MedSeal public rule summary</text>' + labels + '</svg>'
    return document, svg
