--
-- Upgrade choice diagnostics / 祝福选择诊断
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"

---@class UpgradeChoiceHooks : SimpleHook
local UpgradeChoiceHooks = SimpleHook.New()

---@private
local function FindRarityKeepsake(hero, lootName)
    if hero == nil or hero.Traits == nil then
        return nil
    end

    for _, trait in ipairs(hero.Traits) do
        local rarityData = trait.RarityUpgradeData
        if rarityData ~= nil and rarityData.LootName == lootName then
            return trait
        end
    end
end

---@private
---@param options table | nil
---@return string
local function GetOptionSignature(options)
    local names = {}
    for _, option in ipairs(options or {}) do
        table.insert(names, tostring(option.ItemName) .. ":" .. tostring(option.SecondaryItemName))
    end
    return table.concat(names, "|")
end

---@private
---@param source table
---@param playerId number
local function PrepareIndependentChaosOptions(source, playerId)
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room == nil then
        return
    end

    if playerId == 1 then
        return
    end

    local primarySignature = room.CoopChaosPrimaryOptionSignature
    -- P2 的 Chaos 列表在显示前主动生成；若与 P1 相同则切换同步随机槽位重试。
    -- Generate P2's Chaos list before showing it; retry with different synchronized slots if it matches P1.
    for randomSlot = 102, 110 do
        source.UpgradeOptions = nil
        RandomSynchronize(randomSlot)
        SetTraitsOnLoot(source)
        if primarySignature == nil or GetOptionSignature(source.UpgradeOptions) ~= primarySignature then
            CoopAppendTraceLog(string.format(
                "[CoopChaosTrace] player=P%d slot=%d options=%s",
                playerId,
                randomSlot,
                GetOptionSignature(source.UpgradeOptions)
            ))
            return
        end
    end

    CoopAppendTraceLog(string.format(
        "[CoopChaosTrace] player=P%d no-distinct-options=%s",
        playerId,
        GetOptionSignature(source.UpgradeOptions)
    ))
end

---@private
---@param source table
---@param hero table
---@param playerId number
local function PrepareIndependentWeaponOptions(source, hero, playerId)
    if playerId == 1 then
        return
    end

    -- Native menu opening reuses LootTypeHistory[WeaponUpgrade], so equal weapons get equal lists.
    -- 本体菜单会复用 LootTypeHistory[WeaponUpgrade]，相同武器会得到相同列表。
    HeroContext.RunWithHeroContextAwait(hero, function()
        source.UpgradeOptions = nil
        RandomSynchronize(120 + playerId)
        SetTraitsOnLoot(source)
    end)
    CoopAppendTraceLog(string.format(
        "[CoopChoiceTrace] weapon-reroll player=P%d weapon=%s options=%s",
        playerId,
        tostring(hero.WeaponName),
        GetOptionSignature(source.UpgradeOptions)
    ))
end

function UpgradeChoiceHooks.wrap.GetEligibleTraitUpgrades(baseFun, lootData)
    if lootData == nil or lootData.Traits == nil then
        -- 月神咒语等非普通 boon 数据没有 Traits；本体仍会进入候选池补全逻辑。
        -- Selene spells and other non-standard boon data have no Traits, but native code can still enter the option-fill path.
        CoopAppendTraceLog(string.format(
            "[CoopSpellGuardTrace] skip-missing-traits name=%s transforming=%s priority=%s currentPlayer=P%d",
            tostring(lootData and lootData.Name),
            tostring(lootData and lootData.TransformingTraits ~= nil),
            tostring(lootData and lootData.PriorityUpgrades ~= nil),
            CoopPlayers.GetCurrentPlayerId() or 1
        ))
        return {}
    end
    return baseFun(lootData)
end

