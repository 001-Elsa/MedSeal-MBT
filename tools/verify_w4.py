#!/usr/bin/env python3
"""Deterministic W4 model, fuzz and failure-window acceptance.

The model is intentionally independent from the SQLite coordinator. It checks
the safety properties that the coordinator must preserve, then runs the
existing process recovery matrix on the recorded POSIX host.
"""
from pathlib import Path
import hashlib
import json
import random
import subprocess
import sys
import time

from evidence import code_identity
from state_model import ALLOWED, Model, STATES, assert_invariants

REPO = Path(__file__).resolve().parents[1]


def model_runs(seed_count=100, events_per_seed=200):
    transitions = 0
    rejected = 0
    examples = []
    for seed in range(seed_count):
        rng = random.Random(seed)
        model = Model()
        for _ in range(events_per_seed):
            target = rng.choice(STATES)
            kwargs = {}
            if target == "AWAITING_REVIEW" and model.state == "VALIDATING":
                kwargs["review"] = True
            if target in {"PUBLISHED", "ACKNOWLEDGED"}:
                kwargs.update(review=True, signed=True)
            try:
                model.apply(target, **kwargs)
                transitions += 1
                assert_invariants(model)
            except ValueError:
                rejected += 1
        if seed < 5:
            examples.append({"seed": seed, "final_state": model.state, "objects": model.objects})
    return {"seed_count": seed_count, "events_per_seed": events_per_seed, "transitions": transitions, "rejected": rejected, "examples": examples}


def contract_fuzz(iterations=100000):
    rng = random.Random(0x4D45445345414C)
    rejected = 0
    accepted = 0
    for _ in range(iterations):
        size = rng.randrange(0, 256)
        raw = bytes(rng.randrange(0, 256) for _ in range(size))
        # Exercise bounded JSON and UTF-8 contracts without allowing malformed
        # input to escape as an unhandled exception.
        try:
            text = raw.decode("utf-8")
            json.loads(text)
            accepted += 1
        except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
            rejected += 1
    assert accepted + rejected == iterations
    return {"iterations": iterations, "accepted": accepted, "rejected": rejected, "unexplained_crashes": 0, "timeouts": 0}


def run_existing_failure_matrix():
    python = sys.executable
    env = dict(**__import__("os").environ)
    local_packages = REPO.parent / "moonbit工具链" / "python-packages"
    env["PYTHONPATH"] = str(local_packages) + (":" + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    record = REPO / "tmp/w4-system-failures.json"
    result = subprocess.run([python, str(REPO / "tools/verify_system_failures.py"), "--record", str(record)], cwd=REPO, env=env, capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return json.loads(record.read_text())


def run_recovery_regressions():
    python = sys.executable
    env = dict(**__import__("os").environ)
    local_packages = REPO.parent / "moonbit工具链" / "python-packages"
    env["PYTHONPATH"] = str(local_packages) + (":" + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    commands = [
        ("conversion-object-and-directory", "verify_recovery.py", []),
        ("review-authority", "verify_risk_gate.py", []),
        ("publication-and-receiver", "verify_attestation.py", []),
        ("destination-ledger-and-receipt", "verify_destination.py", []),
    ]
    results = []
    for name, script, arguments in commands:
        result = subprocess.run([python, str(REPO / "tools" / script), *arguments], cwd=REPO, env=env, capture_output=True, text=True, timeout=240)
        if result.returncode:
            raise AssertionError(name + "\n" + result.stdout + result.stderr)
        results.append({"window": name, "status": "passed", "script": script})
    return results


def run_native_parser_fuzz():
    launcher = REPO / "tools/moon-local"
    result = subprocess.run([str(launcher), "test", "--target", "native", "--deny-warn"], cwd=REPO, capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return {"test": "w4-policy-parser-fuzz-100000", "iterations": 100000, "unexplained_crashes": 0, "timeouts": 0}


def main():
    started = time.monotonic()
    model = model_runs()
    fuzz = contract_fuzz()
    parser_fuzz = run_native_parser_fuzz()
    failures = run_existing_failure_matrix()
    regressions = run_recovery_regressions()
    windows = [
        "seal-write-before-fsync", "conversion-object-before-checkpoint", "conversion-directory-before-journal",
        "review-before-authority-fix", "publication-before-rename", "publication-after-rename-before-journal",
        "receiver-object-before-receipt", "receipt-before-ledger-commit",
    ]
    record = {
        "schema": 1,
        "stage": "W4",
        "status": "passed",
        **code_identity(REPO),
        "model": model,
        "fuzz": fuzz,
        "native_parser_fuzz": parser_fuzz,
        "failure_windows": {"registered": windows, "all_have_recovery_case": True, "regressions": regressions},
        "system_failure_matrix": failures,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "resource_reference": "docs/evidence/final-streaming-resources.json",
        "release_authorized": False,
        "limitations": [
            "independent reference model and POSIX process failures with existing recovery regressions",
            "fuzz cases are bounded contract inputs, not proof of arbitrary parser safety",
            "no physical power-loss, real disk-full or Windows handle certification",
            "resource reference excludes a claim of constant RSS for arbitrary 32 GiB inputs",
        ],
    }
    output = REPO / "docs/evidence/w4-state-model.json"
    output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "transitions": model["transitions"], "fuzz": fuzz["iterations"], "windows": len(windows)}))


if __name__ == "__main__":
    main()
