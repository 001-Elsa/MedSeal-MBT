#!/usr/bin/env python3
"""Real POSIX process/path failures using synthetic files only."""
from pathlib import Path
import argparse
import json
import os
import signal
import subprocess
import tempfile
import time
from verify_with_pydicom import REPO, generate


def run(binary, *args, **kwargs):
    return subprocess.run([str(binary), *map(str, args)], cwd=REPO, capture_output=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, default=REPO / "_build/native/debug/build/cmd/main/main.exe")
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    if os.name != "posix":
        parser.error("This system-failure matrix is POSIX-only")
    import resource
    results = []
    (REPO / "tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="system-failures-", dir=REPO / "tmp") as temporary:
        root = Path(temporary)
        source = root / "input"
        generate(source, 1000)

        # Actual two-process destination race, not a pre-existing target test.
        output = root / "race"
        processes = [subprocess.Popen([str(args.binary), "batch", str(source), "--output", str(output)],
                     cwd=REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for _ in range(2)]
        codes = [p.wait(timeout=60) for p in processes]
        assert codes.count(0) == 1 and codes.count(0) + sum(c != 0 for c in codes) == 2
        assert run(args.binary, "verify", output).returncode == 0
        assert not list(root.glob("race.medseal-*"))
        results.append({"scenario": "same-target-two-processes", "result": "pass", "exit_codes": codes})

        # SIGKILL after staging has started. Leftovers are private and unpublished.
        output = root / "killed"
        process = subprocess.Popen([str(args.binary), "batch", str(source), "--output", str(output)],
                                   cwd=REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 30
            stage = None
            while time.monotonic() < deadline:
                stages = list(root.glob("killed.medseal-*"))
                if stages and any(stages[0].iterdir()):
                    stage = stages[0]
                    process.kill()
                    break
                if process.poll() is not None:
                    raise AssertionError("Process completed before the kill observation point")
                time.sleep(0.002)
            assert stage is not None
            code = process.wait(timeout=10)
            assert code == -signal.SIGKILL and not output.exists()
            assert stage.stat().st_mode & 0o077 == 0
            assert all(p.stat().st_mode & 0o077 == 0 for p in stage.iterdir())
            results.append({"scenario": "sigkill-after-staging", "result": "pass", "private_leftover": True,
                            "recovery": "not available in P0; do not publish leftover"})
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)

        # A real kernel write limit. This is EFBIG, not evidence of ENOSPC.
        def file_limit():
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
            resource.setrlimit(resource.RLIMIT_FSIZE, (512, 512))
        limited = root / "limited"
        failed = run(args.binary, "batch", source, "--output", limited, preexec_fn=file_limit)
        assert failed.returncode != 0 and not limited.exists()
        assert not list(root.glob("limited.medseal-*"))
        results.append({"scenario": "kernel-file-size-write-failure", "result": "pass", "kind": "EFBIG; not ENOSPC"})

        alias = root / "input-alias"
        alias.symlink_to(source, target_is_directory=True)
        assert run(args.binary, "batch", source, "--output", alias / "nested").returncode != 0
        assert not (source / "nested").exists()
        results.append({"scenario": "parent-symlink-nested-output", "result": "pass"})

        hardlink = source / "hardlink"
        os.link(next(source.glob("*.dcm")), hardlink)
        assert run(args.binary, "plan", source).returncode != 0
        results.append({"scenario": "hardlinked-input", "result": "pass"})
        hardlink.unlink()

        unreadable = next(source.glob("*.dcm"))
        unreadable.chmod(0)
        try:
            if os.geteuid() != 0:
                assert run(args.binary, "plan", source).returncode != 0
                results.append({"scenario": "unreadable-input", "result": "pass"})
            else:
                results.append({"scenario": "unreadable-input", "result": "not-exercised-as-root"})
        finally:
            unreadable.chmod(0o600)
    record = {"scope": "actual process/path/permission failures on this POSIX host; not power-loss or real disk-full certification",
              "scenarios": results, "real_enospc": "not exercised; instance-local storage failure tests cover cleanup"}
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
