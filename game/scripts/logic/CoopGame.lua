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
---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"

---@class CoopGame
local CoopGame = {}

---@type ISaveHandler[]
CoopGame.SaveHandlers = {
    ModRequire "saveHandlers/HeroContextProxySaver.lua";
    ModRequire "saveHandlers/SinglePlayerHeroSaveHandler.lua",
}

function CoopGame.Init()
    Events.run:once("mapLoaded", CoopPlayers.CoopInit)
    Events.engine:on("presave", CoopGame.PreSave)
    Events.engine:on("postsave", CoopGame.PostSave)

    CoopGame.Load()
    CoopRun.Init()
end

---@private
function CoopGame.Load()
    TableUtils.callEvery(CoopGame.SaveHandlers, "Load")
end

---@private
function CoopGame.PreSave()
    TableUtils.callEvery(CoopGame.SaveHandlers, "PreSave")
end

---@private
function CoopGame.PostSave()
    TableUtils.callEveryReverse(CoopGame.SaveHandlers, "PostSave")
end

return CoopGame
