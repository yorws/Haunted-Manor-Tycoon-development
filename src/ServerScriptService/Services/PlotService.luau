--!strict
--[[
    PlotService.luau
    Manages 6 tycoon plots arranged in a hexagon/circle around the Central Market Hub!
    Every plot faces inward towards the central Market Hub at (0, 1, 0).
    Radius from center: 110 studs (very close, short walk to/from market).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local PlotService = {}

local plotsFolder: Folder = (Workspace:FindFirstChild("Plots") or (function()
    local f = Instance.new("Folder")
    f.Name = "Plots"
    f.Parent = Workspace
    return f
end)()) :: Folder
local playerPlotMap: { [number]: Model } = {}
local plotOwnerMap: { [Model]: Player? } = {}

local DataService: any
local EconomyService: any
local ShopService: any

-- Helper to create sturdy anchored parts
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

-- Procedural Room Builder: Constructs stylized primitive models for each upgrade
local function buildRoomModel(plotModel: Model, upgradeId: string, plotCFrame: CFrame): Model
    local roomModel = Instance.new("Model")
    roomModel.Name = "Upgrade_" .. upgradeId
    roomModel.Parent = plotModel:FindFirstChild("BuiltUpgrades") or plotModel

    if upgradeId == "Foyer" then
        -- Grand Gothic Entryway Arch and Chandelier
        local floor = createPart({
            Size = Vector3.new(24, 1, 28),
            CFrame = plotCFrame * CFrame.new(0, 0.5, 5),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(60, 45, 35),
            Name = "FoyerFloor",
            Parent = roomModel,
        })
        -- Left Wall
        createPart({
            Size = Vector3.new(2, 12, 28),
            CFrame = plotCFrame * CFrame.new(-12, 6, 5),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(50, 50, 55),
            Parent = roomModel,
        })
        -- Right Wall
        createPart({
            Size = Vector3.new(2, 12, 28),
            CFrame = plotCFrame * CFrame.new(12, 6, 5),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(50, 50, 55),
            Parent = roomModel,
        })
        -- Roof Arch
        createPart({
            Size = Vector3.new(26, 2, 28),
            CFrame = plotCFrame * CFrame.new(0, 13, 5),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(40, 30, 25),
            Parent = roomModel,
        })
        -- Spooky Chandelier
        local chandelier = createPart({
            Size = Vector3.new(3, 1, 3),
            CFrame = plotCFrame * CFrame.new(0, 10, 5),
            Material = Enum.Material.Metal,
            Color = Color3.fromRGB(30, 30, 30),
            Parent = roomModel,
        })
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 170, 70)
        light.Range = 22
        light.Brightness = 2
        light.Parent = chandelier

    elseif upgradeId == "GraveyardGarden" then
        -- Fenced cemetery with crooked tombstones
        local grassPatch = createPart({
            Size = Vector3.new(28, 0.8, 28),
            CFrame = plotCFrame * CFrame.new(-28, 0.4, 10),
            Material = Enum.Material.Grass,
            Color = Color3.fromRGB(45, 60, 45),
            Parent = roomModel,
        })
        local offsets = { Vector3.new(-24, 2.5, 6), Vector3.new(-32, 2.5, 12), Vector3.new(-26, 2.5, 18) }
        for i, pos in ipairs(offsets) do
            local stone = createPart({
                Size = Vector3.new(3, 4, 1),
                CFrame = plotCFrame * CFrame.new(pos) * CFrame.Angles(0, math.rad((i * 17) % 30 - 15), math.rad(5)),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(80, 80, 85),
                Name = "Tombstone_" .. i,
                Parent = roomModel,
            })
            local cross = createPart({
                Size = Vector3.new(2, 0.6, 1.1),
                CFrame = stone.CFrame * CFrame.new(0, 1, 0),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(80, 80, 85),
                Parent = roomModel,
            })
        end
        local trunk = createPart({
            Size = Vector3.new(2, 10, 2),
            CFrame = plotCFrame * CFrame.new(-36, 5, 10) * CFrame.Angles(0, 0, math.rad(8)),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(35, 25, 20),
            Parent = roomModel,
        })

    elseif upgradeId == "CryptChamber" then
        local cryptBase = createPart({
            Size = Vector3.new(26, 1, 26),
            CFrame = plotCFrame * CFrame.new(28, 0.5, 10),
            Material = Enum.Material.Slate,
            Color = Color3.fromRGB(55, 55, 65),
            Parent = roomModel,
        })
        local sarcophagus = createPart({
            Size = Vector3.new(6, 3, 10),
            CFrame = plotCFrame * CFrame.new(28, 2.5, 10),
            Material = Enum.Material.Marble,
            Color = Color3.fromRGB(90, 85, 95),
            Name = "Sarcophagus",
            Parent = roomModel,
        })
        local lid = createPart({
            Size = Vector3.new(7, 1, 11),
            CFrame = sarcophagus.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(10)),
            Material = Enum.Material.Marble,
            Color = Color3.fromRGB(110, 105, 115),
            Parent = roomModel,
        })
        local glow = Instance.new("PointLight")
        glow.Color = Color3.fromRGB(60, 255, 120)
        glow.Range = 16
        glow.Brightness = 2.5
        glow.Parent = sarcophagus

    elseif upgradeId == "HauntedLibrary" then
        local libraryFloor = createPart({
            Size = Vector3.new(24, 1, 24),
            CFrame = plotCFrame * CFrame.new(-25, 0.5, -20),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(45, 30, 25),
            Parent = roomModel,
        })
        local shelf = createPart({
            Size = Vector3.new(22, 10, 3),
            CFrame = plotCFrame * CFrame.new(-25, 5.5, -31),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(35, 20, 15),
            Parent = roomModel,
        })
        local book = createPart({
            Size = Vector3.new(2.5, 0.6, 3),
            CFrame = plotCFrame * CFrame.new(-25, 5, -20) * CFrame.Angles(math.rad(15), math.rad(25), 0),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(180, 80, 240),
            Name = "FloatingGrimoire",
            Parent = roomModel,
        })
        local bookLight = Instance.new("PointLight")
        bookLight.Color = Color3.fromRGB(190, 90, 255)
        bookLight.Range = 14
        bookLight.Brightness = 2
        bookLight.Parent = book

    elseif upgradeId == "SeanceParlor" then
        local parlorFloor = createPart({
            Size = Vector3.new(24, 1, 24),
            CFrame = plotCFrame * CFrame.new(25, 0.5, -20),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(35, 25, 35),
            Parent = roomModel,
        })
        local tablePart = createPart({
            Size = Vector3.new(8, 2.5, 8),
            CFrame = plotCFrame * CFrame.new(25, 2, -20),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(25, 15, 25),
            Shape = Enum.PartType.Cylinder,
            Parent = roomModel,
        })
        tablePart.CFrame = plotCFrame * CFrame.new(25, 2, -20) * CFrame.Angles(0, 0, math.rad(90))
        local crystalBall = createPart({
            Size = Vector3.new(2.5, 2.5, 2.5),
            CFrame = plotCFrame * CFrame.new(25, 4.8, -20),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(220, 120, 255),
            Shape = Enum.PartType.Ball,
            Name = "CrystalBall",
            Parent = roomModel,
        })
        local ballLight = Instance.new("PointLight")
        ballLight.Color = Color3.fromRGB(220, 100, 255)
        ballLight.Range = 18
        ballLight.Brightness = 3
        ballLight.Parent = crystalBall

    elseif upgradeId == "GargoyleSentry" then
        local pillar = createPart({
            Size = Vector3.new(4, 8, 4),
            CFrame = plotCFrame * CFrame.new(-38, 4, 28),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(70, 70, 75),
            Parent = roomModel,
        })
        local gargoyleHead = createPart({
            Size = Vector3.new(3, 3, 3),
            CFrame = pillar.CFrame * CFrame.new(0, 5, 0),
            Material = Enum.Material.Slate,
            Color = Color3.fromRGB(90, 80, 70),
            Name = "GargoyleHead",
            Parent = roomModel,
        })
        local eyeLight = Instance.new("PointLight")
        eyeLight.Color = Color3.fromRGB(255, 90, 0)
        eyeLight.Range = 12
        eyeLight.Brightness = 3
        eyeLight.Parent = gargoyleHead

    elseif upgradeId == "HolyAltar" then
        local altarBase = createPart({
            Size = Vector3.new(8, 2.5, 8),
            CFrame = plotCFrame * CFrame.new(38, 1.5, 28),
            Material = Enum.Material.Marble,
            Color = Color3.fromRGB(220, 220, 230),
            Parent = roomModel,
        })
        local relic = createPart({
            Size = Vector3.new(2, 4, 2),
            CFrame = altarBase.CFrame * CFrame.new(0, 3, 0),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(255, 235, 130),
            Name = "HolyRelic",
            Parent = roomModel,
        })
        local holyLight = Instance.new("PointLight")
        holyLight.Color = Color3.fromRGB(255, 235, 120)
        holyLight.Range = 25
        holyLight.Brightness = 3.5
        holyLight.Parent = relic
    end

    return roomModel
