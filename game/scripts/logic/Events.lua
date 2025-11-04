--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type Observable
local Observable = ModRequire "../utils/Observable.lua"

---@class Events
local Events = {}

---@type Observable<"hooksPreInicialized" | "hooksInicialized" | "presave" | "postsave">
Events.engine = Observable.new()

---@type Observable<"newRunStarted" | "mapLoaded" | "roomPresentationFinished" | "roomPreLeave" | "allEnemiesDead">
Events.run = Observable.new()

return Events
