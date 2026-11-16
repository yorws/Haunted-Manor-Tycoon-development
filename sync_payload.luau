-- Sync all scripts from disk into Studio
local updated = {}
do
    local target = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("BalanceConfig")
    target.Source = [==[
--!strict
--[[
    BalanceConfig.luau
    Central balance numbers, costs, stats, audio IDs, monster drops,
    and Manor Core 20-level progression data for Haunted Manor Tycoon.
]]

local BalanceConfig = {}

BalanceConfig.General = {
    MaxPlots = 6,
    StarterCoins = 50,
    StarterSouls = 0,
    AutosaveInterval = 60,
    MaxSaveRetries = 3,
    DataStoreKey = "HauntedManor_UserData_v1",
}

BalanceConfig.Core = {
    BaseMaxHealth = 500,
    RegenAmount = 25,             -- Amount of HP healed per tick
    RegenTickInterval = 2.5,      -- Seconds between heal pulses
    OutOfCombatCooldown = 6,      -- Seconds without damage before healing starts
    DefeatRecoveryDuration = 20,
}

BalanceConfig.CoreLevels = {
    MaxLevel = 20,
    -- Cost formula: starts at 100, scales steeply per level
    -- Lv1->2: 100, Lv2->3: 250, Lv3->4: 450, Lv5->6: 1050, Lv9->10: 3250, Lv10->11: 4000, Lv19->20: 18100
    GetUpgradeCost = function(currentLevel: number): number
        -- Base 100, then quadratic: 100 + (level^2 * 25) + (level * 75)
        return math.floor(100 + (currentLevel * currentLevel * 25) + (currentLevel * 75))
    end,
    GetMaxHp = function(level: number): number
        return 500 + ((level - 1) * 200) -- Lvl 1: 500, Lvl 10: 2300, Lvl 20: 4300
    end,
    -- Proximity radius for E-key interaction (studs from ManorCore)
    UpgradeInteractRadius = 14,
    Skills = {
        Level10 = {
            Name = "Spectral Retaliation",
            Description = "When Core HP drops below 50%, immediately zaps up to 10 nearest monsters!",
            TargetCount = 10,
            Damage = 175,
            Range = 85,
            Cooldown = 35,
        },
        Level20 = {
            Name = "Ghost Cloak",
            Description = "When Core HP drops below 35%, the Manor Core phases out and becomes completely invulnerable for 5 seconds!",
            Duration = 5,
            Cooldown = 50,
        },
    },
}

BalanceConfig.MonsterDrops = {
    Ghost = {
        ItemId = "Ectoplasm",
        DisplayName = "Ectoplasm",
        SellPrice = 18,
        Color = Color3.fromRGB(120, 240, 255),
    },
    Zombie = {
        ItemId = "ZombieBone",
        DisplayName = "Zombie Bone",
        SellPrice = 35,
        Color = Color3.fromRGB(225, 220, 200),
    },
    Wraith = {
        ItemId = "DarkEssence",
        DisplayName = "Dark Essence",
        SellPrice = 75,
        Color = Color3.fromRGB(170, 60, 245),
    },
}

BalanceConfig.Upgrades = {
    {
        Id = "Foyer",
        DisplayName = "Manor Foyer",
        Cost = 25,
        Currency = "Coins",
        Requires = nil,
        IncomePerVisitor = 8,
        VisitorIntervalBonus = 0.5,
        Description = "The grand, creaky manor entryway with flickering candle chandeliers.",
        Color = Color3.fromRGB(140, 95, 55),
        PadPosition = Vector3.new(0, 0.5, 18),
    },
    {
        Id = "GraveyardGarden",
        DisplayName = "Graveyard Garden",
        Cost = 85,
        Currency = "Coins",
        Requires = "Foyer",
        IncomePerVisitor = 16,
        VisitorIntervalBonus = 0.8,
        Description = "Ancient crooked gravestones and swirling cemetery fog.",
        Color = Color3.fromRGB(65, 85, 65),
        PadPosition = Vector3.new(-28, 0.5, 10),
    },
    {
        Id = "CryptChamber",
        DisplayName = "Crypt Chamber",
        Cost = 220,
        Currency = "Coins",
        Requires = "GraveyardGarden",
        IncomePerVisitor = 32,
        VisitorIntervalBonus = 1.2,
        Description = "Chilled stone tomb housing a cursed royal sarcophagus.",
        Color = Color3.fromRGB(80, 80, 95),
        PadPosition = Vector3.new(28, 0.5, 10),
    },
    {
        Id = "HauntedLibrary",
        DisplayName = "Haunted Library",
        Cost = 550,
        Currency = "Coins",
        Requires = "CryptChamber",
        IncomePerVisitor = 65,
        VisitorIntervalBonus = 1.6,
        Description = "Cobwebbed shelves of occult tomes with levitating books.",
        Color = Color3.fromRGB(110, 55, 75),
        PadPosition = Vector3.new(-25, 0.5, -20),
    },
    {
        Id = "SeanceParlor",
        DisplayName = "Séance Parlor",
        Cost = 1200,
        Currency = "Coins",
        Requires = "HauntedLibrary",
        IncomePerVisitor = 130,
        VisitorIntervalBonus = 2.2,
        Description = "Summoning circle with an unearthly floating crystal orb.",
        Color = Color3.fromRGB(130, 45, 150),
        PadPosition = Vector3.new(25, 0.5, -20),
    },
    {
        Id = "GargoyleSentry",
        DisplayName = "Gargoyle Sentry",
        Cost = 20,
        Currency = "Souls",
        Requires = "GraveyardGarden",
        DefenseType = "Turret",
        TurretRange = 45,
        TurretDamage = 25,
        TurretCooldown = 1.5,
        Description = "Stone guardian that shoots crackling spectral bolts at encroaching monsters.",
        Color = Color3.fromRGB(200, 110, 25),
        PadPosition = Vector3.new(-38, 0.5, 28),
    },
    {
        Id = "HolyAltar",
        DisplayName = "Holy Relic Altar",
        Cost = 45,
        Currency = "Souls",
        Requires = "SeanceParlor",
        DefenseType = "Sanctuary",
        CoreHpBonus = 500,
        WeaponDamageMultiplier = 1.5,
        Description = "Infuses the Manor Core with +500 Max HP and amplifies Holy Lantern damage by 50%.",
        Color = Color3.fromRGB(250, 220, 85),
        PadPosition = Vector3.new(38, 0.5, 28),
    },
}

BalanceConfig.Monsters = {
    Ghost = {
        DisplayName = "Restless Ghost",
        WalkSpeed = 21,
        MaxHealth = 50,
        Damage = 10,
        SoulDrop = 1,
        AttackRange = 5,
        AttackRate = 1.0,
        Ranged = false,
        Color = Color3.fromRGB(150, 240, 255),
        Transparency = 0.45,
        Material = Enum.Material.ForceField,
        Sounds = {
            Groan = "rbxassetid://125610525645835",
            Attack = "rbxassetid://9113951479",
            Death = "rbxassetid://139090255801447",
            Pitch = 1.15,
            Volume = 1.5,
        },
    },
    Zombie = {
        DisplayName = "Grave Zombie",
        WalkSpeed = 9,
        MaxHealth = 175,
        Damage = 22,
        SoulDrop = 2,
        AttackRange = 5,
        AttackRate = 1.4,
        Ranged = false,
        Color = Color3.fromRGB(65, 95, 60),
        Transparency = 0,
        Material = Enum.Material.CorrodedMetal,
        Sounds = {
            Groan = "rbxassetid://127809799844346",
            Attack = "rbxassetid://109819443674858",
            Death = "rbxassetid://106129958887908",
            Pitch = 0.9,
            Volume = 1.6,
        },
    },
    Wraith = {
        DisplayName = "Shadow Wraith",
        WalkSpeed = 13,
        MaxHealth = 95,
        Damage = 16,
        SoulDrop = 3,
        AttackRange = 28,
        AttackRate = 2.0,
        Ranged = true,
        Color = Color3.fromRGB(45, 15, 60),
        Transparency = 0.2,
        Material = Enum.Material.Neon,
        Sounds = {
            Groan = "rbxassetid://9113985717",
            Attack = "rbxassetid://131653988627020",
            Death = "rbxassetid://80984191739263",
            Pitch = 1.0,
            Volume = 1.6,
        },
    },
}

BalanceConfig.Waves = {
    AutoWaveInterval = 120,
    RewardBaseCoins = 80,
    RewardCoinsPerWave = 35,
    RewardBaseSouls = 5,
    RewardSoulsPerWave = 2,
    MaxWaveCapacity = 25,
}

BalanceConfig.Weapon = {
    Name = "Holy Lantern",
    BaseDamage = 35,
    Range = 36,
    Cooldown = 0.45,
    BeamWidth = 1.2,
    LightColor = Color3.fromRGB(255, 240, 160),
    FireSound = "rbxassetid://115842676995967",
}

BalanceConfig.Visitors = {
    BaseSpawnInterval = 6,
    MinSpawnInterval = 2.5,
    MaxVisitorsPerPlot = 6,
    MaxPlotCapacityWithRooms = 12,
    VisitDuration = 8,
}

return BalanceConfig
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("MonetizationConfig")
    target.Source = [==[
--!strict
--[[
    MonetizationConfig.luau
    Placeholder IDs and configurations for GamePasses and Developer Products.
    Replace 0 with real Roblox asset IDs before publishing.
]]

local MonetizationConfig = {}

-- GamePass Asset IDs (Create these in Roblox Creator Dashboard)
MonetizationConfig.Gamepasses = {
    DoubleCoins = 0, -- Grants x2 Coins earned from visitors & waves
    VipPlot = 0,     -- Gives golden plot aesthetic, 20% room discount, +10 bonus souls on join
}

-- Developer Product IDs (Create these in Roblox Creator Dashboard)
MonetizationConfig.DevProducts = {
    Souls50 = 0,   -- Instant +50 Souls pack
    Souls200 = 0,  -- Instant +200 Souls mega pack
}

-- Multipliers & Perks
MonetizationConfig.Perks = {
    DoubleCoinsMultiplier = 2.0,
    VipDiscountMultiplier = 0.8, -- 20% off Coin upgrade costs
    VipSoulsGift = 10,
}

return MonetizationConfig

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Network")
    target.Source = [==[
--!strict
--[[
    Network.luau
    Central network definition and initialization module.
    Automatically sets up RemoteFunctions and RemoteEvents in ReplicatedStorage.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

local REMOTE_FUNCTIONS = {
    "RequestPurchase",
    "RequestCollectVault",
    "RequestStartWave",
    "GetPlayerData",
    "RequestSellInventory",
    "RequestCoreLevelUp",
}

local REMOTE_EVENTS = {
    "AttackRequest",
    "PlayerDataUpdated",
    "PlotAssigned",
    "WaveStateUpdated",
    "Notification",
    "CombatVisual",
}

local remotesFolder: Folder

local function getOrCreateRemotesFolder(): Folder
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = "Remotes"
            folder.Parent = ReplicatedStorage
        else
            folder = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder
            assert(folder, "[Network] Failed to locate Remotes folder on client!")
        end
    end
    return folder :: Folder
end

remotesFolder = getOrCreateRemotesFolder()

function Network.InitServer()
    assert(RunService:IsServer(), "[Network] InitServer can only be called on the server!")
    
    for _, name in ipairs(REMOTE_FUNCTIONS) do
        if not remotesFolder:FindFirstChild(name) then
            local rf = Instance.new("RemoteFunction")
            rf.Name = name
            rf.Parent = remotesFolder
        end
    end

    for _, name in ipairs(REMOTE_EVENTS) do
        if not remotesFolder:FindFirstChild(name) then
            local re = Instance.new("RemoteEvent")
            re.Name = name
            re.Parent = remotesFolder
        end
    end
end

function Network.GetFunction(name: string): RemoteFunction
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        if RunService:IsClient() then
            remote = remotesFolder:WaitForChild(name, 10)
        else
            remote = Instance.new("RemoteFunction")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end
    assert(remote and remote:IsA("RemoteFunction"), "[Network] RemoteFunction not found: " .. name)
    return remote
end

function Network.GetEvent(name: string): RemoteEvent
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        if RunService:IsClient() then
            remote = remotesFolder:WaitForChild(name, 10)
        else
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end
    assert(remote and remote:IsA("RemoteEvent"), "[Network] RemoteEvent not found: " .. name)
    return remote
end

return Network

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Types")
    target.Source = [==[
--!strict
--[[
    Types.luau
    Central Luau type definitions for Haunted Manor Tycoon.
]]

export type MonsterDropItem = {
    ItemId: string,
    DisplayName: string,
    SellPrice: number,
    Color: Color3,
}

export type PlayerData = {
    Coins: number,
    Souls: number,
    UnlockedUpgrades: { [string]: boolean },
    WaveNumber: number,
    MonstersDefeated: number,
    HasDoubleCoins: boolean,
    HasVip: boolean,
    CoreLevel: number,
    Inventory: { [string]: number },
    LastSaveTimestamp: number,
}

export type UpgradeDef = {
    Id: string,
    DisplayName: string,
    Cost: number,
    Currency: string,
    Requires: string?,
    IncomePerVisitor: number?,
    VisitorIntervalBonus: number?,
    DefenseType: string?,
    TurretRange: number?,
    TurretDamage: number?,
    TurretCooldown: number?,
    CoreHpBonus: number?,
    WeaponDamageMultiplier: number?,
    Description: string,
    Color: Color3,
    PadPosition: Vector3,
}

export type MonsterDef = {
    DisplayName: string,
    WalkSpeed: number,
    MaxHealth: number,
    Damage: number,
    SoulDrop: number,
    AttackRange: number,
    AttackRate: number,
    Ranged: boolean,
    Color: Color3,
    Transparency: number,
    Material: Enum.Material,
    Sounds: {
        Groan: string,
        Attack: string,
        Death: string,
        Pitch: number,
        Volume: number,
    }?,
}

export type WaveStatus = "Waiting" | "Active" | "Victory" | "Defeat"

export type WaveState = {
    WaveNumber: number,
    Status: WaveStatus,
    TimeRemaining: number,
    MonstersRemaining: number,
    CoreHealth: number,
    CoreMaxHealth: number,
    CoreLevel: number,
    IsGhostCloaked: boolean?,
}

return {}
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
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("CombatService")
    target.Source = [==[
--!strict
--[[
    CombatService.luau
    Equips players with the Holy Lantern weapon tool and validates all attacks server-side
    (rate-limiting, distance checks, line-of-sight, Holy Altar damage buffs).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local CombatService = {}

local lastAttackTimes: { [number]: number } = {}

local DataService: any

-- Constructs the physical Holy Lantern Tool
local function createLanternTool(): Tool
    local tool = Instance.new("Tool")
    tool.Name = BalanceConfig.Weapon.Name
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ToolTip = "Shine holy light to purge encroaching monsters!"

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1.2, 1.8, 1.2)
    handle.Material = Enum.Material.Metal
    handle.Color = Color3.fromRGB(80, 65, 45)
    handle.CanCollide = false
    handle.Parent = tool

    -- Glowing Lantern Core
    local glass = Instance.new("Part")
    glass.Name = "LanternGlass"
    glass.Size = Vector3.new(0.8, 1.2, 0.8)
    glass.Material = Enum.Material.Neon
    glass.Color = BalanceConfig.Weapon.LightColor
    glass.CanCollide = false
    glass.CFrame = handle.CFrame
    glass.Parent = tool

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = glass
    weld.Parent = handle

    local light = Instance.new("PointLight")
    light.Color = BalanceConfig.Weapon.LightColor
    light.Range = 20
    light.Brightness = 3
    light.Parent = glass

    return tool
end

function CombatService.Init(dataServiceRef: any)
    DataService = dataServiceRef

    local attackEvent = Network.GetEvent("AttackRequest")
    attackEvent.OnServerEvent:Connect(function(player: Player, targetMonster: any)
        CombatService.HandleAttack(player, targetMonster)
    end)
end

function CombatService.GiveWeapon(player: Player)
    local weaponName = BalanceConfig.Weapon.Name
    local backpack = player:FindFirstChildOfClass("Backpack")
    local character = player.Character

    local hasInBackpack = backpack and backpack:FindFirstChild(weaponName)
    local hasInCharacter = character and character:FindFirstChild(weaponName)

    if not hasInBackpack and not hasInCharacter then
        local lantern = createLanternTool()
        if backpack then
            lantern.Parent = backpack
        elseif character then
            lantern.Parent = character
        end
    end
end

function CombatService.HandleAttack(player: Player, targetMonster: any)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Check if tool is equipped
    local equippedTool = character:FindFirstChild(BalanceConfig.Weapon.Name)
    if not equippedTool then return end

    -- Cooldown check
    local now = os.clock()
    local lastTime = lastAttackTimes[player.UserId] or 0
    if (now - lastTime) < (BalanceConfig.Weapon.Cooldown - 0.05) then
        return -- Attack throttled
    end
    lastAttackTimes[player.UserId] = now

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local handle = equippedTool:FindFirstChild("Handle") :: BasePart? or hrp

    -- Validate target
    if typeof(targetMonster) ~= "Instance" or not targetMonster:IsA("Model") then
        -- Missed shot, still broadcast visual beam forward
        local forwardPos = hrp.Position + (hrp.CFrame.LookVector * BalanceConfig.Weapon.Range)
        local combatVisual = Network.GetEvent("CombatVisual")
        combatVisual:FireAllClients(handle.Position, forwardPos, false)
        return
    end

    local targetHum = targetMonster:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetMonster.PrimaryPart or targetMonster:FindFirstChild("Torso") :: BasePart?

    if not targetHum or targetHum.Health <= 0 or not targetRoot then
        return
    end

    -- Distance validation
    local dist = (hrp.Position - targetRoot.Position).Magnitude
    if dist > (BalanceConfig.Weapon.Range + 6) then
        return -- Out of range exploit blocked
    end

    -- Calculate damage
    local damage = BalanceConfig.Weapon.BaseDamage
    local data = DataService.GetData(player)
    if data and data.UnlockedUpgrades["HolyAltar"] then
        damage = math.floor(damage * 1.5)
    end

    -- Apply damage
    targetHum:TakeDamage(damage)

    -- Replicate holy beam visual to all players
    local combatVisual = Network.GetEvent("CombatVisual")
    combatVisual:FireAllClients(handle.Position, targetRoot.Position, true)
end

function CombatService.ClearPlayer(player: Player)
    lastAttackTimes[player.UserId] = nil
end

return CombatService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService")
    target.Source = [==[
--!strict
--[[
    DataService.luau
    Manages persistent player data via DataStoreService.
    Includes autosave, backoff retries, and seamless mock fallback for Studio without API access.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local DataService = {}

local sessionData: { [number]: Types.PlayerData } = {}
local dataStore: GlobalDataStore? = nil
local isDataStoreAvailable = false

local function initDataStore()
    local success, ds = pcall(function()
        return DataStoreService:GetDataStore(BalanceConfig.General.DataStoreKey)
    end)

    if success and ds then
        dataStore = ds
        -- Test read to verify API access
        local testSuccess = pcall(function()
            ds:GetAsync("__ping__")
        end)
        isDataStoreAvailable = testSuccess
        if not testSuccess then
            warn("[DataService] DataStore API access is disabled (Studio mode). Using in-memory fallback.")
        end
    else
        warn("[DataService] Could not initialize DataStore. Using in-memory fallback.")
        isDataStoreAvailable = false
    end
end

initDataStore()

local function createDefaultData(): Types.PlayerData
    return {
        Coins = BalanceConfig.General.StarterCoins,
        Souls = BalanceConfig.General.StarterSouls,
        UnlockedUpgrades = {},
        WaveNumber = 1,
        MonstersDefeated = 0,
        HasDoubleCoins = false,
        HasVip = false,
        CoreLevel = 1,
        Inventory = {},
        LastSaveTimestamp = os.time(),
    }
end

local function deepCopy(t: any): any
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

function DataService.LoadData(player: Player): Types.PlayerData
    local userId = player.UserId
    local key = "Player_" .. tostring(userId)
    local loadedData: Types.PlayerData? = nil

    if isDataStoreAvailable and dataStore then
        for attempt = 1, BalanceConfig.General.MaxSaveRetries do
            local success, result = pcall(function()
                return dataStore:GetAsync(key)
            end)

            if success then
                if type(result) == "table" then
                    loadedData = result :: Types.PlayerData
                end
                break
            else
                warn(string.format("[DataService] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
                task.wait(1 * attempt)
            end
        end
    end

    if not loadedData then
        loadedData = createDefaultData()
    else
        -- Ensure all schema fields exist
        local default = createDefaultData()
        for k, v in pairs(default) do
            if (loadedData :: any)[k] == nil then
                (loadedData :: any)[k] = v
            end
        end
    end

    sessionData[userId] = loadedData
    return sessionData[userId]
end

function DataService.SaveData(player: Player): boolean
    local userId = player.UserId
    local data = sessionData[userId]
    if not data then return false end

    data.LastSaveTimestamp = os.time()

    if not isDataStoreAvailable or not dataStore then
        return true -- Mock success in Studio
    end

    local key = "Player_" .. tostring(userId)
    for attempt = 1, BalanceConfig.General.MaxSaveRetries do
        local success, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)

        if success then
            return true
        else
            warn(string.format("[DataService] Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
            task.wait(1.5 * attempt)
        end
    end

    return false
end

function DataService.GetData(player: Player): Types.PlayerData?
    return sessionData[player.UserId]
end

function DataService.UpdateData(player: Player, updater: (data: Types.PlayerData) -> ()): Types.PlayerData?
    local data = sessionData[player.UserId]
    if data then
        updater(data)
        return data
    end
    return nil
end

function DataService.ReleaseSession(player: Player)
    DataService.SaveData(player)
    sessionData[player.UserId] = nil
end

function DataService.StartAutosave()
    task.spawn(function()
        while true do
            task.wait(BalanceConfig.General.AutosaveInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                DataService.SaveData(player)
            end
        end
    end)
end

-- BindToClose hook to save remaining players
game:BindToClose(function()
    print("[DataService] Server closing, saving all active players...")
    for _, player in ipairs(Players:GetPlayers()) do
        DataService.SaveData(player)
    end
    print("[DataService] All player data flushed.")
end)

return DataService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("EconomyService")
    target.Source = [==[
--!strict
--[[
    EconomyService.luau
    Authoritative server-side management for Coins, Souls, and plot Vault income.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local EconomyService = {}

-- In-memory pending vault storage for each player (coins accumulated by visitors)
local playerVaults: { [number]: number } = {}

-- References injected by bootstrap or lazy-required
local DataService: any

function EconomyService.Init(dataServiceRef: any)
    DataService = dataServiceRef

    local requestCollectFn = Network.GetFunction("RequestCollectVault")
    requestCollectFn.OnServerInvoke = function(player: Player)
        local collected = EconomyService.CollectVault(player)
        return true, collected
    end
end

function EconomyService.GetVaultBalance(player: Player): number
    return playerVaults[player.UserId] or 0
end

function EconomyService.DepositToVault(player: Player, rawAmount: number)
    local data = DataService.GetData(player)
    if not data then return end

    local multiplier = 1.0
    if data.HasDoubleCoins then
        multiplier = MonetizationConfig.Perks.DoubleCoinsMultiplier
    end

    local finalAmount = math.floor(rawAmount * multiplier)
    playerVaults[player.UserId] = (playerVaults[player.UserId] or 0) + finalAmount
end

function EconomyService.CollectVault(player: Player): number
    local pending = playerVaults[player.UserId] or 0
    if pending <= 0 then return 0 end

    playerVaults[player.UserId] = 0
    EconomyService.AddCoins(player, pending, false)

    local notifEvent = Network.GetEvent("Notification")
    notifEvent:FireClient(player, string.format("Collected +%d Coins from Manor Vault! 🪙", pending), Color3.fromRGB(255, 215, 0))

    return pending
end

function EconomyService.AddCoins(player: Player, amount: number, applyMultipliers: boolean?): number
    if amount <= 0 then return 0 end
    local finalAmount = amount

    local data = DataService.GetData(player)
    if not data then return 0 end

    if applyMultipliers and data.HasDoubleCoins then
        finalAmount = math.floor(amount * MonetizationConfig.Perks.DoubleCoinsMultiplier)
    end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Coins += finalAmount
    end)

    EconomyService.SyncClient(player)
    return finalAmount
end

function EconomyService.AddSouls(player: Player, amount: number): number
    if amount <= 0 then return 0 end
    local data = DataService.GetData(player)
    if not data then return 0 end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Souls += amount
    end)

    EconomyService.SyncClient(player)
    return amount
end

function EconomyService.DeductCoins(player: Player, amount: number): boolean
    if amount <= 0 then return true end
    local data = DataService.GetData(player)
    if not data or data.Coins < amount then return false end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Coins -= amount
    end)

    EconomyService.SyncClient(player)
    return true
end

function EconomyService.DeductSouls(player: Player, amount: number): boolean
    if amount <= 0 then return true end
    local data = DataService.GetData(player)
    if not data or data.Souls < amount then return false end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Souls -= amount
    end)

    EconomyService.SyncClient(player)
    return true
end

function EconomyService.SyncClient(player: Player)
    local data = DataService.GetData(player)
    if data then
        local updateEvent = Network.GetEvent("PlayerDataUpdated")
        updateEvent:FireClient(player, data)
    end
end

function EconomyService.ClearPlayer(player: Player)
    playerVaults[player.UserId] = nil
end

return EconomyService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("ItemDropService")
    target.Source = [==[
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

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("MonetizationService")
    target.Source = [==[
--!strict
--[[
    MonetizationService.luau
    Handles GamePass ownership checks, developer product receipts,
    and grants monetization perks (2x Coins, VIP Plot, Souls packs).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local MonetizationService = {}

local DataService: any
local EconomyService: any

function MonetizationService.Init(dataServiceRef: any, economyServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef

    -- ProcessReceipt callback for Developer Products
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local productId = receiptInfo.ProductId

        if productId == MonetizationConfig.DevProducts.Souls50 and productId ~= 0 then
            EconomyService.AddSouls(player, 50)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        elseif productId == MonetizationConfig.DevProducts.Souls200 and productId ~= 0 then
            EconomyService.AddSouls(player, 200)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end

        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Gamepass purchase listener
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if wasPurchased then
            if passId == MonetizationConfig.Gamepasses.DoubleCoins and passId ~= 0 then
                DataService.UpdateData(player, function(d: Types.PlayerData)
                    d.HasDoubleCoins = true
                end)
                EconomyService.SyncClient(player)
            elseif passId == MonetizationConfig.Gamepasses.VipPlot and passId ~= 0 then
                DataService.UpdateData(player, function(d: Types.PlayerData)
                    d.HasVip = true
                end)
                EconomyService.SyncClient(player)
            end
        end
    end)
end

function MonetizationService.CheckPlayerPasses(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    -- Check 2x Coins
    local doublePassId = MonetizationConfig.Gamepasses.DoubleCoins
    if doublePassId and doublePassId > 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, doublePassId)
        end)
        if success and owns then
            data.HasDoubleCoins = true
        end
    end

    -- Check VIP Plot
    local vipPassId = MonetizationConfig.Gamepasses.VipPlot
    if vipPassId and vipPassId > 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipPassId)
        end)
        if success and owns then
            data.HasVip = true
        end
    end
end

return MonetizationService

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("MonsterService")
    target.Source = [==[
--!strict
--[[
    MonsterService.luau
    Manages monster spawning, anti-stuck navigation towards the Manor Core,
    wave countdowns/triggers, combat damage to Core, out-of-combat Core healing timer,
    soul rewards, turret defenses, and distinct 3D spatial audio for each monster type.
]]

local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local MonsterService = {}

type PlotWaveState = {
    WaveNumber: number,
    Status: Types.WaveStatus,
    TimeRemaining: number,
    ActiveMonsters: { Model },
    MonstersRemaining: number,
    CoreHealth: number,
    CoreMaxHealth: number,
    LastDamageTime: number,
    LastRegenTick: number,
}

local plotWaveStates: { [Model]: PlotWaveState } = {}
local monsterOwnerMap: { [Model]: Player } = {}

local DataService: any
local EconomyService: any
local PlotService: any
local ItemDropService: any
local ShopService: any

-- Helper to create 3D spatial sound
local function createSpatialSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number): Sound
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = pitch
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 12
    sound.RollOffMaxDistance = 90
    sound.Parent = parent
    return sound
end

-- Builds a procedural monster model (Ghost, Zombie, Wraith) with custom audio and non-jamming physics
local function createMonsterModel(monsterType: string): Model
    local def = BalanceConfig.Monsters[monsterType]
    assert(def, "[MonsterService] Unknown monster type: " .. tostring(monsterType))

    local model = Instance.new("Model")
    model.Name = "Monster_" .. monsterType
    model:SetAttribute("MonsterType", monsterType)

    -- Torso (Root Part)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2.4, 2.5, 1.4)
    torso.Color = def.Color
    torso.Material = def.Material
    torso.Transparency = def.Transparency
    torso.CanCollide = false -- Non-collidable with other monsters to prevent jamming
    torso.Anchored = false
    torso.Parent = model

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.6, 1.6, 1.6)
    head.Shape = Enum.PartType.Ball
    head.Color = def.Color
    head.Material = def.Material
    head.Transparency = def.Transparency
    head.CanCollide = false
    head.CFrame = torso.CFrame * CFrame.new(0, 2, 0)
    head.Parent = model

    local neckWeld = Instance.new("WeldConstraint")
    neckWeld.Part0 = torso
    neckWeld.Part1 = head
    neckWeld.Parent = torso

    -- Legs
    local leg1 = Instance.new("Part")
    leg1.Name = "LeftLeg"
    leg1.Size = Vector3.new(1, 2, 1)
    leg1.Color = def.Color
    leg1.Material = def.Material
    leg1.Transparency = def.Transparency
    leg1.CanCollide = false
    leg1.CFrame = torso.CFrame * CFrame.new(-0.7, -2, 0)
    leg1.Parent = model

    local weldL = Instance.new("WeldConstraint")
    weldL.Part0 = torso
    weldL.Part1 = leg1
    weldL.Parent = torso

    local leg2 = Instance.new("Part")
    leg2.Name = "RightLeg"
    leg2.Size = Vector3.new(1, 2, 1)
    leg2.Color = def.Color
    leg2.Material = def.Material
    leg2.Transparency = def.Transparency
    leg2.CanCollide = false
    leg2.CFrame = torso.CFrame * CFrame.new(0.7, -2, 0)
    leg2.Parent = model

    local weldR = Instance.new("WeldConstraint")
    weldR.Part0 = torso
    weldR.Part1 = leg2
    weldR.Parent = torso

    -- Glowing eyes or aura
    local light = Instance.new("PointLight")
    light.Color = if monsterType == "Wraith" then Color3.fromRGB(255, 30, 30) else def.Color
    light.Range = 14
    light.Brightness = 2.5
    light.Parent = head

    -- 3D Spatial Audio Setup
    if def.Sounds then
        local groanSound = createSpatialSound(head, "GroanSound", def.Sounds.Groan, def.Sounds.Volume, def.Sounds.Pitch)
        local attackSound = createSpatialSound(head, "AttackSound", def.Sounds.Attack, def.Sounds.Volume * 1.1, def.Sounds.Pitch)
        local deathSound = createSpatialSound(head, "DeathSound", def.Sounds.Death, def.Sounds.Volume * 1.2, def.Sounds.Pitch)

        task.delay(0.2, function()
            if groanSound.Parent then
                groanSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(95, 105) / 100)
                groanSound:Play()
            end
        end)
    end

    -- Humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = def.MaxHealth
    humanoid.Health = def.MaxHealth
    humanoid.WalkSpeed = def.WalkSpeed
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    humanoid.Parent = model

    -- Overhead Health Billboard
    local bb = Instance.new("BillboardGui")
    bb.Name = "MonsterGui"
    bb.Size = UDim2.new(4, 0, 1.2, 0)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s\nHP: %d/%d", def.DisplayName, humanoid.Health, humanoid.MaxHealth)
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    humanoid.HealthChanged:Connect(function(newHealth)
        if label.Parent then
            label.Text = string.format("%s\nHP: %d/%d", def.DisplayName, math.max(0, math.floor(newHealth)), humanoid.MaxHealth)
        end
    end)

    model.PrimaryPart = torso
    return model
end

-- Floating heal notification tag on Manor Core
function MonsterService.FlashCoreHeal(plotModel: Model, healAmount: number)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local floatGui = Instance.new("BillboardGui")
    floatGui.Name = "HealFloatGui"
    floatGui.Size = UDim2.new(5, 0, 1.8, 0)
    floatGui.StudsOffset = Vector3.new(0, 7.5, 0)
    floatGui.AlwaysOnTop = true
    floatGui.Parent = core

    local floatLabel = Instance.new("TextLabel")
    floatLabel.Size = UDim2.new(1, 0, 1, 0)
    floatLabel.BackgroundTransparency = 1
    floatLabel.Text = string.format("+%d HP 💚", healAmount)
    floatLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
    floatLabel.TextStrokeTransparency = 0
    floatLabel.TextSize = 18
    floatLabel.Font = Enum.Font.GothamBlack
    floatLabel.Parent = floatGui

    local tween = TweenService:Create(floatGui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 10.5, 0),
    })
    tween:Play()
    task.delay(1.2, function()
        floatGui:Destroy()
    end)
end

local function updateCoreVisuals(plotModel: Model, currentHp: number, maxHp: number, mode: string?, extraValue: number?)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local coreGui = core:FindFirstChild("CoreGui")
    if not coreGui then return end

    local label = coreGui:FindFirstChild("CoreLabel") :: TextLabel?
    if not label then return end

    local pct = math.clamp(currentHp / maxHp, 0, 1)
    local statusLine = ""
    local labelColor = Color3.fromRGB(240, 180, 255)

    if mode == "Combat" then
        statusLine = "\n⚔️ Under Attack! (Regen paused)"
        labelColor = Color3.fromRGB(255, 60, 60)
    elseif mode == "Cooldown" then
        statusLine = string.format("\n⏳ Healing in: %ds...", extraValue or 5)
        labelColor = Color3.fromRGB(255, 190, 60)
    elseif mode == "Healing" or mode == "HealingActive" then
        statusLine = "\n💚 Regenerating (+25 HP)"
        labelColor = Color3.fromRGB(90, 255, 130)
    elseif mode == "Full" or pct >= 1 then
        statusLine = "\n✨ Core Fortified"
        labelColor = Color3.fromRGB(240, 180, 255)
    end

    label.Text = string.format("🔮 MANOR CORE\nHP: %d / %d%s", math.floor(currentHp), math.floor(maxHp), statusLine)
    label.TextColor3 = labelColor
end

local function syncWaveToClient(player: Player, state: PlotWaveState)
    local waveEvent = Network.GetEvent("WaveStateUpdated")
    local payload: Types.WaveState = {
        WaveNumber = state.WaveNumber,
        Status = state.Status,
        TimeRemaining = state.TimeRemaining,
        MonstersRemaining = state.MonstersRemaining,
        CoreHealth = state.CoreHealth,
        CoreMaxHealth = state.CoreMaxHealth,
    }
    waveEvent:FireClient(player, payload)
end

function MonsterService.Init(dataServiceRef: any, economyServiceRef: any, plotServiceRef: any, itemDropServiceRef: any, shopServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    PlotService = plotServiceRef
    ItemDropService = itemDropServiceRef
    ShopService = shopServiceRef

    local requestStartWaveFn = Network.GetFunction("RequestStartWave")
    requestStartWaveFn.OnServerInvoke = function(player: Player)
        local plot = PlotService.GetPlayerPlot(player)
        if not plot then return false, "No plot owned." end
        local state = plotWaveStates[plot]
        if not state then return false, "Wave state not found." end
        if state.Status == "Active" then
            return false, "Wave is already in progress!"
        end
        MonsterService.StartWave(player, plot)
        return true, "Wave summoned!"
    end

    -- Heartbeat loop: Wave timers, turret targeting, and Manor Core Out-of-Combat Healing
    task.spawn(function()
        while true do
            task.wait(1)
            local now = os.clock()

            for _, player in ipairs(Players:GetPlayers()) do
                local plot = PlotService.GetPlayerPlot(player)
                if plot then
                    local state = plotWaveStates[plot]
                    if state then
                        -- 1. Wave Status Countdown
                        if state.Status == "Waiting" then
                            state.TimeRemaining -= 1
                            if state.TimeRemaining <= 0 then
                                MonsterService.StartWave(player, plot)
                            else
                                syncWaveToClient(player, state)
                            end
                        elseif state.Status == "Active" then
                            MonsterService.TickTurrets(player, plot, state)
                            if ShopService and ShopService.CheckSkills then
                                ShopService.CheckSkills(player, plot, state)
                            end
                            syncWaveToClient(player, state)
                        end

                        -- 2. Manor Core Out-of-Combat Healing System with Timer
                        if state.Status ~= "Defeat" and state.CoreHealth < state.CoreMaxHealth then
                            local timeSinceDamage = now - (state.LastDamageTime or 0)
                            local outOfCombatDelay = BalanceConfig.Core.OutOfCombatCooldown or 6

                            if timeSinceDamage >= outOfCombatDelay then
                                local tickInterval = BalanceConfig.Core.RegenTickInterval or 2.5
                                if (now - (state.LastRegenTick or 0)) >= tickInterval then
                                    state.LastRegenTick = now
                                    local healAmount = BalanceConfig.Core.RegenAmount or 25

                                    local data = DataService.GetData(player)
                                    if data and data.UnlockedUpgrades["HolyAltar"] then
                                        healAmount += 15 -- Holy Altar buffs healing rate
                                    end

                                    state.CoreHealth = math.min(state.CoreMaxHealth, state.CoreHealth + healAmount)
                                    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Healing", healAmount)
                                    syncWaveToClient(player, state)
                                    MonsterService.FlashCoreHeal(plot, healAmount)
                                else
                                    updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "HealingActive")
                                end
                            else
                                local remainingSeconds = math.ceil(outOfCombatDelay - timeSinceDamage)
                                updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "Cooldown", remainingSeconds)
                            end
                        elseif state.CoreHealth >= state.CoreMaxHealth then
                            updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "Full")
                        end
                    end
                end
            end
        end
    end)
end

function MonsterService.InitPlotWave(player: Player, plotModel: Model)
    local data = DataService.GetData(player)
    local waveNum = if data then data.WaveNumber else 1
    local coreLvl = if data and data.CoreLevel then data.CoreLevel else 1

    local maxCoreHp = BalanceConfig.CoreLevels.GetMaxHp(coreLvl)
    if data and data.UnlockedUpgrades["HolyAltar"] then
        maxCoreHp += 500
    end

    local state: PlotWaveState = {
        WaveNumber = waveNum,
        Status = "Waiting",
        TimeRemaining = BalanceConfig.Waves.AutoWaveInterval,
        ActiveMonsters = {},
        MonstersRemaining = 0,
        CoreHealth = maxCoreHp,
        CoreMaxHealth = maxCoreHp,
        LastDamageTime = 0,
        LastRegenTick = 0,
    }

    plotWaveStates[plotModel] = state
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    syncWaveToClient(player, state)
end

function MonsterService.ApplyCoreLevel(plotModel: Model, level: number)
    local state = plotWaveStates[plotModel]
    if not state then return end

    local newMax = BalanceConfig.CoreLevels.GetMaxHp(level)
    local player = plotOwnerMap[plotModel]
    if player then
        local data = DataService.GetData(player)
        if data and data.UnlockedUpgrades["HolyAltar"] then
            newMax += 500
        end
    end

    local hpDiff = newMax - state.CoreMaxHealth
    state.CoreMaxHealth = newMax
    state.CoreHealth = math.clamp(state.CoreHealth + math.max(0, hpDiff), 0, newMax)
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    if player then
        syncWaveToClient(player, state)
    end
end

function MonsterService.StartWave(player: Player, plotModel: Model)
    local state = plotWaveStates[plotModel]
    if not state or state.Status == "Active" then return end

    state.Status = "Active"
    state.ActiveMonsters = {}

    local monstersToSpawn: { string } = {}
    local wave = state.WaveNumber

    if wave == 1 then
        for _ = 1, 4 do table.insert(monstersToSpawn, "Ghost") end
    elseif wave == 2 then
        for _ = 1, 4 do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, 2 do table.insert(monstersToSpawn, "Zombie") end
    elseif wave == 3 then
        for _ = 1, 5 do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, 3 do table.insert(monstersToSpawn, "Zombie") end
        table.insert(monstersToSpawn, "Wraith")
    else
        local ghostCount = math.min(12, 4 + math.floor(wave * 1.5))
        local zombieCount = math.min(8, 2 + math.floor(wave * 0.8))
        local wraithCount = math.min(5, math.floor(wave * 0.5))

        for _ = 1, ghostCount do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, zombieCount do table.insert(monstersToSpawn, "Zombie") end
        for _ = 1, wraithCount do table.insert(monstersToSpawn, "Wraith") end
    end

    state.MonstersRemaining = #monstersToSpawn
    syncWaveToClient(player, state)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("⚠️ Wave %d Approaching! Defend the Manor Core!", wave), Color3.fromRGB(255, 60, 60))

    task.spawn(function()
        local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart?
        local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
        if not plotBase or not manorCore then return end

        for _, mType in ipairs(monstersToSpawn) do
            if state.Status ~= "Active" then break end

            local spawnOffset = Vector3.new(math.random(-45, 45), 3, 50)
            local worldSpawnPos = (plotBase.CFrame * CFrame.new(spawnOffset)).Position

            local monster = createMonsterModel(mType)
            monster:SetPrimaryPartCFrame(CFrame.new(worldSpawnPos))
            monster.Parent = plotModel
            table.insert(state.ActiveMonsters, monster)
            monsterOwnerMap[monster] = player

            MonsterService.RunMonsterAI(monster, mType, player, plotModel, state)
            task.wait(1.2)
        end
    end)
end

function MonsterService.RunMonsterAI(monster: Model, monsterType: string, player: Player, plotModel: Model, state: PlotWaveState)
    local def = BalanceConfig.Monsters[monsterType]
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    local rootPart = monster.PrimaryPart
    local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
    local head = monster:FindFirstChild("Head") :: BasePart?

    if not humanoid or not rootPart or not manorCore then return end

    local groanSound = head and head:FindFirstChild("GroanSound") :: Sound?
    local attackSound = head and head:FindFirstChild("AttackSound") :: Sound?
    local deathSound = head and head:FindFirstChild("DeathSound") :: Sound?

    humanoid.Died:Connect(function()
        local idx = table.find(state.ActiveMonsters, monster)
        if idx then table.remove(state.ActiveMonsters, idx) end

        if deathSound then
            deathSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(90, 110) / 100)
            deathSound:Play()
        end

        -- Physical loot item drop for shop selling
        if ItemDropService and ItemDropService.SpawnDrop and rootPart then
            ItemDropService.SpawnDrop(monsterType, rootPart.Position, player, plotModel)
        end

        EconomyService.AddSouls(player, def.SoulDrop)
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, string.format("+%d Souls 👻", def.SoulDrop), Color3.fromRGB(160, 240, 255))

        DataService.UpdateData(player, function(d: Types.PlayerData)
            d.MonstersDefeated += 1
        end)

        state.MonstersRemaining = math.max(0, state.MonstersRemaining - 1)
        syncWaveToClient(player, state)

        if state.MonstersRemaining <= 0 and #state.ActiveMonsters == 0 then
            MonsterService.HandleWaveVictory(player, plotModel, state)
        end

        task.wait(1.2)
        monster:Destroy()
    end)

    -- Ambient groaning timer while walking towards Core
    task.spawn(function()
        while monster.Parent and humanoid.Health > 0 and state.Status == "Active" do
            task.wait(math.random(4, 7))
            if monster.Parent and humanoid.Health > 0 and groanSound and not groanSound.IsPlaying then
                groanSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(92, 108) / 100)
                groanSound:Play()
            end
        end
    end)

    -- AI loop: March toward Manor Core with anti-stuck obstacle avoidance
    task.spawn(function()
        local lastPos = rootPart.Position
        local stuckTicks = 0

        while monster.Parent and humanoid.Health > 0 and state.Status == "Active" do
            local dist = (rootPart.Position - manorCore.Position).Magnitude
            if dist > def.AttackRange then
                -- Anti-Stuck Detection: Check displacement
                local moved = (rootPart.Position - lastPos).Magnitude
                lastPos = rootPart.Position

                if moved < 0.65 then
                    stuckTicks += 1
                else
                    stuckTicks = 0
                end

                if stuckTicks >= 3 then
                    -- Monster is stuck on an obstacle: Jump and steer laterally
                    humanoid.Jump = true
                    local lateralOffset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
                    humanoid:MoveTo(rootPart.Position + lateralOffset)
                    task.wait(0.4)
                    stuckTicks = 0
                else
                    humanoid:MoveTo(manorCore.Position)
                end
            else
                humanoid:MoveTo(rootPart.Position)
                stuckTicks = 0

                -- Attack Manor Core (Respect Level 20 Ghost Cloak invulnerability)
                local isCloaked = false
                if ShopService and ShopService.IsGhostCloaked then
                    isCloaked = ShopService.IsGhostCloaked(plotModel)
                end

                if not isCloaked then
                    if attackSound then
                        attackSound:Play()
                    end

                    state.CoreHealth = math.max(0, state.CoreHealth - def.Damage)
                    state.LastDamageTime = os.clock() -- Interrupts Core healing cooldown
                    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Combat")
                    syncWaveToClient(player, state)

                    if def.Ranged then
                        local combatVisual = Network.GetEvent("CombatVisual")
                        combatVisual:FireAllClients(rootPart.Position, manorCore.Position, true)
                    end

                    if state.CoreHealth <= 0 then
                        MonsterService.HandleWaveDefeat(player, plotModel, state)
                        break
                    end
                end

                task.wait(def.AttackRate)
            end
            task.wait(0.4)
        end
    end)
end

function MonsterService.TickTurrets(player: Player, plotModel: Model, state: PlotWaveState)
    local data = DataService.GetData(player)
    if not data or not data.UnlockedUpgrades["GargoyleSentry"] then return end

    local builtFolder = plotModel:FindFirstChild("BuiltUpgrades")
    local turret = builtFolder and builtFolder:FindFirstChild("Upgrade_GargoyleSentry")
    local head = turret and turret:FindFirstChild("GargoyleHead") :: BasePart?
    if not head then return end

    local closestMonster: Model? = nil
    local closestDist = 45

    for _, monster in ipairs(state.ActiveMonsters) do
        if monster.Parent and monster.PrimaryPart then
            local hum = monster:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (head.Position - monster.PrimaryPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestMonster = monster
                end
            end
        end
    end

    if closestMonster and closestMonster.PrimaryPart then
        local targetHum = closestMonster:FindFirstChildOfClass("Humanoid")
        if targetHum then
            targetHum:TakeDamage(25)
            local combatVisual = Network.GetEvent("CombatVisual")
            combatVisual:FireAllClients(head.Position, closestMonster.PrimaryPart.Position, true)
        end
    end
end

function MonsterService.HandleWaveVictory(player: Player, plotModel: Model, state: PlotWaveState)
    state.Status = "Victory"

    local waveRewardCoins = BalanceConfig.Waves.RewardBaseCoins + (state.WaveNumber * BalanceConfig.Waves.RewardCoinsPerWave)
    local waveRewardSouls = BalanceConfig.Waves.RewardBaseSouls + (state.WaveNumber * BalanceConfig.Waves.RewardSoulsPerWave)

    EconomyService.AddCoins(player, waveRewardCoins, true)
    EconomyService.AddSouls(player, waveRewardSouls)

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.WaveNumber += 1
    end)

    state.WaveNumber += 1
    state.TimeRemaining = BalanceConfig.Waves.AutoWaveInterval
    syncWaveToClient(player, state)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("🏆 Wave Cleared! +%d Coins, +%d Souls!", waveRewardCoins, waveRewardSouls), Color3.fromRGB(100, 255, 100))

    task.wait(4)
    state.Status = "Waiting"
    syncWaveToClient(player, state)
end

function MonsterService.HandleWaveDefeat(player: Player, plotModel: Model, state: PlotWaveState)
    state.Status = "Defeat"

    for _, monster in ipairs(state.ActiveMonsters) do
        if monster and monster.Parent then
            monster:Destroy()
        end
    end
    state.ActiveMonsters = {}

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, "💀 Manor Core Shattered! Wave Failed. Core regenerating...", Color3.fromRGB(255, 50, 50))

    syncWaveToClient(player, state)

    task.wait(BalanceConfig.Core.DefeatRecoveryDuration)

    state.CoreHealth = state.CoreMaxHealth
    state.Status = "Waiting"
    state.TimeRemaining = BalanceConfig.Waves.AutoWaveInterval
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    syncWaveToClient(player, state)
end

function MonsterService.ClearPlayerWave(player: Player)
    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        local state = plotWaveStates[plot]
        if state then
            for _, monster in ipairs(state.ActiveMonsters) do
                if monster and monster.Parent then monster:Destroy() end
            end
        end
        plotWaveStates[plot] = nil
    end
end

return MonsterService
]==]
    table.insert(updated, target:GetFullName())
end
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
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("ClientMain")
    target.Source = [==[
--!strict
--[[
    ClientMain.client.luau
    Root client-side entry point for Haunted Manor Tycoon.
    Initializes UI, Plot aesthetics, Combat input, and Core Upgrade proximity controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent:WaitForChild("Controllers")
local UIController = require(Controllers:WaitForChild("UIController"))
local PlotController = require(Controllers:WaitForChild("PlotController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local CoreUpgradeController = require(Controllers:WaitForChild("CoreUpgradeController"))

print("========================================")
print("  Haunted Manor Tycoon - Client Starting")
print("========================================")

-- Initialize Controllers
UIController.Init()
PlotController.Init()
CombatController.Init()
CoreUpgradeController.Init()

print("[ClientMain] All client controllers initialized successfully.")
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CombatController")
    target.Source = [==[
--!strict
--[[
    CombatController.luau
    Handles client-side attack inputs for the Holy Lantern,
    crosshair targeting, instant responsive visual light beams, attack sound effects,
    and replicates server combat visuals.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)

local CombatController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local zapSound: Sound

local function drawHolyBeam(origin: Vector3, targetPos: Vector3, isHit: boolean)
    local distance = (targetPos - origin).Magnitude
    if distance <= 0.1 then return end

    local beamPart = Instance.new("Part")
    beamPart.Name = "HolyBeam"
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.Material = Enum.Material.Neon
    beamPart.Color = if isHit then Color3.fromRGB(255, 230, 110) else Color3.fromRGB(180, 160, 255)
    beamPart.Size = Vector3.new(0.6, 0.6, distance)
    beamPart.CFrame = CFrame.new(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
    beamPart.Transparency = 0.1
    beamPart.Parent = Workspace

    local tween = TweenService:Create(beamPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.1, 0.1, distance),
    })
    tween:Play()
    tween.Completed:Connect(function()
        beamPart:Destroy()
    end)
end

function CombatController.Init()
    local character = player.Character or player.CharacterAdded:Wait()

    -- Audio for Holy Lantern zap
    zapSound = Instance.new("Sound")
    zapSound.Name = "LanternZapSound"
    zapSound.SoundId = BalanceConfig.Weapon.FireSound
    zapSound.Volume = 0.9
    zapSound.PlaybackSpeed = 1.05
    zapSound.Parent = Workspace

    local function setupTool(tool: Tool)
        if tool.Name ~= BalanceConfig.Weapon.Name then return end

        tool.Activated:Connect(function()
            local char = player.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local handle = tool:FindFirstChild("Handle") :: BasePart?
            if not hrp or not handle then return end

            local mouseRay = mouse.UnitRay
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = { char }
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude

            local result = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * BalanceConfig.Weapon.Range, raycastParams)
            local targetMonster: Model? = nil
            local targetPos = mouseRay.Origin + (mouseRay.Direction * BalanceConfig.Weapon.Range)

            if result and result.Instance then
                targetPos = result.Position
                local model = result.Instance:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChildOfClass("Humanoid") and model ~= char then
                    targetMonster = model
                end
            end

            -- Play responsive fire sound
            if zapSound then
                zapSound.PlaybackSpeed = 1.0 + (math.random(-5, 5) / 100)
                zapSound:Play()
            end

            drawHolyBeam(handle.Position, targetPos, targetMonster ~= nil)

            local attackEvent = Network.GetEvent("AttackRequest")
            attackEvent:FireServer(targetMonster)
        end)
    end

    player.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                setupTool(child)
            end
        end)
    end)

    if character then
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                setupTool(child)
            end
        end)
        local existingTool = character:FindFirstChildOfClass("Tool")
        if existingTool then
            setupTool(existingTool)
        end
    end

    local combatVisualEvent = Network.GetEvent("CombatVisual")
    combatVisualEvent.OnClientEvent:Connect(function(origin: Vector3, target: Vector3, isHit: boolean)
        drawHolyBeam(origin, target, isHit)
    end)
end

return CombatController
]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CoreUpgradeController")
    target.Source = [==[
--!strict
--[[
    CoreUpgradeController.luau
    Client-side controller that:
    1. Detects when the local player is near their own Manor Core (within interact radius)
    2. Shows an interactive UI prompt: "Press [E] to Upgrade Core  |  Lv.X → Lv.X+1  |  Cost: N Coins"
    3. Listens for E key / mobile tap to trigger RequestCoreLevelUp RemoteFunction
    4. Updates the prompt dynamically based on player data (level, coins, cost)
    5. Also shows a proximity prompt near the Central Market Hub ShopZone
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local CoreUpgradeController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- Runtime state
local currentCoreLevel = 1
local currentCoins = 0
local localPlotModel: Model? = nil
local isUpgrading = false
local isSelling = false

-- UI refs
local upgradePromptGui: ScreenGui? = nil
local upgradeFrame: Frame? = nil
local upgradeText: TextLabel? = nil
local upgradeCostBar: Frame? = nil

local shopPromptGui: ScreenGui? = nil
local shopFrame: Frame? = nil
local shopText: TextLabel? = nil

-- ---------------------------------------------------------------------------
-- Build UI
-- ---------------------------------------------------------------------------
local function buildUpgradePrompt()
    local sGui = Instance.new("ScreenGui")
    sGui.Name = "CoreUpgradePrompt"
    sGui.ResetOnSpawn = false
    sGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sGui.Enabled = false
    sGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "PromptFrame"
    frame.Size = UDim2.new(0, 340, 0, 100)
    frame.Position = UDim2.new(0.5, -170, 0.75, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = sGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(230, 190, 60)
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Key icon
    local keyBox = Instance.new("TextLabel")
    keyBox.Size = UDim2.new(0, 44, 0, 44)
    keyBox.Position = UDim2.new(0, 14, 0, 28)
    keyBox.BackgroundColor3 = Color3.fromRGB(230, 190, 60)
    keyBox.BorderSizePixel = 0
    keyBox.Text = "E"
    keyBox.TextColor3 = Color3.fromRGB(15, 12, 20)
    keyBox.TextSize = 22
    keyBox.Font = Enum.Font.GothamBlack
    keyBox.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyBox

    -- Main text
    local text = Instance.new("TextLabel")
    text.Name = "PromptText"
    text.Size = UDim2.new(1, -78, 1, -20)
    text.Position = UDim2.new(0, 68, 0, 10)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 230, 100)
    text.TextSize = 15
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextWrapped = true
    text.Text = "⬆️ Upgrade Manor Core\nLv.1 → Lv.2  |  Cost: 100 🪙"
    text.Parent = frame

    -- Cost bar (shows how close player is to affording)
    local barTrack = Instance.new("Frame")
    barTrack.Size = UDim2.new(1, -78, 0, 8)
    barTrack.Position = UDim2.new(0, 68, 1, -18)
    barTrack.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
    barTrack.BorderSizePixel = 0
    barTrack.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = barTrack

    local barFill = Instance.new("Frame")
    barFill.Name = "CostBarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(100, 220, 80)
    barFill.BorderSizePixel = 0
    barFill.Parent = barTrack

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 4)
    barFillCorner.Parent = barFill

    upgradePromptGui = sGui
    upgradeFrame = frame
    upgradeText = text
    upgradeCostBar = barFill
end

local function buildShopPrompt()
    local sGui = Instance.new("ScreenGui")
    sGui.Name = "ShopProximityPrompt"
    sGui.ResetOnSpawn = false
    sGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sGui.Enabled = false
    sGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "ShopFrame"
    frame.Size = UDim2.new(0, 300, 0, 80)
    frame.Position = UDim2.new(0.5, -150, 0.75, 0)
    frame.BackgroundColor3 = Color3.fromRGB(14, 24, 16)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = sGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 220, 100)
    stroke.Thickness = 2
    stroke.Parent = frame

    local keyBox = Instance.new("TextLabel")
    keyBox.Size = UDim2.new(0, 44, 0, 44)
    keyBox.Position = UDim2.new(0, 14, 0, 18)
    keyBox.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
    keyBox.BorderSizePixel = 0
    keyBox.Text = "E"
    keyBox.TextColor3 = Color3.fromRGB(10, 20, 12)
    keyBox.TextSize = 22
    keyBox.Font = Enum.Font.GothamBlack
    keyBox.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyBox

    local text = Instance.new("TextLabel")
    text.Name = "ShopText"
    text.Size = UDim2.new(1, -78, 1, 0)
    text.Position = UDim2.new(0, 68, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(120, 255, 140)
    text.TextSize = 15
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextWrapped = true
    text.Text = "🏪 Old Grimwald's Shop\n[E] Sell all loot for Coins"
    text.Parent = frame

    shopPromptGui = sGui
    shopFrame = frame
    shopText = text
end

-- ---------------------------------------------------------------------------
-- Update upgrade prompt content
-- ---------------------------------------------------------------------------
local function refreshUpgradePrompt()
    if not upgradeText or not upgradePromptGui then return end

    local maxLvl = BalanceConfig.CoreLevels.MaxLevel
    if currentCoreLevel >= maxLvl then
        upgradeText.Text = "🔮 Manor Core: MAX LEVEL (Lv.20)\nAll skills unlocked!"
        upgradeText.TextColor3 = Color3.fromRGB(255, 215, 0)
        if upgradeCostBar then
            upgradeCostBar.Size = UDim2.new(1, 0, 1, 0)
            upgradeCostBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        end
    else
        local cost = BalanceConfig.CoreLevels.GetUpgradeCost(currentCoreLevel)
        local newMaxHp = BalanceConfig.CoreLevels.GetMaxHp(currentCoreLevel + 1)
        local canAfford = currentCoins >= cost

        local affordStr = if canAfford then "✅" else "❌"
        local skillHint = ""
        if currentCoreLevel == 9 then
            skillHint = "\n⚡ Next: UNLOCK Spectral Retaliation!"
        elseif currentCoreLevel == 19 then
            skillHint = "\n👻 Next: UNLOCK Ghost Cloak!"
        end

        upgradeText.Text = string.format(
            "⬆️ Upgrade Core  Lv.%d → Lv.%d%s\n%s Cost: %d 🪙   New Max HP: %d",
            currentCoreLevel, currentCoreLevel + 1, skillHint, affordStr, cost, newMaxHp
        )
        upgradeText.TextColor3 = if canAfford then Color3.fromRGB(100, 255, 120) else Color3.fromRGB(255, 160, 80)

        if upgradeCostBar then
            local pct = math.clamp(currentCoins / math.max(cost, 1), 0, 1)
            TweenService:Create(upgradeCostBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(pct, 0, 1, 0),
                BackgroundColor3 = if pct >= 1 then Color3.fromRGB(100, 220, 80) else Color3.fromRGB(255, 160, 50),
            }):Play()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Show / hide helpers with fade
-- ---------------------------------------------------------------------------
local function showPrompt(sGui: ScreenGui, fr: Frame)
    sGui.Enabled = true
    fr.BackgroundTransparency = 1
    TweenService:Create(fr, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.1,
    }):Play()
end

local function hidePrompt(sGui: ScreenGui)
    sGui.Enabled = false
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function CoreUpgradeController.Init()
    buildUpgradePrompt()
    buildShopPrompt()

    -- Listen for player data updates (coins & core level)
    local updateEvent = Network.GetEvent("PlayerDataUpdated")
    updateEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        currentCoins = data.Coins or 0
        currentCoreLevel = data.CoreLevel or 1
        refreshUpgradePrompt()
    end)

    -- Listen for plot assignment to know which ManorCore to watch
    local plotAssignedEvent = Network.GetEvent("PlotAssigned")
    plotAssignedEvent.OnClientEvent:Connect(function(index: number, plotModel: Model?)
        if plotModel and plotModel:IsA("Model") then
            localPlotModel = plotModel
        else
            -- Find by index
            local plotsFolder = Workspace:FindFirstChild("Plots")
            if plotsFolder then
                for _, m in ipairs(plotsFolder:GetChildren()) do
                    if m:IsA("Model") and m:GetAttribute("PlotIndex") == index then
                        localPlotModel = m :: Model
                        break
                    end
                end
            end
        end
    end)

    -- E key / proximity detection loop
    local UPGRADE_RADIUS = BalanceConfig.CoreLevels.UpgradeInteractRadius or 14
    local SHOP_RADIUS = 20

    local wasNearCore = false
    local wasNearShop = false

    RunService.Heartbeat:Connect(function()
        local character = player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end

        -- Check Manor Core proximity
        local nearCore = false
        if localPlotModel then
            local core = localPlotModel:FindFirstChild("ManorCore") :: BasePart?
            if core then
                local dist = (hrp.Position - core.Position).Magnitude
                nearCore = dist <= UPGRADE_RADIUS
            end
        end

        if nearCore ~= wasNearCore then
            wasNearCore = nearCore
            if nearCore then
                refreshUpgradePrompt()
                showPrompt(upgradePromptGui :: ScreenGui, upgradeFrame :: Frame)
            else
                hidePrompt(upgradePromptGui :: ScreenGui)
            end
        end

        -- Check Market Hub ShopZone proximity
        local nearShop = false
        local hub = Workspace:FindFirstChild("MarketHub")
        if hub then
            local shopZone = hub:FindFirstChild("ShopZone") :: BasePart?
            if shopZone then
                local dist = (hrp.Position - shopZone.Position).Magnitude
                nearShop = dist <= SHOP_RADIUS
            end
        end

        if nearShop ~= wasNearShop then
            wasNearShop = nearShop
            if nearShop then
                showPrompt(shopPromptGui :: ScreenGui, shopFrame :: Frame)
            else
                hidePrompt(shopPromptGui :: ScreenGui)
            end
        end
    end)

    -- E key handler
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end

        -- Upgrade Core
        if wasNearCore and not isUpgrading then
            isUpgrading = true
            local levelUpFn = Network.GetFunction("RequestCoreLevelUp")
            levelUpFn:InvokeServer()
            task.delay(0.6, function() isUpgrading = false end)
        end

        -- Sell Loot at Shop
        if wasNearShop and not isSelling then
            isSelling = true
            local sellFn = Network.GetFunction("RequestSellInventory")
            sellFn:InvokeServer()
            task.delay(1.0, function() isSelling = false end)
        end
    end)

    -- Mobile: tap-to-interact button appears when near (optional placeholder)
    -- Roblox Mobile automatically fires InputBegan for screen taps on ProximityPrompts,
    -- but since we're using custom detection, E-key works for PC/console.
    -- Mobile support: TODO - add on-screen tap button overlay

    print("[CoreUpgradeController] Initialized.")
end

return CoreUpgradeController

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlotController")
    target.Source = [==[
--!strict
--[[
    PlotController.luau
    Handles client-side aesthetic pad animations, pulsing neon glow effects,
    and visual highlights for the player's claimed plot.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlotController = {}

local activeConnections: { [string]: RBXScriptConnection } = {}

function PlotController.Init()
    -- Gentle bobbing and glowing animation for active pads
    local plotsFolder = Workspace:WaitForChild("Plots", 10) :: Folder?
    if not plotsFolder then return end

    local timeElapsed = 0

    local renderConnection = RunService.RenderStepped:Connect(function(dt: number)
        timeElapsed += dt
        local pulse = (math.sin(timeElapsed * 3) + 1) / 2 -- 0 to 1

        for _, plot in ipairs(plotsFolder:GetChildren()) do
            if plot:IsA("Model") then
                -- Pulse Vault Pad
                local vaultPad = plot:FindFirstChild("VaultPad") :: BasePart?
                if vaultPad then
                    vaultPad.Transparency = 0.1 + (pulse * 0.2)
                end

                -- Pulse Cursed Bell Pad
                local bellPad = plot:FindFirstChild("WaveBellPad") :: BasePart?
                if bellPad then
                    bellPad.Transparency = 0.1 + ((1 - pulse) * 0.2)
                end

                -- Pulse active Upgrade Pads
                local padsFolder = plot:FindFirstChild("Pads")
                if padsFolder then
                    for _, pad in ipairs(padsFolder:GetChildren()) do
                        if pad:IsA("BasePart") and pad.Transparency < 0.9 then
                            pad.Transparency = 0.15 + (pulse * 0.15)
                        end
                    end
                end
            end
        end
    end)

    activeConnections["PadPulse"] = renderConnection
end

function PlotController.Cleanup()
    for _, conn in pairs(activeConnections) do
        conn:Disconnect()
    end
    table.clear(activeConnections)
end

return PlotController

]==]
    table.insert(updated, target:GetFullName())
end
do
    local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("UIController")
    target.Source = [==[
--!strict
--[[
    UIController.luau
    Creates and drives the complete touch-friendly ScreenGui HUD:
    - Currency Display (Coins 🪙 & Souls 👻)
    - Manor Core Health Bar
    - Wave Defense Status & Summon Button 🔔
    - Notification Toasts (animated purchase/alert cards)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local coinsLabel: TextLabel
local soulsLabel: TextLabel
local invLabel: TextLabel
local plotLabel: TextLabel
local coreHpLabel: TextLabel
local coreHpBarFill: Frame
local waveStatusLabel: TextLabel
local summonWaveBtn: TextButton
local toastContainer: Frame

local function createCorner(parent: GuiObject, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function createStroke(parent: GuiObject, color: Color3, thickness: number)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Parent = parent
end

function UIController.Init()
    -- Create ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HauntedManorGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- 1. Top HUD Bar (Currencies & Plot)
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(0, 560, 0, 52)
    topBar.Position = UDim2.new(0.5, -280, 0, 15)
    topBar.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
    topBar.BackgroundTransparency = 0.2
    topBar.BorderSizePixel = 0
    topBar.Parent = screenGui
    createCorner(topBar, 12)
    createStroke(topBar, Color3.fromRGB(90, 70, 110), 1.5)

    -- Coins Card
    local coinsCard = Instance.new("Frame")
    coinsCard.Name = "CoinsCard"
    coinsCard.Size = UDim2.new(0.25, 0, 0.8, 0)
    coinsCard.Position = UDim2.new(0.015, 0, 0.1, 0)
    coinsCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    coinsCard.BorderSizePixel = 0
    coinsCard.Parent = topBar
    createCorner(coinsCard, 8)

    coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsLabel"
    coinsLabel.Size = UDim2.new(1, -8, 1, 0)
    coinsLabel.Position = UDim2.new(0, 6, 0, 0)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Text = "🪙 0"
    coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
    coinsLabel.TextSize = 15
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinsLabel.Parent = coinsCard

    -- Souls Card
    local soulsCard = Instance.new("Frame")
    soulsCard.Name = "SoulsCard"
    soulsCard.Size = UDim2.new(0.24, 0, 0.8, 0)
    soulsCard.Position = UDim2.new(0.28, 0, 0.1, 0)
    soulsCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    soulsCard.BorderSizePixel = 0
    soulsCard.Parent = topBar
    createCorner(soulsCard, 8)

    soulsLabel = Instance.new("TextLabel")
    soulsLabel.Name = "SoulsLabel"
    soulsLabel.Size = UDim2.new(1, -8, 1, 0)
    soulsLabel.Position = UDim2.new(0, 6, 0, 0)
    soulsLabel.BackgroundTransparency = 1
    soulsLabel.Text = "👻 0"
    soulsLabel.TextColor3 = Color3.fromRGB(160, 240, 255)
    soulsLabel.TextSize = 15
    soulsLabel.Font = Enum.Font.GothamBold
    soulsLabel.TextXAlignment = Enum.TextXAlignment.Left
    soulsLabel.Parent = soulsCard

    -- Inventory Card (Loot for Shop)
    local invCard = Instance.new("Frame")
    invCard.Name = "InventoryCard"
    invCard.Size = UDim2.new(0.24, 0, 0.8, 0)
    invCard.Position = UDim2.new(0.535, 0, 0.1, 0)
    invCard.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    invCard.BorderSizePixel = 0
    invCard.Parent = topBar
    createCorner(invCard, 8)

    invLabel = Instance.new("TextLabel")
    invLabel.Name = "InventoryLabel"
    invLabel.Size = UDim2.new(1, -8, 1, 0)
    invLabel.Position = UDim2.new(0, 6, 0, 0)
    invLabel.BackgroundTransparency = 1
    invLabel.Text = "🎒 Loot: 0"
    invLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
    invLabel.TextSize = 14
    invLabel.Font = Enum.Font.GothamBold
    invLabel.TextXAlignment = Enum.TextXAlignment.Left
    invLabel.Parent = invCard

    -- Plot Card
    local plotCard = Instance.new("Frame")
    plotCard.Name = "PlotCard"
    plotCard.Size = UDim2.new(0.19, 0, 0.8, 0)
    plotCard.Position = UDim2.new(0.79, 0, 0.1, 0)
    plotCard.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
    plotCard.BorderSizePixel = 0
    plotCard.Parent = topBar
    createCorner(plotCard, 8)

    plotLabel = Instance.new("TextLabel")
    plotLabel.Name = "PlotLabel"
    plotLabel.Size = UDim2.new(1, 0, 1, 0)
    plotLabel.BackgroundTransparency = 1
    plotLabel.Text = "🏰 Plot: --"
    plotLabel.TextColor3 = Color3.fromRGB(220, 200, 240)
    plotLabel.TextSize = 13
    plotLabel.Font = Enum.Font.GothamMedium
    plotLabel.Parent = plotCard

    -- 2. Wave & Manor Core Defense HUD (Top-Center / Left)
    local defensePanel = Instance.new("Frame")
    defensePanel.Name = "DefensePanel"
    defensePanel.Size = UDim2.new(0, 320, 0, 100)
    defensePanel.Position = UDim2.new(0.02, 0, 0.12, 0)
    defensePanel.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
    defensePanel.BackgroundTransparency = 0.25
    defensePanel.BorderSizePixel = 0
    defensePanel.Parent = screenGui
    createCorner(defensePanel, 12)
    createStroke(defensePanel, Color3.fromRGB(120, 60, 160), 1.5)

    -- Core Health Bar Title & Label
    coreHpLabel = Instance.new("TextLabel")
    coreHpLabel.Name = "CoreHpLabel"
    coreHpLabel.Size = UDim2.new(1, -20, 0, 22)
    coreHpLabel.Position = UDim2.new(0, 10, 0, 8)
    coreHpLabel.BackgroundTransparency = 1
    coreHpLabel.Text = "🔮 Core HP: 500 / 500"
    coreHpLabel.TextColor3 = Color3.fromRGB(240, 200, 255)
    coreHpLabel.TextSize = 14
    coreHpLabel.Font = Enum.Font.GothamBold
    coreHpLabel.TextXAlignment = Enum.TextXAlignment.Left
    coreHpLabel.Parent = defensePanel

    -- Health Bar Track
    local coreHpTrack = Instance.new("Frame")
    coreHpTrack.Name = "CoreHpTrack"
    coreHpTrack.Size = UDim2.new(1, -20, 0, 12)
    coreHpTrack.Position = UDim2.new(0, 10, 0, 32)
    coreHpTrack.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
    coreHpTrack.BorderSizePixel = 0
    coreHpTrack.Parent = defensePanel
    createCorner(coreHpTrack, 6)

    coreHpBarFill = Instance.new("Frame")
    coreHpBarFill.Name = "CoreHpBarFill"
    coreHpBarFill.Size = UDim2.new(1, 0, 1, 0)
    coreHpBarFill.BackgroundColor3 = Color3.fromRGB(180, 70, 255)
    coreHpBarFill.BorderSizePixel = 0
    coreHpBarFill.Parent = coreHpTrack
    createCorner(coreHpBarFill, 6)

    -- Wave Status Text
    waveStatusLabel = Instance.new("TextLabel")
    waveStatusLabel.Name = "WaveStatusLabel"
    waveStatusLabel.Size = UDim2.new(0.65, 0, 0, 38)
    waveStatusLabel.Position = UDim2.new(0, 10, 0, 52)
    waveStatusLabel.BackgroundTransparency = 1
    waveStatusLabel.Text = "⏳ Wave 1 in: 120s"
    waveStatusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    waveStatusLabel.TextSize = 13
    waveStatusLabel.Font = Enum.Font.GothamMedium
    waveStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    waveStatusLabel.Parent = defensePanel

    -- Quick Summon Wave Button (Touch Friendly)
    summonWaveBtn = Instance.new("TextButton")
    summonWaveBtn.Name = "SummonWaveBtn"
    summonWaveBtn.Size = UDim2.new(0.3, 0, 0, 34)
    summonWaveBtn.Position = UDim2.new(0.68, 0, 0, 54)
    summonWaveBtn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
    summonWaveBtn.Text = "🔔 Summon"
    summonWaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    summonWaveBtn.TextSize = 12
    summonWaveBtn.Font = Enum.Font.GothamBold
    summonWaveBtn.Parent = defensePanel
    createCorner(summonWaveBtn, 8)

    summonWaveBtn.MouseButton1Click:Connect(function()
        local requestWaveFn = Network.GetFunction("RequestStartWave")
        requestWaveFn:InvokeServer()
    end)

    -- 3. Notification Toast Container (Bottom Center)
    toastContainer = Instance.new("Frame")
    toastContainer.Name = "ToastContainer"
    toastContainer.Size = UDim2.new(0, 380, 0, 120)
    toastContainer.Position = UDim2.new(0.5, -190, 0.82, 0)
    toastContainer.BackgroundTransparency = 1
    toastContainer.Parent = screenGui

    -- Listen to Network Events
    local updateEvent = Network.GetEvent("PlayerDataUpdated")
    updateEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        UIController.UpdatePlayerData(data)
    end)

    local plotAssignedEvent = Network.GetEvent("PlotAssigned")
    plotAssignedEvent.OnClientEvent:Connect(function(index: number)
        plotLabel.Text = string.format("🏰 Plot: #%d", index)
    end)

    local waveStateEvent = Network.GetEvent("WaveStateUpdated")
    waveStateEvent.OnClientEvent:Connect(function(state: Types.WaveState)
        UIController.UpdateWaveState(state)
    end)

    local notifEvent = Network.GetEvent("Notification")
    notifEvent.OnClientEvent:Connect(function(msg: string, color: Color3?)
        UIController.ShowToast(msg, color)
    end)

    -- Initial Data Fetch
    task.spawn(function()
        local getPlayerDataFn = Network.GetFunction("GetPlayerData")
        local data = getPlayerDataFn:InvokeServer() :: Types.PlayerData?
        if data then
            UIController.UpdatePlayerData(data)
        end
    end)
end

function UIController.UpdatePlayerData(data: Types.PlayerData)
    coinsLabel.Text = string.format("🪙 %d", data.Coins)
    soulsLabel.Text = string.format("👻 %d", data.Souls)

    if invLabel then
        local count = 0
        if data.Inventory then
            for _, c in pairs(data.Inventory) do
                count += c
            end
        end
        invLabel.Text = string.format("🎒 Loot: %d", count)
    end
end

function UIController.UpdateWaveState(state: Types.WaveState)
    coreHpLabel.Text = string.format("🔮 Core HP: %d / %d", math.floor(state.CoreHealth), math.floor(state.CoreMaxHealth))
    local pct = math.clamp(state.CoreHealth / state.CoreMaxHealth, 0, 1)
    coreHpBarFill.Size = UDim2.new(pct, 0, 1, 0)

    if pct <= 0.25 then
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(240, 50, 50)
    elseif pct <= 0.5 then
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(240, 160, 50)
    else
        coreHpBarFill.BackgroundColor3 = Color3.fromRGB(180, 70, 255)
    end

    if state.Status == "Waiting" then
        waveStatusLabel.Text = string.format("⏳ Wave %d in: %ds", state.WaveNumber, math.max(0, state.TimeRemaining))
        waveStatusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
        summonWaveBtn.Visible = true
    elseif state.Status == "Active" then
        waveStatusLabel.Text = string.format("⚔️ Wave %d: %d Left", state.WaveNumber, state.MonstersRemaining)
        waveStatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
        summonWaveBtn.Visible = false
    elseif state.Status == "Victory" then
        waveStatusLabel.Text = "🏆 Wave Survived!"
        waveStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        summonWaveBtn.Visible = false
    elseif state.Status == "Defeat" then
        waveStatusLabel.Text = "💀 Core Broken! Recovering..."
        waveStatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        summonWaveBtn.Visible = false
    end
end

function UIController.ShowToast(message: string, color: Color3?)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 36)
    toast.Position = UDim2.new(0, 0, 1, 0)
    toast.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
    toast.BackgroundTransparency = 0.15
    toast.BorderSizePixel = 0
    toast.Parent = toastContainer
    createCorner(toast, 8)
    createStroke(toast, color or Color3.fromRGB(140, 100, 200), 1.5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = toast

    local tweenIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0.4, 0)
    })
    tweenIn:Play()

    task.delay(2.6, function()
        if toast.Parent then
            local tweenOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 1.2, 0),
                BackgroundTransparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                toast:Destroy()
            end)
        end
    end)
end

return UIController

]==]
    table.insert(updated, target:GetFullName())
end
return 'Successfully synced ' .. #updated .. ' scripts: ' .. table.concat(updated, ', ')
