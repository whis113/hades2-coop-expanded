--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"
---@type HeroContextWrapper
local HeroContextWrapper = ModRequire "../logic/HeroContextWrapper.lua"

---@class WeaponLogicHooksLob
local WeaponLogicHooksLob = {}

local LobAmmoPackToHero = {}

function WeaponLogicHooksLob.InitHooks()
    HookUtils.wrap("RecordWeaponCharge", WeaponLogicHooksLob.RecordWeaponChargeWrapHook)
    HookUtils.onPostFunction("LeaveRoom", function()
        -- TODO optimize to prevent memory leaks
        LobAmmoPackToHero = {}
    end)
end

function WeaponLogicHooksLob.RecordWeaponChargeWrapHook(baseFun, unit, weaponData, args, triggerArgs)
    if weaponData.MagnetismMultiplier then
        local currentHero = CurrentRun.Hero
        HookUtils.wrapOnce("GetIdsByType", function(GetIdsByTypeOrig, args)
            return TableUtils.filter(GetIdsByTypeOrig(args), function(value)
                return LobAmmoPackToHero[value] == currentHero
            end)
        end)
    end
    baseFun(unit, weaponData, args, triggerArgs)
end

HookUtils.wrap("SpawnObstacle", function(baseFun, args)
    if args.Name == "LobAmmoPack" then
        -- We will use this in the c++ hook
        -- Index starts from 0 here
        local hero = CurrentRun.Hero
        args.AttachedTable.UsedByHero = hero
        args.AttachedTable.PlayerIndexC = (CoopPlayers.GetPlayerByHero(hero) or 1) - 1

        -- store id for another hooks
        local id = baseFun(args)
        LobAmmoPackToHero[id] = hero

        return id
    else
        return baseFun(args)
    end
end)

HeroContextWrapper.WrapTriggerHero("OnBlinkFinished", "OwnerTable")

return WeaponLogicHooksLob
