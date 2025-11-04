--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../HeroContextProxyStore.lua"

---@class HeroContextProxySaver : ISaveHandler
local HeroContextProxySaver = {}

function HeroContextProxySaver.PreSave()
    for _, instance in HeroContextProxyStore.Iterator() do
        instance:MovePlayerDataToProxy(1)
    end
end

function HeroContextProxySaver.PostSave()
    for _, instance in HeroContextProxyStore.Iterator() do
        instance:CleanProxyTable()
    end
end

function HeroContextProxySaver.Load()

end

return HeroContextProxySaver
