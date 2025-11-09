--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"

---@class FreezeHooks : SimpleHook
local FreezeHooks = SimpleHook.New()

function FreezeHooks.wrap.FreezePlayerUnit(_FreezePlayerUnit, ...)
    for _, hero in CoopPlayers.PlayersIterator() do
        HeroContext.RunWithHeroContext(hero, _FreezePlayerUnit, ...)
    end
end

function FreezeHooks.wrap.UnfreezePlayerUnit(_UnfreezePlayerUnit, ...)
    for _, hero in CoopPlayers.PlayersIterator() do
        HeroContext.RunWithHeroContext(hero, _UnfreezePlayerUnit, ...)
    end
end

return FreezeHooks
