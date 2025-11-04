--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"
---@type HeroContext
local HeroContext = ModRequire "HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"

---@class HeroContextProxySpliter
---@field keys string[]
---@field data any
---@field target table
local HeroContextProxySpliter = {}

---@private
HeroContextProxySpliter.__index = HeroContextProxySpliter

---@param target table
---@param keys string[]
function HeroContextProxySpliter.New(target, keys)
    local separatedData = {}

    ---@type HeroContextProxySpliter
    local handler = setmetatable({
            data = separatedData;
            target = target;
            keys = keys;
        },
        HeroContextProxySpliter
    )

    handler:CreateContextForAllPlayers()
    handler:RemoveKeysFromTarget()
    handler:HookTable()

    return handler
end

---@private
function HeroContextProxySpliter:HookTable()
    local separatedData = self.data
    local hashKeys = TableUtils.toHashmap(self.keys)

    local function getTableForCurrentHero()
        local hero = HeroContext.GetCurrentHeroContext()
        local playerId = CoopPlayers.GetPlayerByHero(hero) or 1
        return separatedData[playerId]
    end

    local mt = {
        __index = function(self, key)
            if hashKeys[key] then
                return getTableForCurrentHero()[key]
            else
                return rawget(self, key)
            end
        end,
        __newindex = function(self, key, value)
            if hashKeys[key] then
                getTableForCurrentHero()[key] = value
            else
                rawset(self, key, value)
            end
        end
    }

    setmetatable(self.target, mt)
end

---@param playerId number
function HeroContextProxySpliter:ExtractCurrentContextToPlayer(playerId)
    local extractTo = self.data[playerId]
    local from = self.target
    for _, key in pairs(self.keys) do
        extractTo[key] = from[key]
        from[key] = nil
    end
end

---@private
function HeroContextProxySpliter:CreateContextForAllPlayers()
    for playerId = 1, CoopPlayers.GetPlayersCount() do
        self.data[playerId] = {}
        self:CopyContextToPlayer(playerId)
    end
end

---@param playerId number
function HeroContextProxySpliter:CopyContextToPlayer(playerId)
    TableUtils.copyKeysDeep(self.target, self.data[playerId], self.keys)
end

---@param playerId number
function HeroContextProxySpliter:MovePlayerDataToTarget(playerId)
    TableUtils.copyKeysDeep(self.data[playerId], self.target, self.keys)
end

function HeroContextProxySpliter:RemoveKeysFromTarget()
    TableUtils.removeKeys(self.target, self.keys)
end

return HeroContextProxySpliter
