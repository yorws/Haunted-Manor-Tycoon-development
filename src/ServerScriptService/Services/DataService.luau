--!strict
--[[
    DataService.luau
    Manages persistent player data via DataStoreService.
    Includes autosave, backoff retries, and seamless mock fallback for Studio without API access.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local DataService = {}

local sessionData: { [number]: Types.PlayerData } = {}
local dataStore: GlobalDataStore? = nil
local isDataStoreAvailable = false

local function initDataStore()
    local success, ds = pcall(function()
        return DataStoreService:GetDataStore(BalanceConfig.General.DataStoreKey)
    end)

    if success and ds then
        dataStore = ds
        -- Test read to verify API access
        local testSuccess = pcall(function()
            ds:GetAsync("__ping__")
        end)
        isDataStoreAvailable = testSuccess
        if not testSuccess then
            warn("[DataService] DataStore API access is disabled (Studio mode). Using in-memory fallback.")
        end
    else
        warn("[DataService] Could not initialize DataStore. Using in-memory fallback.")
        isDataStoreAvailable = false
    end
end

initDataStore()

local function createDefaultData(): Types.PlayerData
    return {
        Coins = BalanceConfig.General.StarterCoins,
        Souls = BalanceConfig.General.StarterSouls,
        UnlockedUpgrades = {},
        WaveNumber = 1,
        MonstersDefeated = 0,
        HasDoubleCoins = false,
        HasVip = false,
        CoreLevel = 1,
        Inventory = {},
        LastSaveTimestamp = os.time(),
    }
end

local function deepCopy(t: any): any
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

function DataService.LoadData(player: Player): Types.PlayerData
    local userId = player.UserId
    local key = "Player_" .. tostring(userId)
    local loadedData: Types.PlayerData? = nil

    if isDataStoreAvailable and dataStore then
        for attempt = 1, BalanceConfig.General.MaxSaveRetries do
            local success, result = pcall(function()
                return dataStore:GetAsync(key)
            end)

            if success then
                if type(result) == "table" then
                    loadedData = result :: Types.PlayerData
                end
                break
            else
                warn(string.format("[DataService] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
                task.wait(1 * attempt)
            end
        end
    end

    if not loadedData then
        loadedData = createDefaultData()
    else
        -- Ensure all schema fields exist
        local default = createDefaultData()
        for k, v in pairs(default) do
            if (loadedData :: any)[k] == nil then
                (loadedData :: any)[k] = v
            end
        end
    end

    sessionData[userId] = loadedData
    return sessionData[userId]
end

function DataService.SaveData(player: Player): boolean
    local userId = player.UserId
    local data = sessionData[userId]
    if not data then return false end

    data.LastSaveTimestamp = os.time()

    if not isDataStoreAvailable or not dataStore then
        return true -- Mock success in Studio
    end

    local key = "Player_" .. tostring(userId)
    for attempt = 1, BalanceConfig.General.MaxSaveRetries do
        local success, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)

        if success then
            return true
        else
            warn(string.format("[DataService] Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
            task.wait(1.5 * attempt)
        end
    end

    return false
end

function DataService.GetData(player: Player): Types.PlayerData?
    return sessionData[player.UserId]
end

function DataService.UpdateData(player: Player, updater: (data: Types.PlayerData) -> ()): Types.PlayerData?
    local data = sessionData[player.UserId]
    if data then
        updater(data)
        return data
    end
    return nil
end

function DataService.ReleaseSession(player: Player)
    DataService.SaveData(player)
    sessionData[player.UserId] = nil
end

function DataService.StartAutosave()
    task.spawn(function()
        while true do
            task.wait(BalanceConfig.General.AutosaveInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                DataService.SaveData(player)
            end
        end
    end)
end

-- BindToClose hook to save remaining players
game:BindToClose(function()
    print("[DataService] Server closing, saving all active players...")
    for _, player in ipairs(Players:GetPlayers()) do
        DataService.SaveData(player)
    end
    print("[DataService] All player data flushed.")
end)

return DataService