function UpgradeChoiceHooks.wrap.OpenUpgradeChoiceMenu(baseFun, source, args)
    -- 将菜单创建者写到 screen source，供后续无触发参数的 UI 回调恢复玩家归属。 / Store the menu owner on its source so later UI callbacks can recover player ownership.
    -- 将菜单创建者写到 screen source，并在其英雄上下文中构建选项；锤子池会读取 CurrentRun.Hero 的武器。 / Store the menu owner on its source and build options in that hero context; hammer pools read the current hero weapon.
    local playerId = CoopPlayers.GetCurrentPlayerId() or 1
    source.CoopModUpgradeChoicePlayerId = playerId
    local hero = CoopPlayers.GetHero(playerId)
    if hero ~= nil then
        local lootData = LootData and LootData[source.Name]
        local isGodBoon = source.GodLoot or (lootData and lootData.GodLoot)
        if source.Name == "WeaponUpgrade" or source.Name == "TrialUpgrade" or isGodBoon then
            -- 锤子和混沌 boon 的选项会在掉落生成时缓存；每位玩家打开前都要清空，让本体按当前 HeroContext 独立生成。
            -- Hammer and Chaos-boon options are cached when loot spawns; clear them for every picker so native code rerolls in that player's HeroContext.
            source.UpgradeOptions = nil
            CoopAppendTraceLog(string.format(
                "[CoopChoiceTrace] refresh-options player=P%d loot=%s god=%s weapon=%s",
                playerId,
                tostring(source.Name),
                tostring(isGodBoon and true or false),
                tostring(hero.WeaponName)
            ))
            if source.Name == "WeaponUpgrade" then
                PrepareIndependentWeaponOptions(source, hero, playerId)
            elseif source.Name == "TrialUpgrade" then
                PrepareIndependentChaosOptions(source, playerId)
            end
        end
        local result = { HeroContext.RunWithHeroContextAwait(hero, baseFun, source, args) }
        if source.Name == "TrialUpgrade" and playerId == 1 and CurrentRun and CurrentRun.CurrentRoom then
            CurrentRun.CurrentRoom.CoopChaosPrimaryOptionSignature = GetOptionSignature(source.UpgradeOptions)
            CoopAppendTraceLog("[CoopChaosTrace] player=P1 options=" .. CurrentRun.CurrentRoom.CoopChaosPrimaryOptionSignature)
        end
        return table.unpack(result)
    end
    return baseFun(source, args)
end

---@private
local EventChoiceCloseHandlers = {
    EchoPostChoicePresentation = true,
    ArachneArmorApply = true,
    NarcissusPostChoicePresentation = true,
    MedeaCursePostChoicePresentation = true,
    CirceBlessingPostChoicePresentation = true,
    IcarusPostChoicePresentation = true,
}

---@private
local NpcBoonChoiceSources = {
    NPC_Echo_01 = true,
    NPC_Arachne_01 = true,
    NPC_Medea_01 = true,
    NPC_Circe_01 = true,
    NPC_Icarus_01 = true,
    NPC_Artemis_Field_01 = true,
    NPC_Athena_01 = true,
    NPC_Dionysus_01 = true,
    NPC_Hades_Field_01 = true,
}

---@private
local function ShouldOpenSecondNpcChoice(screen)
    if CoopPlayers.GetPlayersCount() < 2 or screen == nil or screen.Source == nil then
        return false
    end
    if screen.Source.CoopModSecondNpcChoice then
        return false
    end
    local room = CurrentRun and CurrentRun.CurrentRoom
    if room and room.CoopNpcSecondChoiceStarted then
        return false
    end
    -- 部分 NPC 将收尾回调写在对话屏幕而非 boon 屏幕，故同时按本体收尾回调和实际 NPC source 识别。 / Some NPCs store their finish callback on the dialogue screen rather than the boon screen, so match both native close handlers and the actual NPC source.
    return EventChoiceCloseHandlers[screen.OnCloseFinishedFunctionName] == true
        or NpcBoonChoiceSources[screen.Source.Name] == true
end

