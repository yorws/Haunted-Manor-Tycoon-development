--!strict
--[[
    Types.luau
    Central Luau type definitions for Haunted Manor Tycoon.
]]

export type MonsterDropItem = {
    ItemId: string,
    DisplayName: string,
    SellPrice: number,
    Color: Color3,
}

export type PlayerData = {
    Coins: number,
    Souls: number,
    UnlockedUpgrades: { [string]: boolean },
    WaveNumber: number,
    MonstersDefeated: number,
    HasDoubleCoins: boolean,
    HasVip: boolean,
    CoreLevel: number,
    Inventory: { [string]: number },
    LastSaveTimestamp: number,
}

export type UpgradeDef = {
    Id: string,
    DisplayName: string,
    Cost: number,
    Currency: string,
    Requires: string?,
    IncomePerVisitor: number?,
    VisitorIntervalBonus: number?,
    DefenseType: string?,
    TurretRange: number?,
    TurretDamage: number?,
    TurretCooldown: number?,
    CoreHpBonus: number?,
    WeaponDamageMultiplier: number?,
    Description: string,
    Color: Color3,
    PadPosition: Vector3,
}

export type MonsterDef = {
    DisplayName: string,
    WalkSpeed: number,
    MaxHealth: number,
    Damage: number,
    SoulDrop: number,
    AttackRange: number,
    AttackRate: number,
    Ranged: boolean,
    Color: Color3,
    Transparency: number,
    Material: Enum.Material,
    Sounds: {
        Groan: string,
        Attack: string,
        Death: string,
        Pitch: number,
        Volume: number,
    }?,
}

export type WaveStatus = "Waiting" | "Active" | "Victory" | "Defeat"

export type WaveState = {
    WaveNumber: number,
    Status: WaveStatus,
    TimeRemaining: number,
    MonstersRemaining: number,
    CoreHealth: number,
    CoreMaxHealth: number,
    CoreLevel: number,
    IsGhostCloaked: boolean?,
}

return {}
