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

        -- If plot exists, ensure spawn on plot
        if plot then
            local spawnPart = plot:FindFirstChild("PlotSpawn") :: BasePart?
            local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
            if hrp and spawnPart then
                hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
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

