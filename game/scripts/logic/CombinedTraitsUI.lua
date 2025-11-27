--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"

---@class CombinedTraitsUI
local CombinedTraitsUI = {}

---@private
CombinedTraitsUI.currentTraitsHero = nil

---@public
function CombinedTraitsUI.ChangeHeroInTraitsMenu()
    local currentHeroInMenu = CombinedTraitsUI.GetCurrentTraitHero()
    if CurrentRun.Hero == currentHeroInMenu then
        return
    end

    CombinedTraitsUI.RemoveTraitsFromMenu(currentHeroInMenu)

    CombinedTraitsUI.currentTraitsHero = CurrentRun.Hero
end

---@private
---@param hero table
function CombinedTraitsUI.RemoveTraitsFromMenu(hero)
    for _, trait in pairs(hero.Traits) do
        if not CombinedTraitsUI.IsTrayTarit(trait) then
            TraitUIRemove(trait)
        end
    end
end

---@public
function CombinedTraitsUI.GetCurrentTraitHero()
    return CombinedTraitsUI.currentTraitsHero or CoopPlayers.GetMainHero()
end

---@public
function CombinedTraitsUI.IsTrayTarit(trait)
    local slot = trait.Slot
    return slot == "Keepsake" or slot == "Spell" or slot == "Assist"
end

---@public
function CombinedTraitsUI.IsTraitShouldBeVisibleForCurrentHero(trait)
    if CombinedTraitsUI.IsTrayTarit(trait) then
        return true
    end

    return CurrentRun.Hero == CombinedTraitsUI.GetCurrentTraitHero()
end

return CombinedTraitsUI
