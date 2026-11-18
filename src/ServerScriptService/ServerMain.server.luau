--!strict
--[[
    ServerMain.server.luau
    Bootstraps all backend services safely and guarantees plot assignment & spawn teleport.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Modules.Network)
if Network.InitServer then
    Network.InitServer()
end

local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local ItemDropService = require(Services:WaitForChild("ItemDropService"))
local MonsterService = require(Services:WaitForChild("MonsterService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local WorldService = require(Services:WaitForChild("WorldService"))

if DataService.Init then DataService.Init() end
if EconomyService.Init then EconomyService.Init(DataService) end
if ShopService.Init then ShopService.Init(DataService, EconomyService, PlotService, MonsterService) end
if PlotService.Init then PlotService.Init(DataService, EconomyService, ShopService) end
if ItemDropService.Init then ItemDropService.Init(DataService, EconomyService) end
if MonsterService.Init then MonsterService.Init(DataService, EconomyService, PlotService, ItemDropService, ShopService) end
if CombatService.Init then CombatService.Init(DataService) end
if WorldService.Init then WorldService.Init(ShopService) end

local GetPlayerDataFn = Network.GetFunction("GetPlayerData")
GetPlayerDataFn.OnServerInvoke = function(player: Player)
    return DataService.GetData(player)
end

local function teleportCharacterToPlot(player: Player, character: Model, plotModel: Model)
    local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart?
    local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    if not plotBase or not hrp then return end

    local spawnPos = (plotBase.CFrame * CFrame.new(0, 5, -10)).Position
    local lookTarget = (plotBase.CFrame * CFrame.new(0, 5, 28)).Position
    local targetCF = CFrame.lookAt(spawnPos, lookTarget)

    character:PivotTo(targetCF)
    task.wait(0.15)
    if character.Parent and hrp.Parent then
        hrp.AssemblyLinearVelocity = Vector3.zero
        character:PivotTo(targetCF)
    end
end

local function onPlayerAdded(player: Player)
    local function onCharacterAdded(character: Model)
        if CombatService.GiveWeapon then
            CombatService.GiveWeapon(player)
        end
        local assignedPlot = PlotService.GetPlayerPlot(player)
        if assignedPlot then
            teleportCharacterToPlot(player, character, assignedPlot)
        end
    end

    player.CharacterAdded:Connect(onCharacterAdded)

    if DataService.LoadData then
        pcall(function() DataService.LoadData(player) end)
    end

    local plotModel = PlotService.AssignPlot(player)
    if plotModel then
        local plotSpawn = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
        if plotSpawn then
            player.RespawnLocation = plotSpawn
        end

        if MonsterService.InitPlotWave then
            MonsterService.InitPlotWave(player, plotModel)
        end

        if player.Character then
            task.spawn(teleportCharacterToPlot, player, player.Character, plotModel)
            if CombatService.GiveWeapon then
                CombatService.GiveWeapon(player)
            end
        end
    end

    if EconomyService.SyncClient then
        EconomyService.SyncClient(player)
    end
end

local function onPlayerRemoving(player: Player)
    if MonsterService.ClearPlayerWave then MonsterService.ClearPlayerWave(player) end
    if CombatService.ClearPlayer then CombatService.ClearPlayer(player) end
    if EconomyService.ClearPlayer then EconomyService.ClearPlayer(player) end
    if PlotService.ReleasePlot then PlotService.ReleasePlot(player) end
    if DataService.ReleaseSession then DataService.ReleaseSession(player) end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, existingPlayer in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, existingPlayer)
end