--!strict
--[[
    MonsterService.luau
    Manages monster spawning, wave stat scaling, anti-stuck navigation towards the Manor Core,
    progressive wave coin rewards, sculpted 3D evolving Manor Core architecture (Lv. 1 - 20),
    Core destruction/repair/upgrade animations, and loot drops.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BalanceConfig = require(ReplicatedStorage.Config.BalanceConfig)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Modules.Types)

local MonsterService = {}

type PlotWaveState = {
    WaveNumber: number,
    Status: Types.WaveStatus,
    TimeRemaining: number,
    ActiveMonsters: { Model },
    MonstersRemaining: number,
    CoreHealth: number,
    CoreMaxHealth: number,
    LastDamageTime: number,
    LastRegenTick: number,
}

local plotWaveStates: { [Model]: PlotWaveState } = {}
local monsterOwnerMap: { [Model]: Player } = {}

local DataService: any
local EconomyService: any
local PlotService: any
local ItemDropService: any
local ShopService: any

local function ensureServices()
    local sss = game:GetService("ServerScriptService")
    local services = sss:FindFirstChild("Services") or sss
    if not DataService then DataService = require(services:WaitForChild("DataService")) end
    if not EconomyService then EconomyService = require(services:WaitForChild("EconomyService")) end
    if not PlotService then PlotService = require(services:WaitForChild("PlotService")) end
    if not ItemDropService then ItemDropService = require(services:WaitForChild("ItemDropService")) end
    if not ShopService then ShopService = require(services:WaitForChild("ShopService")) end
end

local function createSpatialSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number): Sound
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = pitch
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 12
    sound.RollOffMaxDistance = 90
    sound.Parent = parent
    return sound
end

local function getCoreTierVisuals(level: number): {
    primaryColor: Color3,
    secondaryColor: Color3,
    accentColor: Color3,
    stoneColor: Color3,
    tierName: string,
}
    local lvl = math.clamp(level, 1, 20)
    if lvl >= 20 then
        return {
            primaryColor = Color3.fromRGB(255, 248, 205),
            secondaryColor = Color3.fromRGB(255, 205, 70),
            accentColor = Color3.fromRGB(160, 240, 255),
            stoneColor = Color3.fromRGB(225, 220, 235),
            tierName = "Astral Cathedral",
        }
    elseif lvl >= 15 then
        return {
            primaryColor = Color3.fromRGB(245, 50, 95),
            secondaryColor = Color3.fromRGB(255, 155, 60),
            accentColor = Color3.fromRGB(255, 215, 90),
            stoneColor = Color3.fromRGB(36, 26, 38),
            tierName = "Crimson Sovereign",
        }
    elseif lvl >= 10 then
        return {
            primaryColor = Color3.fromRGB(70, 225, 255),
            secondaryColor = Color3.fromRGB(145, 120, 255),
            accentColor = Color3.fromRGB(255, 220, 100),
            stoneColor = Color3.fromRGB(48, 54, 72),
            tierName = "Celestial Sanctum",
        }
    elseif lvl >= 5 then
        return {
            primaryColor = Color3.fromRGB(105, 165, 255),
            secondaryColor = Color3.fromRGB(130, 245, 220),
            accentColor = Color3.fromRGB(190, 215, 255),
            stoneColor = Color3.fromRGB(55, 58, 74),
            tierName = "Arcane Spire",
        }
    else
        return {
            primaryColor = Color3.fromRGB(185, 85, 255),
            secondaryColor = Color3.fromRGB(235, 145, 255),
            accentColor = Color3.fromRGB(140, 215, 255),
            stoneColor = Color3.fromRGB(58, 52, 68),
            tierName = "Awakened Relic",
        }
    end
end

local function getIntactCoreCFrame(plotModel: Model, level: number): (CFrame, Vector3)
    local pedestal = plotModel:FindFirstChild("CorePedestal") :: BasePart?
    local lvl = math.clamp(level, 1, 20)
    local scaleBoost = (lvl - 1) * 0.11
    local targetSize = Vector3.new(3.6 + scaleBoost, 5.2 + (scaleBoost * 1.4), 3.6 + scaleBoost)
    if pedestal then
        local cf = pedestal.CFrame * CFrame.new(0, (pedestal.Size.Y * 0.5) + 4.8 + (scaleBoost * 0.7), 0)
            * CFrame.Angles(math.rad(16), math.rad(45), math.rad(16))
        return cf, targetSize
    end
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    return (if core then core.CFrame else CFrame.new()), targetSize
end

local function buildGothicSpireTip(parent: Instance, centerCF: CFrame, baseWidth: number, height: number, color: Color3, material: Enum.Material)
    local halfW = baseWidth * 0.5
    for i = 0, 3 do
        local rot = CFrame.Angles(0, math.rad(i * 90), 0)
        local wedge = Instance.new("WedgePart")
        wedge.Name = "SpireWedge"
        wedge.Size = Vector3.new(baseWidth, height, halfW)
        wedge.CFrame = centerCF * rot * CFrame.new(0, height * 0.5, halfW * 0.5)
        wedge.Color = color
        wedge.Material = material
        wedge.Anchored = true
        wedge.CanCollide = false
        wedge.Parent = parent
    end
end

