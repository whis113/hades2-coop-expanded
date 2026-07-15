$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$source = Join-Path $projectRoot "tools\EnemyScalerNative\EnemyScaler.cpp"
$outputDirectory = Join-Path $projectRoot "tools\EnemyScalerNative\bin"
$output = Join-Path $outputDirectory "Hades2CoopEnemyScaler.exe"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "Visual Studio Build Tools with C++ support are required to build the native enemy scaler."
}

$visualStudioRoot = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ([string]::IsNullOrWhiteSpace($visualStudioRoot)) {
    throw "Visual Studio C++ tools were not found."
}

$vcvars = Join-Path $visualStudioRoot "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) {
    throw "Visual Studio C++ environment script was not found: $vcvars"
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$compileCommand = 'call "{0}" >nul && cl.exe /nologo /std:c++17 /O2 /MT /EHsc /DUNICODE /D_UNICODE "{1}" /Fe:"{2}" /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib comdlg32.lib' -f $vcvars, $source, $output
cmd.exe /d /c $compileCommand
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output)) {
    throw "Native enemy scaler build failed."
}

Write-Host "Built: $output" -ForegroundColor Green
