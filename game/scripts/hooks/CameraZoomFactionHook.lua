--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"

local CameraZoomFactionHook = {}

function CameraZoomFactionHook.InitHooks()
    HookUtils.wrap("CreateRoom", CameraZoomFactionHook.CreateRoomWrapHook)
end

---@private
function CameraZoomFactionHook.CreateRoomWrapHook(baseFunc, ...)
    local room = baseFunc(...)
    if not room.ZoomFraction then
        room.ZoomFraction = 0.6
    elseif room.ZoomFraction > 0.5 then
        room.ZoomFraction = room.ZoomFraction * 0.6
    end
    return room
end

return CameraZoomFactionHook