function MonsterService.RebuildCoreArchitecture(plotModel: Model, level: number)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    local pedestal = plotModel:FindFirstChild("CorePedestal") :: BasePart?
    if not core or not pedestal then return end

    local lvl = math.clamp(level, 1, 20)
    local theme = getCoreTierVisuals(lvl)
    local intactCF, intactSize = getIntactCoreCFrame(plotModel, lvl)

    local oldDecor = plotModel:FindFirstChild("CoreDecorations")
    if oldDecor then
        oldDecor:Destroy()
    end

    local decorFolder = Instance.new("Folder")
    decorFolder.Name = "CoreDecorations"
    decorFolder.Parent = plotModel

    pedestal.Transparency = 1
    pedestal.CanCollide = false
    local pedBasePos = Vector3.new(pedestal.Position.X, pedestal.Position.Y - (pedestal.Size.Y * 0.5), pedestal.Position.Z)

    -- 1. Altar Melingkar 3 Undakan (Circular Tiered Dais)
    local daisTiers = {
        { radius = 15.5 + (lvl * 0.12), height = 0.65, color = theme.stoneColor },
        { radius = 12.2 + (lvl * 0.10), height = 0.65, color = theme.stoneColor },
        { radius = 9.0 + (lvl * 0.08), height = 0.75, color = theme.stoneColor },
    }
    local currentY = pedBasePos.Y
    for idx, tier in ipairs(daisTiers) do
        local stepCyl = Instance.new("Part")
        stepCyl.Name = "AltarStep_" .. idx
        stepCyl.Shape = Enum.PartType.Cylinder
        stepCyl.Size = Vector3.new(tier.height, tier.radius * 2, tier.radius * 2)
        stepCyl.CFrame = CFrame.new(pedBasePos.X, currentY + (tier.height * 0.5), pedBasePos.Z) * CFrame.Angles(0, 0, math.rad(90))
        stepCyl.Material = if lvl >= 10 then Enum.Material.Marble else Enum.Material.Slate
        stepCyl.Color = tier.color
        stepCyl.Anchored = true
        stepCyl.CanCollide = true
        stepCyl.Parent = decorFolder

        local trimRing = Instance.new("Part")
        trimRing.Name = "AltarTrim_" .. idx
        trimRing.Shape = Enum.PartType.Cylinder
        trimRing.Size = Vector3.new(0.18, (tier.radius * 2) + 0.35, (tier.radius * 2) + 0.35)
        trimRing.CFrame = CFrame.new(pedBasePos.X, currentY + tier.height, pedBasePos.Z) * CFrame.Angles(0, 0, math.rad(90))
        trimRing.Material = Enum.Material.Neon
        trimRing.Color = if idx == 3 then theme.primaryColor else theme.secondaryColor
        trimRing.Transparency = if lvl >= 5 then 0.25 else 0.55
        trimRing.Anchored = true
        trimRing.CanCollide = false
        trimRing.Parent = decorFolder

        currentY += tier.height
    end

    local chaliceBase = Instance.new("Part")
    chaliceBase.Name = "ChalicePedestal"
    chaliceBase.Shape = Enum.PartType.Cylinder
    chaliceBase.Size = Vector3.new(1.5, 5.2, 5.2)
    chaliceBase.CFrame = CFrame.new(pedBasePos.X, currentY + 0.75, pedBasePos.Z) * CFrame.Angles(0, 0, math.rad(90))
    chaliceBase.Material = Enum.Material.Marble
    chaliceBase.Color = theme.stoneColor
    chaliceBase.Anchored = true
    chaliceBase.CanCollide = true
    chaliceBase.Parent = decorFolder

    local chaliceBowl = Instance.new("Part")
    chaliceBowl.Name = "ChaliceBowl"
    chaliceBowl.Shape = Enum.PartType.Ball
    chaliceBowl.Size = Vector3.new(4.6, 2.2, 4.6)
    chaliceBowl.CFrame = CFrame.new(pedBasePos.X, currentY + 1.5, pedBasePos.Z)
    chaliceBowl.Material = Enum.Material.Neon
    chaliceBowl.Color = theme.secondaryColor
    chaliceBowl.Transparency = 0.2
    chaliceBowl.Anchored = true
    chaliceBowl.CanCollide = false
    chaliceBowl.Parent = decorFolder

    -- 2. Kristal Inti Berfaset (Faceted Diamond Crystal Core)
    core.Material = Enum.Material.Neon
    core.Color = theme.primaryColor
    core.Transparency = 0.15
    core.Size = intactSize
    core.CFrame = intactCF

    local corePos = intactCF.Position

    local innerSphere = Instance.new("Part")
    innerSphere.Name = "InnerEnergySphere"
    innerSphere.Shape = Enum.PartType.Ball
    innerSphere.Size = Vector3.new(intactSize.X * 0.72, intactSize.X * 0.72, intactSize.X * 0.72)
    innerSphere.CFrame = CFrame.new(corePos)
    innerSphere.Material = Enum.Material.Neon
    innerSphere.Color = Color3.fromRGB(255, 255, 255)
    innerSphere.Anchored = true
    innerSphere.CanCollide = false
    innerSphere.Parent = decorFolder

    local spireConeH = 2.6 + (lvl * 0.08)
    local spireBaseW = intactSize.X * 0.85
    buildGothicSpireTip(
        decorFolder,
        CFrame.new(corePos + Vector3.new(0, intactSize.Y * 0.42, 0)),
        spireBaseW,
        spireConeH,
        theme.secondaryColor,
        Enum.Material.Neon
    )
    buildGothicSpireTip(
        decorFolder,
        CFrame.new(corePos - Vector3.new(0, intactSize.Y * 0.42, 0)) * CFrame.Angles(math.rad(180), 0, 0),
        spireBaseW,
        spireConeH * 0.85,
        theme.secondaryColor,
        Enum.Material.Neon
    )

    local coreLight = core:FindFirstChildOfClass("PointLight")
    if coreLight then
        coreLight.Color = theme.primaryColor
        coreLight.Range = 28 + (lvl * 1.5)
        coreLight.Brightness = 2.4 + (lvl * 0.08)
    end

    -- 3. Pilar Menara Gotik Melingkar (CanCollide = false agar tidak menjebak monster)
    local pillarCount = if lvl >= 10 then 8 else 4
    local ringRadius = 11.2 + (lvl * 0.08)
    local pillarHeight = 4.2 + (lvl * 0.35)

    for i = 1, pillarCount do
        local angle = ((i - 1) / pillarCount) * math.pi * 2 + math.rad(45)
        local px = pedBasePos.X + math.cos(angle) * ringRadius
        local pz = pedBasePos.Z + math.sin(angle) * ringRadius
        local basePillarY = pedBasePos.Y + 1.3

        local column = Instance.new("Part")
        column.Name = "GothicColumn_" .. i
        column.Shape = Enum.PartType.Cylinder
        column.Size = Vector3.new(pillarHeight, 1.35 + (lvl * 0.02), 1.35 + (lvl * 0.02))
        column.CFrame = CFrame.new(px, basePillarY + (pillarHeight * 0.5), pz) * CFrame.Angles(0, 0, math.rad(90))
        column.Material = if lvl >= 10 then Enum.Material.Marble else Enum.Material.Slate
        column.Color = theme.stoneColor
        column.Anchored = true
        column.CanCollide = false
        column.Parent = decorFolder

        local collar = Instance.new("Part")
        collar.Name = "ColumnCollar_" .. i
        collar.Shape = Enum.PartType.Cylinder
        collar.Size = Vector3.new(0.45, 1.85, 1.85)
        collar.CFrame = CFrame.new(px, basePillarY + pillarHeight, pz) * CFrame.Angles(0, 0, math.rad(90))
        collar.Material = Enum.Material.Neon
        collar.Color = theme.accentColor
        collar.Anchored = true
        collar.CanCollide = false
        collar.Parent = decorFolder

        if lvl >= 2 then
            buildGothicSpireTip(
                decorFolder,
                CFrame.new(px, basePillarY + pillarHeight + 0.2, pz) * CFrame.Angles(0, angle, 0),
                1.6,
                1.8 + (lvl * 0.06),
                theme.stoneColor,
                Enum.Material.Slate
            )
        end

        if lvl >= 3 then
            local orbY = basePillarY + pillarHeight + 2.4 + (lvl * 0.06)
            local orb = Instance.new("Part")
            orb.Name = "PillarLanternOrb_" .. i
            orb.Shape = Enum.PartType.Ball
            orb.Size = Vector3.new(1.0 + (lvl * 0.03), 1.0 + (lvl * 0.03), 1.0 + (lvl * 0.03))
            orb.CFrame = CFrame.new(px, orbY, pz)
            orb.Material = Enum.Material.Neon
            orb.Color = if i % 2 == 0 then theme.primaryColor else theme.secondaryColor
            orb.Anchored = true
            orb.CanCollide = false
            orb.Parent = decorFolder

            TweenService:Create(orb, TweenInfo.new(1.8 + (i * 0.15), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                CFrame = CFrame.new(px, orbY + 0.65, pz),
            }):Play()
        end
    end

    -- 4. Cincin Orbital 3D
    local ringCount = if lvl >= 20 then 3 elseif lvl >= 10 then 2 elseif lvl >= 5 then 1 else 0
    for r = 1, ringCount do
        local ringDiameter = intactSize.X + 5.2 + (r * 2.4)
        local ring = Instance.new("Part")
        ring.Name = "OrbitalRing_" .. r
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.22, ringDiameter, ringDiameter)
        ring.Material = Enum.Material.Neon
        ring.Color = if r == 1 then theme.secondaryColor elseif r == 2 then theme.accentColor else theme.primaryColor
        ring.Transparency = 0.25
        ring.Anchored = true
        ring.CanCollide = false

        local tiltX = if r == 1 then math.rad(18) elseif r == 2 then math.rad(-26) else math.rad(38)
        local tiltY = math.rad(r * 55)
        ring.CFrame = CFrame.new(corePos) * CFrame.Angles(tiltX, tiltY, math.rad(90))
        ring.Parent = decorFolder

        TweenService:Create(ring, TweenInfo.new(4.5 + r, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
            CFrame = CFrame.new(corePos) * CFrame.Angles(tiltX, tiltY + math.pi, math.rad(90)),
        }):Play()
    end

    -- 5. Mahkota Halo Melayang (Lv. 7+)
    if lvl >= 7 then
        local crownY = corePos.Y + (intactSize.Y * 0.5) + spireConeH + 1.1
        local halo = Instance.new("Part")
        halo.Name = "CelestialHalo"
        halo.Shape = Enum.PartType.Cylinder
        halo.Size = Vector3.new(0.25, 3.6 + (lvl * 0.12), 3.6 + (lvl * 0.12))
        halo.CFrame = CFrame.new(corePos.X, crownY, corePos.Z) * CFrame.Angles(0, 0, math.rad(90))
        halo.Material = Enum.Material.Neon
        halo.Color = theme.accentColor
        halo.Anchored = true
        halo.CanCollide = false
        halo.Parent = decorFolder

        TweenService:Create(halo, TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = CFrame.new(corePos.X, crownY + 0.7, corePos.Z) * CFrame.Angles(0, 0, math.rad(90)),
        }):Play()
    end

    -- 6. Sayap Perisai Kristal Melengkung (Lv. 14+)
    if lvl >= 14 then
        local wingCount = if lvl >= 18 then 6 else 4
        local wingRadius = (intactSize.X * 0.5) + 3.8
        for w = 1, wingCount do
            local wAngle = ((w - 1) / wingCount) * math.pi * 2
            local wx = corePos.X + math.cos(wAngle) * wingRadius
            local wz = corePos.Z + math.sin(wAngle) * wingRadius
            local wingPos = Vector3.new(wx, corePos.Y, wz)

            local wing = Instance.new("WedgePart")
            wing.Name = "AegisWing_" .. w
            wing.Size = Vector3.new(0.45, 4.6, 2.2)
            wing.CFrame = CFrame.lookAt(wingPos, corePos) * CFrame.Angles(math.rad(-14), 0, 0)
            wing.Material = Enum.Material.ForceField
            wing.Color = theme.secondaryColor
            wing.Transparency = 0.15
            wing.Anchored = true
            wing.CanCollide = false
            wing.Parent = decorFolder
        end
    end

    -- 7. Pilar Cahaya Langit & Partikel Bintang
    if lvl >= 12 then
        local aura = Instance.new("ParticleEmitter")
        aura.Name = "CoreEvolutionAura"
        aura.Color = ColorSequence.new(theme.primaryColor, theme.accentColor)
        aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
        aura.LightEmission = 1
        aura.Lifetime = NumberRange.new(1.0, 1.9)
        aura.Rate = if lvl >= 20 then 36 else 16
        aura.Speed = NumberRange.new(1.5, 4.5)
        aura.Parent = core
    end

    if lvl >= 18 then
        local skyBeam = Instance.new("Part")
        skyBeam.Name = "AstralSkyBeam"
        skyBeam.Shape = Enum.PartType.Cylinder
        skyBeam.Size = Vector3.new(55, if lvl >= 20 then 2.4 else 1.3, if lvl >= 20 then 2.4 else 1.3)
        skyBeam.CFrame = CFrame.new(corePos.X, corePos.Y + 26, corePos.Z) * CFrame.Angles(0, 0, math.rad(90))
        skyBeam.Material = Enum.Material.Neon
        skyBeam.Color = theme.primaryColor
        skyBeam.Transparency = 0.72
        skyBeam.Anchored = true
        skyBeam.CanCollide = false
        skyBeam.Parent = decorFolder
    end
