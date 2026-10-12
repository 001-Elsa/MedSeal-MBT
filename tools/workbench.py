#!/usr/bin/env python3
"""Loopback-only MedSeal operator workbench.

The workbench is a thin, read-mostly host adapter.  It never implements DICOM
conversion or release authorization; those remain in the CLI and the existing
review/signing gates.  Every request is bound to a canonical workspace, an
exact loopback Host/Origin pair and a short-lived capability kept in a 0600
file.  Paths and private values are deliberately absent from API responses.
"""
from __future__ import annotations

import argparse
import hmac
import http.server
import json
import os
import re
import secrets
import sqlite3
import sys
import threading
import urllib.parse
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


JOB_ID = re.compile(r"^[0-9a-f]{32}$")
MAX_BODY = 64 * 1024
MAX_LIMIT = 100


def canonical_root(value: Path) -> Path:
    root = value.absolute()
    if root.is_symlink() or not root.is_dir():
        raise ValueError("workspace-must-be-a-canonical-directory")
    # Parent directories such as /var may themselves be platform symlinks;
    # canonicalize them while rejecting a symlink at the workspace boundary.
    return root.resolve(strict=True)


def safe_job_id(value: str) -> str:
    if not JOB_ID.fullmatch(value):
        raise ValueError("invalid-job-id")
    return value


def safe_child(root: Path, job_id: str) -> Path:
    job_id = safe_job_id(job_id)
    job = root / job_id
    if job.is_symlink() or not job.is_dir() or job.resolve() != job:
        raise ValueError("job-not-found")
    owner = job / "owner"
    if owner.is_symlink() or not owner.is_file():
        raise ValueError("job-not-found")
    try:
        owner_value = owner.read_bytes()
    except OSError:
        raise ValueError("job-not-found")
    if owner_value != job_id.encode("ascii"):
        raise ValueError("job-not-found")
    return job


def read_state(job: Path) -> Tuple[str, int]:
    db_path = job / "job.sqlite"
    if db_path.is_symlink() or not db_path.is_file():
        return "UNKNOWN", 0
    db = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True)
    try:
        state = db.execute("SELECT state FROM current WHERE id=1").fetchone()
        events = db.execute("SELECT count(*) FROM events").fetchone()
        return (state[0] if state else "UNKNOWN", int(events[0] if events else 0))
    except sqlite3.Error:
        return "UNKNOWN", 0
    finally:
        db.close()


def object_page(job: Path, offset: int, limit: int) -> Dict[str, Any]:
    folder = job / "sealed"
    if folder.is_symlink() or not folder.is_dir():
        folder = job / "converted"
    names = []
    if folder.is_dir() and not folder.is_symlink():
        for item in sorted(folder.iterdir(), key=lambda p: p.name):
            if item.is_file() and re.fullmatch(r"(?:input-[0-9]{5,6}|object-[1-9][0-9]*)\.dcm", item.name):
                names.append(item.name)
    page = names[offset : offset + limit]
    state, _ = read_state(job)
    return {
        "schema": 1,
        "offset": offset,
        "limit": limit,
        "total": len(names),
        "items": [
            {"object_id": name.rsplit(".", 1)[0], "status": state.lower(), "pixels_inspected": False}
            for name in page
        ],
    }


def public_job(root: Path, job: Path) -> Dict[str, Any]:
    state, events = read_state(job)
    count = 0
    sealed = job / "sealed"
    if sealed.is_dir() and not sealed.is_symlink():
        count = sum(1 for item in sealed.iterdir() if item.is_file() and item.name.endswith(".dcm"))
    return {
        "schema": 1,
        "job_id": job.name,
        "state": state,
        "events": events,
        "objects": count,
        "release_check": "verify-signed-package-required",
        "actions": ["cancel"] if state in {"INGESTED", "PLANNED", "RUNNING", "VALIDATING", "AWAITING_REVIEW"} else [],
    }


