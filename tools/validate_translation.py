#!/usr/bin/env python3
"""Validate the Thai translation table against extracted English source."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter
from pathlib import Path

from source_text import load_fallbacks


PLACEHOLDER_RE = re.compile(r"\{[^{}]+\}")
RICH_TAG_RE = re.compile(r"</?[A-Za-z][^<>]*>")
CONTROL_TOKEN_RE = re.compile(r"\[(?:LMB|RMB|MMB|[A-Z][A-Z0-9_-]*)\]")
MOJIBAKE_MARKERS = ("à¸", "à¹", "ï»¿", "�")
VALID_STATUSES = {"untranslated", "draft", "reviewed", "in-game verified", "excluded"}


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def tokens(pattern: re.Pattern[str], text: str) -> Counter[str]:
    return Counter(pattern.findall(text or ""))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("translations/source_en/strings.csv"),
    )
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path("translations/th/strings.csv"),
    )
    parser.add_argument(
        "--all-languages",
        type=Path,
        default=Path("source/i2_all_languages.csv"),
    )
    args = parser.parse_args()

    source_rows = read_rows(args.source)
    thai_rows = read_rows(args.translation)
    fallback_by_key = load_fallbacks(args.all_languages)
    errors: list[str] = []
    warnings: list[str] = []

    if len(source_rows) != len(thai_rows):
        errors.append(f"row count differs: source={len(source_rows)} thai={len(thai_rows)}")

    translated = 0
    reviewed = 0
    for position, (source, target) in enumerate(zip(source_rows, thai_rows), start=2):
        identity = f"row {position} ({source.get('key', '')})"
        for field in ("index", "key", "english"):
            if source.get(field, "") != target.get(field, ""):
                errors.append(f"{identity}: protected field '{field}' differs")

        status = target.get("status", "")
        thai = target.get("thai", "")
        if status not in VALID_STATUSES:
            errors.append(f"{identity}: invalid status '{status}'")
        if status in {"draft", "reviewed", "in-game verified"} and not thai.strip():
            errors.append(f"{identity}: status is '{status}' but Thai text is empty")
        if thai.strip() and status == "untranslated":
            warnings.append(f"{identity}: Thai text exists but status is untranslated")
        if any(marker in thai for marker in MOJIBAKE_MARKERS):
            errors.append(f"{identity}: possible mojibake in Thai text")

        if thai.strip():
            comparison_source = source.get("english", "")
            if not comparison_source:
                comparison_source = fallback_by_key.get(source.get("key", ""), ("", ""))[0]
            translated += 1
            reviewed += status in {"reviewed", "in-game verified"}
            if tokens(PLACEHOLDER_RE, comparison_source) != tokens(PLACEHOLDER_RE, thai):
                errors.append(f"{identity}: placeholder set/count differs")
            if tokens(RICH_TAG_RE, comparison_source) != tokens(RICH_TAG_RE, thai):
                errors.append(f"{identity}: rich-text tag set/count differs")
            if tokens(CONTROL_TOKEN_RE, comparison_source) != tokens(CONTROL_TOKEN_RE, thai):
                errors.append(f"{identity}: control-token set/count differs")
            source_line_breaks = comparison_source.count("\n")
            target_line_breaks = thai.count("\n")
            allow_line_break_change = "[allow-linebreak-change]" in target.get("notes", "")
            if source_line_breaks != target_line_breaks and not allow_line_break_change:
                errors.append(
                    f"{identity}: line-break count differs "
                    f"(source={source_line_breaks}, Thai={target_line_breaks})"
                )

    source_identities = Counter((row.get("index", ""), row.get("key", "")) for row in source_rows)
    target_identities = Counter((row.get("index", ""), row.get("key", "")) for row in thai_rows)
    if source_identities != target_identities:
        errors.append("source/translation row identities differ")

    print(f"Rows: {len(source_rows)}")
    print(f"Thai entries: {translated}")
    print(f"Reviewed entries: {reviewed}")
    print(f"Warnings: {len(warnings)}")
    print(f"Errors: {len(errors)}")
    for warning in warnings[:50]:
        print(f"WARNING: {warning}")
    for error in errors[:100]:
        print(f"ERROR: {error}", file=sys.stderr)
    if len(warnings) > 50:
        print(f"WARNING: {len(warnings) - 50} additional warnings omitted")
    if len(errors) > 100:
        print(f"ERROR: {len(errors) - 100} additional errors omitted", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
