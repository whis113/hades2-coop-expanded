--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "../logic/SecondPlayerUI.lua"
---@type CombinedTraitsUI
local CombinedTraitsUI = ModRequire "../logic/CombinedTraitsUI.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type RunEx
local RunEx = ModRequire "../logic/RunEx.lua"
---@type CoopArcana
local CoopArcana = ModRequire "../logic/CoopArcana.lua"
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"

---@class UIHooks : SimpleHook
local UIHooks = SimpleHook.New()
local ENABLE_COOP_SPELL_UI_TRACE = false

---@private
---Returns one player's separated HUD data even when the current hero context belongs to the other player.
---即使当前英雄上下文属于另一名玩家，也返回指定玩家独立的 HUD 数据。
local function GetPlayerHudData(playerId)
    local handler = HeroContextProxySpliterStore.Get("HUDScreen")
    if handler ~= nil then
        return handler:GetPlayerData(playerId)
    end
    return HUDScreen
end

---@private
---Finds the spell trait that belongs to one co-op hero.
---查找指定合作玩家持有的月神 Spell trait。
local function GetPlayerSpellTrait(playerId)
    local hero = CoopPlayers.GetHero(playerId)
    local slottedSpell = hero and hero.SlottedSpell
    if hero == nil or slottedSpell == nil then
        return nil
    end

    for _, trait in ipairs(hero.Traits or {}) do
        if trait.Slot == "Spell" or trait.Name == slottedSpell.TraitName then
            return trait
        end
    end
    return nil
end

---@private
---Returns the owning player for a trait instead of trusting the transient CurrentRun.Hero context.
---根据 trait 所属英雄确定玩家，不依赖换房期间可能短暂错位的 CurrentRun.Hero 上下文。
local function GetTraitOwnerPlayerId(trait)
    if trait == nil then
        return nil
    end

    for playerId = 1, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.GetHero(playerId)
        for _, heroTrait in ipairs(hero and hero.Traits or {}) do
            if heroTrait == trait then
                return playerId
            end
        end
    end
    return CoopPlayers.GetPlayerByHero(CurrentRun and CurrentRun.Hero)
end

---@private
---Collects every UI object ID referenced by one player's traits and HUD component registries.
---收集指定玩家的 trait 与 HUD 组件注册表引用的全部 UI 对象 ID。
local function GetOwnedTraitUiIds(playerId)
    local ids = {}
    local hero = CoopPlayers.GetHero(playerId)
    local fields = {
        "AnchorId",
        "TraitIconOverlay",
        "TraitActiveOverlay",
        "TraitInfoCardId",
        "TraitInfoChargeId",
        "TraitInfoUsesId",
    }

    for _, trait in ipairs(hero and hero.Traits or {}) do
        for _, fieldName in ipairs(fields) do
            local id = trait[fieldName]
            if id ~= nil then
                ids[id] = true
            end
        end
    end

    local hudData = GetPlayerHudData(playerId)
    for _, registryName in ipairs({ "SlottedTraitComponents", "ActiveTraitComponents" }) do
        for anchorId, component in pairs(hudData and hudData[registryName] or {}) do
            ids[anchorId] = true
            if component and component.Id then
                ids[component.Id] = true
            end
        end
    end
    return ids
end

