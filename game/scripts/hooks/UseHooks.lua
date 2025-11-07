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
---@type Events
local Events = ModRequire "../logic/Events.lua"

local InteractHooks = {}

function InteractHooks.InitHooks()
    HookUtils.onPostFunction("UseConsumableItem", InteractHooks.UseConsumableItemPostHook)
end

local _OnUsed = OnUsed
OnUsed = function(args)
    if type(args[1]) == "function" then
        _OnUsed { function(triggerArgs)
            local item = triggerArgs.TriggeredByTable
            if item == nil then
                return
            end

            local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)

            if item.UsedByHero and item.UsedByHero ~= hero then
                -- Don't collect LobAmmoPack for by wrong player
                return
            end

            local mainHero = HeroContext.GetDefaultHero()

            local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
            if functionName == "UseEscapeDoor" and hero ~= mainHero then
                -- Pact door
                -- Disable control for a second player
                -- A second player in context resets weapon choice for the first player
                return;
            else
                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        end
        }
    else
        _OnUsed({
            args[1],
            function(triggerArgs)
                HeroContext.RunWithHeroContext(
                    CoopPlayers.GetHeroByUnit(triggerArgs.UserId),
                    args[2],
                    triggerArgs
                )
            end
        })
    end
end

local _OnActiveUseTarget = OnActiveUseTarget
OnActiveUseTarget = function(args)
    if type(args[1]) == "function" then
        _OnActiveUseTarget{
            function (triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        _OnActiveUseTarget(args)
    end
end

local _OnActiveUseTargetLost = OnActiveUseTargetLost
OnActiveUseTargetLost = function(args)
    if type(args[1]) == "function" then
        _OnActiveUseTargetLost {
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        _OnActiveUseTargetLost(args)
    end
end

function InteractHooks.UseConsumableItemPostHook(consumableItem, args, user)
    if consumableItem.AddAmmo then
        Events.game:trigger("comsumeAmmoItem", consumableItem)
    end
end

return InteractHooks
