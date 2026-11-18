--!strict
--[[
    PlotController.luau
    Handles client-side aesthetic pad animations, pulsing neon glow effects,
    and cleans up distant BillboardGui clutter so labels only appear near the player.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlotController = {}

local activeConnections: { [string]: RBXScriptConnection } = {}

local function applyBillboardDistance(desc: Instance)
    if desc:IsA("BillboardGui") then
        if desc.Name == "OwnerSign" or desc.Name == "HubSign" then
            desc.MaxDistance = 140
        elseif desc.Name == "CoreGui" then
            desc.MaxDistance = 95
        else
            desc.MaxDistance = 65
        end
    end
end

function PlotController.Init()
    local plotsFolder = Workspace:WaitForChild("Plots", 10) :: Folder?
    if not plotsFolder then return end

    -- Apply clean view distances to existing and newly spawned BillboardGuis
    for _, desc in ipairs(Workspace:GetDescendants()) do
        applyBillboardDistance(desc)
    end

    activeConnections["BillboardWatch"] = Workspace.DescendantAdded:Connect(function(desc)
        applyBillboardDistance(desc)
    end)

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

                -- Pulse only unlocked/available Upgrade Pads (leave locked dim pads at 0.7)
                local padsFolder = plot:FindFirstChild("Pads")
                if padsFolder then
                    for _, pad in ipairs(padsFolder:GetChildren()) do
                        if pad:IsA("BasePart") and pad.Transparency < 0.5 then
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