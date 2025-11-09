--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContextProxyStore
local HeroContextProxyStore = ModRequire "../logic/HeroContextProxyStore.lua"

---@class ResourceLoadingHooks : SimpleHook
local ResourceLoadingHooks = SimpleHook.New()

function ResourceLoadingHooks.wrap.LoadSpawnPackages(baseFun, encounter)
    for playerId, hero in CoopPlayers.PlayersIterator() do
        HeroContext.RunWithHeroContext(hero, baseFun, encounter)
    end
end

function ResourceLoadingHooks.post.DoPatches()
    local lootHistory = HeroContextProxyStore.Get("LootTypeHistory")

    if not lootHistory then
        return
    end

    for playerId = 1, CoopPlayers.GetPlayersCount() do
        for lootName, i in pairs(lootHistory:GetPlayerData(playerId)) do
            if not GameData.MissingPackages[lootName] then
                LoadPackages { Name = lootName }
            end
        end
    end
end

return ResourceLoadingHooks
