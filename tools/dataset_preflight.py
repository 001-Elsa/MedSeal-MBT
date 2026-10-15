#!/usr/bin/env python3
"""Bounded POSIX dataset preflight; all DICOM decisions use the MoonBit CLI.

No converted data or release authorization is produced. Original filenames,
hashes and values never enter the public result. Private sealed copies are
removed on exit. Reuse enterprise discovery/sealing rather than a second walker.
"""
from pathlib import Path
import argparse
from collections import Counter
import json
import os
import re
import subprocess
import tempfile

from enterprise_job import scan, seal, DEFAULT_VERIFY, REPO
from private_store import StoreError
from local_fs import signature


ADVICE = {
    "filesystem": "检查目录权限；移除符号链接、硬链接和特殊文件，保留普通文件后重试。",
    "budget": "拆分为各自引用闭合的数据集；本入口限256对象、64MiB/对象、合计128MiB。",
    "format": "核对文件完整性及DICOM Part 10格式，从源系统重新导出受支持的未压缩Explicit VR Little Endian。",
    "encoding": "由源系统明确声明支持的字符集并重新导出；不要直接修改字符集标签冒充转码。",
    "policy": "检查严格策略、规则优先级及允许修改的字段；使用项目提供的strict策略作为基线。",
    "references": "补齐同一批次内的被引用对象，排除重复SOP身份，核对患者与Study/Series归属。",
    "metadata": "按公开规则位置核对必需字段、VR/VM和像素描述；从源系统修复，不猜测缺失值。",
    "runtime": "重新构建固定版本MoonBit命令行，检查运行权限与依赖；不要分享私有诊断日志。",
}
CODE_CATEGORIES = {"MEDSEAL-E108": "encoding", "MEDSEAL-E109": "encoding",
                   "MEDSEAL-E510": "policy", "MEDSEAL-E520": "references",
                   "MEDSEAL-E530": "metadata", "MEDSEAL-E501": "budget",
                   "MEDSEAL-E207": "budget", "MEDSEAL-E302": "filesystem"}


def issue(category, code="PREFLIGHT-BLOCKED", object_id=None):
    value = {"category": category, "code": code, "next_step": ADVICE[category]}
    if object_id is not None:
        value["object"] = object_id
    return value


def command(binary, args):
    try:
        return subprocess.run([str(binary), *map(str, args)], capture_output=True,
                              text=True, encoding="utf-8", timeout=60)
    except (OSError, subprocess.SubprocessError, UnicodeError):
        raise StoreError("preflight-runtime") from None


def failure_code(output):
    match = re.search(r"\bMEDSEAL-E[0-9]{3}\b", output)
    return match.group() if match else "PREFLIGHT-RUNTIME"


