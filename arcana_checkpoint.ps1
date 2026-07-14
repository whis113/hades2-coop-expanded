param(
    [ValidateSet("Create", "Restore")]
    [string]$Action = "Create",
    [string]$CheckpointName = "pre-independent-arcana-20260714"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$checkpointDir = Join-Path $scriptDir "checkpoints\$CheckpointName"
$sourceSnapshotDir = Join-Path $checkpointDir "source"
$payloadSnapshotDir = Join-Path $checkpointDir "payload\TN_CoopMod"
$currentPayloadDir = Join-Path $scriptDir "bin\TN_CoopMod"
$gamePathFile = Join-Path $scriptDir ".gamepath"

$arcanaSourceFiles = @(
    "game\scripts\config.lua",
    "game\scripts\GamemodeInit.lua",
    "game\scripts\hooks\GameStateHooks.lua",
    "game\scripts\hooks\MenuHooks.lua",
    "game\scripts\logic\GameStateEx.lua",
    "game\scripts\logic\HeroEx.lua",
    "game\scripts\logic\CoopPlayers.lua"
)

$postCheckpointArcanaFiles = @(
    "game\scripts\logic\CoopArcana.lua",
    "game\scripts\hooks\ArcanaHooks.lua"
)

function Get-GameModDirectory {
    if (-not (Test-Path -LiteralPath $gamePathFile)) {
        throw "Missing .gamepath. Run .\build_and_deploy.ps1 once before restoring the deployed Mod."
    }

    $gameExe = (Get-Content -LiteralPath $gamePathFile -Raw).Trim()
    if (-not (Test-Path -LiteralPath $gameExe)) {
        throw "Saved Hades2.exe path is invalid: $gameExe"
    }

    $shipDirectory = Split-Path -Parent $gameExe
    $gameDirectory = Split-Path -Parent $shipDirectory
    return Join-Path $gameDirectory "Content\Mods\TN_CoopMod"
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length + 1)
        $destinationFile = Join-Path $Destination $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destinationFile) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destinationFile -Force
    }
}

if ($Action -eq "Create") {
    if (Test-Path -LiteralPath $checkpointDir) {
        throw "Checkpoint already exists: $checkpointDir"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $currentPayloadDir "HadesCoopGame.dll"))) {
        throw "Current Mod payload is missing. Run .\build_and_deploy.ps1 first."
    }

    New-Item -ItemType Directory -Path $sourceSnapshotDir -Force | Out-Null
    foreach ($relativePath in $arcanaSourceFiles) {
        $sourceFile = Join-Path $scriptDir $relativePath
        if (-not (Test-Path -LiteralPath $sourceFile)) {
            throw "Cannot checkpoint missing source file: $sourceFile"
        }

        $snapshotFile = Join-Path $sourceSnapshotDir $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotFile) -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile -Destination $snapshotFile -Force
    }

    Copy-DirectoryContents -Source $currentPayloadDir -Destination $payloadSnapshotDir
    $manifest = [ordered]@{
        CheckpointName = $CheckpointName
        CreatedAt = (Get-Date).ToString("s")
        Purpose = "Known-good state before independent Arcana loadouts"
        ArcanaSourceFiles = $arcanaSourceFiles
        Payload = "bin\\TN_CoopMod"
    } | ConvertTo-Json
    Set-Content -LiteralPath (Join-Path $checkpointDir "checkpoint.json") -Value $manifest -Encoding UTF8

    Write-Host "Arcana checkpoint created: $checkpointDir" -ForegroundColor Green
    exit 0
}

if (-not (Test-Path -LiteralPath $sourceSnapshotDir) -or -not (Test-Path -LiteralPath $payloadSnapshotDir)) {
    throw "Checkpoint is incomplete: $checkpointDir"
}
if (Get-Process -Name "Hades2" -ErrorAction SilentlyContinue) {
    throw "Close Hades II before restoring the Mod."
}

foreach ($relativePath in $arcanaSourceFiles) {
    $snapshotFile = Join-Path $sourceSnapshotDir $relativePath
    $destinationFile = Join-Path $scriptDir $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationFile) -Force | Out-Null
    Copy-Item -LiteralPath $snapshotFile -Destination $destinationFile -Force
}
foreach ($relativePath in $postCheckpointArcanaFiles) {
    $candidate = Join-Path $scriptDir $relativePath
    if (Test-Path -LiteralPath $candidate) {
        Remove-Item -LiteralPath $candidate -Force
    }
}

$targetModDir = Get-GameModDirectory
$stagingDir = "$targetModDir.arcana-rollback-staging"
$backupDir = "$targetModDir.arcana-rollback-backup"
Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-DirectoryContents -Source $payloadSnapshotDir -Destination $stagingDir

if (Test-Path -LiteralPath $targetModDir) {
    Move-Item -LiteralPath $targetModDir -Destination $backupDir
}
Move-Item -LiteralPath $stagingDir -Destination $targetModDir
Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Arcana rollback restored source and deployed Mod from: $checkpointDir" -ForegroundColor Green
