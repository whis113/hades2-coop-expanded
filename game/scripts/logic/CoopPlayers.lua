--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContext
local HeroContext = ModRequire "HeroContext.lua"
---@type CoopControl
local CoopControl = ModRequire "CoopControl.lua"
---@type HeroEx
local HeroEx = ModRequire "HeroEx.lua"
---@type RunEx
local RunEx = ModRequire "RunEx.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "PlayerVisibilityHelper.lua"

---@class CoopPlayers
local CoopPlayers = {}

---@private
---@type table<number, table>
CoopPlayers.PlayerUnitIdToHero = {}
---@private
---@type table[]
CoopPlayers.CoopHeroes = {}

function CoopPlayers.IsPlayerHero(t)
    for i = 1, #CoopPlayers.CoopHeroes do
        if CoopPlayers.CoopHeroes[i] == t then
            return true
        end
    end
    return false
end

function CoopPlayers.GetMainHero()
    return CoopPlayers.CoopHeroes[1]
end

---@return number
function CoopPlayers.GetPlayersCount()
    return CoopGetPlayersCount()
end

---@param unitId integer
---@return boolean
function CoopPlayers.IsPlayerUnit(unitId)
    return CoopPlayers.PlayerUnitIdToHero[unitId] and true
end

function CoopPlayers.SetMainHero(hero)
    DebugPrint{Text = "Set main hero: " .. tostring(hero) }
    CoopPlayers.CoopHeroes[1] = hero
    if hero.ObjectId then
        CoopPlayers.PlayerUnitIdToHero[hero.ObjectId] = hero
    end
end

function CoopPlayers.GetHero(playerId)
    return CoopPlayers.CoopHeroes[playerId]
end

function CoopPlayers.SetHero(playerId, hero)
    CoopPlayers.CoopHeroes[playerId] = hero
end

function CoopPlayers.PlayersIterator()
    return ipairs(CoopPlayers.CoopHeroes)
end

function CoopPlayers.AdditionalHeroesIterator()
    local interator, t, prevKey = ipairs(CoopPlayers.CoopHeroes)
    prevKey = 1
    return interator, t, prevKey
end

---@param hero table
function CoopPlayers.GetPlayerByHero(hero)
    for playerId = 1, #CoopPlayers.CoopHeroes do
        if CoopPlayers.CoopHeroes[playerId] == hero then
            return playerId
        end
    end
end

---@return number
function CoopPlayers.GetCurrentPlayerId()
    return CoopPlayers.GetPlayerByHero(CurrentRun.Hero)
end

function CoopPlayers.GetHeroByUnit(unitId)
    return CoopPlayers.PlayerUnitIdToHero[unitId]
end

---@return table<number>
function CoopPlayers.GetUnits()
    local out = {}
    for unit in pairs(CoopPlayers.PlayerUnitIdToHero) do
        table.insert(out, unit)
    end
    return out
end

---@return boolean
function CoopPlayers.HasAlivePlayers()
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            return true
        end
    end

    return false
end

function CoopPlayers.OnAllPlayersDead()
    local mainHero = CoopPlayers.GetMainHero()
    if mainHero then
        -- 原版死亡结算仍需看到死亡状态；这里只恢复默认上下文，不提前清除 IsDead。 / Native death resolution still needs the dead state, so only restore the default context here.
        HeroContext.SetDefaultHero(mainHero)
    end

    CoopControl.ResetAllPlayers("UserDefined")
    CoopAppendTraceLog("[CoopRunReset] reason=all-players-dead-pending-hub")
end

