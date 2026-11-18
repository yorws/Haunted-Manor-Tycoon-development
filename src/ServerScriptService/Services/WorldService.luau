--!strict
--[[
    WorldService.luau
    Builds the Central Market Hub at the center of the map (0, 1, 0).
    Surrounded closely by all 6 player plots (Hexagonal layout).
    Includes stone pathways connecting the Market Hub directly to every plot entrance!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Modules.Network)
local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)

local WorldService = {}

local ShopService: any
local shopZoneDebounce: { [number]: number } = {}

local HUB_CENTER = Vector3.new(0, 1, 0)

local function createPart(props: { [string]: any }): Part
    local part = Instance.new("Part")
    part.Anchored = if props.Anchored ~= nil then props.Anchored else true
    part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
    for k, v in pairs(props) do
        if k ~= "Anchored" and k ~= "CanCollide" then
            (part :: any)[k] = v
        end
    end
    return part
end

local function buildMarketHub(): Model
    local hubModel = Instance.new("Model")
    hubModel.Name = "MarketHub"
    hubModel.Parent = Workspace

    createPart({
        Size = Vector3.new(65, 2, 65),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -0.9, 0)),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 52, 60),
        Name = "HubPlatform",
        Parent = hubModel,
    })

    createPart({
        Size = Vector3.new(78, 1, 78),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -1.4, 0)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(40, 38, 48),
        Name = "HubRing",
        Parent = hubModel,
    })

    local obelisk = createPart({
        Size = Vector3.new(3, 22, 3),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 11, 0)),
        Material = Enum.Material.Marble,
        Color = Color3.fromRGB(50, 45, 65),
        Name = "MarketObelisk",
        Parent = hubModel,
    })
    local crystal = createPart({
        Size = Vector3.new(2.5, 2.5, 2.5),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 23.5, 0)),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(80, 220, 255),
        Shape = Enum.PartType.Ball,
        Name = "ObeliskCrystal",
        Parent = hubModel,
    })
    local crystalLight = Instance.new("PointLight")
    crystalLight.Color = Color3.fromRGB(80, 220, 255)
    crystalLight.Range = 50
    crystalLight.Brightness = 3
    crystalLight.Parent = crystal

    local obeliskGui = Instance.new("BillboardGui")
    obeliskGui.Name = "HubSign"
    obeliskGui.Size = UDim2.new(10, 0, 2, 0)
    obeliskGui.StudsOffset = Vector3.new(0, 15, 0)
    obeliskGui.AlwaysOnTop = true
    obeliskGui.Parent = obelisk

    local hubTitle = Instance.new("TextLabel")
    hubTitle.Size = UDim2.new(1, 0, 1, 0)
    hubTitle.BackgroundTransparency = 1
    hubTitle.Text = "🏛️ HAUNTED MARKET HUB\n[Short Walk from All Plots]"
    hubTitle.TextColor3 = Color3.fromRGB(180, 240, 255)
    hubTitle.TextStrokeTransparency = 0
    hubTitle.TextSize = 15
    hubTitle.Font = Enum.Font.GothamBlack
    hubTitle.Parent = obeliskGui

    local NUM_PLOTS = BalanceConfig.General.MaxPlots or 6
    local PLOT_RADIUS = BalanceConfig.General.PlotRadius or 145
    for i = 1, NUM_PLOTS do
        local angle = ((i - 1) * (2 * math.pi / NUM_PLOTS))
        local targetX = math.sin(angle) * (PLOT_RADIUS - 42)
        local targetZ = math.cos(angle) * (PLOT_RADIUS - 42)
        local targetPos = Vector3.new(targetX, 0.5, targetZ)

        local midPos = (Vector3.new(0, 0.5, 0) + targetPos) / 2
        local pathLength = (targetPos - Vector3.new(0, 0.5, 0)).Magnitude

        local pathPart = createPart({
            Size = Vector3.new(8, 0.6, pathLength),
            CFrame = CFrame.lookAt(midPos, targetPos),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(60, 58, 65),
            Name = "RoadToPlot_" .. i,
            Parent = hubModel,
        })

        for _, side in ipairs({ -5.5, 5.5 }) do
            local lanternPost = createPart({
                Size = Vector3.new(1.2, 5, 1.2),
                CFrame = pathPart.CFrame * CFrame.new(side, 2.5, 0),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(45, 35, 25),
                Name = "RoadLanternPost",
                Parent = hubModel,
            })
            local lamp = createPart({
                Size = Vector3.new(1.4, 1.4, 1.4),
                CFrame = lanternPost.CFrame * CFrame.new(0, 3, 0),
                Material = Enum.Material.Neon,
                Color = Color3.fromRGB(255, 180, 90),
                Name = "RoadLamp",
                Parent = hubModel,
            })
            local lgt = Instance.new("PointLight")
            lgt.Color = Color3.fromRGB(255, 180, 90)
            lgt.Range = 16
            lgt.Brightness = 1.8
            lgt.Parent = lamp
        end
    end

    createPart({
        Size = Vector3.new(16, 1, 10),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 6.5, 18)),
        Material = Enum.Material.WoodPlanks,
        Color = Color3.fromRGB(80, 40, 25),
        Name = "ShopStallRoof",
        Parent = hubModel,
    })
    local shopCounter = createPart({
        Size = Vector3.new(12, 3, 3),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 2, 15)),
        Material = Enum.Material.Wood,
        Color = Color3.fromRGB(90, 55, 30),
        Name = "ShopCounter",
        Parent = hubModel,
    })
    local shopZone = createPart({
        Size = Vector3.new(16, 0.3, 12),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 0.15, 20)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(50, 180, 70),
        CanCollide = false,
        Name = "ShopZone",
        Parent = hubModel,
    })
    shopZone:SetAttribute("IsShopZone", true)

    local shopSignGui = Instance.new("BillboardGui")
    shopSignGui.Name = "ShopSignGui"
    shopSignGui.Size = UDim2.new(9, 0, 2.5, 0)
    shopSignGui.StudsOffset = Vector3.new(0, 6, 0)
    shopSignGui.AlwaysOnTop = true
    shopSignGui.Parent = shopCounter

    local shopSignLabel = Instance.new("TextLabel")
    shopSignLabel.Name = "ShopSignLabel"
    shopSignLabel.Size = UDim2.new(1, 0, 1, 0)
    shopSignLabel.BackgroundTransparency = 1
    shopSignLabel.Text = "🏪 LOOT SHOP\n[Press E or Step to Sell Loot]"
    shopSignLabel.TextColor3 = Color3.fromRGB(100, 255, 130)
    shopSignLabel.TextStrokeTransparency = 0
    shopSignLabel.TextSize = 15
    shopSignLabel.Font = Enum.Font.GothamBold
    shopSignLabel.Parent = shopSignGui

    local shopLight = Instance.new("PointLight")
    shopLight.Color = Color3.fromRGB(80, 255, 110)
    shopLight.Range = 20
    shopLight.Brightness = 1.8
    shopLight.Parent = shopCounter

    local shopPrompt = Instance.new("ProximityPrompt")
    shopPrompt.Name = "ShopPrompt"
    shopPrompt.ActionText = "Jual Semua Loot"
    shopPrompt.ObjectText = "Old Grimwald"
    shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
    shopPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    shopPrompt.HoldDuration = 0
    shopPrompt.MaxActivationDistance = 16
    shopPrompt.RequiresLineOfSight = false
    shopPrompt.Parent = shopCounter

    shopPrompt.Triggered:Connect(function(triggeringPlayer: Player)
        if not ShopService then
            ShopService = require(game:GetService("ServerScriptService").Services.ShopService)
        end
        if ShopService and ShopService.SellAllInventory then
            ShopService.SellAllInventory(triggeringPlayer)
        end
    end)

    createPart({
        Size = Vector3.new(2, 3, 1.5),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 2.5, 12)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(90, 70, 50),
        Name = "ShopkeeperBody",
        Parent = hubModel,
    })
    local keeperHead = createPart({
        Size = Vector3.new(1.8, 1.8, 1.8),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 4.9, 12)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(220, 180, 140),
        Shape = Enum.PartType.Ball,
        Name = "ShopkeeperHead",
        Parent = hubModel,
    })
    local keeperHat = createPart({
        Size = Vector3.new(2.2, 1.6, 2.2),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 6.1, 12)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(20, 15, 25),
        Shape = Enum.PartType.Cylinder,
        Name = "ShopkeeperHat",
        Parent = hubModel,
    })
    keeperHat.CFrame = keeperHat.CFrame * CFrame.Angles(0, 0, math.rad(90))

    local keeperGui = Instance.new("BillboardGui")
    keeperGui.Size = UDim2.new(5, 0, 1, 0)
    keeperGui.StudsOffset = Vector3.new(0, 3.5, 0)
    keeperGui.AlwaysOnTop = true
    keeperGui.Parent = keeperHead

    local keeperLabel = Instance.new("TextLabel")
    keeperLabel.Size = UDim2.new(1, 0, 1, 0)
    keeperLabel.BackgroundTransparency = 1
    keeperLabel.Text = "🧙 Old Grimwald"
    keeperLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
    keeperLabel.TextStrokeTransparency = 0
    keeperLabel.TextSize = 14
    keeperLabel.Font = Enum.Font.GothamBold
    keeperLabel.Parent = keeperGui

    local comingSoonPositions = {
        { pos = Vector3.new(0, 2, -18), label = "⚗️ CRAFTING\n(Coming Soon)" },
        { pos = Vector3.new(18, 2, 0),  label = "🔁 TRADING\n(Coming Soon)" },
        { pos = Vector3.new(-18, 2, 0), label = "⚔️ CHALLENGE\n(Coming Soon)" },
    }
    for _, info in ipairs(comingSoonPositions) do
        local sign = createPart({
            Size = Vector3.new(7, 4.5, 1),
            CFrame = CFrame.new(HUB_CENTER + info.pos),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(55, 40, 30),
            Parent = hubModel,
        })
        local signGui2 = Instance.new("BillboardGui")
        signGui2.Size = UDim2.new(6, 0, 2.5, 0)
        signGui2.StudsOffset = Vector3.new(0, 3.5, 0)
        signGui2.AlwaysOnTop = true
        signGui2.Parent = sign

        local signLbl = Instance.new("TextLabel")
        signLbl.Size = UDim2.new(1, 0, 1, 0)
        signLbl.BackgroundTransparency = 1
        signLbl.Text = info.label
        signLbl.TextColor3 = Color3.fromRGB(180, 160, 130)
        signLbl.TextStrokeTransparency = 0
        signLbl.TextSize = 14
        signLbl.Font = Enum.Font.GothamBold
        signLbl.Parent = signGui2
    end

    return hubModel
