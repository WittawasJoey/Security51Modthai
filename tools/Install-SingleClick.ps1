param(
    [string]$GamePath,
    [string]$PackagePath = $PSScriptRoot,
    [switch]$DetectOnly
)

$ErrorActionPreference = "Stop"

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($registryPath in @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )) {
        try {
            $item = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
            foreach ($propertyName in @("SteamPath", "InstallPath")) {
                $value = [string]$item.$propertyName
                if ($value) { $roots.Add($value.Replace('/', '\')) }
            }
        } catch { }
    }

    if (${env:ProgramFiles(x86)}) {
        $roots.Add((Join-Path ${env:ProgramFiles(x86)} "Steam"))
    }

    return @($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)
}

function Find-Security51Game {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        $resolved = (Resolve-Path -LiteralPath $ExplicitPath).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved "Security51.exe") -PathType Leaf)) {
            throw "Security51.exe not found under: $resolved"
        }
        return $resolved
    }

    $libraryRoots = New-Object System.Collections.Generic.List[string]
    foreach ($steamRoot in Get-SteamRoots) {
        $libraryRoots.Add($steamRoot)
        $libraryFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $libraryFile -PathType Leaf) {
            $libraryText = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($libraryText, '"path"\s+"([^"]+)"')) {
                $libraryRoots.Add($match.Groups[1].Value.Replace('\\', '\'))
            }
        }
    }

    $matches = @($libraryRoots | Select-Object -Unique | ForEach-Object {
        $candidate = Join-Path $_ "steamapps\common\Security 51"
        if (Test-Path -LiteralPath (Join-Path $candidate "Security51.exe") -PathType Leaf) {
            [IO.Path]::GetFullPath($candidate)
        }
    } | Select-Object -Unique)

    if ($matches.Count -eq 0) {
        throw "Security 51 was not found in any Steam library. Use Install-SingleClick.ps1 -GamePath <path> for a custom location."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple Security 51 installations were found. Use Install-SingleClick.ps1 -GamePath <path> to select one."
    }
    return $matches[0]
}

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$manifestPath = Join-Path $packageRoot "release-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Run this file from an extracted release folder containing release-manifest.json."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$gameRoot = Find-Security51Game -ExplicitPath $GamePath

Write-Output "Security 51 found: $gameRoot"
Write-Output "Package version: $($manifest.modVersion) (game build $($manifest.game.buildId))"
if ($DetectOnly) {
    Write-Output "Detection: OK"
    exit 0
}

$pointerPath = Join-Path $gameRoot "Security51ThaiMod.install.json"
if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
    $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $record = Get-Content -LiteralPath ([string]$pointer.installRecord) -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$record.modVersion -eq [string]$manifest.modVersion) {
        Write-Output "Security 51 Thai Mod $($manifest.modVersion) is already installed."
        exit 0
    }

    Write-Output "Updating Security 51 Thai Mod $($record.modVersion) to $($manifest.modVersion)..."
    & (Join-Path $packageRoot "Uninstall-ThaiMod.ps1") -GamePath $gameRoot
}

& (Join-Path $packageRoot "Install-ThaiMod.ps1") -GamePath $gameRoot -PackagePath $packageRoot
Write-Output "Single-click installation completed successfully."
