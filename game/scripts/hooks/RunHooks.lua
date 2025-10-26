--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type CoopCamera
local CoopCamera = ModRequire "../logic/CoopCamera.lua"
---@type EnemyAiHooks
local EnemyAiHooks = ModRequire "EnemyAiHooks.lua"
---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "../logic/SecondPlayerUI.lua"
---@type RunEx
local RunEx = ModRequire "../logic/RunEx.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "../logic/PlayerVisibilityHelper.lua"
---@type HeroEx
local HeroEx = ModRequire "../logic/HeroEx.lua"
---@type CoopControl
local CoopControl = ModRequire "../logic/CoopControl.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

---@class RunHooks
local RunHooks = {}

function RunHooks.InitHooks()
    HookUtils.onPreFunction("LeaveRoom", RunHooks.LeaveRoomHook)
    HookUtils.onPreFunction("DeathAreaRoomTransition", RunHooks.DeathAreaRoomTransitionPreHook)
    HookUtils.onPreFunction("OnAllEnemiesDead", RunHooks.OnAllEnemiesDeadPreHook)
    HookUtils.wrap("EndEarlyAccessPresentation", RunHooks.EndEarlyAccessPresentationWrapHook)
    HookUtils.wrap("StartRoom", RunHooks.StartRoomWrapHook)
    HookUtils.wrap("KillHero", RunHooks.KillHeroHook)
    HookUtils.wrap("CheckRoomExitsReady", RunHooks.CheckRoomExitsReadyHook)
    HookUtils.wrap("SetupHeroObject", RunHooks.SetupHeroObjectHook)
    HookUtils.wrap("CheckDistanceTrigger", RunHooks.CheckDistanceTriggerWrapHook)
    HookUtils.wrap("EndEncounterEffects", RunHooks.EndEncounterEffectsWrapHook)
    HookUtils.wrap("StartEncounterEffects", RunHooks.StartEncounterEffectsWrapHook)
    HookUtils.onPostFunction("RestoreUnlockRoomExits", RunHooks.RestoreUnlockRoomExitsHook)
    HookUtils.onPostFunction("StartRoomPresentation", RunHooks.StartRoomPresentationPostHook)
    HookUtils.onPostFunction("StartNewRun", RunHooks.StartNewRunPostHook)
end

---@private
function RunHooks.DeathAreaRoomTransitionPreHook()
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
    end
end

---@private
function RunHooks.CheckDistanceTriggerWrapHook(CheckDistanceTriggerFun, ...)
    -- TODO
    -- This hack fixes crashes like Hades 1 #21 when the player 1 is dead.
    -- The crash is caused by invalid reference to the second player.
    -- The game cannot find a player unit and triggers NotifyWithinDistance instantly without result
    HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), CheckDistanceTriggerFun, ...)
end

---@private
function RunHooks.SetupHeroObjectHook(SetupHeroObjectFun, ...)
    local mainHero = CoopPlayers.GetMainHero()

    HeroContext.RunWithHeroContext(mainHero, SetupHeroObjectFun, ...)
    -- Fix unit -> hero table here
    CoopPlayers.UpdateMainHero()

    PlayerVisibilityHelper.AddPlayerMarkers(1, mainHero.ObjectId)

    if mainHero.IsDead and not RunEx.IsRunEnded() then
        HeroEx.HideHero(mainHero)
    end
end

---@private
function RunHooks.StartRoomWrapHook(StartRoomFun, run, currentRoom)
    -- Fixes mouse disappearing after level transiction
    CoopControl.ResetAllPlayers("Current")

    -- Initialization after save loading when encounter is active
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
        CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())
    end

    if currentRoom.RoomSetName == "Surface" then
        RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    else
        RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    HookUtils.onPostFunctionOnce("SwitchActiveUnit", function()
        SwitchActiveUnit { PlayerIndex = 1, Id = CoopPlayers.GetMainHero().ObjectId }
    end)

    if RunEx.IsRunEnded() then
        HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), StartRoomFun, run, currentRoom)
    else
        local hero = CoopPlayers.GetAliveHeroes()[1] or CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(hero, StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = false
    HeroContext.SetDefaultHero(mainHero)

    if mainHero.Health == 0 then
        mainHero.Health = mainHero.MaxHealth
    end

    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end

    HeroContext.RunWithHeroContext(mainHero, StartRoomFun, run, currentRoom)
end

---@private
function RunHooks.StartNewRunPostHook()
    Events.run:trigger("newRunStarted", CurrentRun)
end

--- Bypass IsAlive check with this hook
---@private
function RunHooks.CheckRoomExitsReadyHook(baseFun, ...)
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]
    if aliveHero then
        local result = false
        HeroContext.RunWithHeroContext(aliveHero, function(...)
            result = baseFun(...)
        end, ...)

        return result
    else
        return baseFun(...)
    end
end

---@private
function RunHooks.EndEarlyAccessPresentationWrapHook(baseFun)
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = false
    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end
    HeroContext.RunWithHeroContext(mainHero, baseFun)
end

---@private
function RunHooks.KillHeroHook(baseFun, ...)
    CurrentRun.Hero.IsDead = true
    if not CoopPlayers.HasAlivePlayers() then
        -- Handle death for player 1 only
        local mainHero = CoopPlayers.GetMainHero()
        HeroEx.ShowHero(mainHero, CurrentRun.Hero.ObjectId)
        RemoveOutline({ Id = mainHero.ObjectId })
        HeroContext.RunWithHeroContext(mainHero, baseFun, ...)
        CoopPlayers.OnAllPlayersDead()
        return
    end
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]

    if CurrentRun.Hero == CoopPlayers.GetMainHero() then
        HeroEx.HideHero(CurrentRun.Hero)

        HeroContext.SetDefaultHero(aliveHero)
    else
        local playerId = CoopPlayers.GetPlayerByHero(CurrentRun.Hero)
        if playerId then
            CoopRemovePlayerUnit(playerId)
        end
    end
    -- Unstuck AI
    HeroContext.RunWithHeroContext(aliveHero, EnemyAiHooks.RefreshAI)
end

---@private
function RunHooks.LeaveRoomHook(currentRun, door)
    Events.run:trigger("roomPreLeave", currentRun, door)
end

---@private
function RunHooks.RestoreUnlockRoomExitsHook()
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
    end
    CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())

    local spawnPoint = CurrentRun.CurrentRoom.HeroEndPoint or CoopPlayers.GetMainHero().ObjectId
    for playerId = 2, CoopPlayers.GetPlayersCount() do
        CoopPlayers.RestoreSavedHero(playerId)
        local hero = CoopPlayers.GetHero(playerId)
        if hero and not hero.IsDead then
            Teleport { Id = hero.ObjectId, DestinationId = spawnPoint }
        end
    end

    SecondPlayerUi.Refresh()
end

---@private
function RunHooks.EndEncounterEffectsWrapHook(baseFun, currentRun, currentRoom, currentEncounter)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, currentRun, currentRoom, currentEncounter)
        currentRoom.CodexUpdates = nil
        currentRoom.PendingCodexUpdate = nil
    end
end

---@private
function RunHooks.StartEncounterEffectsWrapHook(baseFun, run)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, run)
    end
end

function RunHooks.StartRoomPresentationPostHook(run, room)
    Events.run:trigger("roomPresentationFinished", run, room)
end

function RunHooks.OnAllEnemiesDeadPreHook()
    Events.run:trigger("allEnemiesDead")
end

return RunHooks
