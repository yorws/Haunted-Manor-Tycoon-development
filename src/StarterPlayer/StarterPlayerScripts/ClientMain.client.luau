--!strict
--[[
    ClientMain.client.luau
    Root client-side entry point for Haunted Manor Tycoon.
    Initializes UI, Plot aesthetics, and Combat input controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Controllers = script.Parent:WaitForChild("Controllers")
local UIController = require(Controllers:WaitForChild("UIController"))
local PlotController = require(Controllers:WaitForChild("PlotController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))

print("========================================")
print("  Haunted Manor Tycoon - Client Starting")
print("========================================")

-- Initialize Controllers
UIController.Init()
PlotController.Init()
CombatController.Init()

print("[ClientMain] All client controllers initialized successfully.")

