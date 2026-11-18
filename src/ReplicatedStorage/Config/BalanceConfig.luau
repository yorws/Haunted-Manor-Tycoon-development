--!strict
--[[
    BalanceConfig.luau
    Centralized tuning values for Wave Survival Monster Hunting, Core Levels, and Loot drops.
]]

local BalanceConfig = {}

BalanceConfig.General = {
    StartingCoins = 100,
    StartingSouls = 0,
    StarterCoins = 100,
    StarterSouls = 0,
    MaxPlots = 6,
    PlotRadius = 145,
    PlotSize = Vector3.new(86, 2, 86),
    AutoSaveInterval = 60,
    AutosaveInterval = 60,
    MaxSaveRetries = 3,
    DataStoreKey = "HauntedManorSurvival_v1",
}

BalanceConfig.Core = {
    BaseMaxHealth = 500,
    OutOfCombatCooldown = 6,
    RegenTickInterval = 2.5,
    DefeatRecoveryDuration = 5,
}

BalanceConfig.CoreLevels = {
    MaxLevel = 20,
    GetMaxHp = function(level: number): number
        return 500 + ((level - 1) * 200)
    end,
    GetRegenAmount = function(level: number): number
        return 25 + ((level - 1) * 15)
    end,
    GetUpgradeCost = function(currentLevel: number): number
        return math.floor(150 * (1.42 ^ (currentLevel - 1)))
    end,
    GetWeaponDamageMultiplier = function(level: number): number
        return 1 + ((level - 1) * 0.15)
    end,
    GetMonsterCoinDrop = function(monsterType: string, waveNumber: number): number
        local base = if monsterType == "Wraith" then 35 elseif monsterType == "Zombie" then 18 else 10
        return math.floor(base + (waveNumber * 2.5))
    end,
    Skills = {
        Level10 = {
            Range = 45,
            TargetCount = 10,
            Damage = 175,
            Cooldown = 35,
        },
        Level20 = {
            Duration = 5,
            Cooldown = 50,
        },
    },
}

BalanceConfig.Waves = {
    AutoWaveInterval = 45,
    RewardBaseCoins = 90,
    RewardCoinsPerWave = 60,
    RewardBaseSouls = 8,
    RewardSoulsPerWave = 4,
    GetWaveRewardCoins = function(waveNumber: number): number
        local w = math.max(1, waveNumber)
        return math.floor(90 + (60 * (w ^ 1.35)))
    end,
    GetWaveRewardSouls = function(waveNumber: number): number
        local w = math.max(1, waveNumber)
        return math.floor(8 + (4 * w))
    end,
}

BalanceConfig.Weapon = {
    Name = "Holy Lantern",
    BaseDamage = 35,
    Range = 36,
    Cooldown = 0.55,
    LightColor = Color3.fromRGB(255, 230, 140),
    SoundId = "rbxassetid://130113322",
}

BalanceConfig.Monsters = {
    Ghost = {
        DisplayName = "👻 Restless Ghost",
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
        DisplayName = "🧟 Grave Zombie",
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
        DisplayName = "👿 Shadow Wraith",
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

BalanceConfig.Upgrades = {}

BalanceConfig.MonsterDrops = {
    Ghost = {
        ItemId = "Ectoplasm",
        DisplayName = "💧 Ectoplasm",
        SellPrice = 20,
        Color = Color3.fromRGB(110, 235, 255),
    },
    Zombie = {
        ItemId = "RottingBone",
        DisplayName = "🦴 Cursed Bone",
        SellPrice = 45,
        Color = Color3.fromRGB(220, 210, 185),
    },
    Wraith = {
        ItemId = "WraithEssence",
        DisplayName = "🔮 Wraith Essence",
        SellPrice = 110,
        Color = Color3.fromRGB(190, 80, 255),
    },
}

BalanceConfig.Items = {
    Ectoplasm = {
        DisplayName = "💧 Ectoplasm",
        SellCoins = 20,
        DropChance = 0.65,
        Color = Color3.fromRGB(110, 235, 255),
    },
    RottingBone = {
        DisplayName = "🦴 Cursed Bone",
        SellCoins = 45,
        DropChance = 0.55,
        Color = Color3.fromRGB(220, 210, 185),
    },
    WraithEssence = {
        DisplayName = "🔮 Wraith Essence",
        SellCoins = 110,
        DropChance = 0.50,
        Color = Color3.fromRGB(190, 80, 255),
    },
}

return BalanceConfig