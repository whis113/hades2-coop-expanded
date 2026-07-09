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

-- This class splits specific table keys for different heroes
--
-- Example:
-- HeroContextProxySpliter.New(MapState, { "lastCastTime" })
-- In this case MapState.lastCastTime will return diffeent values for both players
-- But MapState.globalTimer is still linked with one value

---@class HeroContextProxySpliter
---@field keys string[]
---@field data any
---@field target table
---@field previousMetatable table | nil
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
            previousMetatable = getmetatable(target);
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
    local previousMetatable = self.previousMetatable

    local function getTableForCurrentHero()
        local hero = HeroContext.GetCurrentHeroContext()
        local playerId = CoopPlayers.GetPlayerByHero(hero) or 1
        return separatedData[playerId]
    end

    local mt = {
        __index = function(self, key)
            if hashKeys[key] then
                return getTableForCurrentHero()[key]
            end
            if previousMetatable and previousMetatable.__index then
                if type(previousMetatable.__index) == "function" then
                    return previousMetatable.__index(self, key)
                end
                return previousMetatable.__index[key]
            end
            return rawget(self, key)
        end,
        __newindex = function(self, key, value)
            if hashKeys[key] then
                getTableForCurrentHero()[key] = value
                return
            end
            if previousMetatable and previousMetatable.__newindex then
                if type(previousMetatable.__newindex) == "function" then
                    previousMetatable.__newindex(self, key, value)
                else
                    previousMetatable.__newindex[key] = value
                end
                return
            end
            rawset(self, key, value)
        end,
        -- For debug only
        handler = self,
    }

    setmetatable(self.target, mt)
end

function HeroContextProxySpliter:UnhookTable()
    local mt = getmetatable(self.target)
    if mt and mt.handler == self then
        setmetatable(self.target, self.previousMetatable)
    end
end

---@param playerId number
function HeroContextProxySpliter:ExtractCurrentContextToPlayer(playerId)
    TableUtils.moveKeys(self.target, self.data[playerId], self.keys)
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
    TableUtils.copyKeysDeep(self.data[playerId], self.target, self.keys)
end

---@param playerId number
function HeroContextProxySpliter:MovePlayerDataToTarget(playerId)
    TableUtils.copyKeysDeepRaw(self.data[playerId], self.target, self.keys)
end

function HeroContextProxySpliter:RemoveKeysFromTarget()
    TableUtils.removeKeysRaw(self.target, self.keys)
end

---@param playerId number
function HeroContextProxySpliter:GetPlayerData(playerId)
    return self.data[playerId]
end

return HeroContextProxySpliter