---@param reason string
function CoopPlayers.ResetAfterRunEnd(reason)
    local mainHero = CoopPlayers.GetMainHero()
    if mainHero then
        -- P1 may have become non-default after dying first; restore the hub/default context. / P1 may stop being default after dying first, so restore the hub/default context.
        HeroContext.SetDefaultHero(mainHero)
    end

    for playerId, hero in CoopPlayers.PlayersIterator() do
        if hero then
            -- Run failure must clear the co-op-only death state for every player. / A failed run must clear every player's co-op-only death state.
            hero.IsDead = nil
            hero.Health = hero.MaxHealth or 50

            RemoveInputBlock { Name = "CoopDeadPlayer" .. tostring(playerId), PlayerIndex = playerId }
            if hero.ObjectId then
                ClearEffect({ Id = hero.ObjectId, All = true, BlockAll = true })
                SetAlpha({ Id = hero.ObjectId, Fraction = 1, Duration = 0 })
                HeroEx.ShowHero(hero)
            end
        end
    end

    -- 离开 run 后清理每名玩家的临时 MP trait，避免房间奖励或旧信物残留到准备区。
    -- Clear each player's temporary mana traits after a run so room rewards or old keepsakes cannot leak into the hub.
    CoopPlayers.RemoveRunScopedManaTraits()

    for _, hero in CoopPlayers.PlayersIterator() do
        if hero then
            -- 回到 Hub 后下一趟 run 应从满 MP 开始；P2 没有本体的单人重置路径，必须显式同步。
            -- A new run starts at full mana in the hub; P2 does not use the native single-player reset path, so sync it explicitly.
            HeroContext.RunWithHeroContextAwait(hero, function()
                hero.Mana = hero.MaxMana or hero.Mana
                ValidateMaxMana()
            end)
        end
    end
    -- Hub 的本体 HUD 会在地图/房间演出中重新创建；延迟到该流程之后再同步，避免显示残留到下一次 run。
    -- Native Hub HUD is rebuilt during map/room presentation; refresh after it completes so stale values do not persist until the next run.
    CoopPlayers.ScheduleHubUiRefresh("run-reset:" .. tostring(reason))
    -- Menus and death handling can temporarily swap controller ownership. / Menus and death handling can temporarily swap controller ownership.
    CoopControl.ResetAllPlayers("UserDefined")

    if mainHero and mainHero.ObjectId then
        SwitchActiveUnit { PlayerIndex = 1, Id = mainHero.ObjectId }
    end

    local playerStates = {}
    for playerId, hero in CoopPlayers.PlayersIterator() do
        table.insert(playerStates,
            "P" .. tostring(playerId) ..
            "{dead=" .. tostring(hero and hero.IsDead and true or false) ..
            ",id=" .. tostring(hero and hero.ObjectId) .. "}")
    end
    CoopAppendTraceLog("[CoopRunReset] reason=" .. tostring(reason) .. " players=" .. table.concat(playerStates, " "))
end

---@param reason string
function CoopPlayers.ScheduleHubUiRefresh(reason)
    thread(function()
        wait(0.35, RoomThreadName)
        -- UIHooks fans these native calls out to both HeroContexts.
        -- UIHooks 会将这些本体调用分发到 P1/P2 的 HeroContext。
        FrameState.RequestUpdateHealthUI = true
        ShowHealthUI()
        UpdateHealthUI()
        ShowManaMeter()
        UpdateManaMeterUIReal()
        CoopAppendTraceLog("[CoopHubUiRefresh] reason=" .. tostring(reason))
    end)
end

---@private
---@param hero table
---@param traitName string
---@return boolean
local function HeroHasNamedTrait(hero, traitName)
    for _, trait in ipairs(hero.Traits or {}) do
        if trait.Name == traitName then
            return true
        end
    end
    return false
end

---@private
---@param trait table
---@return table | nil
local function GetMaxManaPropertyChange(trait)
    for _, propertyChange in pairs(trait.PropertyChanges or {}) do
        if propertyChange.LuaProperty == "MaxMana" then
            return propertyChange
        end
    end
end

