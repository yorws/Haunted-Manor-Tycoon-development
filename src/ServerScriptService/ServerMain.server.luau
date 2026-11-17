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
