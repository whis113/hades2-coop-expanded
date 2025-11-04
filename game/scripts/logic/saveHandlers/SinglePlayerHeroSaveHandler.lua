--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../CoopPlayers.lua"

---@class SinglePlayerHeroSaveHandler : ISaveHandler
local SinglePlayerHeroSaveHandler = {}

function SinglePlayerHeroSaveHandler.PreSave()
    CurrentRun.Hero = CoopPlayers.GetMainHero()
    SinglePlayerHeroSaveHandler.ApplyMainHeroDeathWorkaround()
end

function SinglePlayerHeroSaveHandler.PostSave()
    SinglePlayerHeroSaveHandler.RemoveMainHeroDeathWorkaround()

    CurrentRun.Hero = nil
end

function SinglePlayerHeroSaveHandler.Load()
    local hero = CurrentRun and CurrentRun.CoopWorkaroundMainHero
    if hero then
        CurrentRun.Hero = hero
        SinglePlayerHeroSaveHandler.RemoveMainHeroDeathWorkaround()
    end
end

---@private
function SinglePlayerHeroSaveHandler.DoPatchesPreHook()
    local hero = CurrentRun and CurrentRun.CoopWorkaroundMainHero
    if hero then
        CurrentRun.Hero = hero
        SinglePlayerHeroSaveHandler.RemoveMainHeroDeathWorkaround()
    end
end

---@private
function SinglePlayerHeroSaveHandler.ApplyMainHeroDeathWorkaround()
    local hero = CurrentRun and CurrentRun.Hero
    if hero.IsDead then
        CurrentRun.CoopWorkaroundMainHero = hero
        local safeHero = CoopPlayers.GetFirstAliveHero() or hero
        CurrentRun.Hero = safeHero

        local location = GetLocation { Id = safeHero.ObjectId }
        RecordObjectState(CurrentRun.CurrentRoom, hero.ObjectId, "Location", location)
    end
end

---@private
function SinglePlayerHeroSaveHandler.RemoveMainHeroDeathWorkaround()
    CurrentRun.CoopWorkaroundMainHero = nil
end

return SinglePlayerHeroSaveHandler
