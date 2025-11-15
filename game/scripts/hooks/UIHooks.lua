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
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"

---@class UIHooks : SimpleHook
local UIHooks = SimpleHook.New()

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
end

function UIHooks.pre.SetupFormatContainers()
    if ScreenAnchors.CoopWasAppliedProxy then
        return
    end

    HeroContextProxySpliterStore.GetOrCreate("ScreenAnchors", ScreenAnchors, {
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
    local handler = HeroContextProxySpliterStore.GetOrCreate("HUDScreen", HUDScreen, {
        "AmmoX",
        "LastStandX",
        "LastStandSpacingX",
    })

    local secondHeroData = handler:GetPlayerData(2)
    secondHeroData.AmmoX = 1190
    secondHeroData.LastStandX = 1300
    secondHeroData.LastStandSpacingX = -48
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

-- Traits

function UIHooks.wrap.TraitUIAdd(baseFun, trait, args)
    if CoopPlayers.GetMainHero() == CurrentRun.Hero then
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
        return baseFun(trait, args)
    end

    ScreenData.TraitTrayScreen.TraitStartX = 1920 - 50
    ScreenData.TraitTrayScreen.TraitSpacingX = -100
    baseFun(trait, args)
    ScreenData.TraitTrayScreen.TraitStartX = 50
    ScreenData.TraitTrayScreen.TraitSpacingX = 100

end

function UIHooks.post.ShowUseButton(objectId, useTarget)
    if HeroContext.GetDefaultHero() ~= HeroContext.GetCurrentHeroContext() then
        Move({ Id = ScreenAnchors.UsePrompts[objectId], DestinationId = ScreenAnchors.UsePrompts[objectId], OffsetY = -50 })
    end
end

return UIHooks