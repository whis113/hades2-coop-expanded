--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type Events
local Events = ModRequire "Events.lua"
---@type RunEx
local RunEx = ModRequire "RunEx.lua"
---@type HeroContext
local HeroContext = ModRequire "HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"
---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "SecondPlayerUI.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "PlayerVisibilityHelper.lua"
---@type CoopCamera
local CoopCamera = ModRequire "CoopCamera.lua"
---@type CoopControl
local CoopControl = ModRequire "CoopControl.lua"
---@type HeroEx
local HeroEx = ModRequire "HeroEx.lua"
---@type UIHooks
local UIHooks = ModRequire "../hooks/UIHooks.lua"

---@class CoopRun
local CoopRun = {}

-- Boss-to-Rest revival restores a fallen player at 30% of their retained maximum health.
-- Boss 后进入 Rest Room 的复活会保留最大生命，并以 30% 当前生命复活。
local BossRestReviveHealthFraction = 0.30

function CoopRun.Init()
    Events.run:on("newRunStarted", CoopRun.OnRunStarted)
    Events.run:on("mapLoaded", CoopRun.OnMapLoaded)
    Events.run:on("roomPresentationFinished", CoopRun.OnRoomPresentationFinished)
    Events.run:on("roomPreLeave", CoopRun.OnRoomPreLeave)
    Events.run:on("allEnemiesDead", CoopRun.OnAllEnemiesDead)
end

---@private
function CoopRun.OnRunStarted(run)
    CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())

    if not RunEx.IsFirstRun(run) then
        CoopPlayers.RecreateAllAdditionalPlayers()
    end

    -- Reload weapon
    for _, hero in CoopPlayers.AdditionalHeroesIterator() do
        if hero.Weapons.WeaponLob then
            HeroContext.RunWithHeroContext(hero, ReloadAmmo, { Name = "WeaponLob" })
        end
    end
end

---@private
function CoopRun.OnMapLoaded(mapName)
    DebugPrint{ Text = "Coop map starter: " .. tostring(mapName)}
    if RunEx.IsHubRoom(mapName) then
        -- Hub load is the final safety net if the native death outro finished asynchronously. / Hub load is the final safety net when the native death outro completes asynchronously.
        CoopPlayers.ResetAfterRunEnd("hub-map-loaded:" .. tostring(mapName))
    elseif RunEx.IsMetaStoryRoom(mapName) then
        CoopRun.MakeFirstPlayerOnlyMode()
    end
end

---@private
function CoopRun.OnRoomPreLeave(currentRun, door)
    -- Disables the exit door after use
    door.ReadyToUse = false

    -- Updates traits and health
    local nextRoom = door.Room
    local currentHero = CurrentRun.Hero
    local shouldReviveDeadPlayers = RunEx.ShouldReviveDeadPlayersOnTransition(currentRun and currentRun.CurrentRoom, door)
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero ~= currentHero then
            if hero.IsDead then
                if shouldReviveDeadPlayers then
                    CoopRun.ReviveHeroForNextRoom(hero)
                end
            else
                ClearEffect({ Id = hero.ObjectId, All = true, BlockAll = true, })
                StopCurrentStatusAnimation(hero)
                hero.BlockStatusAnimations = true

                local blockDoorHealFromPrevious = type(nextRoom) == "table" and nextRoom.BlockDoorHealFromPrevious
                if not blockDoorHealFromPrevious then
                    HeroContext.RunWithHeroContext(hero, CheckDoorHealTrait, currentRun)
                end

                local removedTraits = {}
                for _, trait in pairs(hero.Traits) do
                    if trait.RemainingUses ~= nil and trait.UsesAsRooms ~= nil and trait.UsesAsRooms then
                        UseTraitData(hero, trait)
                        if trait.RemainingUses ~= nil and trait.RemainingUses <= 0 then
                            table.insert(removedTraits, trait)
                        end
                    end
                end
                for _, trait in pairs(removedTraits) do
                    RemoveTraitData(hero, trait)
                end
            end
        else
            -- Handle current hero (could be P1 or P2 depending on who triggered the door)
            if hero.IsDead and shouldReviveDeadPlayers then
                CoopRun.ReviveHeroForNextRoom(hero)
            end
        end
    end
end

