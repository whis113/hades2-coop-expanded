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

local META_STORY_ROOMS = {
    I_PostBoss01 = true,
    I_DeathAreaRestored = true,
    I_ChronosFlashback01 = true,
    EndCredits01 = true,
    Q_PostBoss01 = true
}

---@return boolean
function RunEx.IsMetaStoryRoom(name)
    return META_STORY_ROOMS[name] or false
end

function RunEx.GetRoomName(room)
    if type(room) == "table" then
        return room.Name or room.ForceRoomName
    end

    return room
end

function RunEx.GetDoorTargetRoomName(door)
    if not door then
        return nil
    end

    return RunEx.GetRoomName(door.Room) or door.ForceRoomName or door.RoomName or door.Name
end

function RunEx.IsBossRoomName(name)
    return type(name) == "string" and name:match("^[A-Z]_Boss%d+") ~= nil
end

function RunEx.IsRestRoomName(name)
    return type(name) == "string" and name:match("^[A-Z]_PostBoss%d+") ~= nil
end

function RunEx.ShouldReviveDeadPlayersOnTransition(currentRoom, door)
    local currentRoomName = RunEx.GetRoomName(currentRoom)
    local nextRoomName = RunEx.GetDoorTargetRoomName(door)

    return RunEx.IsBossRoomName(currentRoomName) and RunEx.IsRestRoomName(nextRoomName)
end

function RunEx.GetCurrentRoom()
    return CurrentHubRoom or CurrentRun.CurrentRoom
end

function RunEx.RemoveRewardFromAllDefaultDoors()
    for _, door in pairs(MapState.OfferedExitDoors) do
        if door.IsDefaultDoor then
            RunEx.RemoveDoorReward(door)
        end
    end
end

---@private
---Clears an enemy's stale target wait and starts its native AI again.
---清理敌人指向失效目标的等待，并重新启动本体 AI。
local function RestartEnemyAI(enemy)
    killTaggedThreads(enemy.AIThreadName)
    killWaitUntilThreads(enemy.AINotifyName)
    Stop({ Id = enemy.ObjectId })
    StopAnimation({ DestinationId = enemy.ObjectId })

    enemy.TargetId = nil
    if enemy.AIStages ~= nil then
        thread(StagedAI, enemy, CurrentRun)
        return
    end

    local aiBehavior = enemy.AIBehavior
    if aiBehavior ~= nil then
        thread(SetAI, aiBehavior, enemy, CurrentRun)
    end
end

function RunEx.RefreshEnemyAI()
    for _, enemy in pairs(ActiveEnemies) do
        -- Normal enemies can restart freely to discard cached dead-player targets.
        -- 普通敌人可以直接重启，以清理缓存的死亡玩家目标。
        if not enemy.IsDead and not enemy.IsBoss then
            RestartEnemyAI(enemy)
        end
    end
end

---@return integer restarted
---@return integer skipped
function RunEx.RefreshBossAI()
    local restarted = 0
    local skipped = 0
    for _, enemy in pairs(ActiveEnemies) do
        if not enemy.IsDead and enemy.IsBoss then
            -- Non-staged bosses can be restarted safely. Staged bosses must keep their native
            -- coroutine because restarting it reapplies phase-one state after a player death.
            -- 非分阶段 Boss 可以安全重启；分阶段 Boss 必须保留本体协程，重启会在玩家死亡后重置第一阶段状态。
            if enemy.AIStages == nil then
                RestartEnemyAI(enemy)
                restarted = restarted + 1
            else
                skipped = skipped + 1
            end
        end
    end
    return restarted, skipped
end

return RunEx
