--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class HookStorage
local HookStorage = {}

---@type SimpleHook[]
local hooks = {}

---@param path string
function HookStorage.Add(path)
    local hook = ModRequire("../" .. path)
    assert(hook, "expected table in " .. path)
    table.insert(hooks, hook)
end

function HookStorage.EngineInit()
    for _, hook in ipairs(hooks) do
        hook:ApplyEngineHooks()
    end
end

function HookStorage.GameInit()
    for _, hook in ipairs(hooks) do
        hook:ApplyGameHooks()
    end
end

return HookStorage
