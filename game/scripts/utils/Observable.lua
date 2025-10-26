--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class HandlerData
---@field fun function
---@field once boolean

---@class Observable<AllowedEvents> : { on: fun(self: self, eventName: AllowedEvents, handler: function), once: fun(self: self, eventName: AllowedEvents, handler: function), trigger: fun(self: self,  eventName: AllowedEvents, ...) }
---@field handlers table<string, HandlerData[]>
local Observable = {}

---@private
Observable.__index = Observable

---@return Observable
function Observable.new()
    return setmetatable({
        handlers = {}

    }, Observable)
end

---@param eventName string
---@param fun function
function Observable:on(eventName, fun)
    self:addHandler(eventName, {
        fun = fun,
        once = false
    })
end

---@param eventName string
---@vararg any
function Observable:trigger(eventName, ...)
    local handlers = self.handlers[eventName]
    if not handlers then
        return
    end

    for _, handler in ipairs(handlers) do
        handler(...)
    end
end

---@param eventName string
---@param fun function
function Observable:once(eventName, fun)
    self:addHandler(eventName, {
        fun = fun,
        once = true
    })
end

---@private
---@param eventName string
---@param handler HandlerData
function Observable:addHandler(eventName, handler)
    local handlers = self.handlers[eventName]
    if handlers then
        table.insert(handlers, handler)
    else
        handlers = { handler }
        self.handlers[eventName] = handlers
    end
end

return Observable
