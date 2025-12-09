--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContextProxy
local HeroContextProxy = ModRequire "../logic/HeroContextProxy.lua"
---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../logic/HeroContextProxyStore.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

---@type ILootDelivery
local LootDelivery = ModRequire "../logic/loot/LootInterface.lua"

---@class LootHooks : SimpleHook
local LootHooks = SimpleHook.New()

---@private
---@type table | nil
LootHooks.BlindLootHero = nil

-- Select hero for blind loot
function LootHooks.wrap.UnwrapRandomLoot(baseFun, ...)
    LootHooks.BlindLootHero = CurrentRun.Hero

    baseFun(...)

    for lootId, lootData in pairs(LootObjects) do
        if not lootData.Cost then
            CoopUseItem(CurrentRun.Hero.ObjectId, lootId)
            break
        end
    end
end

function LootHooks.InitEngineHooks()
    Events.run:on("newRunStarted", LootHooks.InitLootHistoryProxy)

    if CurrentRun then
        LootHooks.InitLootHistoryProxy()
    end
end

---@private
function LootHooks.InitLootHistoryProxy()
    local proxyHandler = HeroContextProxy.New(CurrentRun, "LootTypeHistory")
    HeroContextProxyStore.Set("LootTypeHistory", proxyHandler)
end

---@private
function LootHooks.wrap.GiveLoot(baseFun, args)
    local hero = LootHooks.UseBlindLootHero()
    if hero then
        return LootDelivery.GiveBlindLoot(baseFun, hero, args)
    else
        return LootDelivery.GiveLoot(baseFun, args)
    end
end

---@private
function LootHooks.UseBlindLootHero()
    local hero = LootHooks.BlindLootHero
    if hero then
        LootHooks.BlindLootHero = nil
        return hero
    end
end

---@private
-- Select a player for room reward
function LootHooks.wrap.DoUnlockRoomExits(baseFun, run, room)
    if not LootHooks.NeedsCurrentRoomExitRewards(run) then
        return baseFun(run, room)
    end

    LootDelivery.OnUnlockedRewardedRoom(baseFun, run, room)
end

---@private
function LootHooks.wrap.SpawnRoomReward(baseFun, ...)
    -- Fix #16
    CurrentRun.CurrentRoom.DisableRewardMagnetisim = true

    return LootDelivery.SpawnRoomReward(baseFun, ...)
end

--- Warning: this function mutates the game state in ChooseNextRoomData
---@private
---@param run table
function LootHooks.NeedsCurrentRoomExitRewards(run)
    local roomData = ChooseNextRoomData(run)

    if roomData == nil then
        return false
    end

    if roomData.NoReward then
        return false
    end

    if roomData.NoReroll then
        return false
    end

    return true
end

return LootHooks
