#!/usr/bin/env python3
"""Merges the UI smoke shards' output into one, for the comment and the
artifacts (.github/workflows/ui-smoke.yml runs the scenarios on parallel
runners, one shard each, with scripts/ui-smoke.sh UI_SMOKE_SHARD=k/n).

  ui-smoke-merge.py <shards dir> <out dir> --count <n>

<shards dir> holds one directory per shard, ui-smoke-shard-<k>/, each a
scripts/ui-smoke.sh output directory (results.json, clips/, shots/, logs).
Writes <out dir>/results.json (every scenario, in name order), clips/ and
shots/ (all shards' files together) and logs/shard-<k>/ (each shard's logs
and xcresult). A scenario whose shard left no result (its build or runner
failed) is reported as not run, with the reason, so nothing goes missing.
Exits 0 when every scenario passed, 1 otherwise.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def shard_members(k, n):
    out = subprocess.run(
        [sys.executable, os.path.join(ROOT, "scripts", "smoke-scenarios.py"), "shard", f"{k}/{n}", "--json"],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def copy_tree(source, destination):
    if os.path.isdir(source):
        shutil.copytree(source, destination, dirs_exist_ok=True)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("shards")
    p.add_argument("out")
    p.add_argument("--count", type=int, required=True)
    args = p.parse_args()

    os.makedirs(os.path.join(args.out, "clips"), exist_ok=True)
    os.makedirs(os.path.join(args.out, "shots"), exist_ok=True)
    scenarios = []
    devices = []
    statuses = []
    for k in range(1, args.count + 1):
        shard = os.path.join(args.shards, f"ui-smoke-shard-{k}")
        results_path = os.path.join(shard, "results.json")
        copy_tree(os.path.join(shard, "clips"), os.path.join(args.out, "clips"))
        copy_tree(os.path.join(shard, "shots"), os.path.join(args.out, "shots"))
        logs = os.path.join(args.out, "logs", f"shard-{k}")
        os.makedirs(logs, exist_ok=True)
        if os.path.isdir(shard):
            for name in os.listdir(shard):
                if name.endswith(".log") or name in ("signals", "smoke.xcresult", "final.png", "device.txt"):
                    source = os.path.join(shard, name)
                    if os.path.isdir(source):
                        copy_tree(source, os.path.join(logs, name))
                    else:
                        shutil.copy2(source, logs)
        try:
            with open(results_path, encoding="utf-8") as f:
                results = json.load(f)
        except (OSError, ValueError):
            # The shard never wrote results: its build or test runner failed.
            reason = f"shard {k}/{args.count} produced no results; its build or test runner failed (see its logs)"
            for s in shard_members(k, args.count):
                scenarios.append({
                    "scenario": s["name"], "seed": s["seed"], "file": s["file"], "class": s["class"],
                    "method": s["method"], "status": "not-run", "failure": reason, "files": {},
                })
            statuses.append(1)
            continue
        devices.append(results.get("device", "simulator"))
        statuses.append(results.get("xcodebuild_status", 0))
        scenarios.extend(results.get("scenarios", []))

    scenarios.sort(key=lambda s: s["scenario"])
    summary = {
        "device": devices[0] if devices else "simulator",
        "xcodebuild_status": max(statuses) if statuses else 1,
        "shards": args.count,
        "total": len(scenarios),
        "passed": sum(1 for s in scenarios if s.get("status") == "passed"),
        "failed": sum(1 for s in scenarios if s.get("status") != "passed"),
        "scenarios": scenarios,
    }
    with open(os.path.join(args.out, "results.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)
    print(f"{summary['passed']} of {summary['total']} scenarios passed across {args.count} shards")
    for s in scenarios:
        if s.get("status") != "passed":
            print(f"  {s['scenario']}: {s.get('status')} {s.get('failure', '')}")
    return 0 if summary["failed"] == 0 and scenarios else 1


if __name__ == "__main__":
    sys.exit(main())
