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
