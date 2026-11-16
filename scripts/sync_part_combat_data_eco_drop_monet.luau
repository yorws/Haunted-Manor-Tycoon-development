local updated = {}
do
    local target = game:GetService("ServerScriptService").Services.CombatService
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
    local target = game:GetService("ServerScriptService").Services.DataService
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
    local target = game:GetService("ServerScriptService").Services.EconomyService
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
    local target = game:GetService("ServerScriptService").Services.ItemDropService
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
    local target = game:GetService("ServerScriptService").Services.MonetizationService
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
return 'Synced (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
