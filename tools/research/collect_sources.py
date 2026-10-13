"""Read-only public research; save pinned sources, never execute project code."""
from pathlib import Path, PurePosixPath
from concurrent.futures import ThreadPoolExecutor, as_completed
import datetime, hashlib, json, stat, urllib.request, urllib.parse, zipfile, io

import argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, required=True, help='Local research directory; not the project source tree')
ROOT = parser.parse_args().output_dir.resolve()
ROOT.mkdir(parents=True, exist_ok=True)
PROJECTS = [
    ('MoUI', 'wzzc-dev/MoUI', 'finalist'),
    ('aitne', 'Arcelyth/aitne', 'finalist'),
    ('MoonFrame', 'ihb2032/MoonFrame', 'finalist'),
    ('Frontier Lab', 'shop1111/FrontierLab', 'finalist'),
    ('tokenizers-moonbit', 'howtomakeaname/tokenizers-moonbit', 'third'),
    ('markitdown', 'ZSeanYves/markitdown', 'third'),
    ('moon_graphql', 'Eisem/moon_graphql', 'third'),
    ('MoonBit Hex Editor', 'R00TK17/moonbit-HexEditor', 'third'),
    ('moonsic', 'hyl-star/moonsic', 'third'),
    ('linear-algebra', 'Luna-Flow/linear-algebra', 'third'),
    ('MoonCharts', 'pxgt/mooncharts', 'third'),
    ('raft-moonbit', 'Lfan-ke/raft-moonbit', 'third'),
    ('MoonMarkMind', 'Xiao-li-He/MoonMarkMind', 'third'),
]
CUTOFF = '2026-07-17T15:59:59Z'
HEADERS = {'User-Agent': 'MedSeal-public-project-research', 'Accept': 'application/vnd.github+json'}


def get(url, maximum=4*1024*1024):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=40) as response:
        data = response.read(maximum+1)
        if len(data) > maximum:
            raise ValueError('bounded-download-exceeded')
        return data


def api(path):
    return json.loads(get('https://api.github.com/'+path))


def snapshot(repo, sha, period):
    name = repo.replace('/', '__')
    archive = ROOT / 'archives' / (name+'-'+sha[:12]+'.zip')
    archive.parent.mkdir(exist_ok=True)
    if not archive.exists():
        data = get('https://codeload.github.com/'+repo+'/zip/'+sha, 64*1024*1024)
        archive.write_bytes(data)
    else:
        data = archive.read_bytes()
    target = ROOT/'sources'/period/name
    target.mkdir(parents=True, exist_ok=True)
    files = []
    excluded_links = []
    total = 0
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for member in z.infolist():
            path = PurePosixPath(member.filename)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('unsafe-archive-member')
            if stat.S_ISLNK(member.external_attr >> 16):
                excluded_links.append(member.filename)
                continue
            if member.is_dir() or len(path.parts)<2:
                continue
            relative = Path(*path.parts[1:])
            total += member.file_size
            if total > 256*1024*1024:
                raise ValueError('uncompressed-archive-budget')
            # Read code/docs only. Do not fetch or execute dependencies or demos.
            if member.file_size > 8*1024*1024 or relative.suffix.lower() not in {'.md','.mbt','.mbti','.json','.yaml','.yml','.toml','.txt','.html','.js','.mjs','.ts','.css','.c','.h','.py','.mod','.pkg','.sh','.csv','.lock'} and relative.name not in {'LICENSE','NOTICE','moon.mod','moon.pkg','Makefile'}:
                continue
            content = z.read(member)
            output = target/relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(content)
            files.append({'path':relative.as_posix(),'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()})
    return {'sha':sha,'source_directory':str(target.relative_to(ROOT)), 'archive':str(archive.relative_to(ROOT)), 'archive_sha256':hashlib.sha256(data).hexdigest(), 'excluded_symlinks':excluded_links, 'saved_text_files':len(files),'files':files}


def collect(project):
    name, repo, award = project
    existing = ROOT/(repo.replace('/','__')+'.metadata.json')
    if existing.exists():
        cached = json.loads(existing.read_bytes())
        if not cached.get('error') and cached.get('current') and 'july' in cached:
            return cached
    row = {'name':name,'repository':repo,'official_status':award,'url':'https://github.com/'+repo}
    try:
        meta = api('repos/'+repo)
        row.update(default_branch=meta['default_branch'],created_at=meta['created_at'],license=meta.get('license'),description=meta.get('description'),homepage=meta.get('homepage'),fork=meta['fork'])
        commit = api('repos/'+repo+'/commits/'+urllib.parse.quote(meta['default_branch'],safe=''))
        row['current_commit_date'] = commit['commit']['committer']['date']
        row['current'] = snapshot(repo,commit['sha'],'current')
        candidates = api('repos/'+repo+'/commits?'+urllib.parse.urlencode({'sha':meta['default_branch'],'until':CUTOFF,'per_page':1}))
        if candidates:
            row['july_commit_date'] = candidates[0]['commit']['committer']['date']
            row['july'] = snapshot(repo,candidates[0]['sha'],'july17')
        else:
            row['july'] = None
            row['historical_limit'] = 'No reachable default-branch commit before cutoff; not proof of historical absence.'
    except Exception as e:
        row['error'] = str(e)
    (ROOT/(repo.replace('/','__')+'.metadata.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    return row


def main():
    for name,url in [('official-event.html','https://moonbitlang.github.io/OSC2026/'),('official-showcase.html','https://moonbitlang.github.io/OSC2026/showcase.html'),('current-hackathon.html','https://moonbitlang.github.io/Hackathon2026/')]:
        (ROOT/name).write_bytes(get(url))
    rows=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for future in as_completed([pool.submit(collect,p) for p in PROJECTS]):
            row=future.result();rows.append(row)
            print(json.dumps({k:row.get(k) for k in ('name','repository','current_commit_date','july_commit_date','error')},ensure_ascii=False),flush=True)
    rows.sort(key=lambda r:next(i for i,p in enumerate(PROJECTS) if p[1]==r['repository']))
    (ROOT/'inventory.json').write_text(json.dumps({'retrieved_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'official_url':'https://moonbitlang.github.io/OSC2026/#winners','cutoff':CUTOFF,'historical_scope':'Latest reachable commit on current default branch before acceptance cutoff; not official submitted revision.','projects':rows},ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    main()
