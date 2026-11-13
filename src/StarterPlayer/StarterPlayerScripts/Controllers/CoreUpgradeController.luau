--!strict
--[[
    CoreUpgradeController.luau
    Client-side controller that:
    1. Detects when the local player is near their own Manor Core (within interact radius)
    2. Shows an interactive UI prompt: "Press [E] to Upgrade Core  |  Lv.X → Lv.X+1  |  Cost: N Coins"
    3. Listens for E key / mobile tap to trigger RequestCoreLevelUp RemoteFunction
    4. Updates the prompt dynamically based on player data (level, coins, cost)
    5. Also shows a proximity prompt near the Central Market Hub ShopZone
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local CoreUpgradeController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- Runtime state
local currentCoreLevel = 1
local currentCoins = 0
local localPlotModel: Model? = nil
local isUpgrading = false
local isSelling = false

-- UI refs
local upgradePromptGui: ScreenGui? = nil
local upgradeFrame: Frame? = nil
local upgradeText: TextLabel? = nil
local upgradeCostBar: Frame? = nil

local shopPromptGui: ScreenGui? = nil
local shopFrame: Frame? = nil
local shopText: TextLabel? = nil

-- ---------------------------------------------------------------------------
-- Build UI
-- ---------------------------------------------------------------------------
local function buildUpgradePrompt()
    local sGui = Instance.new("ScreenGui")
    sGui.Name = "CoreUpgradePrompt"
    sGui.ResetOnSpawn = false
    sGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sGui.Enabled = false
    sGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "PromptFrame"
    frame.Size = UDim2.new(0, 340, 0, 100)
    frame.Position = UDim2.new(0.5, -170, 0.75, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = sGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(230, 190, 60)
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Key icon
    local keyBox = Instance.new("TextLabel")
    keyBox.Size = UDim2.new(0, 44, 0, 44)
    keyBox.Position = UDim2.new(0, 14, 0, 28)
    keyBox.BackgroundColor3 = Color3.fromRGB(230, 190, 60)
    keyBox.BorderSizePixel = 0
    keyBox.Text = "E"
    keyBox.TextColor3 = Color3.fromRGB(15, 12, 20)
    keyBox.TextSize = 22
    keyBox.Font = Enum.Font.GothamBlack
    keyBox.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyBox

    -- Main text
    local text = Instance.new("TextLabel")
    text.Name = "PromptText"
    text.Size = UDim2.new(1, -78, 1, -20)
    text.Position = UDim2.new(0, 68, 0, 10)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 230, 100)
    text.TextSize = 15
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextWrapped = true
    text.Text = "⬆️ Upgrade Manor Core\nLv.1 → Lv.2  |  Cost: 100 🪙"
    text.Parent = frame

    -- Cost bar (shows how close player is to affording)
    local barTrack = Instance.new("Frame")
    barTrack.Size = UDim2.new(1, -78, 0, 8)
    barTrack.Position = UDim2.new(0, 68, 1, -18)
    barTrack.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
    barTrack.BorderSizePixel = 0
    barTrack.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = barTrack

    local barFill = Instance.new("Frame")
    barFill.Name = "CostBarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(100, 220, 80)
    barFill.BorderSizePixel = 0
    barFill.Parent = barTrack

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 4)
    barFillCorner.Parent = barFill

    upgradePromptGui = sGui
    upgradeFrame = frame
    upgradeText = text
    upgradeCostBar = barFill
end

local function buildShopPrompt()
    local sGui = Instance.new("ScreenGui")
    sGui.Name = "ShopProximityPrompt"
    sGui.ResetOnSpawn = false
    sGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sGui.Enabled = false
    sGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "ShopFrame"
    frame.Size = UDim2.new(0, 300, 0, 80)
    frame.Position = UDim2.new(0.5, -150, 0.75, 0)
    frame.BackgroundColor3 = Color3.fromRGB(14, 24, 16)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = sGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 220, 100)
    stroke.Thickness = 2
    stroke.Parent = frame

    local keyBox = Instance.new("TextLabel")
    keyBox.Size = UDim2.new(0, 44, 0, 44)
    keyBox.Position = UDim2.new(0, 14, 0, 18)
    keyBox.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
    keyBox.BorderSizePixel = 0
    keyBox.Text = "E"
    keyBox.TextColor3 = Color3.fromRGB(10, 20, 12)
    keyBox.TextSize = 22
    keyBox.Font = Enum.Font.GothamBlack
    keyBox.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyBox

    local text = Instance.new("TextLabel")
    text.Name = "ShopText"
    text.Size = UDim2.new(1, -78, 1, 0)
    text.Position = UDim2.new(0, 68, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(120, 255, 140)
    text.TextSize = 15
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextWrapped = true
    text.Text = "🏪 Old Grimwald's Shop\n[E] Sell all loot for Coins"
    text.Parent = frame

    shopPromptGui = sGui
    shopFrame = frame
    shopText = text
end

-- ---------------------------------------------------------------------------
-- Update upgrade prompt content
-- ---------------------------------------------------------------------------
local function refreshUpgradePrompt()
    if not upgradeText or not upgradePromptGui then return end

    local maxLvl = BalanceConfig.CoreLevels.MaxLevel
    if currentCoreLevel >= maxLvl then
        upgradeText.Text = "🔮 Manor Core: MAX LEVEL (Lv.20)\nAll skills unlocked!"
        upgradeText.TextColor3 = Color3.fromRGB(255, 215, 0)
        if upgradeCostBar then
            upgradeCostBar.Size = UDim2.new(1, 0, 1, 0)
            upgradeCostBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        end
    else
        local cost = BalanceConfig.CoreLevels.GetUpgradeCost(currentCoreLevel)
        local newMaxHp = BalanceConfig.CoreLevels.GetMaxHp(currentCoreLevel + 1)
        local canAfford = currentCoins >= cost

        local affordStr = if canAfford then "✅" else "❌"
        local skillHint = ""
        if currentCoreLevel == 9 then
            skillHint = "\n⚡ Next: UNLOCK Spectral Retaliation!"
        elseif currentCoreLevel == 19 then
            skillHint = "\n👻 Next: UNLOCK Ghost Cloak!"
        end

        upgradeText.Text = string.format(
            "⬆️ Upgrade Core  Lv.%d → Lv.%d%s\n%s Cost: %d 🪙   New Max HP: %d",
            currentCoreLevel, currentCoreLevel + 1, skillHint, affordStr, cost, newMaxHp
        )
        upgradeText.TextColor3 = if canAfford then Color3.fromRGB(100, 255, 120) else Color3.fromRGB(255, 160, 80)

        if upgradeCostBar then
            local pct = math.clamp(currentCoins / math.max(cost, 1), 0, 1)
            TweenService:Create(upgradeCostBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(pct, 0, 1, 0),
                BackgroundColor3 = if pct >= 1 then Color3.fromRGB(100, 220, 80) else Color3.fromRGB(255, 160, 50),
            }):Play()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Show / hide helpers with fade
