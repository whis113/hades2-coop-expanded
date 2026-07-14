$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerProject = Join-Path $scriptDir "tools\TesterInstaller\Hades2CoopInstaller.csproj"
$modSource = Join-Path $scriptDir "bin\TN_CoopMod"
$releaseDir = Join-Path $scriptDir "release\Hades2Coop-v0.2-TestBuild"
$publishDir = Join-Path $scriptDir "tools\TesterInstaller\bin\Release\net8.0-windows\win-x64\publish"

if (-not (Test-Path -LiteralPath (Join-Path $modSource "HadesCoopGame.dll"))) {
    throw "Missing build output: $modSource. Run .\build_and_deploy.ps1 first."
}

Write-Host "Publishing self-contained installer..." -ForegroundColor Cyan
dotnet publish $installerProject -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) {
    throw "Installer publish failed with exit code $LASTEXITCODE"
}

Write-Host "Creating tester package..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $releaseDir) {
    Remove-Item -LiteralPath $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $publishDir "Hades2CoopInstaller.exe") -Destination $releaseDir -Force
Copy-Item -LiteralPath $modSource -Destination (Join-Path $releaseDir "TN_CoopMod") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $scriptDir "TESTER_README.md") -Destination $releaseDir -Force
Copy-Item -LiteralPath (Join-Path $scriptDir "LICENSE.txt") -Destination $releaseDir -Force

$zipPath = Join-Path $scriptDir "release\Hades2Coop-v0.2-TestBuild.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
$packageItems = Get-ChildItem -LiteralPath $releaseDir -Force
Compress-Archive -Path $packageItems.FullName -DestinationPath $zipPath -Force

Write-Host "Tester package created:" -ForegroundColor Green
Write-Host "  Folder: $releaseDir"
Write-Host "  Zip:    $zipPath"
