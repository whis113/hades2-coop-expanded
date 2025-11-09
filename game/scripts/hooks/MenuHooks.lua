--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopControl
local CoopControl = ModRequire "../logic/CoopControl.lua"
---@type HeroEx
local HeroEx = ModRequire "../logic/HeroEx.lua"

---@class MenuHooks : SimpleHook
local MenuHooks = SimpleHook.New()

function MenuHooks.InitGameHooks()
    --MenuHooks.HookUiControl("ShowAwardMenu") -- Wrong name
    MenuHooks.HookUiControl("PlayTextLines")
    MenuHooks.HookUiControl("OpenUpgradeChoiceMenu")
    MenuHooks.HookUiControl("ShowStoreScreen")
    MenuHooks.HookUiControl("OpenSellTraitMenu")
end

---@private
---@param funName string
function MenuHooks.HookUiControl(funName)
    HookUtils.wrap(funName, function(originalFun, ...)
        local currentHero = HeroContext.GetCurrentHeroContext()
        local playerId = CoopPlayers.GetPlayerByHero(currentHero)
        CoopControl.SwitchControlForMenu(playerId)

        HookUtils.onPreFunctionOnce("UnfreezePlayerUnit", function()
            CoopControl.ResetAllPlayers()
        end)

        originalFun(...)
    end)
end

-- function MenuHooks.wrap.ShowAwardMenu(baseFun, ...)
--     if HeroContext.GetCurrentHeroContext() == CoopPlayers.GetMainHero() then
--         baseFun(...)
--         return
--     end

--     local prevGift, prevAssist = GameState.LastAwardTrait, GameState.LastAssistTrait

--     local currentGift, currentAssist = HeroEx.GetGiftAndAssist(CurrentRun.Hero)

--     GameState.LastAwardTrait = currentGift
--     GameState.LastAssistTrait = currentAssist

--     baseFun(...)

--     GameState.LastAwardTrait, GameState.LastAssistTrait = prevGift, prevAssist
-- end

function MenuHooks.wrap.OpenSellTraitMenu(base)
    local playerId = CoopPlayers.GetPlayerByHero(HeroContext.GetCurrentHeroContext()) or 1

    local currentRoom = CurrentRun.CurrentRoom
    local backup
    if playerId > 1 then
        backup = currentRoom.SellOptions
        currentRoom.SellOptions = currentRoom["SellOptions" .. playerId]
    end

    base()

    if playerId > 1 then
        currentRoom["SellOptions" .. playerId] = currentRoom.SellOptions
        currentRoom.SellOptions = backup
    end
end

function MenuHooks.wrap.DisplayTextLine(baseFun, screen, source, line, parentLine)
    if line.Choices then
        -- Only this solution works
        SetConfigOption { Name = "AllowControlHotSwap", Value = true }

        HookUtils.onPreFunctionOnce("UnfreezePlayerUnit", function(name)
            if name == "PlayTextLines" then
                SetConfigOption { Name = "AllowControlHotSwap", Value = false }
            end
        end)
    end
    baseFun(screen, source, line, parentLine)
end

return MenuHooks
