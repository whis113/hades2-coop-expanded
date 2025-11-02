--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class RunEx
local RunEx = {}

---@return boolean
function RunEx.IsRunEnded()
    -- The game sets RunResult when the run ends
    -- So we can use this value to check if the run was finished
    return CurrentRun.RunResult and true
end

---@return boolean
function RunEx.WasTheFirstRunStarted()
    return not GameState or (not CurrentRun and IsEmpty(GameState.RunHistory))
end

---@return boolean
function RunEx.IsFirstRun(run)
    return not GameState or IsEmpty(GameState.RunHistory)
end

---@return boolean
function RunEx.IsShopRoomName(name)
    error("Not implementated")
    return false
end

---@return boolean
function RunEx.IsStoryRoomName(name)
    error("Not implementated")
    return false
end

function RunEx.IsDoorSpecial(door)
    error("Not implementated")
    return false
end

---@return boolean
function RunEx.IsFinalBossDoor(door)
    error("Not implementated")
    return door.ForceRoomName == "D_Boss01"
end

---@return boolean
function RunEx.IsDefaultDoorsLeadToRunProgress()
    error("Not implementated")
    return false
end

function RunEx.RemoveDoorReward(door)
    error("Not implementated")
    return false
end

function RunEx.IsHubRoom(name)
    return name == "Hub_Main" or name == "Hub_PreRun"
end

function RunEx.RemoveRewardFromAllDefaultDoors()
    for _, door in pairs(MapState.OfferedExitDoors) do
        if door.IsDefaultDoor then
            RunEx.RemoveDoorReward(door)
        end
    end
end

return RunEx
