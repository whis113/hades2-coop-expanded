--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContextProxySpliterStore
local HeroContextProxySpliterStore = ModRequire "../logic/HeroContextProxySpliterStore.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"

---@class GameStateHooks : SimpleHook
local GameStateHooks = SimpleHook.New()

---@public
function GameStateHooks:InitEngineHooks()
    if GameState then
        GameStateHooks.ApplyGameStateProxy()
    end
end

---@private
function GameStateHooks.ApplyGameStateProxy()
    local currentMetaUpgradesState = GameState.MetaUpgradeState

    local hadnler = HeroContextProxySpliterStore.GetOrCreate("GameState", GameState, {
        "MetaUpgradeState",
    })

    local firtsPlayerData = hadnler:GetPlayerData(1)
    firtsPlayerData.MetaUpgradeState = currentMetaUpgradesState

    for playerId = 2, CoopPlayers.GetPlayersCount() do
        local playerData = hadnler:GetPlayerData(playerId)

        local playerMetaUpgradeState = GameState['MetaUpgradeStateCoopPlayer' .. playerId]
        if not playerMetaUpgradeState then
            playerMetaUpgradeState = DeepCopyTable(currentMetaUpgradesState)
            GameState['MetaUpgradeStateCoopPlayer' .. playerId] = playerMetaUpgradeState
        end

        playerData.MetaUpgradeState = playerMetaUpgradeState
    end
end

function GameStateHooks.post.InitializeMetaUpgradeState()
    HeroContextProxySpliterStore.Delete("GameState")
    GameStateHooks.ApplyGameStateProxy()
end

function GameStateHooks.wrap.EquipMetaUpgrades(baseFun, hero, args)
    if HeroContext.IsHeroContextExplicit() and hero then
        return baseFun(hero, args)
    end

    for _, playerHero in CoopPlayers.PlayersIterator() do
        if playerHero then
            HeroContext.RunWithHeroContext(playerHero, baseFun, playerHero, args)
        end
    end
end

return GameStateHooks
