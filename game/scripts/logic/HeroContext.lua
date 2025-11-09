--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type Events
local Events = ModRequire "Events.lua"
---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"

---@class HeroContext
local HeroContext = {}

local CorontinueToHero = setmetatable({}, { __mode ="k" })

local defaultHero

local RunMT = {
    __index = function(self, key)
        if key == "Hero" then
            return HeroContext.GetCurrentHeroContext()
        end

        return rawget(self, key)
    end;
}

function HeroContext.InitHooks()
    local _thread = thread
    thread = function(fun, ...)
        local heroContext = CorontinueToHero[coroutine.running()]
        if heroContext then
            _thread(function(...)
                CorontinueToHero[coroutine.running()] = heroContext
                fun(...)
            end, ...)
        else
            _thread(fun, ...)
        end
    end

    local coroutine_yield = coroutine.yield
    ---@diagnostic disable-next-line: duplicate-set-field
    coroutine.yield = function(params)
        if params == "task done" then
            CorontinueToHero[coroutine.running()] = nil
        end
        return coroutine_yield(params)
    end

    Events.run:on("newRunStarted", HeroContext.InitRunHook)
    if CurrentRun then
        HeroContext.InitRunHook()
    end
end

function HeroContext.InitRunHook()
    TableUtils.clean(CorontinueToHero)
    local hero = rawget(CurrentRun, "Hero")
    if not hero then
        error("Current run has no hero")
    end

    defaultHero = hero
    CurrentRun.Hero = nil
    setmetatable(CurrentRun, RunMT)
end

function HeroContext.GetCurrentHeroContext()
    local thread, isMain = coroutine.running()
    if not isMain then
        return CorontinueToHero[thread] or defaultHero
    end

    return defaultHero
end

function HeroContext.IsHeroContextExplicit()
    local thread, isMain = coroutine.running()
    if not isMain then
        return CorontinueToHero[thread] and true
    end
    return false
end

function HeroContext.SetDefaultHero(hero)
    defaultHero = hero
end

function HeroContext.GetDefaultHero()
    return defaultHero
end

---@param hero table Hero info
---@param fun function
---@param ... unknown params
function HeroContext.RunWithHeroContext(hero, fun, ...)
    thread(function(...)
        CorontinueToHero[coroutine.running()] = hero
        fun(...)
    end, ...)
end

---@param hero table Hero info
---@param fun function
---@param ... unknown params
---@return ...
function HeroContext.RunWithHeroContextReturn(hero, fun, ...)
    local out = {}
    HeroContext.RunWithHeroContext(hero, function(...)
        out = { fun(...) }
    end, ...)

    return table.unpack(out)
end

local awaitableThreadId = 0

---@param hero table Hero info
---@param fun function
---@param ... unknown params
function HeroContext.RunWithHeroContextAwait(hero, fun, ...)
    awaitableThreadId = awaitableThreadId + 1
    local notifyName = "RunWithHeroContextAwait" .. awaitableThreadId
    local done = false

    thread(function(...)
        CorontinueToHero[coroutine.running()] = hero
        fun(...)
        notifyExistingWaiters(notifyName)
        done = true
    end, ...)

    if not done then
        waitUntil(notifyName)
    end
end

return HeroContext