---@private
---Writes a compact snapshot of the P2 spell HUD state without changing UI ownership or layout.
---记录 P2 月神 HUD 的紧凑快照，不修改 UI 归属或布局。
local function TracePlayerSpellUi(stage, playerId, trait)
    if not ENABLE_COOP_SPELL_UI_TRACE or playerId ~= 2 then
        return
    end

    trait = trait or GetPlayerSpellTrait(playerId)
    local activeComponent = nil
    local componentContainer = nil
    local hudData = GetPlayerHudData(playerId)
    if trait and trait.AnchorId and hudData then
        activeComponent = hudData.ActiveTraitComponents and hudData.ActiveTraitComponents[trait.AnchorId]
        componentContainer = activeComponent and "active" or nil
        if activeComponent == nil and hudData.SlottedTraitComponents then
            activeComponent = hudData.SlottedTraitComponents[trait.AnchorId]
            componentContainer = activeComponent and "slotted" or nil
        end
    end

    CoopAppendTraceLog(string.format(
        "[CoopSpellUiTrace] stage=%s player=P%d current=P%s spell=%s trait=%s anchor=%s component=%s offset=%s,%s card=%s charge=%s uses=%s",
        tostring(stage),
        playerId,
        tostring(CoopPlayers.GetCurrentPlayerId() or "nil"),
        tostring(CoopPlayers.GetHero(playerId) and CoopPlayers.GetHero(playerId).SlottedSpell and CoopPlayers.GetHero(playerId).SlottedSpell.Name),
        tostring(trait and trait.Name),
        tostring(trait and trait.AnchorId),
        tostring(componentContainer),
        tostring(activeComponent and activeComponent.OffsetX),
        tostring(activeComponent and activeComponent.OffsetY),
        tostring(trait and trait.TraitInfoCardId),
        tostring(trait and trait.TraitInfoChargeId),
        tostring(trait and trait.TraitInfoUsesId)
    ))
end

---@public
---Exposes P2 spell UI tracing to room-transition code.
---向换房逻辑暴露 P2 月神 UI 追踪入口。
function UIHooks.TracePlayerSpellUi(stage, playerId)
    TracePlayerSpellUi(stage, playerId)
end

---@public
---Rebuilds only a player's spell HUD when a room transition left a stale anchor behind.
---仅在换房留下失效 anchor 时重建指定玩家的 Spell HUD，避免触碰通用 boon 托盘。
function UIHooks.RebuildPlayerSpellHud(playerId, stage)
    if playerId ~= 2 then
        return
    end

    local hero = CoopPlayers.GetHero(playerId)
    local trait = GetPlayerSpellTrait(playerId)
    if hero == nil or trait == nil or HUDScreen == nil then
        return
    end

    HeroContext.RunWithHeroContext(hero, function()
        local hudData = GetPlayerHudData(playerId)
        local component = nil
        if trait.AnchorId and hudData and hudData.SlottedTraitComponents then
            component = hudData.SlottedTraitComponents[trait.AnchorId]
        end
        if component == nil and trait.AnchorId and hudData and hudData.ActiveTraitComponents then
            component = hudData.ActiveTraitComponents[trait.AnchorId]
        end

        if trait.AnchorId == nil or component ~= nil then
            TracePlayerSpellUi("spell-rebuild-skip:" .. tostring(stage), playerId, trait)
            return
        end

        -- Native object IDs can be reused by P1 during a room rebuild. Only destroy IDs that P1 does not own.
        -- 换房重建时本体可能把旧对象 ID 复用给 P1；这里只销毁不属于 P1 的对象。
        local p1OwnedIds = GetOwnedTraitUiIds(1)
        local staleIds = CollapseTable({
            trait.AnchorId,
            trait.TraitIconOverlay,
            trait.TraitActiveOverlay,
            trait.TraitInfoCardId,
            trait.TraitInfoChargeId,
            trait.TraitInfoUsesId,
        })
        local destroyIds = {}
        for _, id in ipairs(staleIds) do
            if not p1OwnedIds[id] then
                StopAnimation({ DestinationId = id, Name = "DarkSorceryReady" })
                table.insert(destroyIds, id)
            end
        end
        if not IsEmpty(destroyIds) then
            Destroy({ Ids = destroyIds })
        end
        trait.AnchorId = nil
        trait.TraitIconOverlay = nil
        trait.TraitActiveOverlay = nil
        trait.TraitInfoCardId = nil
        trait.TraitInfoChargeId = nil
        trait.TraitInfoUsesId = nil

        TraitUIAdd(trait, { Show = true })
        TracePlayerSpellUi("spell-rebuilt:" .. tostring(stage), playerId, trait)
    end)
end

