"""Reproducible code-tree identity for pre-commit and CI acceptance evidence."""
from pathlib import Path
import hashlib
import json
import subprocess


def code_identity(repo):
    repo = Path(repo)
    scopes = ['src', 'api', 'cmd', 'tools', 'tests', 'resources', 'conformance', '.github', 'examples/authorization']
    paths = [repo / name for name in ['moon.mod', '.gitattributes', 'requirements-enterprise.txt', 'requirements-qa.txt'] if (repo / name).is_file()]
    for name in scopes:
        root = repo / name
        if root.exists():
            paths.extend(path for path in root.rglob('*') if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc')
    files = [{'path': path.relative_to(repo).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(paths)]
    payload = json.dumps(files, sort_keys=True, separators=(',', ':')).encode()
    return {'source_base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
            'source_tree_scopes': scopes + ['moon.mod', '.gitattributes', 'requirements-enterprise.txt', 'requirements-qa.txt'],
            'source_tree_files': len(files), 'source_tree_sha256': hashlib.sha256(payload).hexdigest()}
