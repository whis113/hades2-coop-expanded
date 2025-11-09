--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class SecondPlayerUi
local SecondPlayerUi = {}

-- Register UI elements for player 2 here
function SecondPlayerUi.RegisterComponents(componentData)

    local function duplicateComponentInOrderList(originalName, p2Name)
        for i, name in pairs(componentData.Order) do
            if name == originalName then
                table.insert(componentData.Order, i, p2Name)
                return
            end
        end
    end

    local function cloneForP2(leftOffsetBase, rightOffsetBase, names)
        for _, name in pairs(names) do
            local component = DeepCopyTable(componentData[name])
            local x = component.X
            if x then
                component.X = nil
                component.RightOffset = rightOffsetBase + (leftOffsetBase - x)
            end

            local nameForP2 = name .. "Player2"
            componentData[nameForP2] = component
            duplicateComponentInOrderList(name, nameForP2)
        end
    end

    componentData.MoneyIcon.BottomOffset = 150

    componentData.ResourceBackingShadow.BottomOffset = -400

    cloneForP2(315, 340, {
        -- Health
        "HealthBack",
        "HealthFalloff",
        "HealthFill",
        "HealthReserve",
        "HealthBuffer",
        "HealthHighIndicator",
        "HealthLowIndicator",
        -- Mane
        "ManaMeterBack",
        "ManaMeterFill",
        "ManaMeterReserve",
        "ManaLowIndicator",
    })

    componentData.HealthFalloffPlayer2.RightOffset = componentData.HealthFalloffPlayer2.RightOffset + 20
    componentData.HealthFillPlayer2.RightOffset = componentData.HealthFillPlayer2.RightOffset + 20
    componentData.HealthReservePlayer2.RightOffset = componentData.HealthReservePlayer2.RightOffset + 20
    componentData.HealthBufferPlayer2.RightOffset = componentData.HealthBufferPlayer2.RightOffset + 20

    componentData.HealthBackPlayer2.FlipHorizontal = true
    componentData.HealthFalloffPlayer2.FlipHorizontal = true
    componentData.HealthFillPlayer2.FlipHorizontal = true
    componentData.HealthReservePlayer2.FlipHorizontal = true
    componentData.HealthBufferPlayer2.FlipHorizontal = true


    componentData.ManaMeterFillPlayer2.RightOffset = componentData.ManaMeterFillPlayer2.RightOffset + 20
    componentData.ManaMeterReservePlayer2.RightOffset = componentData.ManaMeterReservePlayer2.RightOffset + 20

    componentData.ManaMeterBackPlayer2.FlipHorizontal = true
    componentData.ManaMeterFillPlayer2.FlipHorizontal = true
    componentData.ManaMeterReservePlayer2.FlipHorizontal = true
end

function SecondPlayerUi.UpdateHealthUI()

end

function SecondPlayerUi.Refresh()

end

return SecondPlayerUi
