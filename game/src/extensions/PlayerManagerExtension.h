//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#pragma once

#include <hades2/InputHandler.h>
#include <hades2/Player.h>

constexpr size_t MAX_PLAYERS = 2;

class PlayerManagerExtension {
  public:
    PlayerManagerExtension() = default;
    ~PlayerManagerExtension() = default;

    bool AssignGamepad(size_t playerIndex, uint8_t gamepad);
    uint8_t GetGamepad(size_t playerIndex);

    bool AssignController(sgg::Player *player, uint8_t controler);

    bool HasPlayer(size_t index);
    void RemovePlayer(size_t index);

    sgg::Player *CreatePlayer(size_t index);
    sgg::Player *GetPlayer(size_t index);

    sgg::InputHandler *GetInput(size_t index);

    size_t GetPlayersCount() const noexcept;

    void SetCurrentMainPlayer(size_t index);
    void ResetCurrentMainPlayer();

  private:
    sgg::Player *AddPlayer(size_t index);

  private:
    sgg::Player *mainPlayer{};
};
