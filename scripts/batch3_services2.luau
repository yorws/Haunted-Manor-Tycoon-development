-- Batch sync: batch3_services2
local updated = {}
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("PlotService")
    target.Source = [==[
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

    -- Plot Ground (90 x 90 studs)
    local ground = createPart({
        Size = Vector3.new(90, 2, 90),
        CFrame = plotCFrame,
        Material = Enum.Material.Slate,
        Color = Color3.fromRGB(35, 38, 35),
        Name = "PlotBase",
        Parent = plotModel,
    })

    -- Plot Boundary Curbs (Left, Right, Back; Front is open facing Market Hub)
    createPart({
        Size = Vector3.new(92, 3, 2),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -45),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 92),
        CFrame = plotCFrame * CFrame.new(-45, 1.5, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 92),
        CFrame = plotCFrame * CFrame.new(45, 1.5, 0),
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
    coreLabel.Text = "🔮 MANOR CORE\nHP: 500 / 500"
    coreLabel.TextColor3 = Color3.fromRGB(240, 180, 255)
    coreLabel.TextStrokeTransparency = 0
    coreLabel.TextSize = 16
    coreLabel.Font = Enum.Font.GothamBold
    coreLabel.Parent = coreGui

    -- Coin Vault Pad (Collects visitor coins)
    local vaultPad = createPart({
        Size = Vector3.new(7, 0.2, 7),
        CFrame = plotCFrame * CFrame.new(-12, 1.1, 35),
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

    -- Wave Summon Bell Pad (Summons next wave early for Souls)
    local bellPad = createPart({
        Size = Vector3.new(7, 0.2, 7),
        CFrame = plotCFrame * CFrame.new(12, 1.1, 35),
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

    -- Plot Entrance Gate & Welcome Sign (At front Z = 44, facing Market Hub)
    local gateArch = createPart({
        Size = Vector3.new(16, 12, 2),
        CFrame = plotCFrame * CFrame.new(0, 6, 44),
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
    plotSpawn.CFrame = plotCFrame * CFrame.new(0, 1.2, 38)
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
    -- Radius = 105 studs. Front entrance gate faces inward directly towards Market Hub!
    local PLOT_RADIUS = 105
    local NUM_PLOTS = 6

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
                label.Text = "🔮 MANOR CORE\nHP: 500 / 500"
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
    -- Proximity E-key system handles visual upgrade prompt
end

function PlotService.GetPlayerPlot(player: Player): Model?
    return playerPlotMap[player.UserId]
end

return PlotService
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("ShopService")
    target.Source = [==[
--!strict
--[[
    ShopService.luau
    Handles:
    1. Selling inventory monster drops for Coins
    2. Upgrading Manor Core Level (up to Level 20, +150 HP per level)
    3. Core Skills management:
       - Level 10: Spectral Retaliation (When HP < 50%, zaps 10 nearest monsters for 175 dmg, 35s CD)
       - Level 20: Ghost Cloak (When HP < 35%, becomes invincible for 5s, 50s CD)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local ShopService = {}

local DataService: any
local EconomyService: any
local PlotService: any
local MonsterService: any

-- Skill runtime state per plot model
type PlotSkillState = {
    LastL10Trigger: number,
    LastL20Trigger: number,
    IsGhostCloaked: boolean,
    CloakExpiresAt: number,
}

local plotSkillStates: { [Model]: PlotSkillState } = {}

function ShopService.Init(dataServiceRef: any, economyServiceRef: any, plotServiceRef: any, monsterServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    PlotService = plotServiceRef
    MonsterService = monsterServiceRef

    -- RemoteFunction: RequestSellInventory
    local sellFn = Network.GetFunction("RequestSellInventory")
    sellFn.OnServerInvoke = function(player: Player)
        return ShopService.SellAllInventory(player)
    end

    -- RemoteFunction: RequestCoreLevelUp
    local levelUpFn = Network.GetFunction("RequestCoreLevelUp")
    levelUpFn.OnServerInvoke = function(player: Player)
        return ShopService.UpgradeCore(player)
    end
end

function ShopService.GetSkillState(plotModel: Model): PlotSkillState
    if not plotSkillStates[plotModel] then
        plotSkillStates[plotModel] = {
            LastL10Trigger = 0,
            LastL20Trigger = 0,
            IsGhostCloaked = false,
            CloakExpiresAt = 0,
        }
    end
    return plotSkillStates[plotModel]
end

function ShopService.IsGhostCloaked(plotModel: Model): boolean
    local s = plotSkillStates[plotModel]
    if not s then return false end
    if s.IsGhostCloaked then
        if os.clock() > s.CloakExpiresAt then
            s.IsGhostCloaked = false
            -- Reset core transparency
            local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
            if core then
                core.Transparency = 0
            end
            return false
        end
        return true
    end
    return false
end

-- Sells all monster loot in the player's inventory for coins
function ShopService.SellAllInventory(player: Player): (boolean, number, string)
    local data = DataService.GetData(player)
    if not data then return false, 0, "No player data." end

    local inv = data.Inventory
    if not inv then return false, 0, "Inventory empty." end

    local totalCoins = 0
    local totalItems = 0

    -- Lookup table for prices
    local priceMap: { [string]: number } = {}
    for _, drop in pairs(BalanceConfig.MonsterDrops) do
        priceMap[drop.ItemId] = drop.SellPrice
    end

    for itemId, count in pairs(inv) do
        if count > 0 and priceMap[itemId] then
            totalCoins += (priceMap[itemId] * count)
            totalItems += count
        end
    end

    if totalCoins <= 0 or totalItems <= 0 then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, "🛒 Your inventory has no loot to sell! Defeat monsters first.", Color3.fromRGB(240, 200, 80))
        return false, 0, "No items to sell."
    end

    -- Clear sold items
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Inventory = {}
    end)

    EconomyService.AddCoins(player, totalCoins, true)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("💰 Sold %d monster loot for +%d Coins!", totalItems, totalCoins), Color3.fromRGB(80, 255, 120))

    return true, totalCoins, "Items sold successfully."
end

-- Upgrades Manor Core level
function ShopService.UpgradeCore(player: Player): (boolean, number, string)
    local data = DataService.GetData(player)
    if not data then return false, 0, "Data not loaded." end

    local currentLvl = data.CoreLevel or 1
    local maxLvl = BalanceConfig.CoreLevels.MaxLevel

    if currentLvl >= maxLvl then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, "🔮 Manor Core is already at MAX LEVEL (Level 20)!", Color3.fromRGB(255, 215, 0))
        return false, currentLvl, "Max level reached."
    end

    local cost = BalanceConfig.CoreLevels.GetUpgradeCost(currentLvl)
    if data.Coins < cost then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, string.format("❌ Need %d Coins to upgrade Manor Core! (You have %d)", cost, data.Coins), Color3.fromRGB(255, 80, 80))
        return false, currentLvl, "Insufficient coins."
    end

    EconomyService.DeductCoins(player, cost)

    local newLevel = currentLvl + 1
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.CoreLevel = newLevel
    end)

    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        MonsterService.ApplyCoreLevel(plot, newLevel)
        PlotService.UpdateCoreLevelPad(plot, newLevel)
    end

    local newMaxHp = BalanceConfig.CoreLevels.GetMaxHp(newLevel)
    local skillUnlockMsg = ""
    if newLevel == 10 then
        skillUnlockMsg = "\n⚡ UNLOCKED SKILL: Spectral Retaliation! (Auto zaps 10 monsters when HP < 50%)"
    elseif newLevel == 20 then
        skillUnlockMsg = "\n🛡️ UNLOCKED SKILL: Ghost Cloak! (Auto invulnerable for 5s when HP < 35%)"
    end

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("🔮 Manor Core upgraded to Level %d! Max HP: %d!%s", newLevel, newMaxHp, skillUnlockMsg), Color3.fromRGB(200, 100, 255))

    EconomyService.SyncClient(player)
    return true, newLevel, "Core upgraded."
end

-- Checks and fires Level 10 and Level 20 skills during active combat
function ShopService.CheckSkills(player: Player, plotModel: Model, state: any)
    local data = DataService.GetData(player)
    if not data then return end

    local level = data.CoreLevel or 1
    local now = os.clock()
    local skillState = ShopService.GetSkillState(plotModel)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local hpPct = state.CoreHealth / state.CoreMaxHealth

    -- 1. Level 10 Skill: Spectral Retaliation (HP < 50%, zaps 10 nearest monsters)
    if level >= 10 and hpPct < 0.50 then
        local l10Config = BalanceConfig.CoreLevels.Skills.Level10
        if (now - skillState.LastL10Trigger) >= l10Config.Cooldown then
            skillState.LastL10Trigger = now

            -- Find up to 10 active monsters within range
            local targets: { { monster: Model, dist: number } } = {}
            for _, monster in ipairs(state.ActiveMonsters) do
                if monster and monster.Parent and monster.PrimaryPart then
                    local hum = monster:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local d = (monster.PrimaryPart.Position - core.Position).Magnitude
                        if d <= l10Config.Range then
                            table.insert(targets, { monster = monster, dist = d })
                        end
                    end
                end
            end

            table.sort(targets, function(a, b) return a.dist < b.dist end)

            local hitCount = 0
            local combatVisual = Network.GetEvent("CombatVisual")
            for i = 1, math.min(#targets, l10Config.TargetCount) do
                local target = targets[i].monster
                local hum = target:FindFirstChildOfClass("Humanoid")
                local targetRoot = target.PrimaryPart
                if hum and targetRoot then
                    hum:TakeDamage(l10Config.Damage)
                    hitCount += 1
                    combatVisual:FireAllClients(core.Position, targetRoot.Position, true)
                end
            end

            if hitCount > 0 then
                local notif = Network.GetEvent("Notification")
                notif:FireClient(player, string.format("⚡ SPECTRAL RETALIATION! Manor Core zapped %d monsters for %d damage!", hitCount, l10Config.Damage), Color3.fromRGB(130, 240, 255))
            end
        end
    end

    -- 2. Level 20 Skill: Ghost Cloak (HP < 35%, becomes invincible for 5s)
    if level >= 20 and hpPct < 0.35 then
        local l20Config = BalanceConfig.CoreLevels.Skills.Level20
        if (now - skillState.LastL20Trigger) >= l20Config.Cooldown and not skillState.IsGhostCloaked then
            skillState.LastL20Trigger = now
            skillState.IsGhostCloaked = true
            skillState.CloakExpiresAt = now + l20Config.Duration

            -- Ghostly visual effect on Core
            core.Transparency = 0.75
            local notif = Network.GetEvent("Notification")
            notif:FireClient(player, "👻 GHOST CLOAK ACTIVATED! Manor Core is invulnerable for 5 seconds!", Color3.fromRGB(220, 160, 255))

            task.delay(l20Config.Duration, function()
                if plotModel.Parent and core.Parent then
                    skillState.IsGhostCloaked = false
                    core.Transparency = 0
                    local endNotif = Network.GetEvent("Notification")
                    endNotif:FireClient(player, "🛡️ Ghost Cloak expired.", Color3.fromRGB(180, 180, 200))
                end
            end)
        end
    end
end

function ShopService.ClearPlot(plotModel: Model)
    plotSkillStates[plotModel] = nil
end

return ShopService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("VisitorService")
    target.Source = [==[
--!strict
--[[
    VisitorService.luau
    Spawns spooky NPC visitors who tour unlocked rooms, react with spooky comments,
    and pay admission coins directly into the player's Manor Vault.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local VisitorService = {}

local activeVisitors: { [number]: { Model } } = {}
local isRunning = false

local DataService: any
local EconomyService: any
local PlotService: any

-- Color palettes for visitor outfits
local COAT_COLORS = {
    Color3.fromRGB(150, 140, 130), -- Vintage Trench
    Color3.fromRGB(80, 95, 120),   -- Navy Inspector
    Color3.fromRGB(130, 70, 70),   -- Crimson Velvet
    Color3.fromRGB(60, 60, 60),    -- Gothic Black
    Color3.fromRGB(220, 200, 160), -- Tourist Khaki
}

local VISITOR_QUOTES = {
    "😱 This place gives me goosebumps!",
    "👻 Did you see that shadow move?!",
    "🪙 Best haunted tour ever! Take my money!",
    "⚡ Wow, look at the craftsmanship!",
    "✨ Cursed, but aesthetically pleasing!",
    "🕯️ Mind if I snap a photo of this phantom?",
}

local function createVisitorModel(name: string): Model
    local model = Instance.new("Model")
    model.Name = "Visitor_" .. name

    local color = COAT_COLORS[math.random(1, #COAT_COLORS)]

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = color
    torso.Material = Enum.Material.SmoothPlastic
    torso.CanCollide = true
    torso.Parent = model

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.Shape = Enum.PartType.Ball
    head.Color = Color3.fromRGB(240, 215, 190)
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
    head.Parent = model

    local neckWeld = Instance.new("WeldConstraint")
    neckWeld.Part0 = torso
    neckWeld.Part1 = head
    neckWeld.Parent = torso

    -- Legs
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(0.9, 2, 0.9)
    leftLeg.Color = Color3.fromRGB(40, 40, 45)
    leftLeg.Material = Enum.Material.SmoothPlastic
    leftLeg.CanCollide = false
    leftLeg.CFrame = torso.CFrame * CFrame.new(-0.55, -1.9, 0)
    leftLeg.Parent = model

    local leftWeld = Instance.new("WeldConstraint")
    leftWeld.Part0 = torso
    leftWeld.Part1 = leftLeg
    leftWeld.Parent = torso

    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(0.9, 2, 0.9)
    rightLeg.Color = Color3.fromRGB(40, 40, 45)
    rightLeg.Material = Enum.Material.SmoothPlastic
    rightLeg.CanCollide = false
    rightLeg.CFrame = torso.CFrame * CFrame.new(0.55, -1.9, 0)
    rightLeg.Parent = model

    local rightWeld = Instance.new("WeldConstraint")
    rightWeld.Part0 = torso
    rightWeld.Part1 = rightLeg
    rightWeld.Parent = torso

    -- Humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 12
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent = model

    -- Speech Billboard
    local chatGui = Instance.new("BillboardGui")
    chatGui.Name = "VisitorChatGui"
    chatGui.Size = UDim2.new(5, 0, 1.5, 0)
    chatGui.StudsOffset = Vector3.new(0, 3, 0)
    chatGui.AlwaysOnTop = true
    chatGui.Parent = head

    local chatLabel = Instance.new("TextLabel")
    chatLabel.Name = "ChatLabel"
    chatLabel.Size = UDim2.new(1, 0, 1, 0)
    chatLabel.BackgroundTransparency = 0.3
    chatLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    chatLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatLabel.TextSize = 13
    chatLabel.Font = Enum.Font.GothamMedium
    chatLabel.Text = "Tourist"
    chatLabel.Parent = chatGui

    model.PrimaryPart = torso
    return model
end

local function showVisitorQuote(visitor: Model, text: string)
    local head = visitor:FindFirstChild("Head")
    if not head then return end
    local chatGui = head:FindFirstChild("VisitorChatGui")
    if not chatGui then return end
    local label = chatGui:FindFirstChild("ChatLabel") :: TextLabel?
    if label then
        label.Text = text
    end
end

local function runVisitorRoutine(player: Player, plotModel: Model)
    local data = DataService.GetData(player)
    if not data or not data.UnlockedUpgrades["Foyer"] then
        return -- Visitors only arrive once Foyer is unlocked
    end

    local visitorsList = activeVisitors[player.UserId]
    if not visitorsList then
        visitorsList = {}
        activeVisitors[player.UserId] = visitorsList
    end

    if #visitorsList >= BalanceConfig.Visitors.MaxVisitorsPerPlot then
        return
    end

    local gate = plotModel:FindFirstChild("EntranceGate") :: BasePart?
    if not gate then return end

    local spawnPos = gate.Position + Vector3.new(math.random(-4, 4), 1, 8)
    local visitor = createVisitorModel("Tourist_" .. tostring(math.random(100, 999)))
    table.insert(visitorsList, visitor)

    visitor:SetPrimaryPartCFrame(CFrame.new(spawnPos))
    visitor.Parent = plotModel

    task.spawn(function()
        local humanoid = visitor:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        -- Gather tour waypoints from unlocked upgrades
        local waypoints: { Vector3 } = {}
        local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart
        if not plotBase then return end

        for _, u in ipairs(BalanceConfig.Upgrades) do
            if data.UnlockedUpgrades[u.Id] then
                local worldPos = (plotBase.CFrame * CFrame.new(u.PadPosition)).Position
                table.insert(waypoints, worldPos)
            end
        end

        -- Walk through waypoints
        for _, pos in ipairs(waypoints) do
            if not visitor.Parent or not humanoid or humanoid.Health <= 0 then break end
            humanoid:MoveTo(pos)
            humanoid.MoveToFinished:Wait()

            -- Paid room fee
            local quote = VISITOR_QUOTES[math.random(1, #VISITOR_QUOTES)]
            showVisitorQuote(visitor, quote)

            -- Calculate ticket payment
            local totalPay = 10
            for _, u in ipairs(BalanceConfig.Upgrades) do
                if data.UnlockedUpgrades[u.Id] and u.IncomePerVisitor then
                    totalPay += u.IncomePerVisitor
                end
            end

            EconomyService.DepositToVault(player, totalPay)

            -- Update Vault Pad label
            local vaultPad = plotModel:FindFirstChild("VaultPad")
            if vaultPad then
                local vaultGui = vaultPad:FindFirstChild("VaultGui")
                if vaultGui then
                    local vLabel = vaultGui:FindFirstChild("VaultLabel") :: TextLabel?
                    if vLabel then
                        local pending = EconomyService.GetVaultBalance(player)
                        vLabel.Text = string.format("💰 MANOR VAULT\n🪙 %d Coins\n[Step to Collect]", pending)
                    end
                end
            end

            task.wait(math.random(2, 4))
        end

        -- Exit through the gate
        if visitor.Parent and humanoid then
            humanoid:MoveTo(spawnPos)
            showVisitorQuote(visitor, "👋 Leaving Manor...")
            humanoid.MoveToFinished:Wait()
        end

        -- Cleanup
        local idx = table.find(visitorsList, visitor)
        if idx then table.remove(visitorsList, idx) end
        visitor:Destroy()
    end)
end

function VisitorService.Init(dataServiceRef: any, economyServiceRef: any, plotServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    PlotService = plotServiceRef

    isRunning = true
    task.spawn(function()
        while isRunning do
            task.wait(BalanceConfig.Visitors.BaseSpawnInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                local plot = PlotService.GetPlayerPlot(player)
                if plot then
                    runVisitorRoutine(player, plot)
                end
            end
        end
    end)
end

function VisitorService.ClearPlayerVisitors(player: Player)
    local list = activeVisitors[player.UserId]
    if list then
        for _, v in ipairs(list) do
            if v and v.Parent then
                v:Destroy()
            end
        end
        activeVisitors[player.UserId] = nil
    end
end

return VisitorService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("WorldService")
    target.Source = [==[
--!strict
--[[
    WorldService.luau
    Builds the Central Market Hub at the center of the map (0, 1, 0).
    Surrounded closely by all 6 player plots (Hexagonal layout, radius 105 studs).
    Includes stone pathways connecting the Market Hub directly to every plot entrance!
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
        Size = Vector3.new(65, 2, 65),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -0.9, 0)),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 52, 60),
        Name = "HubPlatform",
        Parent = hubModel,
    })

    -- Outer decorative ring
    createPart({
        Size = Vector3.new(78, 1, 78),
        CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -1.4, 0)),
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(40, 38, 48),
        Name = "HubRing",
        Parent = hubModel,
    })

    -- Central Obelisk (landmark/waypoint pillar)
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

    -- Obelisk sign billboard
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

    -- 6 Stone Walkways radiating directly from the Market Hub to each of the 6 plots
    local NUM_PLOTS = 6
    local PLOT_RADIUS = 105
    for i = 1, NUM_PLOTS do
        local angle = ((i - 1) * (2 * math.pi / NUM_PLOTS))
        local targetX = math.sin(angle) * (PLOT_RADIUS - 44) -- Reaches front gate of plot
        local targetZ = math.cos(angle) * (PLOT_RADIUS - 44)
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

        -- Road lanterns along the pathway
        local lantern1 = createPart({
            Size = Vector3.new(1.2, 5, 1.2),
            CFrame = CFrame.new(midPos + Vector3.new(-5, 2.5, 0)),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(45, 35, 25),
            Parent = hubModel,
        })
        local lamp1 = createPart({
            Size = Vector3.new(1.4, 1.4, 1.4),
            CFrame = lantern1.CFrame * CFrame.new(0, 3, 0),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(255, 180, 90),
            Parent = hubModel,
        })
        local lgt = Instance.new("PointLight")
        lgt.Color = Color3.fromRGB(255, 180, 90)
        lgt.Range = 15
        lgt.Brightness = 1.8
        lgt.Parent = lamp1
    end

    -- === LOOT SHOP STALL (Facing players entering from plots) ===
    local shopStall = createPart({
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

    -- Shopkeeper NPC dummy
    local keeperBody = createPart({
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

    -- Future reserved stalls with signs
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
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("ServerMain")
    target.Source = [==[
--!strict
--[[
    ServerMain.server.luau
    Root server-side bootstrap script for Haunted Manor Tycoon.
    Orchestrates service initialization, player lifecycle, and authoritative handlers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require Network & Configs
local Network = require(ReplicatedStorage.Modules.Network)
local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)

-- Require Services
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemDropService = require(Services:WaitForChild("ItemDropService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local VisitorService = require(Services:WaitForChild("VisitorService"))
local MonsterService = require(Services:WaitForChild("MonsterService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))

print("========================================")
print("  Initializing Haunted Manor Tycoon...  ")
print("========================================")

-- 1. Initialize Network Remotes
Network.InitServer()

-- 2. Wire and Initialize Services
EconomyService.Init(DataService)
ItemDropService.Init(DataService, EconomyService)
ShopService.Init(DataService, EconomyService, PlotService, MonsterService)
WorldService.Init(ShopService)
PlotService.Init(DataService, EconomyService, ShopService)
VisitorService.Init(DataService, EconomyService, PlotService)
MonsterService.Init(DataService, EconomyService, PlotService, ItemDropService, ShopService)
CombatService.Init(DataService)
MonetizationService.Init(DataService, EconomyService)

-- 3. Register Data Handshake Remote
local getPlayerDataFn = Network.GetFunction("GetPlayerData")
getPlayerDataFn.OnServerInvoke = function(player: Player)
    return DataService.GetData(player)
end

-- 4. Player Lifecycle Handlers
local function onPlayerAdded(player: Player)
    print(string.format("[ServerMain] Player joined: %s (%d)", player.Name, player.UserId))

    -- Load persistent or default data
    local data = DataService.LoadData(player)

    -- Check GamePass ownership
    MonetizationService.CheckPlayerPasses(player)

    -- Assign a plot
    local plot = PlotService.AssignPlot(player)
    if plot then
        MonsterService.InitPlotWave(player, plot)
    end

    -- Character lifecycle
    local function onCharacterAdded(character: Model)
        CombatService.GiveWeapon(player)

        task.spawn(function()
            local assignedPlot = PlotService.GetPlayerPlot(player) or plot
            if not assignedPlot then
                assignedPlot = PlotService.AssignPlot(player)
            end
            if assignedPlot then
                local manorCore = assignedPlot:FindFirstChild("ManorCore") :: BasePart?
                local spawnPart = assignedPlot:FindFirstChild("PlotSpawn") :: BasePart?
                for _ = 1, 20 do
                    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if hrp then
                        if manorCore then
                            character:PivotTo(manorCore.CFrame * CFrame.new(0, 3, 14))
                        elseif spawnPart then
                            character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
                        end
                        break
                    end
                    task.wait(0.1)
                end
            end
        end)
    end

    if player.Character then
        task.spawn(onCharacterAdded, player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)

    -- Send initial data sync to client
    EconomyService.SyncClient(player)
end

local function onPlayerRemoving(player: Player)
    print(string.format("[ServerMain] Player left: %s", player.Name))

    VisitorService.ClearPlayerVisitors(player)
    MonsterService.ClearPlayerWave(player)
    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        ShopService.ClearPlot(plot)
    end
    PlotService.ReleasePlot(player)
    CombatService.ClearPlayer(player)
    EconomyService.ClearPlayer(player)
    DataService.ReleaseSession(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle any players already connected (e.g. fast Studio start)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- 5. Start Persistent Autosave
DataService.StartAutosave()

print("[ServerMain] Haunted Manor Tycoon server ready!")

]==]
    table.insert(updated, target:GetFullName())
end
return 'Synced batch batch3_services2 (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
