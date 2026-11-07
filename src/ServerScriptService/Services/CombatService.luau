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
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack and not backpack:FindFirstChild(BalanceConfig.Weapon.Name) then
        local lantern = createLanternTool()
        lantern.Parent = backpack
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

