param(
    [string]$GameBuildId = "25104142",
    [string]$PythonPath = "C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$versionMetadata = Get-Content -LiteralPath (Join-Path $projectRoot "version.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$Version = [string]$versionMetadata.modVersion
$gameCompatibility = @($versionMetadata.supportedGameBuilds) | Where-Object {
    [string]$_.buildId -eq $GameBuildId -and [string]$_.status -eq "supported"
} | Select-Object -First 1
if ($null -eq $gameCompatibility) { throw "Game build $GameBuildId is not marked supported in version.json." }

$pluginSource = Get-Content -LiteralPath (Join-Path $projectRoot "src\Security51ThaiMod\Plugin.cs") -Raw
if ($pluginSource -notmatch ('PluginVersion\s*=\s*"' + [regex]::Escape($Version) + '"')) {
    throw "PluginVersion does not match version.json modVersion $Version."
}

$releaseName = "Security51ThaiMod-v$Version-game$GameBuildId"
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "build\release\$releaseName"))
$releaseBase = [IO.Path]::GetFullPath((Join-Path $projectRoot "build\release"))
if (-not $releaseRoot.StartsWith($releaseBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing release path outside build/release: $releaseRoot"
}

& (Join-Path $PSScriptRoot "Build-Dev.ps1") -PythonPath $PythonPath
if ($LASTEXITCODE -ne 0) { throw "Development build failed." }

if (Test-Path -LiteralPath $releaseRoot) {
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null

$payloadSource = Join-Path $projectRoot "build\dev\BepInEx"
Copy-Item -LiteralPath $payloadSource -Destination (Join-Path $releaseRoot "BepInEx") -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-ThaiMod.ps1") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Uninstall-ThaiMod.ps1") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-SingleClick.ps1") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-SingleClick.cmd") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $projectRoot "README.md") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $projectRoot "CHANGELOG.md") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $projectRoot "version.json") -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $projectRoot "docs\GAME_UPDATE_WORKFLOW.md") -Destination $releaseRoot

$payloadFiles = Get-ChildItem -LiteralPath (Join-Path $releaseRoot "BepInEx") -Recurse -File | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring($releaseRoot.Length).TrimStart('\').Replace('\', '/')
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    modVersion = $Version
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    game = [ordered]@{
        appId = [string]$gameCompatibility.appId
        buildId = [string]$gameCompatibility.buildId
        executable = [string]$gameCompatibility.executable
        executableSha256 = [string]$gameCompatibility.executableSha256
    }
    prerequisite = [ordered]@{
        name = "BepInEx Unity IL2CPP x64"
        version = "6.0.0-be.785+6abdba4"
        files = @(
            [ordered]@{ path = "BepInEx/core/BepInEx.Core.dll"; sha256 = "352aacc2d5356489a00891f76db28b6463c81d25bcb02f90035171a669b7e35b" },
            [ordered]@{ path = "BepInEx/core/BepInEx.Unity.IL2CPP.dll"; sha256 = "62c8246a3076bfe459ec80c482381228d0eb1dde3434fe97ae5255fef406fe72" }
        )
    }
    files = @($payloadFiles)
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseRoot "release-manifest.json") -Encoding UTF8

$archivePath = "$releaseRoot.zip"
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
Compress-Archive -LiteralPath $releaseRoot -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$archivePath.sha256" -Value "$archiveHash  $([IO.Path]::GetFileName($archivePath))" -Encoding ASCII

Write-Output "Release package: $releaseRoot"
Write-Output "Archive: $archivePath"
Write-Output "SHA-256: $archiveHash"