end

-- Builds a single plot base, manor core, vault pad, wave bell, and purchase pads
local function generatePlot(plotIndex: number, plotCFrame: CFrame): Model
    local plotModel = Instance.new("Model")
    plotModel.Name = "Plot_" .. tostring(plotIndex)
    plotModel:SetAttribute("PlotIndex", plotIndex)

    -- Plot Ground (86 x 86 studs - prevents collision between neighboring plots)
    local ground = createPart({
        Size = BalanceConfig.General.PlotSize or Vector3.new(86, 2, 86),
        CFrame = plotCFrame,
        Material = Enum.Material.Slate,
        Color = Color3.fromRGB(35, 38, 35),
        Name = "PlotBase",
        Parent = plotModel,
    })

    -- Plot Boundary Curbs (Left, Right, Back; Front is open facing Market Hub)
    createPart({
        Size = Vector3.new(88, 3, 2),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -43),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 88),
        CFrame = plotCFrame * CFrame.new(-43, 1.5, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 88),
        CFrame = plotCFrame * CFrame.new(43, 1.5, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })

    -- Manor Core (The Heart of the plot, placed towards back Z = -30)
    local corePedestal = createPart({
        Size = Vector3.new(10, 2, 10),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -30),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(50, 45, 50),
        Name = "CorePedestal",
        Parent = plotModel,
    })
    local manorCore = createPart({
        Size = Vector3.new(5, 7, 5),
        CFrame = corePedestal.CFrame * CFrame.new(0, 4.5, 0),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(170, 60, 240),
        Name = "ManorCore",
        Parent = plotModel,
    })
    local coreLight = Instance.new("PointLight")
    coreLight.Color = Color3.fromRGB(180, 70, 255)
    coreLight.Range = 25
    coreLight.Brightness = 2.5
    coreLight.Parent = manorCore

    -- Core Billboard
    local coreGui = Instance.new("BillboardGui")
    coreGui.Name = "CoreGui"
    coreGui.Size = UDim2.new(6, 0, 2, 0)
    coreGui.StudsOffset = Vector3.new(0, 6, 0)
    coreGui.AlwaysOnTop = true
    coreGui.Parent = manorCore

    local coreLabel = Instance.new("TextLabel")
    coreLabel.Name = "CoreLabel"
    coreLabel.Size = UDim2.new(1, 0, 1, 0)
    coreLabel.BackgroundTransparency = 1
    coreLabel.Text = "🔮 MANOR CORE [Lv. 1]\nHP: 500 / 500"
    coreLabel.TextColor3 = Color3.fromRGB(240, 180, 255)
    coreLabel.TextStrokeTransparency = 0
    coreLabel.TextSize = 16
    coreLabel.Font = Enum.Font.GothamBold
    coreLabel.Parent = coreGui

    -- Coin Vault Pad (Collects visitor coins - positioned safely to the side)
    local vaultPad = createPart({
        Size = Vector3.new(7, 0.2, 7),
        CFrame = plotCFrame * CFrame.new(-22, 1.1, 33),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(245, 200, 40),
        Name = "VaultPad",
        CanCollide = false,
        Parent = plotModel,
    })
    local vaultGui = Instance.new("BillboardGui")
    vaultGui.Name = "VaultGui"
    vaultGui.Size = UDim2.new(5, 0, 2, 0)
    vaultGui.StudsOffset = Vector3.new(0, 4, 0)
    vaultGui.AlwaysOnTop = true
    vaultGui.Parent = vaultPad

    local vaultLabel = Instance.new("TextLabel")
    vaultLabel.Name = "VaultLabel"
    vaultLabel.Size = UDim2.new(1, 0, 1, 0)
    vaultLabel.BackgroundTransparency = 1
    vaultLabel.Text = "💰 MANOR VAULT\n[Step to Collect]"
    vaultLabel.TextColor3 = Color3.fromRGB(255, 225, 80)
    vaultLabel.TextStrokeTransparency = 0
    vaultLabel.TextSize = 15
    vaultLabel.Font = Enum.Font.GothamBold
    vaultLabel.Parent = vaultGui

    -- Wave Summon Bell Pad (Summons next wave early for Souls - positioned safely to the side)
    local bellPad = createPart({
        Size = Vector3.new(7, 0.2, 7),
        CFrame = plotCFrame * CFrame.new(22, 1.1, 33),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(180, 40, 40),
        Name = "WaveBellPad",
        CanCollide = false,
        Parent = plotModel,
    })
    local bellGui = Instance.new("BillboardGui")
    bellGui.Name = "BellGui"
    bellGui.Size = UDim2.new(5, 0, 2, 0)
    bellGui.StudsOffset = Vector3.new(0, 4, 0)
    bellGui.AlwaysOnTop = true
    bellGui.Parent = bellPad

    local bellLabel = Instance.new("TextLabel")
    bellLabel.Name = "BellLabel"
    bellLabel.Size = UDim2.new(1, 0, 1, 0)
    bellLabel.BackgroundTransparency = 1
    bellLabel.Text = "🔔 CURSED BELL\n[Summon Monster Wave]"
    bellLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    bellLabel.TextStrokeTransparency = 0
    bellLabel.TextSize = 15
    bellLabel.Font = Enum.Font.GothamBold
    bellLabel.Parent = bellGui

    -- Cursed Rift [Monster Incursion Zone] (Visual glowing portal pad inside the plot where monsters spawn)
    local riftPad = createPart({
        Size = Vector3.new(28, 0.1, 8),
        CFrame = plotCFrame * CFrame.new(0, 1.05, 34),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(130, 25, 60),
        Name = "MonsterSpawnRift",
        CanCollide = false,
        Parent = plotModel,
    })
    local riftLight = Instance.new("PointLight")
    riftLight.Color = Color3.fromRGB(255, 40, 80)
    riftLight.Range = 16
    riftLight.Brightness = 2
    riftLight.Parent = riftPad

    local riftGui = Instance.new("BillboardGui")
    riftGui.Name = "RiftGui"
    riftGui.Size = UDim2.new(6, 0, 2, 0)
    riftGui.StudsOffset = Vector3.new(0, 3, 0)
    riftGui.AlwaysOnTop = true
    riftGui.Parent = riftPad

    local riftLabel = Instance.new("TextLabel")
    riftLabel.Name = "RiftLabel"
    riftLabel.Size = UDim2.new(1, 0, 1, 0)
    riftLabel.BackgroundTransparency = 1
    riftLabel.Text = "🌀 CURSED RIFT\n[Monster Incursion Zone]"
    riftLabel.TextColor3 = Color3.fromRGB(255, 80, 120)
    riftLabel.TextStrokeTransparency = 0
    riftLabel.TextSize = 13
    riftLabel.Font = Enum.Font.GothamBold
    riftLabel.Parent = riftGui

    -- Plot Entrance Gate & Welcome Sign (At front Z = 42, facing Market Hub)
    local gateArch = createPart({
        Size = Vector3.new(18, 12, 2),
        CFrame = plotCFrame * CFrame.new(0, 6, 42),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(45, 45, 50),
        Name = "EntranceGate",
        Parent = plotModel,
    })
    local signGui = Instance.new("BillboardGui")
    signGui.Name = "OwnerSign"
    signGui.Size = UDim2.new(12, 0, 2.5, 0)
    signGui.StudsOffset = Vector3.new(0, 5, 0)
    signGui.AlwaysOnTop = true
    signGui.Parent = gateArch

    local signLabel = Instance.new("TextLabel")
    signLabel.Name = "SignLabel"
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = string.format("Plot %d: [Vacant Manor]", plotIndex)
    signLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
    signLabel.TextStrokeTransparency = 0
    signLabel.TextSize = 18
    signLabel.Font = Enum.Font.GothamBlack
    signLabel.Parent = signGui

    -- Spawn Location for plot owner
    local plotSpawn = Instance.new("SpawnLocation")
    plotSpawn.Name = "PlotSpawn"
    plotSpawn.Size = Vector3.new(6, 0.4, 6)
    plotSpawn.CFrame = plotCFrame * CFrame.new(0, 1.2, 36)
    plotSpawn.Anchored = true
    plotSpawn.CanCollide = false
    plotSpawn.Transparency = 1
    plotSpawn.Enabled = false
    plotSpawn.Parent = plotModel

    -- Containers
    local builtFolder = Instance.new("Folder")
    builtFolder.Name = "BuiltUpgrades"
    builtFolder.Parent = plotModel

    local padsFolder = Instance.new("Folder")
    padsFolder.Name = "Pads"
    padsFolder.Parent = plotModel

    -- Create Purchase Pads for each upgrade defined in BalanceConfig
    for _, upgrade in ipairs(BalanceConfig.Upgrades) do
        local pad = createPart({
            Size = Vector3.new(6, 0.2, 6),
            CFrame = plotCFrame * CFrame.new(upgrade.PadPosition),
            Material = Enum.Material.Neon,
            Color = upgrade.Color,
            Name = "Pad_" .. upgrade.Id,
            CanCollide = false,
            Parent = padsFolder,
        })
        pad:SetAttribute("UpgradeId", upgrade.Id)
        pad:SetAttribute("Cost", upgrade.Cost)
        pad:SetAttribute("Currency", upgrade.Currency)

        local padGui = Instance.new("BillboardGui")
        padGui.Name = "PadGui"
        padGui.Size = UDim2.new(6, 0, 2.5, 0)
        padGui.StudsOffset = Vector3.new(0, 3.5, 0)
        padGui.AlwaysOnTop = true
        padGui.Parent = pad

        local padLabel = Instance.new("TextLabel")
        padLabel.Name = "PadLabel"
        padLabel.Size = UDim2.new(1, 0, 1, 0)
        padLabel.BackgroundTransparency = 1
        local icon = if upgrade.Currency == "Souls" then "👻" else "🪙"
        padLabel.Text = string.format("%s\n%s %d %s\n[Step to Buy]", upgrade.DisplayName, icon, upgrade.Cost, upgrade.Currency)
        padLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        padLabel.TextStrokeTransparency = 0
        padLabel.TextSize = 14
        padLabel.Font = Enum.Font.GothamBold
        padLabel.Parent = padGui
    end

    plotModel.PrimaryPart = ground
    plotModel.Parent = plotsFolder

    -- Attach native ProximityPrompt to Manor Core
    PlotService.UpdateCoreLevelPad(plotModel, 1)

    return plotModel
