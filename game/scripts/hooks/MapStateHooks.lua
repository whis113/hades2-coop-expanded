--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../logic/HeroContextProxyStore.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"

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
    -- Fixes dark Melinoë after dash
    --HeroContextProxyStore.Recreate(MapState, "LastBlinkTimeUnmodified")
    MapState.PlayerAlphaFlags = MapState.PlayerAlphaFlags or {}
    HeroContextProxyStore.Recreate(MapState, "PlayerAlphaFlags")
    MapState.HeroNotStopsProjectile = MapState.HeroNotStopsProjectile or {}
    HeroContextProxyStore.Recreate(MapState, "HeroNotStopsProjectile")

    -- Fixes wapons logic
    MapState.EquippedWeapons = MapState.EquippedWeapons or {}
    HeroContextProxyStore.Recreate(MapState, "EquippedWeapons")
    MapState.WeaponCharge = MapState.WeaponCharge or {}
    HeroContextProxyStore.Recreate(MapState, "WeaponCharge")
end

return MapStateHooks
