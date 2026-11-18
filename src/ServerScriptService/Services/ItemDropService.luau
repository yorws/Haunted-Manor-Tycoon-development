--!strict
--[[
    ItemDropService.luau
    Manages physical loot and coins dropped by monsters on death.
    - Stays firmly grounded on the arena floor when idle (no floating).
    - Smoothly magnetizes towards the plot owner when within MAGNET_RANGE studs.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local ItemDropService = {}

local MAGNET_RANGE = 16       -- Jarak deteksi magnet (studs)
local MAGNET_SPEED = 42       -- Kecepatan tarikan magnet (studs/detik)
local COLLECT_DISTANCE = 3.2  -- Jarak otomatis terambil saat mendekati karakter

local DataService: any
local EconomyService: any

local function getGroundedPosition(deathPosition: Vector3, plotModel: Model, halfHeight: number): Vector3
    local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart?
    if plotBase then
        local floorTopY = plotBase.Position.Y + (plotBase.Size.Y * 0.5)
        return Vector3.new(deathPosition.X, floorTopY + halfHeight, deathPosition.Z)
    end
    return Vector3.new(deathPosition.X, 2 + halfHeight, deathPosition.Z)
end

local function attachMagnetBehavior(
    part: BasePart,
    ownerPlayer: Player,
    isCoin: boolean,
    onCollect: () -> ()
)
    local collected = false
    local spinAngle = 0
    local currentSpeed = MAGNET_SPEED * 0.5

    local function triggerCollect()
        if collected then return end
        collected = true
        onCollect()

        local tweenOut = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.zero,
            Transparency = 1,
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            if part.Parent then
                part:Destroy()
            end
        end)
    end

    -- Tetap dukung sentuhan langsung (Touched)
    local touchConn: RBXScriptConnection? = nil
    touchConn = part.Touched:Connect(function(hit)
        if collected then return end
        local touchingPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        if touchingPlayer and touchingPlayer == ownerPlayer then
            if touchConn then
                touchConn:Disconnect()
                touchConn = nil
            end
            triggerCollect()
        end
    end)

    -- Loop Magnet berbasis jarak pemain
    local heartbeatConn: RBXScriptConnection? = nil
    heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
        if collected or not part.Parent then
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
            if touchConn then
                touchConn:Disconnect()
                touchConn = nil
            end
            return
        end

        spinAngle += dt * 2.5

        local character = ownerPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = character and character:FindFirstChildOfClass("Humanoid")

        if hrp and hum and hum.Health > 0 then
            local toPlayer = hrp.Position - part.Position
            local distance = toPlayer.Magnitude

            if distance <= COLLECT_DISTANCE then
                if heartbeatConn then
                    heartbeatConn:Disconnect()
                    heartbeatConn = nil
                end
                if touchConn then
                    touchConn:Disconnect()
                    touchConn = nil
                end
                triggerCollect()
                return
            elseif distance <= MAGNET_RANGE then
                -- Akselerasi tarikan magnet makin cepat saat makin dekat
                local proximityFactor = 1 + ((MAGNET_RANGE - distance) / MAGNET_RANGE)
                currentSpeed = math.min(MAGNET_SPEED * 1.8, currentSpeed + (dt * 75))
                local step = math.min(distance, currentSpeed * proximityFactor * dt)
                local nextPos = part.Position + (toPlayer.Unit * step)

                if isCoin then
                    part.CFrame = CFrame.new(nextPos) * CFrame.Angles(0, spinAngle, math.rad(90))
                else
                    part.CFrame = CFrame.new(nextPos) * CFrame.Angles(0, spinAngle, 0)
                end
                return
            end
        end

        -- Di luar radius magnet: tetap diam menempel di tanah & berputar pelan
        currentSpeed = MAGNET_SPEED * 0.5
        if isCoin then
            part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, spinAngle, math.rad(90))
        else
            part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, spinAngle, 0)
        end
    end)
end