---Native save loading can restore Last Stand data before HUDScreen is created.
---本体读档时可能先恢复死里逃生数据、后创建 HUDScreen；此时延后创建图标以避免读档崩溃。
function UIHooks.wrap.CreateLifePip(baseFun, index)
    if HUDScreen == nil then
        CoopAppendTraceLog("[CoopUiLoadTrace] defer-life-pip index=" .. tostring(index))
        return nil
    end
    return baseFun(index)
end

---The native function reads HUDScreen again after creating pips, so skip the entire rebuild until HUD creation finishes.
---本体函数创建图标后还会继续读取 HUDScreen，因此 HUD 完成创建前必须跳过整段重建。
function UIHooks.wrap.RecreateLifePips(baseFun)
    if HUDScreen == nil then
        UIHooks.DeferredLifePipRebuild = true
        CoopAppendTraceLog("[CoopUiLoadTrace] defer-life-pip-rebuild")
        return nil
    end
    return baseFun()
end

---@private
---@param hero table?
function UIHooks.ShouldBeUiVisibleFor(hero)
    return hero and (RunEx.IsRunEnded() or not hero.IsDead)
end

---@private
---@param funcName string
function UIHooks.CreateSimpleHook(funcName)
    local orig = _G[funcName]
    _G[funcName] = function(...)
        local mainHero = CoopPlayers.GetMainHero()
        local secondHero = CoopPlayers.GetHero(2)
        HeroContext.RunWithHeroContext(mainHero, orig, ...)
        if secondHero then
            HeroContext.RunWithHeroContext(secondHero, SecondPlayerUi[funcName], ...)
        end
    end
end

---@private
---@param funcName string
function UIHooks.CallForEveryHero(funcName)
    HookUtils.wrap(funcName, function(base, ...)
        local mainHero = CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(mainHero, base, ...)
        local secondHero = CoopPlayers.GetHero(2)
        if secondHero then
            HeroContext.RunWithHeroContext(secondHero, base, ...)
        end
    end)
end

---@private
---@param funcName string
function UIHooks.CallForEveryVisibleHero(funcName)
    HookUtils.wrap(funcName, function(base, ...)
        local mainHero = CoopPlayers.GetMainHero()
        if UIHooks.ShouldBeUiVisibleFor(mainHero) then
            HeroContext.RunWithHeroContext(mainHero, base, ...)
        end
        local secondHero = CoopPlayers.GetHero(2)
        if UIHooks.ShouldBeUiVisibleFor(secondHero) then
            HeroContext.RunWithHeroContext(secondHero, base, ...)
        end
    end)
end

---@private
---@param funcName string
function UIHooks.SimpleHookWithVisibilityCheck(funcName)
    local orig = _G[funcName]
    _G[funcName] = function(...)
        local mainHero = CoopPlayers.GetMainHero()
        if UIHooks.ShouldBeUiVisibleFor(mainHero) then
            HeroContext.RunWithHeroContext(mainHero, orig, ...)
        end
        local secondHero = CoopPlayers.GetHero(2)
        if UIHooks.ShouldBeUiVisibleFor(secondHero) then
            HeroContext.RunWithHeroContext(secondHero, SecondPlayerUi[funcName], ...)
        end
    end
end

---@private
function UIHooks.SimpleCurrentTraitWrapper(funcName)
    HookUtils.wrap(funcName, function(baseFun, ...)
        HeroContext.RunWithHeroContext(CombinedTraitsUI.GetCurrentTraitHero(), baseFun, ...)
    end)
end

