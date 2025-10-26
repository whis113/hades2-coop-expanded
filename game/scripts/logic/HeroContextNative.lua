--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

---@class HeroContextNative
local HeroContextNative = {}

function HeroContextNative.RunWithNativeHeroContextFromHero(fun, ...)
    local playerIndex = CoopPlayers.GetPlayerByHero(CurrentRun.Hero) or 1
    HeroContextNative.RunWithNativeHeroContext(playerIndex, fun, ...)
end

function HeroContextNative.RunWithNativeHeroContext(playerIndex, fun, ...)
    CoopSetCurrentMainPlayer(playerIndex)
    local result = fun(...)
    CoopResetCurrentMainPlayer()
    return result
end

return HeroContextNative