end

function PlotService.Init(dataServiceRef: any, economyServiceRef: any, shopServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    ShopService = shopServiceRef

    plotsFolder = Workspace:FindFirstChild("Plots") :: Folder
    if not plotsFolder then
        plotsFolder = Instance.new("Folder")
        plotsFolder.Name = "Plots"
        plotsFolder.Parent = Workspace
    else
        plotsFolder:ClearAllChildren()
    end

    -- Circular/Hexagonal layout: 6 plots surrounding the Central Market Hub at (0, 1, 0)
    -- Radius = 145 studs. Front entrance gate faces inward directly towards Market Hub!
    -- With plot size 86x86, this provides a clean 27+ stud gap between neighboring plots (ZERO collision!).
    local PLOT_RADIUS = BalanceConfig.General.PlotRadius or 145
    local NUM_PLOTS = BalanceConfig.General.MaxPlots or 6

    for index = 1, NUM_PLOTS do
        local angle = ((index - 1) * (2 * math.pi / NUM_PLOTS))
        local posX = math.sin(angle) * PLOT_RADIUS
        local posZ = math.cos(angle) * PLOT_RADIUS
        local plotPos = Vector3.new(posX, 1, posZ)

        -- Orient the plot so that +Z points towards center (0, 1, 0)
        -- CFrame.lookAt(eye, target) makes -Z point to target.
        -- Since EntranceGate is at +Z in local space, we look AWAY from center:
        local lookAway = plotPos + (plotPos - Vector3.new(0, 1, 0))
        local plotCF = CFrame.lookAt(plotPos, lookAway)

        local plotModel = generatePlot(index, plotCF)
        plotOwnerMap[plotModel] = nil
    end

    -- Register Purchase RemoteFunction
    local requestPurchaseFn = Network.GetFunction("RequestPurchase")
    requestPurchaseFn.OnServerInvoke = function(player: Player, upgradeId: string)
        return PlotService.HandlePurchase(player, upgradeId)
    end

    -- Setup Touch listeners on Pads
    PlotService.SetupPadListeners()
end

function PlotService.SetupPadListeners()
    for _, plotModel in ipairs(plotsFolder:GetChildren()) do
        if plotModel:IsA("Model") then
            -- Vault Pad
            local vaultPad = plotModel:FindFirstChild("VaultPad") :: Part?
            if vaultPad then
                vaultPad.Touched:Connect(function(hit)
                    local character = hit.Parent
                    local player = Players:GetPlayerFromCharacter(character)
                    if player and plotOwnerMap[plotModel] == player then
                        EconomyService.CollectVault(player)
                    end
                end)
            end

            -- Wave Bell Pad
            local bellPad = plotModel:FindFirstChild("WaveBellPad") :: Part?
            if bellPad then
                bellPad.Touched:Connect(function(hit)
                    local character = hit.Parent
                    local player = Players:GetPlayerFromCharacter(character)
                    if player and plotOwnerMap[plotModel] == player then
                        local startWaveFn = Network.GetFunction("RequestStartWave")
                    end
                end)
            end

            -- Purchase Pads
            local padsFolder = plotModel:FindFirstChild("Pads")
            if padsFolder then
                for _, pad in ipairs(padsFolder:GetChildren()) do
                    if pad:IsA("BasePart") then
                        pad.Touched:Connect(function(hit)
                            local character = hit.Parent
                            local player = Players:GetPlayerFromCharacter(character)
                            if player and plotOwnerMap[plotModel] == player then
                                local upgradeId = pad:GetAttribute("UpgradeId") :: string?
                                if upgradeId then
                                    PlotService.HandlePurchase(player, upgradeId)
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
end

function PlotService.HandlePurchase(player: Player, upgradeId: string): (boolean, string)
    local plotModel = playerPlotMap[player.UserId]
    if not plotModel then
        return false, "You do not own a plot!"
    end

    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false, "Character not spawned."
    end

    -- Find upgrade config
    local targetUpgrade: Types.UpgradeDef? = nil
    for _, u in ipairs(BalanceConfig.Upgrades) do
        if u.Id == upgradeId then
            targetUpgrade = u :: any
            break
        end
    end

    if not targetUpgrade then
        return false, "Invalid upgrade ID."
    end

    local padsFolder = plotModel:FindFirstChild("Pads")
    local pad = padsFolder and padsFolder:FindFirstChild("Pad_" .. upgradeId) :: BasePart?
    if not pad then
        return false, "Upgrade pad not found."
    end

    -- Security: Validate distance to pad (< 20 studs)
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local dist = (hrp.Position - pad.Position).Magnitude
    if dist > 20 then
        return false, "Too far from upgrade pad!"
    end

    local data = DataService.GetData(player)
    if not data then
        return false, "Data not loaded."
    end

    if data.UnlockedUpgrades[upgradeId] then
        return false, "Already unlocked!"
    end

    if targetUpgrade.Requires and not data.UnlockedUpgrades[targetUpgrade.Requires] then
        return false, string.format("Must unlock %s first!", targetUpgrade.Requires)
    end

    local cost = targetUpgrade.Cost
    if data.HasVip and targetUpgrade.Currency == "Coins" then
        cost = math.floor(cost * MonetizationConfig.Perks.VipDiscountMultiplier)
    end

    if targetUpgrade.Currency == "Coins" then
        if data.Coins < cost then
            local notif = Network.GetEvent("Notification")
            notif:FireClient(player, string.format("Need %d Coins! (You have %d)", cost, data.Coins), Color3.fromRGB(255, 90, 90))
            return false, "Not enough Coins."
        end
        EconomyService.DeductCoins(player, cost)
    elseif targetUpgrade.Currency == "Souls" then
        if data.Souls < cost then
            local notif = Network.GetEvent("Notification")
            notif:FireClient(player, string.format("Need %d Souls! Defeat monster waves to earn Souls.", cost), Color3.fromRGB(255, 90, 90))
            return false, "Not enough Souls."
        end
        EconomyService.DeductSouls(player, cost)
    end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.UnlockedUpgrades[upgradeId] = true
    end)

    local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart
    buildRoomModel(plotModel, upgradeId, plotBase.CFrame)

    pad.Transparency = 1
    pad.CanCollide = false
    local padGui = pad:FindFirstChild("PadGui")
    if padGui then (padGui :: BillboardGui).Enabled = false end

    PlotService.RefreshPadsVisibility(player)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("Unlocked: %s! 🎉", targetUpgrade.DisplayName), Color3.fromRGB(120, 255, 120))

    EconomyService.SyncClient(player)
    return true, "Success"