---输出每名玩家的 MP 与相关 trait，定位信物或残留状态造成的上限偏差。
---Logs each player's mana and related traits to identify keepsake or stale-state cap drift.
function CoopPlayers.TraceManaState(label)
    local playerStates = {}
    for playerId, hero in CoopPlayers.PlayersIterator() do
        local manaTraits = {}
        for _, trait in ipairs(hero.Traits or {}) do
            local manaChange = GetMaxManaPropertyChange(trait)
            if trait.Name == "ManaOverTimeRefundKeepsake"
                or (manaChange and manaChange.LuaProperty == "MaxMana") then
                table.insert(manaTraits,
                    tostring(trait.Name) ..
                    "{source=" .. tostring(trait.Source) ..
                    ",value=" .. tostring(manaChange and manaChange.ChangeValue) .. "}")
            end
        end

        table.insert(playerStates,
            "P" .. tostring(playerId) ..
            "{mana=" .. tostring(hero.Mana) ..
            ",max=" .. tostring(hero.MaxMana) ..
            ",dead=" .. tostring(hero.IsDead and true or false) ..
            ",traits=" .. table.concat(manaTraits, ",") .. "}")
    end

    local text = "[CoopKeepsakeTrace] " .. tostring(label) ..
        " p1Keepsake=" .. tostring(GameState and GameState.LastAwardTrait) ..
        " p2Keepsake=" .. tostring(GameState and GameState.LastAwardTraitCoopPlayer2) ..
        " p1Familiar=" .. tostring(GameState and GameState.EquippedFamiliar) ..
        " p2Familiar=" .. tostring(GameState and GameState.EquippedFamiliarCoopPlayer2) ..
        " players=" .. table.concat(playerStates, " ")
    DebugPrint({ Text = text })
    CoopAppendTraceLog(text)
end

---移除错误写入 P1 的 P2 MP 信物奖励，并按 P1 自己的 traits 重新计算上限。
---Removes a P2 MP-keepsake bonus accidentally written to P1 and recalculates P1's own maximum.
function CoopPlayers.RemoveStaleMainHeroManaKeepsakeBonus()
    local mainHero = CoopPlayers.GetMainHero()
    if mainHero == nil or HeroHasNamedTrait(mainHero, "ManaOverTimeRefundKeepsake") then
        return
    end

    HeroContext.RunWithHeroContextAwait(mainHero, function()
        local removed = false
        for index = #mainHero.Traits, 1, -1 do
            local trait = mainHero.Traits[index]
            local manaPropertyChange = GetMaxManaPropertyChange(trait)
            local manaChange = manaPropertyChange and manaPropertyChange.ChangeValue
            -- 本体预备房卸下该信物时会保留正值 trait，再生成无来源负值 trait 抵消它。
            -- Native pre-run removal leaves the positive trait and adds an untagged negative trait to cancel it.
            local isLegacyKeepsakeBonus = trait.Name == "RoomRewardMaxManaTrait" and trait.Source == "ManaOverTimeRefundKeepsake"
            local isNegativeKeepsakeCompensation = trait.Name == "RoomRewardMaxManaTrait" and manaChange ~= nil and manaChange < 0
            if isLegacyKeepsakeBonus or isNegativeKeepsakeCompensation then
                RemoveTraitData(mainHero, trait)
                removed = true
            end
        end

        if removed then
            -- 通过本体计算重新得到正确 MP 上限，避免保留已移除 trait 的数值。
            -- Recalculate through native logic so no value from the removed trait remains.
            ValidateMaxMana()
            thread(UpdateManaMeterUI)
        end
    end)
end

