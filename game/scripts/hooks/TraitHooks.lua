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
local isApplyingEnterRoomTraitSetup = false

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

function TraitHooks.wrap.ApplyTraitSetupFunctions(baseFun, unit, args)
    if isApplyingEnterRoomTraitSetup or not args or args.Context ~= "EnterRoom" then
        return baseFun(unit, args)
    end

    isApplyingEnterRoomTraitSetup = true
    local result
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        result = HeroContext.RunWithHeroContextAwait(hero, baseFun, hero, args)
    end
    isApplyingEnterRoomTraitSetup = false

    return result
end

return TraitHooks
