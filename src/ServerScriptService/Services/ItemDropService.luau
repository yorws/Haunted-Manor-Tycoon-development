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

return ItemDropService

