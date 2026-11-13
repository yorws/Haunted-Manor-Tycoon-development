--!strict
--[[
    ShopService.luau
    Handles:
    1. Selling inventory monster drops for Coins
    2. Upgrading Manor Core Level (up to Level 20, +150 HP per level)
    3. Core Skills management:
       - Level 10: Spectral Retaliation (When HP < 50%, zaps 10 nearest monsters for 175 dmg, 35s CD)
       - Level 20: Ghost Cloak (When HP < 35%, becomes invincible for 5s, 50s CD)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local ShopService = {}

local DataService: any
local EconomyService: any
local PlotService: any
local MonsterService: any

-- Skill runtime state per plot model
type PlotSkillState = {
    LastL10Trigger: number,
    LastL20Trigger: number,
    IsGhostCloaked: boolean,
    CloakExpiresAt: number,
}

local plotSkillStates: { [Model]: PlotSkillState } = {}

function ShopService.Init(dataServiceRef: any, economyServiceRef: any, plotServiceRef: any, monsterServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    PlotService = plotServiceRef
    MonsterService = monsterServiceRef

    -- RemoteFunction: RequestSellInventory
    local sellFn = Network.GetFunction("RequestSellInventory")
    sellFn.OnServerInvoke = function(player: Player)
        return ShopService.SellAllInventory(player)
    end

    -- RemoteFunction: RequestCoreLevelUp
    local levelUpFn = Network.GetFunction("RequestCoreLevelUp")
    levelUpFn.OnServerInvoke = function(player: Player)
        return ShopService.UpgradeCore(player)
    end
end

function ShopService.GetSkillState(plotModel: Model): PlotSkillState
    if not plotSkillStates[plotModel] then
        plotSkillStates[plotModel] = {
            LastL10Trigger = 0,
            LastL20Trigger = 0,
            IsGhostCloaked = false,
            CloakExpiresAt = 0,
        }
    end
    return plotSkillStates[plotModel]
end

function ShopService.IsGhostCloaked(plotModel: Model): boolean
    local s = plotSkillStates[plotModel]
    if not s then return false end
    if s.IsGhostCloaked then
        if os.clock() > s.CloakExpiresAt then
            s.IsGhostCloaked = false
            -- Reset core transparency
            local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
            if core then
                core.Transparency = 0
            end
            return false
        end
        return true
    end
    return false
end

-- Sells all monster loot in the player's inventory for coins
function ShopService.SellAllInventory(player: Player): (boolean, number, string)
    local data = DataService.GetData(player)
    if not data then return false, 0, "No player data." end

    local inv = data.Inventory
    if not inv then return false, 0, "Inventory empty." end

    local totalCoins = 0
    local totalItems = 0

    -- Lookup table for prices
    local priceMap: { [string]: number } = {}
    for _, drop in pairs(BalanceConfig.MonsterDrops) do
        priceMap[drop.ItemId] = drop.SellPrice
    end

    for itemId, count in pairs(inv) do
        if count > 0 and priceMap[itemId] then
            totalCoins += (priceMap[itemId] * count)
            totalItems += count
        end
    end

    if totalCoins <= 0 or totalItems <= 0 then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, "🛒 Your inventory has no loot to sell! Defeat monsters first.", Color3.fromRGB(240, 200, 80))
        return false, 0, "No items to sell."
    end

    -- Clear sold items
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.Inventory = {}
    end)

    EconomyService.AddCoins(player, totalCoins, true)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("💰 Sold %d monster loot for +%d Coins!", totalItems, totalCoins), Color3.fromRGB(80, 255, 120))

    return true, totalCoins, "Items sold successfully."
end

