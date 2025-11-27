//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "pch.h"
#include <cstring>
#include <exception>

#include "AllyModelLimitsAssertHooh.h"

#include "FunctionHook.h"

// This hook fixes annoying asserts in UnitManager::Update in the coop mode
void AllyModelLimitsAssertHooh::Install(IModApi::GetSymbolAddress_t GetSymbolAddress) {
    static FunctionHook<"_FailedAssertOwnerGSGE", char, const char *, int, const char *,
                        const char *, const char *>
        _FailedAssertOwnerGSGE_Hook{};

    void *funcAddr = reinterpret_cast<void *>(GetSymbolAddress("?_FailedAssertOwnerGSGE@@YA?AW4FailBehavior@@PEBDH000ZZ"));
    if (!funcAddr) {
        throw std::exception("Failed to get _FailedAssertOwnerGSGE address");
    }
    _FailedAssertOwnerGSGE_Hook.Install(funcAddr, 12);

    _FailedAssertOwnerGSGE_Hook.onPreFunction = [](char &ret, const char *file, int line, const char *owner,
                                                   const char *condition, const char *fmt) {
        if (strcmp(condition, "allyBoneCount <= kAllyMaxBoneCount") == 0 ||
            strcmp(condition, "allyTriangleCount <= kAllyMaxTriangleCount") == 0) {
            return false;
        }
        return true;
    };
}
