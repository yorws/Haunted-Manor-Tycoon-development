--!strict
--[[
    AdminController.luau
    Client-side Admin Panel GUI (only visible to authorized Admins in AdminConfig).
    Toggle via the top-right "ADMIN" button or pressing F4.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AdminConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AdminConfig"))
local Network = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"))

local AdminController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local panelFrame: Frame
local plotButtons: { [number]: TextButton } = {}

local function createCorner(parent: GuiObject, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function createStroke(parent: GuiObject, color: Color3, thickness: number)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Parent = parent
end

local function sendAdminCommand(action: string, arg: any): (boolean, any)
    local adminFn = Network.GetFunction("AdminCommand")
    local ok, success, result = pcall(function()
        return adminFn:InvokeServer(action, arg)
    end)
    if ok then
        return success, result
    end
    return false, nil
end

local function refreshPlotList()
    local ok, plots = sendAdminCommand("GetPlotsInfo", nil)
    if ok and type(plots) == "table" then
        for _, info in ipairs(plots) do
            local btn = plotButtons[info.index]
            if btn then
                local isVacant = info.ownerName == "Vacant"
                btn.Text = string.format("Plot #%d\n%s", info.index, if isVacant then "[Kosong]" else info.ownerName)
                btn.BackgroundColor3 = if isVacant then Color3.fromRGB(48, 45, 58) else Color3.fromRGB(65, 95, 145)
            end
        end
    end
end

local function createSectionTitle(parent: Instance, text: string, order: number)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 210, 90)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.Parent = parent
end

local function createActionButton(parent: Instance, text: string, bgColor: Color3, onClick: () -> ())
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.315, 0, 0, 32)
    btn.BackgroundColor3 = bgColor
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.TextWrapped = true
    btn.Parent = parent
    createCorner(btn, 7)

    btn.MouseButton1Click:Connect(onClick)
    return btn
end

function AdminController.Init()
    if not AdminConfig.IsAdmin(player) then
        return
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AdminPanelGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- Tombol Toggle di Kanan Atas
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "AdminToggleBtn"
    toggleBtn.Size = UDim2.new(0, 110, 0, 36)
    toggleBtn.Position = UDim2.new(1, -125, 0, 16)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(165, 45, 55)
    toggleBtn.Text = "🛡️ ADMIN [F4]"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 12
    toggleBtn.Font = Enum.Font.GothamBlack
    toggleBtn.Parent = screenGui
    createCorner(toggleBtn, 9)
    createStroke(toggleBtn, Color3.fromRGB(255, 200, 90), 1.5)

    -- Panel Utama
    panelFrame = Instance.new("Frame")
    panelFrame.Name = "AdminPanel"
    panelFrame.Size = UDim2.new(0, 340, 0, 415)
    panelFrame.Position = UDim2.new(1, -355, 0, 60)
    panelFrame.BackgroundColor3 = Color3.fromRGB(22, 19, 28)
    panelFrame.BackgroundTransparency = 0.08
    panelFrame.Visible = false
    panelFrame.Parent = screenGui
    createCorner(panelFrame, 12)
    createStroke(panelFrame, Color3.fromRGB(255, 190, 70), 1.8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🛡️ ADMIN CHEAT & PLOT CONTROL"
    title.TextColor3 = Color3.fromRGB(255, 220, 90)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panelFrame

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -20, 1, -46)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.CanvasSize = UDim2.new(0, 0, 0, 380)
    content.Parent = panelFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = content

    -- SECTION 1: CHEAT DUIT & SOULS
    createSectionTitle(content, "💰 CHEAT DUIT & SOULS", 1)
    local moneyRow = Instance.new("Frame")
    moneyRow.Size = UDim2.new(1, 0, 0, 34)
    moneyRow.BackgroundTransparency = 1
    moneyRow.LayoutOrder = 2
    moneyRow.Parent = content
    local moneyLayout = Instance.new("UIListLayout")
    moneyLayout.FillDirection = Enum.FillDirection.Horizontal
    moneyLayout.Padding = UDim.new(0, 6)
    moneyLayout.Parent = moneyRow

    createActionButton(moneyRow, "+50K Koin", Color3.fromRGB(185, 140, 30), function()
        sendAdminCommand("AddCoins", 50000)
    end)
    createActionButton(moneyRow, "+500 Souls", Color3.fromRGB(45, 135, 175), function()
        sendAdminCommand("AddSouls", 500)
    end)
    createActionButton(moneyRow, "Reset Duit", Color3.fromRGB(145, 45, 45), function()
        sendAdminCommand("ResetCurrency", nil)
    end)

    -- SECTION 2: CHEAT UPGRADE MANOR CORE
    createSectionTitle(content, "🔮 CHEAT UPGRADE MANOR CORE", 3)
    local coreRow = Instance.new("Frame")
    coreRow.Size = UDim2.new(1, 0, 0, 34)
    coreRow.BackgroundTransparency = 1
    coreRow.LayoutOrder = 4
    coreRow.Parent = content
    local coreLayout = Instance.new("UIListLayout")
    coreLayout.FillDirection = Enum.FillDirection.Horizontal
    coreLayout.Padding = UDim.new(0, 6)
    coreLayout.Parent = coreRow

    createActionButton(coreRow, "+1 Level", Color3.fromRGB(125, 65, 185), function()
        sendAdminCommand("CoreLevelUp", nil)
    end)
    createActionButton(coreRow, "MAX Lv. 20", Color3.fromRGB(175, 55, 145), function()
        sendAdminCommand("CoreMaxLevel", nil)
    end)
    createActionButton(coreRow, "Reset Lv. 1", Color3.fromRGB(95, 55, 75), function()
        sendAdminCommand("CoreResetLevel", nil)
    end)

    -- SECTION 3: CHEAT LOOT
    createSectionTitle(content, "🎒 CHEAT MONSTER LOOT", 5)
    local lootRow = Instance.new("Frame")
    lootRow.Size = UDim2.new(1, 0, 0, 34)
    lootRow.BackgroundTransparency = 1
    lootRow.LayoutOrder = 6
    lootRow.Parent = content
    local lootLayout = Instance.new("UIListLayout")
    lootLayout.FillDirection = Enum.FillDirection.Horizontal
    lootLayout.Padding = UDim.new(0, 6)
    lootLayout.Parent = lootRow

    createActionButton(lootRow, "+10 All Loot", Color3.fromRGB(45, 145, 85), function()
        sendAdminCommand("AddAllLoot", 10)
    end)
    createActionButton(lootRow, "+100 All Loot", Color3.fromRGB(35, 125, 105), function()
        sendAdminCommand("AddAllLoot", 100)
    end)
    createActionButton(lootRow, "Jual Semua", Color3.fromRGB(165, 115, 35), function()
        sendAdminCommand("SellAllLoot", nil)
    end)

    -- SECTION 4: MASUK KE PLOT LAIN & MARKET HUB
    createSectionTitle(content, "🏰 MASUK KE PLOT LAIN / MARKET HUB", 7)

    local hubBtn = Instance.new("TextButton")
    hubBtn.Size = UDim2.new(0.98, 0, 0, 30)
    hubBtn.BackgroundColor3 = Color3.fromRGB(50, 125, 155)
    hubBtn.Text = "🏛️ Teleport ke Haunted Market Hub"
    hubBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hubBtn.TextSize = 12
    hubBtn.Font = Enum.Font.GothamBold
    hubBtn.LayoutOrder = 8
    hubBtn.Parent = content
    createCorner(hubBtn, 7)
    hubBtn.MouseButton1Click:Connect(function()
        sendAdminCommand("TeleportToHub", nil)
    end)

    local plotGrid = Instance.new("Frame")
    plotGrid.Size = UDim2.new(1, 0, 0, 100)
    plotGrid.BackgroundTransparency = 1
    plotGrid.LayoutOrder = 9
    plotGrid.Parent = content

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.315, 0, 0, 44)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    gridLayout.Parent = plotGrid

    for i = 1, 6 do
        local pBtn = Instance.new("TextButton")
        pBtn.BackgroundColor3 = Color3.fromRGB(48, 45, 58)
        pBtn.Text = string.format("Plot #%d\n[Kosong]", i)
        pBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        pBtn.TextSize = 11
        pBtn.Font = Enum.Font.GothamBold
        pBtn.TextWrapped = true
        pBtn.Parent = plotGrid
        createCorner(pBtn, 7)

        pBtn.MouseButton1Click:Connect(function()
            sendAdminCommand("TeleportToPlot", i)
            refreshPlotList()
        end)

        plotButtons[i] = pBtn
    end

    local function togglePanel()
        panelFrame.Visible = not panelFrame.Visible
        if panelFrame.Visible then
            refreshPlotList()
        end
    end

    toggleBtn.MouseButton1Click:Connect(togglePanel)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F4 then
            togglePanel()
        end
    end)
end

return AdminController