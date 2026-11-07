--!strict
--[[
    GuiTheme.luau
    Spooky Gothic color palette and typography constants used across the game's UI.
]]

local GuiTheme = {
    Colors = {
        Background = Color3.fromRGB(24, 20, 28),
        BackgroundCard = Color3.fromRGB(35, 30, 40),
        Border = Color3.fromRGB(90, 70, 110),
        AccentPurple = Color3.fromRGB(180, 70, 255),
        CoinsGold = Color3.fromRGB(255, 220, 70),
        SoulsCyan = Color3.fromRGB(160, 240, 255),
        HealthGreen = Color3.fromRGB(80, 230, 100),
        HealthOrange = Color3.fromRGB(240, 160, 50),
        HealthRed = Color3.fromRGB(240, 50, 50),
        TextPrimary = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(210, 200, 225),
    },
    Fonts = {
        Header = Enum.Font.GothamBold,
        Body = Enum.Font.GothamMedium,
        Sign = Enum.Font.GothamBlack,
    },
}

return GuiTheme

