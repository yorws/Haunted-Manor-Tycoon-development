--!strict
--[[
    MonetizationService.luau
    Handles GamePass ownership checks, developer product receipts,
    and grants monetization perks (2x Coins, VIP Plot, Souls packs).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local MonetizationService = {}

local DataService: any
local EconomyService: any

function MonetizationService.Init(dataServiceRef: any, economyServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef

    -- ProcessReceipt callback for Developer Products
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local productId = receiptInfo.ProductId

        if productId == MonetizationConfig.DevProducts.Souls50 and productId ~= 0 then
            EconomyService.AddSouls(player, 50)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        elseif productId == MonetizationConfig.DevProducts.Souls200 and productId ~= 0 then
            EconomyService.AddSouls(player, 200)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end

        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Gamepass purchase listener
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if wasPurchased then
            if passId == MonetizationConfig.Gamepasses.DoubleCoins and passId ~= 0 then
                DataService.UpdateData(player, function(d: Types.PlayerData)
                    d.HasDoubleCoins = true
                end)
                EconomyService.SyncClient(player)
            elseif passId == MonetizationConfig.Gamepasses.VipPlot and passId ~= 0 then
                DataService.UpdateData(player, function(d: Types.PlayerData)
                    d.HasVip = true
                end)
                EconomyService.SyncClient(player)
            end
        end
    end)
end

function MonetizationService.CheckPlayerPasses(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    -- Check 2x Coins
    local doublePassId = MonetizationConfig.Gamepasses.DoubleCoins
    if doublePassId and doublePassId > 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, doublePassId)
        end)
        if success and owns then
            data.HasDoubleCoins = true
        end
    end

    -- Check VIP Plot
    local vipPassId = MonetizationConfig.Gamepasses.VipPlot
    if vipPassId and vipPassId > 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipPassId)
        end)
        if success and owns then
            data.HasVip = true
        end
    end
end

return MonetizationService

