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
---@type Events
local Events = ModRequire "../logic/Events.lua"
---@type Config
local Config = ModRequire "../config.lua"

---@type LootQuery
local LootQuery = ModRequire "../logic/loot/LootQuery.lua"

---@type CoopDebugMonitor
local CoopDebugMonitor = ModRequire "../logic/CoopDebugMonitor.lua"

local InteractLogicHooks = SimpleHook.New()

---@private
---Returns the Fields reward cage that owns this loot object.
---返回持有该奖励物件的哀悼原野奖励笼。
local function GetFieldsRewardCage(lootId)
    if MapState == nil or MapState.ActiveObstacles == nil then
        return nil
    end

    for _, obstacle in pairs(MapState.ActiveObstacles) do
        if obstacle.Name == "FieldsRewardCage" and obstacle.RewardId == lootId then
            return obstacle
        end
    end
    return nil
end

---@private
---Marks a reward before native Fields code destroys its cage.
---在本体销毁哀悼原野奖励笼前，为奖励实体写入标记。
local function MarkFieldsCageReward(rewardId, cageId)
    local loot = LootObjects and LootObjects[rewardId]
    if loot == nil and MapState and MapState.ActiveObstacles then
        loot = MapState.ActiveObstacles[rewardId]
    end
    if loot ~= nil then
        loot.CoopFieldsCageReward = true
        loot.CoopFieldsCageId = cageId
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] marked reward=%s loot=%s cage=%s",
            tostring(rewardId), tostring(loot.Name), tostring(cageId)
        ))
    end
end

---@private
local function IsShipsRoomReward(room, loot)
    return room ~= nil
        and room.RoomSetName == "O"
        and loot ~= nil
        and room.Encounter ~= nil
        and room.Encounter.Name == "GeneratedO"
        and not loot.BoughtFromShop
        and not loot.Purchased
end

---@private
local function IsFieldsMiniBossRoom(room)
    return room ~= nil
        and (string.find(tostring(room.Name), "_MiniBoss") ~= nil
            or (room.Encounter ~= nil and room.Encounter.EncounterType == "Miniboss"))
end

---@private
---Finds the other living player without changing the room-reward cursor.
---查找另一位存活玩家，不改动房间奖励轮换游标。
local function GetOtherLivingPlayer(playerId)
    for otherPlayerId, hero in CoopPlayers.PlayersIterator() do
        if otherPlayerId ~= playerId and hero ~= nil and not hero.IsDead then
            return otherPlayerId, hero
        end
    end
    return nil, nil
end

---@private
---Spawns the second Fields cage reward only after the first choice has completed.
---仅在首个奖励选择完成后生成第二份哀悼原野笼中奖励。
local function SpawnSecondFieldsCageReward(loot, pickerPlayerId, spawnTarget)
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room == nil or room.RoomSetName ~= "H" or loot == nil then
        return
    end
    if IsFieldsMiniBossRoom(room) then
        -- H Miniboss 在入场时已由通用 Elite 路径生成两份，不能再在拾取后补出第三份。
        -- H Miniboss already receives two rewards through the generic Elite path at entry; never add a third after pickup.
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] second-skip room=%s reason=miniboss-native-double",
            tostring(room.Name)
        ))
        return
    end
    if not (Config and Config.NormalRoomDoubleRewards) or loot.CoopFieldsSecondRewardSpawned then
        return
    end
    if not loot.CoopFieldsCageReward and GetFieldsRewardCage(loot.ObjectId) == nil then
        return
    end

    local secondPlayerId, secondHero = GetOtherLivingPlayer(pickerPlayerId)
    if secondHero == nil then
        return
    end

    loot.CoopFieldsSecondRewardSpawned = true
    room.CoopSpawningFieldsPickupSecondReward = true
    LootQuery.MarkHeroForLoot(secondPlayerId)

    HeroContext.RunWithHeroContextAwait(secondHero, function()
        local secondLootName = loot.Name
        if loot.GodLoot then
            -- 主神 boon 必须重新按 P2 信物和本体奖池预选，不能复制 P1 的神明。
            -- God boons must roll again from P2's keepsake and native god pool, never copy P1's god.
            local secondReward = {
                Name = room.Name,
                ChosenRewardType = "Boon",
                ForcedBoonNames = {},
            }
            SetupRoomReward(CurrentRun, secondReward, nil, {
                AlwaysSetupForceLootName = true,
            })
            secondLootName = secondReward.ForceLootName
            CoopDebugMonitor.RecordReward("fields-boon-preselect", secondPlayerId, secondLootName, secondLootName)
        end

        if secondLootName ~= nil then
            local secondLoot = GiveLoot({
                ForceLootName = secondLootName,
                SpawnPoint = spawnTarget,
                AutoLoadPackages = true,
            })
            if secondLoot ~= nil then
                -- 第二份由 coop 保证；禁止波塞冬等本体逻辑再复制出第三份。
                -- This is the co-op second reward; prevent native duplication from creating a third copy.
                secondLoot.CanDuplicate = false
                secondLoot.CoopFieldsSecondReward = true
            end
            CoopAppendTraceLog(string.format(
                "[CoopFieldsRewardTrace] second-spawn room=%s picker=P%d player=P%d first=%s second=%s",
                tostring(room.Name), pickerPlayerId, secondPlayerId, tostring(loot.Name), tostring(secondLootName)
            ))
            CoopDebugMonitor.RecordReward("fields-reward-second-spawn", secondPlayerId, secondLootName, secondLootName)
        end
    end)

    room.CoopSpawningFieldsPickupSecondReward = nil