end

-- Animasi 1: Manor Core Hancur saat HP mencapai 0
function MonsterService.PlayCoreDestroyAnimation(plotModel: Model)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local oldDecor = plotModel:FindFirstChild("CoreDecorations")
    if oldDecor then
        for _, part in ipairs(oldDecor:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "AstralSkyBeam" then
                    part:Destroy()
                else
                    part.Material = Enum.Material.Cobblestone
                    part.Color = Color3.fromRGB(35, 32, 38)
                end
            end
        end
    end

    local coreLight = core:FindFirstChildOfClass("PointLight")
    if coreLight then
        coreLight.Color = Color3.fromRGB(255, 60, 30)
        coreLight.Brightness = 0.4
    end

    core.Material = Enum.Material.Cobblestone
    core.Color = Color3.fromRGB(35, 32, 38)

    local brokenCF = core.CFrame * CFrame.new(0, -3.2, 0.5) * CFrame.Angles(math.rad(28), math.rad(16), math.rad(-22))
    TweenService:Create(core, TweenInfo.new(0.55, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        CFrame = brokenCF,
    }):Play()

    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "DestroyedSmoke"
    smoke.Color = ColorSequence.new(Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 40, 40))
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4.5) })
    smoke.Lifetime = NumberRange.new(1.2, 2.2)
    smoke.Rate = 35
    smoke.Speed = NumberRange.new(3, 7)
    smoke.Parent = core
    Debris:AddItem(smoke, BalanceConfig.Core.DefeatRecoveryDuration)

    for _ = 1, 12 do
        local debrisPart = Instance.new("Part")
        debrisPart.Size = Vector3.new(math.random(8, 16) / 10, math.random(8, 16) / 10, math.random(8, 16) / 10)
        debrisPart.Material = Enum.Material.Cobblestone
        debrisPart.Color = Color3.fromRGB(45, 42, 50)
        debrisPart.Position = core.Position + Vector3.new(math.random(-3, 3), math.random(0, 3), math.random(-3, 3))
        debrisPart.Anchored = false
        debrisPart.CanCollide = true
        debrisPart.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(14, 26), math.random(-18, 18))
        debrisPart.Parent = plotModel
        Debris:AddItem(debrisPart, 3.5)
    end