-- Upgrades Manor Core level
function ShopService.UpgradeCore(player: Player): (boolean, number, string)
    local data = DataService.GetData(player)
    if not data then return false, 0, "Data not loaded." end

    local currentLvl = data.CoreLevel or 1
    local maxLvl = BalanceConfig.CoreLevels.MaxLevel

    if currentLvl >= maxLvl then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, "🔮 Manor Core is already at MAX LEVEL (Level 20)!", Color3.fromRGB(255, 215, 0))
        return false, currentLvl, "Max level reached."
    end

    local cost = BalanceConfig.CoreLevels.GetUpgradeCost(currentLvl)
    if data.Coins < cost then
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, string.format("❌ Need %d Coins to upgrade Manor Core! (You have %d)", cost, data.Coins), Color3.fromRGB(255, 80, 80))
        return false, currentLvl, "Insufficient coins."
    end

    EconomyService.DeductCoins(player, cost)

    local newLevel = currentLvl + 1
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.CoreLevel = newLevel
    end)

    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        MonsterService.ApplyCoreLevel(plot, newLevel)
        PlotService.UpdateCoreLevelPad(plot, newLevel)
    end

    local newMaxHp = BalanceConfig.CoreLevels.GetMaxHp(newLevel)
    local skillUnlockMsg = ""
    if newLevel == 10 then
        skillUnlockMsg = "\n⚡ UNLOCKED SKILL: Spectral Retaliation! (Auto zaps 10 monsters when HP < 50%)"
    elseif newLevel == 20 then
        skillUnlockMsg = "\n🛡️ UNLOCKED SKILL: Ghost Cloak! (Auto invulnerable for 5s when HP < 35%)"
    end

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("🔮 Manor Core upgraded to Level %d! Max HP: %d!%s", newLevel, newMaxHp, skillUnlockMsg), Color3.fromRGB(200, 100, 255))

    EconomyService.SyncClient(player)
    return true, newLevel, "Core upgraded."
end

-- Checks and fires Level 10 and Level 20 skills during active combat
function ShopService.CheckSkills(player: Player, plotModel: Model, state: any)
    local data = DataService.GetData(player)
    if not data then return end

    local level = data.CoreLevel or 1
    local now = os.clock()
    local skillState = ShopService.GetSkillState(plotModel)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local hpPct = state.CoreHealth / state.CoreMaxHealth

    -- 1. Level 10 Skill: Spectral Retaliation (HP < 50%, zaps 10 nearest monsters)
    if level >= 10 and hpPct < 0.50 then
        local l10Config = BalanceConfig.CoreLevels.Skills.Level10
        if (now - skillState.LastL10Trigger) >= l10Config.Cooldown then
            skillState.LastL10Trigger = now

            -- Find up to 10 active monsters within range
            local targets: { { monster: Model, dist: number } } = {}
            for _, monster in ipairs(state.ActiveMonsters) do
                if monster and monster.Parent and monster.PrimaryPart then
                    local hum = monster:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local d = (monster.PrimaryPart.Position - core.Position).Magnitude
                        if d <= l10Config.Range then
                            table.insert(targets, { monster = monster, dist = d })
                        end
                    end
                end
            end

            table.sort(targets, function(a, b) return a.dist < b.dist end)

            local hitCount = 0
            local combatVisual = Network.GetEvent("CombatVisual")
            for i = 1, math.min(#targets, l10Config.TargetCount) do
                local target = targets[i].monster
                local hum = target:FindFirstChildOfClass("Humanoid")
                local targetRoot = target.PrimaryPart
                if hum and targetRoot then
                    hum:TakeDamage(l10Config.Damage)
                    hitCount += 1
                    combatVisual:FireAllClients(core.Position, targetRoot.Position, true)
                end
            end

            if hitCount > 0 then
                local notif = Network.GetEvent("Notification")
                notif:FireClient(player, string.format("⚡ SPECTRAL RETALIATION! Manor Core zapped %d monsters for %d damage!", hitCount, l10Config.Damage), Color3.fromRGB(130, 240, 255))
            end
        end
    end

    -- 2. Level 20 Skill: Ghost Cloak (HP < 35%, becomes invincible for 5s)
    if level >= 20 and hpPct < 0.35 then
        local l20Config = BalanceConfig.CoreLevels.Skills.Level20
        if (now - skillState.LastL20Trigger) >= l20Config.Cooldown and not skillState.IsGhostCloaked then
            skillState.LastL20Trigger = now
            skillState.IsGhostCloaked = true
            skillState.CloakExpiresAt = now + l20Config.Duration

            -- Ghostly visual effect on Core
            core.Transparency = 0.75
            local notif = Network.GetEvent("Notification")
            notif:FireClient(player, "👻 GHOST CLOAK ACTIVATED! Manor Core is invulnerable for 5 seconds!", Color3.fromRGB(220, 160, 255))

            task.delay(l20Config.Duration, function()
                if plotModel.Parent and core.Parent then
                    skillState.IsGhostCloaked = false
                    core.Transparency = 0
                    local endNotif = Network.GetEvent("Notification")
                    endNotif:FireClient(player, "🛡️ Ghost Cloak expired.", Color3.fromRGB(180, 180, 200))
                end
            end)
        end
    end
end

function ShopService.ClearPlot(plotModel: Model)
    plotSkillStates[plotModel] = nil
end

return ShopService

