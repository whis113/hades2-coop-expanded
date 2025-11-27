//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "pch.h"

#include "../include/HadesModApi.h"
#include "CoopContext.h"
#include "hooks/AnimSwapHook.h"
#include "hooks/MagnetismHook.h"
#include "hooks/AllyModelLimitsAssertHooh.h"

HADES_MOD_API void _cdecl HadesModLuaCreated(lua_State *luaState) {CoopContext::GetInstance()->InitLua(luaState); };

HADES_MOD_API bool _cdecl HadesModInit(const IModApi *modApi) {
    if (modApi->version < MOD_API_VERSION)
        return false;

    AnimSpawnHook::Install(modApi->GetSymbolAddress);
    MagnetismHook::Install(modApi->GetSymbolAddress);
    AllyModelLimitsAssertHooh::Install(modApi->GetSymbolAddress);

    HookTable::Instance().Init(*modApi->GetHookTable());

    return true;
};

HADES_MOD_API bool _cdecl HadesModStart() { return true; };

HADES_MOD_API bool _cdecl HadesModStop() { return true; };