end

-- Animasi 2: Manor Core Dibangun Ulang / Regen
function MonsterService.PlayCoreRepairAnimation(plotModel: Model, isFullRestore: boolean)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local lvl = (plotModel:GetAttribute("CoreLevel") :: number?) or 1
    local theme = getCoreTierVisuals(lvl)

    local spark = Instance.new("ParticleEmitter")
    spark.Name = "RepairSparks"
    spark.Color = ColorSequence.new(Color3.fromRGB(90, 255, 140), Color3.fromRGB(255, 230, 110))
    spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
    spark.LightEmission = 1
    spark.Lifetime = NumberRange.new(0.6, 1.1)
    spark.Rate = 45
    spark.Speed = NumberRange.new(4, 10)
    spark.Parent = core
    Debris:AddItem(spark, 1.4)

    core.Material = Enum.Material.Neon
    core.Color = if isFullRestore then theme.primaryColor else Color3.fromRGB(110, 230, 160)

    local coreLight = core:FindFirstChildOfClass("PointLight")
    if coreLight then
        coreLight.Color = if isFullRestore then theme.primaryColor else Color3.fromRGB(90, 255, 140)
        coreLight.Brightness = 2.6
    end

    if isFullRestore then
        local intactCF, intactSize = getIntactCoreCFrame(plotModel, lvl)
        TweenService:Create(core, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            CFrame = intactCF,
            Size = intactSize,
        }):Play()
        MonsterService.RebuildCoreArchitecture(plotModel, lvl)
    else
        task.delay(0.75, function()
            if core.Parent and core.Material == Enum.Material.Neon then
                TweenService:Create(core, TweenInfo.new(0.4), {
                    Color = theme.primaryColor,
                }):Play()
                if coreLight then
                    coreLight.Color = theme.primaryColor
                end
            end
        end)
    end
end

