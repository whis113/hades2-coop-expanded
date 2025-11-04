--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"

---@class MapStateHooks
local MapStateHooks = {}

---@public
function MapStateHooks.InitHooks()
    HookUtils.onPostFunction("MapStateInit", MapStateHooks.ApplyProxies)
    if MapState then
        MapStateHooks.ApplyProxies()
    end
end

---@private
function MapStateHooks.ApplyProxies()
    HeroContextProxySpliterStore.GetOrCreate("MapState", MapState, {
        "LastBlinkTimeUnmodified",
        "PlayerAlphaFlags",
        "HeroNotStopsProjectile",
        "EquippedWeapons",
        "WeaponCharge",
        "ManaChargeIndicatorIds",
    })
end

return MapStateHooks
