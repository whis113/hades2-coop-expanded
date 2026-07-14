param(
    [switch]$All
)

$ErrorActionPreference = "Stop"
$logPath = Join-Path $env:USERPROFILE "Saved Games\Hades II\TN_CoopMod.log"

if (-not (Test-Path -LiteralPath $logPath)) {
    throw "Co-op log was not found: $logPath"
}

Clear-Host
Write-Host "Hades II Co-op live trace" -ForegroundColor Cyan
Write-Host "Log: $logPath"
Write-Host "Press Ctrl+C to stop. Use -All to show every line." -ForegroundColor DarkGray
Write-Host ""

$pattern = '\[Coop(Debug|KeepsakeTrace|DeathTrace|BossTrace|RarityTrace|RewardTrace|FountainTrace|NpcRewardTrace|HammerTrace|FieldsRewardTrace|FieldsOptionalTrace|ShipsRewardTrace|ChaosTrace|SpellTrace|SpellUiTrace|MenuControlTrace|ChoiceTrace|EndRunTrace|HubUiRefresh|ArcanaAudit|ArcanaRuntime)\]'
Get-Content -LiteralPath $logPath -Tail 80 -Wait | ForEach-Object {
    if ($All -or $_ -match $pattern) {
        if ($_ -match '\[CoopDebug\]') {
            Write-Host $_ -ForegroundColor Cyan
        } elseif ($_ -match '\[CoopDeathTrace\]|\[CoopBossTrace\]') {
            Write-Host $_ -ForegroundColor Yellow
        } else {
            Write-Host $_
        }
    }
}
