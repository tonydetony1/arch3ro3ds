-- src/data/item_passives.lua
-- Effects of the item passives described in src/data/items.lua. A passive works once the
-- item's current rarity reaches the passive's tier (uncommon 2, rare 3, epic 4, legendary 5).
--
-- Passives honoured elsewhere, so not listed here:
--   * every uncommon "Base Attack / HP +25%": the rarity stat multiplier (x1.25 from uncommon);
--   * rare "+N% Dodge / Critical" of armour and rings: read by Items.getStats;
--   * what a weapon always does: Coup de Grace (scythe execution), Double Impact and Total
--     Pierce (boomerang return and pierce), Instant Bolt and Piercing Ray (Brightspear beam).
--
-- Hero effects only set fields on the player; the combat code reads them (Player:shoot,
-- Player:takeDamage, GameState:masteryDamage...). Pet effects set fields on the Pet.

local ItemPassives = {}

ItemPassives.TIERS = { uncommon = 2, rare = 3, epic = 4, legendary = 5 }

-- Monsters that fly (Aerial Hunt) as opposed to ground monsters (Ferocity)
ItemPassives.FLYING = {
    bat = true, raven = true, wisp = true, gargoyle = true, frost_wraith = true,
    witch = true, storm_drake = true, void_watcher = true,
}

ItemPassives.KILL_HEAL = 0.015          -- Soul Reaper: share of max HP restored per kill
ItemPassives.GOLD_DAMAGE_CAP = 0.30     -- Eternal Monarch: +1% per 100 gold, at most +30%
ItemPassives.ENTRY_RUSH_TIME = 5.0      -- Entry Rush: seconds at the start of a room
ItemPassives.CRIT_HASTE_TIME = 2.0      -- Pack Leader: attack speed buff after a crit
ItemPassives.CRIT_SPEED_TIME = 3.0      -- Lethal Gale: move speed buff after a crit
ItemPassives.CRIT_SPEED_STACKS = 5      -- Lethal Gale: at most 5 x 5%
ItemPassives.LOW_HP = 0.20              -- Phantom Drift: below 20% HP

local function add(p, field, amount)
    p[field] = (p[field] or 0) + amount
end

local function mul(p, field, factor)
    p[field] = (p[field] or 1) * factor
end

-- Hero effects by item id and passive tier
local HERO = {
    starter_bow = {
        rare = function(p) add(p, "critChance", 0.10) end,                       -- Eagle Eye
        epic = function(p) add(p, "diagArrows", 1) end,                           -- Fractal Arrows
        legendary = function(p)                                                    -- Solar Judgment
            add(p, "critMultiplier", 0.5)
            p.wallPasses = math.max(p.wallPasses or 0, 1)
        end,
    },
    rapid_daggers = {
        rare = function(p) mul(p, "attackSpeedMult", 1.12) end,                   -- Celestial Frenzy
        epic = function(p) add(p, "rearArrows", 1) end,                           -- Blade Dance
        legendary = function(p) add(p, "critSpeedBoost", 0.05) end,               -- Lethal Gale
    },
    heavy_ballista = {
        rare = function(p) mul(p, "knockbackMult", 2) end,                        -- Seismic Shock
        epic = function(p) p.pierceAll = true end,                                -- Pure Piercing
        legendary = function(p) add(p, "bossDamageMult", 0.35) end,               -- Titan's Bane
    },
    saw_blade = {
        rare = function(p) add(p, "entryRush", 0.20) end,                         -- Entry Rush
        epic = function(p) p.elements.bleed = true end,                           -- Saw Tooth
        legendary = function(p) p.hasRicochet = true end,                         -- Razor Disc
    },
    death_scythe = {
        rare = function(p) mul(p, "knockbackMult", 10) end,                       -- Massive Impact
        legendary = function(p) add(p, "killHeal", ItemPassives.KILL_HEAL) end,  -- Soul Reaper
    },
    stalker_staff = {
        rare = function(p) mul(p, "trackingMult", 1.30) end,                      -- Arcane Guidance
        epic = function(p) p.wallPasses = math.max(p.wallPasses or 0, 1) end,     -- Multiple Orbs
        legendary = function(p) p.orbBlast = true end,                            -- Celestial Comet
    },
    tornado_boomerang = {
        legendary = function(p) p.typhoon = true end,                             -- Swirling Typhoon
    },
    brightspear = {
        legendary = function(p) p.prism = true end,                               -- Starlight Prism
    },
    vest_dexterity = {
        epic = function(p) p.dodgeLightning = true end,                           -- Lightning Agility
        legendary = function(p) add(p, "lowHpDodge", 0.30) end,                   -- Phantom Drift
    },
    phantom_cloak = {
        rare = function(p) add(p, "shotDamageCut", 0.12) end,                     -- Magic Resistance
        epic = function(p) p.contactFreeze = 1.5 end,                             -- Vindictive Frost
        legendary = function(p) p.hurtImmunityTime = 1.0 end,                     -- Incorporeal
    },
    golden_chestplate = {
        rare = function(p) add(p, "goldMultiplier", 0.20) end,                    -- Thirst for Gold
        epic = function(p) add(p, "coinHeal", 2) end,                             -- Golden Aura
        legendary = function(p, ctx)                                               -- Eternal Monarch
            local bonus = math.min(ItemPassives.GOLD_DAMAGE_CAP, math.floor((ctx.gold or 0) / 100) * 0.01)
            add(p, "damageMult", bonus)
        end,
    },
    wolf_ring = {
        epic = function(p) add(p, "groundDamage", 0.20) end,                      -- Ferocity
        legendary = function(p) add(p, "critAttackHaste", 0.15) end,              -- Pack Leader
    },
    bear_ring = {
        rare = function(p) add(p, "bossDamageMult", 0.14) end,                    -- Monster Slayer
        epic = function(p) add(p, "contactDamageCut", 0.10) end,                  -- Carapace
        legendary = function(p) p.primalRage = true end,                          -- Primal Rage
    },
    serpent_ring = {
        epic = function(p) p.elements.poison = true end,                          -- Paralyzing Venom
        legendary = function(p) add(p, "dodgeHeal", 5) end,                       -- Ouroboros
    },
    falcon_ring = {
        rare = function(p) add(p, "flyingDamage", 0.20) end,                      -- Aerial Hunt
        epic = function(p) mul(p, "attackSpeedMult", 1.10) end,                   -- Attack Speed
        legendary = function(p) mul(p, "projSpeedMult", 1.25) end,                -- Peregrine Falcon
    },
    bat_companion = {
        legendary = function(p) add(p, "damageMult", 10 / 30) end,                -- Dark Symbiosis
    },
    ghost_familiar = {
        legendary = function(p) add(p, "critChance", 0.10) end,                   -- Ethereal Bond
    },
    dragon_pet = {
        legendary = function(p) p.elements.fireBoost = 0.15 end,                  -- Heart of the Volcano
    },
}