end

---@public
---Reserves a stable spawn point for a Fields Selene reward that opens its menu without UseLoot.
---为不经过 UseLoot、直接打开菜单的原野月神奖励预留稳定生成点。
function InteractLogicHooks.PrepareFieldsSpellMenu(loot, pickerPlayerId)
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room == nil or room.RoomSetName ~= "H" or loot == nil then
        return nil
    end
    if loot.Name ~= "SpellDrop" and loot.Name ~= "TalentDrop" then
        return nil
    end
    if IsFieldsMiniBossRoom(room)
        or loot.CoopFieldsSecondReward
        or loot.CoopFieldsSecondRewardSpawned
        or (not loot.CoopFieldsCageReward and GetFieldsRewardCage(loot.ObjectId) == nil) then
        return nil
    end

    loot.CoopModPickerPlayerId = pickerPlayerId
    local spawnTarget = SpawnObstacle({
        Name = "InvisibleTarget",
        Group = "Standing",
        DestinationId = loot.ObjectId,
    })
    CoopAppendTraceLog(string.format(
        "[CoopFieldsRewardTrace] spell-menu-start room=%s player=P%d loot=%s id=%s target=%s",
        tostring(room.Name), pickerPlayerId, tostring(loot.Name), tostring(loot.ObjectId), tostring(spawnTarget)
    ))
    return {
        Loot = loot,
        PickerPlayerId = pickerPlayerId,
        SpawnTarget = spawnTarget,
    }
end

---@public
---Spawns the second Fields Selene reward after the first spell menu has completed.
---首个月神菜单完成后生成第二份原野月神奖励。
function InteractLogicHooks.CompleteFieldsSpellMenu(state)
    if state == nil then
        return
    end

    SpawnSecondFieldsCageReward(state.Loot, state.PickerPlayerId, state.SpawnTarget)
    if state.SpawnTarget ~= nil then
        Destroy({ Id = state.SpawnTarget })
    end
    CoopAppendTraceLog(string.format(
        "[CoopFieldsRewardTrace] spell-menu-finished player=P%d loot=%s id=%s",
        state.PickerPlayerId, tostring(state.Loot and state.Loot.Name), tostring(state.Loot and state.Loot.ObjectId)
    ))
end

