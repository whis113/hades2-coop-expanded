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
---@type GameStateEx
local GameStateEx = ModRequire "../logic/GameStateEx.lua"

---@class MenuHooks : SimpleHook
local MenuHooks = SimpleHook.New()

function MenuHooks.InitGameHooks()
    MenuHooks.HookUiControl("OpenKeepsakeRackScreen")
    MenuHooks.HookUiControl("OpenMetaUpgradeCardScreen")
    MenuHooks.HookUiControl("PlayTextLines")
    MenuHooks.HookUiControl("OpenUpgradeChoiceMenu")
    MenuHooks.HookUiControl("ShowStoreScreen")
    MenuHooks.HookUiControl("OpenSellTraitMenu")
end

---@private
---@param funName string
function MenuHooks.HookUiControl(funName)
    HookUtils.wrap(funName, function(originalFun, ...)
        local playerId = CoopPlayers.GetCurrentPlayerId()
        CoopControl.SwitchControlForMenu(playerId)

        HookUtils.onPreFunctionOnce("UnfreezePlayerUnit", function()
            CoopControl.ResetAllPlayers()
        end)

        originalFun(...)
    end)
end

function MenuHooks.pre.OpenMetaUpgradeCardScreen()
    GameStateEx.CopyTraitsToMetaUpgrades(CurrentRun.Hero)
end

function MenuHooks.wrap.OpenKeepsakeRackScreen(baseFun, ...)
    local playerId = CoopPlayers.GetCurrentPlayerId()

    if playerId == 1 then
        baseFun(...)
        return
    end

    local key = "LastAwardTraitCoopPlayer" .. playerId
    local prevGift = GameState.LastAwardTrait
    local currentGift = GameState[key]

    GameState.LastAwardTrait = currentGift

    baseFun(...)

    GameState[key] = GameState.LastAwardTrait
    GameState.LastAwardTrait = prevGift
end

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
