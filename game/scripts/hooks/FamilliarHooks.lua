--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

local FamilliarHooks = SimpleHook.New()

function FamilliarHooks.wrap.UseFamiliar(UseFamiliar, familiar, args, user)
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

return FamilliarHooks
