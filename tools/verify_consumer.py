#!/usr/bin/env python3
"""Build a public API consumer from the package archive in a clean directory."""
from pathlib import Path
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile


REPO = Path(__file__).resolve().parents[1]
MARKER = "public-collection-ok"


def verify_output(output):
    """Independent semantic oracle, rather than the writer checking itself."""
    import pydicom
    lines = output.strip().splitlines()
    if lines[-1:] != [MARKER]:
        raise AssertionError("consumer-output-contract")
    payloads = []
    for index in range(2):
        prefix = f"synthetic-output-{index}:"
        matches = [line[len(prefix):] for line in lines if line.startswith(prefix)]
        if len(matches) != 1:
            raise AssertionError("missing-or-duplicate-synthetic-output")
        payloads.append(bytes.fromhex(matches[0]))
    objects = [pydicom.dcmread(io.BytesIO(data)) for data in payloads]
    for ds in objects:
        if (str(ds.PatientID) != "P1" or str(ds.StudyDate) != "20240307"
                or ds.PixelData != bytes([1, 2, 3, 4])
                or ds.file_meta.MediaStorageSOPInstanceUID != ds.SOPInstanceUID
                or str(ds.file_meta.TransferSyntaxUID) != "1.2.840.10008.1.2.1"
                or str(ds.SOPInstanceUID).startswith("1.2.826.0.1.999")
                or any("SDKCANARY" in str(e.value) for e in ds.iterall())):
            raise AssertionError("independent-output-semantics")
    if (objects[0].SOPInstanceUID == objects[1].SOPInstanceUID
            or objects[0].StudyInstanceUID != objects[1].StudyInstanceUID
            or objects[0].SeriesInstanceUID != objects[1].SeriesInstanceUID
            or objects[1].ReferencedImageSequence[0].ReferencedSOPInstanceUID != objects[0].SOPInstanceUID
            or objects[1].ReferencedImageSequence[0].ReferencedSOPClassUID != objects[0].SOPClassUID):
        raise AssertionError("independent-collection-relations")
    reports = [json.loads(line) for line in lines if line.startswith("{")]
    if len(reports) != 1 or reports[0].get("objects") != 2 or reports[0].get("references") != 1 or reports[0].get("release_authorized") is not False:
        raise AssertionError("public-summary-contract")
    report_text = json.dumps(reports[0])
    if any(value in report_text for value in ("SDKCANARY", "987654321", "20240229", "1.2.826.0.1.999")):
        raise AssertionError("public-report-canary")
    return {"objects": 2, "references": 1, "pixel_bytes_preserved": True,
            "payload_sha256": [hashlib.sha256(data).hexdigest() for data in payloads],
            "public_report_sha256": hashlib.sha256(report_text.encode()).hexdigest()}


def moon_binary():
    configured = os.environ.get("MOON_BIN")
    if configured:
        return Path(configured).resolve(strict=True)
    found = shutil.which("moon")
    if found:
        return Path(found).resolve()
    return (REPO.parent / "moonbit工具链" / "bin" / "moon").resolve(strict=True)


def run_consumer(record_path):
    import pydicom
    moon = moon_binary()
    environment = dict(os.environ)
    environment["MOON_HOME"] = str(moon.parent.parent)
    node_dir = Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin"
    environment["PATH"] = str(moon.parent) + os.pathsep + str(node_dir) + os.pathsep + environment.get("PATH", "")
    sdk = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
    if sys.platform == "darwin" and sdk.is_dir():
        environment["SDKROOT"] = str(sdk)
    subprocess.run([str(moon), "package"], cwd=REPO, env=environment, check=True, stdout=subprocess.DEVNULL)
    archives = sorted((REPO / "_build" / "publish").glob("001-Elsa-medseal-*.zip"), key=lambda p: p.stat().st_mtime_ns)
    if not archives:
        raise AssertionError("published-archive-not-found")
    archive = archives[-1]
    consumer_files = sorted((REPO / "examples/consumer").glob("*.mbt")) + [REPO / "examples/consumer/moon.pkg"]
    pkg = (REPO / "examples/consumer/moon.pkg").read_text(encoding="utf-8")
    for line in pkg.splitlines():
        if '"001-Elsa/medseal/' in line and '"001-Elsa/medseal/api/' not in line:
            raise AssertionError("consumer-imports-internal-package")
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
        backends = {}
        for target in ("native", "js", "wasm", "wasm-gc"):
            subprocess.run([str(moon), "check", "--target", target, "--deny-warn", str(app)], cwd=root, env=environment, check=True, stdout=subprocess.DEVNULL)
            subprocess.run([str(moon), "test", "--target", target, "--deny-warn", str(app)], cwd=root, env=environment, check=True, stdout=subprocess.DEVNULL)
            output = subprocess.run([str(moon), "run", "--target", target, str(app)], cwd=root, env=environment, check=True, capture_output=True, text=True).stdout.strip()
            backends[target] = verify_output(output)
        if any(value != backends["native"] for value in backends.values()):
            raise AssertionError("consumer-cross-backend-byte-difference")
        result = {
            "schema": 1,
            "status": "passed",
            "archive": archive.name,
            "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "checks": [
                "consumer-imports-public-api-only",
                "consumer-resolved-from-published-archive-overlay",
                "clean-directory-check-test-run-four-backends",
                "original-checkout-not-on-consumer-path",
                "consumer-runs-against-archived-package",
                "independent-pydicom-output-and-reference-validation",
                "identical-output-bytes-four-backends",
                "negative-cases-and-budget-enforcement",
            ],
            "output": MARKER,
            "backends": backends,
            "oracle": {"name": "pydicom", "version": pydicom.__version__},
            "source_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
            "source_state": "local-working-tree-archive; not registry publication",
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
