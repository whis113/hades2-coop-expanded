--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

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
    local hadnler = HeroContextProxySpliterStore.GetOrCreate("MapState", MapState, {
        "LastBlinkTimeUnmodified",
        "PlayerAlphaFlags",
        "HeroNotStopsProjectile",
        "EquippedWeapons",
        "WeaponCharge",
        "ManaChargeIndicatorIds",
        "CastArmDisable",
        "ChargedManaWeapons",
        "ShowManaChargeIndicator",
        "ManaChargeIndicatorCost",
        "ManaChargeIndicatorData",
        "ManaChargeIndicatorIds",
        "FamiliarUnit",
    })

    for playerId = 1, CoopPlayers.GetPlayersCount() do
        local playerData = hadnler:GetPlayerData(playerId)
        playerData.EquippedWeapons = playerData.EquippedWeapons or {}
        playerData.HeroNotStopsProjectile = playerData.HeroNotStopsProjectile or {}
        playerData.ChargedManaWeapons = playerData.ChargedManaWeapons or {}
        playerData.ManaChargeIndicatorIds = playerData.ManaChargeIndicatorIds or {}
    end
end

---@private
function MapStateHooks.ApplySessionMapStateProxy()
    HeroContextProxySpliterStore.GetOrCreate("SessionMapState", SessionMapState, {
        "MagnetismMultiplier",
    })
end

function MapStateHooks.post.MapStateInit()
    HeroContextProxySpliterStore.Delete("MapState")
    MapStateHooks.ApplyMapStateProxy()
end

function MapStateHooks.post.SessionMapStateInit()
    HeroContextProxySpliterStore.Delete("SessionMapState")
    MapStateHooks.ApplySessionMapStateProxy()
end

return MapStateHooks
