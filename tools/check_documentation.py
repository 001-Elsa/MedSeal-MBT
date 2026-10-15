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


# These are current contracts, not frozen research/measurement documents.
CURRENT_VERSION_DOCS = (
    'README.md', 'README.mbt.md', 'README.zh-CN.md', 'PROJECT_APPLICATION.md',
    'ACCEPTANCE.md', 'CONTRIBUTING.md', 'SECURITY.md',
    'docs/API_COMPATIBILITY.zh-CN.md', 'docs/DATA_PROCESSING.zh-CN.md',
    'docs/DATA_UPGRADE_STATUS.zh-CN.md', 'docs/MIGRATION_0.5.zh-CN.md',
    'docs/PLATFORM_SYNC.zh-CN.md', 'docs/RELEASE_READINESS.zh-CN.md',
    'docs/SUBMISSION_GUIDE.zh-CN.md', 'docs/SUBMISSION_MATERIALS.zh-CN.md',
    'docs/DOCUMENTATION_STATUS.zh-CN.md',
)
API_LIST_DOCS = ('PROJECT_APPLICATION.md', 'docs/PUBLIC_API.zh-CN.md',
                 'docs/API_COMPATIBILITY.zh-CN.md', 'README.md', 'README.zh-CN.md')
OBSOLETE_CLAIMS = {
    'README.md': ('Current scope: 0.4.1', 'Only Part 10 Explicit'),
    'README.zh-CN.md': ('支持 Part 10、Explicit VR Little Endian、ASCII',),
    'ARCHITECTURE.md': ('Only Transfer Syntax',),
    'docs/STREAMING.md': ('pixels, Implicit VR,',),
    'docs/COMMUNITY_ROADMAP.zh-CN.md': ('Implicit VR LE 仍为评估项',),
    'docs/APPLICATION_VALUE_PLAN.zh-CN.md': ('Implicit VR LE 仍未实现',),
    'PROJECT_APPLICATION.md': ('| 对应版本 | 0.4.1', '六个公共', 'Native139',
                               '各86', '事实以0.4.1'),
}


def current_contract_errors(texts, version, public_packages, schemas):
    errors = []
    for name in CURRENT_VERSION_DOCS:
        if version not in texts[name]:
            errors.append(f'{name}: missing current module version {version}')
    for name in API_LIST_DOCS:
        for package in public_packages:
            if f'api/{package}' not in texts[name]:
                errors.append(f'{name}: missing public API api/{package}')
    for name, claims in OBSOLETE_CLAIMS.items():
        for claim in claims:
            if claim in texts[name]:
                errors.append(f'{name}: obsolete current claim: {claim}')
    application = texts['PROJECT_APPLICATION.md']
    # The application's version row must itself be current; an appended banner
    # must not conceal an old primary application as happened before this audit.
    if not re.search(r'^\| 对应版本 \|[^\n]*' + re.escape(version), application, re.M):
        errors.append('PROJECT_APPLICATION.md: stale primary version row')
    for schema in schemas:
        if schema not in texts['docs/DATA_PROCESSING.zh-CN.md']:
            errors.append(f'data guide: missing schema contract {schema}')
    return errors


def regression_checks(texts, version, public_packages, schemas):
    """Reproduce old documentation failures without changing the worktree."""
    cases = [
        ('PROJECT_APPLICATION.md', lambda s: re.sub(
            r'^(\| 对应版本 \|)[^\n]*', r'\1 0.4.1 社区发行快照 |', s, flags=re.M)),
        ('PROJECT_APPLICATION.md', lambda s: s.replace('api/query', 'old-query')),
        ('docs/STREAMING.md', lambda s: s + '\npixels, Implicit VR, unsupported\n'),
        ('docs/PLATFORM_SYNC.zh-CN.md', lambda s: s.replace(version, '0.4.1')),
        ('docs/DATA_PROCESSING.zh-CN.md', lambda s: s.replace(schemas[0], 'old-schema')),
    ]
    for name, mutate in cases:
        changed = dict(texts)
        changed[name] = mutate(texts[name])
        if not current_contract_errors(changed, version, public_packages, schemas):
            raise AssertionError(f'documentation regression not rejected: {name}')
    return len(cases)


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
        # A blank line must not detach appended API/rule rows from a table.
        lines = text.splitlines()
        fenced = False
        for number, line in enumerate(lines):
            if line.startswith('```'):
                fenced = not fenced
            if fenced or not line.startswith('|'):
                continue
            if number > 0 and lines[number - 1].startswith('|'):
                continue
            if number + 1 == len(lines) or not re.fullmatch(r'[| :\-]+', lines[number + 1]):
                errors.append(f'{name}:{number + 1}: table rows detached from header')
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
    public_packages = sorted(p.parent.name for p in (REPO / 'api').glob('*/pkg.generated.mbti'))
    schema_paths = sorted((REPO / 'resources/data').glob('*.schema.json'))
    schemas = [p.name for p in schema_paths]
    facts['public_api_packages'] = len(public_packages)
    facts['data_report_schemas'] = len(schemas)
    texts = {name: (REPO / name).read_text(encoding='utf-8') for name in names}
    errors.extend(current_contract_errors(texts, version, public_packages, schemas))
    regressions = regression_checks(texts, version, public_packages, schemas)
    # Names must exist in the actual generated public interfaces, not only prose.
    interface_symbols = {
        'query': ('lookup', 'values', 'scalar', 'integer', 'select', 'project', 'group_counts', 'summary'),
        'quality': ('check', 'check_datasets', 'from_errors'),
        'native': ('scan_directory', 'quality_directory', 'plan_directory'),
        'validation': ('plan_collection',),
    }
    for package, symbols in interface_symbols.items():
        interface = (REPO / f'api/{package}/pkg.generated.mbti').read_text(encoding='utf-8')
        for symbol in symbols:
            if not re.search(r'pub (?:async )?fn ' + symbol + r'\(', interface):
                errors.append(f'documented interface missing: api/{package}.{symbol}')
    for key, value in facts.items():
        if f'`{key}={value}`' not in index:
            errors.append(f'document index drift: {key}={value}')
    if '| 参赛者 | 韩桢 |' not in (REPO / 'PROJECT_APPLICATION.md').read_text(encoding='utf-8'):
        errors.append('application identity differs from user-confirmed name')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(json.dumps({'status': 'passed', 'markdown_documents': len(names),
                      'version': version, 'regression_checks': regressions, **facts}, ensure_ascii=False))


if __name__ == '__main__':
    check()
