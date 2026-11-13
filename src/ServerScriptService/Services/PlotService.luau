--!strict
--[[
    PlotService.luau
    Manages 6 tycoon plots, procedural plot world generation, plot assignment,
    authoritative upgrade pad purchases, and physical room assembly.
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

local plotsFolder: Folder
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
        -- 3 Tombstones
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
        -- Dead Spooky Tree
        local trunk = createPart({
            Size = Vector3.new(2, 10, 2),
            CFrame = plotCFrame * CFrame.new(-36, 5, 10) * CFrame.Angles(0, 0, math.rad(8)),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(35, 25, 20),
            Parent = roomModel,
        })

    elseif upgradeId == "CryptChamber" then
        -- Underground Stone Tomb & Sarcophagus
        local cryptBase = createPart({
            Size = Vector3.new(26, 1, 26),
            CFrame = plotCFrame * CFrame.new(28, 0.5, 10),
            Material = Enum.Material.Slate,
            Color = Color3.fromRGB(55, 55, 65),
            Parent = roomModel,
        })
        -- Sarcophagus Base & Lid
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
        -- Eerie Green Glow from inside sarcophagus
        local glow = Instance.new("PointLight")
        glow.Color = Color3.fromRGB(60, 255, 120)
        glow.Range = 16
        glow.Brightness = 2.5
        glow.Parent = sarcophagus

    elseif upgradeId == "HauntedLibrary" then
        -- Bookshelves and floating grimoires
        local libraryFloor = createPart({
            Size = Vector3.new(24, 1, 24),
            CFrame = plotCFrame * CFrame.new(-25, 0.5, -20),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(45, 30, 25),
            Parent = roomModel,
        })
        -- Shelf Wall
        local shelf = createPart({
            Size = Vector3.new(22, 10, 3),
            CFrame = plotCFrame * CFrame.new(-25, 5.5, -31),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(35, 20, 15),
            Parent = roomModel,
        })
        -- Floating Tome
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
        -- Occult circle and floating crystal ball
        local parlorFloor = createPart({
            Size = Vector3.new(24, 1, 24),
            CFrame = plotCFrame * CFrame.new(25, 0.5, -20),
            Material = Enum.Material.WoodPlanks,
            Color = Color3.fromRGB(35, 25, 35),
            Parent = roomModel,
        })
        -- Dark Table
        local tablePart = createPart({
            Size = Vector3.new(8, 2.5, 8),
            CFrame = plotCFrame * CFrame.new(25, 2, -20),
            Material = Enum.Material.Wood,
            Color = Color3.fromRGB(25, 15, 25),
            Shape = Enum.PartType.Cylinder,
            Parent = roomModel,
        })
        tablePart.CFrame = plotCFrame * CFrame.new(25, 2, -20) * CFrame.Angles(0, 0, math.rad(90))
        -- Floating Crystal Ball
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
        -- Defense Turret: Stone gargoyle sentinel
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
        -- Glowing Sentinel Eyes
        local eyeLight = Instance.new("PointLight")
        eyeLight.Color = Color3.fromRGB(255, 90, 0)
        eyeLight.Range = 12
        eyeLight.Brightness = 3
        eyeLight.Parent = gargoyleHead

    elseif upgradeId == "HolyAltar" then
        -- Sanctified Holy Relic Altar
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

    -- Plot Ground (110 x 110 studs)
    local ground = createPart({
        Size = Vector3.new(110, 2, 110),
        CFrame = plotCFrame,
        Material = Enum.Material.Slate,
        Color = Color3.fromRGB(35, 38, 35),
        Name = "PlotBase",
        Parent = plotModel,
    })

    -- Plot Boundary Curb
    createPart({
        Size = Vector3.new(112, 3, 2),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -55),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 112),
        CFrame = plotCFrame * CFrame.new(-55, 1.5, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 3, 112),
        CFrame = plotCFrame * CFrame.new(55, 1.5, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(60, 60, 60),
        Parent = plotModel,
    })

    -- Manor Core (The Heart of the plot, defending objective)
    local corePedestal = createPart({
        Size = Vector3.new(10, 2, 10),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -35),
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
        Size = Vector3.new(8, 0.2, 8),
        CFrame = plotCFrame * CFrame.new(-12, 1.1, 40),
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
        Size = Vector3.new(8, 0.2, 8),
        CFrame = plotCFrame * CFrame.new(12, 1.1, 40),
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

    -- Shop Pad removed: Shop is now at the Central Market Hub
    -- Core Level Up Pad removed: Use E-key proximity near ManorCore (see CoreUpgradeController)

    -- Plot Entrance Gate & Welcome Sign
    local gateArch = createPart({
        Size = Vector3.new(16, 12, 2),
        CFrame = plotCFrame * CFrame.new(0, 6, 52),
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
    plotSpawn.CFrame = plotCFrame * CFrame.new(0, 1.2, 45)
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
    end

    -- Create 6 Plots in a 2x3 layout
    local plotSpacingX = 140
    local plotSpacingZ = 140
    local startX = -((3 - 1) * plotSpacingX) / 2
    local startZ = -((2 - 1) * plotSpacingZ) / 2

    local index = 1
    for row = 0, 1 do
        for col = 0, 2 do
            local posX = startX + (col * plotSpacingX)
            local posZ = startZ + (row * plotSpacingZ)
            local plotCF = CFrame.new(posX, 1, posZ)
            local plotModel = generatePlot(index, plotCF)
            plotOwnerMap[plotModel] = nil
            index += 1
        end
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
                        -- Trigger wave via MonsterService if available
                    end
                end)
            end

            -- Shop Pad listener removed: Shop is now at Central Market Hub

            -- Core Level Up Pad listener removed: Handled via E-key proximity in CoreUpgradeController

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

    -- Security: Validate distance to pad (< 18 studs)
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local dist = (hrp.Position - pad.Position).Magnitude
    if dist > 20 then
        return false, "Too far from upgrade pad!"
    end

    -- Check if already unlocked
    local data = DataService.GetData(player)
    if not data then
        return false, "Data not loaded."
    end

    if data.UnlockedUpgrades[upgradeId] then
        return false, "Already unlocked!"
    end

    -- Check prerequisite
    if targetUpgrade.Requires and not data.UnlockedUpgrades[targetUpgrade.Requires] then
        return false, string.format("Must unlock %s first!", targetUpgrade.Requires)
    end

    -- Check cost and currency
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

    -- Unlock upgrade
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.UnlockedUpgrades[upgradeId] = true
    end)

    -- Build physical model
    local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart
    buildRoomModel(plotModel, upgradeId, plotBase.CFrame)

    -- Hide purchased pad
    pad.Transparency = 1
    pad.CanCollide = false
    local padGui = pad:FindFirstChild("PadGui")
    if padGui then (padGui :: BillboardGui).Enabled = false end

    -- Reveal available next pads
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
                -- Already bought: hide
                pad.Transparency = 1
                pad.CanCollide = false
                if padGui then padGui.Enabled = false end
            elseif prereqMet then
                -- Available to buy: show pad (CanCollide = false so players & monsters walk over smoothly)
                pad.Transparency = 0
                pad.CanCollide = false
                if padGui then padGui.Enabled = true end
            else
                -- Locked behind prereq: hide until ready
                pad.Transparency = 1
                pad.CanCollide = false
                if padGui then padGui.Enabled = false end
            end
        end
    end
end

function PlotService.AssignPlot(player: Player): Model?
    -- Check if player already has a plot
    if playerPlotMap[player.UserId] then
        return playerPlotMap[player.UserId]
    end

    -- Find first vacant plot
    for _, plotModel in ipairs(plotsFolder:GetChildren()) do
        if plotModel:IsA("Model") and plotOwnerMap[plotModel] == nil then
            plotOwnerMap[plotModel] = player
            playerPlotMap[player.UserId] = plotModel

            plotModel:SetAttribute("OwnerUserId", player.UserId)
            plotModel:SetAttribute("OwnerName", player.Name)

            -- Update entrance sign
            local gate = plotModel:FindFirstChild("EntranceGate")
            if gate then
                local signGui = gate:FindFirstChild("OwnerSign")
                if signGui then
                    local label = signGui:FindFirstChild("SignLabel") :: TextLabel?
                    if label then
                        label.Text = string.format("🏰 %s's Haunted Manor", player.DisplayName)
                        label.TextColor3 = Color3.fromRGB(255, 215, 0)
                    end
                end
            end

            -- Rebuild saved upgrades
            local data = DataService.GetData(player)
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

            -- Notify client
            local plotEvent = Network.GetEvent("PlotAssigned")
            plotEvent:FireClient(player, plotModel:GetAttribute("PlotIndex") or 1, plotModel)

            -- Teleport player on spawn
            task.spawn(function()
                local character = player.Character or player.CharacterAdded:Wait()
                local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
                local spawnPart = plotModel:FindFirstChild("PlotSpawn") :: BasePart?
                if hrp and spawnPart then
                    hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
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

    -- Reset entrance sign
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

    -- Clear built rooms
    local builtFolder = plotModel:FindFirstChild("BuiltUpgrades")
    if builtFolder then
        builtFolder:ClearAllChildren()
    end

    -- Reset Core HP and level pad
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

    -- Reset pads
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
    -- CoreLevelPad replaced by E-key proximity system; this function is now a no-op
    -- Kept for compatibility with ShopService calls
end

function PlotService.GetPlayerPlot(player: Player): Model?
    return playerPlotMap[player.UserId]
end

return PlotService

