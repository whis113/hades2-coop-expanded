//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "pch.h"
#include "LuaFunctionDefs.h"
#include "CoopContext.h"
#include "lua.hpp"
#include <chrono>
#include <iomanip>
#include <hades2/HashGuid.h>

// Reads a string field without leaving a value on the Lua stack.
// 读取字符串字段，并确保 Lua 栈不会残留值。
static std::string GetLuaStringField(lua_State *L, int tableIndex, const char *fieldName) {
    tableIndex = lua_absindex(L, tableIndex);
    lua_getfield(L, tableIndex, fieldName);
    const char *value = lua_tostring(L, -1);
    std::string result = value != nullptr ? value : "";
    lua_pop(L, 1);
    return result;
}

// Builds a readable area/layer/room tag from CurrentRun.CurrentRoom.
// 从 CurrentRun.CurrentRoom 构造可读的区域、层级和房间标签。
static std::string GetCoopTraceLocationTag(lua_State *L) {
    lua_getglobal(L, "CurrentRun");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return "[NoRun]";
    }

    lua_getfield(L, -1, "CurrentRoom");
    lua_remove(L, -2);
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return "[NoRoom]";
    }

    const std::string roomName = GetLuaStringField(L, -1, "Name");
    const std::string roomSetName = GetLuaStringField(L, -1, "RoomSetName");
    lua_pop(L, 1);

    std::string area;
    if (roomSetName == "F") area = "Underworld-Layer1-Erebus";
    else if (roomSetName == "G") area = "Underworld-Layer2-Oceanus";
    else if (roomSetName == "H") area = "Underworld-Layer3-Fields";
    else if (roomSetName == "I") area = "Underworld-Layer4-Tartarus";
    else if (roomSetName == "N") area = "Surface-Layer1-Ephyra";
    else if (roomSetName == "O") area = "Surface-Layer2-Rift";
    else if (roomSetName == "P") area = "Surface-Layer3-Olympus";
    else if (roomName.find("Chaos") != std::string::npos) area = "Chaos";
    else if (roomName.find("Hub") != std::string::npos) area = "Hub";
    else area = "Special";

    std::string roomKind = "Room";
    if (roomName.find("MiniBoss") != std::string::npos) roomKind = "EliteRoom";
    else if (roomName.find("Boss") != std::string::npos) roomKind = "BossRoom";
    else if (roomName.find("Shop") != std::string::npos) roomKind = "ShopRoom";
    else if (roomName.find("Reprieve") != std::string::npos) roomKind = "RestRoom";
    else if (roomName.find("Story") != std::string::npos) roomKind = "EventRoom";
    else if (roomName.find("Opening") != std::string::npos) roomKind = "OpeningRoom";
    else if (roomName.find("Combat") != std::string::npos) roomKind = "CombatRoom";

    return "[" + area + "-" + roomKind + "-" + (roomName.empty() ? "Unknown" : roomName) + "]";
}

// 将诊断日志追加到用户的 Hades II 存档目录，绕过 DebugPrint 不落盘的问题。
// Appends a diagnostic line to the user's Hades II save directory, bypassing DebugPrint persistence gaps.
static int CoopAppendTraceLog(lua_State *L) {
    if (!lua_isstring(L, 1)) {
        return luaL_error(L, "Argument 1 must be a string");
    }

    const char *userProfile = std::getenv("USERPROFILE");
    if (userProfile == nullptr) {
        return 0;
    }

    std::string path = std::string(userProfile) + "\\Saved Games\\Hades II\\TN_CoopMod.log";
    std::ofstream output(path, std::ios::app);
    if (output.is_open()) {
        const auto now = std::chrono::system_clock::now();
        const std::time_t nowTime = std::chrono::system_clock::to_time_t(now);
        std::tm localTime{};
        localtime_s(&localTime, &nowTime);
        output << std::put_time(&localTime, "%Y-%m-%d %H:%M:%S") << " "
               << GetCoopTraceLocationTag(L) << " " << lua_tostring(L, 1) << '\n';
    }

    return 0;
}

