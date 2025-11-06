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
    HookUtils.onPostFunction("MapStateInit", MapStateHooks.ApplyMapStateProxy)
    HookUtils.onPostFunction("SessionMapStateInit", MapStateHooks.ApplySessionMapStateProxy)
    if MapState then
        MapStateHooks.ApplyMapStateProxy()
    end
    if SessionMapState then
        MapStateHooks.ApplySessionMapStateProxy()
    end
end

---@private
function MapStateHooks.ApplyMapStateProxy()
    HeroContextProxySpliterStore.GetOrCreate("MapState", MapState, {
        "LastBlinkTimeUnmodified",
        "PlayerAlphaFlags",
        "HeroNotStopsProjectile",
        "EquippedWeapons",
        "WeaponCharge",
        "ManaChargeIndicatorIds",
        "CastArmDisable",
    })
end

---@private
function MapStateHooks.ApplySessionMapStateProxy()
    HeroContextProxySpliterStore.GetOrCreate("SessionMapState", SessionMapState, {
        "MagnetismMultiplier",
    })
end

return MapStateHooks