def report(source, policy=REPO / "examples/strict-policy.json", binary=DEFAULT_VERIFY):
    result = {"schema": 1, "kind": "dataset-preflight", "status": "blocked",
              "release_authorized": False, "scope": "strict-closed-current-dataset",
              "candidates": 0, "excluded_non_part10": 0, "checked": 0,
              "objects": [], "issues": [], "policy_actions": {},
              "collection": "not-checked", "source_stability": "not-checked"}
    try:
        records = scan(source)
        candidates = [row for row in records if row[2]]
        result["candidates"] = len(candidates)
        result["excluded_non_part10"] = sum(row[3] == "non-part10" for row in records)
        if (not candidates or len(candidates) > 256
                or any(row[1][2] > 64 * 1024 ** 2 for row in candidates)
                or sum(row[1][2] for row in candidates) > 128 * 1024 ** 2):
            result["issues"].append(issue("budget"))
            return result
        # POSIX no-follow policy read, bounded before allocating, stable on both
        # sides. Policy is copied into the sealed snapshot used by all commands.
        fd = os.open(policy, os.O_RDONLY | os.O_NOFOLLOW)
        try:
            before = signature(os.fstat(fd))
            if before[2] > 1024 * 1024:
                raise StoreError("preflight-policy")
            policy_bytes = os.read(fd, 1024 * 1024 + 1)
            if len(policy_bytes) > 1024 * 1024 or signature(os.fstat(fd)) != before:
                raise StoreError("preflight-policy")
        finally:
            os.close(fd)
        with tempfile.TemporaryDirectory(prefix="medseal-preflight-") as name:
            root = Path(name)
            snapshot = root / "sealed"
            snapshot.mkdir(mode=0o700)
            seal(source, snapshot)
            if scan(source) != records:
                raise StoreError("input-set-changed-during-sealing")
            local_policy = root / "policy.json"
            with local_policy.open("xb") as stream:
                os.chmod(local_policy, 0o600)
                stream.write(policy_bytes)
            compiled = command(binary, ["explain", local_policy])
            if compiled.returncode:
                result["issues"].append(issue("policy", failure_code(compiled.stdout)))
                return result
            actions = Counter()
            for number, path in enumerate(sorted(snapshot.glob("*.dcm")), 1):
                checked = command(binary, ["explain-object", path, "--policy", local_policy])
                try:
                    summary = json.loads(checked.stdout)
                except (ValueError, TypeError):
                    raise StoreError("preflight-runtime") from None
                ok = checked.returncode == 0 and summary.get("status") == "converted-explanation"
                entry = {"object": number, "status": "checked" if ok else "blocked"}
                result["checked"] += 1
                if not ok:
                    code = summary.get("issue", {}).get("code", "")
                    if not re.fullmatch(r"MEDSEAL-E[0-9]{3}", code):
                        code = "PREFLIGHT-RUNTIME"
                    category = CODE_CATEGORIES.get(code, "format" if code.startswith("MEDSEAL-E1") or code.startswith("MEDSEAL-E2") else "runtime")
                    problem = issue(category, code, number)
                    result["issues"].append(problem)
                    entry["category"] = category
                else:
                    for decision in summary.get("decisions", []):
                        action = decision.get("action")
                        if action in {"keep", "empty", "remove", "replace", "remap", "shift", "recurse"}:
                            actions[action] += 1
                result["objects"].append(entry)
            result["policy_actions"] = dict(sorted(actions.items()))
            result["policy_action_scope"] = "successful-object-explanations-only"
            # Never validate a filtered subset and label the original set ready.
            if not result["issues"]:
                planned = command(binary, ["plan", snapshot, "--policy", local_policy])
                if planned.returncode:
                    code = failure_code(planned.stdout)
                    result["issues"].append(issue(CODE_CATEGORIES.get(code, "runtime"), code))
                    result["collection"] = "blocked"
                else:
                    result["collection"] = "checked"
            if scan(source) != records:
                raise StoreError("input-set-changed-during-preflight")
            result["source_stability"] = "checked-at-boundaries"
            if not result["issues"]:
                result["status"] = "ready-for-planning"
    except StoreError as error:
        category = "budget" if str(error) in {"input-depth-budget", "input-entry-budget", "object-count-budget", "single-object-budget", "private-space-budget"} else "policy" if str(error) == "preflight-policy" else "runtime" if str(error) == "preflight-runtime" else "filesystem"
        result["issues"].append(issue(category))
    except (OSError, ValueError):
        # No exception payloads: paths, policy text and identifiers are private.
        result["issues"].append(issue("runtime" if not Path(binary).is_file() else "filesystem"))
    result["categories"] = dict(sorted(Counter(item["category"] for item in result["issues"]).items()))
    return result


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--policy", type=Path, default=REPO / "examples/strict-policy.json")
    parser.add_argument("--binary", type=Path, default=DEFAULT_VERIFY)
    args = parser.parse_args()
    result = report(args.input, args.policy, args.binary)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "ready-for-planning" else 1


if __name__ == "__main__":
    raise SystemExit(main())
