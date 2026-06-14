--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"
---@type HeroContextWrapper
local HeroContextWrapper = ModRequire "../logic/HeroContextWrapper.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"
---@type CoopModConfig
local Config = ModRequire "../config.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"

local WeaponLogicHooksLob = SimpleHook.New()

local LobAmmoPackToHero = {}

function WeaponLogicHooksLob:InitGameHooks()
    Events.game:on("comsumeAmmoItem", function (item)
        LobAmmoPackToHero[item.ObjectId] = nil
    end)

    -- Needs for WeaponLogicHooksLob.wrap.ReloadAmmo hook
    WeaponData.WeaponLob.StartRoomEvents[1].Args.ReloadForAllPlayers = true
end

function WeaponLogicHooksLob:InitEngineHooks()
    HeroContextWrapper.WrapTriggerHero("OnBlinkFinished", "OwnerTable")
end

--- TODO replace with better variant
function WeaponLogicHooksLob.post.LeaveRoom()
    LobAmmoPackToHero = {}
end

function WeaponLogicHooksLob.wrap.RecordWeaponCharge(baseFun, unit, weaponData, args, triggerArgs)
    if weaponData.MagnetismMultiplier then
        local currentHero = CurrentRun.Hero
        HookUtils.wrapOnce("GetIdsByType", function(GetIdsByTypeOrig, args)
            return TableUtils.filter(GetIdsByTypeOrig(args), function(value)
                return LobAmmoPackToHero[value] == currentHero
            end)
        end)
    end
    baseFun(unit, weaponData, args, triggerArgs)
end

function WeaponLogicHooksLob.wrap.SpawnObstacle(baseFun, args)
    if args.Name == "LobAmmoPack" then
        local hero = CurrentRun.Hero
        local playerIndex = CoopPlayers.GetPlayerByHero(hero) or 1

        -- Don't allow use the ammo pack for another player
        args.AttachedTable.UsedByHero = hero

        -- We will use this in the c++ hook
        -- Index starts from 0 here
        args.AttachedTable.PlayerIndexC = playerIndex - 1

        -- store id for another hooks
        local id = baseFun(args)
        LobAmmoPackToHero[id] = hero

        local colorCfg = Config["Player" .. playerIndex .. "Outline"]

        SetColor { Id = id, Color = { colorCfg.R, colorCfg.G, colorCfg.B, 255 } }

        return id
    else
        return baseFun(args)
    end
end

function WeaponLogicHooksLob.wrap.ReloadAmmo(baseFun, weaponData, customArgs)
    if customArgs and customArgs.ReloadForAllPlayers then
       for _, hero in CoopPlayers.PlayersIterator() do
            HeroContext.RunWithHeroContext(hero, baseFun, weaponData)
       end
    else
        baseFun(weaponData)
    end
end

return WeaponLogicHooksLob
