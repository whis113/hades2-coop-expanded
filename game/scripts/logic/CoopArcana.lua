--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class CoopArcana
local CoopArcana = {}
local ENABLE_COOP_ARCANA_AUDIT = false

---@type CoopModConfig
local Config = ModRequire "../config.lua"

local CURRENT_VERSION = 1

-- Marks the temporary P2 Arcana editor while native UI code is running.
-- 标记原版 UI 正在运行的临时 P2 阿卡那编辑器。
CoopArcana.ActiveEditorPlayerId = nil

local function GetEquippedCardsFromState(metaUpgradeState)
    local equipped = {}
    for metaUpgradeName, state in pairs(metaUpgradeState or {}) do
        if MetaUpgradeCardData[metaUpgradeName] and state.Equipped then
            equipped[metaUpgradeName] = true
        end
    end
    return equipped
end

local function CopyEquippedCards(equipped)
    local copy = {}
    for metaUpgradeName, value in pairs(equipped or {}) do
        if value and MetaUpgradeCardData[metaUpgradeName] then
            copy[metaUpgradeName] = true
        end
    end
    return copy
end

local function GetSharedLayoutSet(layoutIndex)
    local savedLayouts = GameState.SavedMetaUpgradeLayouts or {}
    local savedLayout = savedLayouts[layoutIndex]
    if not IsEmpty(savedLayout) then
        return CopyEquippedCards(savedLayout)
    end
    return GetEquippedCardsFromState(GameState.MetaUpgradeState)
end

local function CountCards(cards)
    local count = 0
    for _, value in pairs(cards or {}) do
        if value then
            count = count + 1
        end
    end
    return count
end

local function GetLayoutCount()
    local count = 1
    for layoutIndex in pairs(GameState.SavedMetaUpgradeLayouts or {}) do
        if type(layoutIndex) == "number" then
            count = math.max(count, layoutIndex)
        end
    end
    return count
end

local function CopySavedLayouts(savedLayouts, layoutCount)
    local copy = {}
    for layoutIndex = 1, layoutCount do
        copy[layoutIndex] = CopyEquippedCards(savedLayouts and savedLayouts[layoutIndex])
    end
    return copy
end

local function BuildSavedLayoutsView(playerId, layoutCount)
    local layouts = {}
    local playerData = CoopArcana.GetPlayerData(playerId)
    for layoutIndex = 1, layoutCount do
        local layout = playerData.Layouts[layoutIndex]
        layouts[layoutIndex] = CopyEquippedCards(layout and layout.Equipped)
    end
    return layouts
end

local function TraceAudit(stage)
    if not ENABLE_COOP_ARCANA_AUDIT or not Config.Debug.ArcanaLoadoutAudit then
        return
    end

    local playerData = CoopArcana.GetPlayerData(2)
    local p2Layout = playerData.Layouts[playerData.CurrentLayout]
    local text = "[CoopArcanaAudit] stage=" .. tostring(stage) ..
        " sharedEquipped=" .. tostring(CountCards(GetEquippedCardsFromState(GameState.MetaUpgradeState))) ..
        " p1Layout=" .. tostring(GameState.CurrentMetaUpgradeLayout or 1) ..
        " p2Layout=" .. tostring(playerData.CurrentLayout) ..
        " p2Equipped=" .. tostring(CountCards(p2Layout and p2Layout.Equipped)) ..
        " metaState=" .. tostring(GameState.MetaUpgradeState) ..
        " p2Data=" .. tostring(playerData)
    DebugPrint({ Text = text })
    if CoopAppendTraceLog then
        CoopAppendTraceLog(text)
    end
end

---Records the shared P1 state and isolated P2 loadout without changing either one.
---记录共享 P1 状态和隔离 P2 预设，不修改任何一方数据。
function CoopArcana.TraceAudit(stage)
    TraceAudit(stage)
end

local function GetTemporaryCards(playerId)
    if not CurrentRun or not CurrentRun.CoopTemporaryMetaUpgrades then
        return {}
    end
    return CopyEquippedCards(CurrentRun.CoopTemporaryMetaUpgrades[playerId])
end

local function GetRuntimeEquippedCards(playerId)
    local equippedCards = CoopArcana.GetEquippedCards(playerId)
    for metaUpgradeName in pairs(GetTemporaryCards(playerId)) do
        equippedCards[metaUpgradeName] = true
    end
    return equippedCards
end

local function BuildMetaUpgradeStateView(playerId, includeTemporaryCards)
    local stateView = DeepCopyTable(GameState.MetaUpgradeState)
    local equippedCards = includeTemporaryCards and GetRuntimeEquippedCards(playerId) or CoopArcana.GetEquippedCards(playerId)
    for metaUpgradeName, state in pairs(stateView) do
        if MetaUpgradeCardData[metaUpgradeName] then
            state.Equipped = equippedCards[metaUpgradeName] or nil
        end
    end
    return stateView, equippedCards
end

