#!/usr/bin/env python3
"""Bounded loopback Orthanc REST adapter for independently verified packages.

No automatic remote upload, credential handling, or de-identification bypass.
Retries reverify the full signed package before touching the receiver. Orthanc
is not an atomic batch transaction: failures explicitly remain partial.
"""
from pathlib import Path
import argparse
import json
import urllib.error
import urllib.parse
import urllib.request
from verify_delivery import verify_package, read_file


class ReceiverError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ReceiverError("redirect-refused")


class Orthanc:
    def __init__(self, base, expected_version):
        parsed = urllib.parse.urlsplit(base)
        if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
                or not parsed.port or parsed.username or parsed.password
                or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
            raise ReceiverError("loopback-http-origin-required")
        if not expected_version or len(expected_version) > 32:
            raise ReceiverError("fixed-version-required")
        self.base = base.rstrip("/")
        self.version = expected_version
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, method, path, body=None, limit=4 * 1024 * 1024):
        if not path.startswith("/") or ".." in path:
            raise ReceiverError("invalid-route")
        req = urllib.request.Request(self.base + path, data=body, method=method,
                                     headers={"Content-Type": "application/dicom"})
        try:
            with self.opener.open(req, timeout=10) as response:
                data = response.read(limit + 1)
                if len(data) > limit:
                    raise ReceiverError("response-budget")
                return data
        except ReceiverError:
            raise
        except urllib.error.HTTPError:
            raise ReceiverError("receiver-rejected") from None
        except (OSError, urllib.error.URLError):
            raise ReceiverError("transport-retryable") from None

    def json(self, method, path, body=None):
        try:
            return json.loads(self.request(method, path, body))
        except (ValueError, UnicodeError):
            raise ReceiverError("invalid-receiver-response") from None

    def check(self):
        system = self.json("GET", "/system")
        if system.get("Version") != self.version:
            raise ReceiverError("receiver-version-mismatch")
        return system

    def upload(self, data):
        result = self.json("POST", "/instances", data)
        identity = result.get("ID", "")
        if (result.get("Status") not in {"Success", "AlreadyStored"}
                or len(identity) != 44 or any(c not in "0123456789abcdef-" for c in identity)):
            raise ReceiverError("upload-not-acknowledged")
        return identity, result["Status"]

    def file(self, identity):
        if len(identity) != 44 or any(c not in "0123456789abcdef-" for c in identity):
            raise ReceiverError("invalid-instance-id")
        return self.request("GET", "/instances/" + identity + "/file", limit=256 * 1024 * 1024)


def deliver(package, trust, base, expected_version, allow_synthetic=False):
    checked = verify_package(package, trust, allow_synthetic)
    if checked["objects"] > 256:
        raise ReceiverError("receiver-object-budget")
    root = Path(package).resolve(strict=True)
    release = json.loads(read_file(root / "release.json", 4 * 1024 * 1024, True))
    objects = sorted((item for item in release["files"] if item["file"].endswith(".dcm")), key=lambda item: item["file"])
    # Validate bounds before uploading anything. Read_file is stable/no-follow;
    # each object's signed digest is checked again immediately before upload.
    sizes = [(root / item["file"]).stat().st_size for item in objects]
    if any(size > 64 * 1024 * 1024 for size in sizes) or sum(sizes) > 128 * 1024 * 1024:
        raise ReceiverError("receiver-byte-budget")
    receiver = Orthanc(base, expected_version)
    receiver.check()
    completed = 0
    duplicates = 0
    import hashlib
    for item in objects:
        data = read_file(root / item["file"], 64 * 1024 * 1024, True)
        if hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise ReceiverError("package-changed")
        try:
            identity, status = receiver.upload(data)
            # Orthanc can regenerate File Meta; compare Dataset semantics at the
            # independent receiver acceptance, not a promise of byte identity.
            if not receiver.file(identity):
                raise ReceiverError("empty-retrieval")
        except ReceiverError as error:
            return {"schema": 1, "status": "partial-retry-required", "objects": len(objects),
                    "completed": completed, "code": str(error), "release_authorized": False,
                    "atomic_batch": False}
        completed += 1
        duplicates += status == "AlreadyStored"
    verify_package(root, trust, allow_synthetic)
    return {"schema": 1, "status": "receiver-stored", "objects": completed, "already_stored": duplicates,
            "atomic_batch": False, "semantic_acceptance": "independent-reader-required",
            "release_authorized": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--trust", type=Path, required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--allow-synthetic", action="store_true")
    args = parser.parse_args()
    try:
        result = deliver(args.package, args.trust, args.base, args.version, args.allow_synthetic)
    except Exception:
        result = {"schema": 1, "status": "blocked", "code": "package-or-receiver-check", "release_authorized": False}
    print(json.dumps(result))
    raise SystemExit(0 if result["status"] == "receiver-stored" else 1)
