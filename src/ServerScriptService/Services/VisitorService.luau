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