// bool CoopSetPlayerGamepad(number playerIndex, number controllerIndex)
static int CoopSetPlayerGamepad(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    if (!lua_isnumber(L, 2)) {
        return luaL_error(L, "Argument 2 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    uint8_t controllerIndex = static_cast<uint8_t>(lua_tonumber(L, 2));

    bool result = CoopContext::GetInstance()->GetPlayerManager().AssignGamepad(playerIndex, controllerIndex);

    lua_pushboolean(L, result);
    return 1;
}

// number CoopGetPlayerGamepad(number playerIndex)
static int CoopGetPlayerGamepad(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    size_t result = CoopContext::GetInstance()->GetPlayerManager().GetGamepad(playerIndex);

    lua_pushnumber(L, result);
    return 1;
}

// number CoopGetGamepadName(number controllerIndex)
static int CoopGetGamepadName(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    uint8_t index = static_cast<uint8_t>(lua_tonumber(L, 1));
    // Hades 1 code
    //lua_pushstring(L, sgg::getGamePadNameForIndex(index));
    lua_pushstring(L, "unknown");
    return 1;
}

// number CoopGetPlayersCount()
static int CoopGetPlayersCount(lua_State *L) {
    size_t playersCount = CoopContext::GetInstance()->GetPlayerManager().GetPlayersCount();

    lua_pushnumber(L, playersCount);
    return 1;
}

// number CoopCreatePlayer()
static int CoopCreatePlayer(lua_State *L) {
    size_t playerIndex = CoopContext::GetInstance()->CreatePlayer();

    if (playerIndex != -1)
        lua_pushnumber(L, playerIndex + 1);
    else
        lua_pushboolean(L, false);

    return 1;
}

// bool CoopCreatePlayer(number playerIndex)
static int CoopRemovePlayer(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;

    bool result = CoopContext::GetInstance()->RemovePlayer(playerIndex);
    lua_pushboolean(L, result);

    return 1;
}

// bool CoopCreatePlayer()
static int CoopHasPlayer(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    bool status = CoopContext::GetInstance()->GetPlayerManager().HasPlayer(playerIndex);

    lua_pushboolean(L, status);

    return 1;
}

// number/false CoopCreatePlayer(number playerIndex)
static int CoopCreatePlayerUnit(lua_State* L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;

    size_t unitId = CoopContext::GetInstance()->CreatePlayerUnit(playerIndex);

    if (unitId != -1)
        lua_pushnumber(L, unitId);
    else
        lua_pushboolean(L, false);

    return 1;
}

// bool CoopCreatePlayer(number playerIndex)
static int CoopRemovePlayerUnit(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;

    bool result = CoopContext::GetInstance()->RemovePlayerUnit(playerIndex);
    lua_pushboolean(L, result);

    return 1;
}

// bool CoopUseItem(number playerUnit, number lootUnit)
static int CoopUseItem(lua_State* L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    if (!lua_isnumber(L, 2)) {
        return luaL_error(L, "Argument 2 must be a number");
    }

    size_t playerUnit = static_cast<size_t>(lua_tonumber(L, 1));
    size_t thingUnit = static_cast<size_t>(lua_tonumber(L, 2));

    bool result = CoopContext::GetInstance()->UseItem(playerUnit, thingUnit);
    lua_pushboolean(L, result);

    return 1;
}

static int CoopSetCurrentMainPlayer(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;

    CoopContext::GetInstance()->GetPlayerManager().SetCurrentMainPlayer(playerIndex);
    return 0;
}

static int CoopResetCurrentMainPlayer(lua_State *L) {
    CoopContext::GetInstance()->GetPlayerManager().ResetCurrentMainPlayer();
    return 0;
}

static int CoopSetAnimationSwap(lua_State *L) {
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    if (!lua_isstring(L, 2)) {
        return luaL_error(L, "Argument 2 must be a sting");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    if (playerIndex >= MAX_PLAYERS) {
        return luaL_error(L, "Player index out of range");
    }

    const char *fromAnimationStr = lua_tostring(L, 2);

    sgg::HashGuid fromAnimHash = sgg::HashGuid::StringIntern(fromAnimationStr, 0);
    if (!fromAnimHash.GetId()) {
        return luaL_error(L, "Invalid animation name");
    }

    const char *toAnimationStr = lua_tostring(L, 3);

    sgg::HashGuid toAnimHash = sgg::HashGuid::StringIntern(toAnimationStr, 0);
    if (!toAnimHash.GetId()) {
        return luaL_error(L, "Invalid animation name");
    }

    CoopContext::GetInstance()->GetAnimationSwap(playerIndex).SetSwap(fromAnimHash, toAnimHash);

    return 0;
}

static int CoopRemoveAnimationSwap(lua_State *L) { 
    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "Argument 1 must be a number");
    }

    if (!lua_isstring(L, 2)) {
        return luaL_error(L, "Argument 2 must be a sting");
    }

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    if (playerIndex >= MAX_PLAYERS) {
        return luaL_error(L, "Player index out of range");
    }

    const char *fromAnimationStr = lua_tostring(L, 2);

    sgg::HashGuid animNameHash = sgg::HashGuid::StringIntern(fromAnimationStr, 0);
    if (!animNameHash.GetId()) {
        return luaL_error(L, "Invalid animation name");
    }

    CoopContext::GetInstance()->GetAnimationSwap(playerIndex).RemoveSwap(animNameHash);

    return 0;
}

void LuaFunctionDefs::Load(lua_State* L) {
    #define REGISTER(fun) lua_register(L, #fun, fun)

    REGISTER(CoopSetPlayerGamepad);
    REGISTER(CoopGetPlayerGamepad);
    REGISTER(CoopGetGamepadName);

    REGISTER(CoopGetPlayersCount);
    REGISTER(CoopCreatePlayer);
    REGISTER(CoopRemovePlayer);
    REGISTER(CoopHasPlayer);

    REGISTER(CoopCreatePlayerUnit);
    REGISTER(CoopRemovePlayerUnit);
    REGISTER(CoopUseItem);

    REGISTER(CoopSetCurrentMainPlayer);
    REGISTER(CoopResetCurrentMainPlayer);

    REGISTER(CoopSetAnimationSwap);
    REGISTER(CoopRemoveAnimationSwap);
    REGISTER(CoopAppendTraceLog);

    #undef REGISTER
}