end

function PlotService.RefreshPadsVisibility(player: Player)
    local plotModel = playerPlotMap[player.UserId]
    if not plotModel then return end

    local data = DataService.GetData(player)
    if not data then return end

    local padsFolder = plotModel:FindFirstChild("Pads")
    if not padsFolder then return end

    for _, upgrade in ipairs(BalanceConfig.Upgrades) do
        local pad = padsFolder:FindFirstChild("Pad_" .. upgrade.Id) :: BasePart?
        if pad then
            local padGui = pad:FindFirstChild("PadGui") :: BillboardGui?
            local isUnlocked = data.UnlockedUpgrades[upgrade.Id] == true
            local prereqMet = upgrade.Requires == nil or data.UnlockedUpgrades[upgrade.Requires] == true

            if isUnlocked then
                pad.Transparency = 1
                pad.CanCollide = false
                if padGui then padGui.Enabled = false end
            elseif prereqMet then
                pad.Transparency = 0
                pad.CanCollide = false
                if padGui then padGui.Enabled = true end
            else
                pad.Transparency = 1
                pad.CanCollide = false
                if padGui then padGui.Enabled = false end
            end
        end
    end
end

function PlotService.AssignPlot(player: Player): Model?
    if not DataService then
        DataService = require(game:GetService("ServerScriptService").Services.DataService)
    end
    if not EconomyService then
        EconomyService = require(game:GetService("ServerScriptService").Services.EconomyService)
    end
    if not plotsFolder then
        plotsFolder = Workspace:FindFirstChild("Plots") :: Folder
    end
    if not plotsFolder then return nil end

    if playerPlotMap[player.UserId] then
        return playerPlotMap[player.UserId]
    end

    for _, plotModel in ipairs(plotsFolder:GetChildren()) do
        if plotModel:IsA("Model") and plotOwnerMap[plotModel] == nil then
            plotOwnerMap[plotModel] = player
            playerPlotMap[player.UserId] = plotModel

            plotModel:SetAttribute("OwnerUserId", player.UserId)
            plotModel:SetAttribute("OwnerName", player.Name)

            local gate = plotModel:FindFirstChild("EntranceGate")
            if gate then
                local signGui = gate:FindFirstChild("OwnerSign")
                if signGui then
                    local label = signGui:FindFirstChild("SignLabel") :: TextLabel?
                    if label then
                        label.Text = string.format("🏰 %s's Manor", player.DisplayName)
                        label.TextColor3 = Color3.fromRGB(255, 215, 0)
                    end
                end
            end

            local data = if DataService then DataService.GetData(player) else nil
            if data then
                local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart
                for _, upgrade in ipairs(BalanceConfig.Upgrades) do
                    if data.UnlockedUpgrades[upgrade.Id] then
                        buildRoomModel(plotModel, upgrade.Id, plotBase.CFrame)
                    end
                end
                PlotService.UpdateCoreLevelPad(plotModel, data.CoreLevel or 1)
            end

            PlotService.RefreshPadsVisibility(player)

            local plotEvent = Network.GetEvent("PlotAssigned")
            if plotEvent then
                plotEvent:FireClient(player, plotModel:GetAttribute("PlotIndex") or 1, plotModel)
            end

            -- Teleport player directly into their monster arena right by the Manor Core!
            task.spawn(function()
                local character = player.Character or player.CharacterAdded:Wait()
                local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
                local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
                local spawnPart = plotModel:FindFirstChild("PlotSpawn") :: BasePart?
                if hrp then
                    if manorCore then
                        character:PivotTo(manorCore.CFrame * CFrame.new(0, 3, 14))
                    elseif spawnPart then
                        character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
                    end
                end
            end)

            return plotModel
        end
    end

    warn("[PlotService] Server is full! No vacant plots available.")
    return nil
