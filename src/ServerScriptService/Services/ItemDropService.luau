--!strict
--[[
    ItemDropService.luau
    Manages physical loot dropped by monsters on death.
    Spawns interactive glowing pickups in the plot world.
    When collected by players, items are stored in their inventory.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local ItemDropService = {}

local DataService: any
local EconomyService: any

function ItemDropService.Init(dataServiceRef: any, economyServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
end

-- Spawns a physical drop in the plot world
function ItemDropService.SpawnDrop(monsterType: string, deathPosition: Vector3, ownerPlayer: Player, plotModel: Model)
    local dropConfig = BalanceConfig.MonsterDrops[monsterType]
    if not dropConfig then return end

    local dropsFolder = plotModel:FindFirstChild("ItemDrops")
    if not dropsFolder then
        dropsFolder = Instance.new("Folder")
        dropsFolder.Name = "ItemDrops"
        dropsFolder.Parent = plotModel
    end

    local dropPart = Instance.new("Part")
    dropPart.Name = "Drop_" .. dropConfig.ItemId
    dropPart.Size = Vector3.new(1.8, 1.8, 1.8)
    dropPart.Position = deathPosition + Vector3.new(0, 1.5, 0)
    dropPart.Anchored = true
    dropPart.CanCollide = false
    dropPart.Material = Enum.Material.Neon
    dropPart.Color = dropConfig.Color
    dropPart.Shape = Enum.PartType.Ball
    dropPart.Parent = dropsFolder

    -- Floating animation
    local light = Instance.new("PointLight")
    light.Color = dropConfig.Color
    light.Range = 12
    light.Brightness = 2.5
    light.Parent = dropPart

    -- BillboardGui label
    local bb = Instance.new("BillboardGui")
    bb.Name = "DropGui"
    bb.Size = UDim2.new(4.5, 0, 1.5, 0)
    bb.StudsOffset = Vector3.new(0, 2.2, 0)
    bb.AlwaysOnTop = true
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

    -- Gentle bobbing tween
    local startY = dropPart.Position.Y
    local tweenUp = TweenService:Create(dropPart, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Position = Vector3.new(dropPart.Position.X, startY + 0.8, dropPart.Position.Z),
    })
    tweenUp:Play()

    -- Pickup detection
    local collected = false
    local touchConn: RBXScriptConnection? = nil
    touchConn = dropPart.Touched:Connect(function(hit)
        if collected then return end
        local character = hit.Parent
        local touchingPlayer = Players:GetPlayerFromCharacter(character)
        
        -- Only plot owner can pick up
        if touchingPlayer and touchingPlayer == ownerPlayer then
            collected = true
            if touchConn then
                touchConn:Disconnect()
                touchConn = nil
            end

            -- Update Inventory
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

            -- Disappear effect
            local tweenOut = TweenService:Create(dropPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.zero,
                Transparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                dropPart:Destroy()
            end)
        end
    end)

    -- Auto despawn drop after 90 seconds if uncollected
    Debris:AddItem(dropPart, 90)
end

-- Spawns physical shimmering gold coins dropped directly by monsters!
-- Scales with wave progression so higher waves reward players with huge coin bounties.
function ItemDropService.SpawnCoinDrop(coinAmount: number, deathPosition: Vector3, ownerPlayer: Player, plotModel: Model)
    if coinAmount <= 0 then return end

    local dropsFolder = plotModel:FindFirstChild("ItemDrops")
    if not dropsFolder then
        dropsFolder = Instance.new("Folder")
        dropsFolder.Name = "ItemDrops"
        dropsFolder.Parent = plotModel
    end

    local coinPart = Instance.new("Part")
    coinPart.Name = "CoinDrop"
    coinPart.Size = Vector3.new(1.8, 0.4, 1.8)
    coinPart.Position = deathPosition + Vector3.new(0, 1.2, 0)
    coinPart.Anchored = true
    coinPart.CanCollide = false
    coinPart.Material = Enum.Material.Neon
    coinPart.Color = Color3.fromRGB(255, 215, 0)
    coinPart.Shape = Enum.PartType.Cylinder
    -- Orient horizontally flat
    coinPart.CFrame = CFrame.new(deathPosition + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    coinPart.Parent = dropsFolder

    local goldLight = Instance.new("PointLight")
    goldLight.Color = Color3.fromRGB(255, 220, 60)
    goldLight.Range = 14
    goldLight.Brightness = 2.5
    goldLight.Parent = coinPart

    local bb = Instance.new("BillboardGui")
    bb.Name = "CoinGui"
    bb.Size = UDim2.new(4, 0, 1.4, 0)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
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

    -- Shimmering floating animation
    local startY = coinPart.Position.Y
    local tweenUp = TweenService:Create(coinPart, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Position = Vector3.new(coinPart.Position.X, startY + 0.6, coinPart.Position.Z),
    })
    tweenUp:Play()

    local collected = false
    local touchConn: RBXScriptConnection? = nil
    touchConn = coinPart.Touched:Connect(function(hit)
        if collected then return end
        local character = hit.Parent
        local touchingPlayer = Players:GetPlayerFromCharacter(character)

        if touchingPlayer and touchingPlayer == ownerPlayer then
            collected = true
            if touchConn then
                touchConn:Disconnect()
                touchConn = nil
            end

            -- Award Coins to player
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

            -- Disappear effect
            local tweenOut = TweenService:Create(coinPart, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.zero,
                Transparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                coinPart:Destroy()
            end)
        end
    end)

    -- Auto cleanup after 90 seconds
    Debris:AddItem(coinPart, 90)
end

return ItemDropService

