param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-FullChildPath {
    param([string]$Parent, [string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "Rooted recorded path is forbidden: $RelativePath" }
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\')
    $childFull = [IO.Path]::GetFullPath((Join-Path $parentFull $RelativePath))
    if (-not $childFull.StartsWith($parentFull + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Recorded path escapes its expected root: $RelativePath" }
    return $childFull
}

$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
$targetExePath = [IO.Path]::GetFullPath((Join-Path $gameRoot "Security51.exe"))
$runningTarget = Get-Process -Name "Security51" -ErrorAction SilentlyContinue | Where-Object {
    try { [IO.Path]::GetFullPath($_.Path) -eq $targetExePath } catch { $true }
}
if ($runningTarget) { throw "Security 51 is running from the target game directory. Close it before uninstalling." }

$pointerPath = Join-Path $gameRoot "Security51ThaiMod.install.json"
if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) { throw "Thai mod install record not found in $gameRoot" }
$pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$recordPath = (Resolve-Path -LiteralPath ([string]$pointer.installRecord)).Path
$record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$record.schemaVersion -ne 1 -or [IO.Path]::GetFullPath([string]$record.gameRoot).TrimEnd('\') -ne $gameRoot) { throw "Install record does not match this game directory." }
$backupRoot = (Resolve-Path -LiteralPath ([string]$record.backupRoot)).Path.TrimEnd('\')

foreach ($entry in $record.files) {
    $targetPath = Get-FullChildPath -Parent $gameRoot -RelativePath ([string]$entry.path)
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        $currentHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if (-not $Force -and $currentHash -ne ([string]$entry.installedSha256).ToLowerInvariant()) {
            throw "Installed file was modified after installation: $($entry.path). Re-run with -Force only if overwriting it is intended."
        }
    }
}

foreach ($entry in $record.files) {
    $relativePath = [string]$entry.path
    $targetPath = Get-FullChildPath -Parent $gameRoot -RelativePath $relativePath
    $backupPath = Get-FullChildPath -Parent $backupRoot -RelativePath $relativePath
    if ([bool]$entry.hadOriginal) {
        if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) { throw "Required backup is missing: $relativePath" }
        New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
        Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force
    } elseif (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Force
    }
}
Remove-Item -LiteralPath $pointerPath -Force
Write-Output "Security 51 Thai Mod uninstalled. Other BepInEx files were left untouched."
Write-Output "Backup retained at: $backupRoot"