-- Animasi 3: Manor Core Upgrade Level (Evolusi Visual 3D + Gelombang Energi)
function MonsterService.PlayCoreUpgradeAnimation(plotModel: Model, newLevel: number)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local theme = getCoreTierVisuals(newLevel)
    MonsterService.RebuildCoreArchitecture(plotModel, newLevel)

    core.Color = Color3.fromRGB(255, 240, 130)

    local ring = Instance.new("Part")
    ring.Name = "UpgradeShockwave"
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = theme.secondaryColor
    ring.Anchored = true
    ring.CanCollide = false
    ring.Transparency = 0.2
    ring.Size = Vector3.new(0.4, 7, 7)
    ring.CFrame = CFrame.new(core.Position - Vector3.new(0, core.Size.Y * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = plotModel

    local ringTween = TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.4, 30, 30),
        CFrame = CFrame.new(core.Position + Vector3.new(0, core.Size.Y * 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Transparency = 1,
    })
    ringTween:Play()
    ringTween.Completed:Connect(function()
        ring:Destroy()
    end)

    task.delay(0.5, function()
        if core.Parent then
            TweenService:Create(core, TweenInfo.new(0.45), {
                Color = theme.primaryColor,
            }):Play()
        end
    end)
end

local function createMonsterModel(monsterType: string, waveNumber: number, ownerUserId: number): Model
    local def = BalanceConfig.Monsters[monsterType]
    assert(def, "[MonsterService] Unknown monster type: " .. tostring(monsterType))

    local hpMultiplier = 1 + ((math.max(1, waveNumber) - 1) * 0.14)
    local scaledMaxHp = math.floor(def.MaxHealth * hpMultiplier)

    local model = Instance.new("Model")
    model.Name = "Monster_" .. monsterType
    model:SetAttribute("MonsterType", monsterType)
    model:SetAttribute("OwnerUserId", ownerUserId)

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2.4, 2.5, 1.4)
    torso.Color = def.Color
    torso.Material = def.Material
    torso.Transparency = def.Transparency
    torso.CanCollide = false
    torso.Anchored = false
    torso.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.6, 1.6, 1.6)
    head.Shape = Enum.PartType.Ball
    head.Color = def.Color
    head.Material = def.Material
    head.Transparency = def.Transparency
    head.CanCollide = false
    head.CFrame = torso.CFrame * CFrame.new(0, 2, 0)
    head.Parent = model

    local neckWeld = Instance.new("WeldConstraint")
    neckWeld.Part0 = torso
    neckWeld.Part1 = head
    neckWeld.Parent = torso

    local leg1 = Instance.new("Part")
    leg1.Name = "LeftLeg"
    leg1.Size = Vector3.new(1, 2, 1)
    leg1.Color = def.Color
    leg1.Material = def.Material
    leg1.Transparency = def.Transparency
    leg1.CanCollide = false
    leg1.CFrame = torso.CFrame * CFrame.new(-0.7, -2, 0)
    leg1.Parent = model

    local weldL = Instance.new("WeldConstraint")
    weldL.Part0 = torso
    weldL.Part1 = leg1
    weldL.Parent = torso

    local leg2 = Instance.new("Part")
    leg2.Name = "RightLeg"
    leg2.Size = Vector3.new(1, 2, 1)
    leg2.Color = def.Color
    leg2.Material = def.Material
    leg2.Transparency = def.Transparency
    leg2.CanCollide = false
    leg2.CFrame = torso.CFrame * CFrame.new(0.7, -2, 0)
    leg2.Parent = model

    local weldR = Instance.new("WeldConstraint")
    weldR.Part0 = torso
    weldR.Part1 = leg2
    weldR.Parent = torso

    local light = Instance.new("PointLight")
    light.Color = if monsterType == "Wraith" then Color3.fromRGB(255, 30, 30) else def.Color
    light.Range = 14
    light.Brightness = 2.5
    light.Parent = head

    if def.Sounds then
        local groanSound = createSpatialSound(head, "GroanSound", def.Sounds.Groan, def.Sounds.Volume, def.Sounds.Pitch)
        createSpatialSound(head, "AttackSound", def.Sounds.Attack, def.Sounds.Volume * 1.1, def.Sounds.Pitch)
        createSpatialSound(head, "DeathSound", def.Sounds.Death, def.Sounds.Volume * 1.2, def.Sounds.Pitch)

        task.delay(0.2, function()
            if groanSound.Parent then
                groanSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(95, 105) / 100)
                groanSound:Play()
            end
        end)
    end

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = scaledMaxHp
    humanoid.Health = scaledMaxHp
    humanoid.WalkSpeed = def.WalkSpeed
    humanoid.JumpPower = 55
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    humanoid.Parent = model

    local bb = Instance.new("BillboardGui")
    bb.Name = "MonsterGui"
    bb.Size = UDim2.new(4, 0, 1.2, 0)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 70
    bb.Parent = head

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s\nHP: %d/%d", def.DisplayName, humanoid.Health, humanoid.MaxHealth)
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    humanoid.HealthChanged:Connect(function(newHealth)
        if label.Parent then
            label.Text = string.format("%s\nHP: %d/%d", def.DisplayName, math.max(0, math.floor(newHealth)), humanoid.MaxHealth)
        end
    end)

    model.PrimaryPart = torso
    return model
end

function MonsterService.FlashCoreHeal(plotModel: Model, healAmount: number)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    MonsterService.PlayCoreRepairAnimation(plotModel, false)

    local floatGui = Instance.new("BillboardGui")
    floatGui.Name = "HealFloatGui"
    floatGui.Size = UDim2.new(5, 0, 1.8, 0)
    floatGui.StudsOffset = Vector3.new(0, 8.5, 0)
    floatGui.AlwaysOnTop = true
    floatGui.MaxDistance = 80
    floatGui.Parent = core

    local floatLabel = Instance.new("TextLabel")
    floatLabel.Size = UDim2.new(1, 0, 1, 0)
    floatLabel.BackgroundTransparency = 1
    floatLabel.Text = string.format("🔧 +%d HP 💚", healAmount)
    floatLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
    floatLabel.TextStrokeTransparency = 0
    floatLabel.TextSize = 18
    floatLabel.Font = Enum.Font.GothamBlack
    floatLabel.Parent = floatGui

    local tween = TweenService:Create(floatGui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 11.5, 0),
    })
    tween:Play()
    task.delay(1.2, function()
        if floatGui.Parent then
            floatGui:Destroy()
        end
    end)
end

