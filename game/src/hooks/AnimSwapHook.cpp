//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "pch.h"
#include "AnimSwapHook.h"
#include "CoopContext.h"
#include <hades2/HashGuid.h>
#include <hades2/PlayerUnit.h>
#include <hades2/AnimationData.h>
#include <hades2/GameDataManager.h>

#include "FunctionHook.h"

// The game uses animation swaps to change animations for the player
// for different weapons and states.
// It workds like mapping from one animation name to another.
// Eg, "MelinoeIdle" -> "Melinoe_Lob_Idle"
//
// This hook changes animations based on the current thing context
// We need this to support different player units with different weapons

static FunctionHook<"sgg::AnimationManager::GetNameSwap(sgg::HashGuid*)", sgg::HashGuid*, sgg::HashGuid *,
                    sgg::HashGuid>
    GetNameSwapByName{};

static FunctionHook<"sgg::AnimationManager::GetNameSwap(sgg::AnimationData*)", sgg::AnimationData *,
                    sgg::AnimationData *>
    GetNameSwapByAnim{};

//sgg::Animation *__fastcall sgg::AnimationManager::CreateAndInit(
        //sgg::AnimationData *data,
        //Vectormath::Vector2 location,
        //sgg::AnimationManager *manager,
        //sgg::Thing *attachTo,
        //bool isChild,
        //bool suppressSounds,
        //sgg::Animation *spawner)

static FunctionHook<"sgg::AnimationManager::CreateAndInit", void*, sgg::AnimationData *, Vectormath::Vector2, void*, sgg::Thing*, bool, bool, void*>
    AnimationManager_CreateAndInit{};

//sgg::Animation *__fastcall sgg::Thing::SetAnimation(
//        sgg::Thing *this,
//        const sgg::HashGuid animName,
//        bool suppressSounds,
//        bool suppressSoundsIfInvisible,
//        bool copyFromPrev,
//        sgg::HashGuid modelName)
static FunctionHook<"sgg::Thing::SetAnimation", void *, sgg::Thing *, sgg::HashGuid, bool, bool, bool, sgg::HashGuid>
    Thing_SetAnimation{};

static FunctionHook<"sgg::Unit::PlayMoveAnimation", void, sgg::Unit *, bool> Unit_PlayMoveAnimation{};
static FunctionHook<"sgg::Unit::IsPlayingMoveAnimation", int64_t, sgg::Unit *> Unit_IsPlayingMoveAnimation{};

static FunctionHook<"sgg::AnimationManager::Reset", void, void *> AnimationManager_Reset{};

static bool isHookInstalled = false;
static size_t lastKnownPlayerIndex = 0;

static void ApplyPlayerContextFromThing(sgg::Thing *thing) {
    if (!thing || !thing->IsPlayerUnit()) {
        return;
    }
    auto *player = static_cast<sgg::PlayerUnit *>(thing)->GetPlayer();
    if (!player) {
        return;
    }
    lastKnownPlayerIndex = player->GetIndex();
}

void AnimSpawnHook::Install(IModApi::GetSymbolAddress_t GetSymbolAddress) {
    if (isHookInstalled) {
        return;
    }
    isHookInstalled = true;

    static CoopContext *coopContext = CoopContext::GetInstance();

    // Setters
    auto animationManager_CreateAndInitPos = GetSymbolAddress("sgg::AnimationManager::CreateAndInit");
    if (!animationManager_CreateAndInitPos)
        return;

    //AnimationManager_CreateAndInit.Install(reinterpret_cast<void *>(animationManager_CreateAndInitPos), 12);
    AnimationManager_CreateAndInit.onPreFunction = [](void *&ret, sgg::AnimationData *data,
                                                      Vectormath::Vector2 location, void *manager, sgg::Thing *attachTo,
                                                      bool isChild, bool suppressSounds, void *spawner) {
        ApplyPlayerContextFromThing(attachTo);
        return true;
    };

    //

    auto thingSetAnimationPos = GetSymbolAddress("?SetAnimation@Thing@sgg@@QEAAPEAVAnimation@2@UHashGuid@2@_N11U42@@Z");
    if (!thingSetAnimationPos)
        return;

    Thing_SetAnimation.Install(reinterpret_cast<void *>(thingSetAnimationPos), 12);
    Thing_SetAnimation.onPreFunction = [](void *&, sgg::Thing *self, sgg::HashGuid, bool, bool, bool, sgg::HashGuid) {
        ApplyPlayerContextFromThing(self);
        return true;
    };

    //

    auto unit_PlayMoveAnimationPos = GetSymbolAddress("sgg::Unit::PlayMoveAnimation");
    if (!unit_PlayMoveAnimationPos)
        return;

    Unit_PlayMoveAnimation.Install(reinterpret_cast<void *>(unit_PlayMoveAnimationPos), 12);
    Unit_PlayMoveAnimation.onPreFunction = [](sgg::Unit *self, bool) {
        ApplyPlayerContextFromThing(self);
        return true;
    };

    //

    auto unit_IsPlayingMoveAnimationnPos = GetSymbolAddress("sgg::Unit::IsPlayingMoveAnimation");
    if (!unit_IsPlayingMoveAnimationnPos)
        return;

    Unit_IsPlayingMoveAnimation.Install(reinterpret_cast<void *>(unit_IsPlayingMoveAnimationnPos), 12);
    Unit_IsPlayingMoveAnimation.onPreFunction = [](int64_t&, sgg::Unit *self) {
        ApplyPlayerContextFromThing(self);
        return true;
    };

    // Getters
    auto getAnimationSwapByHash = GetSymbolAddress("?GetNameSwap@AnimationManager@sgg@@SA?AUHashGuid@2@U32@@Z");
    if (!getAnimationSwapByHash)
        return;

    GetNameSwapByName.Install(reinterpret_cast<void *>(getAnimationSwapByHash), 12);
    GetNameSwapByName.onPreFunction = [](sgg::HashGuid*& ret, sgg::HashGuid * result, sgg::HashGuid name) {
        bool hasSwap = coopContext->GetAnimationSwap(lastKnownPlayerIndex).GetSwap(name, *result);
        if (hasSwap) {
            ret = result;
            return false;
        }

        return true;
    };

    auto getAnimationSwapByAnimation = GetSymbolAddress("?GetNameSwap@AnimationManager@sgg@@SAPEAVAnimationData@2@PEAV32@@Z");
    if (!getAnimationSwapByAnimation)
        return;

    GetNameSwapByAnim.Install(reinterpret_cast<void *>(getAnimationSwapByAnimation), 12);
    GetNameSwapByAnim.onPreFunction = [](sgg::AnimationData *&ret, sgg::AnimationData *from) {
        sgg::HashGuid result{0};
        bool hasSwap = coopContext->GetAnimationSwap(lastKnownPlayerIndex).GetSwap(from->GetName(), result);
        if (hasSwap) {
            ret = sgg::GameDataManager::GetAnimationData(result);
            return false;
        }

        return true;
    };

    // Reset
    auto animationManagerResetPos = GetSymbolAddress("sgg::AnimationManager::Reset");
    if (!animationManagerResetPos)
        return;

    AnimationManager_Reset.Install(reinterpret_cast<void *>(animationManagerResetPos), 12);
    AnimationManager_Reset.onPreFunction = [](void* manager) {
        for (size_t i = 0; i < MAX_PLAYERS; i++) {
            coopContext->GetAnimationSwap(i).Reset();
        }
        return true;
    };
}
