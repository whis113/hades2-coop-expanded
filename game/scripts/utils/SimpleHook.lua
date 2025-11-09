--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HookUtils
local HookUtils = ModRequire "HookUtils.lua"
---@type TableUtils
local TableUtils = ModRequire "TableUtils.lua"

---@class SimpleHook
---@field pre table<string, fun(...)>
---@field wrap table<string, fun(baseFun: function, ...): unknown?>
---@field post table<string, fun(...)>
---@field replace table<string, fun(...)>
local SimpleHook = {}

---@private
SimpleHook.__index = SimpleHook

---@return SimpleHook
function SimpleHook.New()
    local self = {
        pre = {};
        wrap = {};
        post = {};
        replace = {},
    }

    return setmetatable(self, SimpleHook)
end

---@private
function SimpleHook:ApplyHooks()

    local function apply(functions, hookType)
        local applied = {}
        for funName, hook in pairs(functions) do
            if _G[funName] then
                HookUtils[hookType](funName, hook)
                table.insert(applied, funName)
            end
        end

        TableUtils.removeKeys(functions, applied)
    end

    apply(self.pre, "onPreFunction")
    apply(self.wrap, "wrap")
    apply(self.post, "onPostFunction")
    apply(self.replace, "replace")
end

---@private
function SimpleHook:CheckMissingFunctions()
    local function check(t)
        for funName in pairs(t) do
            error("The function " .. tostring(funName) .. " wasn't hooked")
        end
    end

    check(self.pre)
    check(self.wrap)
    check(self.post)
    check(self.replace)
end

function SimpleHook:ApplyEngineHooks()
    self:ApplyHooks()
    self:InitEngineHooks()
end

-- Overload this function
function SimpleHook:InitEngineHooks()

end

function SimpleHook:ApplyGameHooks()
    self:ApplyHooks()
    self:CheckMissingFunctions()
    self:InitGameHooks()
end

-- Overload this function
function SimpleHook:InitGameHooks()

end

return SimpleHook