def public_report(root: Path, job: Path) -> Dict[str, Any]:
    state, events = read_state(job)
    manifest = job / "converted" / "manifest.json"
    object_count = 0
    policy_sha256 = None
    if manifest.is_file() and not manifest.is_symlink():
        try:
            data = json.loads(manifest.read_bytes())
            objects = data.get("objects", [])
            if isinstance(objects, list):
                object_count = len(objects)
            if isinstance(data.get("policy_sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", data["policy_sha256"]):
                policy_sha256 = data["policy_sha256"]
        except (OSError, ValueError, TypeError):
            pass
    result: Dict[str, Any] = {
        "schema": 1,
        "status": "workbench-summary",
        "release_authorized": False,
        "job_id": job.name,
        "state": state,
        "events": events,
        "objects": object_count,
        "pixels_inspected": False,
        "next_step": "independent-review-required" if state == "AWAITING_REVIEW" else "follow-state-machine",
    }
    if policy_sha256 is not None:
        result["policy_sha256"] = policy_sha256
    return result


UI = """<!doctype html><html lang='zh-CN'><meta charset='utf-8'>
<meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'\">
<title>MedSeal 本地工作台</title><style>body{font:16px system-ui;margin:2rem;max-width:1100px}button{margin:.2rem;padding:.4rem .7rem}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:.4rem;text-align:left}.muted{color:#666}</style>
<h1>MedSeal 本地工作台</h1><p class='muted'>仅限本机受控工作区；像素未自动放行，发布仍需独立审核与签名。</p>
<label>本机会话 capability：<input id='session' type='password' size='52' autocomplete='off'></label>
<button id='reload'>刷新</button><span id='msg'></span><table><thead><tr><th>作业</th><th>状态</th><th>对象</th><th>事件</th><th>操作</th></tr></thead><tbody id='rows'></tbody></table>
<script>
const out=(x)=>document.getElementById('msg').textContent=x;
async function api(path,opts={}){const token=document.getElementById('session').value;opts.headers={...(opts.headers||{}),'X-MedSeal-Session':token};if(opts.method==='POST')opts.headers['X-MedSeal-CSRF']=token;const r=await fetch(path,opts);const x=await r.json();if(!r.ok)throw Error(x.code||'request-failed');return x;}
async function load(){try{const x=await api('/api/v1/jobs?offset=0&limit=100');const rows=document.getElementById('rows');rows.textContent='';for(const j of x.items){const tr=document.createElement('tr');for(const v of [j.job_id,j.state,j.objects,j.events]){const td=document.createElement('td');td.textContent=v;tr.append(td)}const td=document.createElement('td');if(j.actions.includes('cancel')){const b=document.createElement('button');b.textContent='请求取消';b.onclick=()=>cancel(j.job_id);td.append(b)}const b=document.createElement('button');b.textContent='查看报告';b.onclick=()=>report(j.job_id);td.append(b);tr.append(td);rows.append(tr)}out(' 已加载 '+x.total+' 个作业')}catch(e){out(' 加载失败：'+e.message)}}
async function cancel(id){try{await api('/api/v1/jobs/'+id+'/cancel',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});await load()}catch(e){out(' 操作失败：'+e.message)}}
async function report(id){try{const x=await api('/api/v1/jobs/'+id+'/report');out(' '+JSON.stringify(x))}catch(e){out(' 报告失败：'+e.message)}}
document.getElementById('reload').onclick=load;load();
</script></html>"""


class WorkbenchServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address: Tuple[str, int], root: Path, capability: bytes):
        self.root = root
        self.capability = capability
        super().__init__(address, WorkbenchHandler)


