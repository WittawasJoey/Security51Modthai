#!/usr/bin/env python3
"""Validate PoC translations against the extracted English corpus."""

from __future__ import annotations

import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path


PLACEHOLDER_RE = re.compile(r"\{[^{}]+\}")
RICH_TAG_RE = re.compile(r"</?[A-Za-z][^<>]*>")


def tokens(pattern: re.Pattern[str], value: str) -> Counter[str]:
    return Counter(pattern.findall(value))


root = Path(__file__).resolve().parent.parent
source_path = root / "translations" / "source_en" / "strings.csv"
poc_path = root / "translations" / "th" / "poc.json"

with source_path.open("r", encoding="utf-8-sig", newline="") as handle:
    source_rows = list(csv.DictReader(handle))
with poc_path.open("r", encoding="utf-8-sig") as handle:
    poc = json.load(handle)

source_by_key: dict[str, list[dict[str, str]]] = {}
for row in source_rows:
    source_by_key.setdefault(row["key"], []).append(row)

errors: list[str] = []
for key, thai in poc.items():
    candidates = source_by_key.get(key, [])
    if not candidates:
        errors.append(f"unknown key: {key}")
        continue
    if not isinstance(thai, str) or not thai.strip():
        errors.append(f"empty Thai text: {key}")
        continue
    english = candidates[0]["english"]
    if tokens(PLACEHOLDER_RE, english) != tokens(PLACEHOLDER_RE, thai):
        errors.append(f"placeholder mismatch: {key}")
    if tokens(RICH_TAG_RE, english) != tokens(RICH_TAG_RE, thai):
        errors.append(f"rich-text tag mismatch: {key}")
    if any(marker in thai for marker in ("à¸", "à¹", "�")):
        errors.append(f"possible mojibake: {key}")

print(f"PoC translations: {len(poc)}")
print(f"Errors: {len(errors)}")
for error in errors:
    print(f"ERROR: {error}", file=sys.stderr)
raise SystemExit(1 if errors else 0)

