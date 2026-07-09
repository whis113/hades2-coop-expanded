--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class GameStateEx
local GameStateEx = {}

---@type CoopModConfig
local Config = ModRequire "../config.lua"

function GameStateEx.CopyTraitsToMetaUpgrades(hero)
    local metaUpgrades = GameState.MetaUpgradeState

    local traitToMeta = {}

    for name, data in pairs(MetaUpgradeCardData) do
        local upgarde = metaUpgrades[name]
        if upgarde then
            upgarde.Equipped = false
        end
        if data.TraitName then
            traitToMeta[data.TraitName] = upgarde
        end
    end

    for k, trait in ipairs(hero.Traits) do
        local upgrade = traitToMeta[trait.Name]
        if upgrade then
            upgrade.Equipped = true
        end
    end
end

local function CountLayoutCells(layout)
    local count = 0
    if not layout then
        return count
    end
    for _, rowData in pairs(layout) do
        if type(rowData) == "table" then
            for _, cardName in pairs(rowData) do
                if cardName then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function CountUnlockedMetaUpgrades()
    local count = 0
    if not GameState or not GameState.MetaUpgradeState then
        return count
    end
    for metaUpgradeName, state in pairs(GameState.MetaUpgradeState) do
        if MetaUpgradeCardData[metaUpgradeName] and state.Unlocked then
            count = count + 1
        end
    end
    return count
end

local function GetRecognizedArcanaLimit()
    if GetMaxMetaUpgradeCost then
        return GetMaxMetaUpgradeCost()
    end
    return nil
end

function GameStateEx.RepairArcanaFullUnlockState(reason)
    if not Config.Debug.ArcanaFullUnlockRepair then
        return
    end
    if not GameState or not MetaUpgradeDefaultCardLayout or not MetaUpgradeCardData then
        return
    end

    local beforeLayoutCount = CountLayoutCells(GameState.MetaUpgradeCardLayout)
    local beforeUnlockedCount = CountUnlockedMetaUpgrades()
    local limitLevel = GameState.MetaUpgradeLimitLevel or 0
    local recognizedLimit = GetRecognizedArcanaLimit()

    DebugPrint({
        Text = "[CoopArcanaRepair] reason=" .. tostring(reason) ..
            " limitLevel=" .. tostring(limitLevel) ..
            " recognizedLimit=" .. tostring(recognizedLimit) ..
            " layoutCells=" .. tostring(beforeLayoutCount) ..
            " unlocked=" .. tostring(beforeUnlockedCount) ..
            " screensViewed=" .. tostring(GameState.ScreensViewed and GameState.ScreensViewed.MetaUpgradeCardLayout),
    })

    GameState.MetaUpgradeCardLayout = DeepCopyTable(MetaUpgradeDefaultCardLayout)
    GameState.MetaUpgradeState = GameState.MetaUpgradeState or {}

    for metaUpgradeName, metaUpgradeData in pairs(MetaUpgradeCardData) do
        if not metaUpgradeData.DebugOnly then
            GameState.MetaUpgradeState[metaUpgradeName] = GameState.MetaUpgradeState[metaUpgradeName] or {}
            GameState.MetaUpgradeState[metaUpgradeName].Unlocked = true
            GameState.MetaUpgradeState[metaUpgradeName].Level = GameState.MetaUpgradeState[metaUpgradeName].Level or 1
        end
    end

    GameState.ScreensViewed = GameState.ScreensViewed or {}
    GameState.ScreensViewed.MetaUpgradeCardLayout = true

    if UpdateMetaUpgradeUnlockedCountCache then
        UpdateMetaUpgradeUnlockedCountCache()
    end

    DebugPrint({
        Text = "[CoopArcanaRepair] applied reason=" .. tostring(reason) ..
            " layoutCells=" .. tostring(CountLayoutCells(GameState.MetaUpgradeCardLayout)) ..
            " unlocked=" .. tostring(CountUnlockedMetaUpgrades()) ..
            " unlockedCache=" .. tostring(GameState.MetaUpgradeUnlockedCountCache),
    })
end

return GameStateEx
