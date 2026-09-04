# Game baseline

The authoritative machine-readable baseline is generated at
`reports/game-baseline.json` by `tools/Get-GameBaseline.ps1`.

The report records:

- Steam App ID and installed build ID
- Unity version and scripting backend
- SHA-256 and size of the main executable, IL2CPP metadata, and Unity asset files
- known artifacts left by the previous unsuccessful mod attempt
- backup files that Steam Verify does not remove

Regenerate the report after every official game update and before building or
installing a patch. A release installer must refuse to patch a build whose
supported hashes do not match.