local function updateCoreVisuals(plotModel: Model, currentHp: number, maxHp: number, mode: string?, extraValue: number?)
    local core = plotModel:FindFirstChild("ManorCore") :: BasePart?
    if not core then return end

    local coreGui = core:FindFirstChild("CoreGui")
    if not coreGui then return end

    local label = coreGui:FindFirstChild("CoreLabel") :: TextLabel?
    if not label then return end

    local pct = math.clamp(currentHp / maxHp, 0, 1)
    local statusLine = ""
    local labelColor = Color3.fromRGB(240, 180, 255)
    local currentLvl = plotModel:GetAttribute("CoreLevel") or 1
    local theme = getCoreTierVisuals(currentLvl)

    if mode == "Destroyed" or currentHp <= 0 then
        statusLine = "\n💥 CORE HANCUR! Membangun ulang..."
        labelColor = Color3.fromRGB(255, 50, 50)
    elseif mode == "Combat" then
        statusLine = "\n⚔️ Under Attack! (Regen paused)"
        labelColor = Color3.fromRGB(255, 60, 60)
    elseif mode == "Cooldown" then
        statusLine = string.format("\n⏳ Memperbaiki dalam: %ds...", extraValue or 5)
        labelColor = Color3.fromRGB(255, 190, 60)
    elseif mode == "Healing" or mode == "HealingActive" then
        local healVal = extraValue or BalanceConfig.CoreLevels.GetRegenAmount(currentLvl)
        statusLine = string.format("\n🔧 Memperbaiki Core (+%d HP)", healVal)
        labelColor = Color3.fromRGB(90, 255, 130)
    elseif mode == "Full" or pct >= 1 then
        statusLine = string.format("\n✨ %s", theme.tierName)
        labelColor = theme.secondaryColor
    end

    label.Text = string.format("🔮 MANOR CORE [Lv. %d]\nHP: %d / %d%s", currentLvl, math.floor(currentHp), math.floor(maxHp), statusLine)
    label.TextColor3 = labelColor
end

local function syncWaveToClient(player: Player, plotModel: Model, state: PlotWaveState)
    local waveEvent = Network.GetEvent("WaveStateUpdated")
    local isCloaked = false
    if ShopService and ShopService.IsGhostCloaked then
        isCloaked = ShopService.IsGhostCloaked(plotModel)
    end

    local payload: Types.WaveState = {
        WaveNumber = state.WaveNumber,
        Status = state.Status,
        TimeRemaining = state.TimeRemaining,
        MonstersRemaining = state.MonstersRemaining,
        CoreHealth = state.CoreHealth,
        CoreMaxHealth = state.CoreMaxHealth,
        CoreLevel = (plotModel:GetAttribute("CoreLevel") :: number?) or 1,
        IsGhostCloaked = isCloaked,
    }
    waveEvent:FireClient(player, payload)
end

function MonsterService.Init(dataServiceRef: any, economyServiceRef: any, plotServiceRef: any, itemDropServiceRef: any, shopServiceRef: any)
    DataService = dataServiceRef
    EconomyService = economyServiceRef
    PlotService = plotServiceRef
    ItemDropService = itemDropServiceRef
    ShopService = shopServiceRef

    local requestStartWaveFn = Network.GetFunction("RequestStartWave")
    requestStartWaveFn.OnServerInvoke = function(player: Player)
        local plot = PlotService.GetPlayerPlot(player)
        if not plot then return false, "No plot owned." end
        local state = plotWaveStates[plot]
        if not state then return false, "Wave state not found." end
        if state.Status == "Active" then
            return false, "Wave is already in progress!"
        end
        MonsterService.StartWave(player, plot)
        return true, "Wave summoned!"
    end

    task.spawn(function()
        while true do
            task.wait(1)
            local now = os.clock()

            for _, player in ipairs(Players:GetPlayers()) do
                local plot = PlotService.GetPlayerPlot(player)
                if plot then
                    local state = plotWaveStates[plot]
                    if state then
                        if state.Status == "Waiting" then
                            state.TimeRemaining -= 1
                            if state.TimeRemaining <= 0 then
                                MonsterService.StartWave(player, plot)
                            else
                                syncWaveToClient(player, plot, state)
                            end
                        elseif state.Status == "Active" then
                            if ShopService and ShopService.CheckSkills then
                                ShopService.CheckSkills(player, plot, state)
                            end
                            syncWaveToClient(player, plot, state)
                        end

                        if state.Status ~= "Defeat" and state.CoreHealth < state.CoreMaxHealth then
                            local timeSinceDamage = now - (state.LastDamageTime or 0)
                            local outOfCombatDelay = BalanceConfig.Core.OutOfCombatCooldown or 6

                            if timeSinceDamage >= outOfCombatDelay then
                                local tickInterval = BalanceConfig.Core.RegenTickInterval or 2.5
                                if (now - (state.LastRegenTick or 0)) >= tickInterval then
                                    state.LastRegenTick = now
                                    local coreLvl = plot:GetAttribute("CoreLevel") or 1
                                    local healAmount = BalanceConfig.CoreLevels.GetRegenAmount(coreLvl)

                                    state.CoreHealth = math.min(state.CoreMaxHealth, state.CoreHealth + healAmount)
                                    updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "Healing", healAmount)
                                    syncWaveToClient(player, plot, state)
                                    MonsterService.FlashCoreHeal(plot, healAmount)
                                else
                                    updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "HealingActive")
                                end
                            else
                                local remainingSeconds = math.ceil(outOfCombatDelay - timeSinceDamage)
                                updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "Cooldown", remainingSeconds)
                            end
                        elseif state.CoreHealth >= state.CoreMaxHealth and state.Status ~= "Defeat" then
                            updateCoreVisuals(plot, state.CoreHealth, state.CoreMaxHealth, "Full")
                        end
                    end
                end
            end
        end
    end)
end

function MonsterService.InitPlotWave(player: Player, plotModel: Model)
    ensureServices()
    local data = DataService.GetData(player)
    local waveNum = if data then data.WaveNumber else 1
    local coreLvl = if data and data.CoreLevel then data.CoreLevel else 1

    local maxCoreHp = BalanceConfig.CoreLevels.GetMaxHp(coreLvl)

    local state: PlotWaveState = {
        WaveNumber = waveNum,
        Status = "Waiting",
        TimeRemaining = BalanceConfig.Waves.AutoWaveInterval,
        ActiveMonsters = {},
        MonstersRemaining = 0,
        CoreHealth = maxCoreHp,
        CoreMaxHealth = maxCoreHp,
        LastDamageTime = 0,
        LastRegenTick = 0,
    }

    plotWaveStates[plotModel] = state
    plotModel:SetAttribute("CoreLevel", coreLvl)
    MonsterService.RebuildCoreArchitecture(plotModel, coreLvl)
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    syncWaveToClient(player, plotModel, state)
end

