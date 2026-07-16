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
---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "../logic/SecondPlayerUI.lua"
---@type RunEx
local RunEx = ModRequire "../logic/RunEx.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "../logic/PlayerVisibilityHelper.lua"
---@type HeroEx
local HeroEx = ModRequire "../logic/HeroEx.lua"
---@type CoopControl
local CoopControl = ModRequire "../logic/CoopControl.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"
---@type CoopModConfig
local Config = ModRequire "../config.lua"
---@type ChronosRecovery
local ChronosRecovery = ModRequire "../logic/ChronosRecovery.lua"

---@class RunHooks : SimpleHook
local RunHooks = SimpleHook.New()

local function CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

local function GetPlayerStateText()
    local out = {}
    for playerId, hero in CoopPlayers.PlayersIterator() do
        table.insert(out, "P" .. tostring(playerId) ..
            "{dead=" .. tostring(hero and hero.IsDead and true or false) ..
            ",id=" .. tostring(hero and hero.ObjectId) .. "}")
    end
    return table.concat(out, " ")
end

local function GetFlagStateText(flags)
    local out = {}
    for flag, enabled in pairs(flags or {}) do
        if enabled then
            table.insert(out, tostring(flag))
        end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function GetBossStateText()
    local out = {}
    for _, enemy in pairs(ActiveEnemies or {}) do
        if enemy.IsBoss then
            table.insert(out,
                tostring(enemy.Name) ..
                "{id=" .. tostring(enemy.ObjectId) ..
                ",dead=" .. tostring(enemy.IsDead and true or false) ..
                ",phase=" .. tostring(enemy.CurrentPhase) .. "/" .. tostring(enemy.Phases) ..
                ",target=" .. tostring(enemy.TargetId) ..
                ",ai=" .. tostring(enemy.AIThreadName) ..
                ",notify=" .. tostring(enemy.AINotifyName) ..
                ",flags=" .. GetFlagStateText(enemy.InvulnerableFlags) .. "}")
        end
    end
    return table.concat(out, " ")
end

