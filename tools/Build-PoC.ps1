param(
    [string]$DotnetPath = (Join-Path $PSScriptRoot "..\.tools\dotnet-sdk-6\dotnet.exe"),
    [string]$PythonPath = "C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$output = Join-Path $root "build\poc\BepInEx\plugins\Security51Thai"

& $PythonPath (Join-Path $PSScriptRoot "validate_poc.py")
if ($LASTEXITCODE -ne 0) { throw "PoC translation validation failed." }

$env:DOTNET_CLI_HOME = Join-Path $root ".tools"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
& $DotnetPath build (Join-Path $root "src\Security51ThaiMod\Security51ThaiMod.csproj") -c Release --nologo
if ($LASTEXITCODE -ne 0) { throw "Plugin build failed." }

New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "src\Security51ThaiMod\bin\Release\net6.0\Security51ThaiMod.dll") -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $root "translations\th\poc.json") -Destination (Join-Path $output "strings.th.json") -Force
$fontOutput = Join-Path $output "fonts"
New-Item -ItemType Directory -Path $fontOutput -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "fonts\NotoSansThai\NotoSansThai-Variable.ttf") -Destination $fontOutput -Force
Copy-Item -LiteralPath (Join-Path $root "fonts\NotoSansThai\OFL.txt") -Destination $fontOutput -Force

$files = Get-ChildItem -LiteralPath (Join-Path $root "build\poc") -Recurse -File | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring((Join-Path $root "build\poc").Length).TrimStart('\').Replace('\', '/')
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$files | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $root "build\poc\manifest.json") -Encoding UTF8
Write-Output "PoC package created under: $(Join-Path $root 'build\poc')"
