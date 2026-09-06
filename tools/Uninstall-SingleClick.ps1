param(
    [string]$GamePath,
    [string]$PackagePath = $PSScriptRoot,
    [switch]$Force
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
        throw "Security 51 was not found in any Steam library. Use Uninstall-SingleClick.ps1 -GamePath <path> for a custom location."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple Security 51 installations were found. Use Uninstall-SingleClick.ps1 -GamePath <path> to select one."
    }
    return $matches[0]
}

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$gameRoot = Find-Security51Game -ExplicitPath $GamePath

Write-Output "Security 51 found: $gameRoot"

# Ensure game is not currently running
$gameExe = Join-Path $gameRoot "Security51.exe"
$targetExePath = [IO.Path]::GetFullPath($gameExe)
$runningTarget = Get-Process -Name "Security51" -ErrorAction SilentlyContinue | Where-Object {
    try { [IO.Path]::GetFullPath($_.Path) -eq $targetExePath } catch { $true }
}
if ($runningTarget) {
    throw "Security 51 is running. Please close the game before uninstalling."
}

$pointerPath = Join-Path $gameRoot "Security51ThaiMod.install.json"
$pluginDir = Join-Path $gameRoot "BepInEx\plugins\Security51Thai"
$uninstallerScript = Join-Path $packageRoot "Uninstall-ThaiMod.ps1"

if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf) -and -not (Test-Path -LiteralPath $pluginDir)) {
    Write-Output "Security 51 Thai Mod is not installed in: $gameRoot"
    exit 0
}

if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
    if (Test-Path -LiteralPath $uninstallerScript -PathType Leaf) {
        $uninstallArgs = @{ GamePath = $gameRoot }
        if ($Force) { $uninstallArgs["Force"] = $true }
        & $uninstallerScript @uninstallArgs
    } else {
        # Fallback if uninstaller script is missing
        $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $recordPath = [string]$pointer.installRecord
        if ($recordPath -and (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
            $record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($entry in $record.files) {
                $targetFile = [IO.Path]::GetFullPath((Join-Path $gameRoot ([string]$entry.path)))
                if (Test-Path -LiteralPath $targetFile) {
                    Remove-Item -LiteralPath $targetFile -Force -Recurse
                }
            }
        }
        Remove-Item -LiteralPath $pointerPath -Force
    }
}

$pluginDir = Join-Path $gameRoot "BepInEx\plugins\Security51Thai"
if (Test-Path -LiteralPath $pluginDir) {
    Write-Output "Removing Security51Thai plugin directory..."
    Remove-Item -LiteralPath $pluginDir -Recurse -Force
    Write-Output "Removed: $pluginDir"
}

Write-Output "Security 51 Thai Mod uninstalled successfully. Other BepInEx files were left untouched."
