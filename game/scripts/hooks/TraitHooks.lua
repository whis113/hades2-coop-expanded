--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"

---@class TraitHooks : SimpleHook
local TraitHooks = SimpleHook.New()

local isUpdatingChamberTraits = false

function TraitHooks.wrap.CheckChamberTraits(baseFun, ...)
    if isUpdatingChamberTraits then
        return baseFun(...)
    end

    isUpdatingChamberTraits = true
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, ...)
    end
    isUpdatingChamberTraits = false
end

return TraitHooks
