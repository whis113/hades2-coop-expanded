--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

-- Load menu and add gamemode button
--ModRequire "CoopMenu.lua"

-- Get current gamemode
-- local _, data = GetTempRuntimeData("Gamemode")
-- if data ~= "Coop" then
--     return
-- end

-- Disable the gamemode for the next run
--SetTempRuntimeData("Gamemode", nil)

-- Load gamemode hooks

SetTempRuntimeData("TN_Coop:control", {
    {
        Device = "Keyboard",
        ControllerId = 4,
    },
    {
        Device = "Gamepad",
        ControllerId = 0,
    },
})

if not CoopHasPlayer(2) then
    CoopCreatePlayer()
end

local gamemode = ModRequire "GamemodeInit.lua"
gamemode.Start()
