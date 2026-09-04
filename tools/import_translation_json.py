#!/usr/bin/env python3
"""Import a reviewed JSON key/value batch into the canonical Thai CSV table."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


VALID_STATUSES = {"draft", "reviewed", "in-game verified"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("batch", type=Path)
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path("translations/th/strings.csv"),
    )
    parser.add_argument("--status", choices=sorted(VALID_STATUSES), default="draft")
    args = parser.parse_args()

    with args.batch.open("r", encoding="utf-8-sig") as handle:
        batch = json.load(handle)
    if not isinstance(batch, dict) or not all(
        isinstance(key, str) and isinstance(value, str) for key, value in batch.items()
    ):
        raise SystemExit("Batch must be a JSON object containing string key/value pairs.")

    with args.translation.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames
        rows = list(reader)
    if not fieldnames:
        raise SystemExit("Translation CSV has no header.")

    known_keys = {row["key"] for row in rows}
    unknown = sorted(set(batch) - known_keys)
    if unknown:
        raise SystemExit("Unknown translation keys: " + ", ".join(unknown))

    updated = 0
    for row in rows:
        value = batch.get(row["key"])
        if value is None:
            continue
        row["thai"] = value
        row["status"] = args.status
        updated += 1

    temporary = args.translation.with_suffix(args.translation.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(args.translation)
    print(f"Imported {len(batch)} keys into {updated} rows with status '{args.status}'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
