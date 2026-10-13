#!/usr/bin/env python3
"""Check maintained document inventory, local links and versioned code facts."""
from pathlib import Path
import json
import re
import subprocess
from urllib.parse import unquote, urlsplit

REPO = Path(__file__).resolve().parents[1]


def documents():
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '*.md'],
        cwd=REPO, text=True, encoding='utf-8').splitlines()
    return sorted(set(names))


def check():
    names = documents()
    errors = []
    index = (REPO / 'docs/DOCUMENTATION_STATUS.zh-CN.md').read_text(encoding='utf-8')
    for name in names:
        source = REPO / name
        text = source.read_text(encoding='utf-8')
        if f'`{name}`' not in index:
            errors.append(name + ': missing from reviewed document inventory')
        if '韩枕' in text:
            errors.append(name + ': incorrect participant name')
        # Examples inside code fences are not Markdown links.
        prose = re.sub(r'```.*?```', '', text, flags=re.S)
        for match in re.finditer(r'\[[^\]\n]+\]\(([^)\n]+)\)', prose):
            raw = match.group(1).strip()
            target = raw[1:raw.index('>')] if raw.startswith('<') else raw.split()[0]
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            path = unquote(parsed.path)
            resolved = Path(path) if path.startswith('/') else source.parent / path
            if not resolved.exists():
                line = text[:match.start()].count('\n') + 1
                errors.append(f'{name}:{line}: missing local link {target}')

    if (REPO / 'README.md').read_bytes() != (REPO / 'README.mbt.md').read_bytes():
        errors.append('README.md and README.mbt.md differ')
    module = (REPO / 'moon.mod').read_text(encoding='utf-8')
    version = re.search(r'^version\s*=\s*"([^"]+)"', module, re.M).group(1)
    model = (REPO / 'src/model/version.mbt').read_text(encoding='utf-8')
    if f'"{version}"' not in model:
        errors.append('CLI version differs from module metadata')
    corpus = json.loads((REPO / 'conformance/manifest.json').read_text(encoding='utf-8'))
    facts = {
        'classified_attributes': len(json.loads((REPO / 'resources/rules/strict-v1.json').read_text(encoding='utf-8'))['attributes']),
        'rulebook_entries': len(json.loads((REPO / 'resources/rules/rulebook-v1.json').read_text(encoding='utf-8'))['rules']),
        'corpus_cases': len(corpus['entries']) + len(corpus['collections']),
    }
    for key, value in facts.items():
        if f'`{key}={value}`' not in index:
            errors.append(f'document index drift: {key}={value}')
    if '| 参赛者 | 韩桢 |' not in (REPO / 'PROJECT_APPLICATION.md').read_text(encoding='utf-8'):
        errors.append('application identity differs from user-confirmed name')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(json.dumps({'status': 'passed', 'markdown_documents': len(names),
                      'version': version, **facts}, ensure_ascii=False))


if __name__ == '__main__':
    check()
