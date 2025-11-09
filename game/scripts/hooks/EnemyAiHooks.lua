--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"

---@class EnemyAiHooks : SimpleHook
local EnemyAiHooks = SimpleHook.New()

---@private
---@param unitId integer
function EnemyAiHooks.getNearestHero(unitId)
    local nearest
    local distance = 99999

    for playerId = 1, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.GetHero(playerId)
        if hero.IsDead then
            goto continue
        end
        local thisDistance = GetDistance { Id = hero.ObjectId, DestinationId = unitId }
        if thisDistance <= distance then
            nearest = hero
            distance = thisDistance
        end
        ::continue::
    end

    return nearest or HeroContext.GetDefaultHero()
end

---@private
---@param baseFun function
---@param enemy table
---@param weaponAiData table?
---@return integer
function EnemyAiHooks.wrap.GetTargetId(baseFun, enemy, weaponAiData)
    local hero = EnemyAiHooks.getNearestHero(enemy.ObjectId)
    return HeroContext.RunWithHeroContextReturn(hero, baseFun, enemy, weaponAiData)
end

---@private
---@param baseFun function
---@param params table
function EnemyAiHooks.wrap.NotifyWithinDistance(baseFun, params)
    if params.Notify == "ContractOpen" then
        -- Skip pact door
        baseFun(params)
        return
    end

    if CoopPlayers.IsPlayerUnit(params.DestinationId) then
        params.DestinationId = nil
        params.DestinationIds = CoopPlayers.GetUnits()
        params.Ids = params.Ids or { params.Id }
        params.Id = nil
        NotifyWithinDistanceAny(params)
    else
        baseFun(params)
    end
end

function EnemyAiHooks.wrap.IsAIActive(baseFun, ...)
    local alivePlayer = CoopPlayers.GetAliveHeroes()[1]
    if alivePlayer then
        return HeroContext.RunWithHeroContextReturn(alivePlayer, baseFun, ...)
    else
        return baseFun(...)
    end
end

return EnemyAiHooks
