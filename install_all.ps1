$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = $scriptDir
$gamePathFile = Join-Path $projectRoot ".gamepath"

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
        if ($savedPath -and (Test-Path -LiteralPath $savedPath)) { return $savedPath }
    }
    return Select-HadesExe
}

function Find-ModExtensionDir {
    $candidates = @(
        (Join-Path $projectRoot "libs\hades2-mod-extension"),
        (Join-Path $projectRoot "..\hades2-mod-extension"),
        (Join-Path $projectRoot "..\..\hades2-coop-procject\hades2-mod-extension")
    )

    foreach ($candidate in $candidates) {
        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
        if ($resolved) { return $resolved.Path }
    }

    throw "Could not find hades2-mod-extension."
}

$cmake = Get-CMakePath

Write-Host "Using CMake: $cmake" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hades II Co-op Mod - full install" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project root: $projectRoot" -ForegroundColor Gray

$exePath = Get-HadesExePath
$gameExeDir = Split-Path -Parent $exePath
$gameDir = Split-Path -Parent $gameExeDir
$modsDir = Join-Path $gameDir "Content\Mods"
$pluginsDir = Join-Path $gameExeDir "plugins"
$returnOfModdingPath = Join-Path $gameExeDir "ReturnOfModding"
$useReturnOfModding = Test-Path -LiteralPath $returnOfModdingPath

Write-Host "Game exe: $exePath" -ForegroundColor Gray
Write-Host "Mods dir: $modsDir" -ForegroundColor Gray

$modExtDir = Find-ModExtensionDir
$modExtBuildDir = Join-Path $modExtDir "build_msvc"

Write-Host "`n[1/5] Configure hades2-mod-extension..." -ForegroundColor Yellow
& $cmake -A x64 "$modExtDir" -B "$modExtBuildDir"

Write-Host "`n[2/5] Build hades2-mod-extension..." -ForegroundColor Yellow
& $cmake --build "$modExtBuildDir" --target install --config Release

$asiPath = Join-Path $modExtDir "bin\HadesModNativeExtension.asi"
$coreSource = Join-Path $modExtDir "bin\TN_Core"
if (-not (Test-Path -LiteralPath $asiPath)) { throw "Build failed: HadesModNativeExtension.asi was not found at $asiPath" }
if (-not (Test-Path -LiteralPath $coreSource)) { throw "Build failed: TN_Core was not found at $coreSource" }

$coopBuildDir = Join-Path $projectRoot "build_msvc"

Write-Host "`n[3/5] Configure and build hades2-coop..." -ForegroundColor Yellow
& $cmake -A x64 "$projectRoot" -B "$coopBuildDir"
& $cmake --build "$coopBuildDir" --target install --config Release

$coopSourceCandidates = @(
    (Join-Path $projectRoot "bin\TN_CoopMod"),
    (Join-Path $coopBuildDir "bin\TN_CoopMod")
)
$coopSource = $null
foreach ($candidate in $coopSourceCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $coopSource = $candidate
        break
    }
}
if (-not $coopSource) { throw "Co-op build output was not found in bin\TN_CoopMod or build_msvc\bin\TN_CoopMod" }

$dllPath = Join-Path $coopSource "HadesCoopGame.dll"
if (-not (Test-Path -LiteralPath $dllPath)) { throw "Build failed: HadesCoopGame.dll was not found at $dllPath" }

Write-Host "`n[4/5] Install loader files..." -ForegroundColor Yellow
if (-not (Test-Path -LiteralPath $pluginsDir)) {
    New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
}
Copy-Item -LiteralPath $asiPath -Destination $pluginsDir -Force
Write-Host "Copied HadesModNativeExtension.asi" -ForegroundColor Green

if (-not $useReturnOfModding) {
    $hookedPath = Join-Path $gameExeDir "bink2w64Hooked.dll"
    $originalBink = Join-Path $gameExeDir "bink2w64.dll"

    if (-not (Test-Path -LiteralPath $hookedPath) -and (Test-Path -LiteralPath $originalBink)) {
        Move-Item -LiteralPath $originalBink -Destination $hookedPath -Force
        Write-Host "Backed up original bink2w64.dll" -ForegroundColor Green
    }

    $url = "https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases/download/x64-latest/bink2w64-x64.zip"
    $zipPath = Join-Path $env:TEMP "asi_loader.zip"
    $extractPath = Join-Path $env:TEMP "asi_loader_temp"

    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

    $dllSource = Get-ChildItem -LiteralPath $extractPath -Filter "bink2w64.dll" -Recurse | Select-Object -First 1
    if (-not $dllSource) { throw "Downloaded ASI loader archive did not contain bink2w64.dll" }

    Move-Item -LiteralPath $dllSource.FullName -Destination $originalBink -Force
    Remove-Item -LiteralPath $zipPath -Force
    Remove-Item -LiteralPath $extractPath -Recurse -Force
    Write-Host "Installed ASI loader bink2w64.dll" -ForegroundColor Green
} else {
    Write-Host "ReturnOfModding detected; skipped ASI loader install." -ForegroundColor Green
}

Write-Host "`n[5/5] Copy mod files..." -ForegroundColor Yellow
if (-not (Test-Path -LiteralPath $modsDir)) {
    New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
}

$coreDest = Join-Path $modsDir "TN_Core"
$coopDest = Join-Path $modsDir "TN_CoopMod"

if (Test-Path -LiteralPath $coreDest) { Remove-Item -LiteralPath $coreDest -Recurse -Force }
Copy-Item -LiteralPath $coreSource -Destination $modsDir -Recurse -Force

if (Test-Path -LiteralPath $coopDest) { Remove-Item -LiteralPath $coopDest -Recurse -Force }
Copy-Item -LiteralPath $coopSource -Destination $modsDir -Recurse -Force

Write-Host "`nInstall complete." -ForegroundColor Green
Write-Host "  $pluginsDir\HadesModNativeExtension.asi" -ForegroundColor White
Write-Host "  $modsDir\TN_Core" -ForegroundColor White
Write-Host "  $modsDir\TN_CoopMod" -ForegroundColor White
Write-Host "`nFor later Lua-only updates, run: .\dev_deploy.ps1" -ForegroundColor Gray