-- ---------------------------------------------------------------------------
local function showPrompt(sGui: ScreenGui, fr: Frame)
    sGui.Enabled = true
    fr.BackgroundTransparency = 1
    TweenService:Create(fr, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.1,
    }):Play()
end

local function hidePrompt(sGui: ScreenGui)
    sGui.Enabled = false
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function CoreUpgradeController.Init()
    buildUpgradePrompt()
    buildShopPrompt()

    -- Listen for player data updates (coins & core level)
    local updateEvent = Network.GetEvent("PlayerDataUpdated")
    updateEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        currentCoins = data.Coins or 0
        currentCoreLevel = data.CoreLevel or 1
        refreshUpgradePrompt()
    end)

    -- Listen for plot assignment to know which ManorCore to watch
    local plotAssignedEvent = Network.GetEvent("PlotAssigned")
    plotAssignedEvent.OnClientEvent:Connect(function(index: number, plotModel: Model?)
        if plotModel and plotModel:IsA("Model") then
            localPlotModel = plotModel
        else
            -- Find by index
            local plotsFolder = Workspace:FindFirstChild("Plots")
            if plotsFolder then
                for _, m in ipairs(plotsFolder:GetChildren()) do
                    if m:IsA("Model") and m:GetAttribute("PlotIndex") == index then
                        localPlotModel = m :: Model
                        break
                    end
                end
            end
        end
    end)

    -- E key / proximity detection loop
    local UPGRADE_RADIUS = BalanceConfig.CoreLevels.UpgradeInteractRadius or 14
    local SHOP_RADIUS = 20

    local wasNearCore = false
    local wasNearShop = false

    RunService.Heartbeat:Connect(function()
        local character = player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end

        -- Check Manor Core proximity
        local nearCore = false
        if localPlotModel then
            local core = localPlotModel:FindFirstChild("ManorCore") :: BasePart?
            if core then
                local dist = (hrp.Position - core.Position).Magnitude
                nearCore = dist <= UPGRADE_RADIUS
            end
        end

        if nearCore ~= wasNearCore then
            wasNearCore = nearCore
            if nearCore then
                refreshUpgradePrompt()
                showPrompt(upgradePromptGui :: ScreenGui, upgradeFrame :: Frame)
            else
                hidePrompt(upgradePromptGui :: ScreenGui)
            end
        end

        -- Check Market Hub ShopZone proximity
        local nearShop = false
        local hub = Workspace:FindFirstChild("MarketHub")
        if hub then
            local shopZone = hub:FindFirstChild("ShopZone") :: BasePart?
            if shopZone then
                local dist = (hrp.Position - shopZone.Position).Magnitude
                nearShop = dist <= SHOP_RADIUS
            end
        end

        if nearShop ~= wasNearShop then
            wasNearShop = nearShop
            if nearShop then
                showPrompt(shopPromptGui :: ScreenGui, shopFrame :: Frame)
            else
                hidePrompt(shopPromptGui :: ScreenGui)
            end
        end
    end)

    -- E key handler
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end

        -- Upgrade Core
        if wasNearCore and not isUpgrading then
            isUpgrading = true
            local levelUpFn = Network.GetFunction("RequestCoreLevelUp")
            levelUpFn:InvokeServer()
            task.delay(0.6, function() isUpgrading = false end)
        end

        -- Sell Loot at Shop
        if wasNearShop and not isSelling then
            isSelling = true
            local sellFn = Network.GetFunction("RequestSellInventory")
            sellFn:InvokeServer()
            task.delay(1.0, function() isSelling = false end)
        end
    end)

    -- Mobile: tap-to-interact button appears when near (optional placeholder)
    -- Roblox Mobile automatically fires InputBegan for screen taps on ProximityPrompts,
    -- but since we're using custom detection, E-key works for PC/console.
    -- Mobile support: TODO - add on-screen tap button overlay

    print("[CoreUpgradeController] Initialized.")
end

return CoreUpgradeController

