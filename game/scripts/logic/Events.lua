--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type Observable
local Observable = ModRequire "../utils/Observable.lua"

---@class Events
local Events = {}

---@type Observable<"hooksPreInicialized" | "hooksInicialized" | "presave" | "postsave" | "tick">
Events.engine = Observable.new()

---@type Observable<"newRunStarted" | "mapLoaded" | "roomPreStart" | "roomPresentationFinished" | "roomPreLeave" | "allEnemiesDead">
Events.run = Observable.new()

---@type Observable<"comsumeAmmoItem">
Events.game = Observable.new()

return Events
