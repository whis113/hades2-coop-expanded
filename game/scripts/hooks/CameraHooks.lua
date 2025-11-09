--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type CoopCamera
local CoopCamera = ModRequire "../logic/CoopCamera.lua"

local CameraHooks = SimpleHook.New()

function CameraHooks.wrap.CreateRoom(baseFunc, ...)
    local room = baseFunc(...)
    if not room.ZoomFraction then
        room.ZoomFraction = 0.6
    elseif room.ZoomFraction > 0.5 then
        room.ZoomFraction = room.ZoomFraction * 0.6
    end
    return room
end

function CameraHooks.post.PanCamera(args)
    -- FIXME Ids is a table
    local id = args.Id or args.Ids
    if id then
        CoopCamera.ForceFocus(CoopPlayers.IsPlayerUnit(id))
    end
end

return CameraHooks
