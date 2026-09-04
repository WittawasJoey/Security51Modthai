#!/usr/bin/env python3
"""Export non-empty canonical Thai translations to the plugin JSON format."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path("translations/th/strings.csv"),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    with args.translation.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    exported: dict[str, str] = {}
    conflicts: list[str] = []
    for row in rows:
        thai = row.get("thai", "").strip()
        status = row.get("status", "")
        if not thai or status in {"untranslated", "excluded"}:
            continue
        key = row["key"]
        previous = exported.get(key)
        if previous is not None and previous != thai:
            conflicts.append(key)
            continue
        exported[key] = thai

    if conflicts:
        raise SystemExit("Conflicting translations for duplicate keys: " + ", ".join(sorted(set(conflicts))))
    if not exported:
        raise SystemExit("No translated entries were available to export.")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(exported, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Exported {len(exported)} unique Thai terms to {args.output}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
