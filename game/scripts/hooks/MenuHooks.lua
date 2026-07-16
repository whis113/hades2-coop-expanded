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
---@type CoopArcana
local CoopArcana = ModRequire "../logic/CoopArcana.lua"
---@type RunEx
local RunEx = ModRequire "../logic/RunEx.lua"
---@type ChronosRecovery
local ChronosRecovery = ModRequire "../logic/ChronosRecovery.lua"
---@type InteractLogicHooks
local InteractLogicHooks = ModRequire "InteractLogicHooks.lua"

---@class MenuHooks : SimpleHook
local MenuHooks = SimpleHook.New()
local ENABLE_COOP_SPELL_UI_TRACE = false

---@private
MenuHooks.ActiveKeepsakeRackPlayerId = nil

---@private
---Tracks nested menu owners so closing a child screen restores the parent player's controller.
---记录嵌套菜单的拥有者，使子界面关闭后恢复父菜单玩家的控制器。
MenuHooks.MenuOwnerStack = {}

---@private
---Tracks the P1 death input block while P2 temporarily owns a native P1 menu.
---记录 P2 临时接管原生 P1 菜单期间被暂停的 P1 死亡输入锁。
MenuHooks.SuspendedP1DeathInputBlock = false

---@private
function MenuHooks.SuspendP1DeathInputBlockForP2Menu(playerId)
    if playerId ~= 2 or MenuHooks.SuspendedP1DeathInputBlock then
        return
    end

    local mainHero = CoopPlayers.GetMainHero()
    if mainHero ~= nil and mainHero.IsDead then
        -- Native menu input always listens on slot 1 after controller hot-swap.
        -- 手柄热切换后，本体菜单输入始终监听原生槽位 1。
        RemoveInputBlock({ Name = "CoopDeadPlayer1", PlayerIndex = 1 })
        MenuHooks.SuspendedP1DeathInputBlock = true
        CoopAppendTraceLog("[CoopMenuControlTrace] suspend-dead-input player=P1 owner=P2")
    end
end

---@private
function MenuHooks.RestoreP1DeathInputBlockAfterMenu()
    if not MenuHooks.SuspendedP1DeathInputBlock then
        return
    end

    local mainHero = CoopPlayers.GetMainHero()
    if mainHero ~= nil and mainHero.IsDead then
        AddInputBlock({ Name = "CoopDeadPlayer1", PlayerIndex = 1 })
    end
    MenuHooks.SuspendedP1DeathInputBlock = false
    CoopAppendTraceLog("[CoopMenuControlTrace] restore-dead-input player=P1")
end

---@private
function MenuHooks.PushMenuOwner(playerId, funName)
    if #MenuHooks.MenuOwnerStack == 0 then
        MenuHooks.SuspendP1DeathInputBlockForP2Menu(playerId)
    end
    table.insert(MenuHooks.MenuOwnerStack, playerId)
    CoopAppendTraceLog(string.format(
        "[CoopMenuControlTrace] push menu=%s owner=P%d depth=%d",
        tostring(funName), playerId, #MenuHooks.MenuOwnerStack
    ))
end

