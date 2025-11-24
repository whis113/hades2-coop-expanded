--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

---@class FamiliarHooks : SimpleHook
local FamiliarHooks = SimpleHook.New()

function FamiliarHooks:InitEngineHooks()
    Events.run:on("roomPreStart", FamiliarHooks.LoadAdditionalPackages)
end

function FamiliarHooks.LoadAdditionalPackages()
    local loadAdditional = {}
    for playerId in pairs(CoopPlayers.GetAliveHeroes()) do
        local key = "EquippedFamiliarCoopPlayer" .. playerId
        local familiar = GameState[key]
        if familiar then
            table.insert(loadAdditional, familiar)
        end
    end
    if not IsEmpty(loadAdditional) then
        LoadPackages { Names = loadAdditional }
    end
end

function FamiliarHooks.wrap.UseFamiliar(UseFamiliar, familiar, args, user)
    local playerId = CoopPlayers.GetCurrentPlayerId()

    if playerId == 1 then
        return UseFamiliar(familiar, args, user)
    end

    local prevFamilliar = GameState.EquippedFamiliar
    local key = "EquippedFamiliarCoopPlayer" .. playerId

    GameState.EquippedFamiliar = GameState[key]

    UseFamiliar(familiar, args, user)

    GameState[key] = GameState.EquippedFamiliar
    GameState.EquippedFamiliar = prevFamilliar
end

-- Activate familiars for all alive players here
function FamiliarHooks.wrap.FamiliarSetup(ActivateFamiliar, eventSource, args)
    local firstPlayerFamiliar = GameState.EquippedFamiliar
    for playerId, hero in pairs(CoopPlayers.GetAliveHeroes()) do
        if playerId == 1 then
            GameState.EquippedFamiliar = firstPlayerFamiliar
        else
            GameState.EquippedFamiliar = GameState["EquippedFamiliarCoopPlayer" .. playerId]
        end
        HeroContext.RunWithHeroContextAwait(hero, ActivateFamiliar, eventSource, args)
    end
    GameState.EquippedFamiliar = firstPlayerFamiliar
end

return FamiliarHooks
