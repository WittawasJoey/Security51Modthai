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

function Test-PreflightChecks {
    param(
        [string]$GameRoot,
        [string]$PackageRoot,
        [psobject]$Manifest
    )

    $gameExe = Join-Path $GameRoot ([string]$Manifest.game.executable)
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
        throw "Security51.exe not found in $GameRoot"
    }

    $targetExePath = [IO.Path]::GetFullPath($gameExe)
    $runningTarget = Get-Process -Name "Security51" -ErrorAction SilentlyContinue | Where-Object {
        try { [IO.Path]::GetFullPath($_.Path) -eq $targetExePath } catch { $true }
    }
    if ($runningTarget) {
        throw "Security 51 is running from the target game directory. Close it before installing."
    }

    $actualExeHash = (Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualExeHash -ne ([string]$Manifest.game.executableSha256).ToLowerInvariant()) {
        throw "Unsupported or modified game executable. Expected SHA-256 $($Manifest.game.executableSha256), got $actualExeHash"
    }

    $steamApps = Split-Path -Parent (Split-Path -Parent $GameRoot)
    $steamManifest = Join-Path $steamApps "appmanifest_$($Manifest.game.appId).acf"
    if (Test-Path -LiteralPath $steamManifest -PathType Leaf) {
        $steamText = Get-Content -LiteralPath $steamManifest -Raw
        if ($steamText -match '"buildid"\s+"([0-9]+)"') {
            if ($Matches[1] -ne [string]$Manifest.game.buildId) {
                throw "Unsupported Steam build $($Matches[1]); expected $($Manifest.game.buildId)."
            }
        }
    }

    foreach ($required in $Manifest.prerequisite.files) {
        $requiredPath = [IO.Path]::GetFullPath((Join-Path $GameRoot ([string]$required.path)))
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "$($Manifest.prerequisite.name) $($Manifest.prerequisite.version) is required ($($required.path) missing)."
        }
        $requiredHash = (Get-FileHash -LiteralPath $requiredPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($requiredHash -ne ([string]$required.sha256).ToLowerInvariant()) {
            throw "Prerequisite integrity failure: $($required.path)"
        }
    }

    foreach ($file in $Manifest.files) {
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $PackageRoot ([string]$file.path)))
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Package payload file missing: $($file.path)"
        }
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -ne ([string]$file.sha256).ToLowerInvariant()) {
            throw "Package payload corrupted: $($file.path)"
        }
    }
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

Write-Output "Running pre-flight validation..."
Test-PreflightChecks -GameRoot $gameRoot -PackageRoot $packageRoot -Manifest $manifest
Write-Output "Pre-flight validation passed."

$pointerPath = Join-Path $gameRoot "Security51ThaiMod.install.json"
$needsUninstall = $false
if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
    $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $recordPath = [string]$pointer.installRecord
    if ($recordPath -and (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
        $record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$record.modVersion -eq [string]$manifest.modVersion) {
            # Check if installed files are intact
            $isCorrupted = $false
            foreach ($file in $manifest.files) {
                $targetFile = [IO.Path]::GetFullPath((Join-Path $gameRoot ([string]$file.path)))
                if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
                    $isCorrupted = $true
                    break
                }
                $fileHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($fileHash -ne ([string]$file.sha256).ToLowerInvariant()) {
                    $isCorrupted = $true
                    break
                }
            }

            if (-not $isCorrupted) {
                Write-Output "Security 51 Thai Mod $($manifest.modVersion) is already installed and verified intact."
                exit 0
            }
            Write-Warning "Existing installation of version $($manifest.modVersion) has missing or modified files. Re-installing / repairing..."
        } else {
            Write-Output "Updating Security 51 Thai Mod $($record.modVersion) to $($manifest.modVersion)..."
        }
        $needsUninstall = $true
    } else {
        Write-Warning "Orphaned install pointer found without backing record. Cleaning up pointer..."
        Remove-Item -LiteralPath $pointerPath -Force
    }
}

if ($needsUninstall) {
    & (Join-Path $packageRoot "Uninstall-ThaiMod.ps1") -GamePath $gameRoot
}

& (Join-Path $packageRoot "Install-ThaiMod.ps1") -GamePath $gameRoot -PackagePath $packageRoot
Write-Output "Single-click installation completed successfully."
