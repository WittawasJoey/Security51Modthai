#!/usr/bin/env python3
"""Generate documented exclusions for source rows whose value is exactly #N/A."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("translations/source_en/strings.csv"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("translations/th/generated-exclusions-na.json"),
    )
    args = parser.parse_args()

    with args.source.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    keys = sorted({row["key"] for row in rows if row["english"].strip() == "#N/A"})
    exclusions = {key: "ค่าต้นฉบับ #N/A ไม่ใช่ข้อความสำหรับแปล" for key in keys}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(exclusions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Generated {len(exclusions)} #N/A exclusions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
