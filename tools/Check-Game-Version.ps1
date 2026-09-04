param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
    [string]$VersionFile = (Join-Path $PSScriptRoot "..\version.json")
)

$ErrorActionPreference = "Stop"
$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
$versionPath = (Resolve-Path -LiteralPath $VersionFile).Path
$metadata = Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json

$steamApps = Split-Path -Parent (Split-Path -Parent $gameRoot)
$steamManifest = Join-Path $steamApps "appmanifest_4246860.acf"
if (-not (Test-Path -LiteralPath $steamManifest -PathType Leaf)) {
    throw "Steam manifest not found: $steamManifest"
}

$steamText = Get-Content -LiteralPath $steamManifest -Raw
if ($steamText -notmatch '"buildid"\s+"([0-9]+)"') {
    throw "Cannot read Steam build ID from: $steamManifest"
}
$installedBuildId = $Matches[1]
$compatibility = @($metadata.supportedGameBuilds) | Where-Object {
    [string]$_.buildId -eq $installedBuildId -and [string]$_.status -eq "supported"
} | Select-Object -First 1

Write-Output "Mod version: $($metadata.modVersion)-$($metadata.releaseChannel)"
Write-Output "Installed Steam build: $installedBuildId"

if ($null -eq $compatibility) {
    Write-Error "Security 51 build $installedBuildId is not supported. Extract, migrate, validate, and test before creating a new release."
    exit 2
}

$gameExe = Join-Path $gameRoot ([string]$compatibility.executable)
if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
    throw "Game executable not found: $gameExe"
}
$actualHash = (Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedHash = ([string]$compatibility.executableSha256).ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    Write-Error "Build ID matches, but executable SHA-256 differs. Expected $expectedHash, got $actualHash."
    exit 3
}

Write-Output "Compatibility: SUPPORTED"
Write-Output "Executable SHA-256: VERIFIED"
