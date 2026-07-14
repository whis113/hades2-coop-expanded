$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerProject = Join-Path $scriptDir "tools\TesterInstaller\Hades2CoopInstaller.csproj"
$modSource = Join-Path $scriptDir "bin\TN_CoopMod"
$modExtensionRoot = Join-Path $scriptDir "..\..\reference project\hades2-coop-procject\hades2-mod-extension"
$modExtensionBin = Join-Path $modExtensionRoot "bin"
$coreSource = Join-Path $modExtensionBin "TN_Core"
$nativeExtensionSource = Join-Path $modExtensionBin "HadesModNativeExtension.asi"
$releaseDir = Join-Path $scriptDir "release\Hades2Coop-v0.2.2-TestBuild"
$publishDir = Join-Path $scriptDir "tools\TesterInstaller\bin\Release\net8.0-windows\win-x64\publish"
$asiLoaderUrl = "https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases/download/x64-latest/bink2w64-x64.zip"

if (-not (Test-Path -LiteralPath (Join-Path $modSource "HadesCoopGame.dll"))) {
    throw "Missing build output: $modSource. Run .\build_and_deploy.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $coreSource "init.lua"))) {
    throw "Missing TN_Core dependency: $coreSource. Build hades2-mod-extension first."
}
if (-not (Test-Path -LiteralPath $nativeExtensionSource)) {
    throw "Missing HadesModNativeExtension.asi: $nativeExtensionSource. Build hades2-mod-extension first."
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
New-Item -ItemType Directory -Path (Join-Path $releaseDir "Dependencies") -Force | Out-Null
Copy-Item -LiteralPath $coreSource -Destination (Join-Path $releaseDir "Dependencies\TN_Core") -Recurse -Force
Copy-Item -LiteralPath $nativeExtensionSource -Destination (Join-Path $releaseDir "Dependencies\HadesModNativeExtension.asi") -Force

# Bundle the loader so testers do not need a development setup or a network connection.
# 打包加载器，测试者无需开发环境或网络连接即可完成首次安装。
$loaderZip = Join-Path $env:TEMP "hades2-coop-asi-loader.zip"
# 打包加载器，测试者无需开发环境或网络连接即可完成首次安装。
$loaderZip = Join-Path $env:TEMP "hades2-coop-asi-loader.zip"
$loaderExtract = Join-Path $env:TEMP "hades2-coop-asi-loader"
$loaderZip = Join-Path $env:TEMP "hades2-coop-asi-loader.zip"
Remove-Item -LiteralPath $loaderZip -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $loaderExtract -Recurse -Force -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $asiLoaderUrl -OutFile $loaderZip
Expand-Archive -LiteralPath $loaderZip -DestinationPath $loaderExtract -Force
$loaderSource = Get-ChildItem -LiteralPath $loaderExtract -Filter "bink2w64.dll" -Recurse | Select-Object -First 1
if (-not $loaderSource) {
    throw "Ultimate ASI Loader archive did not contain bink2w64.dll."
}
Copy-Item -LiteralPath $loaderSource.FullName -Destination (Join-Path $releaseDir "Dependencies\bink2w64.dll") -Force
Remove-Item -LiteralPath $loaderZip -Force
Remove-Item -LiteralPath $loaderExtract -Recurse -Force

Copy-Item -LiteralPath (Join-Path $scriptDir "TESTER_README.md") -Destination $releaseDir -Force
Copy-Item -LiteralPath (Join-Path $scriptDir "LICENSE.txt") -Destination $releaseDir -Force

$zipPath = Join-Path $scriptDir "release\Hades2Coop-v0.2.2-TestBuild.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
$packageItems = Get-ChildItem -LiteralPath $releaseDir -Force
Compress-Archive -Path $packageItems.FullName -DestinationPath $zipPath -Force

Write-Host "Tester package created:" -ForegroundColor Green
Write-Host "  Folder: $releaseDir"
Write-Host "  Zip:    $zipPath"
