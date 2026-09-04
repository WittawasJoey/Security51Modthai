# Tools

## Python runtime

The project currently uses Python 3.12 from the Codex workspace runtime.

## UnityPy

- Version: 1.25.3
- Local path: `.tools/python`
- Purpose: inspect standard Unity objects and export TextAssets
- Limitation: stripped IL2CPP MonoBehaviour type trees cannot be reconstructed by
  UnityPy alone for this game build.

## AssetRipper

- Version: 2.0.0 Free, Windows x64
- Source: official AssetRipper GitHub release
- Archive SHA-256: `9a7ef0e7c5c3ea5b90b4e6d855e2d98d5f7ec8c3f9e26fccbc194c6a7b01baf7`
- Purpose: reconstruct IL2CPP types from `GameAssembly.dll` and
  `global-metadata.dat`, inspect `I2Languages`, and export structured JSON

AssetRipper successfully initialized metadata version 39 for Unity `6000.3.8f1`
and reconstructed the `I2Languages` MonoBehaviour from `resources.assets`.

## Runtime PoC validator

`tools/validate_runtime_log.py` checks the latest BepInEx log for loader startup,
Thai plugin loading, I2 term injection, Thai TMP fallback creation, and plugin
errors. Pass the game log path explicitly so the project does not assume a fixed
Steam library location.

## Translation build pipeline

- `tools/import_translation_json.py` imports a bounded JSON translation batch
  into the canonical CSV while preserving protected source columns.
- `tools/export_translation_json.py` exports translated canonical rows and
  rejects conflicting translations for duplicate keys.
- `tools/Build-Dev.ps1` validates the full table, exports plugin JSON, builds the
  IL2CPP plugin, and writes a package checksum manifest.
- `tools/Build-Release.ps1` creates the mod-only release directory, checksum
  manifest, ZIP archive, and SHA-256 sidecar after running the development build.
- `tools/Install-ThaiMod.ps1` refuses unsupported game/BepInEx builds, validates
  every payload hash, backs up conflicts, and records the exact installed files.
- `tools/Uninstall-ThaiMod.ps1` restores only recorded conflicts and refuses to
  overwrite payload files modified after installation unless explicitly forced.
- `tools/report_translation_coverage.py` writes coverage by category and status
  to `reports/translation-coverage.json`.
- `tools/export_fallback_source.py` exports keys whose English slot is empty but
  whose Russian slot contains the only usable source text. The shared
  `tools/source_text.py` makes validation and coverage consistently prefer
  English and then Russian without rewriting the extracted source.
