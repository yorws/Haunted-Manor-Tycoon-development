--!strict
--[[
    BalanceConfig.luau
    Central balance numbers, costs, stats, audio IDs, monster drops,
    and Manor Core 20-level progression data for Haunted Manor Tycoon.
]]

local BalanceConfig = {}

BalanceConfig.General = {
    MaxPlots = 6,
    StarterCoins = 50,
    StarterSouls = 0,
    AutosaveInterval = 60,
    MaxSaveRetries = 3,
    DataStoreKey = "HauntedManor_UserData_v1",
}

BalanceConfig.Core = {
    BaseMaxHealth = 500,
    RegenAmount = 25,             -- Amount of HP healed per tick
    RegenTickInterval = 2.5,      -- Seconds between heal pulses
    OutOfCombatCooldown = 6,      -- Seconds without damage before healing starts
    DefeatRecoveryDuration = 20,
}

BalanceConfig.CoreLevels = {
    MaxLevel = 20,
    GetUpgradeCost = function(currentLevel: number): number
        return currentLevel * 140 -- Lvl 1->2: 140, Lvl 9->10: 1260, Lvl 19->20: 2660
    end,
    GetMaxHp = function(level: number): number
        return 500 + ((level - 1) * 150) -- Lvl 1: 500, Lvl 10: 1850, Lvl 20: 3350
    end,
    Skills = {
        Level10 = {
            Name = "Spectral Retaliation",
            Description = "When Core HP drops below 50%, immediately zaps up to 10 nearest monsters!",
            TargetCount = 10,
            Damage = 175,
            Range = 85,
            Cooldown = 35,
        },
        Level20 = {
            Name = "Ghost Cloak",
            Description = "When Core HP drops below 35%, the Manor Core phases out and becomes completely invulnerable for 5 seconds!",
            Duration = 5,
            Cooldown = 50,
        },
    },
}

BalanceConfig.MonsterDrops = {
    Ghost = {
        ItemId = "Ectoplasm",
        DisplayName = "Ectoplasm",
        SellPrice = 18,
        Color = Color3.fromRGB(120, 240, 255),
    },
    Zombie = {
        ItemId = "ZombieBone",
        DisplayName = "Zombie Bone",
        SellPrice = 35,
        Color = Color3.fromRGB(225, 220, 200),
    },
    Wraith = {
        ItemId = "DarkEssence",
        DisplayName = "Dark Essence",
        SellPrice = 75,
        Color = Color3.fromRGB(170, 60, 245),
    },
}

BalanceConfig.Upgrades = {
    {
        Id = "Foyer",
        DisplayName = "Manor Foyer",
        Cost = 25,
        Currency = "Coins",
        Requires = nil,
        IncomePerVisitor = 8,
        VisitorIntervalBonus = 0.5,
        Description = "The grand, creaky manor entryway with flickering candle chandeliers.",
        Color = Color3.fromRGB(140, 95, 55),
        PadPosition = Vector3.new(0, 0.5, 18),
    },
    {
        Id = "GraveyardGarden",
        DisplayName = "Graveyard Garden",
        Cost = 85,
        Currency = "Coins",
        Requires = "Foyer",
        IncomePerVisitor = 16,
        VisitorIntervalBonus = 0.8,
        Description = "Ancient crooked gravestones and swirling cemetery fog.",
        Color = Color3.fromRGB(65, 85, 65),
        PadPosition = Vector3.new(-28, 0.5, 10),
    },
    {
        Id = "CryptChamber",
        DisplayName = "Crypt Chamber",
        Cost = 220,
        Currency = "Coins",
        Requires = "GraveyardGarden",
        IncomePerVisitor = 32,
        VisitorIntervalBonus = 1.2,
        Description = "Chilled stone tomb housing a cursed royal sarcophagus.",
        Color = Color3.fromRGB(80, 80, 95),
        PadPosition = Vector3.new(28, 0.5, 10),
    },
    {
        Id = "HauntedLibrary",
        DisplayName = "Haunted Library",
        Cost = 550,
        Currency = "Coins",
        Requires = "CryptChamber",
        IncomePerVisitor = 65,
        VisitorIntervalBonus = 1.6,
        Description = "Cobwebbed shelves of occult tomes with levitating books.",
        Color = Color3.fromRGB(110, 55, 75),
        PadPosition = Vector3.new(-25, 0.5, -20),
    },
    {
        Id = "SeanceParlor",
        DisplayName = "Séance Parlor",
        Cost = 1200,
        Currency = "Coins",
        Requires = "HauntedLibrary",
        IncomePerVisitor = 130,
        VisitorIntervalBonus = 2.2,
        Description = "Summoning circle with an unearthly floating crystal orb.",
        Color = Color3.fromRGB(130, 45, 150),
        PadPosition = Vector3.new(25, 0.5, -20),
    },
    {
        Id = "GargoyleSentry",
        DisplayName = "Gargoyle Sentry",
        Cost = 20,
        Currency = "Souls",
        Requires = "GraveyardGarden",
        DefenseType = "Turret",
        TurretRange = 45,
        TurretDamage = 25,
        TurretCooldown = 1.5,
        Description = "Stone guardian that shoots crackling spectral bolts at encroaching monsters.",
        Color = Color3.fromRGB(200, 110, 25),
        PadPosition = Vector3.new(-38, 0.5, 28),
    },
    {
        Id = "HolyAltar",
        DisplayName = "Holy Relic Altar",
        Cost = 45,
        Currency = "Souls",
        Requires = "SeanceParlor",
        DefenseType = "Sanctuary",
        CoreHpBonus = 500,
        WeaponDamageMultiplier = 1.5,
        Description = "Infuses the Manor Core with +500 Max HP and amplifies Holy Lantern damage by 50%.",
        Color = Color3.fromRGB(250, 220, 85),
        PadPosition = Vector3.new(38, 0.5, 28),
    },
}

