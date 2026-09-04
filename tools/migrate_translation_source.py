#!/usr/bin/env python3
"""Merge an extracted source CSV into the canonical Thai translation table."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


FIELDS = ["index", "key", "english", "thai", "status", "notes"]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("new_source", type=Path)
    parser.add_argument("old_translation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source_rows = read_rows(args.new_source)
    old_rows = read_rows(args.old_translation)
    old_by_key: dict[str, dict[str, str]] = {}
    for row in old_rows:
        key = row.get("key", "")
        current = old_by_key.get(key)
        if current is None or (not current.get("thai") and row.get("thai")):
            old_by_key[key] = row

    preserved = new_entries = changed = 0
    output_rows: list[dict[str, str]] = []
    for source in source_rows:
        key = source.get("key", "")
        english = source.get("english", "")
        old = old_by_key.get(key)
        thai = status = notes = ""
        if old is None:
            status = "untranslated"
            new_entries += 1
        elif old.get("english", "") == english:
            thai = old.get("thai", "")
            status = old.get("status", "") or "untranslated"
            notes = old.get("notes", "")
            preserved += 1
        elif not old.get("english", ""):
            if old.get("thai", ""):
                thai = old.get("thai", "")
                status = old.get("status", "") or "draft"
                notes = "[source update] English added; preserved existing fallback translation"
                preserved += 1
            else:
                status = "untranslated"
                notes = "[new source text] added by game update"
                new_entries += 1
        else:
            status = "untranslated"
            notes = f"[source changed] previous English: {old.get('english', '')}"
            changed += 1

        output_rows.append(
            {
                "index": source.get("index", ""),
                "key": key,
                "english": english,
                "thai": thai,
                "status": status,
                "notes": notes,
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"Rows: {len(output_rows)}")
    print(f"Preserved rows: {preserved}")
    print(f"New/untranslated rows: {new_entries}")
    print(f"Changed-source rows reset: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