---@private
function MenuHooks.PopMenuOwner(playerId, funName)
    table.remove(MenuHooks.MenuOwnerStack)
    local parentPlayerId = MenuHooks.MenuOwnerStack[#MenuHooks.MenuOwnerStack]
    if parentPlayerId ~= nil then
        CoopControl.SwitchControlForMenu(parentPlayerId)
    else
        CoopControl.ExitMenuControl()
        MenuHooks.RestoreP1DeathInputBlockAfterMenu()
    end
    CoopAppendTraceLog(string.format(
        "[CoopMenuControlTrace] pop menu=%s owner=P%d restore=%s depth=%d",
        tostring(funName), playerId, tostring(parentPlayerId and ("P" .. parentPlayerId) or "gameplay"), #MenuHooks.MenuOwnerStack
    ))
end

---@private
---@param args table
---@return number
local function GetMenuOwnerPlayerId(args)
    -- 某些消耗品菜单在异步回调中打开，此时 CurrentRun.Hero 可能已经恢复为 P1；优先读取拾取物记录的所有者。
    -- Some consumable menus open from async callbacks after CurrentRun.Hero has reverted to P1; prefer the owner recorded on the picked item.
    for _, value in ipairs(args) do
        if type(value) == "table" and value.CoopModPickerPlayerId ~= nil then
            return value.CoopModPickerPlayerId
        end
    end
    return CoopPlayers.GetCurrentPlayerId() or 1
end

---@private
---Returns the Selene consumable passed to a spell/talent menu, when present.
---返回月神菜单携带的消耗品参数（若存在）。
local function GetSpellMenuItem(args)
    for _, value in ipairs(args) do
        if type(value) == "table" and (value.Name == "SpellDrop" or value.Name == "TalentDrop") then
            return value
        end
    end
    return nil
end

---@private
---Logs menu context only for Selene selection screens.
---仅记录月神选择菜单的玩家上下文。
local function TraceSpellMenu(stage, funName, playerId, args)
    if not ENABLE_COOP_SPELL_UI_TRACE
        or (funName ~= "OpenSpellScreen" and funName ~= "OpenTalentScreen") then
        return
    end

    local item = GetSpellMenuItem(args)
    CoopAppendTraceLog(string.format(
        "[CoopSpellUiTrace] stage=%s menu=%s owner=P%d current=P%s item=%s id=%s",
        tostring(stage), tostring(funName), playerId,
        tostring(CoopPlayers.GetCurrentPlayerId() or "nil"),
        tostring(item and item.Name), tostring(item and item.ObjectId)
    ))
end

function MenuHooks.InitGameHooks()
    MenuHooks.HookUiControl("OpenKeepsakeRackScreen")
    MenuHooks.HookUiControl("OpenWeaponShopScreen")
    MenuHooks.HookUiControl("OpenCosmeticsShopScreen")
    MenuHooks.HookUiControl("ShowBoonInfoScreen")
    MenuHooks.HookUiControl("OpenBountyBoardScreen")
    MenuHooks.HookUiControl("OpenCodexScreen")
    MenuHooks.HookUiControl("OpenElementalPromptScreen")
    MenuHooks.HookUiControl("OpenFamiliarCostumeScreen")
    MenuHooks.HookUiControl("OpenFamiliarShopScreen")
    MenuHooks.HookUiControl("OpenGameStatsScreen")
    MenuHooks.HookUiControl("OpenGhostAdminScreen")
    MenuHooks.HookUiControl("OpenMailboxScreen")
    MenuHooks.HookUiControl("OpenMarketScreen")
    MenuHooks.HookUiControl("OpenMusicPlayerScreen")
    MenuHooks.HookUiControl("OpenQuestLogScreen")
    -- Run-clear input is handled directly by native code, so it must explicitly enter the co-op menu-control stack.
    -- 结算界面的输入由本体直接处理，因此必须显式进入双人菜单控制栈。
    MenuHooks.HookUiControl("OpenRunClearScreen")
    MenuHooks.HookUiControl("OpenInventoryScreen")
    MenuHooks.HookUiControl("OpenRunHistoryScreen")
    MenuHooks.HookUiControl("OpenSellTraitMenu")
    MenuHooks.HookUiControl("OpenShrineScreen")
    MenuHooks.HookUiControl("OpenSpellScreen")
    MenuHooks.HookUiControl("OpenTalentScreen")
    MenuHooks.HookUiControl("ShowStoreScreen")
    MenuHooks.HookUiControl("ShowSurfaceShopScreen")
    MenuHooks.HookUiControl("OpenMetaUpgradeCardScreen")
    MenuHooks.HookUiControl("OpenTradeScreen")
    MenuHooks.HookUiControl("OpenTraitTrayScreen")
    MenuHooks.HookUiControl("OpenUpgradeChoiceMenu")
    MenuHooks.HookUiControl("PlayTextLines")
    MenuHooks.HookUiControl("OpenWeaponUpgradeScreen")
end

---@private
---@param funName string
function MenuHooks.HookUiControl(funName)
    HookUtils.wrap(funName, function(originalFun, ...)
        local args = { ... }
        local playerId = GetMenuOwnerPlayerId(args)
        local hero = CoopPlayers.GetHero(playerId)
        MenuHooks.PushMenuOwner(playerId, funName)
        CoopControl.SwitchControlForMenu(playerId)
        TraceSpellMenu("menu-open", funName, playerId, args)
        local fieldsSpellState = nil
        if funName == "OpenSpellScreen" or funName == "OpenTalentScreen" then
            fieldsSpellState = InteractLogicHooks.PrepareFieldsSpellMenu(GetSpellMenuItem(args), playerId)
        end

        if funName == "OpenMetaUpgradeCardScreen" and playerId == 1 then
            GameStateEx.RepairArcanaFullUnlockState("HookUiControl.OpenMetaUpgradeCardScreen")
        end

        -- 菜单内部会直接读取 CurrentRun.Hero；整个生命周期必须保持在打开者的上下文中。
        -- Native menu logic reads CurrentRun.Hero directly, so keep the full menu lifetime in the opener's context.
        if hero ~= nil then
            local result
            if funName == "OpenMetaUpgradeCardScreen" and playerId > 1 then
                -- P2 edits a temporary view so native layout switching cannot overwrite P1.
                -- P2 在临时视图中编辑，避免原版切换预设覆盖 P1。
                result = { CoopArcana.RunWithEditorLoadout(playerId, function()
                    return HeroContext.RunWithHeroContextAwait(hero, originalFun, table.unpack(args))
                end) }
            else
                result = { HeroContext.RunWithHeroContextAwait(hero, originalFun, table.unpack(args)) }
            end
            if funName == "OpenMetaUpgradeCardScreen" then
                CoopArcana.TraceAudit("card-screen-closed:P" .. tostring(playerId))
            end
            InteractLogicHooks.CompleteFieldsSpellMenu(fieldsSpellState)
            TraceSpellMenu("menu-close", funName, playerId, args)
            MenuHooks.PopMenuOwner(playerId, funName)
            return table.unpack(result)
        end
        local result = { originalFun(table.unpack(args)) }
        if funName == "OpenMetaUpgradeCardScreen" then
            CoopArcana.TraceAudit("card-screen-closed:P" .. tostring(playerId))
        end
        InteractLogicHooks.CompleteFieldsSpellMenu(fieldsSpellState)
        TraceSpellMenu("menu-close", funName, playerId, args)
        MenuHooks.PopMenuOwner(playerId, funName)
        return table.unpack(result)
    end)
end

function MenuHooks.wrap.CloseRunClearScreen(baseFun, screen)
    local result = { baseFun(screen) }
    -- The clear screen has just returned to gameplay. In a P1-dead Chronos clear, restore P2
    -- before the reward is spawned so P2 can collect it and use the exit into the palace.
    -- 结算页刚返回战斗；若 Chronos 战中 P1 死亡，须在奖励生成前恢复 P2，才能拾取沙漏并通过出口进入宫殿。
    ChronosRecovery.RestoreSurvivorControlAfterClearScreen()
    return table.unpack(result)
end

function MenuHooks.wrap.OpenKeepsakeRackScreen(baseFun, ...)
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    MenuHooks.ActiveKeepsakeRackPlayerId = playerId

    if playerId == 1 then
        baseFun(...)
        MenuHooks.ActiveKeepsakeRackPlayerId = nil
        return
    end

    local key = "LastAwardTraitCoopPlayer" .. playerId
    local blockedKey = "BlockedKeepsakesCoopPlayer" .. playerId
    local prevGift = GameState.LastAwardTrait
    local currentGift = GameState[key]
    local prevBlockedKeepsakes

    if CurrentRun then
        prevBlockedKeepsakes = CurrentRun.BlockedKeepsakes
        CurrentRun[blockedKey] = CurrentRun[blockedKey] or {}
        CurrentRun.BlockedKeepsakes = CurrentRun[blockedKey]
    end

    GameState.LastAwardTrait = currentGift

    baseFun(...)

    GameState[key] = GameState.LastAwardTrait
    GameState.LastAwardTrait = prevGift
    if CurrentRun then
        CurrentRun[blockedKey] = CurrentRun.BlockedKeepsakes
        CurrentRun.BlockedKeepsakes = prevBlockedKeepsakes
    end
    MenuHooks.ActiveKeepsakeRackPlayerId = nil
end

---@private
function MenuHooks.IsCoopRestRoomKeepsakeRack()
    if not CurrentRun or not CurrentRun.CurrentRoom then
        return false
    end

    if CoopPlayers.GetPlayersCount() <= 1 then
        return false
    end

    return RunEx.IsRestRoomName(CurrentRun.CurrentRoom.Name)
end

---@private
function MenuHooks.HasPlayerUsedKeepsakeRack(playerId)
    local room = CurrentRun and CurrentRun.CurrentRoom
    return room
        and room.CoopKeepsakeRackUsedByPlayer
        and room.CoopKeepsakeRackUsedByPlayer[playerId]
end

---@private
function MenuHooks.HaveAllPlayersUsedKeepsakeRack(room)
    for playerId = 1, CoopPlayers.GetPlayersCount() do
        if not room.CoopKeepsakeRackUsedByPlayer[playerId] then
            return false
        end
    end

    return true
end

---@private
function MenuHooks.MarkKeepsakeRackUsed(playerId, source)
    if not MenuHooks.IsCoopRestRoomKeepsakeRack() then
        return
    end

    local room = CurrentRun.CurrentRoom
    room.CoopKeepsakeRackUsedByPlayer = room.CoopKeepsakeRackUsedByPlayer or {}
    room.CoopKeepsakeRackUsedByPlayer[playerId] = true

    if MenuHooks.HaveAllPlayersUsedKeepsakeRack(room) then
        room.BlockKeepsakeMenu = true
        if source ~= nil then
            source.UseText = "UseLockedGiftRack"
            SetAnimation({ Name = "GiftRackClosed", DestinationId = source.ObjectId })
        end
    else
        room.BlockKeepsakeMenu = false
        if source ~= nil then
            source.UseText = "UseAwardMenu"
            UpdateGiftRackShineStatus(source)
        end
    end
end

function MenuHooks.wrap.UseKeepsakeRack(baseFun, giftRack, user)
    if not MenuHooks.IsCoopRestRoomKeepsakeRack() then
        return baseFun(giftRack, user)
    end

    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    if MenuHooks.HasPlayerUsedKeepsakeRack(playerId) then
        CannotUseKeepsakeRackPresentation(giftRack.ObjectId)
        return
    end

    local room = CurrentRun.CurrentRoom
    -- 原版会用房间级 BlockKeepsakeMenu 锁柜；co-op 中临时放开给尚未使用的玩家。
    -- The base game locks the rack at room level; in co-op, temporarily reopen it for the unused player.
    local prevBlocked = room.BlockKeepsakeMenu
    if prevBlocked then
        room.BlockKeepsakeMenu = false
    end

    local result = { baseFun(giftRack, user) }

    if prevBlocked and not MenuHooks.HasPlayerUsedKeepsakeRack(playerId) then
        room.BlockKeepsakeMenu = prevBlocked
    end

    return table.unpack(result)
end

function MenuHooks.wrap.KeepsakeScreenClose(baseFun, screen, button)
    local playerId = MenuHooks.ActiveKeepsakeRackPlayerId or CoopPlayers.GetCurrentPlayerId() or 1
    -- 只有真正更换信物才消耗本玩家在该 Rest Room 的使用次数。
    -- Only an actual keepsake change consumes this player's Rest Room rack use.
    local changed = screen ~= nil and screen.LastTrait ~= GameState.LastAwardTrait
    CoopPlayers.TraceManaState("keepsake-close-before-p" .. tostring(playerId))

    local hero = CoopPlayers.GetHero(playerId)
    if playerId > 1 and hero ~= nil then
        -- 本体关闭流程会直接对 CurrentRun.Hero 卸载/装备信物；必须绑定到选择者。
        -- Native close logic unequips/equips CurrentRun.Hero directly, so bind it to the chooser.
        HeroContext.RunWithHeroContextAwait(hero, baseFun, screen, button)
    else
        baseFun(screen, button)
    end

    if playerId > 1 then
        -- 修复旧版本曾把 P2 MP 信物的独立奖励 trait 写入 P1 的残留状态。
        -- Clean up legacy state where the P2 MP-keepsake reward trait was written to P1.
        CoopPlayers.RemoveStaleMainHeroManaKeepsakeBonus()
    end

    CoopPlayers.TraceManaState("keepsake-close-after-p" .. tostring(playerId))

    if changed then
        MenuHooks.MarkKeepsakeRackUsed(playerId, screen.Source)
    end
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

function MenuHooks.pre.OnScreenOpened(screen)
    DebugPrint { Text = "OnScreenOpened:  " .. tostring(screen.Name) }
end

return MenuHooks
