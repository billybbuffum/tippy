#!/usr/bin/env python3
"""Writes the sticky pull request comment of the UI smoke workflow from
results.json (scripts/ui-smoke.sh) and the demo list
(scripts/smoke-scenarios.py changed --json): the feature demos first, with
their GIFs inline, then the regression table with every scenario's GIF
folded away. Markdown on stdout.

  ui-smoke-comment.py --results out/ui-smoke/results.json --demos demos.json \
      --media-url https://github.com/o/r/blob/pr-media/pr-7 --run-url ... \
      [--clips-artifact URL] [--shots-artifact URL] [--logs-artifact URL] \
      --sha <sha> --run-number <n>
"""
import argparse
import datetime
import json

MARKER = "<!-- ui-smoke -->"


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def status_word(entry):
    return {"passed": "passed", "failed": "**failed**", "incomplete": "**incomplete**", "not-run": "not run"}.get(
        entry.get("status"), entry.get("status", "?")
    )


def seconds(entry):
    duration = entry.get("duration")
    return f"{duration:.0f} s" if isinstance(duration, (int, float)) and duration > 0 else "–"


def gif_url(media, entry):
    if not media or "gif" not in entry.get("files", {}):
        return None
    return f"{media}/{entry['scenario']}.gif?raw=true"


def failure_line(entry):
    failure = entry.get("failure")
    if not failure:
        return ""
    failure = " ".join(failure.split())
    if len(failure) > 160:
        failure = failure[:157] + "…"
    return failure.replace("|", "\\|")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--results", required=True)
    p.add_argument("--demos", required=True)
    p.add_argument("--media-url", default="")
    p.add_argument("--run-url", required=True)
    p.add_argument("--clips-artifact", default="")
    p.add_argument("--shots-artifact", default="")
    p.add_argument("--logs-artifact", default="")
    p.add_argument("--sha", default="")
    p.add_argument("--run-number", default="")
    args = p.parse_args()

    try:
        results = load(args.results)
    except (OSError, ValueError):
        results = {"device": "simulator", "total": 0, "passed": 0, "failed": 0, "scenarios": []}
    demos_info = load(args.demos)
    demo_names = demos_info.get("demos", [])
    source = demos_info.get("source", "diff")
    by_name = {s["scenario"]: s for s in results.get("scenarios", [])}
    scenarios = results.get("scenarios", [])
    media = args.media_url.rstrip("/")

    lines = [MARKER]
    total, passed = results.get("total", 0), results.get("passed", 0)
    if total == 0:
        lines.append("### UI smoke test: nothing ran")
        lines.append("")
        lines.append(f"The simulator build or the test runner failed before any scenario; see the [run]({args.run_url}).")
    elif passed == total:
        lines.append(f"### UI smoke test: all {total} scenarios passed")
    else:
        lines.append(f"### UI smoke test: {passed} of {total} scenarios passed")
        failed = [s["scenario"] for s in scenarios if s.get("status") != "passed"]
        lines.append("")
        lines.append("Failed: " + ", ".join(f"`{name}`" for name in failed) + ". The table below says where each stopped; the screenshots artifact has the last frame.")
    lines.append("")

    # Feature demo
    lines.append("#### Feature demo")
    lines.append("")
    if demo_names:
        if source == "body":
            lines.append("_Named by `Smoke-demo:` in the pull request body._")
        else:
            lines.append("_Scenarios this pull request added or changed._")
        lines.append("")
        for name in demo_names:
            entry = by_name.get(name)
            if entry is None:
                lines.append(f"- **{name}**: not in this run")
                continue
            parts = [f"**{name}**", status_word(entry), seconds(entry), f"seed `{entry.get('seed', 'default')}`"]
            if failure_line(entry):
                parts.append(failure_line(entry))
            lines.append("- " + " · ".join(parts))
        lines.append("")
        images = []
        for name in demo_names:
            entry = by_name.get(name)
            url = gif_url(media, entry) if entry else None
            if url:
                images.append(f'<img src="{url}" width="300" alt="{name}">')
        if images:
            lines.append("<p>" + " ".join(images) + "</p>")
        else:
            lines.append("_No clip was recorded for the demo scenarios._")
    elif source == "body":
        lines.append("_None: the pull request body says `Smoke-demo: none`._")
    else:
        lines.append("_None: no scenario in `UISmoke/Tests/` was added or changed. A feature or fix should come with one (see CLAUDE.md); name an existing one with `Smoke-demo: <scenario>` in the body if it already shows the change._")
    lines.append("")

    # Regression suite
    lines.append("#### Regression suite")
    lines.append("")
    lines.append("| Scenario | Status | Time | Seed | Clip |")
    lines.append("|---|---|---|---|---|")
    for entry in scenarios:
        name = entry["scenario"]
        url = gif_url(media, entry)
        clip = f"[GIF]({url})" if url else "–"
        if args.clips_artifact and "mp4" in entry.get("files", {}):
            clip += f" · [MP4]({args.clips_artifact})"
        status = status_word(entry)
        if failure_line(entry):
            status += f"<br><sub>{failure_line(entry)}</sub>"
        demo = " (demo)" if name in demo_names else ""
        lines.append(f"| `{name}`{demo} | {status} | {seconds(entry)} | `{entry.get('seed', 'default')}` | {clip} |")
    lines.append("")
    gifs = [(s["scenario"], gif_url(media, s)) for s in scenarios if gif_url(media, s)]
    if gifs:
        lines.append("<details>")
        lines.append(f"<summary>Every scenario's clip ({len(gifs)})</summary>")
        lines.append("")
        for name, url in gifs:
            lines.append(f"**{name}**")
            lines.append("")
            lines.append(f'<img src="{url}" width="240" alt="{name}">')
            lines.append("")
        lines.append("</details>")
        lines.append("")

    links = [f"[Workflow run]({args.run_url})"]
    if args.clips_artifact:
        links.append(f"[MP4 + GIF clips]({args.clips_artifact})")
    if args.shots_artifact:
        links.append(f"[Screenshots]({args.shots_artifact})")
    if args.logs_artifact:
        links.append(f"[Logs and xcresult]({args.logs_artifact})")
    lines.append(" · ".join(links))
    lines.append("")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines.append(
        f"<sub>Commit {args.sha[:7]} on {results.get('device', 'simulator')}, run #{args.run_number}, {stamp}. "
        "Runs when the `smoke` label is added; remove and re-add it to run again.</sub>"
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
