#!/usr/bin/env python3
"""The UI smoke scenarios as data: which exist, which a pull request added or
changed, and whether a pull request that touches Sources/ brought one.
Used by scripts/ui-smoke.sh and the workflows; see "UI smoke test" in
README.md.

  smoke-scenarios.py list [--json]
      Every scenario in UISmoke/Tests: one `test…` method is one scenario,
      named after the method in kebab case (testLogDrink is log-drink).
      --json adds the file, class, method and seed of each.

  smoke-scenarios.py changed --base <ref> [--body-file <file>] [--json]
      The scenarios the current HEAD added or changed since the merge base
      with <ref> (a method with a changed line, or a new file). A
      `Smoke-demo:` line in the pull request body (--body-file) overrides
      it: `Smoke-demo: log-drink, home` names the demos,
      `Smoke-demo: none` declares there are none.

  smoke-scenarios.py check --base <ref> --body-file <file>
      The "Smoke scenario present" check: fails (exit 1, with the reason)
      when Sources/ changed but no scenario did and the body has no
      `Smoke-demo:` line, or when that line names a scenario that does
      not exist.
"""
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS_DIR = "UISmoke/Tests"
METHOD = re.compile(r"^\s*func\s+(test\w*)\s*\(")
CLASS = re.compile(r"^\s*(?:final\s+)?class\s+(\w+)\s*:")
SEED = re.compile(r"launch\(seed:\s*\.`?(\w+)`?")
DEMO_LINE = re.compile(r"^\s*smoke-demo\s*:\s*(.*?)\s*$", re.IGNORECASE | re.MULTILINE)


def kebab(method):
    """testLogDrinkFreeDay -> log-drink-free-day (the rule in
    SmokeSupport.swift)."""
    name = method[4:] if method.startswith("test") else method
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower() or "scenario"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def parse_file(path, text):
    """The scenarios in one test file, each with its line range."""
    lines = text.split("\n")
    scenarios = []
    current_class = None
    for number, line in enumerate(lines, start=1):
        if m := CLASS.match(line):
            current_class = m.group(1)
        if m := METHOD.match(line):
            # A method's range runs to the line before the next method's
            # doc comment.
            start = number
            while start > 1 and lines[start - 2].strip().startswith("///"):
                start -= 1
            if scenarios and scenarios[-1]["end"] is None:
                scenarios[-1]["end"] = start - 1
            scenarios.append({
                "name": kebab(m.group(1)),
                "method": m.group(1),
                "class": current_class or "",
                "file": path,
                "start": start,
                "end": None,
            })
    if scenarios and scenarios[-1]["end"] is None:
        scenarios[-1]["end"] = len(lines)
    for scenario in scenarios:
        body = "\n".join(lines[scenario["start"] - 1:scenario["end"]])
        m = SEED.search(body)
        scenario["seed"] = kebab("test" + m.group(1)[0].upper() + m.group(1)[1:]) if m else "default"
    return scenarios


def test_files():
    directory = os.path.join(ROOT, TESTS_DIR)
    if not os.path.isdir(directory):
        return []
    return sorted(
        os.path.join(TESTS_DIR, f) for f in os.listdir(directory) if f.endswith(".swift")
    )


def all_scenarios():
    scenarios = []
    for path in test_files():
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            scenarios.extend(parse_file(path, f.read()))
    return sorted(scenarios, key=lambda s: s["name"])


def changed_files(base):
    """Paths changed between the merge base with `base` and HEAD."""
    out = git("diff", "--name-only", f"{base}...HEAD")
    return [line for line in out.split("\n") if line]


