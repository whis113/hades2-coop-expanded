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
        local aliveUnitIds = {}
        for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
            if hero.ObjectId ~= nil then
                table.insert(aliveUnitIds, hero.ObjectId)
            end
        end
        if #aliveUnitIds == 0 then
            return baseFun(params)
        end
        -- Enemy distance waits must exclude dead heroes; otherwise Boss AI can reacquire a hidden P1 after control moved to P2.
        -- 敌人的距离等待必须排除死亡英雄；否则 Boss AI 会在控制权切到 P2 后重新锁定隐藏的 P1。
        params.DestinationId = nil
        params.DestinationIds = aliveUnitIds
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
