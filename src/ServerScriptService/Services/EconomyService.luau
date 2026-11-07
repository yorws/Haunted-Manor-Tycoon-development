--!strict
--[[
    EconomyService.luau
    Authoritative server-side management for Coins, Souls, and plot Vault income.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local EconomyService = {}

-- In-memory pending vault storage for each player (coins accumulated by visitors)
local playerVaults: { [number]: number } = {}

-- References injected by bootstrap or lazy-required
local DataService: any

function EconomyService.Init(dataServiceRef: any)
    DataService = dataServiceRef

    local requestCollectFn = Network.GetFunction("RequestCollectVault")
    requestCollectFn.OnServerInvoke = function(player: Player)
        local collected = EconomyService.CollectVault(player)
        return true, collected
    end
end

function EconomyService.GetVaultBalance(player: Player): number
    return playerVaults[player.UserId] or 0
end

function EconomyService.DepositToVault(player: Player, rawAmount: number)
    local data = DataService.GetData(player)
    if not data then return end

    local multiplier = 1.0
    if data.HasDoubleCoins then
        multiplier = MonetizationConfig.Perks.DoubleCoinsMultiplier
    end

    local finalAmount = math.floor(rawAmount * multiplier)
    playerVaults[player.UserId] = (playerVaults[player.UserId] or 0) + finalAmount
end

function EconomyService.CollectVault(player: Player): number
    local pending = playerVaults[player.UserId] or 0
    if pending <= 0 then return 0 end

    playerVaults[player.UserId] = 0
    EconomyService.AddCoins(player, pending, false)

    local notifEvent = Network.GetEvent("Notification")
    notifEvent:FireClient(player, string.format("Collected +%d Coins from Manor Vault! 🪙", pending), Color3.fromRGB(255, 215, 0))

    return pending
end

function EconomyService.AddCoins(player: Player, amount: number, applyMultipliers: boolean?): number
    if amount <= 0 then return 0 end
    local finalAmount = amount

    local data = DataService.GetData(player)
    if not data then return 0 end

    if applyMultipliers and data.HasDoubleCoins then
        finalAmount = math.floor(amount * MonetizationConfig.Perks.DoubleCoinsMultiplier)
    end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Coins += finalAmount
    end)

    EconomyService.SyncClient(player)
    return finalAmount
end

function EconomyService.AddSouls(player: Player, amount: number): number
    if amount <= 0 then return 0 end
    local data = DataService.GetData(player)
    if not data then return 0 end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Souls += amount
    end)

    EconomyService.SyncClient(player)
    return amount
end

function EconomyService.DeductCoins(player: Player, amount: number): boolean
    if amount <= 0 then return true end
    local data = DataService.GetData(player)
    if not data or data.Coins < amount then return false end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Coins -= amount
    end)

    EconomyService.SyncClient(player)
    return true
end

function EconomyService.DeductSouls(player: Player, amount: number): boolean
    if amount <= 0 then return true end
    local data = DataService.GetData(player)
    if not data or data.Souls < amount then return false end

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Souls -= amount
    end)

    EconomyService.SyncClient(player)
    return true
end

function EconomyService.SyncClient(player: Player)
    local data = DataService.GetData(player)
    if data then
        local updateEvent = Network.GetEvent("PlayerDataUpdated")
        updateEvent:FireClient(player, data)
    end
end

function EconomyService.ClearPlayer(player: Player)
    playerVaults[player.UserId] = nil
end

return EconomyService

