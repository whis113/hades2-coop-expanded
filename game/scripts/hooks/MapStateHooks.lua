--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../HeroContextProxyStore.lua"

---@type HookUtils
local HookUtils = ModRequire "../HookUtils.lua"

---@class MapStateHooks
local MapStateHooks = {}

function MapStateHooks.InitHooks()
    HookUtils.onPostFunctionOnce("MapStateInit", MapStateHooks.ApplyProxies)
    if MapState then
        MapStateHooks.ApplyProxies()
    end
end

function MapStateHooks.ApplyProxies()
    -- Fixes dark Melinoë after dash
    --HeroContextProxyStore.Recreate(MapState, "LastBlinkTimeUnmodified")
    MapState.PlayerAlphaFlags = MapState.PlayerAlphaFlags or {}
    HeroContextProxyStore.Recreate(MapState, "PlayerAlphaFlags")
    MapState.HeroNotStopsProjectile = MapState.HeroNotStopsProjectile or {}
    HeroContextProxyStore.Recreate(MapState, "HeroNotStopsProjectile")
end

return MapStateHooks
