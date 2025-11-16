--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../HeroContextProxySpliterStore.lua"

---@class HeroContextProxySpliterSaver : ISaveHandler
local HeroContextProxySpliterSaver = {}

function HeroContextProxySpliterSaver.PreSave()
    for _, instance in HeroContextProxySpliterStore.Iterator() do
        instance:MovePlayerDataToTarget(1)
    end
end

function HeroContextProxySpliterSaver.PostSave()
    for _, instance in HeroContextProxySpliterStore.Iterator() do
        instance:RemoveKeysFromTarget()
    end
end

function HeroContextProxySpliterSaver.Load()

end

return HeroContextProxySpliterSaver
