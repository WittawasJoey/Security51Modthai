#!/usr/bin/env python3
"""Export rows that require Russian because the official English slot is empty."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--all-languages", type=Path, default=Path("source/i2_all_languages.csv"))
    parser.add_argument("--output", type=Path, default=Path("translations/source_ru/strings.csv"))
    args = parser.parse_args()

    with args.all_languages.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    fallback_rows = [
        {
            "key": row["Key []"],
            "description": row["Description []"],
            "source_language": "ru",
            "source_text": row["Russian [ru]"],
        }
        for row in rows
        if not row["English [en]"] and row["Russian [ru]"]
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["key", "description", "source_language", "source_text"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(fallback_rows)
    print(f"Exported {len(fallback_rows)} Russian fallback source rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
