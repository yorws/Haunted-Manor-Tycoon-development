--!strict
--[[
    AdminService.luau
    Server-side handler for Admin Panel cheats:
    - Add/Reset Coins & Souls
    - Instant Manor Core Level Up (+1, Max Lv. 20, Reset Lv. 1)
    - Grant Monster Loot items
    - Teleport to any Plot (1-6) or Market Hub, and inspect plot owners
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AdminConfig = require(ReplicatedStorage.Config.AdminConfig)
local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local AdminService = {}

local DataService: any
local EconomyService: any
local PlotService: any
local MonsterService: any
local ShopService: any

local function notifyAdmin(player: Player, msg: string, color: Color3?)
    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, "[ADMIN] " .. msg, color or Color3.fromRGB(255, 200, 70))
end

local function setCoreLevelDirect(player: Player, targetLevel: number)
    local clamped = math.clamp(targetLevel, 1, BalanceConfig.CoreLevels.MaxLevel or 20)
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.CoreLevel = clamped
    end)

    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        if MonsterService and MonsterService.ApplyCoreLevel then
            MonsterService.ApplyCoreLevel(plot, clamped)
        end
        if PlotService and PlotService.UpdateCoreLevelPad then
            PlotService.UpdateCoreLevelPad(plot, clamped)
        end
    end

    EconomyService.SyncClient(player)
    return clamped
end

function AdminService.Init(dataRef: any, econRef: any, plotRef: any, monsterRef: any, shopRef: any)
    DataService = dataRef
    EconomyService = econRef
    PlotService = plotRef
    MonsterService = monsterRef
    ShopService = shopRef

    local adminFn = Network.GetFunction("AdminCommand")
    adminFn.OnServerInvoke = function(player: Player, action: string, arg: any)
        if not AdminConfig.IsAdmin(player) then
            warn(string.format("[AdminService] Unauthorized admin attempt by %s (%d)", player.Name, player.UserId))
            return false, "Unauthorized"
        end

        return AdminService.ExecuteCommand(player, action, arg)
    end
end

function AdminService.GetPlotsInfo(): { { index: number, ownerName: string } }
    local list = {}
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return list end

    for i = 1, (BalanceConfig.General.MaxPlots or 6) do
        local plotModel = plotsFolder:FindFirstChild("Plot_" .. tostring(i))
        local ownerName = "Vacant"
        if plotModel then
            local attr = plotModel:GetAttribute("OwnerName")
            if type(attr) == "string" and attr ~= "" then
                ownerName = attr
            end
        end
        table.insert(list, {
            index = i,
            ownerName = ownerName,
        })
    end

    return list
end

function AdminService.ExecuteCommand(player: Player, action: string, arg: any): (boolean, any)
    local data = DataService.GetData(player)
    if not data then
        return false, "Player data not loaded."
    end

    -- 1. CHEAT DUIT & SOULS
    if action == "AddCoins" then
        local amount = tonumber(arg) or 1000
        EconomyService.AddCoins(player, amount, false)
        notifyAdmin(player, string.format("+%d Coins ditambahkan!", amount), Color3.fromRGB(255, 220, 70))
        return true, "Coins added"

    elseif action == "AddSouls" then
        local amount = tonumber(arg) or 100
        EconomyService.AddSouls(player, amount)
        notifyAdmin(player, string.format("+%d Souls ditambahkan!", amount), Color3.fromRGB(160, 240, 255))
        return true, "Souls added"

    elseif action == "ResetCurrency" then
        DataService.UpdateData(player, function(d: Types.PlayerData)
            d.Coins = 0
            d.Souls = 0
        end)
        EconomyService.SyncClient(player)
        notifyAdmin(player, "Coins & Souls di-reset ke 0.", Color3.fromRGB(255, 110, 110))
        return true, "Currency reset"

    -- 2. CHEAT UPGRADE MANOR CORE
    elseif action == "CoreLevelUp" then
        local nextLvl = (data.CoreLevel or 1) + 1
        local finalLvl = setCoreLevelDirect(player, nextLvl)
        notifyAdmin(player, string.format("Manor Core naik ke Lv. %d!", finalLvl), Color3.fromRGB(200, 120, 255))
        return true, finalLvl

    elseif action == "CoreMaxLevel" then
        local maxLvl = BalanceConfig.CoreLevels.MaxLevel or 20
        local finalLvl = setCoreLevelDirect(player, maxLvl)
        notifyAdmin(player, string.format("Manor Core MAX LEVEL (Lv. %d)!", finalLvl), Color3.fromRGB(255, 215, 0))
        return true, finalLvl

    elseif action == "CoreResetLevel" then
        local finalLvl = setCoreLevelDirect(player, 1)
        notifyAdmin(player, "Manor Core di-reset ke Lv. 1.", Color3.fromRGB(255, 130, 130))
        return true, finalLvl

    -- 3. CHEAT LOOT
    elseif action == "AddAllLoot" then
        local qty = tonumber(arg) or 10
        DataService.UpdateData(player, function(d: Types.PlayerData)
            if not d.Inventory then
                d.Inventory = {}
            end
            for _, drop in pairs(BalanceConfig.MonsterDrops) do
                d.Inventory[drop.ItemId] = (d.Inventory[drop.ItemId] or 0) + qty
            end
        end)
        EconomyService.SyncClient(player)
        notifyAdmin(player, string.format("+%d semua jenis Loot masuk ke tas!", qty), Color3.fromRGB(120, 255, 160))
        return true, "Loot granted"

    elseif action == "SellAllLoot" then
        if ShopService and ShopService.SellAllInventory then
            return ShopService.SellAllInventory(player)
        end
        return false, "ShopService unavailable"

    -- 4. MASUK / TELEPORT KE PLOT LAIN ATAU MARKET HUB
    elseif action == "GetPlotsInfo" then
        return true, AdminService.GetPlotsInfo()

    elseif action == "TeleportToPlot" then
        local plotIndex = tonumber(arg) or 1
        local plotsFolder = Workspace:FindFirstChild("Plots")
        local targetPlot = plotsFolder and plotsFolder:FindFirstChild("Plot_" .. tostring(plotIndex)) :: Model?
        if not targetPlot then
            return false, "Plot tidak ditemukan."
        end

        local plotBase = targetPlot:FindFirstChild("PlotBase") :: BasePart?
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not plotBase or not character or not hrp then
            return false, "Karakter belum siap."
        end

        local destPos = (plotBase.CFrame * CFrame.new(0, 5, -10)).Position
        local lookAtCore = (plotBase.CFrame * CFrame.new(0, 5, -28)).Position
        hrp.AssemblyLinearVelocity = Vector3.zero
        character:PivotTo(CFrame.lookAt(destPos, lookAtCore))

        local ownerName = (targetPlot:GetAttribute("OwnerName") :: string?) or "Vacant"
        notifyAdmin(player, string.format("Teleport ke Arena #%d (%s)", plotIndex, ownerName), Color3.fromRGB(130, 220, 255))
        return true, "Teleported"

    elseif action == "TeleportToHub" then
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not character or not hrp then
            return false, "Karakter belum siap."
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
        character:PivotTo(CFrame.lookAt(Vector3.new(0, 5, 6), Vector3.new(0, 5, 15)))
        notifyAdmin(player, "Teleport ke Haunted Market Hub!", Color3.fromRGB(130, 220, 255))
        return true, "Teleported to Hub"
    end

    return false, "Unknown admin action"
end

return AdminService