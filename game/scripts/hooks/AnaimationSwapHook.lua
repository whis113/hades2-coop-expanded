--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"

local ANIMATIONS_TO_SWAP = {
    ["MelinoeIdle"] = true;
    ["MelinoeDashStart"] = true;
    ["MelinoeDash"] = true;
    ["MelinoeSprint"] = true;
    ["MelinoeStart"] = true;
    ["MelinoeRun"] = true;
    ["MelinoeStop"] = true;
    ["MelinoeGetHit"] = true;
    ["Melinoe_GetHit_LastStand"] = true;

    ["Melinoe_Cast_Start"] = true;
    ["Melinoe_Cast_StartLoop"] = true;
    ["Melinoe_Cast_Fire"] = true;
    ["Melinoe_Cast_End"] = true;
    ["Melinoe_Cast_Fire_Quick"] = true;

    ["Melinoe_CrossCast_Start"] = true;
    ["Melinoe_ForwardCast_Unequip"] = true;

    ["MelinoeEquip"] = true;
    ["MelinoeActionIdle"] = true;
    ["MelinoeInteract"] = true;
    ["MelinoeBoonPreInteract"] = true;
}

local AnaimationSwapHook = SimpleHook.New()

function AnaimationSwapHook.wrap.SwapAnimation(baseFun, args)
    if ANIMATIONS_TO_SWAP[args.Name] then
        local playerIndex = CoopPlayers.GetCurrentPlayerId() or 1
        if args.Reverse then
            CoopRemoveAnimationSwap(playerIndex, args.Name)
        else
            CoopSetAnimationSwap(playerIndex, args.Name, args.DestinationName)
        end
    else
        baseFun(args)
    end
end

return AnaimationSwapHook
