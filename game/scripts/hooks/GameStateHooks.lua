--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type GameStateEx
local GameStateEx = ModRequire "../logic/GameStateEx.lua"
---@type CoopArcana
local CoopArcana = ModRequire "../logic/CoopArcana.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"

---@class GameStateHooks : SimpleHook
local GameStateHooks = SimpleHook.New()

-- Keep Arcana / MetaUpgradeState on the vanilla single-player GameState path.
-- Splitting this table can corrupt saved Arcana unlock/progression data.

function GameStateHooks.post.InitializeMetaUpgradeState()
    GameStateEx.RepairArcanaFullUnlockState("InitializeMetaUpgradeState")
    CoopArcana.Initialize()
end

function GameStateHooks.wrap.RequestPreRunLoadoutChangeSave(baseFun, ...)
    if CoopArcana.IsEditorActive() then
        -- The native card screen saves while P2's temporary tables are installed.
        -- 原版卡牌页会在 P2 临时表仍安装时请求存档，此处延后到恢复共享表之后。
        CoopAppendTraceLog("[CoopArcanaEditor] stage=save-deferred player=P" .. tostring(CoopArcana.ActiveEditorPlayerId))
        return
    end
    return baseFun(...)
end

function GameStateHooks.wrap.MetaUpgradeCardAction(baseFun, screen, button)
    if CoopArcana.IsEditorActive() and button and button.CardState ~= "UNLOCKED" then
        -- Progression remains shared; P2 may equip unlocked cards but cannot spend or unlock here.
        -- 进度保持共享；P2 可装备已解锁卡牌，但不能在这里消费或解锁。
        InvalidMetaUpgradeCardAction(screen, button)
        return
    end
    return baseFun(screen, button)
end

function GameStateHooks.wrap.IncreaseMetaUpgradeCardLimit(baseFun, screen, button)
    if CoopArcana.IsEditorActive() then
        -- Card-cap purchases are permanent shared progression, never a P2 loadout edit.
        -- 卡槽上限购买属于永久共享进度，不能作为 P2 预设编辑处理。
        CannotAffordMetaUpgradeLimitPresentation(screen, button)
        return
    end
    return baseFun(screen, button)
end

function GameStateHooks.wrap.EnterUpgradeMode(baseFun, screen, button)
    if CoopArcana.IsEditorActive() then
        -- Card upgrades are permanent shared progression, never a P2 loadout edit.
        -- 卡牌升级属于永久共享进度，不能作为 P2 预设编辑处理。
        return
    end
    return baseFun(screen, button)
end

function GameStateHooks.wrap.AddRandomMetaUpgrades(baseFun, numCards, args)
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    CoopAppendTraceLog("[CoopArcanaTemporary] stage=add-random-enter player=P" .. tostring(playerId) ..
        " count=" .. tostring(numCards) ..
        " rarity=" .. tostring(args and args.RarityLevel))
    if playerId == 1 then
        return baseFun(numCards, args)
    end

    -- Circe and post-Boss cards must modify the chooser's temporary Arcana view.
    -- 喀耳刻和 Boss 后加卡必须修改选择者自己的临时阿卡那视图。
    return CoopArcana.RunWithTemporaryCards(playerId, function()
        return baseFun(numCards, args)
    end)
end

function GameStateHooks.wrap.CirceMetaUpgradeRarity(baseFun, args)
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    if playerId == 1 then
        return baseFun(args)
    end

    -- Circe rarity choices enumerate equipped cards through GameState.
    -- 喀耳刻的稀有度选项通过 GameState 枚举已装备卡牌。
    return CoopArcana.RunWithPlayerLoadout(playerId, function()
        return baseFun(args)
    end)
end

---@private
---Matches the native Kill-side gate for post-Boss Arcana cards.
---匹配本体 Kill 中对 Boss 后阿卡那卡牌的触发条件。
local function IsPostBossArcanaKill(victim, triggerArgs)
    if triggerArgs and triggerArgs.SkipOnDeathFunction then
        return false
    end
    if not victim or not victim.IsBoss or victim.BlockPostBossMetaUpgrades then
        return false
    end
    if victim.UseGroupHealthBar and not victim.GroupHealthBarOwner then
        return false
    end
    return CurrentRun and CurrentRun.EnteredBiomes < GameData.FullRunBiomeCount
