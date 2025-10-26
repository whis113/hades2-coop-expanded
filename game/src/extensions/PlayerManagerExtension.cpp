//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "PlayerManagerExtension.h"
#include <hades2/PlayerManager.h>

bool PlayerManagerExtension::AssignGamepad(size_t playerIndex, uint8_t gamepadIndex) {
    if (GetPlayersCount() < playerIndex + 1)
        return false;

    auto *player = sgg::PlayerManager::Instance()->GetPlayer(playerIndex);

    if (!player)
        return false;

    auto *input = GetInput(player->GetControllerIndex());

    if (!input)
        return false;

    input->SetGamepadId(gamepadIndex);

    return true;
}

uint8_t PlayerManagerExtension::GetGamepad(size_t playerIndex) {
    if (GetPlayersCount() < playerIndex + 1)
        return -1;

    auto *player = sgg::PlayerManager::Instance()->GetPlayer(playerIndex);

    if (!player)
        return -1;

    auto *input = GetInput(player->GetControllerIndex());

    if (!input)
        return -1;

    return input->GetGamepadId();
}

bool PlayerManagerExtension::AssignController(sgg::Player *player, uint8_t ccontroler) {
    sgg::PlayerManager::Instance()->AssignController(player, ccontroler);
    return false;
}

bool PlayerManagerExtension::HasPlayer(size_t index) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return false;

    return instance->m_palyers[index];
}

// TODO use RemovePlayer from the game
void PlayerManagerExtension::RemovePlayer(size_t index) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return;

    auto *player = instance->m_palyers[index];

    if (player) {
        delete player;
        instance->m_palyers[index] = nullptr;
    }
}

sgg::Player *PlayerManagerExtension::CreatePlayer(size_t index) {
    auto *instance = sgg::PlayerManager::Instance();

    if (index >= MAX_PLAYERS)
        return nullptr;

    // This struct has size 2 in the game
    if (instance->m_palyers.size() <= index)
        return nullptr;

    if (instance->m_palyers[index] != nullptr)
        return nullptr;

    uint8_t controller = 1;

    auto player = AddPlayer(index);
    AssignController(player, controller);

    return player;
}

sgg::Player *PlayerManagerExtension::AddPlayer(size_t index) {
    auto *player =
        static_cast<sgg::Player *>(_aligned_malloc(sizeof(sgg::Player), std::alignment_of<sgg::Player>::value));

    uint8_t controllerIndex = 1;
    sgg::Player::internal_constructor(player, index, &controllerIndex);

    auto *instance = sgg::PlayerManager::Instance();
    instance->m_palyers[index] = player;
    return player;
}

sgg::Player *PlayerManagerExtension::GetPlayer(size_t index) {
    return sgg::PlayerManager::Instance()->m_palyers[index];
}
sgg::InputHandler *PlayerManagerExtension::GetInput(size_t index) {
    return sgg::PlayerManager::Instance()->m_inputMethods[index];
};

size_t PlayerManagerExtension::GetPlayersCount() const noexcept {
    size_t size = 0;
    for (auto *player : sgg::PlayerManager::Instance()->m_palyers)
        if (player)
            size++;

    return size;
}

void PlayerManagerExtension::SetCurrentMainPlayer(size_t index) {
    if (!mainPlayer) {
        mainPlayer = GetPlayer(0);
    }

    auto *instance = sgg::PlayerManager::Instance();
    auto *newMainPlayer = GetPlayer(index);
    newMainPlayer->SetIndex(0);
    instance->m_palyers[0] = newMainPlayer;
}

void PlayerManagerExtension::ResetCurrentMainPlayer() {
    auto *instance = sgg::PlayerManager::Instance();
    instance->m_palyers[0] = mainPlayer;
    // Reset indexes to fix engine checks
    for (size_t index = 0; index < instance->m_palyers.size(); index++) {
        GetPlayer(index)->SetIndex(index);
    }
}