---移除仅应在单次 run 内存在的 MP trait，并为所有玩家重新计算上限。
---Removes mana traits that belong only to a completed run and recalculates every player's cap.
function CoopPlayers.RemoveRunScopedManaTraits()
    local removedByPlayer = {}

    for playerId, hero in CoopPlayers.PlayersIterator() do
        if hero then
            HeroContext.RunWithHeroContextAwait(hero, function()
                local removed = 0
                local hasManaKeepsake = HeroHasNamedTrait(hero, "ManaOverTimeRefundKeepsake")

                for index = #hero.Traits, 1, -1 do
                    local trait = hero.Traits[index]
                    local manaPropertyChange = GetMaxManaPropertyChange(trait)
                    local manaChange = manaPropertyChange and manaPropertyChange.ChangeValue
                    local isRoomManaReward = trait.Name == "RoomRewardMaxManaTrait"
                        and trait.Source == nil
                        and manaChange ~= nil
                        and manaChange > 0
                    local isStaleManaKeepsakeBonus = trait.Name == "RoomRewardMaxManaTrait"
                        and trait.Source == "ManaOverTimeRefundKeepsake"
                        and not hasManaKeepsake
                    local isStaleManaKeepsakeCompensation = trait.Name == "RoomRewardMaxManaTrait"
                        and manaChange ~= nil
                        and manaChange < 0
                        and not hasManaKeepsake

                    if isRoomManaReward or isStaleManaKeepsakeBonus or isStaleManaKeepsakeCompensation then
                        RemoveTraitData(hero, trait)
                        removed = removed + 1
                    end
                end

                if removed > 0 then
                    -- 使用本体逻辑重建 MP 上限；当前 HeroContext 确保不会把 P2 的结果写入 P1。
                    -- Rebuild the mana cap through native logic; the current hero context prevents P2 values from writing to P1.
                    ValidateMaxMana()
                end
                removedByPlayer[playerId] = removed
            end)
        end
    end

    -- UpdateManaMeterUI is already hooked to render both player HUDs in their own hero contexts.
    -- UpdateManaMeterUI 已被 hook 为在各自 HeroContext 中刷新两名玩家的 HUD。
    thread(UpdateManaMeterUI)

    local parts = {}
    for playerId = 1, CoopPlayers.GetPlayersCount() do
        table.insert(parts, "P" .. tostring(playerId) .. "=" .. tostring(removedByPlayer[playerId] or 0))
    end
    CoopAppendTraceLog("[CoopHubManaReset] removed=" .. table.concat(parts, ","))
end

---移除错误附着到 P1 的 P2 熟灵 traits，避免 P2 的属性加成修改 P1。
---Removes P2 familiar traits incorrectly attached to P1 so P2 stat bonuses cannot modify P1.
function CoopPlayers.RemoveMisplacedAdditionalFamiliarTraits()
    local mainHero = CoopPlayers.GetMainHero()
    if mainHero == nil then
        return
    end

    local mainFamiliar = GameState and GameState.EquippedFamiliar
    local mainTraitNames = (mainFamiliar and FamiliarData[mainFamiliar] and FamiliarData[mainFamiliar].TraitNames) or {}
    local mainTraitSet = {}
    for _, traitName in ipairs(mainTraitNames) do
        mainTraitSet[traitName] = true
    end

    local misplacedTraitSet = {}
    for playerId = 2, CoopPlayers.GetPlayersCount() do
        local familiarName = GameState["EquippedFamiliarCoopPlayer" .. playerId]
        local familiarData = familiarName and FamiliarData[familiarName]
        if familiarData then
            for _, traitName in ipairs(familiarData.TraitNames or {}) do
                if not mainTraitSet[traitName] then
                    misplacedTraitSet[traitName] = true
                end
            end
        end
    end

    if IsEmpty(misplacedTraitSet) then
        return
    end

    HeroContext.RunWithHeroContextAwait(mainHero, function()
        local removed = false
        for index = #mainHero.Traits, 1, -1 do
            local trait = mainHero.Traits[index]
            if misplacedTraitSet[trait.Name] then
                RemoveTraitData(mainHero, trait)
                removed = true
            end
        end

        if removed then
            -- 熟灵可能影响 HP 或 MP；移除后使用本体计算重新同步两项上限。
            -- Familiars can affect HP or MP, so resync both caps through native calculations.
            ValidateMaxHealth()
            ValidateMaxMana()
            FrameState.RequestUpdateHealthUI = true
            thread(UpdateManaMeterUI)
        end
    end)
end

---@return table[]
function CoopPlayers.GetAliveHeroes()
    local out = {}
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            table.insert(out, hero)
        end
    end

    return out
end

---@return table?
function CoopPlayers.GetFirstAliveHero()
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            return hero
        end
    end
end

function CoopPlayers.RestoreSavedHero(playerId)
    local hero = CurrentRun["Hero" .. playerId]
    DebugPrint { Text = "Restore player hero" .. tostring(playerId) .. " " .. tostring(hero) }
    if hero then
        CoopPlayers.CoopHeroes[playerId] = hero
        if not hero.IsDead then
            CoopPlayers.InitCoopUnit(playerId)
        end
    end
