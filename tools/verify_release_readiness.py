#!/usr/bin/env python3
"""Regression for pinned import inventory and fail-closed source archives."""
from pathlib import Path
import tempfile
import stat
import zipfile
from release_readiness import module_metadata, archive_inventory, verify_source_members, REPO


def rejects(action):
    try:
        action()
    except ValueError:
        return
    raise AssertionError("invalid-release-metadata-accepted")


def main():
    prefix = 'name = "test/module"\nversion = "1.0.0"\n'
    expected = ["moonbitlang/async@0.22.4", "moonbitlang/x@0.5.5", "gmlewis/sha256@0.18.0"]
    assert module_metadata()["dependencies"] == expected
    for punctuation in (",", ""):
        assert module_metadata(prefix + 'import {\n  "a/b@1.0.0"' + punctuation + '\n}\n')["dependencies"] == ["a/b@1.0.0"]
    for suffix in ('', 'import {\n}\n', 'import {\n"a/b@1.0.0",\n',
                   'import {\n"a/b",\n}\n', 'import {\nINVALID\n}\n',
                   'import {\n"a/b@1.0.0",\n"a/b@1.0.0",\n}\n'):
        rejects(lambda: module_metadata(prefix + suffix))
    with tempfile.TemporaryDirectory(prefix="medseal-release-regression-") as temp:
        archive = Path(temp) / "001-Elsa-medseal-0.2.0.zip"
        for bad in ("../escape", "private/key", "_build/output"):
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr(bad, "bad")
            rejects(lambda: archive_inventory(archive))
        with zipfile.ZipFile(archive, "w") as package:
            link = zipfile.ZipInfo("link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            package.writestr(link, "../private")
        rejects(lambda: archive_inventory(archive))
        # Same name/version does not establish provenance. This source substitution
        # must fail even when the checkout is clean and metadata matches.
        with zipfile.ZipFile(archive, "w") as package:
            for name in ("moon.mod", "README.mbt.md", "LICENSE", "THIRD_PARTY.md"):
                package.write(REPO / name, name)
            package.writestr("src/parser/parser.mbt", "substituted source")
        rejects(lambda: verify_source_members(archive_inventory(archive)))
        # Direct provenance checks also run in a dirty development checkout.
        rejects(lambda: verify_source_members({"files": [{"file": "moon.mod", "sha256": "0" * 64}]}))
        rejects(lambda: verify_source_members({"files": [{"file": "untracked.mbt", "sha256": "0" * 64}]}))
    print("release-metadata-regression: passed")


if __name__ == "__main__":
    main()
