--!strict
--[[
    CombatController.luau
    Handles client-side Holy Lantern aiming, click-to-attack raycast/proximity targeting,
    beam visual effects, and Holy Laser Zap combat audio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules", 15)
ReplicatedStorage:WaitForChild("Remotes", 15)

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BalanceConfig"))
local Network = require(Modules:WaitForChild("Network"))

local CombatController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local lastAttack = 0
local attackSound: Sound

local function findNearestMonster(origin: Vector3, maxRange: number): Model?
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return nil end

    local bestMonster: Model? = nil
    local bestDist = maxRange

    for _, desc in ipairs(plotsFolder:GetDescendants()) do
        if desc:IsA("Model") and desc:GetAttribute("MonsterType") ~= nil then
            local hum = desc:FindFirstChildOfClass("Humanoid")
            local root = desc.PrimaryPart or desc:FindFirstChild("Torso") :: BasePart?
            if hum and hum.Health > 0 and root then
                local dist = (origin - root.Position).Magnitude
                if dist <= bestDist then
                    bestDist = dist
                    bestMonster = desc
                end
            end
        end
    end

    return bestMonster
end

local function spawnBeamEffect(startPos: Vector3, endPos: Vector3, hitMonster: boolean)
    local distance = (endPos - startPos).Magnitude
    if distance < 0.5 then return end

    local beam = Instance.new("Part")
    beam.Name = "HolyBeam"
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = if hitMonster then Color3.fromRGB(255, 240, 140) else Color3.fromRGB(200, 220, 255)
    beam.Size = Vector3.new(if hitMonster then 0.45 else 0.25, if hitMonster then 0.45 else 0.25, distance)
    beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
    beam.Parent = Workspace

    local tween = TweenService:Create(beam, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.05, 0.05, distance),
    })
    tween:Play()
    tween.Completed:Connect(function()
        beam:Destroy()
    end)
end

function CombatController.Init()
    attackSound = Instance.new("Sound")
    attackSound.Name = "LanternAttackSound"
    attackSound.SoundId = (BalanceConfig.Weapon and BalanceConfig.Weapon.SoundId) or "rbxassetid://130113322"
    attackSound.Volume = 0.7
    attackSound.PlaybackSpeed = 1.15
    attackSound.Parent = Workspace

    local combatVisualEvent = Network.GetEvent("CombatVisual")
    combatVisualEvent.OnClientEvent:Connect(function(startPos: Vector3, endPos: Vector3, hitMonster: boolean)
        spawnBeamEffect(startPos, endPos, hitMonster)
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local character = player.Character
            if not character then return end

            local weaponName = (BalanceConfig.Weapon and BalanceConfig.Weapon.Name) or "Holy Lantern"
            local equipped = character:FindFirstChild(weaponName)
            if not equipped then return end

            local cooldown = (BalanceConfig.Weapon and BalanceConfig.Weapon.Cooldown) or 0.5
            local now = os.clock()
            if (now - lastAttack) < cooldown then return end
            lastAttack = now

            local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hrp then return end

            local targetMonster: Model? = nil
            local hitInstance = mouse.Target
            if hitInstance then
                local candidate = hitInstance:FindFirstAncestorOfClass("Model")
                if candidate and candidate:GetAttribute("MonsterType") ~= nil then
                    targetMonster = candidate
                end
            end

            if not targetMonster then
                local range = (BalanceConfig.Weapon and BalanceConfig.Weapon.Range) or 36
                targetMonster = findNearestMonster(hrp.Position, range)
            end

            attackSound:Play()
            local attackEvent = Network.GetEvent("AttackRequest")
            attackEvent:FireServer(targetMonster)
        end
    end)
end

return CombatController