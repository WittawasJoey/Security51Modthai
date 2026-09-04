param(
    [Parameter(Mandatory = $true)]
    [string]$InstallRecord
)

$ErrorActionPreference = "Stop"

function Assert-ChildPath {
    param([string]$Parent, [string]$Child)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside expected root: $childFull"
    }
}

$recordPath = (Resolve-Path -LiteralPath $InstallRecord).Path
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$gameRoot = [IO.Path]::GetFullPath([string]$record.gameRoot).TrimEnd('\')
$backupDirectory = [IO.Path]::GetFullPath([string]$record.backupDirectory).TrimEnd('\')

if (-not (Test-Path -LiteralPath (Join-Path $gameRoot "Security51.exe"))) {
    throw "The recorded game root is invalid: $gameRoot"
}
if (-not (Test-Path -LiteralPath $backupDirectory)) {
    throw "The recorded backup directory no longer exists: $backupDirectory"
}
if (Get-Process -Name "Security51" -ErrorAction SilentlyContinue) {
    throw "Security 51 is currently running. Close it before restoring files."
}

# Remove only the loader roots and root files installed by this development run.
foreach ($relativePath in @("BepInEx", "dotnet", ".doorstop_version", "doorstop_config.ini", "winhttp.dll", "changelog.txt")) {
    $targetPath = Join-Path $gameRoot $relativePath
    Assert-ChildPath -Parent $gameRoot -Child $targetPath
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }
}

foreach ($relativePathValue in $record.movedLegacyPaths) {
    $relativePath = ([string]$relativePathValue).Replace('/', '\')
    $sourcePath = Join-Path $backupDirectory $relativePath
    $destinationPath = Join-Path $gameRoot $relativePath
    Assert-ChildPath -Parent $backupDirectory -Child $sourcePath
    Assert-ChildPath -Parent $gameRoot -Child $destinationPath
    if (Test-Path -LiteralPath $sourcePath) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
        Move-Item -LiteralPath $sourcePath -Destination $destinationPath
    }
}

Write-Output "Pre-development state restored from: $backupDirectory"

