--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

-- Load menu and add gamemode button
ModRequire "mainmenu/CoopMenu.lua"

-- Get current gamemode
local _, data = GetTempRuntimeData("Gamemode")
if data ~= "Coop" then
    return
end

-- Disable the gamemode for the next run
SetTempRuntimeData("Gamemode", nil)

-- Load gamemode hooks

if not CoopHasPlayer(2) then
    CoopCreatePlayer()
end

(ModRequire "GamemodeInit.lua").Start()
