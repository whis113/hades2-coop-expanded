--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContextProxySpliter
local HeroContextProxySpliter = ModRequire "HeroContextProxySpliter.lua"

---@class HeroContextProxySpliterStore
local HeroContextProxySpliterStore = {}

---@type table<string, HeroContextProxySpliter>
local store = {}

---@param name string
---@param instance HeroContextProxySpliter
function HeroContextProxySpliterStore.Set(name, instance)
    store[name] = instance
end

---@param name string
---@return HeroContextProxySpliter | nil
function HeroContextProxySpliterStore.Get(name)
    return store[name]
end

---@param name string
---@param target table
---@param keys string[]
---@return HeroContextProxySpliter
function HeroContextProxySpliterStore.GetOrCreate(name, target, keys)
    local proxy = store[name]
    if proxy then
        return proxy
    else
        proxy = HeroContextProxySpliter.New(target, keys)
        store[name] = proxy
        return proxy
    end
end

---@param name string
---@param target table
---@param keys string[]
---@return HeroContextProxySpliter
function HeroContextProxySpliterStore.Recreate(name, target, keys)
    local proxy = HeroContextProxySpliter.New(target, keys)
    store[name] = proxy
    return proxy
end

function HeroContextProxySpliterStore.Delete(name)
    store[name] = nil
end

---@return fun(store: table<string, HeroContextProxySpliter>, index?: string): string, HeroContextProxySpliter
---@return table<string, HeroContextProxySpliter>
function HeroContextProxySpliterStore.Iterator()
    return pairs(store)
end

return HeroContextProxySpliterStore
