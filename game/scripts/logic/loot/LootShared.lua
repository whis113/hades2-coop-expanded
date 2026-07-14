--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContext
local HeroContext = ModRequire "../HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../CoopPlayers.lua"
---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../HeroContextProxyStore.lua"
---@type Events
local Events = ModRequire "../Events.lua"
---@type LootQuery
local LootQuery = ModRequire "LootQuery.lua"
---@type Config
local Config = ModRequire "../../config.lua"
---@type CoopDebugMonitor
local CoopDebugMonitor = ModRequire "../CoopDebugMonitor.lua"
---@type RunEx
local RunEx = ModRequire "../RunEx.lua"
---@type ChronosRecovery
local ChronosRecovery = ModRequire "../ChronosRecovery.lua"

---@class LootShared : ILootDelivery
local LootShared = {}

function LootShared.InitHooks()
    Events.run:on("newRunStarted", LootShared.Reset)
end

---@param baseFun fun(run: table, room: table)
---@param run table
---@param room table
function LootShared.OnUnlockedRewardedRoom(baseFun, run, room)
    local playerIndex = LootQuery.UseNextHeroForLoot()
    if playerIndex then
        room.CoopModPlayerId = playerIndex
        HeroContext.RunWithHeroContext(CoopPlayers.GetHero(playerIndex), baseFun, run, room)
    else
        baseFun(run, room)
    end
end

---@param baseFun fun(eventSource: table, args: table)
---@param eventSource table
---@param args table
function LootShared.SpawnRoomReward(baseFun, eventSource, args)
    args = args or {}
    local room = CurrentRun.CurrentRoom
    local roomRewardPredefinedPlayerId = room.CoopModPlayerId

    if roomRewardPredefinedPlayerId == nil then
        -- 开局和部分特殊房不会经过 DoUnlockRoomExits；首份沿当前英雄分配，并同步轮换游标。 / Opening and special rooms may bypass DoUnlockRoomExits; assign the first reward to the current hero and synchronize the rotation cursor.
        roomRewardPredefinedPlayerId = CoopPlayers.GetPlayerByHero(CurrentRun.Hero) or 1
        room.CoopModPlayerId = roomRewardPredefinedPlayerId
        LootQuery.MarkHeroForLoot(roomRewardPredefinedPlayerId)
    end

    local hero = roomRewardPredefinedPlayerId and CoopPlayers.GetHero(roomRewardPredefinedPlayerId) or CurrentRun.Hero

    if hero.IsDead then
        local alternativePlayerIndex
        if roomRewardPredefinedPlayerId then
            alternativePlayerIndex = LootQuery.UseNextHeroForLoot()

            if not alternativePlayerIndex then
                DebugPrint { Text = "Cannot spawn a loot for a player. Cannot choose alternative hero" }
                return baseFun(eventSource, args)
            end

            hero = CoopPlayers.GetHero(alternativePlayerIndex)
        else
            hero = CoopPlayers.GetAliveHeroes()[1]

            if not hero then
                DebugPrint { Text = "Cannot spawn a loot for a player. All players are dead" }
                return baseFun(eventSource, args)
            end
        end
    end

    -- 第一份奖励沿用既有玩家轮换上下文。
    -- The first reward keeps the existing rotating hero context.
    -- 自定义房间奖励函数会在内部创建 loot 后直接返回 nil；记录期间创建的首份 loot，避免船区等路径丢失双奖励。 / Custom room reward functions may create loot internally and return nil; retain the first loot created during the call so ship-area paths keep their second reward.
    room.CoopModSpawnRoomRewardActive = true
    room.CoopModPrimaryRoomReward = nil
    local nativeReward = HeroContext.RunWithHeroContextAwait(hero, baseFun, eventSource, args)
    local reward = nativeReward or room.CoopModPrimaryRoomReward
    room.CoopModSpawnRoomRewardActive = nil
    if reward ~= nil and reward.Name == "MixerIBossDrop" then
        -- The clear reward is a safe checkpoint: the boss is dead and presentation leftovers may be cleared.
        -- 通关奖励生成是安全恢复点：Boss 已死亡，此时可以清理黑幕和摄像机演出残留。
        ChronosRecovery.Recover("boss-reward-spawned", true)
    end
    if room.RoomSetName == "O" then
        -- 船区奖励由转舵后的 encounter override 决定，记录实体创建以核对预选与实际落地是否一致。
        -- Ship rewards use the post-wheel encounter override; record created entities to compare preselection with world spawn.
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] first-generated room=%s encounter=%s player=P%d reward=%s id=%s type=%s",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), roomRewardPredefinedPlayerId,
            tostring(reward and reward.Name), tostring(reward and reward.ObjectId),
            tostring(LootShared.GetRoomRewardType(room, reward))
        ))
    end
    CoopAppendTraceLog(string.format(
        "[CoopRewardTrace] room=%s encounter=%s firstPlayer=P%d native=%s tracked=%s reward=%s type=%s",
        tostring(room.Name),
        tostring(room.Encounter and room.Encounter.Name),
        roomRewardPredefinedPlayerId,
        tostring(nativeReward and nativeReward.Name),
        tostring(room.CoopModPrimaryRoomReward and room.CoopModPrimaryRoomReward.Name),
        tostring(reward and reward.Name),
        tostring(LootShared.GetRoomRewardType(room, reward))
    ))
    LootShared.SpawnSecondFieldsOptionalReward(baseFun, eventSource, args, room, reward)
    LootShared.SpawnSecondShipsReward(baseFun, eventSource, args, room, reward)
    LootShared.SpawnSecondNormalRoomReward(baseFun, eventSource, args, room, reward)
    return reward
