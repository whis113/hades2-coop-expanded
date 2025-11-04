--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

---@class SaveHooks
local SaveHooks = {}

function SaveHooks.InitHooks()
    HookUtils.wrap("Save", SaveHooks.SaveWrapper)
end

---@private
function SaveHooks.SaveWrapper(baseFun)
    Events.engine:trigger("presave")
    baseFun()
    Events.engine:trigger("postsave")
end

return SaveHooks
