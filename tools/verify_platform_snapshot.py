#!/usr/bin/env python3
"""Require the module ZIP to contain exactly the committed source snapshot."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import tarfile
import zipfile

REPO = Path(__file__).resolve().parents[1]
HEADER = '# Generated from the Git index by tools/verify_platform_snapshot.py.\n# Default deny; explicitly include every reviewed project file, including dotfiles.\n*\n!*/\n'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO)


def allowlist(names):
    lines = []
    for name in sorted(names):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or any(
            p in {'.git', '.mooncakes', '_build', 'tmp', 'private', 'secrets',
                  '满意度数据波动', '__pycache__'} for p in path.parts):
            raise ValueError('private-or-unsafe-path:' + name)
        if any(c in name for c in '\n\r*?[]!\\'):
            raise ValueError('unsupported-allowlist-path:' + name)
        lines.append('!/' + name + '\n')
    return HEADER + ''.join(lines)


def committed(revision):
    data = git('archive', '--format=tar', revision)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        files = {}
        for entry in archive:
            if entry.isdir():
                continue
            if not entry.isfile():
                raise ValueError('non-regular-source-member:' + entry.name)
            files[entry.name] = archive.extractfile(entry).read()
    return files


def verify(archive, revision):
    source = committed(revision)
    expected_rules = allowlist(source)
    if source.get('.moonignore', b'').decode('utf-8') != expected_rules:
        raise ValueError('stale-publish-allowlist; regenerate from reviewed Git index')
    with zipfile.ZipFile(archive) as package:
        members = [p for p in package.infolist() if not p.is_dir()]
        names = [p.filename for p in members]
        if len(names) != len(set(names)):
            raise ValueError('duplicate-archive-members')
        allowlist(names)
        missing = sorted(set(source) - set(names))
        extra = sorted(set(names) - set(source))
        if missing or extra:
            raise ValueError(json.dumps({'missing': missing, 'extra': extra}))
        mismatches = []
        manifest = []
        for entry in sorted(members, key=lambda p: p.filename):
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError('archive-symlink:' + entry.filename)
            data = package.read(entry)
            if data != source[entry.filename]:
                mismatches.append(entry.filename)
            manifest.append({'path': entry.filename, 'bytes': len(data),
                             'sha256': hashlib.sha256(data).hexdigest()})
        if mismatches:
            raise ValueError('archive-bytes-differ:' + ','.join(mismatches))
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True,
        separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()
    return {'schema': 1, 'status': 'exact-committed-snapshot',
            'source_commit': git('rev-parse', revision).decode().strip(),
            'source_tree': git('rev-parse', revision + '^{tree}').decode().strip(),
            'file_count': len(manifest), 'content_manifest_sha256': digest,
            'archive_sha256': hashlib.sha256(Path(archive).read_bytes()).hexdigest(),
            'missing_files': [], 'extra_files': [], 'changed_files': [],
            'content_manifest': manifest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-allowlist', action='store_true')
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--revision', default='HEAD')
    parser.add_argument('--record', type=Path)
    args = parser.parse_args()
    if args.write_allowlist:
        names = set(git('ls-files', '-z').decode('utf-8').rstrip('\0').split('\0'))
        names.add('.moonignore')
        (REPO / '.moonignore').write_text(allowlist(names), encoding='utf-8', newline='\n')
        print(json.dumps({'status': 'allowlist-written', 'files': len(names)}))
    if args.archive:
        result = verify(args.archive, args.revision)
        if args.record:
            args.record.parent.mkdir(parents=True, exist_ok=True)
            args.record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({k: v for k, v in result.items() if k != 'content_manifest'}))
    if not args.write_allowlist and not args.archive:
        parser.error('provide --write-allowlist or --archive')


if __name__ == '__main__':
    main()
