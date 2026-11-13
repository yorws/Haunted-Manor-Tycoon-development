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