function MonsterService.ApplyCoreLevel(plotModel: Model, level: number)
    local state = plotWaveStates[plotModel]
    if not state then return end

    plotModel:SetAttribute("CoreLevel", level)
    local newMax = BalanceConfig.CoreLevels.GetMaxHp(level)

    local ownerUserId = plotModel:GetAttribute("OwnerUserId")
    local player = if ownerUserId then Players:GetPlayerByUserId(ownerUserId) else nil

    local hpDiff = newMax - state.CoreMaxHealth
    state.CoreMaxHealth = newMax
    state.CoreHealth = math.clamp(state.CoreHealth + math.max(0, hpDiff), 0, newMax)

    MonsterService.PlayCoreUpgradeAnimation(plotModel, level)
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    if player then
        syncWaveToClient(player, plotModel, state)
    end
end

function MonsterService.StartWave(player: Player, plotModel: Model)
    local state = plotWaveStates[plotModel]
    if not state or state.Status == "Active" then return end

    state.Status = "Active"
    state.ActiveMonsters = {}

    local monstersToSpawn: { string } = {}
    local wave = state.WaveNumber

    if wave == 1 then
        for _ = 1, 5 do table.insert(monstersToSpawn, "Ghost") end
    elseif wave == 2 then
        for _ = 1, 5 do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, 2 do table.insert(monstersToSpawn, "Zombie") end
    elseif wave == 3 then
        for _ = 1, 6 do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, 3 do table.insert(monstersToSpawn, "Zombie") end
        table.insert(monstersToSpawn, "Wraith")
    else
        local ghostCount = math.min(14, 4 + math.floor(wave * 1.5))
        local zombieCount = math.min(10, 2 + math.floor(wave * 0.9))
        local wraithCount = math.min(6, math.floor(wave * 0.6))

        for _ = 1, ghostCount do table.insert(monstersToSpawn, "Ghost") end
        for _ = 1, zombieCount do table.insert(monstersToSpawn, "Zombie") end
        for _ = 1, wraithCount do table.insert(monstersToSpawn, "Wraith") end
    end

    state.MonstersRemaining = #monstersToSpawn
    syncWaveToClient(player, plotModel, state)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("⚠️ Wave %d Approaching! Hunt the Monsters!", wave), Color3.fromRGB(255, 60, 60))

    task.spawn(function()
        local plotBase = plotModel:FindFirstChild("PlotBase") :: BasePart?
        local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
        if not plotBase or not manorCore then return end

        for _, mType in ipairs(monstersToSpawn) do
            if state.Status ~= "Active" then break end

            local spawnOffset = Vector3.new(math.random(-14, 14), 3, math.random(33, 36))
            local worldSpawnPos = (plotBase.CFrame * CFrame.new(spawnOffset)).Position

            local monster = createMonsterModel(mType, wave, player.UserId)
            local corePos = manorCore.Position
            monster:PivotTo(CFrame.lookAt(worldSpawnPos, Vector3.new(corePos.X, worldSpawnPos.Y, corePos.Z)))
            monster.Parent = plotModel
            table.insert(state.ActiveMonsters, monster)
            monsterOwnerMap[monster] = player

            MonsterService.RunMonsterAI(monster, mType, player, plotModel, state)
            task.wait(1.1)
        end
    end)
end

function MonsterService.RunMonsterAI(monster: Model, monsterType: string, player: Player, plotModel: Model, state: PlotWaveState)
    local def = BalanceConfig.Monsters[monsterType]
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    local rootPart = monster.PrimaryPart
    local manorCore = plotModel:FindFirstChild("ManorCore") :: BasePart?
    local head = monster:FindFirstChild("Head") :: BasePart?

    if not humanoid or not rootPart or not manorCore then return end

    local dmgMultiplier = 1 + ((math.max(1, state.WaveNumber) - 1) * 0.08)
    local scaledDamage = math.floor(def.Damage * dmgMultiplier)

    local groanSound = head and head:FindFirstChild("GroanSound") :: Sound?
    local attackSound = head and head:FindFirstChild("AttackSound") :: Sound?
    local deathSound = head and head:FindFirstChild("DeathSound") :: Sound?

    humanoid.Died:Connect(function()
        ensureServices()
        monsterOwnerMap[monster] = nil
        local idx = table.find(state.ActiveMonsters, monster)
        if idx then table.remove(state.ActiveMonsters, idx) end

        if deathSound and def.Sounds then
            deathSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(90, 110) / 100)
            deathSound:Play()
        end

        if ItemDropService and ItemDropService.SpawnDrop and rootPart then
            ItemDropService.SpawnDrop(monsterType, rootPart.Position, player, plotModel)
        end

        if ItemDropService and ItemDropService.SpawnCoinDrop and rootPart then
            local coinAmount = BalanceConfig.CoreLevels.GetMonsterCoinDrop(monsterType, state.WaveNumber)
            local coinOffset = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
            ItemDropService.SpawnCoinDrop(coinAmount, rootPart.Position + coinOffset, player, plotModel)
        end

        EconomyService.AddSouls(player, def.SoulDrop)
        local notif = Network.GetEvent("Notification")
        notif:FireClient(player, string.format("+%d Souls 👻", def.SoulDrop), Color3.fromRGB(160, 240, 255))

        DataService.UpdateData(player, function(d: Types.PlayerData)
            d.MonstersDefeated += 1
        end)

        state.MonstersRemaining = math.max(0, state.MonstersRemaining - 1)
        syncWaveToClient(player, plotModel, state)

        if state.MonstersRemaining <= 0 and #state.ActiveMonsters == 0 then
            MonsterService.HandleWaveVictory(player, plotModel, state)
        end

        task.wait(1.2)
        monster:Destroy()
    end)

    task.spawn(function()
        while monster.Parent and humanoid.Health > 0 and state.Status == "Active" do
            task.wait(math.random(4, 7))
            if monster.Parent and humanoid.Health > 0 and groanSound and not groanSound.IsPlaying and def.Sounds then
                groanSound.PlaybackSpeed = def.Sounds.Pitch * (math.random(92, 108) / 100)
                groanSound:Play()
            end
        end
    end)

    task.spawn(function()
        local lastPos = rootPart.Position
        local stuckTicks = 0

        while monster.Parent and humanoid.Health > 0 and state.Status == "Active" do
            local coreLvl = (plotModel:GetAttribute("CoreLevel") :: number?) or 1
            local altarRadius = 15.5 + (coreLvl * 0.12)
            local effectiveAttackRange = if def.Ranged
                then def.AttackRange
                else (altarRadius + def.AttackRange)

            local flatMonsterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
            local flatCorePos = Vector3.new(manorCore.Position.X, 0, manorCore.Position.Z)
            local dist = (flatMonsterPos - flatCorePos).Magnitude

            if dist > effectiveAttackRange then
                local moved = (rootPart.Position - lastPos).Magnitude
                lastPos = rootPart.Position

                if moved < 0.65 then
                    stuckTicks += 1
                else
                    stuckTicks = 0
                end

                local groundTarget = Vector3.new(manorCore.Position.X, rootPart.Position.Y, manorCore.Position.Z)

                if stuckTicks >= 2 then
                    humanoid.Jump = true
                    local lateralOffset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
                    humanoid:MoveTo(groundTarget + lateralOffset)
                    stuckTicks = 0
                else
                    humanoid:MoveTo(groundTarget)
                end
            else
                humanoid:MoveTo(rootPart.Position)
                stuckTicks = 0

                local lookAtCore = Vector3.new(manorCore.Position.X, rootPart.Position.Y, manorCore.Position.Z)
                rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookAtCore)

                local isCloaked = false
                if ShopService and ShopService.IsGhostCloaked then
                    isCloaked = ShopService.IsGhostCloaked(plotModel)
                end

                if not isCloaked then
                    if attackSound then
                        attackSound:Play()
                    end

                    state.CoreHealth = math.max(0, state.CoreHealth - scaledDamage)
                    state.LastDamageTime = os.clock()
                    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Combat")
                    syncWaveToClient(player, plotModel, state)

                    local combatVisual = Network.GetEvent("CombatVisual")
                    combatVisual:FireAllClients(rootPart.Position, manorCore.Position, true)

                    if state.CoreHealth <= 0 then
                        MonsterService.HandleWaveDefeat(player, plotModel, state)
                        break
                    end
                end

                task.wait(def.AttackRate)
            end
            task.wait(0.35)
        end
    end)