end

function PlotService.ReleasePlot(player: Player)
    local plotModel = playerPlotMap[player.UserId]
    if not plotModel then return end

    plotOwnerMap[plotModel] = nil
    playerPlotMap[player.UserId] = nil

    plotModel:SetAttribute("OwnerUserId", nil)
    plotModel:SetAttribute("OwnerName", nil)

    local gate = plotModel:FindFirstChild("EntranceGate")
    if gate then
        local signGui = gate:FindFirstChild("OwnerSign")
        if signGui then
            local label = signGui:FindFirstChild("SignLabel") :: TextLabel?
            if label then
                label.Text = string.format("Plot %d: [Vacant Manor]", plotModel:GetAttribute("PlotIndex") or 0)
                label.TextColor3 = Color3.fromRGB(200, 200, 210)
            end
        end
    end

    local builtFolder = plotModel:FindFirstChild("BuiltUpgrades")
    if builtFolder then
        builtFolder:ClearAllChildren()
    end

    local manorCore = plotModel:FindFirstChild("ManorCore")
    if manorCore then
        local coreGui = manorCore:FindFirstChild("CoreGui")
        if coreGui then
            local label = coreGui:FindFirstChild("CoreLabel") :: TextLabel?
            if label then
                label.Text = "🔮 MANOR CORE [Lv. 1]\nHP: 500 / 500"
            end
        end
    end
    PlotService.UpdateCoreLevelPad(plotModel, 1)

    local padsFolder = plotModel:FindFirstChild("Pads")
    if padsFolder then
        for _, pad in ipairs(padsFolder:GetChildren()) do
            if pad:IsA("BasePart") then
                local upgradeId = pad:GetAttribute("UpgradeId") :: string
                if upgradeId == "Foyer" then
                    pad.Transparency = 0
                    pad.CanCollide = false
                    local padGui = pad:FindFirstChild("PadGui") :: BillboardGui?
                    if padGui then padGui.Enabled = true end
                else
                    pad.Transparency = 1
                    pad.CanCollide = false
                    local padGui = pad:FindFirstChild("PadGui") :: BillboardGui?
                    if padGui then padGui.Enabled = false end
                end
            end
        end
    end
