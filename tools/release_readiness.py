#!/usr/bin/env python3
"""Create an auditable 0.2.0 release-readiness record.

This tool deliberately separates a locally verified archive from publication on
Mooncakes or a mirror.  Platform observations are supplied as small JSON files
captured by a human from the respective service; the tool never turns a local
build into a claim that a remote release exists.
"""

from pathlib import Path
import argparse
import hashlib
import json
import re
import stat
import subprocess
import sys
import zipfile


REPO = Path(__file__).resolve().parents[1]
MODULE_RE = re.compile(r"^name\s*=\s*\"([^\"]+)\"\s*$", re.MULTILINE)
VERSION_RE = re.compile(r"^version\s*=\s*\"([^\"]+)\"\s*$", re.MULTILINE)
IMPORT_RE = re.compile(r'^\s*"([^"\s]+@[^"\s]+)"\s*,?\s*(?://.*)?$')
EXPECTED_ARCHIVE_PREFIX = "001-Elsa-medseal-"
PRIVATE_PARTS = {".git", ".mooncakes", "tmp", "_build", "private", "secrets"}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def git(*args):
    return subprocess.run(
        ["git"] + list(args), cwd=REPO, check=True, capture_output=True, text=True
    ).stdout.strip()


def module_metadata(text=None):
    if text is None:
        text = (REPO / "moon.mod").read_text(encoding="utf-8")
    name = MODULE_RE.search(text)
    version = VERSION_RE.search(text)
    if not name or not version:
        raise ValueError("moon-mod-name-and-version-required")
    imports = []
    in_imports = False
    found_imports = False
    for line in text.splitlines():
        if line.strip() == "import {":
            if found_imports:
                raise ValueError("duplicate-import-block")
            found_imports = True
            in_imports = True
            continue
        if in_imports and line.strip() == "}":
            in_imports = False
            continue
        if in_imports:
            if not line.strip() or line.lstrip().startswith("//"):
                continue
            match = IMPORT_RE.match(line)
            if not match:
                raise ValueError("malformed-pinned-import:" + line.strip())
            if match.group(1) in imports:
                raise ValueError("duplicate-import")
            imports.append(match.group(1))
    if not found_imports or in_imports or not imports:
        raise ValueError("complete-nonempty-import-block-required")
    return {"name": name.group(1), "version": version.group(1), "dependencies": imports}


def archive_inventory(archive):
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        if len(names) != len(set(names)):
            raise ValueError("archive-contains-duplicate-paths")
        files = []
        for name in names:
            path = Path(name)
            if stat.S_ISLNK(package.getinfo(name).external_attr >> 16):
                raise ValueError("archive-contains-symlink:" + name)
            if name.endswith("/"):
                continue
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("archive-path-escape:" + name)
            if any(part in PRIVATE_PARTS for part in path.parts):
                raise ValueError("archive-contains-private-path:" + name)
            content = package.read(name)
            files.append({"file": name, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()})
        required = {"moon.mod", "README.mbt.md", "LICENSE", "THIRD_PARTY.md"}
        missing = sorted(required - {item["file"] for item in files})
        if missing:
            raise ValueError("archive-missing-required-files:" + ",".join(missing))
        return {"files": files, "file_count": len(files), "moon_mod": package.read("moon.mod").decode("utf-8")}


def verify_source_members(inventory):
    tracked = set(git("ls-files").splitlines())
    for item in inventory["files"]:
        name = item["file"]
        if name not in tracked:
            raise ValueError("archive-member-not-tracked:" + name)
        committed = subprocess.run(["git", "show", "HEAD:" + name], cwd=REPO,
                                   check=True, capture_output=True).stdout
        if hashlib.sha256(committed).hexdigest() != item["sha256"]:
            raise ValueError("archive-member-differs-from-source-commit:" + name)


def read_observation(path, platform, candidate_version):
    if path is None:
        return {"platform": platform, "status": "pending-human-observation"}
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if value.get("platform") != platform:
        raise ValueError("observation-platform-mismatch:" + platform)
    if not value.get("source"):
        raise ValueError("observation-source-required:" + platform)
    observed = value.get("observed_version")
    candidate_visible = observed == candidate_version and value.get("status") == "published"
    value["candidate_version"] = candidate_version
    value["candidate_visible"] = candidate_visible
    if not candidate_visible:
        value["status"] = value.get("status", "pending-human-observation")
    return value


def build_record(archive, mooncakes_observation=None, gitlink_observation=None, ci_urls=None):
    archive = Path(archive).resolve(strict=True)
    metadata = module_metadata()
    expected_name = EXPECTED_ARCHIVE_PREFIX + metadata["version"] + ".zip"
    if archive.name != expected_name:
        raise ValueError("archive-version-name-mismatch:" + expected_name)
    inventory = archive_inventory(archive)
    archived_mod = VERSION_RE.search(inventory["moon_mod"])
    if not archived_mod or archived_mod.group(1) != metadata["version"]:
        raise ValueError("archive-moon-mod-version-mismatch")
    archived_name = MODULE_RE.search(inventory["moon_mod"])
    if not archived_name or archived_name.group(1) != metadata["name"]:
        raise ValueError("archive-moon-mod-name-mismatch")
    if module_metadata(inventory["moon_mod"]) != metadata:
        raise ValueError("archive-dependency-metadata-mismatch")
    status = git("status", "--porcelain")
    if status:
        raise ValueError("tracked-worktree-must-be-clean-before-release-readiness")
    verify_source_members(inventory)
    record = {
        "schema": 1,
        "stage": "W6-release-readiness",
        "status": "candidate-ready-for-platform-publish",
        "release_status": "engineering-preview",
        "repository": git("remote", "get-url", "origin"),
        "source_commit": git("rev-parse", "HEAD"),
        "module": metadata,
        "archive": {
            "file": archive.name,
            "bytes": archive.stat().st_size,
            "sha256": sha256(archive),
            "file_count": inventory["file_count"],
            "content_manifest": inventory["files"],
        },
        "ci_urls": ci_urls or [],
        "platforms": {
            "mooncakes": read_observation(mooncakes_observation, "mooncakes", metadata["version"]),
            "gitlink": read_observation(gitlink_observation, "gitlink", metadata["version"]),
        },
        "checks": [
            "clean-tracked-worktree",
            "archive-name-binds-module-version",
            "archive-moon-mod-binds-module-name-and-version",
            "archive-paths-have-no-traversal-or-private-store",
            "archive-contains-required-public-metadata",
            "archive-and-member-sha256-recorded",
            "every-archive-member-matches-source-commit",
            "ci-identifiers-recorded-separately-from-platform-publication",
        ],
        "publication_authorized": False,
        "field_acceptance_complete": False,
    }
    if any(item.get("candidate_visible") for item in record["platforms"].values()):
        record["status"] = "candidate-partially-visible-review-required"
    if all(item.get("candidate_visible") for item in record["platforms"].values()):
        record["status"] = "candidate-visible-on-platforms-review-required"
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--mooncakes-observation", type=Path)
    parser.add_argument("--gitlink-observation", type=Path)
    parser.add_argument("--ci-url", action="append", default=[])
    args = parser.parse_args()
    record = build_record(args.archive, args.mooncakes_observation, args.gitlink_observation, args.ci_url)
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": record["status"], "archive_sha256": record["archive"]["sha256"], "platforms": record["platforms"]}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError, zipfile.BadZipFile) as error:
        print("release-readiness-error: " + str(error), file=sys.stderr)
        raise SystemExit(2)
