--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type ILootDelivery
local LootDelivery = ModRequire "../logic/loot/LootInterface.lua"

local _OnUsed = OnUsed
OnUsed = function(args)
    if type(args[1]) == "function" then
        _OnUsed { function(triggerArgs)
            local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
            local mainHero = HeroContext.GetDefaultHero()

            local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
            if functionName == "UseEscapeDoor" and hero ~= mainHero then
                -- Pact door
                -- Disable control for a second player
                -- A second player in context resets weapon choice for the first player
                return;
            else
                HeroContext.RunWithHeroContext(
                    CoopPlayers.GetHeroByUnit(triggerArgs.UserId),
                    args[1],
                    triggerArgs
                )
            end
        end
        }
    elseif args[1] == "ConsumableItems" then
        _OnUsed {
            args[1],
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local item = triggerArgs.AttachedTable

                if not LootDelivery.CanUseHeroLoot(item, hero) then
                    return
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[2],
                    triggerArgs
                )
            end
        }
    elseif args[1] == "Loot"  then
        _OnUsed({
            args[1],
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                if not LootDelivery.CanUseHeroLoot(triggerArgs.AttachedTable, hero) then
                    return
                end

                -- Regenerate traits in loot
                -- Pregenerated loot can contains unsupported loot
                -- for a second hero
                triggerArgs.AttachedTable.UpgradeOptions = nil

                HeroContext.RunWithHeroContext(
                    hero,
                    args[2],
                    triggerArgs
                )
            end
        })
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
