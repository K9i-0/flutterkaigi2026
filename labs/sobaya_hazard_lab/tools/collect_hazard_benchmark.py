#!/usr/bin/env python3
"""Reassemble bounded iOS log chunks. Input is plain text or a JSON log array.

Usage: python3 tools/collect_hazard_benchmark.py run.log output-directory
Only complete, consistent chunk groups produce a result JSON. Repeated identical
lines are accepted; conflicting duplicates, missing chunks, and bad data fail.
"""
import argparse
import base64
import json
from pathlib import Path
import re

MARKER = "HAZARD_GAME_BENCHMARK_CHUNK "


def collect(lines):
    groups = {}
    for line in lines:
        if MARKER not in line:
            continue
        chunk = json.loads(line.split(MARKER, 1)[1])
        identifier, part, total = chunk["id"], chunk["part"], chunk["total"]
        if not isinstance(identifier, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", identifier):
            raise ValueError("Invalid chunk id")
        if type(part) is not int or type(total) is not int or not 1 <= part <= total:
            raise ValueError(f"Invalid sequence: {identifier}")
        group = groups.setdefault(identifier, {"total": total, "parts": {}})
        if group["total"] != total:
            raise ValueError(f"Conflicting total: {identifier}")
        previous = group["parts"].get(part)
        if previous is not None and previous != chunk["data"]:
            raise ValueError(f"Conflicting part {part}: {identifier}")
        group["parts"][part] = chunk["data"]
    if not groups:
        raise ValueError("No benchmark chunks found")
    results = {}
    for identifier, group in groups.items():
        missing = set(range(1, group["total"] + 1)) - group["parts"].keys()
        if missing:
            raise ValueError(f"Incomplete {identifier}, missing parts: {sorted(missing)}")
        encoded = "".join(group["parts"][part] for part in range(1, group["total"] + 1))
        result = json.loads(base64.b64decode(encoded, validate=True).decode("utf-8"))
        if not isinstance(result, dict):
            raise ValueError(f"Expected JSON object: {identifier}")
        results[identifier] = result
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    raw = args.log.read_text()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = None
    lines = parsed if isinstance(parsed, list) else raw.splitlines()
    results = collect(lines)
    args.output.mkdir(parents=True, exist_ok=True)
    for identifier, result in results.items():
        path = args.output / f"benchmark-{identifier}.json"
        path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(path)


if __name__ == "__main__":
    main()
