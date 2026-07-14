--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "HeroContext.lua"
---@type CoopCamera
local CoopCamera = ModRequire "CoopCamera.lua"

---@class ChronosRecovery
local ChronosRecovery = {}

---@private
---Checks whether the saved Chronos room already contains its clear reward.
---检查读档后的克洛诺斯房间是否已经存在通关奖励。
local function HasChronosClearReward()
    for _, loot in pairs(LootObjects or {}) do
        if loot.Name == "MixerIBossDrop" then
            return true
        end
    end
    for _, obstacle in pairs(MapState and MapState.ActiveObstacles or {}) do
        if obstacle.Name == "MixerIBossDrop" then
            return true
        end
    end
    return false
end

---@public
---Returns true only after Chronos has entered a completed presentation state.
---仅在克洛诺斯已经进入结算完成状态后返回 true。
function ChronosRecovery.ShouldRecoverSavedRoom()
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room == nil or room.Name ~= "I_Boss01" then
        return false
    end
    return room.ExitsUnlocked
        or HasChronosClearReward()
        or (room.Encounter and room.Encounter.BossKillPresentation and IsEmpty(RequiredKillEnemies or {}))
end

---@public
---Clears presentation leftovers and restores co-op camera focus without changing save progression.
---清理结算演出残留并恢复双人摄像机，不修改存档进度。
function ChronosRecovery.Recover(stage, force)
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room == nil or room.Name ~= "I_Boss01" then
        return false
    end
    if not force and not ChronosRecovery.ShouldRecoverSavedRoom() then
        return false
    end

    local deathBackgroundId = ScreenAnchors and ScreenAnchors.DeathBackground
    if deathBackgroundId ~= nil then
        SetAlpha({ Id = deathBackgroundId, Fraction = 0, Duration = 0 })
        -- A stale Combat_Menu screen obstacle can ignore alpha after the clear screen closes; remove it and let native code recreate it later.
        -- 结算界面关闭后残留的 Combat_Menu 黑幕可能忽略透明度；销毁它，后续演出再由本体重新创建。
        Destroy({ Id = deathBackgroundId })
        ScreenAnchors.DeathBackground = nil
    end
    local deathBackingId = ScreenAnchors and ScreenAnchors.DeathBacking
    if deathBackingId ~= nil then
        SetAlpha({ Id = deathBackingId, Fraction = 0, Duration = 0 })
    end
    -- Chronos can leave a global fade active after the boss presentation; clear it separately from HUD anchors.
    -- 克洛诺斯结算可能在 HUD 锚点之外留下全局淡出层，需单独恢复。
    FadeIn({ Duration = 0 })

    RemoveInputBlock({ Name = "ChronosKillPresentation" })
    RemoveInputBlock({ Name = "GenericBossKillPresentation" })
    RemoveTimerBlock(CurrentRun, "GenericBossKillPresentation")
    SetConfigOption({ Name = "UseOcclusion", Value = true })
    UnlockCameraMotion("GenericBossKillPresentation")
    ClearCameraClamp({ LerpTime = 0 })

    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and hero.ObjectId then
            HeroContext.RunWithHeroContext(hero, function()
                ClearPlayerFade("KillPresentation", 0)
                SetPlayerVulnerable("GenericBossKillPresentation")
            end)
            SetThingProperty({ Property = "ElapsedTimeMultiplier", Value = 1, DataValue = false, DestinationId = hero.ObjectId })
            SetThingProperty({ Property = "AllowAnyFire", Value = true, DataValue = false, DestinationId = hero.ObjectId })
            RemoveFromGroup({ Id = hero.ObjectId, Names = { "Combat_Menu_Overlay_Backing" } })
            AddToGroup({ Id = hero.ObjectId, Name = "Standing", DrawGroup = true })
            if not hero.IsDead then
                SetAlpha({ Id = hero.ObjectId, Fraction = 1, Duration = 0 })
            end
        end
    end

    if room.Encounter ~= nil then
        room.Encounter.BossKillPresentation = false
    end
    if HUDScreen ~= nil then
        ShowCombatUI("BossKill")
        ToggleCombatControl(CombatControlsDefaults, true, "BossKill")
    end

    local cameraHero = CoopPlayers.GetAliveHeroes()[1] or CoopPlayers.GetMainHero()
    if cameraHero ~= nil and cameraHero.ObjectId ~= nil and CoopCamera.LockCameraOrig ~= nil then
        -- P1 can be dead when the P2-owned clear screen closes. Never lock the arena camera to
        -- that hidden unit; the survivor must be able to reach the Chronos reward and exit.
        -- P2 持有结算页时 P1 可能已经死亡，绝不能把战场镜头锁到隐藏的 P1；存活者必须能走到沙漏并离场。
        CoopCamera.ForceFocus(false)
        CoopCamera.LockCameraOrig({ Id = cameraHero.ObjectId, Duration = 0 })
    else
        CoopCamera.ForceFocus(true)
        CoopCamera.Update()
    end
    CoopAppendTraceLog(string.format(
        "[CoopEndRunTrace] chronos-recovery stage=%s deathBackground=%s deathBacking=%s rewardPresent=%s exitsUnlocked=%s camera=P%s:%s",
        tostring(stage), tostring(deathBackgroundId), tostring(deathBackingId), tostring(HasChronosClearReward()), tostring(room.ExitsUnlocked),
        tostring(CoopPlayers.GetPlayerByHero(cameraHero) or "nil"), tostring(cameraHero and cameraHero.ObjectId)
    ))
    return true
end

---@public
---Restores the survivor's gameplay state after the Chronos clear screen closes.
---克洛诺斯结算页关闭后恢复存活玩家的战斗状态。
function ChronosRecovery.RestoreSurvivorControlAfterClearScreen()
    local room = CurrentRun and CurrentRun.CurrentRoom
    local hero = CoopPlayers.GetAliveHeroes()[1]
    if room == nil or room.Name ~= "I_Boss01" or hero == nil or hero.ObjectId == nil then
        return false
    end

    HeroContext.SetDefaultHero(hero)
    HeroContext.RunWithHeroContext(hero, function()
        ClearPlayerFade("KillPresentation", 0)
        SetPlayerVulnerable("ChronosKillPresentation")
        SetPlayerVulnerable("GenericBossKillPresentation")
    end)
    -- Explicitly restore the survivor's native movement slot after menu controller hot-swap.
    -- 在菜单手柄热切换后，显式恢复存活者对应的本体移动槽位。
    local playerId = CoopPlayers.GetPlayerByHero(hero)
    if playerId ~= nil then
        ToggleMove({ Enabled = true, PlayerIndex = playerId })
    end
    if CoopCamera.LockCameraOrig ~= nil then
        CoopCamera.ForceFocus(false)
        CoopCamera.LockCameraOrig({ Id = hero.ObjectId, Duration = 0 })
    end
    CoopAppendTraceLog(string.format(
        "[CoopEndRunTrace] chronos-clear-closed survivor=P%s:%s",
        tostring(playerId or "nil"), tostring(hero.ObjectId)
    ))
    return true
end

return ChronosRecovery