end

function PlotService.UpdateCoreLevelPad(plotModel: Model, level: number)
    plotModel:SetAttribute("CoreLevel", level)

    local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not manorCore then return end

    -- Update billboard label level heading
    local coreGui = manorCore:FindFirstChild("CoreGui")
    if coreGui then
        local label = coreGui:FindFirstChild("CoreLabel") :: TextLabel?
        if label then
            local currentText = label.Text
            if string.find(currentText, "🔮 MANOR CORE") then
                label.Text = string.gsub(currentText, "🔮 MANOR CORE[^\n]*", string.format("🔮 MANOR CORE [Lv. %d]", level))
            else
                label.Text = string.format("🔮 MANOR CORE [Lv. %d]\nHP: %d / %d", level, 500 + ((level - 1) * 200), 500 + ((level - 1) * 200))
            end
        end
    end

    local prompt = manorCore:FindFirstChild("CoreUpgradePrompt") :: ProximityPrompt?
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = "CoreUpgradePrompt"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.HoldDuration = 0.4
        prompt.MaxActivationDistance = 16
        prompt.RequiresLineOfSight = false
        prompt.Parent = manorCore

        prompt.Triggered:Connect(function(triggeringPlayer: Player)
            local owner = plotOwnerMap[plotModel]
            if owner ~= triggeringPlayer then
                local notif = Network.GetEvent("Notification")
                if notif then
                    notif:FireClient(triggeringPlayer, "⛔ Ini bukan Manor Core milikmu!", Color3.fromRGB(255, 80, 80))
                end
                return
            end

            if not ShopService then
                ShopService = require(game:GetService("ServerScriptService").Services.ShopService)
            end
            if ShopService and ShopService.UpgradeCore then
                ShopService.UpgradeCore(triggeringPlayer)
            end
        end)
    end

    local maxLvl = BalanceConfig.CoreLevels.MaxLevel or 20
    if level >= maxLvl then
        prompt.ActionText = "Max Level"
        prompt.ObjectText = string.format("Manor Core ⭐ Lv.%d (MAX)", level)
        prompt.Enabled = false
    else
        local nextCost = BalanceConfig.CoreLevels.GetUpgradeCost(level)
        prompt.ActionText = "Upgrade Manor Core"
        prompt.ObjectText = string.format("Lv.%d ➔ Lv.%d  (Biaya: %d 🪙)", level, level + 1, nextCost)
        prompt.Enabled = true
    end
end

function PlotService.GetPlayerPlot(player: Player): Model?
    return playerPlotMap[player.UserId]
end

return PlotService