end

function CoopPlayers.InitCoopUnit(playerId)
    local unit = CoopCreatePlayerUnit(playerId)

    if not unit then
        return false
    end

    local hero = CoopPlayers.CoopHeroes[playerId]
    if not hero then
        hero = HeroEx.CreateFreshHero{
            playerId = playerId,
            keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId],
            familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId],
            weaponName = WeaponSets.HeroPrimaryWeapons[1];
            weaponVariant = 1;
        }
    end

    DebugPrint { Text = "Create hero for player " .. tostring(playerId) }

    CoopPlayers.PlayerUnitIdToHero[unit] = hero
    CoopPlayers.CoopHeroes[playerId] = hero
    CurrentRun["Hero" .. playerId] = hero

    PlayerVisibilityHelper.AddPlayerMarkers(playerId, unit)

    HeroEx.SetupAdditional(RunEx.GetCurrentRoom(), nil, hero, unit)

    SetUntargetable { Id = hero.ObjectId }
    -- Disables bow arrow bounces
    SetUnitProperty { DestinationId = unit, Property = "FriendlyToPlayer", Value = true }

    Teleport { Id = hero.ObjectId, DestinationId = CoopPlayers.GetMainHero().ObjectId }

    return hero
end

---@param playerId number
function CoopPlayers.RecreateFreshHeroWithCurrentMeta(playerId)
    local hero = CoopPlayers.CoopHeroes[playerId]
    local currentUnit = hero.ObjectId
    local weaponName, weaponIndex = HeroEx.GetHeroWeaponFull(hero)

    weaponName = weaponName or WeaponSets.HeroPrimaryWeapons[1]
    weaponIndex = weaponIndex or 1

    hero = HeroEx.CreateFreshHero{
        playerId = playerId,
        keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId];
        familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId];
        weaponName = weaponName;
        weaponVariant = weaponIndex;
    }

    if currentUnit then
        CoopPlayers.PlayerUnitIdToHero[currentUnit] = hero
    end
    CoopPlayers.CoopHeroes[playerId] = hero
    CurrentRun["Hero" .. playerId] = hero
end

function CoopPlayers.RecreateAllAdditionalPlayers()
    for playerIndex = 2, CoopPlayers.GetPlayersCount() do
        CoopPlayers.RecreateFreshHeroWithCurrentMeta(playerIndex)
    end
end

function CoopPlayers.UpdateMainHero()
    local hero = CoopPlayers.GetMainHero()
    CoopPlayers.PlayerUnitIdToHero[hero.ObjectId] = hero
    SetUntargetable { Id = hero.ObjectId }
end

function CoopPlayers.HealAllAdditionalPlayers()
    for playerIndex = 2, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.CoopHeroes[playerIndex]
        if hero then
            hero.IsDead = nil
            hero.Health = hero.MaxHealth
        end
    end
end

function CoopPlayers.CoopInit()
    CoopControl.InitControlSchemas()

    if RunEx.WasTheFirstRunStarted() then
        return
    end

    CoopPlayers.CoopHeroes[1] = CurrentRun.Hero

    if RunEx.IsRunEnded() then
        -- Create fresh hero for all players
        for playerId = 2, CoopPlayers.GetPlayersCount() do
            CoopPlayers.CoopHeroes[playerId] = HeroEx.CreateFreshHero {
                playerId = playerId,
                keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId],
                familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId],
                weaponName = WeaponSets.HeroPrimaryWeapons[1],
                weaponVariant = 1,
            }
        end
    else
        -- Load saved heroes
        for playerId = 2, CoopPlayers.GetPlayersCount() do
            CoopPlayers.CoopHeroes[playerId] = CurrentRun["Hero" .. playerId]
        end
    end
end

function CoopPlayers.IsHeroShouldBeHidden(hero)
    return hero.IsDead and not RunEx.IsRunEnded()
end

return CoopPlayers
