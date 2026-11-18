--!strict
--[[
    AdminConfig.luau
    Daftar Admin berdasarkan Username maupun UserId Roblox.
]]

local RunService = game:GetService("RunService")

local AdminConfig = {}

-- Masukkan Username Roblox kamu di sini
AdminConfig.AdminUsernames = {
    "uryowrs",
}

-- (Opsional) Masukkan UserId berupa angka jika ingin pakai UserId juga
AdminConfig.AdminUserIds = {
    -- Contoh: 123456789,
}

-- Otomatis izinkan akses Admin saat testing di Roblox Studio
AdminConfig.AllowStudioTesting = true

function AdminConfig.IsAdmin(player: Player): boolean
    if AdminConfig.AllowStudioTesting and RunService:IsStudio() then
        return true
    end

    local lowerName = string.lower(player.Name)
    for _, name in ipairs(AdminConfig.AdminUsernames) do
        if lowerName == string.lower(name) then
            return true
        end
    end

    for _, id in ipairs(AdminConfig.AdminUserIds) do
        if player.UserId == id then
            return true
        end
    end

    return false
end

return AdminConfig