-- Pet effects by item id and passive tier
local PET = {
    bat_companion = {
        rare = function(pet) pet.haste = (pet.haste or 1) * 1.15 end,             -- Echolocation
        epic = function(pet) pet.wallPasses = 99 end,                             -- Spectral Laser
    },
    ghost_familiar = {
        rare = function(pet) pet.freezeChance = 0.15 end,                         -- Haunted Orb
        epic = function(pet) pet.bounces = 2 end,                                 -- Spectral Ricochet
    },
    dragon_pet = {
        rare = function(pet) pet.burns = true end,                                -- Blaze
        epic = function(pet) pet.twin = true end,                                 -- Twin Flame
    },
}

-- Passive tiers in the order they unlock
local ORDER = { "uncommon", "rare", "epic", "legendary" }

local function applyFrom(effects, itemId, rarityTier, target, ctx)
    local byTier = effects[itemId]
    if not byTier then return end
    for _, tier in ipairs(ORDER) do
        local fn = byTier[tier]
        if fn and rarityTier >= ItemPassives.TIERS[tier] then fn(target, ctx) end
    end
end

-- Hero effects of one equipped item. ctx.gold: gold held (Eternal Monarch).
function ItemPassives.applyHero(player, itemId, rarityTier, ctx)
    player.elements = player.elements or {}
    applyFrom(HERO, itemId, rarityTier, player, ctx or {})
end

-- Effects of an equipped pet item on its Pet
function ItemPassives.applyPet(pet, itemId, rarityTier)
    applyFrom(PET, itemId, rarityTier, pet, {})
end

-- Damage multiplier against `target` from Ferocity, Aerial Hunt and Primal Rage
function ItemPassives.damageFactor(player, target)
    local mult = 1
    if ItemPassives.FLYING[target.type] then
        mult = mult + (player.flyingDamage or 0)
    else
        mult = mult + (player.groundDamage or 0)
    end
    if player.primalRage then
        local missing = 1 - player.hp / math.max(1, player.maxHp)
        mult = mult + math.floor(missing * 100 / 5) * 0.01
    end
    return mult
end

ItemPassives.HERO = HERO
ItemPassives.PET = PET

-- Passives with no entry above because they already work: the weapon always does it, or
-- Items.getStats reads the "+N%" of the description (see the header)
ItemPassives.HONOURED_ELSEWHERE = {
    ["Coup de Grace"] = true, ["Double Impact"] = true, ["Total Pierce"] = true,
    ["Instant Bolt"] = true, ["Piercing Ray"] = true,
    ["Keen Senses"] = true, ["Slippery Step"] = true, ["Undulating Evasion"] = true,
}

return ItemPassives
