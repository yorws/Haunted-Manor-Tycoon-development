--!strict
--[[
    ClientMain.client.luau
    Root client-side entry point for Haunted Manor Tycoon.
    Initializes UI, Plot aesthetics, Combat input, Core Upgrade, and Admin controllers.
]]

local Controllers = script.Parent:WaitForChild("Controllers")
local UIController = require(Controllers:WaitForChild("UIController"))
local PlotController = require(Controllers:WaitForChild("PlotController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local CoreUpgradeController = require(Controllers:WaitForChild("CoreUpgradeController"))
local AdminController = require(Controllers:WaitForChild("AdminController"))

print("========================================")
print("  Haunted Manor Tycoon - Client Starting")
print("========================================")

UIController.Init()
PlotController.Init()
CombatController.Init()
CoreUpgradeController.Init()
AdminController.Init()

print("[ClientMain] All client controllers initialized successfully.")