end

---@private
function LootShared.ShouldSpawnSecondShipsReward(room, reward)
    local encounterName = room and room.Encounter and room.Encounter.Name
    return Config and Config.ExpandedRoomDoubleRewards
        and reward ~= nil
        and room ~= nil
        and room.RoomSetName == "O"
        and encounterName == "GeneratedO"
        and not room.CoopSecondShipsRewardSpawned
        and not room.CoopSpawningSecondShipsReward
        and LootShared.GetRoomRewardType(room, reward) ~= "Empty"
end

---@private
---Spawns the second reward after a Thessaly ship-wheel encounter.
---在塞萨利裂谷船舵遭遇战结算后生成第二份奖励。
function LootShared.SpawnSecondShipsReward(baseFun, eventSource, args, room, reward)
    if not LootShared.ShouldSpawnSecondShipsReward(room, reward) then
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] second-skip room=%s encounter=%s reward=%s type=%s expanded=%s spawned=%s spawning=%s",
            tostring(room and room.Name), tostring(room and room.Encounter and room.Encounter.Name),
            tostring(reward and reward.Name), tostring(LootShared.GetRoomRewardType(room, reward)),
            tostring(Config and Config.ExpandedRoomDoubleRewards),
            tostring(room and room.CoopSecondShipsRewardSpawned), tostring(room and room.CoopSpawningSecondShipsReward)
        ))
        return
    end

    local playerId = LootQuery.UseNextHeroForLoot()
    local hero = playerId and CoopPlayers.GetHero(playerId)
    if hero == nil or hero.IsDead then
        return
    end

    local rewardType = LootShared.GetRoomRewardType(room, reward)
    room.CoopSecondShipsRewardSpawned = true
    room.CoopSpawningSecondShipsReward = true
    CoopAppendTraceLog(string.format(
        "[CoopShipsRewardTrace] second-start room=%s encounter=%s player=P%d first=%s firstId=%s type=%s",
        tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), playerId,
        tostring(reward.Name), tostring(reward.ObjectId), tostring(rewardType)
    ))

    -- Reserve a nearby target before the native reward flow may destroy or replace the first entity.
    -- 在本体流程可能销毁或替换首份实体前预留旁侧落点。
    local spawnTarget = SpawnObstacle({
        Name = "InvisibleTarget",
        Group = "Standing",
        DestinationId = reward.ObjectId,
        OffsetX = 120,
    })

    HeroContext.RunWithHeroContextAwait(hero, function()
        local secondArgs = MergeTables(args, {
            RewardOverride = rewardType,
            SpawnRewardOnId = spawnTarget,
            IgnoreRoomSpawnOnLootPoint = true,
            AutoLoadPackages = true,
            IgnoreAssert = true,
        })

        if rewardType == "Boon" then
            -- Ship god boons use P2's native god pool, keepsake force, and rarity effects.
            -- 船区主神 boon 使用 P2 的本体神明池、定向信物与稀有度效果。
            local secondReward = {
                Name = room.Name,
                ChosenRewardType = "Boon",
                ForcedBoonNames = {},
            }
            SetupRoomReward(CurrentRun, secondReward, nil, {
                AlwaysSetupForceLootName = true,
            })
            secondArgs.LootName = secondReward.ForceLootName
            CoopAppendTraceLog(string.format(
                "[CoopShipsRewardTrace] second-boon-preselect room=%s player=P%d force=%s",
                tostring(room.Name), playerId, tostring(secondReward.ForceLootName)
            ))
            CoopDebugMonitor.RecordReward("ships-boon-preselect", playerId, secondReward.ForceLootName, secondReward.ForceLootName)
        end

        local secondReward = baseFun(eventSource, secondArgs)
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] second-generated room=%s encounter=%s player=P%d first=%s firstId=%s second=%s secondId=%s type=%s",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), playerId,
            tostring(reward.Name), tostring(reward.ObjectId),
            tostring(secondReward and secondReward.Name), tostring(secondReward and secondReward.ObjectId), tostring(rewardType)
        ))
        CoopDebugMonitor.RecordReward("ships-reward-second-spawn", playerId, secondReward and secondReward.Name, secondReward and secondReward.Name)
    end)

    Destroy({ Id = spawnTarget })
    room.CoopSpawningSecondShipsReward = nil
