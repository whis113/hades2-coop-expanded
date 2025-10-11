--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HookUtils
local HookUtils = ModRequire "../HookUtils.lua"
---@type HeroContext
local HeroContext = ModRequire "../HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../CoopPlayers.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "../PlayerVisibilityHelper.lua"

---@class PlayerVisibilityHooks
local PlayerVisibilityHooks = {}

function PlayerVisibilityHooks.InitHooks()
    HookUtils.onPostFunction("SetPlayerUnDarkside", PlayerVisibilityHooks.SetPlayerUnDarksidePostHook)
end

---@private
function PlayerVisibilityHooks.SetPlayerUnDarksidePostHook()
    if IsEmpty(SessionMapState.DarkSide) then
        local hero = HeroContext.GetCurrentHeroContext()
        PlayerVisibilityHelper.TriggerOutline(CoopPlayers.GetPlayerByHero(hero), hero.ObjectId)
    end
end

return PlayerVisibilityHooks
