--
-- Co-op runtime diagnostics / 双人运行时诊断面板
--

---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"
---@type Events
local Events = ModRequire "Events.lua"
---@type Config
local Config = ModRequire "../config.lua"

---@class CoopDebugMonitor
local CoopDebugMonitor = {}

---@private
CoopDebugMonitor.AnchorId = nil
---@private
CoopDebugMonitor.Generation = 0
---@private
CoopDebugMonitor.LastRewardEvent = "none"

---@private
local function ShortName(value)
    if value == nil then
        return "-"
    end
    return tostring(value):gsub("Keepsake$", ""):gsub("Familiar$", "")
end

---@private
local function GetPlayerKeepsake(hero)
    if hero == nil or hero.Traits == nil then
        return nil
    end

    for _, trait in ipairs(hero.Traits) do
        if trait.Name and string.find(trait.Name, "Keepsake$") then
            return trait
        end
    end
end

---@private
local function GetForceBoonState(hero)
    local keepsake = GetPlayerKeepsake(hero)
    if keepsake == nil or keepsake.ForceBoonName == nil then
        return "-"
    end

    local uses = keepsake.RemainingUses or keepsake.Uses or "?"
    return ShortName(keepsake.ForceBoonName) .. "(" .. tostring(uses) .. ")"
end

---@private
local function GetRarityState(hero)
    local keepsake = GetPlayerKeepsake(hero)
    if keepsake == nil or keepsake.RarityUpgradeData == nil then
        return "-"
    end

    return tostring(keepsake.RarityUpgradeData.Uses or "?")
end

---@private
function CoopDebugMonitor.GetPlayerLine(playerId)
    local hero = CoopPlayers.GetHero(playerId)
    if hero == nil then
        return "P" .. tostring(playerId) .. ": unavailable"
    end

    local familiarKey = playerId == 1 and "EquippedFamiliar" or "EquippedFamiliarCoopPlayer" .. tostring(playerId)
    local familiar = GameState and GameState[familiarKey]
    local keepsake = GetPlayerKeepsake(hero)

    return string.format(
        "P%d HP %d/%d MP %d/%d %s | K:%s F:%s | Force:%s Rarity:%s",
        playerId,
        math.floor(hero.Health or 0),
        math.floor(hero.MaxHealth or 0),
        math.floor(hero.Mana or 0),
        math.floor(hero.MaxMana or 0),
        hero.IsDead and "DEAD" or "LIVE",
        ShortName(keepsake and keepsake.Name),
        ShortName(familiar),
        GetForceBoonState(hero),
        GetRarityState(hero)
    )
end

---@private
function CoopDebugMonitor.GetText()
    local room = CurrentRun and CurrentRun.CurrentRoom or nil
    local roomName = room and room.Name or "-"
    local encounter = room and room.Encounter and room.Encounter.Name or "-"

    return table.concat({
        "CO-OP DEBUG | " .. tostring(roomName) .. " | " .. tostring(encounter),
        CoopDebugMonitor.GetPlayerLine(1),
        CoopDebugMonitor.GetPlayerLine(2),
        "Last reward: " .. CoopDebugMonitor.LastRewardEvent,
    }, "\n")
end

---@private
function CoopDebugMonitor.EnsurePanel()
    if CoopDebugMonitor.AnchorId ~= nil then
        return
    end

    -- 使用独立屏幕锚点，避免改变角色、房间或奖励对象。 / Use an independent screen anchor so no hero, room, or reward object is mutated.
    CoopDebugMonitor.AnchorId = CreateScreenObstacle({
        Name = "BlankObstacle",
        Group = "Combat_UI",
        X = 370,
        Y = 150,
    })
    CreateTextBox({
        Id = CoopDebugMonitor.AnchorId,
        Text = CoopDebugMonitor.GetText(),
        Font = "LatoMedium",
        FontSize = 16,
        Width = 700,
        Justification = "Left",
        Color = { 210, 245, 255, 255 },
        ShadowColor = { 0, 0, 0, 240 },
        ShadowOffset = { 0, 2 },
        ShadowBlur = 0,
        OutlineThickness = 2,
        OutlineColor = { 0, 0, 0, 1 },
        Group = "Combat_UI",
    })
end

function CoopDebugMonitor.Refresh()
    if not (Config.Debug and Config.Debug.RuntimeMonitor) then
        return
    end
    if CurrentRun == nil then
        return
    end

    CoopDebugMonitor.EnsurePanel()
    ModifyTextBox({ Id = CoopDebugMonitor.AnchorId, Text = CoopDebugMonitor.GetText() })
end

---@param label string
---@param playerId number
---@param rewardName string|nil
---@param forcedName string|nil
function CoopDebugMonitor.RecordReward(label, playerId, rewardName, forcedName)
    CoopDebugMonitor.LastRewardEvent = string.format(
        "%s P%d result=%s forced=%s",
        tostring(label),
        playerId,
        ShortName(rewardName),
        ShortName(forcedName)
    )

    local hero = CoopPlayers.GetHero(playerId)
    local keepsake = GetPlayerKeepsake(hero)
    CoopAppendTraceLog(string.format(
        "[CoopDebug] reward label=%s player=P%d result=%s forced=%s keepsake=%s traitForce=%s forceUses=%s rarityUses=%s",
        tostring(label),
        playerId,
        tostring(rewardName),
        tostring(forcedName),
        tostring(keepsake and keepsake.Name),
        tostring(keepsake and keepsake.ForceBoonName),
        tostring(keepsake and keepsake.Uses),
        tostring(keepsake and keepsake.RarityUpgradeData and keepsake.RarityUpgradeData.Uses)
    ))
    CoopDebugMonitor.Refresh()
end

---@private
function CoopDebugMonitor.UpdateLoop(generation)
    while generation == CoopDebugMonitor.Generation and CurrentRun ~= nil do
        CoopDebugMonitor.Refresh()
        waitUnmodified(Config.Debug.RuntimeMonitorInterval or 0.25)
    end
end

function CoopDebugMonitor.Start()
    if not (Config.Debug and Config.Debug.RuntimeMonitor) then
        return
    end

    CoopDebugMonitor.Generation = CoopDebugMonitor.Generation + 1
    thread(CoopDebugMonitor.UpdateLoop, CoopDebugMonitor.Generation)
end

function CoopDebugMonitor.Init()
    Events.run:on("newRunStarted", CoopDebugMonitor.Start)
    Events.run:on("roomPreStart", CoopDebugMonitor.Refresh)

    if CurrentRun ~= nil then
        CoopDebugMonitor.Start()
    end
end

return CoopDebugMonitor
