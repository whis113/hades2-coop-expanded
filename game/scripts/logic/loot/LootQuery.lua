--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../CoopPlayers.lua"

---@class LootQuery
local LootQuery = {}

function LootQuery.Reset()
    CurrentRun.CoopLootCounter = CurrentRun.CoopLootCounter or RandomInt(1, CoopPlayers.GetPlayersCount())
end

---@return number | nil
function LootQuery.UseNextHeroForLoot()
    local playersCount = CoopPlayers.GetPlayersCount()
    if playersCount <= 1 then
        return
    end

    local startPos = CurrentRun.CoopLootCounter
    local playerIndex = startPos + 1
    while true do
        if playerIndex > playersCount then
            playerIndex = 1
        end

        if playerIndex == startPos then
            return
        end

        local hero = CoopPlayers.GetHero(playerIndex)
        if not hero.IsDead then
            CurrentRun.CoopLootCounter = playerIndex
            return playerIndex
        end

        playerIndex = playerIndex + 1
    end
end

---@param playerId number
function LootQuery.MarkHeroForLoot(playerId)
    if playerId ~= nil then
        -- 首份奖励也必须推进游标，否则第二份可能再次选中同一位玩家。 / The first reward must advance the cursor too, otherwise the second reward can select the same player again.
        CurrentRun.CoopLootCounter = playerId
    end
end

return LootQuery
