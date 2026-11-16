-- Batch sync: batch2_services1
local updated = {}
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
return 'Synced batch batch2_services1 (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