end

---@private
---Replays only native temporary Arcana grants for a living P2.
---仅为存活的 P2 重放本体的临时阿卡那加卡逻辑。
local function GrantPostBossArcanaForP2(source)
    local playerTwo = CoopPlayers.GetHero(2)
    if playerTwo == nil or playerTwo.IsDead then
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=kill-skip source=" .. tostring(source) ..
            " reason=" .. tostring(playerTwo == nil and "missing" or "dead"))
        return
    end

    HeroContext.RunWithHeroContextAwait(playerTwo, function()
        local delay = 3.5
        local postBossCards = GetTotalHeroTraitValue("PostBossCards")
        local keepsake = GetHeroTrait("BossMetaUpgradeKeepsake")
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=kill-p2 source=" .. tostring(source) ..
            " cards=" .. tostring(postBossCards) ..
            " keepsake=" .. tostring(keepsake and keepsake.Name) ..
            " uses=" .. tostring(keepsake and keepsake.RemainingUses))

        if postBossCards > 0 then
            AddRandomMetaUpgrades(postBossCards, { Delay = delay })
            delay = delay + 3.5
        end
        if keepsake and keepsake.RemainingUses > 0 then
            AddRandomMetaUpgrades(2, {
                RarityLevel = GetTotalHeroTraitValue("PostBossCardRarity"),
                Delay = delay,
            })
            UseHeroTraitsWithValue("PostBossCardRarity")
            keepsake.CustomName = keepsake.ZeroBonusTrayText or "BossMetaUpgradeKeepsake_Expired"
        end
    end)
end

function GameStateHooks.post.Kill(victim, triggerArgs)
    if not IsPostBossArcanaKill(victim, triggerArgs) then
        return
    end
    -- Native Kill already grants P1's cards; add P2's isolated temporary cards.
    -- 本体 Kill 已给 P1 加卡；此处追加 P2 隔离的临时卡牌。
    GrantPostBossArcanaForP2(tostring(victim.Name) .. ":" .. tostring(victim.ObjectId))
end

function GameStateHooks.wrap.TriggerPostBossEvents(baseFun, eventSource, args)
    CoopAppendTraceLog("[CoopArcanaPostBoss] stage=entered owner=P" .. tostring(CoopPlayers.GetCurrentPlayerId() or 1))
    local results = { baseFun(eventSource, args) }
    local playerTwo = CoopPlayers.GetHero(2)
    if playerTwo == nil or playerTwo.IsDead then
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=p2-skip reason=" .. tostring(playerTwo == nil and "missing" or "dead"))
        return table.unpack(results)
    end
    if CurrentRun.CoopP2PostBossArcanaGranted then
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=p2-skip reason=already-granted")
        return table.unpack(results)
    end

    -- Native post-Boss events only inspect CurrentRun.Hero, so replay only the Arcana-card
    -- portion for P2. Other post-Boss effects remain single shared events.
    -- 本体 Boss 后事件只检查 CurrentRun.Hero，因此仅为 P2 重放阿卡那加卡部分；
    -- 其余 Boss 后效果仍保持单份共享事件。
    HeroContext.RunWithHeroContextAwait(playerTwo, function()
        CurrentRun.CoopP2PostBossArcanaGranted = true
        local delay = 0.5
        local postBossCards = GetTotalHeroTraitValue("PostBossCards")
        local keepsake = GetHeroTrait("BossMetaUpgradeKeepsake")
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=p2-check cards=" .. tostring(postBossCards) ..
            " keepsake=" .. tostring(keepsake and keepsake.Name) ..
            " uses=" .. tostring(keepsake and keepsake.RemainingUses))
        if postBossCards > 0 then
            AddRandomMetaUpgrades(postBossCards, { Delay = delay })
            delay = delay + 3.5
        end

        if keepsake and keepsake.RemainingUses > 0 then
            AddRandomMetaUpgrades(2, {
                RarityLevel = GetTotalHeroTraitValue("PostBossCardRarity"),
                Delay = delay,
            })
            UseHeroTraitsWithValue("PostBossCardRarity")
            keepsake.CustomName = keepsake.ZeroBonusTrayText or "BossMetaUpgradeKeepsake_Expired"
        end
    end)
    return table.unpack(results)
end

return GameStateHooks
