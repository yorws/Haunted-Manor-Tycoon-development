--!strict
--[[
    WorldService.luau
    Builds the Central Market Hub at the center of the map, accessible from all 6 player plots.
    The hub contains a Loot Shop zone (sell monster drops for Coins) and room for future stalls.
    
    Map center: (0, 1, 0) — equidistant from all 6 plots which are arranged in a 2x3 grid.
    Hub sits at Y=1 on a raised circular stone platform.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Modules.Network)

local WorldService = {}

local ShopService: any

local HUB_CENTER = Vector3.new(0, 1, 0) -- Middle of the entire map

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

    -- Main circular stone platform (40 stud radius)
    local platform = createPart({
        Size = Vector3.new(80, 2, 80),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -1, 0)),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 52, 60),
        Name = "HubPlatform",
        Parent = hubModel,
    })

    -- Outer decorative ring (slightly lower, different material)
    createPart({
        Size = Vector3.new(96, 1, 96),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -1.5, 0)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(40, 38, 48),
        Name = "HubRing",
        Parent = hubModel,
    })

    -- Central Obelisk (landmark/waypoint pillar)
    local obelisk = createPart({
        Size = Vector3.new(3, 24, 3),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 12, 0)),
        Material = Enum.Material.Marble,
        Color = Color3.fromRGB(50, 45, 65),
        Name = "MarketObelisk",
        Parent = hubModel,
    })
    -- Glowing crystal top
    local crystal = createPart({
        Size = Vector3.new(2.5, 2.5, 2.5),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 25.5, 0)),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(80, 220, 255),
        Shape = Enum.PartType.Ball,
        Name = "ObeliskCrystal",
        Parent = hubModel,
    })
    local crystalLight = Instance.new("PointLight")
    crystalLight.Color = Color3.fromRGB(80, 220, 255)
    crystalLight.Range = 60
    crystalLight.Brightness = 3
    crystalLight.Parent = crystal

    -- Obelisk sign billboard
    local obeliskGui = Instance.new("BillboardGui")
    obeliskGui.Name = "HubSign"
    obeliskGui.Size = UDim2.new(10, 0, 2, 0)
    obeliskGui.StudsOffset = Vector3.new(0, 16, 0)
    obeliskGui.AlwaysOnTop = true
    obeliskGui.Parent = obelisk

    local hubTitle = Instance.new("TextLabel")
    hubTitle.Size = UDim2.new(1, 0, 1, 0)
    hubTitle.BackgroundTransparency = 1
    hubTitle.Text = "🏛️ HAUNTED MARKET\n[Sell Loot • Trade • More Coming Soon]"
    hubTitle.TextColor3 = Color3.fromRGB(180, 240, 255)
    hubTitle.TextStrokeTransparency = 0
    hubTitle.TextSize = 15
    hubTitle.Font = Enum.Font.GothamBlack
    hubTitle.Parent = obeliskGui

    -- 4 corner lantern pillars for atmosphere
    local lanternPositions = {
        Vector3.new(-30, 7, -30),
        Vector3.new(30, 7, -30),
        Vector3.new(-30, 7, 30),
        Vector3.new(30, 7, 30),
    }
    local lanternColors = {
        Color3.fromRGB(255, 100, 50),
        Color3.fromRGB(80, 180, 255),
        Color3.fromRGB(220, 80, 255),
        Color3.fromRGB(80, 255, 140),
    }
    for i, lpos in ipairs(lanternPositions) do
        local pillar = createPart({
            Size = Vector3.new(2, 14, 2),
            CFrame = CFrame.new(HUB_CENTER + lpos),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(50, 48, 58),
            Parent = hubModel,
        })
        local lanternHead = createPart({
            Size = Vector3.new(2.8, 2.8, 2.8),
            CFrame = CFrame.new(HUB_CENTER + lpos + Vector3.new(0, 7.4, 0)),
            Material = Enum.Material.Neon,
            Color = lanternColors[i],
            Parent = hubModel,
        })
        local lLight = Instance.new("PointLight")
        lLight.Color = lanternColors[i]
        lLight.Range = 25
        lLight.Brightness = 2
        lLight.Parent = lanternHead
    end

    -- === LOOT SHOP ZONE (South of obelisk, Z+) ===
    -- Stall canopy
    local shopStall = createPart({
        Size = Vector3.new(20, 1, 14),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 7, 28)),
        Material = Enum.Material.WoodPlanks,
        Color = Color3.fromRGB(80, 40, 25),
        Name = "ShopStallRoof",
        Parent = hubModel,
    })
    -- Stall counter
    local shopCounter = createPart({
        Size = Vector3.new(14, 3, 3),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 2, 24)),
        Material = Enum.Material.Wood,
        Color = Color3.fromRGB(90, 55, 30),
        Name = "ShopCounter",
        Parent = hubModel,
    })
    -- Shop floor zone (the interactable area; ShopZone attribute used by client)
    local shopZone = createPart({
        Size = Vector3.new(18, 0.3, 14),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 0.15, 30)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(50, 180, 70),
        CanCollide = false,
        Name = "ShopZone",
        Parent = hubModel,
    })
    shopZone:SetAttribute("IsShopZone", true)

    -- Glowing shop sign
    local shopSignGui = Instance.new("BillboardGui")
    shopSignGui.Name = "ShopSignGui"
    shopSignGui.Size = UDim2.new(9, 0, 2.5, 0)
    shopSignGui.StudsOffset = Vector3.new(0, 7, 0)
    shopSignGui.AlwaysOnTop = true
    shopSignGui.Parent = shopCounter

    local shopSignLabel = Instance.new("TextLabel")
    shopSignLabel.Name = "ShopSignLabel"
    shopSignLabel.Size = UDim2.new(1, 0, 1, 0)
    shopSignLabel.BackgroundTransparency = 1
    shopSignLabel.Text = "🏪 LOOT SHOP\n[Press E to Sell Monster Loot]"
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

    -- Shopkeeper NPC dummy (decorative)
    local keeperBody = createPart({
        Size = Vector3.new(2, 3, 1.5),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 2.5, 20)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(90, 70, 50),
        Name = "ShopkeeperBody",
        Parent = hubModel,
    })
    local keeperHead = createPart({
        Size = Vector3.new(1.8, 1.8, 1.8),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 4.9, 20)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(220, 180, 140),
        Shape = Enum.PartType.Ball,
        Name = "ShopkeeperHead",
        Parent = hubModel,
    })
    local keeperHat = createPart({
        Size = Vector3.new(2.2, 1.6, 2.2),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 6.1, 20)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(20, 15, 25),
        Shape = Enum.PartType.Cylinder,
        Name = "ShopkeeperHat",
        Parent = hubModel,
    })
    keeperHat.CFrame = keeperHat.CFrame * CFrame.Angles(0, 0, math.rad(90))

    -- Shopkeeper nameplate
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

    -- [RESERVED ZONES] Future stalls on other sides:
    -- North (Z-): Reserved for future upgrade/crafting stall
    -- East (X+): Reserved for future trading stall
    -- West (X-): Reserved for future challenge/event stall

    -- Placeholder "Coming Soon" signs for other 3 stall positions
    local comingSoonPositions = {
        { pos = Vector3.new(0, 2, -28), label = "⚗️ CRAFTING\n(Coming Soon)" },
        { pos = Vector3.new(28, 2, 0),  label = "🔁 TRADING\n(Coming Soon)" },
        { pos = Vector3.new(-28, 2, 0), label = "⚔️ CHALLENGE\n(Coming Soon)" },
    }
    for _, info in ipairs(comingSoonPositions) do
        local sign = createPart({
            Size = Vector3.new(8, 5, 1),
            CFrame = CFrame.new(HUB_CENTER + info.pos),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(55, 40, 30),
            Parent = hubModel,
        })
        local signGui2 = Instance.new("BillboardGui")
        signGui2.Size = UDim2.new(6, 0, 2.5, 0)
        signGui2.StudsOffset = Vector3.new(0, 4, 0)
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

    -- Build Central Market Hub
    -- Remove old hub if any (e.g., from previous play session in Studio)
    local existing = Workspace:FindFirstChild("MarketHub")
    if existing then existing:Destroy() end
    local hubModel = buildMarketHub()

    -- Wire server-side ShopZone touch for selling (server authority)
    local shopZone = hubModel:FindFirstChild("ShopZone") :: BasePart?
    if shopZone then
        shopZone.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player and ShopService and ShopService.SellAllInventory then
                ShopService.SellAllInventory(player)
            end
        end)
    end

    -- Pulsing crystal animation
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