function UIHooks:InitGameHooks()
    -- Health
    UIHooks.CallForEveryVisibleHero("ShowHealthUI")
    UIHooks.CallForEveryHero("UpdateHealthUI")
    UIHooks.CallForEveryHero("HideHealthUI")

    -- Mana
    UIHooks.CallForEveryVisibleHero("ShowManaMeter")
    UIHooks.CallForEveryHero("UpdateManaMeterUIReal")
    UIHooks.CallForEveryHero("HideManaMeter")

    -- Ammo
    UIHooks.CallForEveryVisibleHero("ShowAmmoUI")
    --UIHooks.CallForEveryHero("UpdateAmmoUI")
    UIHooks.CallForEveryHero("HideAmmoUI")

    -- AxeUI
    UIHooks.CallForEveryVisibleHero("ShowAxeUI")
    UIHooks.CallForEveryHero("HideAxeUI")

    -- LobUI WTF is that
    UIHooks.CallForEveryVisibleHero("ShowLobUI")
    UIHooks.CallForEveryHero("HideLobUI")

    -- DaggerUI
    UIHooks.CallForEveryVisibleHero("ShowDaggerUI")
    UIHooks.CallForEveryHero("HideDaggerUI")

    -- SuitUI
    UIHooks.CallForEveryVisibleHero("ShowSuitUI")
    UIHooks.CallForEveryHero("HideSuitUI")

    -- Taits tray
    UIHooks.CallForEveryVisibleHero("ShowTraitUI")
    UIHooks.CallForEveryHero("HideTraitUI")

    UIHooks.SimpleCurrentTraitWrapper("TraitTrayScreenClose")
    UIHooks.SimpleCurrentTraitWrapper("PinTraitDetails")
end

function UIHooks.pre.SetupFormatContainers()
    if ScreenAnchors.CoopWasAppliedProxy then
        return
    end

    HeroContextProxySpliterStore.Recreate("ScreenAnchors", ScreenAnchors, {
        "AmmoIndicatorUI",
        "AxeUI",
        "AxeUIChargeAmount",
        "LobUI",
        "LobUIChargeAmount",
        "DaggerUI",
        "DaggerUIChargeAmount",
        "SuitUI",
        "SuitUIChargeAmount",
        "LifePipIds",
    })

    ScreenAnchors.CoopWasAppliedProxy = true
end

function UIHooks.ApplyScreenConfigProxy()
    if HUDScreen == nil then
        return nil
    end
    local handler = HeroContextProxySpliterStore.Recreate("HUDScreen", HUDScreen, {
        "AmmoX",
        "LastStandX",
        "LastStandSpacingX",
        -- Each hero needs its own trait component registry; shared tables leave P2 spell anchors stale after a room rebuild.
        -- 每位英雄需要独立的 trait 组件注册表；共享表会在换房重建后让 P2 Spell 保留失效 anchor。
        "SlottedTraitComponents",
        "ActiveTraitComponents",
    })

    local secondHeroData = handler:GetPlayerData(2)
    secondHeroData.AmmoX = 1190
    secondHeroData.LastStandX = 1300
    secondHeroData.LastStandSpacingX = -48
    -- A fresh HUD must not inherit P1's old component IDs into P2's registries.
    -- 新 HUD 不能把 P1 的旧组件 ID 深拷贝给 P2；P2 组件会在各自 HeroContext 中重新登记。
    secondHeroData.SlottedTraitComponents = {}
    secondHeroData.ActiveTraitComponents = {}
    return handler
end

function UIHooks.pre.CreateScreenFromData(screen, componentData)
    if screen ~= HUDScreen then
        return
    end
    UIHooks.ApplyScreenConfigProxy()

    SecondPlayerUi.RegisterComponents(componentData)

    local allComponents = {}
    screen.Components = setmetatable({}, {
        __index = function(self, key)
            local currentHero = HeroContext.GetCurrentHeroContext()
            local mainHero = CoopPlayers.GetMainHero()
            if currentHero == mainHero then
                return allComponents[key]
            else
                local alternativeKey = key .. "Player2"
                return allComponents[alternativeKey] or allComponents[key]
            end
        end,
        __newindex = function(self, key, value)
            allComponents[key] = value
        end
    })
end

