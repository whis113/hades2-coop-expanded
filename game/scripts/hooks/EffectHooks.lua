---@type HeroContextWrapper
local HeroContextWrapper = ModRequire "../logic/HeroContextWrapper.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

local hook = SimpleHook.New()

function hook:InitEngineHooks()
    HeroContextWrapper.WrapTriggerHero("OnEffectCleared", "Victim")
    HeroContextWrapper.WrapTriggerHero("OnEffectStackDecrease", "Victim")
    HeroContextWrapper.WrapTriggerHero("OnEffectDelayedKnockbackForce", "Victim")
end

function hook.wrap.OnEffectApply(baseFunc, args)
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
end

return hook