end

---@private
function LootShared.ShouldSpawnSecondFieldsOptionalReward(args, room, reward)
    return Config and Config.NormalRoomDoubleRewards
        and reward ~= nil
        and room ~= nil
        and room.RoomSetName == "H"
        and args.NotRequiredPickup
        and args.SpawnRewardOnId ~= nil
        and not room.CoopSpawningSecondFieldsOptionalReward
end

---@private
---Duplicates a Fields mini reward beside the native optional reward.
---在本体原野次要奖励旁复制一份同类型奖励。
function LootShared.SpawnSecondFieldsOptionalReward(baseFun, eventSource, args, room, reward)
    if not LootShared.ShouldSpawnSecondFieldsOptionalReward(args, room, reward) then
        return
    end

    local playerId = LootQuery.UseNextHeroForLoot()
    local hero = playerId and CoopPlayers.GetHero(playerId)
    if hero == nil or hero.IsDead then
        return
    end

    room.CoopSpawningSecondFieldsOptionalReward = true
    local spawnTarget = SpawnObstacle({
        Name = "InvisibleTarget",
        Group = "Standing",
        DestinationId = reward.ObjectId,
        OffsetX = 120,
    })

    HeroContext.RunWithHeroContextAwait(hero, function()
        local secondArgs = MergeTables(args, {
            SpawnRewardOnId = spawnTarget,
            IgnoreRoomSpawnOnLootPoint = true,
        })
        local secondReward = baseFun(eventSource, secondArgs)
        if secondReward ~= nil then
            MapState.OptionalRewards[secondReward.ObjectId] = secondReward
        end
        CoopAppendTraceLog(string.format(
            "[CoopFieldsOptionalTrace] second-spawn room=%s player=P%d first=%s firstId=%s second=%s secondId=%s",
            tostring(room.Name), playerId, tostring(reward.Name), tostring(reward.ObjectId),
            tostring(secondReward and secondReward.Name), tostring(secondReward and secondReward.ObjectId)
        ))
    end)

    Destroy({ Id = spawnTarget })
    room.CoopSpawningSecondFieldsOptionalReward = nil
end

