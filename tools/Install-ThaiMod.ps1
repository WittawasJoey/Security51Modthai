param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
    [string]$PackagePath = $PSScriptRoot,
    [string]$StateRoot = (Join-Path $env:LOCALAPPDATA "Security51ThaiMod")
)

$ErrorActionPreference = "Stop"

function Get-FullChildPath {
    param([string]$Parent, [string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "Rooted package path is forbidden: $RelativePath" }
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\')
    $childFull = [IO.Path]::GetFullPath((Join-Path $parentFull $RelativePath))
    if (-not $childFull.StartsWith($parentFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its expected root: $RelativePath"
    }
    return $childFull
}

$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path.TrimEnd('\')
$manifestPath = Join-Path $packageRoot "release-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "release-manifest.json not found in $packageRoot" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$manifest.schemaVersion -ne 1) { throw "Unsupported release manifest schema." }
$gameExe = Join-Path $gameRoot ([string]$manifest.game.executable)
if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) { throw "Security51.exe not found in $gameRoot" }
$targetExePath = [IO.Path]::GetFullPath($gameExe)
$runningTarget = Get-Process -Name "Security51" -ErrorAction SilentlyContinue | Where-Object {
    try { [IO.Path]::GetFullPath($_.Path) -eq $targetExePath } catch { $true }
}
if ($runningTarget) { throw "Security 51 is running from the target game directory. Close it before installing." }

$actualExeHash = (Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualExeHash -ne ([string]$manifest.game.executableSha256).ToLowerInvariant()) {
    throw "Unsupported or modified game executable. Expected SHA-256 $($manifest.game.executableSha256), got $actualExeHash"
}

$steamApps = Split-Path -Parent (Split-Path -Parent $gameRoot)
$steamManifest = Join-Path $steamApps "appmanifest_$($manifest.game.appId).acf"
if (-not (Test-Path -LiteralPath $steamManifest -PathType Leaf)) { throw "Steam app manifest not found: $steamManifest" }
$steamText = Get-Content -LiteralPath $steamManifest -Raw
if ($steamText -notmatch '"buildid"\s+"([0-9]+)"') { throw "Cannot read Steam build ID." }
if ($Matches[1] -ne [string]$manifest.game.buildId) { throw "Unsupported Steam build $($Matches[1]); expected $($manifest.game.buildId)." }

foreach ($required in $manifest.prerequisite.files) {
    $requiredPath = Get-FullChildPath -Parent $gameRoot -RelativePath ([string]$required.path)
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "$($manifest.prerequisite.name) $($manifest.prerequisite.version) is required." }
    $requiredHash = (Get-FileHash -LiteralPath $requiredPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($requiredHash -ne ([string]$required.sha256).ToLowerInvariant()) { throw "Unsupported prerequisite file: $($required.path)" }
}

$pointerPath = Join-Path $gameRoot "Security51ThaiMod.install.json"
if (Test-Path -LiteralPath $pointerPath) { throw "An install record already exists. Uninstall the current Thai mod first." }

foreach ($file in $manifest.files) {
    $sourcePath = Get-FullChildPath -Parent $packageRoot -RelativePath ([string]$file.path)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Package file missing: $($file.path)" }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne ([string]$file.sha256).ToLowerInvariant() -or (Get-Item -LiteralPath $sourcePath).Length -ne [long]$file.size) {
        throw "Package integrity check failed: $($file.path)"
    }
}

$installId = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$backupRoot = [IO.Path]::GetFullPath((Join-Path $StateRoot "backups\$installId"))
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$installed = @()
try {
    foreach ($file in $manifest.files) {
        $relativePath = [string]$file.path
        $sourcePath = Get-FullChildPath -Parent $packageRoot -RelativePath $relativePath
        $targetPath = Get-FullChildPath -Parent $gameRoot -RelativePath $relativePath
        $hadOriginal = Test-Path -LiteralPath $targetPath -PathType Leaf
        if ($hadOriginal) {
            $backupPath = Get-FullChildPath -Parent $backupRoot -RelativePath $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
            Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        $installed += [ordered]@{ path = $relativePath; installedSha256 = ([string]$file.sha256).ToLowerInvariant(); hadOriginal = $hadOriginal }
    }

    $record = [ordered]@{
        schemaVersion = 1
        modVersion = [string]$manifest.modVersion
        installedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        gameRoot = $gameRoot
        backupRoot = $backupRoot
        files = @($installed)
    }
    $recordPath = Join-Path $backupRoot "install-record.json"
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding UTF8
    [ordered]@{ schemaVersion = 1; installRecord = $recordPath } | ConvertTo-Json | Set-Content -LiteralPath $pointerPath -Encoding UTF8
} catch {
    [array]::Reverse($installed)
    foreach ($entry in $installed) {
        $targetPath = Get-FullChildPath -Parent $gameRoot -RelativePath ([string]$entry.path)
        $backupPath = Get-FullChildPath -Parent $backupRoot -RelativePath ([string]$entry.path)
        if ([bool]$entry.hadOriginal -and (Test-Path -LiteralPath $backupPath)) { Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force }
        elseif (Test-Path -LiteralPath $targetPath) { Remove-Item -LiteralPath $targetPath -Force }
    }
    throw
}

Write-Output "Security 51 Thai Mod $($manifest.modVersion) installed."
Write-Output "Install record: $recordPath"
