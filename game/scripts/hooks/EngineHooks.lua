--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

local EngineHooks = SimpleHook.New()

function EngineHooks.post.draw()
    Events.engine:trigger("tick")
end

return EngineHooks