---@private
function LootShared.ShouldSpawnSecondNormalRoomReward(args, room, reward)
    if not (Config and Config.NormalRoomDoubleRewards) then
        return false
    end
    if reward == nil or room == nil then
        return false
    end
    if room.CoopSecondNormalRoomRewardSpawned or room.CoopSpawningSecondNormalRoomReward
        or room.CoopSecondShipsRewardSpawned or room.CoopSpawningSecondShipsReward then
        return false
    end
    -- 排除 cage / bonus / 指定生成点等特殊奖励路径。
    -- Exclude cage, bonus, and explicit-spawn reward paths.
    if args.RewardOverride ~= nil or args.NotRequiredPickup or args.SpawnRewardOnId ~= nil then
        return false
    end
    if room.DeferReward or room.NoReward then
        return false
    end
    local rewardType = LootShared.GetRoomRewardType(room, reward)
    if rewardType == nil or rewardType == "Story" or rewardType == "Empty" or rewardType == "Shop" then
        return false
    end

    local encounter = room.Encounter
    -- 当前只覆盖普通战斗房，Chaos/Event/Boss 后续单独适配。
    -- Only normal combat rooms are covered here; Chaos/Event/Boss need separate handling.
    if RunEx.IsBossRoomName(room.Name) then
        return false
    end

    -- MiniBoss 名称也会包含 Boss；只能按本体显式 Boss 标记排除，不能按字符串模糊匹配。 / MiniBoss names also contain Boss; exclude only explicit native boss markers, never a fuzzy name match.
    if encounter and (encounter.IsBoss or encounter.EncounterType == "Boss") then
        return false
    end

    -- 普通、精英和无 Encounter 的固定关键奖励共用本路径；Boss、商店和特殊生成点仍在前面排除。 / Normal, Elite, and encounterless fixed rewards share this path; Bosses, shops, and special spawns stay excluded above.
    if encounter ~= nil and encounter.EncounterType ~= "Default" and not (Config and Config.ExpandedRoomDoubleRewards) then
        return false
    end

    local aliveHeroes = CoopPlayers.GetAliveHeroes()
    return aliveHeroes ~= nil and #aliveHeroes > 1
end

---@private
function LootShared.GetRoomRewardType(room, reward)
    -- 与本体 SpawnRoomReward 相同，优先使用遭遇战/房间保存的奖励类型；不要仅从已创建 loot 反推。
    -- Match native SpawnRoomReward: prefer the encounter/room reward type instead of inferring only from created loot.
    local encounter = room and room.Encounter
    local rewardType = encounter and encounter.EncounterRoomRewardOverride
    rewardType = rewardType or room.ChangeReward or room.ChosenRewardType
    if rewardType ~= nil then
        return rewardType
    end

    local roomReward = room and room.Reward
    if type(roomReward) == "string" then
        return roomReward
    end
    if type(roomReward) == "table" and roomReward.Name ~= nil then
        return roomReward.Name
    end

    local lootData = reward and reward.Name and LootData[reward.Name]
    if reward and (reward.GodLoot or reward.TreatAsGodLootByShops or (lootData and lootData.GodLoot)) then
        return "Boon"
    end
    if reward and reward.Name == "WeaponUpgrade" then
        return "WeaponUpgrade"
    end
    -- 自定义房间函数的消耗品通常以奖励名创建，可直接作为本体 RewardOverride。 / Custom room functions usually create consumables by reward name, which can be reused as the native RewardOverride.
    return reward and reward.Name
end

---@private
function LootShared.SpawnSecondNormalRoomReward(baseFun, eventSource, args, room, reward)
    if not LootShared.ShouldSpawnSecondNormalRoomReward(args, room, reward) then
        return
    end

    local playerIndex = LootQuery.UseNextHeroForLoot()
    if playerIndex == nil then
        return
    end

    local hero = CoopPlayers.GetHero(playerIndex)
    if hero == nil or hero.IsDead then
        return
    end

    room.CoopSecondNormalRoomRewardSpawned = true
    room.CoopSpawningSecondNormalRoomReward = true
    CoopAppendTraceLog(string.format(
        "[CoopRewardTrace] second-spawn room=%s player=P%d type=%s",
        tostring(room.Name),
        playerIndex,
        tostring(LootShared.GetRoomRewardType(room, reward))
    ))

    HeroContext.RunWithHeroContextAwait(hero, function()
        -- Chaos 与事件奖励保持复制；普通/Elite 主神 boon 才独立生成。 / Chaos and event rewards copy; only normal/Elite god boons roll independently.
        local encounter = room.Encounter
        local isCopyOnlyRoom = room.RoomSetName == "Chaos" or (encounter ~= nil and encounter.EncounterType == "NonCombat")
        local rewardType = LootShared.GetRoomRewardType(room, reward)
        local secondLoot
        if rewardType == "Boon" and not isCopyOnlyRoom then
            secondLoot = LootShared.SpawnIndependentBoonReward(baseFun, eventSource, args, room)
        else
            -- 非 boon 奖励复制第一份，保持双人房的固定奖励一致。
            -- Non-boon rewards copy the first reward to keep fixed room rewards identical.
            secondLoot = baseFun(eventSource, MergeTables(args, {
                RewardOverride = rewardType,
                LootName = room.ForceLootName,
                AutoLoadPackages = true,
            }))
        end
        if room.RoomSetName == "O" then
            CoopAppendTraceLog(string.format(
                "[CoopShipsRewardTrace] second-generated room=%s player=P%d source=%s reward=%s id=%s type=%s",
                tostring(room.Name), playerIndex, tostring(reward and reward.Name),
                tostring(secondLoot and secondLoot.Name), tostring(secondLoot and secondLoot.ObjectId), tostring(rewardType)
            ))
        end
    end)

    room.CoopSpawningSecondNormalRoomReward = false
