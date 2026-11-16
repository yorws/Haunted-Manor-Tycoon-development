local updated = {}
do
    local target = game:GetService("StarterPlayer").StarterPlayerScripts.ClientMain
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
    local target = game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.CombatController
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
    local target = game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.PlotController
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
return 'Synced (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')
