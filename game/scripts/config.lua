--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class CoopModConfig
local Config = {
    -- Choose loot delivery type here
    -- Possible values: "Shared"
    --
    -- Shared - rooms generate one reward. Only one player can pick it up.
    -- The game has a query that select a player context for a reward.
    -- E.g. Player 1 boon room, meta progress room, Player 2 boon room, Player 1 boon room...
    LootDelivery = "Shared",
    -- 普通战斗房双固定奖励开关。
    -- Enables the second fixed reward in normal combat rooms.
    NormalRoomDoubleRewards = true,
    -- 开局免费 boon 双发开关。
    -- Enables a second copy of the free starting boon.
    StartingBoonDoubleRewards = true,
    -- 扩展 Elite、无 Encounter 关键奖励、Chaos 和事件房的双奖励。 / Enables expanded double rewards for Elite, encounterless, Chaos, and event rooms.
    ExpandedRoomDoubleRewards = true,
    EnemyScaling = {
        -- Apply after native enemy, Elite, and Shrine health calculations.
        -- 在原版敌人、精英和誓约生命值计算完成后应用。
        Enabled = true,
        -- Default co-op balance: all hostile enemy health is multiplied by 1.5.
        -- 默认双人平衡：所有敌对单位生命值乘以 1.5。
        HealthMultiplier = 1.5,
    },
    Player1HasOutline = true;
    Player1Outline = {
        R = 0,
        G = 0,
        B = 200,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    Player2HasOutline = true,
    Player2Outline = {
        R = 0,
        G = 200,
        B = 0,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    TextAbovePlayersEnabled = false;
    TextAbovePlayersParams = {
        -- CreateTextBox params
        OffsetX = 0,
        OffsetY = -150,
        FontSize = 28,
        Color = { 255, 255, 255, 255 },
        ShadowColor = { 0, 0, 0, 240 },
        ShadowOffset = { 0, 2 },
        ShadowBlur = 0,
        OutlineThickness = 3,
        OutlineColor = { 0, 0, 0, 1 },
        Font = "LatoMedium",
        Justification = "Center"
    },
    Debug = {
        OneHit = false,
        P1GodMode = false,
        P2GodMode = false,
        SoftlockTrace = true,
        -- 实时显示双人运行状态；测试完成后可改为 false。 / Shows live co-op state; set false after testing.
        RuntimeMonitor = false,
        -- 面板刷新间隔（秒）。 / Monitor refresh interval in seconds.
        RuntimeMonitorInterval = 0.25,
        -- Log native and scaled enemy health when validating balance changes.
        -- 验证平衡改动时记录原版与倍率后的敌人生命值。
        EnemyScalingTrace = false,
        ArcanaFullUnlockRepair = false,
        ArcanaMaxLevelRepair = false,
        -- Audit shared permanent Arcana state and the isolated P2 loadout data.
        -- 审计共享的永久阿卡那状态与隔离的 P2 预设数据。
        ArcanaLoadoutAudit = true,
    }
}

return Config