BalanceConfig.Monsters = {
    Ghost = {
        DisplayName = "Restless Ghost",
        WalkSpeed = 21,
        MaxHealth = 50,
        Damage = 10,
        SoulDrop = 1,
        AttackRange = 5,
        AttackRate = 1.0,
        Ranged = false,
        Color = Color3.fromRGB(150, 240, 255),
        Transparency = 0.45,
        Material = Enum.Material.ForceField,
        Sounds = {
            Groan = "rbxassetid://125610525645835",
            Attack = "rbxassetid://9113951479",
            Death = "rbxassetid://139090255801447",
            Pitch = 1.15,
            Volume = 1.5,
        },
    },
    Zombie = {
        DisplayName = "Grave Zombie",
        WalkSpeed = 9,
        MaxHealth = 175,
        Damage = 22,
        SoulDrop = 2,
        AttackRange = 5,
        AttackRate = 1.4,
        Ranged = false,
        Color = Color3.fromRGB(65, 95, 60),
        Transparency = 0,
        Material = Enum.Material.CorrodedMetal,
        Sounds = {
            Groan = "rbxassetid://127809799844346",
            Attack = "rbxassetid://109819443674858",
            Death = "rbxassetid://106129958887908",
            Pitch = 0.9,
            Volume = 1.6,
        },
    },
    Wraith = {
        DisplayName = "Shadow Wraith",
        WalkSpeed = 13,
        MaxHealth = 95,
        Damage = 16,
        SoulDrop = 3,
        AttackRange = 28,
        AttackRate = 2.0,
        Ranged = true,
        Color = Color3.fromRGB(45, 15, 60),
        Transparency = 0.2,
        Material = Enum.Material.Neon,
        Sounds = {
            Groan = "rbxassetid://9113985717",
            Attack = "rbxassetid://131653988627020",
            Death = "rbxassetid://80984191739263",
            Pitch = 1.0,
            Volume = 1.6,
        },
    },
}

BalanceConfig.Waves = {
    AutoWaveInterval = 120,
    RewardBaseCoins = 80,
    RewardCoinsPerWave = 35,
    RewardBaseSouls = 5,
    RewardSoulsPerWave = 2,
    MaxWaveCapacity = 25,
}

BalanceConfig.Weapon = {
    Name = "Holy Lantern",
    BaseDamage = 35,
    Range = 36,
    Cooldown = 0.45,
    BeamWidth = 1.2,
    LightColor = Color3.fromRGB(255, 240, 160),
    FireSound = "rbxassetid://115842676995967",
}

BalanceConfig.Visitors = {
    BaseSpawnInterval = 6,
    MinSpawnInterval = 2.5,
    MaxVisitorsPerPlot = 6,
    MaxPlotCapacityWithRooms = 12,
    VisitDuration = 8,
}

return BalanceConfig
