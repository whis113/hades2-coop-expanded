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
local chamberTraitHeroes = setmetatable({}, { __mode = "k" })

function TraitHooks.wrap.AddMaxMana(baseFun, manaGained, source, args)
    local hero = chamberTraitHeroes[coroutine.running()] or (CurrentRun and CurrentRun.Hero)
    local playerId = hero and CoopPlayers.GetPlayerByHero(hero)
    if not (args and args.Thread and playerId and playerId > 1) then
        return baseFun(manaGained, source, args)
    end

    -- 原版会启动子协程；将该协程绑定到 P2 后，继续由原版处理 MP 与最大 MP。
    -- The original starts a child coroutine; bind it to P2, then let native Lua handle mana and max mana unchanged.
    local childArgs = ShallowCopyTable(args)
    HeroContext.RunWithHeroContext(hero, function()
        childArgs.Thread = false
        return baseFun(manaGained, source, childArgs)
    end)
end

function TraitHooks.wrap.CheckChamberTraits(baseFun, ...)
    if isUpdatingChamberTraits then
        return baseFun(...)
    end

    isUpdatingChamberTraits = true
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        -- 任一玩家过门时都为双方重放原版房间进度；子协程必须继承当前 replay 的玩家。
        -- Either player opening a door replays original room progress for both; child threads inherit this replay hero.
        HeroContext.RunWithHeroContextAwait(hero, function(...)
            local thread = coroutine.running()
            chamberTraitHeroes[thread] = hero
            baseFun(...)
            chamberTraitHeroes[thread] = nil
        end, ...)
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
