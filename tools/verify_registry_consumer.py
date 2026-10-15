#!/usr/bin/env python3
"""Install the published module in an independent project; no source fallback."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from verify_consumer import REPO, moon_binary, verify_output, MARKER
from release_readiness import module_metadata


def verify(version, record, contract="collection"):
    moon = moon_binary()
    env = dict(os.environ, MOON_HOME=str(moon.parent.parent))
    sdk = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
    if sdk.is_dir():
        env["SDKROOT"] = str(sdk)
    with tempfile.TemporaryDirectory(prefix="medseal-registry-consumer-") as temp:
        root = Path(temp)
        (root / "moon.mod").write_text('name = "medseal-test/independent-consumer"\n', encoding="utf-8")
        app = root / "app"
        if contract == "policy":
            # Explicit historical contract; never fall back after a new SDK
            # compilation failure and call that a successful collection test.
            app.mkdir()
            (app / "moon.pkg").write_text('import { "001-Elsa/medseal/api/policy", }\npkgtype(kind: "executable")\n', encoding="utf-8")
            (app / "main.mbt").write_text('///|\nfn main {\n  try {\n    ignore(@policy.strict())\n    println("public-policy-ok")\n  } catch {\n    _ => abort("policy failed")\n  }\n}\n', encoding="utf-8")
        else:
            shutil.copytree(REPO / "examples/consumer", app,
                            ignore=shutil.ignore_patterns("README.md", "*.mbti"))
        subprocess.run([str(moon), "add", "001-Elsa/medseal@" + version], cwd=root, env=env, check=True)
        installed = root / ".mooncakes/001-Elsa/medseal"
        metadata = (installed / "moon.mod").read_text(encoding="utf-8")
        if f'version = "{version}"' not in metadata:
            raise AssertionError("registry-version-mismatch")
        if installed.is_symlink() or REPO == installed.resolve() or REPO in installed.resolve().parents:
            raise AssertionError("local-source-fallback")
        subprocess.run([str(moon), "check", "--target", "native", "--deny-warn"], cwd=root, env=env, check=True)
        output = subprocess.run([str(moon), "run", "--target", "native", "app"], cwd=root, env=env,
                                check=True, capture_output=True, text=True).stdout.strip()
        if contract == "policy":
            if output != "public-policy-ok":
                raise AssertionError("legacy-policy-contract")
            semantics = {"contract": "policy-only; no conversion tested"}
        else:
            semantics = verify_output(output)
        files = [{"file": str(p.relative_to(installed)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                 for p in sorted(installed.rglob("*")) if p.is_file() and "_build" not in p.parts]
        result = {"schema": 1, "status": "passed", "module": "001-Elsa/medseal", "version": version,
                  "source": "https://mooncakes.io/docs/001-Elsa/medseal@" + version,
                  "checks": ["independent-module-moon-add", "registry-version-checked", "no-local-source-copy",
                             "public-api-check-and-run"], "downloaded_files": files,
                  "output": MARKER if contract == "collection" else "public-policy-ok",
                  "contract": contract,
                  "semantics": semantics,
                  "field_acceptance_complete": False}
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default=module_metadata()["version"])
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--contract", choices=("collection", "policy"), default="collection",
                        help="policy explicitly tests the historical <=0.2.3 API; never a conversion claim")
    args = parser.parse_args()
    result = verify(args.version, args.record, args.contract)
    print(json.dumps({k: v for k, v in result.items() if k != "downloaded_files"}))


if __name__ == "__main__":
    main()
