#!/usr/bin/env python3
"""Build a public API consumer from the package archive in a clean directory."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile


REPO = Path(__file__).resolve().parents[1]


def moon_binary():
    configured = os.environ.get("MOON_BIN")
    if configured:
        return Path(configured).resolve(strict=True)
    found = shutil.which("moon")
    if found:
        return Path(found).resolve()
    return (REPO.parent / "moonbit工具链" / "bin" / "moon").resolve(strict=True)


def run_consumer(record_path):
    moon = moon_binary()
    environment = dict(os.environ)
    environment["MOON_HOME"] = str(moon.parent.parent)
    sdk = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
    if sys.platform == "darwin" and sdk.is_dir():
        environment["SDKROOT"] = str(sdk)
    subprocess.run([str(moon), "package"], cwd=REPO, env=environment, check=True, stdout=subprocess.DEVNULL)
    archives = sorted((REPO / "_build" / "publish").glob("001-Elsa-medseal-*.zip"), key=lambda p: p.stat().st_mtime_ns)
    if not archives:
        raise AssertionError("published-archive-not-found")
    archive = archives[-1]
    consumer_files = [REPO / "examples" / "consumer" / name for name in ("moon.pkg", "main.mbt")]
    with tempfile.TemporaryDirectory(prefix="medseal-consumer-") as temp:
        root = Path(temp)
        with zipfile.ZipFile(archive) as package:
            package.extractall(root)
        # The archive is the only MedSeal source. Third-party Mooncakes are
        # copied separately so the check does not silently use the checkout.
        shutil.copytree(REPO / ".mooncakes", root / ".mooncakes")
        app = root / "external-consumer"
        app.mkdir()
        for source in consumer_files:
            shutil.copyfile(source, app / source.name)
        subprocess.run([str(moon), "check", "--target", "native", "--deny-warn", str(app)], cwd=root, env=environment, check=True)
        subprocess.run([str(moon), "build", "--target", "native", str(app)], cwd=root, env=environment, check=True, stdout=subprocess.DEVNULL)
        binaries = sorted(
            path for path in (root / "_build").glob("**/external-consumer.exe")
            if path.parent.name == "external-consumer"
        )
        if len(binaries) != 1:
            raise AssertionError("consumer-binary-not-unique")
        output = subprocess.run([str(binaries[0])], cwd=root, env=environment, check=True, capture_output=True, text=True).stdout.strip()
        if not output.startswith("public-policy-ok"):
            raise AssertionError("consumer-output-contract")
        result = {
            "schema": 1,
            "status": "passed",
            "archive": archive.name,
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "checks": [
                "consumer-imports-public-api-only",
                "consumer-resolved-from-published-archive-overlay",
                "clean-directory-check-and-build",
                "original-checkout-not-on-consumer-path",
                "consumer-runs-against-archived-package",
            ],
            "output": output,
            "release_authorized": False,
            "registry_consumer_pending": True,
        }
    Path(record_path).parent.mkdir(parents=True, exist_ok=True)
    Path(record_path).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main():
    record = Path(sys.argv[1]) if len(sys.argv) == 2 else REPO / "tmp" / "w6-consumer.json"
    print(json.dumps(run_consumer(record), ensure_ascii=False))


if __name__ == "__main__":
    main()
