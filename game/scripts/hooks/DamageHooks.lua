--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "../logic/SecondPlayerUI.lua"
---@type HeroContextWrapper
local HeroContextWrapper = ModRequire "../logic/HeroContextWrapper.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopModConfig
local Config = ModRequire "../config.lua"

local DamageHooks = SimpleHook.New()

function DamageHooks:InitEngineHooks()
    -- TODO check: HandleStoredProjectileDeath
    -- Lob weapon fucked in ChronosPhaseTransition
    -- WTF with LOB ChronosPhaseTransition

    HeroContextWrapper.WrapTriggerHero("OnWeaponFired", "OwnerTable")
    HeroContextWrapper.WrapTriggerHero("OnWeaponTriggerRelease", "OwnerTable")
    HeroContextWrapper.WrapTriggerHero("OnWeaponFailedToFire", "TriggeredByTable")
    HeroContextWrapper.WrapTriggerHero("OnWeaponCharging", "OwnerTable")
    HeroContextWrapper.WrapTriggerHero("OnWeaponChargeCanceled", "OwnerTable")
    HeroContextWrapper.WrapTriggerHero("OnPerfectChargeWindowEntered", "OwnerTable")
    HeroContextWrapper.WrapTriggerHero("OnProjectileCreation", "TriggeredByTable")
    HeroContextWrapper.WrapTriggerHero("OnProjectileArm", "TriggeredByTable")
    HeroContextWrapper.WrapTriggerHero("OnProjectileBlock", "Blocker")
    HeroContextWrapper.WrapTriggerHero("OnDodge", "TriggeredByTable")
    HeroContextWrapper.WrapTriggerHero("OnProjectileReflect", "TriggeredByTable")
    HeroContextWrapper.WrapTriggerHero("OnWeaponClipEmpty", "OwnerTable")
    -- OnTouchdown -- TODO
    -- OnCollisionReaction
    -- OnAllegianceFlip
    -- OnObstacleCollision
    -- OnUnitCollision
    -- OnMovementReaction
end

function DamageHooks.wrap.OnHit(baseFun, args)
    -- Only one usage
    local fun = args[1]
    baseFun { function(triggerArgs)
        local attacker = triggerArgs.AttackerTable
        local victim = triggerArgs.TriggeredByTable

        local isAttackerPlayer = attacker and CoopPlayers.IsPlayerHero(attacker)
        local isVictimPlayer = CoopPlayers.IsPlayerHero(victim)

        -- Disable PvP
        if isAttackerPlayer and isVictimPlayer then
            return
        end

        if Config.Debug.P1GodMode and isVictimPlayer and victim == CoopPlayers.GetHero(1) then
            return
        end

        if Config.Debug.P2GodMode and isVictimPlayer and victim == CoopPlayers.GetHero(2) then
            return
        end

        if Config.Debug.OneHit then
            triggerArgs.DamageAmount = 10000
        end

        if isAttackerPlayer and victim then
            -- Save last attacker to run OnEffectApply with the right hero context
            victim.CoopLastAttacker = attacker
        end

        if isAttackerPlayer then
            HeroContext.RunWithHeroContext(attacker, fun, triggerArgs)
        elseif isVictimPlayer then
            HeroContext.RunWithHeroContext(victim, fun, triggerArgs)
        else
            fun(triggerArgs)
        end

        if isVictimPlayer then
            if victim == CoopPlayers.GetMainHero() then
                UpdateHealthUI()
            elseif victim == CoopPlayers.GetHero(2) then
                SecondPlayerUi.UpdateHealthUI()
            end
        end
    end }
end

function DamageHooks.wrap.OnProjectileDeath(_OnProjectileDeath, args)
    local originalHandler = args[1]

    _OnProjectileDeath { function(triggerArgs)
        local attacker = triggerArgs.AttackerTable
        local isAttackerPlayer = attacker and CoopPlayers.IsPlayerHero(attacker)
        local victim = triggerArgs.TriggeredByTable
        local isVictimPlayer = victim and CoopPlayers.IsPlayerHero(victim)

        if triggerArgs.name == "RangedWeapon" then
            -- This hack disables PvP for red crystals
            if isAttackerPlayer and isVictimPlayer then
                triggerArgs.TriggeredByTable = nil
            end
        end

        if isAttackerPlayer then
            HeroContext.RunWithHeroContext(attacker, originalHandler, triggerArgs)
        elseif isVictimPlayer then
            HeroContext.RunWithHeroContext(victim, originalHandler, triggerArgs)
        else
            originalHandler(triggerArgs)
        end
    end }
end

return DamageHooks
