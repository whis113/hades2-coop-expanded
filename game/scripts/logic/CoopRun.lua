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

---@class CoopRun
local CoopRun = {}

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
        CoopPlayers.HealAllAdditionalPlayers()
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
    hero.Health = hero.MaxHealth or 50

    -- P2's unit is removed on death, but P1 can still have an object to clean up.
    if hero.ObjectId then
        ClearEffect({ Id = hero.ObjectId, All = true, BlockAll = true, })
    end
    StopCurrentStatusAnimation(hero)
    hero.BlockStatusAnimations = true
end

---@private
function CoopRun.OnRoomPresentationFinished(run, currentRoom)
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
