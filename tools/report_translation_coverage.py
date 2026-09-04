#!/usr/bin/env python3
"""Generate category and status coverage for the canonical Thai translation table."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

from source_text import load_fallbacks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("translations/source_en/strings.csv"))
    parser.add_argument("--translation", type=Path, default=Path("translations/th/strings.csv"))
    parser.add_argument("--output", type=Path, default=Path("reports/translation-coverage.json"))
    parser.add_argument("--all-languages", type=Path, default=Path("source/i2_all_languages.csv"))
    args = parser.parse_args()

    with args.source.open("r", encoding="utf-8-sig", newline="") as handle:
        source = list(csv.DictReader(handle))
    with args.translation.open("r", encoding="utf-8-sig", newline="") as handle:
        target = list(csv.DictReader(handle))
    if len(source) != len(target):
        raise SystemExit("Source and translation row counts differ.")
    fallback_by_key = load_fallbacks(args.all_languages)

    statuses: Counter[str] = Counter()
    categories: dict[str, Counter[str]] = defaultdict(Counter)
    translated_keys: set[str] = set()
    visible_source_keys: set[str] = set()
    excluded_keys: set[str] = set()
    for source_row, target_row in zip(source, target):
        status = target_row["status"]
        translated = bool(target_row["thai"].strip()) and status != "excluded"
        category = source_row["category"] or "(uncategorized)"
        statuses[status] += 1
        categories[category]["rows"] += 1
        if status == "excluded":
            categories[category]["excluded_rows"] += 1
            excluded_keys.add(source_row["key"])
        effective_source = source_row["english"] or fallback_by_key.get(source_row["key"], ("", ""))[0]
        if effective_source.strip() and effective_source != "#N/A":
            visible_source_keys.add(source_row["key"])
        if translated:
            categories[category]["translated_rows"] += 1
            translated_keys.add(source_row["key"])

    report = {
        "source_rows": len(source),
        "unique_source_keys": len({row["key"] for row in source}),
        "nonempty_source_keys": len(visible_source_keys),
        "excluded_unique_keys": len(excluded_keys),
        "eligible_nonempty_keys": len(visible_source_keys - excluded_keys),
        "translated_unique_keys": len(translated_keys),
        "coverage_percent_of_nonempty_keys": round(
            100 * len(translated_keys) / len(visible_source_keys), 2
        ),
        "coverage_percent_of_eligible_keys": round(
            100 * len(translated_keys) / len(visible_source_keys - excluded_keys), 2
        ),
        "statuses_by_row": dict(sorted(statuses.items())),
        "categories": {
            category: {
                **counts,
                "coverage_percent": round(
                    100 * counts["translated_rows"] / counts["rows"], 2
                ),
            }
            for category, counts in sorted(categories.items())
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"Coverage: {report['translated_unique_keys']}/{report['nonempty_source_keys']} "
        f"non-empty unique keys ({report['coverage_percent_of_nonempty_keys']}%)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
