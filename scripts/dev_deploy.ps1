$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$gamePathFile = Join-Path $projectRoot ".gamepath"

function Select-HadesExe {
    $browser = New-Object System.Windows.Forms.OpenFileDialog
    $browser.InitialDirectory = [Environment]::GetFolderPath('MyComputer')
    $browser.Filter = "Executable Files (*.exe)|Hades2.exe"
    $browser.Title = "Select Hades2.exe"

    if ($browser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Canceled." -ForegroundColor Yellow
        exit 1
    }

    $browser.FileName | Out-File -LiteralPath $gamePathFile -Encoding UTF8
    return $browser.FileName
}

function Get-HadesExePath {
    if (Test-Path -LiteralPath $gamePathFile) {
        $savedPath = (Get-Content -LiteralPath $gamePathFile -Raw).Trim()
        if ($savedPath -and (Test-Path -LiteralPath $savedPath)) {
            return $savedPath
        }
    }

    return Select-HadesExe
}

function Get-CoopOutputDir {
    $candidates = @(
        (Join-Path $projectRoot "bin\TN_CoopMod"),
        (Join-Path $projectRoot "build_msvc\bin\TN_CoopMod")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "Co-op build output was not found. Run .\scripts\build_and_deploy.ps1 or cmake --build build_msvc --target install --config Release first."
}

$buildPath = Get-CoopOutputDir
$gameExePath = Get-HadesExePath
$gameExeDir = Split-Path -Path $gameExePath -Parent
$gameDir = Split-Path -Path $gameExeDir -Parent
$modsDir = Join-Path $gameDir "Content\Mods\TN_CoopMod"

Write-Host "Source: $buildPath" -ForegroundColor Gray
Write-Host "Target: $modsDir" -ForegroundColor Gray

if (-not (Test-Path -LiteralPath $modsDir)) {
    throw "Target mod directory does not exist. Run .\scripts\install_all.ps1 first."
}

Write-Host "`nCopying changed files..." -ForegroundColor Cyan

$copyCount = 0
$skipCount = 0

Get-ChildItem -LiteralPath $buildPath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($buildPath.Length + 1)
    $targetFile = Join-Path $modsDir $relativePath
    $targetDir = Split-Path -Parent $targetFile

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $needsCopy = $false
    if (-not (Test-Path -LiteralPath $targetFile)) {
        $needsCopy = $true
    } else {
        $sourceHash = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash
        $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm MD5).Hash
        if ($sourceHash -ne $targetHash) {
            $needsCopy = $true
        } else {
            $skipCount++
        }
    }

    if ($needsCopy) {
        Copy-Item -LiteralPath $_.FullName -Destination $targetFile -Force
        $copyCount++
        Write-Host "  copied $relativePath" -ForegroundColor Green
    }
}

Write-Host "`nDeploy complete." -ForegroundColor Green
Write-Host "  copied: $copyCount files" -ForegroundColor White
Write-Host "  skipped: $skipCount files" -ForegroundColor Gray

$dllPath = Join-Path $modsDir "HadesCoopGame.dll"
if (Test-Path -LiteralPath $dllPath) {
    $dllTime = (Get-Item -LiteralPath $dllPath).LastWriteTime
    Write-Host "`nDLL last write time: $dllTime" -ForegroundColor Cyan
}
