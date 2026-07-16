[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$gamePathFile = Join-Path $projectRoot ".gamepath"

function Select-HadesExe {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.OpenFileDialog
    $browser.InitialDirectory = [Environment]::GetFolderPath('MyComputer')
    $browser.Filter = "Executable Files (*.exe)|Hades2.exe"
    $browser.Title = "Select Hades2.exe"

    if ($browser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw "Canceled: Hades2.exe was not selected."
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

function Assert-ExpectedModPath([string]$gameDirectory, [string]$modDirectory) {
    $expectedPath = [System.IO.Path]::GetFullPath((Join-Path $gameDirectory "Content\Mods\TN_CoopMod"))
    $actualPath = [System.IO.Path]::GetFullPath($modDirectory)
    if (-not [string]::Equals($expectedPath, $actualPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove an unexpected path: $actualPath"
    }
}

if (Get-Process -Name "Hades2" -ErrorAction SilentlyContinue) {
    throw "Hades II is running. Exit the game before uninstalling the Mod."
}

$exePath = Get-HadesExePath
if ([System.IO.Path]::GetFileName($exePath) -ne "Hades2.exe") {
    throw "Expected Hades2.exe, received: $exePath"
}

$shipDirectory = Split-Path -Parent $exePath
$gameDirectory = Split-Path -Parent $shipDirectory
$modDirectory = Join-Path $gameDirectory "Content\Mods\TN_CoopMod"
Assert-ExpectedModPath $gameDirectory $modDirectory

if (-not (Test-Path -LiteralPath $modDirectory)) {
    Write-Host "TN_CoopMod is not installed: $modDirectory" -ForegroundColor Yellow
    exit 0
}

# 仅删除本 Mod payload；保留共享加载器和 TN_Core，避免影响其他 Mod。
# Remove only this Mod payload; retain shared loader files and TN_Core for other Mods.
if ($PSCmdlet.ShouldProcess($modDirectory, "Remove TN_CoopMod payload")) {
    Remove-Item -LiteralPath $modDirectory -Recurse -Force
    Write-Host "Removed TN_CoopMod: $modDirectory" -ForegroundColor Green
    Write-Host "Retained shared TN_Core, ASI loader, plugins, and save data." -ForegroundColor Gray
}
