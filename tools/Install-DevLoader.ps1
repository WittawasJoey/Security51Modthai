param(
    [string]$GamePath = "D:\SteamLibrary\steamapps\common\Security 51",
    [string]$LoaderPath = (Join-Path $PSScriptRoot "..\.tools\BepInEx-6.0.0-be.785+6abdba4"),
    [string]$LoaderVersion = "6.0.0-be.785+6abdba4",
    [string]$BackupRoot = (Join-Path $PSScriptRoot "..\backups")
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

$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
$loaderRoot = (Resolve-Path -LiteralPath $LoaderPath).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $gameRoot "Security51.exe"))) {
    throw "Security51.exe not found under $gameRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $loaderRoot "winhttp.dll"))) {
    throw "Staged BepInEx loader not found under $loaderRoot"
}
if (Get-Process -Name "Security51" -ErrorAction SilentlyContinue) {
    throw "Security 51 is currently running. Close it before installing the development loader."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDirectory = [IO.Path]::GetFullPath((Join-Path $BackupRoot "pre-bepinex-$timestamp"))
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$legacyTargets = @(
    ".doorstop_version",
    "doorstop_config.ini",
    "winhttp.dll",
    "BepInEx",
    "AutoTranslator",
    "dotnet",
    "mono",
    "Security51_Data_ThaiMod",
    "Security51_Thai_Mod_Pack",
    "Install_Thai_Mod.bat",
    "Uninstall_Thai_Mod.bat",
    "README.md",
    "preloader_20260827_211636_766.log",
    "preloader_20260827_211654_590.log",
    "Security51_Data\StreamingAssets\I2Languages.csv",
    "Security51_Data\StreamingAssets\I2Languages.txt",
    "Security51_Data\StreamingAssets\LanguageSource.csv"
)

$moved = @()
foreach ($relativePath in $legacyTargets) {
    $sourcePath = Join-Path $gameRoot $relativePath
    Assert-ChildPath -Parent $gameRoot -Child $sourcePath
    if (Test-Path -LiteralPath $sourcePath) {
        $destinationPath = Join-Path $backupDirectory $relativePath
        Assert-ChildPath -Parent $backupDirectory -Child $destinationPath
        $destinationParent = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        Move-Item -LiteralPath $sourcePath -Destination $destinationPath
        $moved += $relativePath.Replace('\', '/')
    }
}

$assetBackupDirectory = Join-Path $backupDirectory "Security51_Data"
New-Item -ItemType Directory -Path $assetBackupDirectory -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $gameRoot "Security51_Data") -File -Filter "*.bak" | ForEach-Object {
    Assert-ChildPath -Parent $gameRoot -Child $_.FullName
    Move-Item -LiteralPath $_.FullName -Destination (Join-Path $assetBackupDirectory $_.Name)
    $moved += "Security51_Data/$($_.Name)"
}

$packageFiles = Get-ChildItem -LiteralPath $loaderRoot -Recurse -File
foreach ($file in $packageFiles) {
    $relativePath = $file.FullName.Substring($loaderRoot.Length).TrimStart('\')
    $destinationPath = Join-Path $gameRoot $relativePath
    Assert-ChildPath -Parent $gameRoot -Child $destinationPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
}

$record = [ordered]@{
    schemaVersion = 1
    installedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    gameRoot = $gameRoot
    loaderVersion = $LoaderVersion
    loaderSource = $loaderRoot
    backupDirectory = $backupDirectory
    movedLegacyPaths = @($moved)
    installedPackagePaths = @($packageFiles | ForEach-Object {
        $_.FullName.Substring($loaderRoot.Length).TrimStart('\').Replace('\', '/')
    })
}
$recordPath = Join-Path $backupDirectory "install-record.json"
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8

Write-Output "Development loader installed."
Write-Output "Backup: $backupDirectory"
Write-Output "Legacy paths moved: $($moved.Count)"
Write-Output "Loader files copied: $($packageFiles.Count)"