end

---@private
---为第二位玩家按本体规则预生成普通 boon，不继承第一份的神明。
---Pre-generates a normal boon for the second player using native rules without inheriting the first god.
function LootShared.SpawnIndependentBoonReward(baseFun, eventSource, args, room)
    -- 使用临时奖励记录，避免覆盖房间的 P1 奖励数据。
    -- Use a temporary reward record so the P1 room reward data is not overwritten.
    local secondReward = {
        Name = room.Name,
        ChosenRewardType = "Boon",
        ForcedBoonNames = {},
    }

    -- 不传 previouslyChosenRewards：原版连续房间允许再次遇到同一神明。
    -- Do not pass previouslyChosenRewards: native consecutive rooms may repeat the same god.
    SetupRoomReward(CurrentRun, secondReward, nil, {
        AlwaysSetupForceLootName = true,
    })

    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    -- 记录预选结果与当前信物 trait，专门诊断 P2 强制 boon 是否在选池阶段丢失。 / Record selection and keepsake trait to diagnose P2 force-boon loss during pool selection.
    CoopDebugMonitor.RecordReward("room-boon-preselect", playerId, secondReward.ForceLootName, secondReward.ForceLootName)

    if secondReward.ForceLootName == nil then
        return
    end

    -- 本体 GiveLoot 会在当前英雄上下文消耗对应信物，并应用稀有度加成。
    -- Native GiveLoot consumes the matching keepsake and applies rarity bonuses in this hero context.
    local secondLoot = baseFun(eventSource, MergeTables(args, {
        RewardOverride = "Boon",
        LootName = secondReward.ForceLootName,
        AutoLoadPackages = true,
    }))
    CoopDebugMonitor.RecordReward("room-boon-spawn", playerId, secondReward.ForceLootName, secondReward.ForceLootName)
    return secondLoot
end

function LootShared.Reset()
    HeroContextProxyStore.GetOrCreate(CurrentRun, "LootTypeHistory"):Reset()
    LootQuery.Reset()
end

---@private
local NamedNpcRewardEncounterPrefixes = {
    ArtemisCombat = true,
    AthenaCombat = true,
    DionysusCombat = true,
    HadesCombat = true,
}

---@private
function LootShared.IsNamedNpcRewardEncounter(room)
    local encounterName = room and room.Encounter and room.Encounter.Name
    if encounterName == nil then
        return false
    end

    for prefix in pairs(NamedNpcRewardEncounterPrefixes) do
        if string.find(encounterName, "^" .. prefix) then
            return true
        end
    end
    return false
end

---@private
function LootShared.ShouldSpawnSecondDirectReward(args, reward)
    if not (Config and Config.ExpandedRoomDoubleRewards) then
        return false
    end
    if reward == nil or CurrentRun == nil or CurrentRun.CurrentRoom == nil then
        return false
    end

    local room = CurrentRun.CurrentRoom
    -- 第二份房间奖励内部可能再次调用 GiveLoot；该调用属于已计划的第二份，不能再额外复制成第三份。 / The second room-reward path can call GiveLoot internally; it is already the planned second reward and must not be copied into a third one.
    if room.CoopModSpawnRoomRewardActive
        or room.CoopSpawningSecondNormalRoomReward
        or room.CoopSecondDirectRewardSpawned
        or room.CoopSpawningSecondDirectReward
        or room.CoopSpawningFieldsPickupSecondReward
        or room.CoopSpawningSecondShipsReward then
        return false
    end
    if RunEx.IsBossRoomName(room.Name) or room.DeferReward or room.NoReward then
        return false
    end
    if args == nil or args.BoughtFromShop or args.PurchasedFromShop then
        return false
    end

    local encounter = room.Encounter
    -- 某些哀悼原野普通房会绕过 SpawnRoomReward 直接调用 GiveLoot；将普通/精英战斗房纳入 fallback。
    -- Some Mourning Fields combat rooms bypass SpawnRoomReward and call GiveLoot directly; include normal and elite combat rooms in the fallback.
    local isCombatEncounter = encounter ~= nil
        and (encounter.EncounterType == "Default" or encounter.EncounterType == "Miniboss")
    return room.RoomSetName == "Chaos"
        or isCombatEncounter
        or (encounter ~= nil and encounter.EncounterType == "NonCombat")
        or LootShared.IsNamedNpcRewardEncounter(room)