function CoopRun.ReviveHeroForNextRoom(hero)
    hero.IsDead = false
    local maxHealth = hero.MaxHealth or 50
    hero.Health = math.max(1, math.ceil(maxHealth * BossRestReviveHealthFraction))

    -- 死亡玩家在战斗中只透明/锁输入，不删除单位。
    -- Dead co-op heroes are made invisible/input-locked during combat instead of deleting their units.
    -- 复活时先恢复既有单位可见，再交给房间表现流程传送。
    -- On revive, show the existing unit before room presentation teleports it.
    if hero.ObjectId then
        ClearEffect({ Id = hero.ObjectId, All = true, BlockAll = true, })
        HeroEx.ShowHero(hero)
    end
    local playerId = CoopPlayers.GetPlayerByHero(hero)
    if playerId then
        RemoveInputBlock { Name = "CoopDeadPlayer" .. tostring(playerId), PlayerIndex = playerId }
    end
    StopCurrentStatusAnimation(hero)
    hero.BlockStatusAnimations = true

    if CoopAppendTraceLog then
        CoopAppendTraceLog(string.format(
            "[CoopReviveTrace] player=P%s health=%s/%s fraction=%.2f",
            tostring(playerId),
            tostring(hero.Health),
            tostring(maxHealth),
            BossRestReviveHealthFraction
        ))
    end
end

---@private
function CoopRun.OnRoomPresentationFinished(run, currentRoom)
    if RunEx.IsRunEnded() then
        -- Hub 房间演出结束后再刷新一次，处理本体在 StartRoom 后覆盖 HUD 的情况。
        -- Refresh once more after Hub presentation in case native StartRoom work overwrote the HUD.
        CoopPlayers.ScheduleHubUiRefresh("hub-room-presentation:" .. tostring(currentRoom and currentRoom.Name))
    end

    for playerId = 2, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.GetHero(playerId)
        if not hero or (hero and not hero.IsDead) then
            CoopPlayers.InitCoopUnit(playerId)
        end
    end
    SecondPlayerUi.Refresh()
    CoopCamera.ForceFocus(true)

    CoopPlayers.UpdateMainHero()

    local mainHero = CoopPlayers.GetMainHero()
    local isMainPlayerDead = mainHero and mainHero.IsDead
    if not isMainPlayerDead then
        -- For some strange reason RoomEntrancePortal keeps the main player invisible
        SetAlpha { Id = mainHero.ObjectId, Fraction = 1.0, Duration = 1.0 }
    end

    local teleportPoint = currentRoom.HeroEndPoint or mainHero.ObjectId

    for playerId = 2, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.GetHero(playerId)
        if not hero.IsDead then
            Teleport({ Id = hero.ObjectId, DestinationId = teleportPoint })
            --CoopControl.Reset(playerId)
            if isMainPlayerDead then
                RemoveInputBlock { PlayerIndex = playerId, Name = "MoveHeroToRoomPosition" }
            end
        end
    end

    -- The native HUD may rebuild after this callback; capture both the immediate and settled P2 spell state.
    -- 本体 HUD 可能在此回调后继续重建；记录 P2 Spell 的即时状态和稳定后的状态。
    UIHooks.TracePlayerSpellUi("room-presentation-finished:" .. tostring(currentRoom and currentRoom.Name), 2)
    thread(function()
        wait(0.4, RoomThreadName)
        -- Recreate only P2's spell icon when native HUD reconstruction discarded its component registration.
        -- 当本体 HUD 重建丢失 P2 Spell 组件注册时，只重建 P2 的法术图标。
        UIHooks.RebuildPlayerSpellHud(2, "room-presentation-settled:" .. tostring(currentRoom and currentRoom.Name))
        UIHooks.TracePlayerSpellUi("room-presentation-settled:" .. tostring(currentRoom and currentRoom.Name), 2)
    end)
end

---@private
function CoopRun.OnAllEnemiesDead()
    for playerID = 2, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.GetHero(playerID)
        if hero and not hero.IsDead and hero.ObjectId then
            ClearEffect{ Id = hero.ObjectId, Name = "StyxPoison" }
            ClearEffect{ Id = hero.ObjectId, Name = "DamageOverTime" }
            ClearEffect{ Id = hero.ObjectId, Name = "Inked" }
        end
    end
end

function CoopRun.MakeFirstPlayerOnlyMode()
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = nil
    mainHero.Health = mainHero.MaxHealth or 100
    for _, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
        hero.Health = 0
    end
end

return CoopRun
