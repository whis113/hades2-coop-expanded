$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$buildDir = Join-Path $projectRoot "build_msvc"

function Get-CMakePath {
    $command = Get-Command cmake -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.CMake.Project -property installationPath
        if ($vsPath) {
            $candidate = Join-Path $vsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }

    $candidates = @(
        "C:\Program Files\CMake\bin\cmake.exe",
        "C:\Program Files (x86)\CMake\bin\cmake.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    throw "cmake.exe was not found. Install CMake, add it to PATH, or install Visual Studio's CMake component."
}

$cmake = Get-CMakePath

Write-Host "Using CMake: $cmake" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hades II Co-op Mod - build and deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Configure CMake..." -ForegroundColor Yellow
& $cmake -A x64 "$projectRoot" -B "$buildDir"

Write-Host "`n[2/3] Build install target..." -ForegroundColor Yellow
& $cmake --build "$buildDir" --target install --config Release

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host "`n[3/3] Deploy to game directory..." -ForegroundColor Yellow
& (Join-Path $scriptDir "dev_deploy.ps1")

Write-Host "`nBuild and deploy complete." -ForegroundColor Green
