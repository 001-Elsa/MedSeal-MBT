#!/usr/bin/env python3
"""Build a self-contained offline page from the actual MoonBit JS compiler."""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
from verify_consumer import REPO, moon_binary


def build(output):
    moon = moon_binary()
    env = dict(os.environ, MOON_HOME=str(moon.parent.parent))
    subprocess.run([str(moon), "build", "--target", "js", "--deny-warn", "web/core"], cwd=REPO, env=env, check=True)
    engine = (REPO / "_build/js/debug/build/web/core/core.js").read_text(encoding="utf-8")
    # The compiler emits a single named ESM export. Keep exactly that binding
    # in the inline module so opening the resulting file needs no HTTP server.
    pattern = r'export\s*\{\s*([A-Za-z0-9_$]+)\s+as\s+analyze\s*\}\s*;?'
    if len(re.findall(pattern, engine)) != 1:
        raise ValueError("unexpected-moonbit-js-export-shape")
    inline = re.sub(pattern, r'const analyze = \1;', engine)
    inline = re.sub(r'//# sourceMappingURL=.*', '', inline)
    manifest = json.loads((REPO / "conformance/manifest.json").read_text(encoding="utf-8"))
    collection = next(item for item in manifest["collections"] if item["id"] == "closed-reference")
    samples = []
    for item in collection["members"]:
        data = (REPO / "conformance" / item["file"]).read_bytes()
        if hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise ValueError("synthetic-fixture-digest-mismatch")
        samples.append(data.hex())
    sources = {str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest()
               for base in ("api", "src", "web") for p in sorted((REPO / base).rglob("*"))
               if p.is_file() and p.suffix in (".mbt", ".pkg", ".html", ".js")}
    record = {"schema": 1, "engine_sha256": hashlib.sha256(engine.encode()).hexdigest(),
              "source_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "source_files_sha256": sources, "samples": collection["members"],
              "release_authorized": False, "registry_publication": False}
    template = (REPO / "web/lab.html").read_text(encoding="utf-8")
    page = template.replace('/*ENGINE*/', inline).replace('/*SAMPLES*/',
        'const SAMPLES = ' + json.dumps(samples) + ';\nconst BUILD = ' + json.dumps({k: record[k] for k in ("engine_sha256", "source_base_commit")}) + ';')
    page = page.replace('/*UI*/', (REPO / "web/lab.js").read_text(encoding="utf-8"))
    script = re.search(r'<script type="module">([\s\S]*?)</script>', page).group(1)
    digest = base64.b64encode(hashlib.sha256(script.encode()).digest()).decode()
    csp = f"default-src 'none'; script-src 'sha256-{digest}'; style-src 'unsafe-inline'; connect-src 'none'; img-src 'none'; font-src 'none'; base-uri 'none'; form-action 'none'"
    page = page.replace('<!--CSP-->', '<meta http-equiv="Content-Security-Policy" content="' + csp + '">')
    if len(re.findall(r'</script', page, flags=re.I)) != 1 or any(t in page for t in ('/*ENGINE*/', '/*SAMPLES*/', '/*UI*/')):
        raise ValueError("unsafe-inline-bundle-or-unreplaced-placeholder")
    output.mkdir(parents=True, exist_ok=True)
    (output / "index.html").write_text(page, encoding="utf-8", newline="\n")
    (output / "engine.mjs").write_text(engine, encoding="utf-8", newline="\n")
    (output / "samples.json").write_text(json.dumps(samples), encoding="utf-8", newline="\n")
    record["html_sha256"] = hashlib.sha256((output / "index.html").read_bytes()).hexdigest()
    (output / "build.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPO / "tmp/community-lab")
    args = parser.parse_args()
    result = build(args.output.resolve())
    print(json.dumps({"status": "built", "page": str(args.output / "index.html"),
                      "html_sha256": result["html_sha256"]}, ensure_ascii=False))
