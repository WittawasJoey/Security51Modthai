#!/usr/bin/env python3
"""Convert AssetRipper's I2Languages MonoBehaviour JSON to translation files."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path


PLACEHOLDER_RE = re.compile(r"\{[^{}]+\}")
RICH_TAG_RE = re.compile(r"</?[A-Za-z][^<>]*>")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="AssetRipper JSON for I2Languages")
    parser.add_argument("--output-root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    with args.input.open("r", encoding="utf-8-sig") as handle:
        asset = json.load(handle)

    source = asset["m_Structure"]["mSource"]
    languages = source["mLanguages"]
    terms = source["mTerms"]
    language_columns = [f'{item["Name"]} [{item["Code"]}]' for item in languages]

    full_rows: list[dict[str, object]] = []
    source_rows: list[dict[str, object]] = []
    thai_rows: list[dict[str, object]] = []
    category_counts: Counter[str] = Counter()
    duplicate_keys: Counter[str] = Counter()
    missing_english = 0
    placeholder_entries = 0
    rich_tag_entries = 0

    for index, term in enumerate(terms):
        key = term.get("Term", "")
        values = list(term.get("Languages", []))
        values.extend([""] * (len(languages) - len(values)))
        values = values[: len(languages)]
        mapping = dict(zip(language_columns, values, strict=True))
        english = values[2] if len(values) > 2 else ""
        description = values[1] if len(values) > 1 else ""
        category = key.split("/", 1)[0] if "/" in key else "(root)"
        placeholders = sorted(set(PLACEHOLDER_RE.findall(english)))
        rich_tags = sorted(set(RICH_TAG_RE.findall(english)))

        duplicate_keys[key] += 1
        category_counts[category] += 1
        missing_english += not bool(english.strip())
        placeholder_entries += bool(placeholders)
        rich_tag_entries += bool(rich_tags)

        full_rows.append(
            {
                "index": index,
                "key": key,
                "term_type": term.get("TermType", 0),
                **mapping,
            }
        )
        source_rows.append(
            {
                "index": index,
                "key": key,
                "category": category,
                "term_type": term.get("TermType", 0),
                "description": description,
                "english": english,
                "placeholders": " | ".join(placeholders),
                "rich_text_tags": " | ".join(rich_tags),
            }
        )
        thai_rows.append(
            {
                "index": index,
                "key": key,
                "english": english,
                "thai": "",
                "status": "untranslated",
                "notes": "",
            }
        )

    output_root = args.output_root
    write_csv(
        output_root / "source" / "i2_all_languages.csv",
        ["index", "key", "term_type", *language_columns],
        full_rows,
    )
    write_csv(
        output_root / "translations" / "source_en" / "strings.csv",
        [
            "index",
            "key",
            "category",
            "term_type",
            "description",
            "english",
            "placeholders",
            "rich_text_tags",
        ],
        source_rows,
    )
    write_csv(
        output_root / "translations" / "th" / "strings.csv",
        ["index", "key", "english", "thai", "status", "notes"],
        thai_rows,
    )

    duplicate_list = [
        {"key": key, "count": count}
        for key, count in sorted(duplicate_keys.items())
        if count > 1
    ]
    report = {
        "schemaVersion": 1,
        "source": str(args.input),
        "sourceSha256": sha256(args.input),
        "assetName": asset.get("m_Name"),
        "languageCount": len(languages),
        "languages": languages,
        "termCount": len(terms),
        "uniqueKeyCount": len(duplicate_keys),
        "duplicateKeyCount": len(duplicate_list),
        "duplicates": duplicate_list,
        "missingEnglishCount": missing_english,
        "entriesWithPlaceholders": placeholder_entries,
        "entriesWithRichTextTags": rich_tag_entries,
        "categoryCounts": dict(category_counts.most_common()),
    }
    report_path = output_root / "reports" / "i2-extraction-report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(f"Languages: {len(languages)}")
    print(f"Terms: {len(terms)} ({len(duplicate_keys)} unique keys)")
    print(f"Duplicate keys: {len(duplicate_list)}")
    print(f"Missing English: {missing_english}")
    print(f"Report: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

