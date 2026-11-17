local updated = {}
do
    local target = game:GetService("ServerScriptService").Services.ShopService
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
    local target = game:GetService("ServerScriptService").Services.VisitorService
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
    local target = game:GetService("ServerScriptService").Services.WorldService
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
local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)

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
    local NUM_PLOTS = BalanceConfig.General.MaxPlots or 6
    local PLOT_RADIUS = BalanceConfig.General.PlotRadius or 145
    for i = 1, NUM_PLOTS do
        local angle = ((i - 1) * (2 * math.pi / NUM_PLOTS))
        local targetX = math.sin(angle) * (PLOT_RADIUS - 42) -- Reaches front entrance gate of plot
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

        -- Road lanterns aligned symmetrically along the cobblestone edges
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

    -- Native Roblox ProximityPrompt for Old Grimwald Loot Shop
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
    local target = game:GetService("ServerScriptService").ServerMain
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

local Network = require(ReplicatedStorage.Modules.Network)
local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)

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

Network.InitServer()

EconomyService.Init(DataService)
ItemDropService.Init(DataService, EconomyService)
ShopService.Init(DataService, EconomyService, PlotService, MonsterService)
WorldService.Init(ShopService)
PlotService.Init(DataService, EconomyService, ShopService)
VisitorService.Init(DataService, EconomyService, PlotService)
MonsterService.Init(DataService, EconomyService, PlotService, ItemDropService, ShopService)
CombatService.Init(DataService)
MonetizationService.Init(DataService, EconomyService)

local getPlayerDataFn = Network.GetFunction("GetPlayerData")
getPlayerDataFn.OnServerInvoke = function(player: Player)
    return DataService.GetData(player)
end

local processedPlayers: { [number]: boolean } = {}

local function handleNewPlayer(player: Player)
    if processedPlayers[player.UserId] then
        return
    end
    processedPlayers[player.UserId] = true

    print(string.format("[ServerMain] Player joined: %s (%d)", player.Name, player.UserId))
    
    DataService.LoadData(player)
    MonetizationService.CheckPlayerPasses(player)
    
    local plot = PlotService.AssignPlot(player)
    if plot then
        MonsterService.InitPlotWave(player, plot)
    end

    local function onCharacterAdded(character: Model)
        CombatService.GiveWeapon(player)

        task.spawn(function()
            local assignedPlot = PlotService.GetPlayerPlot(player) or plot
            if not assignedPlot then
                assignedPlot = PlotService.AssignPlot(player)
            end
            if assignedPlot then
                local spawnPart = assignedPlot:FindFirstChild("PlotSpawn") :: BasePart?
                local manorCore = assignedPlot:FindFirstChild("ManorCore") :: BasePart?
                for _ = 1, 30 do
                    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if hrp and manorCore then
                        character:PivotTo(manorCore.CFrame * CFrame.new(0, 3, 14))
                        break
                    elseif hrp and spawnPart then
                        character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3.5, 0))
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

    EconomyService.SyncClient(player)
end

local function onPlayerRemoving(player: Player)
    processedPlayers[player.UserId] = nil
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

Players.PlayerAdded:Connect(handleNewPlayer)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(handleNewPlayer, p)
end

DataService.StartAutosave()
print("[ServerMain] Haunted Manor Tycoon server ready!")
]==]
    table.insert(updated, target:GetFullName())
end
return 'Synced (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