end

function WorldService.Init(shopServiceRef: any)
    ShopService = shopServiceRef

    local existing = Workspace:FindFirstChild("MarketHub")
    if existing then existing:Destroy() end
    local hubModel = buildMarketHub()

    -- FIXED: Added debounce to prevent notification spam when standing on ShopZone
    local shopZone = hubModel:FindFirstChild("ShopZone") :: BasePart?
    if shopZone then
        shopZone.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player and ShopService and ShopService.SellAllInventory then
                local now = os.clock()
                if (now - (shopZoneDebounce[player.UserId] or 0)) < 1.5 then
                    return
                end
                shopZoneDebounce[player.UserId] = now
                ShopService.SellAllInventory(player)
            end
        end)
    end

    Players.PlayerRemoving:Connect(function(player)
        shopZoneDebounce[player.UserId] = nil
    end)

    task.spawn(function()
        local crystalPart = hubModel:FindFirstChild("ObeliskCrystal") :: BasePart?
        if not crystalPart then return end
        while crystalPart.Parent do
            local tUp = TweenService:Create(crystalPart, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = Vector3.new(3.5, 3.5, 3.5),
            })
            tUp:Play()
            task.wait(1.5)
            local tDown = TweenService:Create(crystalPart, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = Vector3.new(2.5, 2.5, 2.5),
            })
            tDown:Play()
            task.wait(1.5)
        end
    end)
end

return WorldService