local function TraceBossState(label)
    if not Config.Debug.SoftlockTrace then
        return
    end

    local room = CurrentRun and CurrentRun.CurrentRoom
    local encounter = room and room.Encounter
    if not (encounter and encounter.EncounterType == "Boss") then
        return
    end

    local text = "[CoopBossTrace] " .. label ..
        " room=" .. tostring(room.Name) ..
        " encounter=" .. tostring(encounter.Name) ..
        " mapBlockSpawns=" .. tostring(MapState and MapState.BlockSpawns) ..
        " roomExitsUnlocked=" .. tostring(room.ExitsUnlocked) ..
        " requiredKills=" .. tostring(CountTable(RequiredKillEnemies)) ..
        " alivePlayers=" .. tostring(#CoopPlayers.GetAliveHeroes()) ..
        " defaultHero=" .. tostring(HeroContext.GetDefaultHero() and HeroContext.GetDefaultHero().ObjectId) ..
        " runFlags=" .. GetFlagStateText(CurrentRun.InvulnerableFlags) ..
        " players=" .. GetPlayerStateText() ..
        " bosses=" .. GetBossStateText()
    DebugPrint { Text = text }
    CoopAppendTraceLog(text)
end

---@private
---Releases boss AI waits that were targeting a player who just died.
---解除仍朝向刚死亡玩家的 Boss AI 等待。
local function WakeBossAiAfterPlayerDeath(aliveHero)
    local room = CurrentRun and CurrentRun.CurrentRoom
    local encounterName = room and room.Encounter and room.Encounter.Name or ""
    if aliveHero == nil or aliveHero.ObjectId == nil or not string.find(encounterName, "Boss") then
        return 0, 0
    end

    local released = 0
    local deferred = 0
    for _, enemy in pairs(ActiveEnemies or {}) do
        if enemy ~= nil and not enemy.IsDead and enemy.AINotifyName ~= nil then
            -- Prometheus owns a separate cinematic coroutine while the fire-wave memory attack
            -- is active. Releasing its normal AI wait here skips the native landing/outro path.
            -- 普罗米修斯火浪记忆攻击期间使用独立演出协程；此处释放常规 AI 等待会跳过本体落地/收尾流程。
            if enemy.InvulnerableFlags and enemy.InvulnerableFlags.PrometheusMemoryPresentation then
                deferred = deferred + 1
            else
            local notifyName = enemy.AINotifyName
            -- Abort the in-flight attack so the native loop rebuilds its local AI data and asks
            -- GetTargetId for a living player on the next iteration.
            -- 中断当前攻击，使本体循环下一轮重建局部 AI 数据，并通过 GetTargetId 重新选择存活玩家。
            enemy.TargetId = aliveHero.ObjectId
            enemy.ForcedWeaponInterrupt = "CoopRetargetAfterPlayerDeath"
            -- Distance waits read NotifyResultsTable to choose their next target. Point every interrupted boss wait at the survivor.
            -- 距离等待会从 NotifyResultsTable 读取下一目标；将被中断的 Boss 等待明确指向存活者。
            NotifyResultsTable[notifyName] = aliveHero.ObjectId
            if string.find(notifyName, "WaitForRotation") then
                -- The rotation wait is bound to the old facing target. Re-face toward the living player before releasing it.
                -- 转向等待绑定了旧的朝向目标；释放前先朝向仍存活的玩家。
                AngleTowardTarget({ Id = enemy.ObjectId, DestinationId = aliveHero.ObjectId })
            end
            notifyExistingWaiters(enemy.AINotifyName)
            SetThreadWait(enemy.AIThreadName, 0.01)
            released = released + 1
            end
        end
    end

    CoopAppendTraceLog(string.format(
        "[CoopBossTrace] death-ai-wake room=%s encounter=%s target=%s released=%d deferredPresentation=%d",
        tostring(room and room.Name), tostring(encounterName), tostring(aliveHero.ObjectId), released, deferred
    ))
    return released, deferred
end

local function TraceBossDeathTimeline()
    local room = CurrentRun and CurrentRun.CurrentRoom
    if not room then
        return
    end

    thread(function()
        for _, delay in ipairs({ 0.5, 2.0, 5.0 }) do
            waitUnmodified(delay)
            if CurrentRun and CurrentRun.CurrentRoom == room then
                TraceBossState("after-death+" .. tostring(delay))
            end
        end
    end)
end

local function TraceDeathState(label)
    if not Config.Debug.SoftlockTrace then
        return
    end

    local room = CurrentRun and CurrentRun.CurrentRoom
    local text = "[CoopDeathTrace] " .. label ..
        " room=" .. tostring(room and room.Name) ..
        " alivePlayers=" .. tostring(#CoopPlayers.GetAliveHeroes()) ..
        " defaultHero=" .. tostring(HeroContext.GetDefaultHero() and HeroContext.GetDefaultHero().ObjectId) ..
        " players=" .. GetPlayerStateText()
    CoopAppendTraceLog(text)
end

local function GetDeadPlayerInputBlockName(playerId)
    return "CoopDeadPlayer" .. tostring(playerId)
end

local function SetHeroDeadPresentation(hero)
    local playerId = CoopPlayers.GetPlayerByHero(hero)
    if playerId then
        AddInputBlock { Name = GetDeadPlayerInputBlockName(playerId), PlayerIndex = playerId }
    end
    if hero.ObjectId then
        SetAlpha { Id = hero.ObjectId, Fraction = 0, Duration = 0 }
    end
end

local function TraceRoomExitState(label, result)
    if not Config.Debug.SoftlockTrace then
        return
    end

    local room = CurrentRun and CurrentRun.CurrentRoom
    local encounter = room and room.Encounter

    DebugPrint { Text = "[CoopSoftlockTrace] " .. label ..
        " result=" .. tostring(result) ..
        " room=" .. tostring(room and room.Name) ..
        " roomSet=" .. tostring(room and room.RoomSetName) ..
        " encounter=" .. tostring(encounter and encounter.Name) ..
        " encounterType=" .. tostring(encounter and encounter.EncounterType) ..
        " exitsUnlocked=" .. tostring(room and room.ExitsUnlocked) ..
        " requiredKills=" .. tostring(CountTable(RequiredKillEnemies)) ..
        " requiredObjects=" .. tostring(CountTable(MapState and MapState.RoomRequiredObjects)) ..
        " alivePlayers=" .. tostring(#CoopPlayers.GetAliveHeroes()) ..
        " players=" .. GetPlayerStateText() }
end

---@private
---Applies only the P2-specific Arcana part of native post-Boss effects once.
---仅为 P2 执行一次本体 Boss 后效果中的阿卡那加卡部分。
local function GrantPostBossArcanaForP2(currentRoom, currentEncounter)
    if not currentEncounter or currentEncounter.EncounterType ~= "Boss" then
        return
    end
    -- Layer guardians use *_BossNN room names; miniboss rooms use *_MiniBossNN.
    -- 层守卫使用 *_BossNN 房间名；小 Boss 使用 *_MiniBossNN。
    local roomName = currentRoom and currentRoom.Name or ""
    local isLayerBoss = string.match(roomName, "^[A-Z]+_Boss%d+$") ~= nil
    if not isLayerBoss then
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=end-effects-skip reason=non-layer-boss room=" ..
            tostring(roomName))
        return
    end
    if CurrentRun.CoopP2PostBossArcanaGranted then
        return
    end

    local playerTwo = CoopPlayers.GetHero(2)
    if playerTwo == nil or playerTwo.IsDead then
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=end-effects-skip reason=" .. tostring(playerTwo == nil and "missing" or "dead"))
        return
    end

    CurrentRun.CoopP2PostBossArcanaGranted = true
    HeroContext.RunWithHeroContextAwait(playerTwo, function()
        local delay = 0.5
        local postBossCards = GetTotalHeroTraitValue("PostBossCards")
        local keepsake = GetHeroTrait("BossMetaUpgradeKeepsake")
        CoopAppendTraceLog("[CoopArcanaPostBoss] stage=end-effects-p2 cards=" .. tostring(postBossCards) ..
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

function RunHooks.pre.DeathAreaRoomTransition()
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
    end
end

function RunHooks.wrap.CheckDistanceTrigger(CheckDistanceTriggerFun, ...)
    -- Distance triggers must bind to the living hero after P1 dies; boss and miniboss presentations use these waits.
    -- P1 死亡后距离触发器必须绑定存活英雄；Boss 和小 Boss 演出会使用这些等待条件。
    local contextHero = CoopPlayers.GetAliveHeroes()[1] or CoopPlayers.GetMainHero()
    HeroContext.RunWithHeroContext(contextHero, CheckDistanceTriggerFun, ...)
end

function RunHooks.wrap.SetupHeroObject(SetupHeroObjectFun, ...)
    local mainHero = CoopPlayers.GetMainHero()

    HeroContext.RunWithHeroContext(mainHero, SetupHeroObjectFun, ...)
    -- Fix unit -> hero table here
    CoopPlayers.UpdateMainHero()

    PlayerVisibilityHelper.AddPlayerMarkers(1, mainHero.ObjectId)

    if mainHero.IsDead and not RunEx.IsRunEnded() then
        HeroEx.HideHero(mainHero)
    end
end

function RunHooks.wrap.StartRoom(StartRoomFun, run, currentRoom)
    -- Fixes mouse disappearing after level transiction
    CoopControl.ResetAllPlayers("Current")

    -- Initialization after save loading when encounter is active
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
        CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())
    end

    if currentRoom.RoomSetName == "Surface" then
        RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    else
        RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    HookUtils.onPostFunctionOnce("SwitchActiveUnit", function()
        SwitchActiveUnit { PlayerIndex = 1, Id = CoopPlayers.GetMainHero().ObjectId }
    end)

    if RunEx.IsRunEnded() then
        HeroContext.SetDefaultHero(CoopPlayers.GetMainHero())
        HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), StartRoomFun, run, currentRoom)
    else
        local hero = CoopPlayers.GetAliveHeroes()[1] or CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(hero, StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = false
    HeroContext.SetDefaultHero(mainHero)

    if mainHero.Health == 0 then
        mainHero.Health = mainHero.MaxHealth
    end

    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end

    HeroContext.RunWithHeroContext(mainHero, StartRoomFun, run, currentRoom)
end

function RunHooks.post.StartNewRun()
    Events.run:trigger("newRunStarted", CurrentRun)
    CoopPlayers.RemoveMisplacedAdditionalFamiliarTraits()
    CoopPlayers.TraceManaState("new-run-before-mana-cleanup")
    -- 新 run 前清理旧版本可能残留在 P1 的 P2 MP 信物加成。
    -- Clear any legacy P2 MP-keepsake bonus left on P1 before a new run starts.
    CoopPlayers.RemoveStaleMainHeroManaKeepsakeBonus()
    CoopPlayers.TraceManaState("new-run-after-mana-cleanup")
end

--- Bypass IsAlive check with this hook
function RunHooks.wrap.CheckRoomExitsReady(baseFun, ...)
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]
    if aliveHero then
        local result = false
        HeroContext.RunWithHeroContext(aliveHero, function(...)
            result = baseFun(...)
        end, ...)

        TraceRoomExitState("CheckRoomExitsReady", result)

        return result
    else
        local result = baseFun(...)
        TraceRoomExitState("CheckRoomExitsReadyNoAliveHero", result)
        return result
    end
end

function RunHooks.wrap.EndEarlyAccessPresentation(baseFun)
    local mainHero = CoopPlayers.GetMainHero()
    CoopAppendTraceLog("[CoopEndRunTrace] early-access-outro-start mainHero=" .. tostring(mainHero and mainHero.ObjectId))
    mainHero.IsDead = false
    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end
    -- 结局演出内部包含多个 wait；必须使用 Await 版本保持整个协程都绑定 P1。
    -- The ending presentation contains multiple waits; use Await so the full coroutine remains bound to P1.
    -- Native code kills P1 asynchronously at the outro end; do not route that ending-only death through co-op wipe handling.
    -- 本体会在结局尾部异步击杀 P1；该结算专用死亡不能进入双人团灭接管。
    CurrentRun.CoopModEndingEarlyAccess = true
    local result = { HeroContext.RunWithHeroContextAwait(mainHero, baseFun) }
    CurrentRun.CoopModEndingEarlyAccess = nil
    CoopAppendTraceLog("[CoopEndRunTrace] early-access-outro-finished")
    return table.unpack(result)
end

function RunHooks.wrap.ChronosKillPresentation(baseFun, unit, args)
    local mainHero = CoopPlayers.GetMainHero()
    local presentationHero = CoopPlayers.GetAliveHeroes()[1] or mainHero
    -- Chronos opens the clear screen after several waits; it must stay in a living player's context.
    -- 克洛诺斯会在多段等待后打开结算界面，演出全程必须保持在存活玩家的上下文中。
    CoopAppendTraceLog(string.format(
        "[CoopEndRunTrace] chronos-presentation-owner=P%s",
        tostring(CoopPlayers.GetPlayerByHero(presentationHero) or "nil")
    ))
    local result = { HeroContext.RunWithHeroContextAwait(presentationHero, baseFun, unit, args) }
    ChronosRecovery.Recover("presentation-finished", true)
    return table.unpack(result)
end

function RunHooks.wrap.KillHero(baseFun, ...)
    local dyingHero = CurrentRun.Hero
    if CurrentRun.CoopModEndingEarlyAccess then
        -- Preserve the native save and map-transition flow for the ending-only death.
        -- 保留结算专用死亡的本体存档与地图切换流程。
        CoopAppendTraceLog("[CoopEndRunTrace] early-access-native-kill hero=" .. tostring(dyingHero and dyingHero.ObjectId))
        return baseFun(...)
    end
    if dyingHero.IsDead then
        TraceBossState("duplicate-death-ignored")
        return
    end

    dyingHero.IsDead = true
    TraceRoomExitState("KillHero")
    TraceBossState("death-marked")
    TraceDeathState("death-marked")
    if not CoopPlayers.HasAlivePlayers() then
        -- 全员死亡时回到原版 P1 死亡结算路径。
        -- If all players are dead, fall back to the original P1 death flow.
        local mainHero = CoopPlayers.GetMainHero()
        HeroEx.ShowHero(mainHero, dyingHero.ObjectId)
        RemoveOutline({ Id = mainHero.ObjectId })
        HeroContext.RunWithHeroContext(mainHero, baseFun, ...)
        CoopPlayers.OnAllPlayersDead()
        return
    end
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]

    if dyingHero == CoopPlayers.GetMainHero() then
        SetHeroDeadPresentation(dyingHero)

        HeroContext.SetDefaultHero(aliveHero)
    else
        SetHeroDeadPresentation(dyingHero)
    end
    -- Never rebuild a boss AI from stage one: staged bosses retain phase-local state in the
    -- native coroutine. Retarget and release the existing coroutine instead.
    -- 绝不从第一阶段重建 Boss AI：分阶段 Boss 的阶段状态保存在本体协程中；这里只重定向并释放原协程。
    local released, deferred = WakeBossAiAfterPlayerDeath(aliveHero)
    if released > 0 then
        CoopAppendTraceLog(string.format(
            "[CoopBossTrace] death-ai-retarget room=%s target=%s",
            tostring(CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Name),
            tostring(aliveHero.ObjectId)
        ))
    elseif deferred > 0 then
        CoopAppendTraceLog(string.format(
            "[CoopBossTrace] death-ai-deferred room=%s target=%s reason=PrometheusMemoryPresentation",
            tostring(CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Name),
            tostring(aliveHero.ObjectId)
        ))
    end
    TraceBossState("death-handled")
    TraceDeathState("death-handled")
    TraceBossDeathTimeline()
