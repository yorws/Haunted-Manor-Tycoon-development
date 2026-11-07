--!strict
--[[
    MonetizationConfig.luau
    Placeholder IDs and configurations for GamePasses and Developer Products.
    Replace 0 with real Roblox asset IDs before publishing.
]]

local MonetizationConfig = {}

-- GamePass Asset IDs (Create these in Roblox Creator Dashboard)
MonetizationConfig.Gamepasses = {
    DoubleCoins = 0, -- Grants x2 Coins earned from visitors & waves
    VipPlot = 0,     -- Gives golden plot aesthetic, 20% room discount, +10 bonus souls on join
}

-- Developer Product IDs (Create these in Roblox Creator Dashboard)
MonetizationConfig.DevProducts = {
    Souls50 = 0,   -- Instant +50 Souls pack
    Souls200 = 0,  -- Instant +200 Souls mega pack
}

-- Multipliers & Perks
MonetizationConfig.Perks = {
    DoubleCoinsMultiplier = 2.0,
    VipDiscountMultiplier = 0.8, -- 20% off Coin upgrade costs
    VipSoulsGift = 10,
}

return MonetizationConfig

