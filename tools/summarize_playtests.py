#!/usr/bin/env python3
"""Summarize locally collected matches without mixing human and scripted data."""
import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path


def summarize(directory: Path, include_automated: bool = False) -> str:
    reports = []
    ignored = 0
    seen = set()
    for path in sorted(directory.glob("match-*.json")):
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(report, dict) or report.get("schema") != 1:
                raise ValueError("unsupported report schema")
            if report.get("source") != "human" and not include_automated:
                ignored += 1
                continue
            if report.get("id") in seen:
                continue
            seen.add(report.get("id"))
            reports.append(report)
        except (OSError, ValueError, TypeError) as exc:
            print(f"Skipped {path.name}: {exc}", file=sys.stderr)
    groups = defaultdict(Counter)
    events = Counter()
    ratings = defaultdict(list)
    for report in reports:
        source = report.get("source", "unknown")
        for shot in report.get("shots", []):
            key = (
                source,
                report.get("balance_version", "unknown"),
                report.get("difficulty", "unknown"),
                "wet" if shot.get("wetness", 0) >= .4 else "dry",
                "tired" if shot.get("energy", 1) < .45 or shot.get("fatigue", 0) > .2 else "fresh",
                "wide" if shot.get("angle", 0) >= 30 else "central",
                "close" if shot.get("distance", 0) < 12 else "mid" if shot.get("distance", 0) < 24 else "far",
                shot.get("kind", "unknown"),
            )
            groups[key]["shots"] += 1
            groups[key][shot.get("outcome", "unresolved")] += 1
        events.update(event.get("event", "unknown") for event in report.get("events", []))
        for dimension in ("controls", "balance", "animation"):
            value = report.get("feedback", {}).get(dimension)
            if isinstance(value, (int, float)) and 1 <= value <= 5:
                ratings[(source, dimension)].append(value)
    lines = [f"Matches: {len(reports)}; excluded automated reports: {ignored}.",
             "Shot groups retain source, balance version and difficulty. Small samples are descriptive, not balance verdicts.",
             "Goals are directly attributed shot outcomes; own goals, rebounds and unresolved shots remain separate.", "",
             "| Source / version / difficulty / weather / fitness / angle / distance / shot | N | Goal | Saved | Blocked | Unresolved |",
             "|---|---:|---:|---:|---:|---:|"]
    for key, counts in sorted(groups.items(), key=lambda item: str(item[0])):
        lines.append(f"| {' / '.join(map(str, key))} | {counts['shots']} | {counts['goal']} | {counts['saved']} | {counts['blocked']} | {counts['unresolved'] + counts['pending']} |")
    lines += ["", "Ratings (1–5):"]
    for (source, dimension), values in sorted(ratings.items()):
        lines.append(f"- {source} {dimension}: {sum(values)/len(values):.2f} ({len(values)} responses)")
    lines += ["", "Control events:"]
    lines += [f"- {key}: {value}" for key, value in sorted(events.items())]
    if any(report.get("truncated") for report in reports):
        lines.append("\nSome reports reached their event/sample limits; counts are incomplete.")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Local playtests folder")
    parser.add_argument("--include-automated", action="store_true", help="Keep fixture data in separately labelled groups")
    parser.add_argument("--output", type=Path, help="Optional Markdown report")
    args = parser.parse_args()
    if not args.directory.is_dir():
        parser.error("The report directory does not exist")
    result = summarize(args.directory, args.include_automated)
    if args.output:
        args.output.write_text(result, encoding="utf-8")
    else:
        print(result, end="")