def changed_scenarios(base):
    """Scenarios with a changed line, in the current tree, since `base`."""
    scenarios = {s["name"]: s for s in all_scenarios()}
    touched = set()
    for path in changed_files(base):
        if not path.startswith(TESTS_DIR + "/") or not path.endswith(".swift"):
            continue
        in_file = [s for s in scenarios.values() if s["file"] == path]
        if not os.path.exists(os.path.join(ROOT, path)):
            continue  # deleted: nothing to demo
        diff = git("diff", "-U0", f"{base}...HEAD", "--", path)
        if "\n--- /dev/null" in diff or diff.startswith("--- /dev/null"):
            touched.update(s["name"] for s in in_file)  # a new file: every method
            continue
        for m in re.finditer(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", diff, re.MULTILINE):
            start = int(m.group(1))
            count = int(m.group(2)) if m.group(2) is not None else 1
            # A pure deletion (count 0) sits between `start` and the next line.
            lo, hi = (start, start + 1) if count == 0 else (start, start + count - 1)
            for s in in_file:
                if lo <= s["end"] and hi >= s["start"]:
                    touched.add(s["name"])
    return [scenarios[name] for name in sorted(touched)]


def demo_override(body):
    """None when the body has no Smoke-demo line; [] for `none`; else the
    names (unvalidated)."""
    if not body:
        return None
    m = DEMO_LINE.search(body)
    if not m:
        return None
    value = m.group(1).strip().strip("`").strip()
    if value.lower() in ("none", "no", "-", ""):
        return []
    return [name.strip().strip("`") for name in re.split(r"[,\s]+", value) if name.strip().strip("`")]


def read_body(path):
    if not path:
        return ""
    with open(path, encoding="utf-8") as f:
        return f.read()


def cmd_list(args):
    scenarios = all_scenarios()
    if args.json:
        print(json.dumps(scenarios, indent=2))
    else:
        for s in scenarios:
            print(s["name"])


def resolve_demos(base, body):
    """The demo scenarios for a PR: the override if any, else detection.
    Returns (names, unknown names, source)."""
    known = {s["name"] for s in all_scenarios()}
    override = demo_override(body)
    if override is not None:
        unknown = [n for n in override if n not in known]
        return [n for n in override if n in known], unknown, "body"
    return [s["name"] for s in changed_scenarios(base)], [], "diff"


def cmd_changed(args):
    names, unknown, source = resolve_demos(args.base, read_body(args.body_file))
    if unknown:
        print(f"warning: Smoke-demo names unknown scenarios: {', '.join(unknown)}", file=sys.stderr)
    if args.json:
        print(json.dumps({"demos": names, "source": source, "unknown": unknown}))
    else:
        for name in names:
            print(name)


def cmd_check(args):
    body = read_body(args.body_file)
    files = changed_files(args.base)
    sources = [f for f in files if f.startswith("Sources/") or f.startswith("Modules/")]
    changed = changed_scenarios(args.base)
    override = demo_override(body)
    known = {s["name"] for s in all_scenarios()}

    if override:
        unknown = [n for n in override if n not in known]
        if unknown:
            print(f"Smoke-demo names scenarios that do not exist: {', '.join(unknown)}.")
            print(f"Known scenarios: {', '.join(sorted(known))}.")
            return 1
    if not sources:
        print("No change under Sources/ or Modules/; no scenario required.")
        return 0
    if changed:
        print("Scenarios added or changed: " + ", ".join(s["name"] for s in changed) + ".")
        return 0
    if override is not None:
        if override:
            print("Smoke-demo names existing scenarios: " + ", ".join(override) + ".")
        else:
            print("Smoke-demo: none. The pull request declares it has no UI to show.")
        return 0
    print(
        "This pull request changes " + ", ".join(sources[:5]) + (", …" if len(sources) > 5 else "")
        + " but adds or changes no UI smoke scenario in UISmoke/Tests/.\n"
        "\n"
        "Every feature or fix needs a scenario the reviewer can watch (see CLAUDE.md):\n"
        "  - add or update a test method in UISmoke/Tests/ that shows the change, or\n"
        "  - if an existing scenario already shows it, add a line to the PR body:\n"
        "        Smoke-demo: <scenario>, <scenario>\n"
        "  - or, for a change with nothing to show on screen (CI, docs, a refactor):\n"
        "        Smoke-demo: none\n"
        "\n"
        "Scenarios today: " + ", ".join(sorted(known)) + "."
    )
    return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("list")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_list)
    p = sub.add_parser("changed")
    p.add_argument("--base", required=True)
    p.add_argument("--body-file")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_changed)
    p = sub.add_parser("check")
    p.add_argument("--base", required=True)
    p.add_argument("--body-file")
    p.set_defaults(func=cmd_check)
    args = parser.parse_args()
    sys.exit(args.func(args) or 0)


if __name__ == "__main__":
    main()
