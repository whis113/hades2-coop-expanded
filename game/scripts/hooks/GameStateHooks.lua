--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type GameStateEx
local GameStateEx = ModRequire "../logic/GameStateEx.lua"

---@class GameStateHooks : SimpleHook
local GameStateHooks = SimpleHook.New()

-- Keep Arcana / MetaUpgradeState on the vanilla single-player GameState path.
-- Splitting this table can corrupt saved Arcana unlock/progression data.

function GameStateHooks.post.InitializeMetaUpgradeState()
    GameStateEx.RepairArcanaFullUnlockState("InitializeMetaUpgradeState")
end

return GameStateHooks
