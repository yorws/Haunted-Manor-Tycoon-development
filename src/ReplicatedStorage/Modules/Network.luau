--!strict
--[[
    Network.luau
    Central network definition and initialization module.
    Automatically sets up RemoteFunctions and RemoteEvents in ReplicatedStorage.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

local REMOTE_FUNCTIONS = {
    "RequestPurchase",
    "RequestCollectVault",
    "RequestStartWave",
    "GetPlayerData",
}

local REMOTE_EVENTS = {
    "AttackRequest",
    "PlayerDataUpdated",
    "PlotAssigned",
    "WaveStateUpdated",
    "Notification",
    "CombatVisual",
}

local remotesFolder: Folder

local function getOrCreateRemotesFolder(): Folder
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = "Remotes"
            folder.Parent = ReplicatedStorage
        else
            folder = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder
            assert(folder, "[Network] Failed to locate Remotes folder on client!")
        end
    end
    return folder :: Folder
end

remotesFolder = getOrCreateRemotesFolder()

function Network.InitServer()
    assert(RunService:IsServer(), "[Network] InitServer can only be called on the server!")
    
    for _, name in ipairs(REMOTE_FUNCTIONS) do
        if not remotesFolder:FindFirstChild(name) then
            local rf = Instance.new("RemoteFunction")
            rf.Name = name
            rf.Parent = remotesFolder
        end
    end

    for _, name in ipairs(REMOTE_EVENTS) do
        if not remotesFolder:FindFirstChild(name) then
            local re = Instance.new("RemoteEvent")
            re.Name = name
            re.Parent = remotesFolder
        end
    end
end

function Network.GetFunction(name: string): RemoteFunction
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        if RunService:IsClient() then
            remote = remotesFolder:WaitForChild(name, 10)
        else
            remote = Instance.new("RemoteFunction")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end
    assert(remote and remote:IsA("RemoteFunction"), "[Network] RemoteFunction not found: " .. name)
    return remote
end

function Network.GetEvent(name: string): RemoteEvent
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        if RunService:IsClient() then
            remote = remotesFolder:WaitForChild(name, 10)
        else
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end
    assert(remote and remote:IsA("RemoteEvent"), "[Network] RemoteEvent not found: " .. name)
    return remote
end

return Network

