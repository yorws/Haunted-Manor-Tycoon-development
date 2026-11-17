--!strict
--[[
    CoreUpgradeController.luau
    Client-side controller for Manor Core and Shop interactions.
    Now leverages Roblox's official ProximityPrompt system for seamless,
    highly responsive, cross-platform [E] interactions.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local CoreUpgradeController = {}

function CoreUpgradeController.Init()
    print("[CoreUpgradeController] Initialized with native Roblox ProximityPrompt support.")

    -- Optional: Play a responsive sound or visual feedback when player triggers a prompt
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if prompt.Name == "CoreUpgradePrompt" then
            -- Optional client side chime
        elseif prompt.Name == "ShopPrompt" then
            -- Optional client side register chime
        end
    end)
end

return CoreUpgradeController