end

---@private
function LootShared.SpawnSecondDirectReward(baseFun, args, reward)
    if not LootShared.ShouldSpawnSecondDirectReward(args, reward) then
        return
    end

    local playerId = LootQuery.UseNextHeroForLoot()
    local hero = playerId and CoopPlayers.GetHero(playerId)
    if hero == nil or hero.IsDead then
        return
    end

    local room = CurrentRun.CurrentRoom
    room.CoopSecondDirectRewardSpawned = true
    room.CoopSpawningSecondDirectReward = true

    HeroContext.RunWithHeroContextAwait(hero, function()
        local secondArgs = MergeTables(args, {
            SpawnPoint = args.SpawnPoint or reward.ObjectId,
            OffsetX = (args.OffsetX or 0) + 120,
            AutoLoadPackages = true,
        })

        local lootData = reward.Name and LootData[reward.Name]
        local isGodLoot = reward.GodLoot or reward.TreatAsGodLootByShops or (lootData and lootData.GodLoot)
        if isGodLoot and room.RoomSetName ~= "Chaos" and (room.Encounter == nil or room.Encounter.EncounterType ~= "NonCombat") then
            -- 普通战斗房绕过 SpawnRoomReward 时，主神 boon 仍须按 P2 本体奖池独立生成。
            -- When a normal combat room bypasses SpawnRoomReward, its god boon must still roll independently from P2's native pool.
            local secondReward = {
                Name = room.Name,
                ChosenRewardType = "Boon",
                ForcedBoonNames = {},
            }
            SetupRoomReward(CurrentRun, secondReward, nil, {
                AlwaysSetupForceLootName = true,
            })
            secondArgs.ForceLootName = secondReward.ForceLootName
            CoopDebugMonitor.RecordReward("direct-room-boon-preselect", playerId, secondReward.ForceLootName, secondReward.ForceLootName)
        else
            -- Chaos/Event 与非主神固定奖励复制第一份，保持原事件内容与代价。
            -- Chaos/events and fixed non-god rewards copy the first result to preserve event content and costs.
            secondArgs.ForceLootName = args.ForceLootName or reward.Name
        end

        baseFun(secondArgs)
        CoopDebugMonitor.RecordReward("direct-reward-second-spawn", playerId, secondArgs.ForceLootName, secondArgs.ForceLootName)
    end)

    room.CoopSpawningSecondDirectReward = false
end

---@param baseFun fun(args: table): table
---@param hero table
---@param args table
---@return table
function LootShared.GiveBlindLoot(baseFun, hero, args)
    return HeroContext.RunWithHeroContextReturn(hero, baseFun, args)
end

---@param baseFun fun(args: table): table
---@param args table
---@return table
function LootShared.GiveLoot(baseFun, args)
    local reward = baseFun(args)
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room and room.CoopModSpawnRoomRewardActive and not room.CoopSpawningSecondNormalRoomReward then
        -- 本体 SpawnRoomReward 的自定义分支不返回 loot，保存首个 GiveLoot 结果供外层补发第二份。 / Native custom SpawnRoomReward branches do not return loot, so retain the first GiveLoot result for the outer second-reward pass.
        room.CoopModPrimaryRoomReward = room.CoopModPrimaryRoomReward or reward
    end
    LootShared.SpawnSecondDirectReward(baseFun, args or {}, reward)
    return reward
end

---@param loot table
---@param hero table
function LootShared.CanUseHeroLoot(loot, hero)
    return true
end

return LootShared
