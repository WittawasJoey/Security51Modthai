"""Shared source-text fallback helpers for extracted I2 localization data."""

from __future__ import annotations

import csv
from pathlib import Path


def load_fallbacks(path: Path) -> dict[str, tuple[str, str]]:
    """Return key -> (text, language), preferring English and then Russian."""
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    result: dict[str, tuple[str, str]] = {}
    for row in rows:
        key = row["Key []"]
        english = row["English [en]"]
        russian = row["Russian [ru]"]
        if english:
            result[key] = (english, "en")
        elif russian:
            result[key] = (russian, "ru")
    return result
