//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#pragma once

#include <hades2/HashGuid.h>
#include <hades2/Player.h>
#include <string>
#include <unordered_map>

class PlayerAnimationSwap {
  public:
    void RemoveSwap(const sgg::HashGuid fromAnimation) noexcept { animationSwaps.erase(fromAnimation.GetId()); }

    void SetSwap(const sgg::HashGuid fromAnimation, const sgg::HashGuid toAnimation) {
        animationSwaps[fromAnimation.GetId()] = toAnimation.GetId();
    };

    bool GetSwap(const sgg::HashGuid fromAnimation, sgg::HashGuid &outToAnimation) const noexcept {
        auto it = animationSwaps.find(fromAnimation.GetId());
        if (it == animationSwaps.end())
            return false;
        outToAnimation = it->second;
        return true;
    };

    void Reset() { animationSwaps.clear(); };

  private:
    std::unordered_map<uint32_t, uint32_t> animationSwaps{};
};
