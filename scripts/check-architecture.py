#!/usr/bin/env python3
"""Checks the iPhone app's layering rules (docs/architecture.md, "Enforced
rules"). Cheap and dependency-free: it reads import lines and a few
forbidden constructs, file by file. Run from the repository root:

    scripts/check-architecture.py

Exits 1 and lists every violation when a rule is broken. CI runs it on every
push and pull request (.github/workflows/architecture.yml).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "Sources" / "Tippy"
MODULES = ROOT / "Modules"

# Every bounded-context module under Modules/<Name>/Sources/<Name>.
CONTEXTS = sorted(
    p.name for p in MODULES.glob("*/Sources/*") if p.is_dir() and p.name == p.parent.parent.name
) if MODULES.exists() else []

IMPORT = re.compile(r"^\s*(?:@[\w()]+\s+)*import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?([\w.]+)", re.M)
CLOCK = re.compile(r"\bDate\(\)|\bDate\.now\b")
ADAPTER_CONSTRUCTION = re.compile(
    r"\b(FileJournalStore|NotificationReminderScheduler|InMemoryJournalStore|SilentReminderScheduler)\s*[.(]"
)
STRIP_COMMENTS = re.compile(r"//.*?$|/\*.*?\*/", re.M | re.S)

# Layer -> imports it may use. Contexts (the domain modules) are added below.
ALLOWED = {
    "domain": {"Foundation"},
    "model": {"Foundation", "Observation"},
    "adapters": {"Foundation", "UserNotifications", "CloudKit", "HealthKit", "WidgetKit", "os"},
    "views": {"SwiftUI", "UIKit", "Foundation", "UniformTypeIdentifiers", "Charts", "Observation"},
    "app": {"SwiftUI", "Foundation", "Observation"},
    "demo": {"Foundation"},
}


def layer_of(path: pathlib.Path) -> str | None:
    rel = path.relative_to(ROOT).parts
    if rel[0] == "Modules" and "Sources" in rel:
        return "domain"
    if rel[:2] == ("Sources", "Tippy") and len(rel) > 3:
        return {
            "Model": "model",
            "Adapters": "adapters",
            "Views": "views",
            "App": "app",
            "Demo": "demo",
        }.get(rel[2])
    if rel[:2] == ("Sources", "Tippy"):
        return "misplaced"
    return None


def module_dependencies() -> dict[str, set[str]]:
    """Which other contexts each context's Package.swift depends on."""
    deps = {}
    for name in CONTEXTS:
        manifest = (MODULES / name / "Package.swift").read_text()
        deps[name] = {c for c in CONTEXTS if c != name and re.search(rf'"{c}"', manifest)}
    return deps


def main() -> int:
    problems: list[str] = []
    deps = module_dependencies()

    for path in sorted(list(APP.rglob("*.swift")) + list(MODULES.glob("*/Sources/**/*.swift"))):
        layer = layer_of(path)
        rel = path.relative_to(ROOT)
        if layer is None:
            continue
        if layer == "misplaced":
            problems.append(f"{rel}: app sources live in App/, Model/, Adapters/, Views/ or Demo/")
            continue
        source = STRIP_COMMENTS.sub("", path.read_text())
        imports = set(IMPORT.findall(source))

        allowed = set(ALLOWED[layer])
        if layer == "domain":
            context = rel.parts[1]
            allowed |= deps.get(context, set())
        else:
            allowed |= set(CONTEXTS)
        for module in sorted(imports - allowed):
            problems.append(f"{rel}: the {layer} layer may not import {module}")

        if layer in ("domain", "model", "views") and CLOCK.search(source):
            problems.append(f"{rel}: no Date() / Date.now in the {layer} layer; take the injected clock (model.now)")

        if layer not in ("app", "demo") and ADAPTER_CONSTRUCTION.search(source):
            # An adapter may define itself; it may not construct others.
            defined = set(re.findall(r"\b(?:class|struct)\s+(\w+)", source))
            used = set(ADAPTER_CONSTRUCTION.findall(source)) - defined
            for name in sorted(used):
                problems.append(f"{rel}: only the composition root (App/) or Demo/ may create {name}")

        if layer == "views" and re.search(r"\bJournalCodec\b|\bstore\.(save|load)\b", source):
            problems.append(f"{rel}: views go through JournalModel, never storage")

    # Context dependencies must not form a cycle.
    def visit(node: str, stack: list[str]) -> None:
        if node in stack:
            problems.append("Modules/: dependency cycle " + " -> ".join(stack[stack.index(node):] + [node]))
            return
        for nxt in deps.get(node, ()):
            visit(nxt, stack + [node])

    for name in CONTEXTS:
        visit(name, [])

    if problems:
        print("Architecture check failed (see docs/architecture.md):")
        for problem in sorted(set(problems)):
            print(f"  - {problem}")
        return 1
    print(f"Architecture check passed: {len(CONTEXTS)} context(s), app layers clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
