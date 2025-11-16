--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class GameStateEx
local GameStateEx = {}

function GameStateEx.CopyTraitsToMetaUpgrades(hero)
    local metaUpgrades = GameState.MetaUpgradeState

    local traitToMeta = {}

    for name, data in pairs(MetaUpgradeCardData) do
        local upgarde = metaUpgrades[name]
        if upgarde then
            upgarde.Equipped = false
        end
        if data.TraitName then
            traitToMeta[data.TraitName] = upgarde
        end
    end

    for k, trait in ipairs(hero.Traits) do
        local upgrade = traitToMeta[trait.Name]
        if upgrade then
            upgrade.Equipped = true
        end
    end
end

return GameStateEx
