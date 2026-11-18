--!strict
--[[
    CombatService.luau
    Equips players with the Holy Lantern weapon tool and validates all attacks server-side
    (rate-limiting, distance checks, ownership checks, Core Level damage scaling).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)

local CombatService = {}

local lastAttackTimes: { [number]: number } = {}
local DataService: any

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

    local equippedTool = character:FindFirstChild(BalanceConfig.Weapon.Name)
    if not equippedTool then return end

    local now = os.clock()
    local lastTime = lastAttackTimes[player.UserId] or 0
    if (now - lastTime) < (BalanceConfig.Weapon.Cooldown - 0.05) then
        return
    end
    lastAttackTimes[player.UserId] = now

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local handle = equippedTool:FindFirstChild("Handle") :: BasePart? or hrp

    if typeof(targetMonster) ~= "Instance" or not targetMonster:IsA("Model") then
        local forwardPos = hrp.Position + (hrp.CFrame.LookVector * BalanceConfig.Weapon.Range)
        local combatVisual = Network.GetEvent("CombatVisual")
        combatVisual:FireAllClients(handle.Position, forwardPos, false)
        return
    end

    local ownerId = targetMonster:GetAttribute("OwnerUserId")
    if ownerId ~= nil and ownerId ~= player.UserId then
        return
    end

    local targetHum = targetMonster:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetMonster.PrimaryPart or targetMonster:FindFirstChild("Torso") :: BasePart?

    if not targetHum or targetHum.Health <= 0 or not targetRoot then
        return
    end

    local dist = (hrp.Position - targetRoot.Position).Magnitude
    if dist > (BalanceConfig.Weapon.Range + 6) then
        return
    end

    local coreLevel = 1
    local data = DataService.GetData(player)
    if data and data.CoreLevel then
        coreLevel = data.CoreLevel
    end

    local multiplier = BalanceConfig.CoreLevels.GetWeaponDamageMultiplier(coreLevel)
    local damage = math.floor(BalanceConfig.Weapon.BaseDamage * multiplier)

    targetHum:TakeDamage(damage)

    local combatVisual = Network.GetEvent("CombatVisual")
    combatVisual:FireAllClients(handle.Position, targetRoot.Position, true)
end

function CombatService.ClearPlayer(player: Player)
    lastAttackTimes[player.UserId] = nil
end

return CombatService