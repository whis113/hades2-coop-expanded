--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

---@class ThreadSplitHooks : SimpleHook
local ThreadSplitHooks = SimpleHook.New()

local THREAD_TO_SPLIT = {
    ManaRegenStartup = true;
    ManaRegenInterval = true;
    IdleManaRegen = true;
}

---@param name string
local function GetThreadRename(name)
    if name and THREAD_TO_SPLIT[name] then
        name = name .. "CoopPlayers" .. (CoopPlayers.GetCurrentPlayerId() or 1)
    end

    return name
end

function ThreadSplitHooks.wrap.HasThread(HasThread, name)
    return HasThread(GetThreadRename(name))
end

function ThreadSplitHooks.wrap.waitUnmodified(waitUnmodified, duration, tag, persist)
    return waitUnmodified(duration, GetThreadRename(tag), persist)
end

function ThreadSplitHooks.wrap.SetThreadWait(SetThreadWait, tag, duration)
    return SetThreadWait(GetThreadRename(tag), duration)
end

function ThreadSplitHooks.wrap.killTaggedThreads(killTaggedThreads, tag)
    return killTaggedThreads(GetThreadRename(tag))
end

function ThreadSplitHooks.wrap.wait(wait, duration, tag, persist)
    return wait(duration, GetThreadRename(tag), persist)
end

return ThreadSplitHooks
