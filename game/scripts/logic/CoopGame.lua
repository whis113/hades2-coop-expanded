--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"
---@type CoopRun
local CoopRun = ModRequire "CoopRun.lua"
---@type Events
local Events = ModRequire "Events.lua"

---@class CoopGame
local CoopGame = {}

function CoopGame.Init()
    Events.run:once("mapLoaded", CoopPlayers.CoopInit)
    CoopRun.Init()
end

return CoopGame
