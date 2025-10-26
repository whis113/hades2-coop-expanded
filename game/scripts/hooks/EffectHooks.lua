---@type HeroContextWrapper
local HeroContextWrapper = ModRequire "../logic/HeroContextWrapper.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

HookUtils.wrap("OnEffectApply", function(baseFunc, args)
    local originalHandler = args[1]

    baseFunc {
        function(triggerArgs)
            local target = triggerArgs.Victim
            if CoopPlayers.IsPlayerHero(target) then
                HeroContext.RunWithHeroContext(target, originalHandler, triggerArgs)
            elseif target and target.CoopLastAttacker then
                HeroContext.RunWithHeroContext(target.CoopLastAttacker, originalHandler, triggerArgs)
            else
                originalHandler(triggerArgs)
            end
        end
    }
end)

HeroContextWrapper.WrapTriggerHero("OnEffectCleared", "Victim")
HeroContextWrapper.WrapTriggerHero("OnEffectStackDecrease", "Victim")
HeroContextWrapper.WrapTriggerHero("OnEffectDelayedKnockbackForce", "Victim")
