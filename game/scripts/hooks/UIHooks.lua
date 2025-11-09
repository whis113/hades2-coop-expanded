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
end

function UIHooks.pre.CreateScreenFromData(screen, componentData)
    if screen ~= HUDScreen then
        return
    end
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

function UIHooks.wrap.PulseText(_PulseText, args)
    if args.ScreenAnchorReference and HeroContext.GetCurrentHeroContext() == CoopPlayers.GetHero(2) then
        local idOnSecond = SecondPlayerUi.ScreenAnchors[args.ScreenAnchorReference]
        if idOnSecond then
            args.Id = idOnSecond
        end
    end

    _PulseText(args)
end

function UIHooks.post.ShowUseButton(objectId, useTarget)
    if HeroContext.GetDefaultHero() ~= HeroContext.GetCurrentHeroContext() then
        Move({ Id = ScreenAnchors.UsePrompts[objectId], DestinationId = ScreenAnchors.UsePrompts[objectId], OffsetY = -50 })
    end
end

return UIHooks