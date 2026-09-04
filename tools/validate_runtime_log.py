#!/usr/bin/env python3
"""Validate that the Security 51 Thai PoC initialized successfully at runtime."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path, help="Path to BepInEx/LogOutput.log")
args = parser.parse_args()

text = args.log.read_text(encoding="utf-8-sig", errors="replace")

required = {
    "BepInEx loader": "Chainloader startup complete",
    "Thai font fallback": "Created Thai TMP fallback",
}
errors: list[str] = []
for label, marker in required.items():
    if marker not in text:
        errors.append(f"missing runtime marker: {label}")

loaded_match = re.search(r"Security 51 Thai Mod .* loaded with (\d+) translations", text)
applied_match = re.search(r"Applied (\d+) Thai term values \(UpdateSources\)", text)
loaded_count = int(loaded_match.group(1)) if loaded_match else 0
applied_count = int(applied_match.group(1)) if applied_match else 0
if not loaded_match:
    errors.append("missing runtime marker: Thai plugin")
if not applied_match:
    errors.append("missing runtime marker: I2 injection")
if loaded_match and applied_match and loaded_count != applied_count:
    errors.append(
        f"translation count mismatch: loaded={loaded_count}, applied={applied_count}"
    )

plugin_error_lines = [
    line for line in text.splitlines()
    if "[Error  :Security 51 Thai Mod]" in line
]
if plugin_error_lines:
    errors.extend(f"plugin error: {line}" for line in plugin_error_lines)

marker_total = len(required) + 2
missing_markers = sum("missing runtime marker" in item for item in errors)
print(f"Runtime markers: {marker_total - missing_markers}/{marker_total}")
print(f"Translations loaded/applied: {loaded_count}/{applied_count}")
print(f"Plugin errors: {len(plugin_error_lines)}")
for error in errors:
    print(f"ERROR: {error}")
raise SystemExit(1 if errors else 0)