class WorkbenchHandler(http.server.BaseHTTPRequestHandler):
    server: WorkbenchServer

    def log_message(self, fmt: str, *args: Any) -> None:
        # Request headers can contain the capability; never write access logs.
        return

    def send_json(self, status: int, value: Dict[str, Any]) -> None:
        body = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self) -> None:
        body = UI.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def auth(self, mutate: bool = False) -> bool:
        host = self.headers.get("Host", "")
        expected = "127.0.0.1:%d" % self.server.server_port
        if host not in {expected, "localhost:%d" % self.server.server_port}:
            self.send_json(421, {"schema": 1, "status": "rejected", "code": "host-not-allowed"})
            return False
        origin = self.headers.get("Origin")
        if origin is not None and origin not in {"http://127.0.0.1:%d" % self.server.server_port, "http://localhost:%d" % self.server.server_port}:
            self.send_json(403, {"schema": 1, "status": "rejected", "code": "origin-not-allowed"})
            return False
        presented = self.headers.get("X-MedSeal-Session", "").encode("ascii", "ignore")
        if not hmac.compare_digest(presented, self.server.capability):
            self.send_json(401, {"schema": 1, "status": "rejected", "code": "session-required"})
            return False
        if mutate and not hmac.compare_digest(self.headers.get("X-MedSeal-CSRF", "").encode("ascii", "ignore"), self.server.capability):
            self.send_json(403, {"schema": 1, "status": "rejected", "code": "csrf-required"})
            return False
        return True

    def path_parts(self) -> List[str]:
        parsed = urllib.parse.urlsplit(self.path)
        return [part for part in parsed.path.split("/") if part]

    def query_page(self) -> Tuple[int, int]:
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query, strict_parsing=False)
        try:
            offset = int(query.get("offset", ["0"])[0])
            limit = int(query.get("limit", ["50"])[0])
        except ValueError:
            raise ValueError("invalid-pagination")
        if offset < 0 or offset > 1000000 or limit < 1 or limit > MAX_LIMIT:
            raise ValueError("invalid-pagination")
        return offset, limit

    def do_GET(self) -> None:
        if self.path.split("?", 1)[0] == "/":
            # The shell contains no private data. API calls from it remain
            # capability-protected, so opening the page does not disclose the
            # workspace or create a session.
            self.send_html()
            return
        if not self.auth():
            return
        parts = self.path_parts()
        try:
            if parts == ["api", "v1", "session"]:
                self.send_json(200, {"schema": 1, "status": "ready", "scope": "loopback-workspace", "release_authorized": False})
            elif parts == ["api", "v1", "jobs"]:
                offset, limit = self.query_page()
                jobs = [item for item in self.server.root.iterdir() if item.is_dir() and not item.is_symlink() and JOB_ID.fullmatch(item.name)]
                jobs.sort(key=lambda p: p.name)
                page = jobs[offset : offset + limit]
                self.send_json(200, {"schema": 1, "offset": offset, "limit": limit, "total": len(jobs), "items": [public_job(self.server.root, item) for item in page]})
            elif len(parts) == 5 and parts[:3] == ["api", "v1", "jobs"] and parts[4] in {"report", "objects"}:
                job = safe_child(self.server.root, parts[3])
                if parts[4] == "report":
                    self.send_json(200, public_report(self.server.root, job))
                else:
                    offset, limit = self.query_page()
                    self.send_json(200, object_page(job, offset, limit))
            elif len(parts) == 4 and parts[:3] == ["api", "v1", "jobs"]:
                self.send_json(200, public_job(self.server.root, safe_child(self.server.root, parts[3])))
            else:
                self.send_json(404, {"schema": 1, "status": "rejected", "code": "not-found"})
        except (ValueError, OSError, sqlite3.Error):
            self.send_json(400, {"schema": 1, "status": "rejected", "code": "invalid-workbench-request"})

    def read_json(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", "-1"))
        if length < 0 or length > MAX_BODY:
            raise ValueError("body-budget")
        body = self.rfile.read(length)
        if body:
            value = json.loads(body.decode("utf-8"))
            if not isinstance(value, dict):
                raise ValueError("object-required")
            return value
        return {}

    def do_POST(self) -> None:
        if not self.auth(mutate=True):
            return
        parts = self.path_parts()
        try:
            if len(parts) == 5 and parts[:3] == ["api", "v1", "jobs"] and parts[4] == "cancel":
                self.read_json()
                safe_child(self.server.root, parts[3])
                from enterprise_job import cancel_job
                result = cancel_job(self.server.root, parts[3])
                self.send_json(200, result)
            else:
                self.send_json(404, {"schema": 1, "status": "rejected", "code": "not-found"})
        except Exception:
            self.send_json(400, {"schema": 1, "status": "rejected", "code": "operation-rejected"})


def capability_file(path: Path) -> bytes:
    path = path.absolute()
    if path.exists():
        if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
            raise ValueError("unsafe-capability-file")
        value = path.read_bytes()
        if len(value) != 64 or not re.fullmatch(rb"[0-9a-f]{64}", value):
            raise ValueError("invalid-capability-file")
        return value
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    value = secrets.token_hex(32).encode("ascii")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(path, flags, 0o600)
    try:
        os.write(fd, value)
    finally:
        os.close(fd)
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="serve the local MedSeal operator workbench")
    parser.add_argument("serve", nargs="?", default="serve", choices=["serve"])
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--capability-file", type=Path, required=True)
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args()
    try:
        root = canonical_root(args.root)
        capability = capability_file(args.capability_file)
        server = WorkbenchServer(("127.0.0.1", args.port), root, capability)
        print(json.dumps({"schema": 1, "status": "ready", "host": "127.0.0.1", "port": server.server_port, "capability_file": str(args.capability_file.absolute()), "session_header": "X-MedSeal-Session", "release_authorized": False}), flush=True)
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    except Exception as error:
        print(json.dumps({"schema": 1, "status": "failed", "code": str(error)}), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