end

function MonsterService.HandleWaveVictory(player: Player, plotModel: Model, state: PlotWaveState)
    ensureServices()
    state.Status = "Victory"

    local clearedWave = state.WaveNumber
    local waveRewardCoins = if BalanceConfig.Waves.GetWaveRewardCoins
        then BalanceConfig.Waves.GetWaveRewardCoins(clearedWave)
        else (BalanceConfig.Waves.RewardBaseCoins + (clearedWave * BalanceConfig.Waves.RewardCoinsPerWave))

    local waveRewardSouls = if BalanceConfig.Waves.GetWaveRewardSouls
        then BalanceConfig.Waves.GetWaveRewardSouls(clearedWave)
        else (BalanceConfig.Waves.RewardBaseSouls + (clearedWave * BalanceConfig.Waves.RewardSoulsPerWave))

    local actualCoins = EconomyService.AddCoins(player, waveRewardCoins, true)
    EconomyService.AddSouls(player, waveRewardSouls)

    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.WaveNumber += 1
    end)

    state.WaveNumber += 1
    state.TimeRemaining = BalanceConfig.Waves.AutoWaveInterval
    syncWaveToClient(player, plotModel, state)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(
        player,
        string.format("🏆 Wave %d Selesai! +%d Koin 🪙, +%d Souls 👻!", clearedWave, actualCoins, waveRewardSouls),
        Color3.fromRGB(100, 255, 100)
    )

    task.wait(4)
    state.Status = "Waiting"
    syncWaveToClient(player, plotModel, state)
end

function MonsterService.HandleWaveDefeat(player: Player, plotModel: Model, state: PlotWaveState)
    ensureServices()
    state.Status = "Defeat"

    for _, monster in ipairs(state.ActiveMonsters) do
        if monster and monster.Parent then
            monsterOwnerMap[monster] = nil
            monster:Destroy()
        end
    end
    state.ActiveMonsters = {}

    MonsterService.PlayCoreDestroyAnimation(plotModel)
    updateCoreVisuals(plotModel, 0, state.CoreMaxHealth, "Destroyed")

    local prevWave = state.WaveNumber
    state.WaveNumber = 1
    DataService.UpdateData(player, function(d: Types.PlayerData)
        d.WaveNumber = 1
    end)

    local notif = Network.GetEvent("Notification")
    notif:FireClient(player, string.format("💥 Manor Core Hancur! Wave %d Gagal. Membangun ulang ke Wave 1...", prevWave), Color3.fromRGB(255, 50, 50))

    syncWaveToClient(player, plotModel, state)

    local recoveryDuration = BalanceConfig.Core.DefeatRecoveryDuration or 5
    local steps = 5
    for step = 1, steps do
        task.wait(recoveryDuration / steps)
        state.CoreHealth = math.floor((state.CoreMaxHealth / steps) * step)
        MonsterService.PlayCoreRepairAnimation(plotModel, step == steps)
        updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, if step == steps then "Full" else "Healing")
        syncWaveToClient(player, plotModel, state)
    end

    state.CoreHealth = state.CoreMaxHealth
    state.Status = "Waiting"
    state.TimeRemaining = BalanceConfig.Waves.AutoWaveInterval
    updateCoreVisuals(plotModel, state.CoreHealth, state.CoreMaxHealth, "Full")
    syncWaveToClient(player, plotModel, state)
end

function MonsterService.ClearPlayerWave(player: Player)
    local plot = PlotService.GetPlayerPlot(player)
    if plot then
        local state = plotWaveStates[plot]
        if state then
            for _, monster in ipairs(state.ActiveMonsters) do
                if monster and monster.Parent then
                    monsterOwnerMap[monster] = nil
                    monster:Destroy()
                end
            end
        end
        plotWaveStates[plot] = nil
    end
end

return MonsterService