---Returns P2-owned loadout data while leaving vanilla Arcana progression shared.
---返回 P2 专属预设数据，同时保持原版阿卡那永久进度共享。
function CoopArcana.GetPlayerData(playerId)
    GameState.CoopArcanaLoadouts = GameState.CoopArcanaLoadouts or {
        Version = CURRENT_VERSION,
        Players = {},
    }
    local root = GameState.CoopArcanaLoadouts
    root.Version = CURRENT_VERSION
    root.Players = root.Players or {}

    local playerData = root.Players[playerId]
    if playerData == nil then
        playerData = {
            CurrentLayout = GameState.CurrentMetaUpgradeLayout or 1,
            Layouts = {},
        }
        root.Players[playerId] = playerData
    end

    playerData.CurrentLayout = playerData.CurrentLayout or 1
    playerData.Layouts = playerData.Layouts or {}
    return playerData
end

---Creates missing P2 preset slots from P1's current shared Arcana presets once.
---仅在缺失时从 P1 当前共享阿卡那预设创建 P2 槽位，绝不覆盖既有 P2 配置。
function CoopArcana.Initialize()
    if not GameState or not GameState.MetaUpgradeState then
        return
    end

    local playerData = CoopArcana.GetPlayerData(2)
    for layoutIndex = 1, GetLayoutCount() do
        if playerData.Layouts[layoutIndex] == nil then
            playerData.Layouts[layoutIndex] = {
                Equipped = GetSharedLayoutSet(layoutIndex),
            }
        else
            playerData.Layouts[layoutIndex].Equipped = CopyEquippedCards(playerData.Layouts[layoutIndex].Equipped)
        end
    end

    if playerData.Layouts[playerData.CurrentLayout] == nil then
        playerData.Layouts[playerData.CurrentLayout] = {
            Equipped = GetEquippedCardsFromState(GameState.MetaUpgradeState),
        }
    end
    TraceAudit("initialize")
end

---Returns whether native code is currently editing P2's temporary Arcana view.
---返回本体代码是否正在编辑 P2 的临时阿卡那视图。
function CoopArcana.IsEditorActive()
    return CoopArcana.ActiveEditorPlayerId ~= nil
end

---@private
local function PersistEditorLayouts(playerId, editorState, editorLayouts, currentLayout)
    local playerData = CoopArcana.GetPlayerData(playerId)
    local layoutCount = math.max(GetLayoutCount(), currentLayout or 1)

    for layoutIndex = 1, layoutCount do
        local equipped = editorLayouts and editorLayouts[layoutIndex]
        playerData.Layouts[layoutIndex] = {
            Equipped = CopyEquippedCards(equipped),
        }
    end

    currentLayout = currentLayout or playerData.CurrentLayout or 1
    playerData.Layouts[currentLayout] = {
        Equipped = GetEquippedCardsFromState(editorState),
    }
    playerData.CurrentLayout = currentLayout
end

---Runs the native Arcana card screen against an isolated P2 editor view.
---在隔离的 P2 编辑视图中运行原版阿卡那卡牌页面。
function CoopArcana.RunWithEditorLoadout(playerId, callback)
    if playerId == nil or playerId == 1 then
        return callback()
    end

    CoopArcana.Initialize()
    local playerData = CoopArcana.GetPlayerData(playerId)
    local layoutCount = GetLayoutCount()
    local shared = {
        MetaUpgradeState = GameState.MetaUpgradeState,
        SavedMetaUpgradeLayouts = GameState.SavedMetaUpgradeLayouts,
        CurrentMetaUpgradeLayout = GameState.CurrentMetaUpgradeLayout,
        PrevMetaUpgradeLayout = GameState.PrevMetaUpgradeLayout,
        MetaUpgradeCardLayout = GameState.MetaUpgradeCardLayout,
        MetaUpgradeLayoutsArt = GameState.MetaUpgradeLayoutsArt,
    }

    local editorState = BuildMetaUpgradeStateView(playerId)
    local editorLayouts = BuildSavedLayoutsView(playerId, layoutCount)
    GameState.MetaUpgradeState = editorState
    GameState.SavedMetaUpgradeLayouts = editorLayouts
    GameState.CurrentMetaUpgradeLayout = playerData.CurrentLayout
    GameState.PrevMetaUpgradeLayout = playerData.CurrentLayout
    GameState.MetaUpgradeCardLayout = DeepCopyTable(shared.MetaUpgradeCardLayout)
    GameState.MetaUpgradeLayoutsArt = DeepCopyTable(shared.MetaUpgradeLayoutsArt)
    CoopArcana.ActiveEditorPlayerId = playerId

    local openedText = "[CoopArcanaEditor] stage=open player=P" .. tostring(playerId) ..
        " layout=" .. tostring(playerData.CurrentLayout) ..
        " equipped=" .. tostring(CountCards(playerData.Layouts[playerData.CurrentLayout].Equipped))
    CoopAppendTraceLog(openedText)

    -- Restore every shared reference even if a native presentation fails.
    -- 即使本体演出报错，也必须恢复全部共享引用。
    local success, results = xpcall(function()
        return { callback() }
    end, debug.traceback)

    local finalLayout = GameState.CurrentMetaUpgradeLayout
    PersistEditorLayouts(playerId, GameState.MetaUpgradeState, GameState.SavedMetaUpgradeLayouts, finalLayout)

    GameState.MetaUpgradeState = shared.MetaUpgradeState
    GameState.SavedMetaUpgradeLayouts = shared.SavedMetaUpgradeLayouts
    GameState.CurrentMetaUpgradeLayout = shared.CurrentMetaUpgradeLayout
    GameState.PrevMetaUpgradeLayout = shared.PrevMetaUpgradeLayout
    GameState.MetaUpgradeCardLayout = shared.MetaUpgradeCardLayout
    GameState.MetaUpgradeLayoutsArt = shared.MetaUpgradeLayoutsArt
    CoopArcana.ActiveEditorPlayerId = nil

    -- Save only after P1's shared state has been restored.
    -- 仅在 P1 共享状态恢复后才请求存档。
    if RequestPreRunLoadoutChangeSave then
        RequestPreRunLoadoutChangeSave()
    end

    local closedData = CoopArcana.GetPlayerData(playerId)
    CoopAppendTraceLog("[CoopArcanaEditor] stage=close player=P" .. tostring(playerId) ..
        " layout=" .. tostring(closedData.CurrentLayout) ..
        " equipped=" .. tostring(CountCards(closedData.Layouts[closedData.CurrentLayout].Equipped)))
    TraceAudit("editor-closed:P" .. tostring(playerId))

    if not success then
        error(results)
    end
    return table.unpack(results)
