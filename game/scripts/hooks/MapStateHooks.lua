--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"

---@class MapStateHooks  : SimpleHook
local MapStateHooks = SimpleHook.New()

---@public
function MapStateHooks:InitEngineHooks()
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

MapStateHooks.post.MapStateInit = MapStateHooks.ApplyMapStateProxy
MapStateHooks.post.SessionMapStateInit = MapStateHooks.ApplySessionMapStateProxy

return MapStateHooks
