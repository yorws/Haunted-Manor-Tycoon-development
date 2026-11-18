--!strict
--[[
    PlotService.luau
    Manages 6 battle arena plots arranged in a circle around the Central Market Hub.
    Includes native PlotSpawn so players always spawn directly inside their own arena.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)

local PlotService = {}

local plotsFolder: Folder
local playerPlotMap: { [number]: Model } = {}
local plotOwnerMap: { [Model]: Player? } = {}
local bellDebounce: { [number]: number } = {}

local DataService: any
local EconomyService: any
local ShopService: any
local MonsterService: any

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

local function generatePlot(plotIndex: number, plotCFrame: CFrame): Model
    local plotModel = Instance.new("Model")
    plotModel.Name = "Plot_" .. tostring(plotIndex)
    plotModel:SetAttribute("PlotIndex", plotIndex)

    -- Arena Ground
    local ground = createPart({
        Size = BalanceConfig.General.PlotSize or Vector3.new(86, 2, 86),
        CFrame = plotCFrame,
        Material = Enum.Material.Slate,
        Color = Color3.fromRGB(32, 34, 38),
        Name = "PlotBase",
        Parent = plotModel,
    })

    -- Native SpawnLocation inside the Arena (facing Cursed Rift)
    local spawnPos = (plotCFrame * CFrame.new(0, 1.2, -10)).Position
    local lookTarget = (plotCFrame * CFrame.new(0, 1.2, 28)).Position
    local plotSpawn = Instance.new("SpawnLocation")
    plotSpawn.Name = "PlotSpawn"
    plotSpawn.Size = Vector3.new(6, 0.4, 6)
    plotSpawn.CFrame = CFrame.lookAt(spawnPos, lookTarget)
    plotSpawn.Anchored = true
    plotSpawn.CanCollide = false
    plotSpawn.Transparency = 1
    plotSpawn.Neutral = false
    plotSpawn.Enabled = false
    plotSpawn.Duration = 0
    plotSpawn.Parent = plotModel

    -- Arena Perimeter Walls
    createPart({
        Size = Vector3.new(88, 4, 2),
        CFrame = plotCFrame * CFrame.new(0, 2, -43),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 55, 62),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 4, 88),
        CFrame = plotCFrame * CFrame.new(-43, 2, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 55, 62),
        Parent = plotModel,
    })
    createPart({
        Size = Vector3.new(2, 4, 88),
        CFrame = plotCFrame * CFrame.new(43, 2, 0),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(55, 55, 62),
        Parent = plotModel,
    })

    -- Tactical Cover Pillars in the Arena
    local pillarOffsets = {
        Vector3.new(-16, 4.5, 4),
        Vector3.new(16, 4.5, 4),
        Vector3.new(-22, 4.5, -14),
        Vector3.new(22, 4.5, -14),
    }
    for i, offset in ipairs(pillarOffsets) do
        createPart({
            Size = Vector3.new(3.5, 7, 3.5),
            CFrame = plotCFrame * CFrame.new(offset),
            Material = Enum.Material.Cobblestone,
            Color = Color3.fromRGB(65, 60, 72),
            Name = "ArenaPillar_" .. i,
            Parent = plotModel,
        })
    end

    -- Manor Core (Objective to Defend & Upgrade with [E])
    local corePedestal = createPart({
        Size = Vector3.new(10, 2, 10),
        CFrame = plotCFrame * CFrame.new(0, 1.5, -30),
        Material = Enum.Material.Cobblestone,
        Color = Color3.fromRGB(50, 45, 55),
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
    coreLight.Range = 28
    coreLight.Brightness = 2.5
    coreLight.Parent = manorCore

    local coreGui = Instance.new("BillboardGui")
    coreGui.Name = "CoreGui"
    coreGui.Size = UDim2.new(6, 0, 2, 0)
    coreGui.StudsOffset = Vector3.new(0, 6, 0)
    coreGui.AlwaysOnTop = true
    coreGui.MaxDistance = 95
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

    -- Wave Summon Bell Pad (Step to summon wave immediately)
    local bellPad = createPart({
        Size = Vector3.new(7, 0.25, 7),
        CFrame = plotCFrame * CFrame.new(20, 1.15, 24),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(190, 40, 40),
        Name = "WaveBellPad",
        CanCollide = false,
        Parent = plotModel,
    })
    local bellGui = Instance.new("BillboardGui")
    bellGui.Name = "BellGui"
    bellGui.Size = UDim2.new(5, 0, 2, 0)
    bellGui.StudsOffset = Vector3.new(0, 4, 0)
    bellGui.AlwaysOnTop = true
    bellGui.MaxDistance = 65
    bellGui.Parent = bellPad

    local bellLabel = Instance.new("TextLabel")
    bellLabel.Name = "BellLabel"
    bellLabel.Size = UDim2.new(1, 0, 1, 0)
    bellLabel.BackgroundTransparency = 1
    bellLabel.Text = "🔔 CURSED BELL\n[Step to Summon Wave]"
    bellLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    bellLabel.TextStrokeTransparency = 0
    bellLabel.TextSize = 15
    bellLabel.Font = Enum.Font.GothamBold
    bellLabel.Parent = bellGui

    -- Monster Spawn Rift
    local riftPad = createPart({
        Size = Vector3.new(32, 0.15, 8),
        CFrame = plotCFrame * CFrame.new(0, 1.08, 34),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(140, 20, 60),
        Name = "MonsterSpawnRift",
        CanCollide = false,
        Parent = plotModel,
    })
    local riftLight = Instance.new("PointLight")
    riftLight.Color = Color3.fromRGB(255, 40, 80)
    riftLight.Range = 18
    riftLight.Brightness = 2.5
    riftLight.Parent = riftPad

    local riftGui = Instance.new("BillboardGui")
    riftGui.Name = "RiftGui"
    riftGui.Size = UDim2.new(6, 0, 2, 0)
    riftGui.StudsOffset = Vector3.new(0, 3, 0)
    riftGui.AlwaysOnTop = true
    riftGui.MaxDistance = 65
    riftGui.Parent = riftPad

    local riftLabel = Instance.new("TextLabel")
    riftLabel.Name = "RiftLabel"
    riftLabel.Size = UDim2.new(1, 0, 1, 0)
    riftLabel.BackgroundTransparency = 1
    riftLabel.Text = "🌀 CURSED RIFT\n[Monster Spawn Zone]"
    riftLabel.TextColor3 = Color3.fromRGB(255, 80, 120)
    riftLabel.TextStrokeTransparency = 0
    riftLabel.TextSize = 14
    riftLabel.Font = Enum.Font.GothamBold
    riftLabel.Parent = riftGui

    -- Entrance Archway
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
    signGui.MaxDistance = 140
    signGui.Parent = gateArch

    local signLabel = Instance.new("TextLabel")
    signLabel.Name = "SignLabel"
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = string.format("Arena %d: [Vacant]", plotIndex)
    signLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
    signLabel.TextStrokeTransparency = 0
    signLabel.TextSize = 18
    signLabel.Font = Enum.Font.GothamBlack
    signLabel.Parent = signGui

    plotModel.PrimaryPart = ground
    plotModel.Parent = plotsFolder

    PlotService.UpdateCoreLevelPad(plotModel, 1)

    return plotModel
end

function PlotService.Init(dataServiceRef: any, economyServiceRef: any, shopServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    ShopService = shopServiceRef

    -- Remove any leftover static plots in Workspace
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and string.match(child.Name, "^Plot_%d+") then
            child:Destroy()
        end
    end

    local existingPlots = Workspace:FindFirstChild("Plots")
    if existingPlots then
        existingPlots:Destroy()
    end

    plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "Plots"
    plotsFolder.Parent = Workspace

    local PLOT_RADIUS = BalanceConfig.General.PlotRadius or 145
    local NUM_PLOTS = BalanceConfig.General.MaxPlots or 6

    for index = 1, NUM_PLOTS do
        local angle = ((index - 1) * (2 * math.pi / NUM_PLOTS))
        local posX = math.sin(angle) * PLOT_RADIUS
        local posZ = math.cos(angle) * PLOT_RADIUS
        local plotPos = Vector3.new(posX, 1, posZ)

        local lookAway = plotPos + (plotPos - Vector3.new(0, 1, 0))
        local plotCF = CFrame.lookAt(plotPos, lookAway)

        local plotModel = generatePlot(index, plotCF)
        plotOwnerMap[plotModel] = nil
    end

    PlotService.SetupPadListeners()
end

function PlotService.SetupPadListeners()
    for _, plotModel in ipairs(plotsFolder:GetChildren()) do
        if plotModel:IsA("Model") then
            local bellPad = plotModel:FindFirstChild("WaveBellPad") :: Part?
            if bellPad then
                bellPad.Touched:Connect(function(hit)
                    local character = hit.Parent
                    local player = Players:GetPlayerFromCharacter(character)
                    if player and plotOwnerMap[plotModel] == player then
                        local now = os.clock()
                        if (now - (bellDebounce[player.UserId] or 0)) < 1.5 then
                            return
                        end
                        bellDebounce[player.UserId] = now

                        if not MonsterService then
                            local services = ServerScriptService:FindFirstChild("Services")
                            if services then
                                MonsterService = require(services:WaitForChild("MonsterService"))
                            end
                        end
                        if MonsterService and MonsterService.StartWave then
                            MonsterService.StartWave(player, plotModel)
                        end
                    end
                end)
            end
        end
    end
end

function PlotService.AssignPlot(player: Player): Model?
    if not DataService then
        DataService = require(ServerScriptService.Services.DataService)
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

            local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
            if plotSpawn then
                plotSpawn.Enabled = true
                player.RespawnLocation = plotSpawn
            end

            local gate = plotModel:FindFirstChild("EntranceGate")
            if gate then
                local signGui = gate:FindFirstChild("OwnerSign")
                if signGui then
                    local label = signGui:FindFirstChild("SignLabel") :: TextLabel?
                    if label then
                        label.Text = string.format("⚔️ %s's Arena", player.DisplayName)
                        label.TextColor3 = Color3.fromRGB(255, 215, 0)
                    end
                end
            end

            local data = if DataService then DataService.GetData(player) else nil
            if data then
                PlotService.UpdateCoreLevelPad(plotModel, data.CoreLevel or 1)
            end

            local plotEvent = Network.GetEvent("PlotAssigned")
            if plotEvent then
                plotEvent:FireClient(player, plotModel:GetAttribute("PlotIndex") or 1, plotModel)
            end

            return plotModel
        end
    end

    return nil
end

function PlotService.ReleasePlot(player: Player)
    bellDebounce[player.UserId] = nil

    local plotModel = playerPlotMap[player.UserId]
    if not plotModel then return end

    plotOwnerMap[plotModel] = nil
    playerPlotMap[player.UserId] = nil

    plotModel:SetAttribute("OwnerUserId", nil)
    plotModel:SetAttribute("OwnerName", nil)

    local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
    if plotSpawn then
        plotSpawn.Enabled = false
    end

    local gate = plotModel:FindFirstChild("EntranceGate")
    if gate then
        local signGui = gate:FindFirstChild("OwnerSign")
        if signGui then
            local label = signGui:FindFirstChild("SignLabel") :: TextLabel?
            if label then
                label.Text = string.format("Arena %d: [Vacant]", plotModel:GetAttribute("PlotIndex") or 0)
                label.TextColor3 = Color3.fromRGB(200, 200, 210)
            end
        end
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
end

function PlotService.UpdateCoreLevelPad(plotModel: Model, level: number)
    plotModel:SetAttribute("CoreLevel", level)

    local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not manorCore then return end

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
                ShopService = require(ServerScriptService.Services.ShopService)
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
        prompt.ActionText = "Upgrade Core (+HP & +Damage)"
        prompt.ObjectText = string.format("Lv.%d ➔ Lv.%d  (Biaya: %d 🪙)", level, level + 1, nextCost)
        prompt.Enabled = true
    end
end

function PlotService.GetPlayerPlot(player: Player): Model?
    return playerPlotMap[player.UserId]
end

return PlotService