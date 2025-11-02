--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroEx
local HeroEx = ModRequire "logic/HeroEx.lua"
---@type CoopGame
local CoopGame = ModRequire "logic/CoopGame.lua"

---@type Events
local Events = ModRequire "logic/Events.lua"

local hooks = {}
local function AddHooks(path)
    local hook = ModRequire(path)
    if hook and hook ~= true and hook.InitHooks then
        table.insert(hooks, hook)
    end
end

AddHooks "logic/CoopCamera.lua"
AddHooks "logic/HeroContext.lua"
AddHooks "hooks/FreezeHooks.lua"
AddHooks "hooks/RunHooks.lua"
AddHooks "hooks/MenuHooks.lua"
AddHooks "hooks/SaveHooks.lua"
AddHooks "hooks/EnemyAiHooks.lua"
AddHooks "hooks/LootHooks.lua"
AddHooks "hooks/UIHooks.lua"
AddHooks "hooks/VulnerabilityHooks.lua"
AddHooks "hooks/ResourceLoadingHooks.lua"
AddHooks "logic/loot/LootInterface.lua"
AddHooks "hooks/MapStateHooks.lua"
AddHooks "hooks/PlayerVisibilityHooks.lua"
AddHooks "hooks/CameraZoomFactionHook.lua"

AddHooks "hooks/DamageHooks.lua"
AddHooks "hooks/UseHooks.lua"
AddHooks "hooks/ControlHooks.lua"
AddHooks "hooks/WeaponHooks.lua"
AddHooks "hooks/EffectHooks.lua"
AddHooks "hooks/AnaimationSwapHook.lua"

local hooksInited = false
local function TryInstalBasicHooks()
    if hooksInited then
        return
    end

    hooksInited = true
    Events.engine:trigger("hooksPreInicialized")

    HeroEx.Init()

    for _, hook in ipairs(hooks) do
        hook.InitHooks()
    end

    CoopGame.Init()

    Events.engine:trigger("hooksInicialized")
end

OnPreThingCreation
{
    TryInstalBasicHooks
}

OnAnyLoad {
    function(triggerArgs)
        Events.run:trigger("mapLoaded", triggerArgs.name)
    end
}

OnMenuOpened {
    "MainMenuScreen",
    function(triggerArgs)
        SetConfigOption { Name = "AllowControlHotSwap", Value = true }
    end
}
