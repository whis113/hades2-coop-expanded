--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

---@class ThreadSplitHooks : SimpleHook
local ThreadSplitHooks = SimpleHook.New()

local THREAD_TO_SPLIT = {
    -- Mana regen
    ManaRegenStartup = true;
    ManaRegenInterval = true;
    IdleManaRegen = true;
    -- TODO check
    WeaponCastArmIndicatorFire = true;

    WeaponStaffSwing5IndicatorFire = true,
    WeaponStaffBallIndicatorFire = true,

    WeaponDagger5IndicatorFire = true,
    WeaponDaggerThrowIndicatorFire = true,

    WeaponTorchIndicatorFire = true;
    WeaponTorchSpecialIndicatorFire = true;

    WeaponAxeSpinIndicatorFire = true,
    WeaponAxeSpecialSwingIndicatorFire = true,

    WeaponLobIndicatorFire = true;
    WeaponLobSpecialIndicatorFire = true;

    WeaponSuitChargedIndicatorFire = true,
    WeaponSuitRangedIndicatorFire = true,

    -- weapon charge
    ChargeManaWeaponStart = true;
    ManaChargeComplete = true;
}

---@param name string
local function GetThreadRename(name)
    if name and THREAD_TO_SPLIT[name] then
        name = name .. "CoopPlayers" .. (CoopPlayers.GetCurrentPlayerId() or 1)
    end

    return name
end

function ThreadSplitHooks:InitGameHooks()
    setmetatable(_eventTimeoutRecord, {
        __index = function(self, key)
            return rawget(self, GetThreadRename(key))
        end;
        __newindex = function(self, key, value)
            rawset(self, GetThreadRename(key), value)
        end;
    })
end

function ThreadSplitHooks.wrap.HasThread(HasThread, name)
    return HasThread(GetThreadRename(name))
end

function ThreadSplitHooks.wrap.waitUnmodified(waitUnmodified, duration, tag, persist)
    return waitUnmodified(duration, GetThreadRename(tag), persist)
end

function ThreadSplitHooks.wrap.SetThreadWait(SetThreadWait, tag, duration)
    return SetThreadWait(GetThreadRename(tag), duration)
end

function ThreadSplitHooks.wrap.killTaggedThreads(killTaggedThreads, tag)
    return killTaggedThreads(GetThreadRename(tag))
end

function ThreadSplitHooks.wrap.wait(wait, duration, tag, persist)
    return wait(duration, GetThreadRename(tag), persist)
end

function ThreadSplitHooks.wrap.HasWaitUntil(HasWaitUntil, tag)
    return HasWaitUntil(GetThreadRename(tag))
end

function ThreadSplitHooks.wrap.waitUntil(waitUntil, event, tag, persist)
    return waitUntil(GetThreadRename(event), tag, persist)
end

function ThreadSplitHooks.wrap.notifyExistingWaiters(notifyExistingWaiters, event, wasTimeout)
    return notifyExistingWaiters(GetThreadRename(event), wasTimeout)
end

function ThreadSplitHooks.wrap.NotifyOnWeaponCharge(NotifyOnWeaponCharge, args)
    args.Notify = GetThreadRename(args.Notify)
    NotifyOnWeaponCharge(args)
end

return ThreadSplitHooks