function UIHooks.post.CreateScreenFromData(screen, componentData)
    if screen ~= HUDScreen or not UIHooks.DeferredLifePipRebuild then
        return
    end

    UIHooks.DeferredLifePipRebuild = nil
    -- Let native screen construction finish before rebuilding player-specific Last Stand pips.
    -- 等待本体屏幕构建完成后，再重建每位玩家独立的死里逃生图标。
    thread(function()
        wait(0)
        for playerId, hero in CoopPlayers.PlayersIterator() do
            if hero ~= nil and HUDScreen ~= nil then
                HeroContext.RunWithHeroContext(hero, RecreateLifePips)
            end
        end
        CoopAppendTraceLog("[CoopUiLoadTrace] restored-life-pip-rebuild")
    end)
end

-- Traits

function UIHooks.wrap.TraitUIAdd(baseFun, trait, args)
    if not CombinedTraitsUI.IsTraitShouldBeVisibleForCurrentHero(trait) then
        return
    end

    local currentHero = CurrentRun.Hero
    if CoopPlayers.GetMainHero() == currentHero then
        return baseFun(trait, args)
    end

    if not HUDScreen then
        return
    end

    if trait.AnchorId or (args and args.LocationX) then
        return baseFun(trait, args)
    end

    local slotIndex = GetIndex(HUDScreen.SlottedTraitOrder, trait.Slot)

    if slotIndex > 0 then
        -- P2 slot traits share the native tray layout unless we mirror the X direction here.
        -- P2 的槽位 trait 默认会复用本体左侧托盘；此处镜像到右侧，月神 Spell 也固定在 P2 状态条上方。
        local originalStartX = ScreenData.TraitTrayScreen.TraitStartX
        local originalSpacingX = ScreenData.TraitTrayScreen.TraitSpacingX
        ScreenData.TraitTrayScreen.TraitStartX = 1920 - 50
        ScreenData.TraitTrayScreen.TraitSpacingX = -100
        baseFun(trait, args)
        ScreenData.TraitTrayScreen.TraitStartX = originalStartX
        ScreenData.TraitTrayScreen.TraitSpacingX = originalSpacingX
        return
    end

    ScreenData.TraitTrayScreen.TraitStartX = 1920 - 50
    ScreenData.TraitTrayScreen.TraitSpacingX = -100
    baseFun(trait, args)
    ScreenData.TraitTrayScreen.TraitStartX = 50
    ScreenData.TraitTrayScreen.TraitSpacingX = 100

end

function UIHooks.wrap.TraitTrayShowMetaUpgrades(baseFun, screen, activeCategory, args)
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    if playerId == 1 then
        return baseFun(screen, activeCategory, args)
    end

    -- The native tray filters Arcana by the shared GameState table instead of the viewed hero.
    -- 本体托盘按共享 GameState 筛选阿卡那，而不是按正在查看的英雄筛选。
    return CoopArcana.RunWithPlayerLoadout(playerId, function()
        local equipped = CoopArcana.GetEquippedCards(playerId)
        CoopAppendTraceLog("[CoopArcanaTray] player=P" .. tostring(playerId) ..
            " equipped=" .. tostring((function()
                local count = 0
                for _ in pairs(equipped) do
                    count = count + 1
                end
                return count
            end)()))
        return baseFun(screen, activeCategory, args)
    end)
end

function UIHooks.post.TraitUIAdd(trait, args)
    if trait and trait.Slot == "Spell" then
        local playerId = GetTraitOwnerPlayerId(trait)
        TracePlayerSpellUi("trait-ui-add", playerId, trait)
    end
end

function UIHooks.post.CreateSpellHUD(trait, args)
    if trait and trait.Slot == "Spell" then
        local playerId = GetTraitOwnerPlayerId(trait)
        TracePlayerSpellUi("create-spell-hud", playerId, trait)
    end
end

function UIHooks.post.ShowUseButton(objectId, useTarget)
    if HeroContext.GetDefaultHero() ~= HeroContext.GetCurrentHeroContext() then
        Move{ Id = ScreenAnchors.UsePrompts[objectId], DestinationId = ScreenAnchors.UsePrompts[objectId], OffsetY = -50 }
    end
end

function UIHooks.pre.OpenTraitTrayScreen()
    CombinedTraitsUI.ChangeHeroInTraitsMenu()
end

return UIHooks