end

---Returns an isolated copy so callers cannot mutate persistent P2 data by accident.
---返回隔离副本，避免调用方意外修改持久化的 P2 数据。
function CoopArcana.GetEquippedCards(playerId, layoutIndex)
    if playerId == 1 then
        return GetEquippedCardsFromState(GameState.MetaUpgradeState)
    end

    local playerData = CoopArcana.GetPlayerData(playerId)
    local layout = playerData.Layouts[layoutIndex or playerData.CurrentLayout]
    return CopyEquippedCards(layout and layout.Equipped)
end

---Runs synchronous native Arcana setup with P2's isolated equipment view.
---使用 P2 隔离的装备视图执行同步的本体阿卡那初始化。
function CoopArcana.RunWithPlayerLoadout(playerId, callback)
    if playerId == nil or playerId == 1 then
        return callback()
    end

    local sharedState = GameState.MetaUpgradeState
    local stateView, equippedCards = BuildMetaUpgradeStateView(playerId, true)
    GameState.MetaUpgradeState = stateView

    -- Always restore shared progress, including when native setup reports an error.
    -- 即使本体初始化报错也必须恢复共享进度，避免临时 P2 视图残留。
    local success, results = xpcall(function()
        return { callback() }
    end, debug.traceback)
    GameState.MetaUpgradeState = sharedState
    if not success then
        error(results)
    end

    local playerData = CoopArcana.GetPlayerData(playerId)
    local text = "[CoopArcanaRuntime] stage=apply player=P" .. tostring(playerId) ..
        " layout=" .. tostring(playerData.CurrentLayout) ..
        " equipped=" .. tostring(CountCards(equippedCards)) ..
        " sharedEquipped=" .. tostring(CountCards(GetEquippedCardsFromState(sharedState)))
    DebugPrint({ Text = text })
    if CoopAppendTraceLog then
        CoopAppendTraceLog(text)
    end
    return table.unpack(results)
end

---Runs a run-time Arcana change against one player's isolated temporary-card state.
---在单个玩家隔离的本局临时卡牌状态中执行运行时阿卡那变更。
function CoopArcana.RunWithTemporaryCards(playerId, callback)
    if playerId == nil or playerId == 1 then
        return callback()
    end

    CurrentRun.CoopTemporaryMetaUpgrades = CurrentRun.CoopTemporaryMetaUpgrades or {}
    local sharedState = GameState.MetaUpgradeState
    local sharedTemporary = CurrentRun.TemporaryMetaUpgrades
    local stateView = BuildMetaUpgradeStateView(playerId, true)
    local temporaryView = CopyEquippedCards(CurrentRun.CoopTemporaryMetaUpgrades[playerId])
    GameState.MetaUpgradeState = stateView
    CurrentRun.TemporaryMetaUpgrades = temporaryView

    -- Keep P2 temporary cards isolated from P1 even when native logic yields for a presentation.
    -- 即使本体逻辑为演出让出协程，也要保持 P2 临时卡牌与 P1 隔离。
    local success, results = xpcall(function()
        return { callback() }
    end, debug.traceback)

    CurrentRun.CoopTemporaryMetaUpgrades[playerId] = CopyEquippedCards(CurrentRun.TemporaryMetaUpgrades)
    GameState.MetaUpgradeState = sharedState
    CurrentRun.TemporaryMetaUpgrades = sharedTemporary

    local text = "[CoopArcanaTemporary] player=P" .. tostring(playerId) ..
        " cards=" .. tostring(CountCards(CurrentRun.CoopTemporaryMetaUpgrades[playerId]))
    CoopAppendTraceLog(text)
    if not success then
        error(results)
    end
    return table.unpack(results)
end

return CoopArcana