end

function RunHooks.pre.LeaveRoom(currentRun, door)
    Events.run:trigger("roomPreLeave", currentRun, door)

    local previousRoomName = currentRun and currentRun.CurrentRoom and currentRun.CurrentRoom.Name
    local nextRoomName = door and door.Room and door.Room.Name
    -- 原版 LeaveRoom 只为当前开门英雄调用一次 RefillMana；将这一次基础过门补蓝分发给所有存活英雄。
    -- Native LeaveRoom calls RefillMana once for only the door owner; fan out this one base door refill to every alive hero.
    HookUtils.wrapOnce("RefillMana", function(baseFun)
        local manaBefore = {}
        local aliveHeroes = CoopPlayers.GetAliveHeroes()
        for _, hero in ipairs(aliveHeroes) do
            manaBefore[hero] = hero.Mana
            HeroContext.RunWithHeroContextAwait(hero, baseFun)
        end

        if CoopAppendTraceLog then
            local playerStates = {}
            for _, hero in ipairs(aliveHeroes) do
                local playerId = CoopPlayers.GetPlayerByHero(hero)
                table.insert(playerStates, string.format(
                    "P%s{%s->%s/%s}",
                    tostring(playerId),
                    tostring(manaBefore[hero]),
                    tostring(hero.Mana),
                    tostring(hero.MaxMana)
                ))
            end
            CoopAppendTraceLog("[CoopDoorManaTrace] from=" .. tostring(previousRoomName) ..
                " to=" .. tostring(nextRoomName) .. " " .. table.concat(playerStates, " "))
        end
    end)
