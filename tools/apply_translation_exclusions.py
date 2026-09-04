#!/usr/bin/env python3
"""Apply documented translation exclusions to the canonical Thai CSV."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("exclusions", type=Path)
    parser.add_argument("--translation", type=Path, default=Path("translations/th/strings.csv"))
    args = parser.parse_args()

    exclusions = json.loads(args.exclusions.read_text(encoding="utf-8-sig"))
    if not isinstance(exclusions, dict) or not all(
        isinstance(key, str) and isinstance(reason, str) and reason.strip()
        for key, reason in exclusions.items()
    ):
        raise SystemExit("Exclusions must be a JSON object of key/non-empty reason pairs.")

    with args.translation.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames
        rows = list(reader)
    if not fieldnames:
        raise SystemExit("Translation CSV has no header.")

    known = {row["key"] for row in rows}
    unknown = sorted(set(exclusions) - known)
    if unknown:
        raise SystemExit("Unknown exclusion keys: " + ", ".join(unknown))

    changed = 0
    for row in rows:
        reason = exclusions.get(row["key"])
        if reason is None:
            continue
        if row["thai"].strip():
            raise SystemExit(f"Refusing to exclude translated key: {row['key']}")
        row["status"] = "excluded"
        row["notes"] = f"[excluded] {reason}"
        changed += 1

    temporary = args.translation.with_suffix(args.translation.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(args.translation)
    print(f"Applied {len(exclusions)} exclusions to {changed} rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
