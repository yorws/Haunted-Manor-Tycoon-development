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

