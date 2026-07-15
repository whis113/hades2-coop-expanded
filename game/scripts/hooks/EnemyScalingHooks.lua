--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopModConfig
local Config = ModRequire "../config.lua"

local EnemyScalingHooks = SimpleHook.New()

local function ScaleHealth(value, multiplier)
    if value == nil then
        return nil
    end

    return math.max(1, math.floor(value * multiplier + 0.5))
end

local function IsHostileEnemy(unit)
    return unit ~= nil
        and unit.AddToEnemyTeam == true
        and unit.IsNeutral ~= true
        and unit.Charmed ~= true
        and unit.AlwaysTraitor ~= true
        and unit.MaxHealth ~= nil
        and unit.MaxHealth > 0
end

function EnemyScalingHooks.post.SetupUnit(unit)
    local scaling = Config.EnemyScaling
    if scaling == nil or scaling.Enabled ~= true or unit == nil then
        return
    end

    local multiplier = tonumber(scaling.HealthMultiplier) or 1
    if multiplier <= 0 or multiplier == 1 or unit.CoopEnemyHealthScaled or not IsHostileEnemy(unit) then
        return
    end

    -- SetupUnit has already applied native Elite and Shrine modifiers at this point.
    -- 此时 SetupUnit 已完成原版精英和誓约修正。
    local nativeMaxHealth = unit.MaxHealth
    unit.MaxHealth = ScaleHealth(unit.MaxHealth, multiplier)
    unit.Health = ScaleHealth(unit.Health, multiplier)

    -- Keep buffered shields proportional to the visible health pool.
    -- 让护盾缓冲生命与可见生命池保持相同比例。
    unit.HealthBuffer = ScaleHealth(unit.HealthBuffer, multiplier)
    unit.MaxHealthBuffer = ScaleHealth(unit.MaxHealthBuffer, multiplier)
    unit.CoopEnemyHealthScaled = true

    if Config.Debug.EnemyScalingTrace and CoopAppendTraceLog then
        CoopAppendTraceLog(string.format(
            "[CoopEnemyScale] name=%s id=%s nativeMax=%s scaledMax=%s multiplier=%.2f",
            tostring(unit.Name),
            tostring(unit.ObjectId),
            tostring(nativeMaxHealth),
            tostring(unit.MaxHealth),
            multiplier
        ))
    end
end

return EnemyScalingHooks
