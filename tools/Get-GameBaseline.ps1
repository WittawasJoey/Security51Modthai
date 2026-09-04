param(
    [Parameter(Mandatory = $false)]
    [string]$GamePath = "D:\SteamLibrary\steamapps\common\Security 51",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot "..\reports\game-baseline.json"
}
$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path
$dataRoot = Join-Path $gameRoot "Security51_Data"

if (-not (Test-Path -LiteralPath (Join-Path $gameRoot "Security51.exe"))) {
    throw "Security51.exe was not found under: $gameRoot"
}

$coreRelativePaths = @(
    "Security51.exe",
    "UnityPlayer.dll",
    "GameAssembly.dll",
    "Security51_Data\globalgamemanagers",
    "Security51_Data\globalgamemanagers.assets",
    "Security51_Data\resources.assets",
    "Security51_Data\sharedassets0.assets",
    "Security51_Data\sharedassets1.assets",
    "Security51_Data\sharedassets2.assets",
    "Security51_Data\sharedassets3.assets",
    "Security51_Data\sharedassets4.assets",
    "Security51_Data\sharedassets5.assets",
    "Security51_Data\il2cpp_data\Metadata\global-metadata.dat"
)

$coreFiles = foreach ($relativePath in $coreRelativePaths) {
    $fullPath = Join-Path $gameRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        $item = Get-Item -LiteralPath $fullPath
        [ordered]@{
            path = $relativePath.Replace("\", "/")
            size = $item.Length
            sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
            lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString("o")
        }
    }
}

$knownModArtifacts = @(
    "winhttp.dll",
    "doorstop_config.ini",
    ".doorstop_version",
    "BepInEx",
    "AutoTranslator",
    "Security51_Data_ThaiMod",
    "Security51_Thai_Mod_Pack",
    "Install_Thai_Mod.bat",
    "Uninstall_Thai_Mod.bat",
    "README.md",
    "Security51_Data\StreamingAssets\I2Languages.csv",
    "Security51_Data\StreamingAssets\I2Languages.txt",
    "Security51_Data\StreamingAssets\LanguageSource.csv"
)

$artifacts = foreach ($relativePath in $knownModArtifacts) {
    $fullPath = Join-Path $gameRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        $item = Get-Item -LiteralPath $fullPath
        [ordered]@{
            path = $relativePath.Replace("\", "/")
            type = if ($item.PSIsContainer) { "directory" } else { "file" }
            size = if ($item.PSIsContainer) { $null } else { $item.Length }
        }
    }
}

$backupFiles = Get-ChildItem -LiteralPath $dataRoot -File -Filter "*.bak" | ForEach-Object {
    [ordered]@{
        path = ("Security51_Data/" + $_.Name)
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifestPath = "D:\SteamLibrary\steamapps\appmanifest_4246860.acf"
$manifestText = if (Test-Path -LiteralPath $manifestPath) {
    Get-Content -LiteralPath $manifestPath -Raw
} else {
    ""
}

$buildId = if ($manifestText -match '"buildid"\s+"([0-9]+)"') { $Matches[1] } else { $null }

$result = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    game = [ordered]@{
        name = "Security 51"
        appId = "4246860"
        buildId = $buildId
        unityVersion = "6000.3.8f1"
        backend = "IL2CPP"
        root = $gameRoot
    }
    coreFiles = @($coreFiles)
    knownModArtifacts = @($artifacts)
    backupFiles = @($backupFiles)
    notes = @(
        "Steam Verify repairs official files but does not remove unknown extra files.",
        "Presence in knownModArtifacts does not by itself mean that an artifact is currently loaded."
    )
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Baseline written to: $OutputPath"
Write-Output "Build ID: $buildId"
Write-Output "Core files hashed: $($coreFiles.Count)"
Write-Output "Known mod artifacts found: $($artifacts.Count)"