function ItemDropService.Init(dataServiceRef: any, economyServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
end

function ItemDropService.SpawnDrop(monsterType: string, deathPosition: Vector3, ownerPlayer: Player, plotModel: Model)
    local dropConfig = BalanceConfig.MonsterDrops[monsterType]
    if not dropConfig then return end

    local dropsFolder = plotModel:FindFirstChild("ItemDrops")
    if not dropsFolder then
        dropsFolder = Instance.new("Folder")
        dropsFolder.Name = "ItemDrops"
        dropsFolder.Parent = plotModel
    end

    local groundedPos = getGroundedPosition(deathPosition, plotModel, 0.75)

    local dropPart = Instance.new("Part")
    dropPart.Name = "Drop_" .. dropConfig.ItemId
    dropPart.Size = Vector3.new(1.5, 1.5, 1.5)
    dropPart.CFrame = CFrame.new(groundedPos)
    dropPart.Anchored = true
    dropPart.CanCollide = false
    dropPart.Material = Enum.Material.Neon
    dropPart.Color = dropConfig.Color
    dropPart.Shape = Enum.PartType.Block
    dropPart.Parent = dropsFolder

    local light = Instance.new("PointLight")
    light.Color = dropConfig.Color
    light.Range = 11
    light.Brightness = 2.2
    light.Parent = dropPart

    local bb = Instance.new("BillboardGui")
    bb.Name = "DropGui"
    bb.Size = UDim2.new(4.5, 0, 1.5, 0)
    bb.StudsOffset = Vector3.new(0, 1.8, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Parent = dropPart

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("✨ %s\n(%d 🪙 at Shop)", dropConfig.DisplayName, dropConfig.SellPrice)
    label.TextColor3 = dropConfig.Color
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    attachMagnetBehavior(dropPart, ownerPlayer, false, function()
        if not DataService then
            DataService = require(game:GetService("ServerScriptService").Services.DataService)
        end
        if not EconomyService then
            EconomyService = require(game:GetService("ServerScriptService").Services.EconomyService)
        end

        DataService.UpdateData(ownerPlayer, function(d: Types.PlayerData)
            if not d.Inventory then
                d.Inventory = {}
            end
            d.Inventory[dropConfig.ItemId] = (d.Inventory[dropConfig.ItemId] or 0) + 1
        end)

        EconomyService.SyncClient(ownerPlayer)

        local notif = Network.GetEvent("Notification")
        notif:FireClient(ownerPlayer, string.format("📦 Picked up %s! (Sell at Shop)", dropConfig.DisplayName), dropConfig.Color)
    end)

    Debris:AddItem(dropPart, 90)
end

function ItemDropService.SpawnCoinDrop(coinAmount: number, deathPosition: Vector3, ownerPlayer: Player, plotModel: Model)
    if coinAmount <= 0 then return end

    local dropsFolder = plotModel:FindFirstChild("ItemDrops")
    if not dropsFolder then
        dropsFolder = Instance.new("Folder")
        dropsFolder.Name = "ItemDrops"
        dropsFolder.Parent = plotModel
    end

    local groundedPos = getGroundedPosition(deathPosition, plotModel, 0.22)

    local coinPart = Instance.new("Part")
    coinPart.Name = "CoinDrop"
    coinPart.Size = Vector3.new(0.4, 1.7, 1.7)
    coinPart.Anchored = true
    coinPart.CanCollide = false
    coinPart.Material = Enum.Material.Neon
    coinPart.Color = Color3.fromRGB(255, 215, 0)
    coinPart.Shape = Enum.PartType.Cylinder
    coinPart.CFrame = CFrame.new(groundedPos) * CFrame.Angles(0, 0, math.rad(90))
    coinPart.Parent = dropsFolder

    local goldLight = Instance.new("PointLight")
    goldLight.Color = Color3.fromRGB(255, 220, 60)
    goldLight.Range = 12
    goldLight.Brightness = 2.2
    goldLight.Parent = coinPart

    local bb = Instance.new("BillboardGui")
    bb.Name = "CoinGui"
    bb.Size = UDim2.new(4, 0, 1.4, 0)
    bb.StudsOffset = Vector3.new(0, 1.6, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Parent = coinPart

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("🪙 +%d Koin!", coinAmount)
    label.TextColor3 = Color3.fromRGB(255, 225, 70)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    attachMagnetBehavior(coinPart, ownerPlayer, true, function()
        if not EconomyService then
            EconomyService = require(game:GetService("ServerScriptService").Services.EconomyService)
        end
        if EconomyService and EconomyService.AddCoins then
            EconomyService.AddCoins(ownerPlayer, coinAmount, true)
        end

        local notif = Network.GetEvent("Notification")
        if notif then
            notif:FireClient(ownerPlayer, string.format("🪙 +%d Koin diambil dari monster!", coinAmount), Color3.fromRGB(255, 220, 50))
        end
    end)

    Debris:AddItem(coinPart, 90)
end

return ItemDropService