function InteractLogicHooks.wrap.UseLoot(baseFun, usee, args, user)
    local pickerPlayerId = CoopPlayers.GetCurrentPlayerId() or 1
    local room = CurrentRun and CurrentRun.CurrentRoom

    if usee ~= nil and (usee.Name == "SpellDrop" or usee.Name == "TalentDrop") then
        -- Spell rewards may use UseLoot instead of UseConsumableItem depending on their native path.
        -- 月神奖励会随本体路径走 UseLoot 或 UseConsumableItem；两者都记录实际拾取者。
        usee.CoopModPickerPlayerId = pickerPlayerId
        CoopAppendTraceLog(string.format(
            "[CoopSpellTrace] pickup-via-loot player=P%d item=%s id=%s",
            pickerPlayerId, tostring(usee.Name), tostring(usee.ObjectId)
        ))
    end
    local isFieldsCageLoot = room ~= nil
        and room.RoomSetName == "H"
        and usee ~= nil
        and (usee.CoopFieldsCageReward or GetFieldsRewardCage(usee.ObjectId) ~= nil)
        and not usee.CoopFieldsSecondReward
        and not usee.CoopFieldsSecondRewardSpawned

    if isFieldsCageLoot then
        -- 原野奖励在战斗解锁后才可拾取；记录完整拾取边界以定位第二份实体丢失位置。
        -- Fields rewards become usable after combat unlock; record the pickup boundary to locate missing second loot.
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] pickup-start room=%s encounter=%s player=P%d loot=%s id=%s",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), pickerPlayerId,
            tostring(usee.Name), tostring(usee.ObjectId)
        ))
    elseif IsShipsRoomReward(room, usee) then
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] pickup-start room=%s encounter=%s player=P%d loot=%s id=%s",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), pickerPlayerId,
            tostring(usee.Name), tostring(usee.ObjectId)
        ))
    end

    local spawnTarget = nil
    if isFieldsCageLoot then
        -- 与本体波塞冬双奖励相同：先建立稳定的落点，避免首份选择销毁 loot 后丢失坐标。
        -- Match native Poseidon duplication: reserve a stable spawn point before the first choice may destroy the loot.
        spawnTarget = SpawnObstacle({
            Name = "InvisibleTarget",
            Group = "Standing",
            DestinationId = usee.ObjectId,
        })
    end

    local result = { baseFun(usee, args, user) }

    if isFieldsCageLoot then
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] pickup-finished room=%s player=P%d loot=%s id=%s result=%s",
            tostring(room.Name), pickerPlayerId, tostring(usee.Name), tostring(usee.ObjectId), tostring(result[1])
        ))
    elseif IsShipsRoomReward(room, usee) then
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] pickup-finished room=%s player=P%d loot=%s id=%s result=%s",
            tostring(room.Name), pickerPlayerId, tostring(usee.Name), tostring(usee.ObjectId), tostring(result[1])
        ))
    end

    if isFieldsCageLoot and result[1] then
        SpawnSecondFieldsCageReward(usee, pickerPlayerId, spawnTarget)
    end
    if isFieldsCageLoot then
        if spawnTarget ~= nil then
            Destroy({ Id = spawnTarget })
        end
    end

    return table.unpack(result)
end

function InteractLogicHooks.wrap.StartFieldsEncounter(baseFun, rewardCage, args)
    if rewardCage ~= nil then
        MarkFieldsCageReward(rewardCage.RewardId, rewardCage.ObjectId)
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] encounter-start room=%s cage=%s reward=%s",
            tostring(CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Name),
            tostring(rewardCage.ObjectId), tostring(rewardCage.RewardId)
        ))
    end
    return baseFun(rewardCage, args)
end

function InteractLogicHooks.wrap.UnlockRewardCagesMiniboss(baseFun, encounter, args)
    if encounter ~= nil then
        MarkFieldsCageReward(encounter.RewardId, encounter.RewardCageId)
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] miniboss-unlock room=%s encounter=%s cage=%s reward=%s",
            tostring(CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Name), tostring(encounter.Name),
            tostring(encounter.RewardCageId), tostring(encounter.RewardId)
        ))
    end
    return baseFun(encounter, args)
end

