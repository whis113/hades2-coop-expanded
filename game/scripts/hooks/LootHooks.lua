--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HeroContextProxy
local HeroContextProxy = ModRequire "../logic/HeroContextProxy.lua"
---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../logic/HeroContextProxyStore.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type Config
local Config = ModRequire "../config.lua"
---@type CoopDebugMonitor
local CoopDebugMonitor = ModRequire "../logic/CoopDebugMonitor.lua"

---@type ILootDelivery
local LootDelivery = ModRequire "../logic/loot/LootInterface.lua"

---@class LootHooks : SimpleHook
local LootHooks = SimpleHook.New()

---@private
---@type table | nil
LootHooks.BlindLootHero = nil

-- 为随机生成的免费 loot 选择玩家上下文。
-- Select the hero context for blind/free random loot.
function LootHooks.wrap.UnwrapRandomLoot(baseFun, ...)
    local previousLootObjects = {}
    for lootId in pairs(LootObjects) do
        previousLootObjects[lootId] = true
    end

    LootHooks.BlindLootHero = CurrentRun.Hero

    baseFun(...)

    local firstLootId = nil
    local firstLootData = nil
    for lootId, lootData in pairs(LootObjects) do
        if not previousLootObjects[lootId] and not lootData.Cost then
            firstLootId = lootId
            firstLootData = lootData
            break
        end
    end

    if firstLootId == nil then
        return
    end

    LootHooks.SpawnSecondBlindLoot(firstLootData)
    CoopUseItem(CurrentRun.Hero.ObjectId, firstLootId)
end

---@private
function LootHooks.SpawnSecondBlindLoot(firstLootData)
    if not (Config and Config.StartingBoonDoubleRewards) then
        return
    end
    if firstLootData == nil or firstLootData.Name == nil then
        return
    end

    local secondHero = nil
    for _, hero in pairs(CoopPlayers.GetAliveHeroes()) do
        if hero ~= CurrentRun.Hero then
            secondHero = hero
            break
        end
    end
    if secondHero == nil then
        return
    end

    local secondLootName = LootHooks.ChooseIndependentStartingBoon(secondHero)
    if secondLootName == nil then
        CoopDebugMonitor.RecordReward("start-boon-preselect", CoopPlayers.GetPlayerByHero(secondHero) or 2, nil, nil)
        return
    end

    local secondPlayerId = CoopPlayers.GetPlayerByHero(secondHero) or 2
    CoopDebugMonitor.RecordReward("start-boon-preselect", secondPlayerId, secondLootName, secondLootName)

    -- 开局第二份 boon 独立按 P2 的本体信物与神明池预选，但不自动打开第二个菜单。
    -- The second starting boon uses P2 native keepsake and god-pool rules, without auto-opening its menu.
    local prevBlindLootHero = LootHooks.BlindLootHero
    LootHooks.BlindLootHero = secondHero
    local secondLoot = GiveLoot({
        ForceLootName = secondLootName,
        SpawnPoint = firstLootData.ObjectId,
        OffsetX = 120,
        OffsetY = 0,
        AutoLoadPackages = true,
    })
    LootHooks.BlindLootHero = prevBlindLootHero

    if secondLoot ~= nil then
        secondLoot.CanDuplicate = false
    end
    CoopDebugMonitor.RecordReward("start-boon-spawn", secondPlayerId, secondLootName, secondLootName)
end

---@private
---按本体普通 boon 房规则为开局第二位玩家预选神明。
---Pre-selects the starting second-player god using native normal-boon room rules.
function LootHooks.ChooseIndependentStartingBoon(hero)
    return HeroContext.RunWithHeroContextAwait(hero, function()
        local secondReward = {
            Name = CurrentRun.CurrentRoom.Name,
            ChosenRewardType = "Boon",
            ForcedBoonNames = {},
        }

        -- 不排除 P1 的首个 boon，允许两名玩家获得同一神明。
        -- Do not exclude P1's starting boon, so both players may receive the same god.
        SetupRoomReward(CurrentRun, secondReward, nil, {
            AlwaysSetupForceLootName = true,
        })
        return secondReward.ForceLootName
    end)
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

--- 注意：该函数会通过 ChooseNextRoomData 改动游戏状态。
--- Warning: this function mutates the game state through ChooseNextRoomData.
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
