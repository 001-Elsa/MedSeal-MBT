#!/usr/bin/env python3
"""Acceptance checks for the loopback workbench security and operator contract."""
import http.client
import json
import os
import secrets
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def request(port, headers, path, method="GET", body=None):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    conn.request(method, path, body=body, headers=headers)
    response = conn.getresponse()
    raw = response.read()
    conn.close()
    return response.status, raw


def make_job(root, job_id, state="INGESTED", objects=3):
    job = root / job_id
    job.mkdir(mode=0o700)
    (job / "owner").write_text(job_id, encoding="ascii")
    (job / "owner").chmod(0o600)
    (job / "sealed").mkdir(mode=0o700)
    for index in range(1, objects + 1):
        (job / "sealed" / ("input-%05d.dcm" % index)).write_bytes(b"synthetic")
    db = sqlite3.connect(job / "job.sqlite")
    db.executescript("CREATE TABLE current(id INTEGER PRIMARY KEY,state TEXT NOT NULL); CREATE TABLE events(sequence INTEGER PRIMARY KEY,state TEXT NOT NULL,code TEXT NOT NULL,time_ns INTEGER NOT NULL);")
    db.execute("INSERT INTO current VALUES(1,?)", (state,))
    db.execute("INSERT INTO events VALUES(1,?,?,?)", (state, "synthetic", time.time_ns()))
    db.commit()
    db.close()
    (job / "job.sqlite").chmod(0o600)


def main():
    with tempfile.TemporaryDirectory(prefix="medseal-workbench-") as directory:
        root = Path(directory) / "workspace"
        root.mkdir(mode=0o700)
        job_id = "0123456789abcdef0123456789abcdef"
        make_job(root, job_id)
        capability_file = Path(directory) / "session"
        process = subprocess.Popen([sys.executable, str(REPO / "tools/workbench.py"), "--root", str(root), "--capability-file", str(capability_file), "--port", "0"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            line = process.stdout.readline().strip()
            boot = json.loads(line)
            port = boot["port"]
            token = capability_file.read_bytes().decode("ascii", "strict")
            if len(token) != 64:
                raise AssertionError("capability file must be textual")
            headers = {"X-MedSeal-Session": token, "Host": "127.0.0.1:%d" % port}
            status, raw = request(port, {}, "/api/v1/session")
            assert status == 401 and json.loads(raw)["code"] == "session-required"
            status, raw = request(port, {**headers, "Origin": "https://evil.example"}, "/api/v1/session")
            assert status == 403 and json.loads(raw)["code"] == "origin-not-allowed"
            status, raw = request(port, headers, "/api/v1/jobs?offset=0&limit=1")
            data = json.loads(raw)
            assert status == 200 and data["total"] == 1 and len(data["items"]) == 1
            assert "workspace" not in raw.decode() and "sealed" not in raw.decode()
            status, raw = request(port, headers, "/api/v1/jobs/%s/objects?offset=0&limit=2" % job_id)
            data = json.loads(raw)
            assert status == 200 and data["total"] == 3 and len(data["items"]) == 2
            status, raw = request(port, headers, "/api/v1/jobs/%s/report" % job_id)
            report = json.loads(raw)
            assert status == 200 and report["release_authorized"] is False and report["pixels_inspected"] is False
            status, raw = request(port, {**headers, "X-MedSeal-CSRF": "bad"}, "/api/v1/jobs/%s/cancel" % job_id, "POST", b"{}")
            assert status == 403 and json.loads(raw)["code"] == "csrf-required"
            status, raw = request(port, {**headers, "X-MedSeal-CSRF": token, "Content-Type": "application/json"}, "/api/v1/jobs/%s/cancel" % job_id, "POST", b"{}")
            assert status == 200 and json.loads(raw)["status"] == "cancellation-requested"
            status, raw = request(port, headers, "/api/v1/jobs/../report")
            assert status in {400, 404}
            print(json.dumps({"status": "passed", "checks": 8, "scope": "loopback-host-origin-session-csrf-pagination-allowlist-cancel"}))
        finally:
            process.terminate()
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
