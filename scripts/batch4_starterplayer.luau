-- Batch sync: batch4_starterplayer
local updated = {}
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("ClientMain")
    target.Source = [==[
--!strict
--[[
    ClientMain.client.luau
    Root client-side entry point for Haunted Manor Tycoon.
    Initializes UI, Plot aesthetics, Combat input, and Core Upgrade proximity controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent:WaitForChild("Controllers")
local UIController = require(Controllers:WaitForChild("UIController"))
local PlotController = require(Controllers:WaitForChild("PlotController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local CoreUpgradeController = require(Controllers:WaitForChild("CoreUpgradeController"))

print("========================================")
print("  Haunted Manor Tycoon - Client Starting")
print("========================================")

-- Initialize Controllers
UIController.Init()
PlotController.Init()
CombatController.Init()
CoreUpgradeController.Init()

print("[ClientMain] All client controllers initialized successfully.")
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CombatController")
    target.Source = [==[
--!strict
--[[
    CombatController.luau
    Handles client-side attack inputs for the Holy Lantern,
    crosshair targeting, instant responsive visual light beams, attack sound effects,
    and replicates server combat visuals.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)

local CombatController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local zapSound: Sound

local function drawHolyBeam(origin: Vector3, targetPos: Vector3, isHit: boolean)
    local distance = (targetPos - origin).Magnitude
    if distance <= 0.1 then return end

    local beamPart = Instance.new("Part")
    beamPart.Name = "HolyBeam"
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.Material = Enum.Material.Neon
    beamPart.Color = if isHit then Color3.fromRGB(255, 230, 110) else Color3.fromRGB(180, 160, 255)
    beamPart.Size = Vector3.new(0.6, 0.6, distance)
    beamPart.CFrame = CFrame.new(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
    beamPart.Transparency = 0.1
    beamPart.Parent = Workspace

    local tween = TweenService:Create(beamPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.1, 0.1, distance),
    })
    tween:Play()
    tween.Completed:Connect(function()
        beamPart:Destroy()
    end)
end

function CombatController.Init()
    local character = player.Character or player.CharacterAdded:Wait()

    -- Audio for Holy Lantern zap
    zapSound = Instance.new("Sound")
    zapSound.Name = "LanternZapSound"
    zapSound.SoundId = BalanceConfig.Weapon.FireSound
    zapSound.Volume = 0.9
    zapSound.PlaybackSpeed = 1.05
    zapSound.Parent = Workspace

    local function setupTool(tool: Tool)
        if tool.Name ~= BalanceConfig.Weapon.Name then return end

        tool.Activated:Connect(function()
            local char = player.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local handle = tool:FindFirstChild("Handle") :: BasePart?
            if not hrp or not handle then return end

            local mouseRay = mouse.UnitRay
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = { char }
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude

            local result = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * BalanceConfig.Weapon.Range, raycastParams)
            local targetMonster: Model? = nil
            local targetPos = mouseRay.Origin + (mouseRay.Direction * BalanceConfig.Weapon.Range)

            if result and result.Instance then
                targetPos = result.Position
                local model = result.Instance:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChildOfClass("Humanoid") and model ~= char then
                    targetMonster = model
                end
            end

            -- Play responsive fire sound
            if zapSound then
                zapSound.PlaybackSpeed = 1.0 + (math.random(-5, 5) / 100)
                zapSound:Play()
            end

            drawHolyBeam(handle.Position, targetPos, targetMonster ~= nil)

            local attackEvent = Network.GetEvent("AttackRequest")
            attackEvent:FireServer(targetMonster)
        end)
    end

    player.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                setupTool(child)
            end
        end)
    end)

    if character then
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                setupTool(child)
            end
        end)
        local existingTool = character:FindFirstChildOfClass("Tool")
        if existingTool then
            setupTool(existingTool)
        end
    end

    local combatVisualEvent = Network.GetEvent("CombatVisual")
    combatVisualEvent.OnClientEvent:Connect(function(origin: Vector3, target: Vector3, isHit: boolean)
        drawHolyBeam(origin, target, isHit)
    end)
end

return CombatController
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CoreUpgradeController")
    target.Source = [==[
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

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlotController")
    target.Source = [==[
--!strict
--[[
    PlotController.luau
    Handles client-side aesthetic pad animations, pulsing neon glow effects,
    and visual highlights for the player's claimed plot.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlotController = {}

local activeConnections: { [string]: RBXScriptConnection } = {}

function PlotController.Init()
    -- Gentle bobbing and glowing animation for active pads
    local plotsFolder = Workspace:WaitForChild("Plots", 10) :: Folder?
    if not plotsFolder then return end

    local timeElapsed = 0

    local renderConnection = RunService.RenderStepped:Connect(function(dt: number)
        timeElapsed += dt
        local pulse = (math.sin(timeElapsed * 3) + 1) / 2 -- 0 to 1

        for _, plot in ipairs(plotsFolder:GetChildren()) do
            if plot:IsA("Model") then
                -- Pulse Vault Pad
                local vaultPad = plot:FindFirstChild("VaultPad") :: BasePart?
                if vaultPad then
                    vaultPad.Transparency = 0.1 + (pulse * 0.2)
                end

                -- Pulse Cursed Bell Pad
                local bellPad = plot:FindFirstChild("WaveBellPad") :: BasePart?
                if bellPad then
                    bellPad.Transparency = 0.1 + ((1 - pulse) * 0.2)
                end

                -- Pulse active Upgrade Pads
                local padsFolder = plot:FindFirstChild("Pads")
                if padsFolder then
                    for _, pad in ipairs(padsFolder:GetChildren()) do
                        if pad:IsA("BasePart") and pad.Transparency < 0.9 then
                            pad.Transparency = 0.15 + (pulse * 0.15)
                        end
                    end
                end
            end
        end
    end)

    activeConnections["PadPulse"] = renderConnection
end

function PlotController.Cleanup()
    for _, conn in pairs(activeConnections) do
        conn:Disconnect()
    end
    table.clear(activeConnections)
end

return PlotController

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("UIController")
    target.Source = [==[
--!strict
--[[
    UIController.luau
    Creates and drives the complete touch-friendly ScreenGui HUD:
    - Currency Display (Coins 🪙 & Souls 👻)
    - Manor Core Health Bar
    - Wave Defense Status & Summon Button 🔔
    - Notification Toasts (animated purchase/alert cards)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local coinsLabel: TextLabel
local soulsLabel: TextLabel
local invLabel: TextLabel
local plotLabel: TextLabel
local coreHpLabel: TextLabel
local coreHpBarFill: Frame
local waveStatusLabel: TextLabel
local summonWaveBtn: TextButton
local toastContainer: Frame

local function createCorner(parent: GuiObject, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function createStroke(parent: GuiObject, color: Color3, thickness: number)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Parent = parent
end

function UIController.Init()
    -- Create ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HauntedManorGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- 1. Top HUD Bar (Currencies & Plot)
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(0, 560, 0, 52)
    topBar.Position = UDim2.new(0.5, -280, 0, 15)
    topBar.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
    topBar.BackgroundTransparency = 0.2
    topBar.BorderSizePixel = 0
    topBar.Parent = screenGui
    createCorner(topBar, 12)
    createStroke(topBar, Color3.fromRGB(90, 70, 110), 1.5)

    -- Coins Card
    local coinsCard = Instance.new("Frame")
    coinsCard.Name = "CoinsCard"
    coinsCard.Size = UDim2.new(0.25, 0, 0.8, 0)
    coinsCard.Position = UDim2.new(0.015, 0, 0.1, 0)
    coinsCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    coinsCard.BorderSizePixel = 0
    coinsCard.Parent = topBar
    createCorner(coinsCard, 8)

    coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsLabel"
    coinsLabel.Size = UDim2.new(1, -8, 1, 0)
    coinsLabel.Position = UDim2.new(0, 6, 0, 0)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Text = "🪙 0"
    coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
    coinsLabel.TextSize = 15
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinsLabel.Parent = coinsCard

    -- Souls Card
    local soulsCard = Instance.new("Frame")
    soulsCard.Name = "SoulsCard"
    soulsCard.Size = UDim2.new(0.24, 0, 0.8, 0)
    soulsCard.Position = UDim2.new(0.28, 0, 0.1, 0)
    soulsCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    soulsCard.BorderSizePixel = 0
    soulsCard.Parent = topBar
    createCorner(soulsCard, 8)

    soulsLabel = Instance.new("TextLabel")
    soulsLabel.Name = "SoulsLabel"
    soulsLabel.Size = UDim2.new(1, -8, 1, 0)
    soulsLabel.Position = UDim2.new(0, 6, 0, 0)
    soulsLabel.BackgroundTransparency = 1
    soulsLabel.Text = "👻 0"
    soulsLabel.TextColor3 = Color3.fromRGB(160, 240, 255)
    soulsLabel.TextSize = 15
    soulsLabel.Font = Enum.Font.GothamBold
    soulsLabel.TextXAlignment = Enum.TextXAlignment.Left
    soulsLabel.Parent = soulsCard

    -- Inventory Card (Loot for Shop)
    local invCard = Instance.new("Frame")
    invCard.Name = "InventoryCard"
    invCard.Size = UDim2.new(0.24, 0, 0.8, 0)
    invCard.Position = UDim2.new(0.535, 0, 0.1, 0)
    invCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    invCard.BorderSizePixel = 0
    invCard.Parent = topBar
    createCorner(invCard, 8)

    invLabel = Instance.new("TextLabel")
    invLabel.Name = "InventoryLabel"
    invLabel.Size = UDim2.new(1, -8, 1, 0)
    invLabel.Position = UDim2.new(0, 6, 0, 0)
    invLabel.BackgroundTransparency = 1
    invLabel.Text = "🎒 Loot: 0"
    invLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
    invLabel.TextSize = 14
    invLabel.Font = Enum.Font.GothamBold
    invLabel.TextXAlignment = Enum.TextXAlignment.Left
    invLabel.Parent = invCard

    -- Plot Card
    local plotCard = Instance.new("Frame")
    plotCard.Name = "PlotCard"
    plotCard.Size = UDim2.new(0.19, 0, 0.8, 0)
    plotCard.Position = UDim2.new(0.79, 0, 0.1, 0)
    plotCard.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
    plotCard.BorderSizePixel = 0
    plotCard.Parent = topBar
    createCorner(plotCard, 8)

    plotLabel = Instance.new("TextLabel")
    plotLabel.Name = "PlotLabel"
    plotLabel.Size = UDim2.new(1, 0, 1, 0)
    plotLabel.BackgroundTransparency = 1
    plotLabel.Text = "🏰 Plot: --"
    plotLabel.TextColor3 = Color3.fromRGB(220, 200, 240)
    plotLabel.TextSize = 13
    plotLabel.Font = Enum.Font.GothamMedium
    plotLabel.Parent = plotCard

    -- 2. Wave & Manor Core Defense HUD (Top-Center / Left)
    local defensePanel = Instance.new("Frame")
    defensePanel.Name = "DefensePanel"
    defensePanel.Size = UDim2.new(0, 320, 0, 100)
    defensePanel.Position = UDim2.new(0.02, 0, 0.12, 0)
    defensePanel.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
    defensePanel.BackgroundTransparency = 0.25
    defensePanel.BorderSizePixel = 0
    defensePanel.Parent = screenGui
    createCorner(defensePanel, 12)
    createStroke(defensePanel, Color3.fromRGB(120, 60, 160), 1.5)

    -- Core Health Bar Title & Label
    coreHpLabel = Instance.new("TextLabel")
    coreHpLabel.Name = "CoreHpLabel"
    coreHpLabel.Size = UDim2.new(1, -20, 0, 22)
    coreHpLabel.Position = UDim2.new(0, 10, 0, 8)
    coreHpLabel.BackgroundTransparency = 1
    coreHpLabel.Text = "🔮 Core HP: 500 / 500"
    coreHpLabel.TextColor3 = Color3.fromRGB(240, 200, 255)
    coreHpLabel.TextSize = 14
    coreHpLabel.Font = Enum.Font.GothamBold
    coreHpLabel.TextXAlignment = Enum.TextXAlignment.Left
    coreHpLabel.Parent = defensePanel

    -- Health Bar Track
    local coreHpTrack = Instance.new("Frame")
    coreHpTrack.Name = "CoreHpTrack"
    coreHpTrack.Size = UDim2.new(1, -20, 0, 12)
    coreHpTrack.Position = UDim2.new(0, 10, 0, 32)
    coreHpTrack.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
    coreHpTrack.BorderSizePixel = 0
    coreHpTrack.Parent = defensePanel
    createCorner(coreHpTrack, 6)

    coreHpBarFill = Instance.new("Frame")
    coreHpBarFill.Name = "CoreHpBarFill"
    coreHpBarFill.Size = UDim2.new(1, 0, 1, 0)
    coreHpBarFill.BackgroundColor3 = Color3.fromRGB(180, 70, 255)
    coreHpBarFill.BorderSizePixel = 0
    coreHpBarFill.Parent = coreHpTrack
    createCorner(coreHpBarFill, 6)

    -- Wave Status Text
    waveStatusLabel = Instance.new("TextLabel")
    waveStatusLabel.Name = "WaveStatusLabel"
    waveStatusLabel.Size = UDim2.new(0.65, 0, 0, 38)
    waveStatusLabel.Position = UDim2.new(0, 10, 0, 52)
    waveStatusLabel.BackgroundTransparency = 1
    waveStatusLabel.Text = "⏳ Wave 1 in: 120s"
    waveStatusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    waveStatusLabel.TextSize = 13
    waveStatusLabel.Font = Enum.Font.GothamMedium
    waveStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    waveStatusLabel.Parent = defensePanel

    -- Quick Summon Wave Button (Touch Friendly)
    summonWaveBtn = Instance.new("TextButton")
    summonWaveBtn.Name = "SummonWaveBtn"
    summonWaveBtn.Size = UDim2.new(0.3, 0, 0, 34)
    summonWaveBtn.Position = UDim2.new(0.68, 0, 0, 54)
    summonWaveBtn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
    summonWaveBtn.Text = "🔔 Summon"
    summonWaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    summonWaveBtn.TextSize = 12
    summonWaveBtn.Font = Enum.Font.GothamBold
    summonWaveBtn.Parent = defensePanel
    createCorner(summonWaveBtn, 8)

    summonWaveBtn.MouseButton1Click:Connect(function()
        local requestWaveFn = Network.GetFunction("RequestStartWave")
        requestWaveFn:InvokeServer()
    end)

    -- 3. Notification Toast Container (Bottom Center)
    toastContainer = Instance.new("Frame")
    toastContainer.Name = "ToastContainer"
    toastContainer.Size = UDim2.new(0, 380, 0, 120)
    toastContainer.Position = UDim2.new(0.5, -190, 0.82, 0)
    toastContainer.BackgroundTransparency = 1
    toastContainer.Parent = screenGui

    -- Listen to Network Events
    local updateEvent = Network.GetEvent("PlayerDataUpdated")
    updateEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        UIController.UpdatePlayerData(data)
    end)

    local plotAssignedEvent = Network.GetEvent("PlotAssigned")
    plotAssignedEvent.OnClientEvent:Connect(function(index: number)
        plotLabel.Text = string.format("🏰 Plot: #%d", index)
    end)

    local waveStateEvent = Network.GetEvent("WaveStateUpdated")
    waveStateEvent.OnClientEvent:Connect(function(state: Types.WaveState)
        UIController.UpdateWaveState(state)
    end)

    local notifEvent = Network.GetEvent("Notification")
    notifEvent.OnClientEvent:Connect(function(msg: string, color: Color3?)
        UIController.ShowToast(msg, color)
    end)

    -- Initial Data Fetch
    task.spawn(function()
        local getPlayerDataFn = Network.GetFunction("GetPlayerData")
        local data = getPlayerDataFn:InvokeServer() :: Types.PlayerData?
        if data then
            UIController.UpdatePlayerData(data)
        end
    end)
end

function UIController.UpdatePlayerData(data: Types.PlayerData)
    coinsLabel.Text = string.format("🪙 %d", data.Coins)
    soulsLabel.Text = string.format("👻 %d", data.Souls)

    if invLabel then
        local count = 0
        if data.Inventory then
            for _, c in pairs(data.Inventory) do
                count += c
            end
        end
        invLabel.Text = string.format("🎒 Loot: %d", count)
    end
end

function UIController.UpdateWaveState(state: Types.WaveState)
    coreHpLabel.Text = string.format("🔮 Core HP: %d / %d", math.floor(state.CoreHealth), math.floor(state.CoreMaxHealth))
    local pct = math.clamp(state.CoreHealth / state.CoreMaxHealth, 0, 1)
    coreHpBarFill.Size = UDim2.new(pct, 0, 1, 0)

    if pct <= 0.25 then
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(240, 50, 50)
    elseif pct <= 0.5 then
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(240, 160, 50)
    else
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(180, 70, 255)
    end

    if state.Status == "Waiting" then
        waveStatusLabel.Text = string.format("⏳ Wave %d in: %ds", state.WaveNumber, math.max(0, state.TimeRemaining))
        waveStatusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
        summonWaveBtn.Visible = true
    elseif state.Status == "Active" then
        waveStatusLabel.Text = string.format("⚔️ Wave %d: %d Left", state.WaveNumber, state.MonstersRemaining)
        waveStatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
        summonWaveBtn.Visible = false
    elseif state.Status == "Victory" then
        waveStatusLabel.Text = "🏆 Wave Survived!"
        waveStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        summonWaveBtn.Visible = false
    elseif state.Status == "Defeat" then
        waveStatusLabel.Text = "💀 Core Broken! Recovering..."
        waveStatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        summonWaveBtn.Visible = false
    end
end

function UIController.ShowToast(message: string, color: Color3?)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 36)
    toast.Position = UDim2.new(0, 0, 1, 0)
    toast.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
    toast.BackgroundTransparency = 0.15
    toast.BorderSizePixel = 0
    toast.Parent = toastContainer
    createCorner(toast, 8)
    createStroke(toast, color or Color3.fromRGB(140, 100, 200), 1.5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = toast

    local tweenIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0.4, 0)
    })
    tweenIn:Play()

    task.delay(2.6, function()
        if toast.Parent then
            local tweenOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 1.2, 0),
                BackgroundTransparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                toast:Destroy()
            end)
        end
    end)
end

return UIController

]==]
    table.insert(updated, target:GetFullName())
end
return 'Synced batch batch4_starterplayer (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
