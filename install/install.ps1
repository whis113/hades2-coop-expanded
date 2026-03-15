Add-Type -AssemblyName System.Windows.Forms

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('MyComputer')
    Filter = "Executable Files (*.exe)|Hades2.exe"
    Title = "Select your Hades2.exe"
}

if ($FileBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
}

$ExePath = $FileBrowser.FileName
$GameExeDir = Split-Path -Path $ExePath -Parent
$GameDir = Split-Path -Path $GameExeDir -Parent
$ModsDir = Join-Path $GameDir "Content/Mods"
$PluginsDir = Join-Path -Path $GameExeDir -ChildPath "plugins"

Write-Host "Target Directory: $GameExeDir" -ForegroundColor Cyan

function installPlugin() {
    Write-Host "Installing HadesModNativeExtension.asi" -ForegroundColor Cyan

    if (-not (Test-Path -Path $PluginsDir)) {
        New-Item -ItemType Directory -Path $PluginsDir | Out-Null
        Write-Host "Created plugins folder."
    }

    if (Test-Path -Path "HadesModNativeExtension.asi") {
        Copy-Item -Path "HadesModNativeExtension.asi" -Destination $PluginsDir -Force
        Write-Host "Copied HadesModNativeExtension.asi to $PluginsDir" -ForegroundColor Green
    } else {
        Write-Error "Source 'HadesModNativeExtension.asi' not found in the current script directory!"
        exit
    }
}

function installASILoader() {
    Write-Host "Downloading ASI Loader..." -ForegroundColor Cyan

    if (-not (Test-Path -Path $PluginsDir)) {
        Write-Host "Rename bink2w64.dll to bink2w64Hooked.dll."
        Move-Item -Path  (Join-Path $GameExeDir "bink2w64.dll") -Destination (Join-Path $GameExeDir "bink2w64Hooked.dll") -Force
    } else {
        Write-Host "Skip bink2w64Hooked.dll."
    }

    $Url = "https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases/download/x64-latest/bink2w64-x64.zip"
    $ZipPath = Join-Path -Path $env:TEMP -ChildPath "asi_loader.zip"
    $TempExtractPath = Join-Path -Path $env:TEMP -ChildPath "asi_loader_temp"
    
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath

    # Unpack and move bink2w64.dll
    if (Test-Path $TempExtractPath) { Remove-Item $TempExtractPath -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $TempExtractPath -Force

    $DllSource = Get-ChildItem -Path $TempExtractPath -Filter "bink2w64.dll" -Recurse | Select-Object -First 1

    if ($DllSource) {
        Move-Item -Path $DllSource.FullName -Destination (Join-Path $GameExeDir "bink2w64.dll") -Force
        Write-Host "Successfully installed bink2w64.dll to game folder." -ForegroundColor Green
    } else {
        Write-Error "Could not find bink2w64.dll inside the downloaded zip."
    }

    # Cleanup
    Remove-Item $ZipPath -Force
    Remove-Item $TempExtractPath -Recurse -Force
}

function installMod() {
    param (
        $ModName
    )

    Write-Host "Copy $ModName mod files..." -ForegroundColor Cyan
    
    if (Test-Path -Path $ModsDir/$ModName) {
        Remove-Item $ModsDir/$ModName -Force -Recurse
    }
    Copy-Item -Path $ModName -Destination $ModsDir -Force -Recurse
}

function install {
    installPlugin;
    if (Test-Path $GameExeDir/ReturnOfModding) {
        Write-Host "`nReturn of modding dedected. Skip custom ASI loader" -ForegroundColor Green
    } else {
        installASILoader
    }

    if (-not (Test-Path -Path $ModsDir)) {
        New-Item -ItemType Directory -Path $ModsDir | Out-Null
        Write-Host "Created Mods folder."
    }

    
    installMod -ModName "TN_Core"
    installMod -ModName "TN_CoopMod"
}


install

Write-Host "`nSetup complete!." -ForegroundColor Green