end

function RunHooks.post.RestoreUnlockRoomExits()
    TraceRoomExitState("RestoreUnlockRoomExits")

    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
        CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())
    end

    local spawnPoint = CurrentRun.CurrentRoom.HeroEndPoint or CoopPlayers.GetMainHero().ObjectId
    for playerId = 2, CoopPlayers.GetPlayersCount() do
        CoopPlayers.RestoreSavedHero(playerId)
        local hero = CoopPlayers.GetHero(playerId)
        -- Teleport alive players (including those revived in OnRoomPreLeave)
        if hero and hero.ObjectId and not hero.IsDead then
            Teleport { Id = hero.ObjectId, DestinationId = spawnPoint }
        end
    end

    SecondPlayerUi.Refresh()
end

function RunHooks.wrap.EndEncounterEffects(baseFun, currentRun, currentRoom, currentEncounter)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, currentRun, currentRoom, currentEncounter)
        currentRoom.CodexUpdates = nil
        currentRoom.PendingCodexUpdate = nil
    end
end

function RunHooks.wrap.StartEncounterEffects(baseFun, run)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, run)
    end
end

function RunHooks.post.StartRoomPresentation(run, room)
    Events.run:trigger("roomPresentationFinished", run, room)
    ChronosRecovery.Recover("room-presentation", false)
end

function RunHooks.pre.OnAllEnemiesDead()
    TraceRoomExitState("OnAllEnemiesDead")
    Events.run:trigger("allEnemiesDead")
end

function RunHooks.pre.StartRoom()
    Events.run:trigger("roomPreStart")
end

--- 修正 Chronos 阶段转换后的玩家位置。
--- Fix player positions after Chronos phase transitions.
function RunHooks.post.ChronosPhaseTransition()
    TraceBossState("chronos-phase-transition")
    for _, hero in pairs(CoopPlayers.GetAliveHeroes()) do
        Teleport({ Id = hero.ObjectId, DestinationId = 645921 })
    end
end

return RunHooks