function InteractLogicHooks.wrap.UseConsumableItem(baseFun, consumableItem, args, user)
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    local room = CurrentRun and CurrentRun.CurrentRoom
    local isFieldsReward = room ~= nil
        and room.RoomSetName == "H"
        and consumableItem ~= nil
        and consumableItem.CoopFieldsCageReward
    local isShipsReward = IsShipsRoomReward(room, consumableItem)
    local isFieldsSeleneReward = room ~= nil
        and room.RoomSetName == "H"
        and consumableItem ~= nil
        and (consumableItem.Name == "SpellDrop" or consumableItem.Name == "TalentDrop")
    local fieldsSeleneStates = isFieldsSeleneReward and (room.CoopFieldsSeleneRewardStates or {}) or nil
    if isFieldsSeleneReward then
        room.CoopFieldsSeleneRewardStates = fieldsSeleneStates
    end
    local fieldsSeleneState = fieldsSeleneStates and fieldsSeleneStates[consumableItem.Name]
    local shouldRearmFieldsConsumable = isFieldsReward
        and not IsFieldsMiniBossRoom(room)
        and not consumableItem.CoopFieldsSecondConsumable

    if isFieldsReward then
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] pickup-start room=%s encounter=%s player=P%d loot=%s id=%s kind=consumable",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), playerId,
            tostring(consumableItem.Name), tostring(consumableItem.ObjectId)
        ))
    elseif isShipsReward then
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] pickup-start room=%s encounter=%s player=P%d loot=%s id=%s kind=consumable",
            tostring(room.Name), tostring(room.Encounter and room.Encounter.Name), playerId,
            tostring(consumableItem.Name), tostring(consumableItem.ObjectId)
        ))
    end

    if consumableItem ~= nil and (consumableItem.Name == "SpellDrop" or consumableItem.Name == "TalentDrop") then
        -- 保存实际拾取者，供异步打开的塞勒涅菜单恢复 P2 HeroContext 与手柄控制权。
        -- Preserve the actual picker so asynchronously opened Selene menus restore P2's HeroContext and controller ownership.
        consumableItem.CoopModPickerPlayerId = playerId
        CoopAppendTraceLog(string.format(
            "[CoopSpellTrace] pickup player=P%d item=%s id=%s",
            playerId,
            tostring(consumableItem.Name),
            tostring(consumableItem.ObjectId)
        ))
    end

    if isFieldsSeleneReward and fieldsSeleneState == "rearmed" then
        -- The native respawn creates a new item table, so use room state to consume the one co-op second Selene reward exactly once.
        -- 本体重生会创建新的物品表，故用房间状态确保 coop 的第二份月神奖励只会被领取一次。
        fieldsSeleneStates[consumableItem.Name] = "claimed"
        consumableItem.RespawnAfterUse = nil
    elseif shouldRearmFieldsConsumable then
        -- 与本体 Poseidon 消耗品双奖励相同：首份使用后保留同一实体一次，再由第二名玩家领取。
        -- Match native Poseidon consumable duplication: keep the same entity for one more use, then let the second player claim it.
        consumableItem.RespawnAfterUse = true
        consumableItem.CoopFieldsSecondConsumablePending = true
    end
    local result = { baseFun(consumableItem, args, user) }

    if consumableItem ~= nil and consumableItem.CoopFieldsSecondConsumablePending then
        consumableItem.RespawnAfterUse = nil
        consumableItem.CoopFieldsSecondConsumablePending = nil
        consumableItem.CoopFieldsSecondConsumable = true
        if fieldsSeleneStates ~= nil then
            fieldsSeleneStates[consumableItem.Name] = "rearmed"
        end
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] second-rearmed room=%s firstPlayer=P%d loot=%s id=%s",
            tostring(room.Name), playerId, tostring(consumableItem.Name), tostring(consumableItem.ObjectId)
        ))
    end

    if isFieldsReward then
        CoopAppendTraceLog(string.format(
            "[CoopFieldsRewardTrace] pickup-finished room=%s player=P%d loot=%s id=%s result=%s kind=consumable",
            tostring(room.Name), playerId, tostring(consumableItem.Name), tostring(consumableItem.ObjectId), tostring(result[1])
        ))
    elseif isShipsReward then
        CoopAppendTraceLog(string.format(
            "[CoopShipsRewardTrace] pickup-finished room=%s player=P%d loot=%s id=%s result=%s kind=consumable",
            tostring(room.Name), playerId, tostring(consumableItem.Name), tostring(consumableItem.ObjectId), tostring(result[1])
        ))
    end

    return table.unpack(result)
end

