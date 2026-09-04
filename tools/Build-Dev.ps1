param(
    [string]$DotnetPath = (Join-Path $PSScriptRoot "..\.tools\dotnet-sdk-6\dotnet.exe"),
    [string]$PythonPath = "C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$output = Join-Path $root "build\dev\BepInEx\plugins\Security51Thai"
$translationJson = Join-Path $output "strings.th.json"

& $PythonPath (Join-Path $PSScriptRoot "validate_translation.py")
if ($LASTEXITCODE -ne 0) { throw "Canonical translation validation failed." }

& $PythonPath (Join-Path $PSScriptRoot "export_translation_json.py") --output $translationJson
if ($LASTEXITCODE -ne 0) { throw "Translation export failed." }

$env:DOTNET_CLI_HOME = Join-Path $root ".tools"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
& $DotnetPath build (Join-Path $root "src\Security51ThaiMod\Security51ThaiMod.csproj") -c Release --nologo
if ($LASTEXITCODE -ne 0) { throw "Plugin build failed." }

Copy-Item -LiteralPath (Join-Path $root "src\Security51ThaiMod\bin\Release\net6.0\Security51ThaiMod.dll") -Destination $output -Force
$fontOutput = Join-Path $output "fonts"
New-Item -ItemType Directory -Path $fontOutput -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "fonts\NotoSansThai\NotoSansThai-Variable.ttf") -Destination $fontOutput -Force
Copy-Item -LiteralPath (Join-Path $root "fonts\NotoSansThai\OFL.txt") -Destination $fontOutput -Force

$packageRoot = Join-Path $root "build\dev"
$files = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring($packageRoot.Length).TrimStart('\').Replace('\', '/')
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$files | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $packageRoot "manifest.json") -Encoding UTF8
Write-Output "Development package created under: $packageRoot"