function UpgradeChoiceHooks.wrap.CloseUpgradeChoiceScreen(baseFun, screen, button)
    if not ShouldOpenSecondNpcChoice(screen) then
        return baseFun(screen, button)
    end

    local firstPlayerId = screen.Source.CoopModUpgradeChoicePlayerId
        or CoopPlayers.GetCurrentPlayerId()
        or 1
    local secondPlayerId = firstPlayerId == 1 and 2 or 1
    local secondHero = CoopPlayers.GetHero(secondPlayerId)
    if secondHero == nil or secondHero.IsDead then
        return baseFun(screen, button)
    end

    local room = CurrentRun and CurrentRun.CurrentRoom
    if room then
        room.CoopNpcSecondChoiceStarted = true
    end

    local closeHandler = screen.OnCloseFinishedFunctionName
    local closeArgs = screen.OnCloseFinishedFunctionArgs
    local source = DeepCopyTable(screen.Source)
    source.CoopModSecondNpcChoice = true
    source.CoopModUpgradeChoicePlayerId = secondPlayerId
    -- 清空首位玩家已看到的选项，让另一位玩家通过本体规则重新生成一套列表。 / Clear the first player's seen options so the other player receives a fresh native list.
    source.UpgradeOptions = nil

    -- 首位玩家选完后不能先执行 NPC 离场/结算；将该回调延后到另一位玩家的选择关闭时。 / Do not run NPC departure/finalization after the first choice; defer it until the other player closes their choice.
    screen.OnCloseFinishedFunctionName = nil
    screen.OnCloseFinishedFunctionArgs = nil
    CoopAppendTraceLog(string.format(
        "[CoopNpcRewardTrace] first-choice player=P%d source=%s handler=%s; opening player=P%d list",
        firstPlayerId, tostring(source.Name), tostring(closeHandler), secondPlayerId
    ))
    local result = { baseFun(screen, button) }

    HeroContext.RunWithHeroContextAwait(secondHero, function()
        OpenUpgradeChoiceMenu(source, {
            OverwriteTableKeys = {
                OnCloseFinishedFunctionName = closeHandler,
                OnCloseFinishedFunctionArgs = closeArgs,
            },
        })
    end)

    return table.unpack(result)
end

function UpgradeChoiceHooks.wrap.UpgradeChoiceScreenCheckRarifyButton(baseFun, screen, button)
    local sourcePlayerId = screen and screen.Source and screen.Source.CoopModUpgradeChoicePlayerId
    local sourceHero = sourcePlayerId and CoopPlayers.GetHero(sourcePlayerId)
    local result
    local contextPlayerId

    if sourceHero ~= nil then
        -- 本体函数直接读取 CurrentRun.Hero.Traits；祝福菜单必须回到拾取该 boon 的玩家。 / Native code reads CurrentRun.Hero.Traits directly, so bind the menu to the boon picker.
        result = { HeroContext.RunWithHeroContextAwait(sourceHero, function()
            -- 必须在上下文尚未恢复默认 Hero 前记录，避免诊断日志把 P2 错写成 P1。 / Record before the context restores the default hero so diagnostics do not mislabel P2 as P1.
            contextPlayerId = CoopPlayers.GetPlayerByHero(CurrentRun.Hero) or 1
            return baseFun(screen, button)
        end) }
    else
        contextPlayerId = CoopPlayers.GetPlayerByHero(CurrentRun and CurrentRun.Hero) or 1
        result = { baseFun(screen, button) }
    end

    local displayedPlayerId = sourcePlayerId or "?"
    local lootName = button and button.LootData and button.LootData.Name
    local trait = FindRarityKeepsake(sourceHero or (CurrentRun and CurrentRun.Hero), lootName)
    local rarityUses = trait and trait.RarityUpgradeData and trait.RarityUpgradeData.Uses
    local visible = screen and screen.Components and screen.Components.RarifyButton and screen.Components.RarifyButton.Visible

    -- 记录本体实际读取的 HeroContext，而非仅记录掉落所属玩家。 / Log the HeroContext actually read by native UI code, not just the loot owner.
    CoopAppendTraceLog(string.format(
        "[CoopRarityTrace] sourcePlayer=P%s contextPlayer=P%d loot=%s trait=%s rarityUses=%s visible=%s",
        tostring(displayedPlayerId),
        contextPlayerId,
        tostring(lootName),
        tostring(trait and trait.Name),
        tostring(rarityUses),
        tostring(visible and true or false)
    ))

    return table.unpack(result)
end

return UpgradeChoiceHooks