function InteractLogicHooks.wrap.OnUsed(_OnUsed, args)
    if type(args[1]) == "function" then
        _OnUsed { function(triggerArgs)
            local item = triggerArgs.TriggeredByTable
            if item == nil then
                return
            end

            local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)

            if item.UsedByHero and item.UsedByHero ~= hero then
                -- Don't collect LobAmmoPack for by wrong player
                return
            end

            local mainHero = HeroContext.GetDefaultHero()

            local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
            if functionName == "UseEscapeDoor" and hero ~= mainHero then
                -- Pact door
                -- Disable control for a second player
                -- A second player in context resets weapon choice for the first player
                return;
            else
                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        end
        }
    else
        _OnUsed({
            args[1],
            function(triggerArgs)
                HeroContext.RunWithHeroContext(
                    CoopPlayers.GetHeroByUnit(triggerArgs.UserId),
                    args[2],
                    triggerArgs
                )
            end
        })
    end
end

function InteractLogicHooks.wrap.OnActiveUseTarget(baseFun, args)
    if type(args[1]) == "function" then
        baseFun {
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        baseFun(args)
    end
end

function InteractLogicHooks.wrap.OnActiveUseTargetLost(baseFun, args)
    if type(args[1]) == "function" then
        baseFun {
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        baseFun(args)
    end
end

---@private
local function HasAnotherLivingFountainUser(users)
    for playerId, hero in CoopPlayers.PlayersIterator() do
        if hero ~= nil and not hero.IsDead and playerId ~= users.CurrentPlayerId and not users[playerId] then
            return true
        end
    end
    return false
end

function InteractLogicHooks.wrap.UseHealthFountain(baseFun, used, user)
    if CoopPlayers.GetPlayersCount() < 2 or CurrentRun == nil or CurrentRun.CurrentRoom == nil then
        return baseFun(used, user)
    end

    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    local hero = CoopPlayers.GetHero(playerId)
    local room = CurrentRun.CurrentRoom
    room.CoopHealthFountainUsers = room.CoopHealthFountainUsers or {}
    local users = room.CoopHealthFountainUsers[used.ObjectId] or {}
    room.CoopHealthFountainUsers[used.ObjectId] = users

    if users[playerId] then
        return
    end

    users[playerId] = true
    users.CurrentPlayerId = playerId
    local shouldRearm = HasAnotherLivingFountainUser(users)
    CoopAppendTraceLog(string.format(
        "[CoopFountainTrace] before room=%s player=P%d fountain=%s rearm=%s",
        tostring(room.Name), tostring(playerId), tostring(used.ObjectId), tostring(shouldRearm)
    ))
    local pendingKey = "CoopHealthFountainPending" .. tostring(used.ObjectId)
    if shouldRearm and used.BlockExitUntilUsed then
        -- 本体在本次使用结束时检查出口；临时占位确保 P1 使用后不会提前开门。 / Native code checks exits at the end of this use; a temporary marker prevents unlocking after only P1 has used it.
        MapState.RoomRequiredObjects[pendingKey] = used
    end

    local result
    if hero ~= nil then
        result = { HeroContext.RunWithHeroContextAwait(hero, baseFun, used, user) }
    else
        result = { baseFun(used, user) }
    end

    if shouldRearm then
        MapState.RoomRequiredObjects[pendingKey] = nil
        MapState.RoomRequiredObjects[used.ObjectId] = used
        if used.RecordObjectState and room.ObjectStates and room.ObjectStates[used.ObjectId] then
            -- 首次使用不应把本房永久存为耗尽；第二次使用仍交给本体正常记录。 / The first use must not persist this room as spent; the second use remains native and records normally.
            room.ObjectStates[used.ObjectId].UseableOff = nil
            room.ObjectStates[used.ObjectId].Animation = nil
        end
        UseableOn({ Id = used.ObjectId })
        RefreshUseButton(used.ObjectId, used)
    end

    users.CurrentPlayerId = nil
    CoopAppendTraceLog(string.format(
        "[CoopFountainTrace] after room=%s player=P%d fountain=%s rearmed=%s",
        tostring(room.Name), tostring(playerId), tostring(used.ObjectId), tostring(shouldRearm)
    ))
    return table.unpack(result)
end

function InteractLogicHooks.post.UseConsumableItem(consumableItem, args, user)
    if consumableItem.AddAmmo then
        Events.game:trigger("comsumeAmmoItem", consumableItem)
    end
end

return InteractLogicHooks
