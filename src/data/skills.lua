-- src/data/skills.lua
-- Architecture extensible pour 200+ compétences in-game avec système de Hooks
-- Hooks : onApply, onShoot, onHit, onMonsterDeath, onUpdate

local Skills = {
    registry = {},
    list = {},
}

function Skills.register(def)
    Skills.registry[def.id] = def
    table.insert(Skills.list, def.id)
    return def
end

-- ============================================================================
-- 1. TIRS & MULTISHOT
-- ============================================================================
Skills.register({
    id = "front_arrow",
    name = "Front Arrow +1",
    desc = "Fires +1 additional arrow forward",
    rarity = "epic",
    category = "shots",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.frontArrows = (p.frontArrows or 1) + 1
        end,
    }
})

Skills.register({
    id = "diag_arrows",
    name = "Diagonal Arrows",
    desc = "Fires 2 additional arrows at 45 degrees",
    rarity = "rare",
    category = "shots",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.diagArrows = (p.diagArrows or 0) + 1
        end,
    }
})

Skills.register({
    id = "rear_arrow",
    name = "Rear Arrow",
    desc = "Fires 1 arrow directly backward",
    rarity = "common",
    category = "shots",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.rearArrows = (p.rearArrows or 0) + 1
        end,
    }
})

Skills.register({
    id = "side_arrows",
    name = "Side Arrows",
    desc = "Fires 2 arrows to the sides at 90 degrees",
    rarity = "common",
    category = "shots",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.sideArrows = (p.sideArrows or 0) + 1
        end,
    }
})

-- ============================================================================
-- 2. PROPRIÉTÉS DU PROJECTILE
-- ============================================================================
Skills.register({
    id = "ricochet",
    name = "Ricochet",
    desc = "Arrows bounce between nearby monsters",
    rarity = "epic",
    category = "projectile",
    icon = "ricochet",
    hooks = {
        onApply = function(p)
            p.hasRicochet = true
        end,
    }
})

Skills.register({
    id = "piercing",
    name = "Piercing Shot",
    desc = "Arrows penetrate through all enemies",
    rarity = "rare",
    category = "projectile",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.hasPiercing = true
        end,
    }
})

Skills.register({
    id = "bouncy_wall",
    name = "Bouncy Wall",
    desc = "Arrows bounce off arena boundaries",
    rarity = "epic",
    category = "projectile",
    icon = "ricochet",
    hooks = {
        onApply = function(p)
            p.hasBouncyWalls = true
        end,
    }
})

Skills.register({
    id = "giant_arrow",
    name = "Giant Arrow",
    desc = "Arrow radius +60% and Damage +35%",
    rarity = "rare",
    category = "projectile",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.arrowRadiusBonus = (p.arrowRadiusBonus or 0) + 2.0
            p.damageMult = p.damageMult * 1.35
        end,
    }
})

-- ============================================================================
-- 3. ÉLÉMENTS (FEU, GLACE, FOUDRE, POISON)
-- ============================================================================
Skills.register({
    id = "fire_element",
    name = "Blaze",
    desc = "Ignites enemies with continuous fire damage for 3s",
    rarity = "rare",
    category = "elements",
    icon = "damage",
    hooks = {
        onApply = function(p) p.elements = p.elements or {}; p.elements.fire = true end,
        onHit = function(target, proj, player, dmg, fctPool)
            if fctPool then
                local f = fctPool:obtain()
                if f then f:spawn(target.x, target.y - 14, math.floor(dmg * 0.4), false) end
            end
        end,
    }
})

Skills.register({
    id = "ice_element",
    name = "Frostbite",
    desc = "Slows struck monsters down by 40%",
    rarity = "rare",
    category = "elements",
    icon = "crit",
    hooks = {
        onApply = function(p) p.elements = p.elements or {}; p.elements.ice = true end,
        onHit = function(target, proj, player, dmg, fctPool)
            target.speedMult = 0.6
        end,
    }
})

Skills.register({
    id = "lightning_element",
    name = "Bolt",
    desc = "Triggers area chain lightning upon hit",
    rarity = "epic",
    category = "elements",
    icon = "speed",
    hooks = {
        onApply = function(p) p.elements = p.elements or {}; p.elements.lightning = true end,
    }
})

Skills.register({
    id = "poison_element",
    name = "Poison Touch",
    desc = "Poisons targets with continuous acid damage",
    rarity = "common",
    category = "elements",
    icon = "damage",
    hooks = {
        onApply = function(p) p.elements = p.elements or {}; p.elements.poison = true end,
    }
})

-- ============================================================================
-- 4. ORBITAUX & ESPRITS TOURNANTS
-- ============================================================================
Skills.register({
    id = "rotating_sword_fire",
    name = "Blazing Sword",
    desc = "A flaming sword orbits around you",
    rarity = "epic",
    category = "orbitals",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.orbitals = p.orbitals or {}
            table.insert(p.orbitals, { type = "fire", angle = 0, dist = 26, dmg = 20, color = {1.0, 0.4, 0.1} })
        end,
    }
})

Skills.register({
    id = "rotating_sword_ice",
    name = "Frost Sword",
    desc = "A frost sword orbits and damages on contact",
    rarity = "rare",
    category = "orbitals",
    icon = "crit",
    hooks = {
        onApply = function(p)
            p.orbitals = p.orbitals or {}
            table.insert(p.orbitals, { type = "ice", angle = math.pi, dist = 26, dmg = 15, color = {0.3, 0.8, 1.0} })
        end,
    }
})

Skills.register({
    id = "rotating_sword_poison",
    name = "Toxic Sword",
    desc = "A venomous sword orbits around you",
    rarity = "rare",
    category = "orbitals",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.orbitals = p.orbitals or {}
            table.insert(p.orbitals, { type = "poison", angle = math.pi * 0.5, dist = 26, dmg = 12, color = {0.2, 0.9, 0.3} })
        end,
    }
})

Skills.register({
    id = "shield_orb",
    name = "Shield Guard",
    desc = "A floating shield blocks incoming enemy missiles",
    rarity = "rare",
    category = "orbitals",
    icon = "crit",
    hooks = {
        onApply = function(p)
            p.orbitals = p.orbitals or {}
            table.insert(p.orbitals, { type = "shield", angle = -math.pi * 0.5, dist = 28, dmg = 5, isShield = true, color = {0.9, 0.75, 0.2} })
        end,
    }
})

Skills.register({
    id = "shield_guard",
    name = "Divine Aegis",
    desc = "Two golden shields orbit, blocking all enemy projectiles",
    rarity = "epic",
    category = "orbitals",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.orbitals = p.orbitals or {}
            table.insert(p.orbitals, { type = "shield", angle = 0, dist = 32, dmg = 10, isShield = true, color = {1.0, 0.85, 0.2} })
            table.insert(p.orbitals, { type = "shield", angle = math.pi, dist = 32, dmg = 10, isShield = true, color = {1.0, 0.85, 0.2} })
        end,
    }
})

-- ============================================================================
-- 5. STATS & BOOSTS PASSIFS
-- ============================================================================
Skills.register({
    id = "attack_boost",
    name = "Attack Boost",
    desc = "+30% Attack damage",
    rarity = "common",
    category = "stats",
    icon = "damage",
    hooks = {
        onApply = function(p) p.damageMult = p.damageMult * 1.30 end,
    }
})

Skills.register({
    id = "attack_speed_boost",
    name = "Attack Speed Boost",
    desc = "+35% Attack speed",
    rarity = "common",
    category = "stats",
    icon = "speed",
    hooks = {
        onApply = function(p) p.attackSpeedMult = p.attackSpeedMult * 1.35 end,
    }
})

Skills.register({
    id = "max_hp_boost",
    name = "Max HP Boost",
    desc = "+25% Max HP and restores 40 HP",
    rarity = "common",
    category = "stats",
    icon = "heal",
    hooks = {
        onApply = function(p)
            p.maxHp = math.floor(p.maxHp * 1.25)
            p.hp = math.min(p.maxHp, p.hp + 40)
        end,
    }
})

Skills.register({
    id = "dodge_boost",
    name = "Grace of Hermes",
    desc = "+15% Chance to Dodge incoming attacks",
    rarity = "rare",
    category = "stats",
    icon = "boots",
    hooks = {
        onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.15 end,
    }
})

Skills.register({
    id = "crit_master",
    name = "Crit Master",
    desc = "+25% Crit chance and doubled Crit damage",
    rarity = "epic",
    category = "stats",
    icon = "crit",
    hooks = {
        onApply = function(p)
            p.critChance = p.critChance + 0.25
            p.critMultiplier = (p.critMultiplier or 2.0) + 0.5
        end,
    }
})

Skills.register({
    id = "swift_stride",
    name = "Hermes Boots",
    desc = "+25% Movement speed",
    rarity = "common",
    category = "stats",
    icon = "boots",
    hooks = {
        onApply = function(p) p.speed = p.speed * 1.25 end,
    }
})

Skills.register({
    id = "first_aid",
    name = "Emergency Potion",
    desc = "Instantly restores 45% of max HP",
    rarity = "common",
    category = "stats",
    icon = "heal",
    hooks = {
        onApply = function(p)
            p.hp = math.min(p.maxHp, p.hp + math.floor(p.maxHp * 0.45))
        end,
    }
})

Skills.register({
    id = "greed_gold",
    name = "Greed",
    desc = "+50% Gold coins collected",
    rarity = "rare",
    category = "stats",
    icon = "multishot",
    hooks = {
        onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1.0) * 1.5 end,
    }
})

Skills.register({
    id = "giant_form",
    name = "Giant",
    desc = "Character size +15%, Damage +40%, Max HP +30%",
    rarity = "epic",
    category = "stats",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.damageMult = p.damageMult * 1.40
            p.maxHp = math.floor(p.maxHp * 1.30)
            p.hp = p.maxHp
            p.radius = p.radius * 1.15
        end,
    }
})

-- ============================================================================
-- 6. EFFETS À LA MORT DES ENNEMIS & PASSIVES DE COMBAT
-- ============================================================================
Skills.register({
    id = "death_explosion",
    name = "Death Bomb",
    desc = "Enemies explode upon defeat dealing AoE damage",
    rarity = "epic",
    category = "death",
    icon = "damage",
    hooks = {
        onMonsterDeath = function(monster, player, pools)
            if pools and pools.dummyPool then
                local dCount = pools.dummyPool.activeCount
                for i = 1, dCount do
                    local idx = pools.dummyPool.activeList[i]
                    local target = pools.dummyPool.items[idx]
                    if target and target.alive and target.id ~= monster.id then
                        local dx = target.x - monster.x
                        local dy = target.y - monster.y
                        if (dx * dx + dy * dy) < 2500 then -- Rayon 50px
                            target:takeDamage(25)
                            if pools.fctPool then
                                local f = pools.fctPool:obtain()
                                if f then f:spawn(target.x, target.y, 25, false) end
                            end
                        end
                    end
                end
            end
        end,
    }
})

Skills.register({
    id = "death_starburst",
    name = "Death Starburst",
    desc = "Fires 8 radial needles upon monster death",
    rarity = "rare",
    category = "death",
    icon = "multishot",
    hooks = {
        onMonsterDeath = function(monster, player, pools)
            if pools and pools.projectilePool then
                for a = 0, 7 do
                    local angle = a * (math.pi / 4)
                    local p = pools.projectilePool:obtain()
                    if p then
                        p:spawn(monster.x, monster.y, math.cos(angle), math.sin(angle), {
                            projectile_speed = 220,
                            damage = 18,
                            range = 200,
                            radius = 2.5,
                            color = {0.9, 0.4, 1.0}
                        }, false, 0)
                    end
                end
            end
        end,
    }
})

Skills.register({
    id = "bloodthirst",
    name = "Bloodthirst",
    desc = "Restores 25 HP upon defeating an enemy",
    rarity = "rare",
    category = "death",
    icon = "heal",
    hooks = {
        onMonsterDeath = function(monster, player)
            player.hp = math.min(player.maxHp, player.hp + 25)
        end,
    }
})

Skills.register({
    id = "headshot",
    name = "Headshot",
    desc = "3% chance to instantly kill non-boss monsters",
    rarity = "epic",
    category = "death",
    icon = "crit",
    hooks = {
        onHit = function(target, proj, player, dmg, fctPool)
            if not target.isBoss and math.random() < 0.03 then
                target:takeDamage(9999)
                if fctPool then
                    local f = fctPool:obtain()
                    if f then f:spawn(target.x, target.y - 12, "FATAL!", true) end
                end
            end
        end,
    }
})

Skills.register({
    id = "fury",
    name = "Fury",
    desc = "Lower HP grants higher Attack (up to +75%)",
    rarity = "epic",
    category = "stats",
    icon = "damage",
    hooks = {
        onUpdate = function(player)
            local missingHpRatio = 1.0 - (player.hp / player.maxHp)
            player.furyBonus = missingHpRatio * 0.75
        end,
    }
})

-- ============================================================================
-- 7. POUVOIRS INTERDITS DU DIABLE (DEVIL PACTS)
-- ============================================================================
Skills.register({
    id = "devil_multishot",
    name = "Dark Multishot",
    desc = "Fires an additional front arrow",
    rarity = "forbidden",
    category = "devil",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.frontArrows = (p.frontArrows or 1) + 1
        end,
    }
})

Skills.register({
    id = "devil_rage",
    name = "Demonic Rage",
    desc = "+35% Permanent raw damage",
    rarity = "forbidden",
    category = "devil",
    icon = "damage",
    hooks = {
        onApply = function(p)
            p.damageMult = (p.damageMult or 1.0) + 0.35
        end,
    }
})

Skills.register({
    id = "devil_haste",
    name = "Infernal Haste",
    desc = "+30% Movement and attack speed",
    rarity = "forbidden",
    category = "devil",
    icon = "speed",
    hooks = {
        onApply = function(p)
            p.speed = (p.speed or 130) * 1.20
        end,
    }
})

Skills.register({
    id = "devil_ghost",
    name = "Ghost Walk",
    desc = "Enables walking through walls and obstacles",
    rarity = "forbidden",
    category = "devil",
    icon = "shield",
    hooks = {
        onApply = function(p)
            p.canGhostWalk = true
        end,
    }
})

-- ============================================================================
-- SÉLECTION ALÉATOIRE POUR LE DRAFT (3 CARTES SANS DOUBLONS)
-- ============================================================================
-- ============================================================================
-- 8. POUVOIRS CÉLESTES (MÉTÉORES, ÉPÉES VOLANTES, WINGMAN, ÉTOILE)
-- ============================================================================
local METEOR_ELEMENTS = {
    meteor_fire    = { key = "fire",      color = { 1.00, 0.45, 0.12, 1.0 }, name = "Blazing Meteor",  desc = "A flaming meteor crashes down every 4s" },
    meteor_ice     = { key = "ice",       color = { 0.45, 0.85, 1.00, 1.0 }, name = "Frost Meteor",    desc = "An ice meteor crashes down and freezes the area" },
    meteor_thunder = { key = "lightning", color = { 1.00, 0.90, 0.30, 1.0 }, name = "Thunder Meteor",  desc = "A lightning meteor strikes and electrocutes" },
}

-- Fait tomber un météore sur un monstre au hasard (ou devant le héros si l'arène est vide)
local function spawnMeteor(player, dummyPool, projectilePool)
    if not projectilePool then return end
    local tx, ty
    if dummyPool and dummyPool.activeCount > 0 then
        local pick = math.random(1, dummyPool.activeCount)
        local target = dummyPool.items[dummyPool.activeList[pick]]
        if target and target.alive then
            tx, ty = target.x, target.y
        end
    end
    if not tx then
        tx = player.x + (player.aimDirX or 0) * 90
        ty = player.y + (player.aimDirY or -1) * 90
    end

    local proj = projectilePool:obtain()
    if not proj then return end
    local def = METEOR_ELEMENTS[player.meteorSkillId or "meteor_fire"] or METEOR_ELEMENTS.meteor_fire
    local dmg = math.floor(55 + 45 * ((player.meteorLevel or 1) - 1) + (player.currentWeapon.damage * (player.damageMult or 1.0)) * 0.8)
    proj:spawnLobbed(tx + math.random(-18, 18), ty - 190, tx, ty, 0.85, dmg, 44, def.color, false, player.meteorSkillId or "meteor_fire")
end

local function meteorUpdate(player, dt, dummyPool, fctPool, projectilePool)
    if (player.meteorLevel or 0) <= 0 or not projectilePool then return end
    player.meteorTimer = (player.meteorTimer or 0) - dt
    if player.meteorTimer > 0 then return end
    -- Cadence : 4 s, réduite de 25 % par niveau supplémentaire
    player.meteorTimer = 4.0 / (1 + ((player.meteorLevel or 1) - 1) * 0.35)
    spawnMeteor(player, dummyPool, projectilePool)
end

for id, def in pairs(METEOR_ELEMENTS) do
    Skills.register({
        id = id,
        name = def.name,
        desc = def.desc,
        rarity = "epic",
        category = "sky",
        icon = "meteor",
        hooks = {
            onApply = function(p)
                p.meteorLevel = (p.meteorLevel or 0) + 1
                p.meteorSkillId = id
                p.meteorTimer = 1.5
                p.elements = p.elements or {}
                p.elements[def.key] = true
            end,
            onUpdate = meteorUpdate,
        }
    })
end

Skills.register({
    id = "flying_swords",
    name = "Flying Swords",
    desc = "2 daggers dive toward the nearest enemy",
    rarity = "epic",
    category = "sky",
    icon = "swords",
    hooks = {
        onApply = function(p)
            p.flyingSwordCount = math.min(4, (p.flyingSwordCount or 0) + 2)
            for i = 1, p.flyingSwordCount do
                local sw = p.flyingSwords[i]
                sw.state = "hover"
                sw.timer = 0.6 + i * 0.25
                sw.x, sw.y = p.x, p.y - 19
            end
        end,
    }
})

Skills.register({
    id = "wingman",
    name = "Wingman",
    desc = "Pets intercept and block enemy projectiles",
    rarity = "rare",
    category = "defense",
    icon = "shield",
    hooks = {
        onApply = function(p) p.hasWingman = true end,
    }
})

Skills.register({
    id = "invincible_star",
    name = "Invincible Star",
    desc = "Golden shield grants invulnerability for 2s every 10s",
    rarity = "epic",
    category = "defense",
    icon = "star",
    hooks = {
        onApply = function(p)
            p.hasStar = true
            p.starCooldown = 6.0
        end,
    }
})

-- ============================================================================
-- 9. POUVOIRS CLASSIQUES D'ARCHERO (marque, clone, vie bonus, nova, soin)
-- ============================================================================
Skills.register({
    id = "dark_touch",
    name = "Dark Touch",
    desc = "Struck enemies take +25% increased damage",
    rarity = "rare",
    category = "debuff",
    icon = "damage",
    hooks = {
        onApply = function(p) p.hasDarkTouch = true end,
    }
})

Skills.register({
    id = "shadow_clone",
    name = "Shadow Clone",
    desc = "A clone follows you and fires at 45% damage",
    rarity = "epic",
    category = "summon",
    icon = "multishot",
    hooks = {
        onApply = function(p)
            p.hasShadowClone = true
            p.shadowClone = p.shadowClone or { x = p.x - 22, y = p.y + 12, timer = 0 }
        end,
    }
})

Skills.register({
    id = "extra_life",
    name = "Extra Life",
    desc = "Resurrects once with half max HP",
    rarity = "epic",
    category = "defense",
    icon = "heal",
    hooks = {
        onApply = function(p) p.extraLives = (p.extraLives or 0) + 1 end,
    }
})

Skills.register({
    id = "death_nova",
    name = "Death Nova",
    desc = "Enemies explode upon defeat in a deadly nova",
    rarity = "epic",
    category = "damage",
    icon = "damage",
    hooks = {
        onApply = function(p) p.hasDeathNova = true end,
        onMonsterDeath = function(target, player, ctx)
            if not player.hasDeathNova or not ctx or not ctx.dummyPool then return end
            local VFX = require("src.render.vfx_manager")
            VFX.addSparks(target.x, target.y, 12, { 0.75, 0.35, 1.0, 1.0 })
            VFX.shakeLight()
            local pool = ctx.dummyPool
            for i = 1, pool.activeCount do
                local other = pool.items[pool.activeList[i]]
                if other and other.alive and other.id ~= target.id then
                    local dx = other.x - target.x
                    local dy = other.y - target.y
                    local distSq = dx * dx + dy * dy
                    if distSq <= 52 * 52 then
                        local dist = math.max(1, math.sqrt(distSq))
                        other:takeDamage(42, dx / dist, dy / dist)
                        VFX.triggerHitFlash(other, 2)
                        if ctx.fctPool then
                            local f = ctx.fctPool:obtain()
                            if f then f:spawn(other.x, other.y - 10, 42, true) end
                        end
                    end
                end
            end
        end,
    }
})

Skills.register({
    id = "holy_touch",
    name = "Holy Touch",
    desc = "Each arrow hit restores 1% max HP",
    rarity = "rare",
    category = "defense",
    icon = "heal",
    hooks = {
        onApply = function(p) p.holyTouch = (p.holyTouch or 0) + 0.01 end,
    }
})

-- ============================================================================
-- 8. AMÉLIORATIONS CUMULABLES (chaque prise renforce l'effet)
-- ============================================================================
-- Ces compétences peuvent sortir plusieurs fois dans une même partie : chaque
-- copie empile son effet, jusqu'à la limite donnée par `maxStacks`.

-- ---------------------------------------------------------------- COMMUNES --
Skills.register({
    id = "sharp_arrows", name = "Sharp Arrows", desc = "+8% Damage",
    rarity = "common", category = "stats", icon = "damage", maxStacks = 6,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.08 end }
})

Skills.register({
    id = "quick_draw", name = "Quick Draw", desc = "+8% Attack speed",
    rarity = "common", category = "stats", icon = "speed", maxStacks = 6,
    hooks = { onApply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.08 end }
})

Skills.register({
    id = "light_step", name = "Light Step", desc = "+6% Movement speed",
    rarity = "common", category = "stats", icon = "boots", maxStacks = 6,
    hooks = { onApply = function(p) p.speed = p.speed * 1.06 end }
})

Skills.register({
    id = "vitality_training", name = "Vitality Training", desc = "+25 Max HP",
    rarity = "common", category = "stats", icon = "heal", maxStacks = 6,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 25; p.hp = p.hp + 25 end }
})

Skills.register({
    id = "keen_eye", name = "Keen Eye", desc = "+4% Critical chance",
    rarity = "common", category = "stats", icon = "crit", maxStacks = 6,
    hooks = { onApply = function(p) p.critChance = (p.critChance or 0) + 0.04 end }
})

Skills.register({
    id = "heavy_tip", name = "Heavy Tip", desc = "+15% Critical damage",
    rarity = "common", category = "stats", icon = "crit", maxStacks = 6,
    hooks = { onApply = function(p) p.critMultiplier = (p.critMultiplier or 1.5) + 0.15 end }
})

Skills.register({
    id = "agile_dodge", name = "Agile Dodge", desc = "+3% Dodge chance",
    rarity = "common", category = "stats", icon = "boots", maxStacks = 6,
    hooks = { onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.03 end }
})

Skills.register({
    id = "broad_head", name = "Broad Head", desc = "Larger arrow heads (+1 radius)",
    rarity = "common", category = "shots", icon = "multishot", maxStacks = 5,
    hooks = { onApply = function(p) p.arrowRadiusBonus = (p.arrowRadiusBonus or 0) + 1 end }
})

Skills.register({
    id = "coin_charm", name = "Lucky Charm", desc = "+10% Gold collected",
    rarity = "common", category = "utility", icon = "star", maxStacks = 6,
    hooks = { onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1) + 0.10 end }
})

Skills.register({
    id = "scholar", name = "Scholar", desc = "+12% Experience gained",
    rarity = "common", category = "utility", icon = "star", maxStacks = 6,
    hooks = { onApply = function(p) p.xpMultiplier = (p.xpMultiplier or 1) + 0.12 end }
})

Skills.register({
    id = "field_bandage", name = "Field Bandage", desc = "Regenerates 0.4 HP per second",
    rarity = "common", category = "survival", icon = "heal", maxStacks = 6,
    hooks = { onApply = function(p) p.hpRegen = (p.hpRegen or 0) + 0.4 end }
})

Skills.register({
    id = "iron_skin", name = "Iron Skin", desc = "+18 Max HP and instant heal",
    rarity = "common", category = "survival", icon = "shield", maxStacks = 6,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 18) end }
})

-- -------------------------------------------------------------------- RARES --
Skills.register({
    id = "vampiric_edge", name = "Vampiric Edge", desc = "Life steal: 2% of damage dealt",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.lifeSteal = (p.lifeSteal or 0) + 0.02 end }
})

Skills.register({
    id = "titan_slayer", name = "Titan Slayer", desc = "+18% Damage against bosses",
    rarity = "rare", category = "stats", icon = "swords", maxStacks = 4,
    hooks = { onApply = function(p) p.bossDamageMult = (p.bossDamageMult or 1) + 0.18 end }
})

Skills.register({
    id = "crit_surge", name = "Crit Surge", desc = "+8% Critical chance",
    rarity = "rare", category = "stats", icon = "crit", maxStacks = 4,
    hooks = { onApply = function(p) p.critChance = (p.critChance or 0) + 0.08 end }
})

Skills.register({
    id = "deep_wound", name = "Deep Wound", desc = "+30% Critical damage",
    rarity = "rare", category = "stats", icon = "crit", maxStacks = 4,
    hooks = { onApply = function(p) p.critMultiplier = (p.critMultiplier or 1.5) + 0.30 end }
})

Skills.register({
    id = "swift_recovery", name = "Swift Recovery", desc = "Regenerates 1 HP per second",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.hpRegen = (p.hpRegen or 0) + 1.0 end }
})

Skills.register({
    id = "gold_rush", name = "Gold Rush", desc = "+22% Gold collected",
    rarity = "rare", category = "utility", icon = "star", maxStacks = 4,
    hooks = { onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1) + 0.22 end }
})

Skills.register({
    id = "arcane_study", name = "Arcane Study", desc = "+25% Experience gained",
    rarity = "rare", category = "utility", icon = "star", maxStacks = 4,
    hooks = { onApply = function(p) p.xpMultiplier = (p.xpMultiplier or 1) + 0.25 end }
})

Skills.register({
    id = "thick_hide", name = "Thick Hide", desc = "+7% Dodge chance",
    rarity = "rare", category = "survival", icon = "shield", maxStacks = 4,
    hooks = { onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.07 end }
})

Skills.register({
    id = "war_drums", name = "War Drums", desc = "+15% Attack speed",
    rarity = "rare", category = "stats", icon = "speed", maxStacks = 4,
    hooks = { onApply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.15 end }
})

Skills.register({
    id = "brutal_force", name = "Brutal Force", desc = "+16% Damage",
    rarity = "rare", category = "stats", icon = "damage", maxStacks = 4,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.16 end }
})

Skills.register({
    id = "marathon", name = "Marathon", desc = "+12% Movement speed",
    rarity = "rare", category = "stats", icon = "boots", maxStacks = 4,
    hooks = { onApply = function(p) p.speed = p.speed * 1.12 end }
})

Skills.register({
    id = "giant_growth", name = "Giant Growth", desc = "+60 Max HP and instant heal",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 60; p.hp = math.min(p.maxHp, p.hp + 60) end }
})

Skills.register({
    id = "hunters_mark", name = "Hunter's Mark", desc = "+22% Damage",
    rarity = "rare", category = "stats", icon = "damage", maxStacks = 3,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.22 end }
})

-- ------------------------------------------------------------------ ÉPIQUES --
Skills.register({
    id = "blood_pact", name = "Blood Pact", desc = "Life steal: 5% of damage dealt",
    rarity = "epic", category = "survival", icon = "heal", maxStacks = 3,
    hooks = { onApply = function(p) p.lifeSteal = (p.lifeSteal or 0) + 0.05 end }
})

Skills.register({
    id = "titan_bane", name = "Titan's Bane", desc = "+35% Damage against bosses",
    rarity = "epic", category = "stats", icon = "swords", maxStacks = 3,
    hooks = { onApply = function(p) p.bossDamageMult = (p.bossDamageMult or 1) + 0.35 end }
})

Skills.register({
    id = "precision_strike", name = "Precision Strike", desc = "+12% Critical chance and +25% Crit damage",
    rarity = "epic", category = "stats", icon = "crit", maxStacks = 3,
    hooks = { onApply = function(p)
        p.critChance = (p.critChance or 0) + 0.12
        p.critMultiplier = (p.critMultiplier or 1.5) + 0.25
    end }
})

Skills.register({
    id = "phantom_step", name = "Phantom Step", desc = "+12% Dodge chance and +6% Speed",
    rarity = "epic", category = "survival", icon = "boots", maxStacks = 3,
    hooks = { onApply = function(p)
        p.dodgeChance = (p.dodgeChance or 0) + 0.12
        p.speed = p.speed * 1.06
    end }
})

Skills.register({
    id = "arrow_rain", name = "Arrow Rain", desc = "+1 Additional front arrow",
    rarity = "epic", category = "shots", icon = "multishot", maxStacks = 3,
    hooks = { onApply = function(p) p.frontArrows = (p.frontArrows or 1) + 1 end }
})

Skills.register({
    id = "wind_blades", name = "Wind Blades", desc = "+1 Side arrow on each flank",
    rarity = "epic", category = "shots", icon = "multishot", maxStacks = 3,
    hooks = { onApply = function(p) p.sideArrows = (p.sideArrows or 0) + 1 end }
})

Skills.register({
    id = "war_machine", name = "War Machine", desc = "+20% Damage and +10% Attack speed",
    rarity = "epic", category = "stats", icon = "damage", maxStacks = 3,
    hooks = { onApply = function(p)
        p.damageMult = (p.damageMult or 1) * 1.20
        p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.10
    end }
})

-- -------------------------------------------------------------- LÉGENDAIRES --
Skills.register({
    id = "dragon_heart", name = "Dragon Heart", desc = "+40% Max HP and regenerates 2 HP/s",
    rarity = "legendary", category = "survival", icon = "heal", maxStacks = 1,
    hooks = { onApply = function(p)
        local bonus = math.floor(p.maxHp * 0.40)
        p.maxHp = p.maxHp + bonus
        p.hp = math.min(p.maxHp, p.hp + bonus)
        p.hpRegen = (p.hpRegen or 0) + 2.0
    end }
})

Skills.register({
    id = "time_dilation", name = "Time Dilation", desc = "+20% Attack and movement speed",
    rarity = "legendary", category = "stats", icon = "speed", maxStacks = 1,
    hooks = { onApply = function(p)
        p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.20
        p.speed = p.speed * 1.20
    end }
})

Skills.register({
    id = "midas_touch", name = "Midas Touch", desc = "+50% Gold and +25% Experience",
    rarity = "legendary", category = "utility", icon = "star", maxStacks = 1,
    hooks = { onApply = function(p)
        p.goldMultiplier = (p.goldMultiplier or 1) + 0.50
        p.xpMultiplier = (p.xpMultiplier or 1) + 0.25
    end }
})

Skills.register({
    id = "soul_harvest", name = "Soul Harvest", desc = "Life steal: 8% of damage dealt",
    rarity = "legendary", category = "survival", icon = "heal", maxStacks = 1,
    hooks = { onApply = function(p) p.lifeSteal = (p.lifeSteal or 0) + 0.08 end }
})

-- ============================================================================
-- TIRAGE DES COMPÉTENCES (pondéré par rareté, avec cumul limité)
-- ============================================================================
-- Poids relatifs : une légendaire sort bien plus rarement qu'une commune.
Skills.DRAFT_WEIGHTS = {
    common = 46, uncommon = 24, rare = 20, epic = 8, legendary = 2,
    forbidden = 0, -- réservées aux pactes du Diable, jamais proposées au niveau
}

-- Nombre de fois qu'une compétence peut être empilée par défaut
local DEFAULT_MAX_STACKS = { common = 5, uncommon = 4, rare = 3, epic = 2, legendary = 1, forbidden = 1 }

function Skills.maxStacks(def)
    if not def then return 1 end
    return def.maxStacks or DEFAULT_MAX_STACKS[def.rarity or "common"] or 3
end

-- Nombre de copies déjà prises dans la partie en cours
function Skills.stackCount(acquired, id)
    local n = 0
    for _, sk in ipairs(acquired or {}) do
        if sk.id == id then n = n + 1 end
    end
    return n
end

-- Propose `count` compétences distinctes, en excluant celles déjà au maximum.
-- `acquired` est la liste des compétences déjà prises pendant la partie.
function Skills.getRandomDraft(count, acquired)
    count = count or 3

    local pool, total = {}, 0
    for _, id in ipairs(Skills.list) do
        local def = Skills.registry[id]
        local weight = Skills.DRAFT_WEIGHTS[def.rarity or "common"] or 0
        if weight > 0 and Skills.stackCount(acquired, id) < Skills.maxStacks(def) then
            total = total + weight
            pool[#pool + 1] = { def = def, weight = weight }
        end
    end

    local draft = {}
    for _ = 1, math.min(count, #pool) do
        local roll, acc = math.random() * total, 0
        for i, entry in ipairs(pool) do
            acc = acc + entry.weight
            if roll <= acc or i == #pool then
                table.insert(draft, entry.def)
                total = total - entry.weight
                table.remove(pool, i)
                break
            end
        end
    end

    return draft
end

function Skills.get(id)
    return Skills.registry[id]
end

-- ============================================================================
-- SYNERGIES & FUSIONS LÉGENDAIRES DE COMPÉTENCES (STYLE VAMPIRE SURVIVORS / ARCHERO 2)
-- ============================================================================
Skills.SYNERGIES = {
    toxic_flame = {
        id = "toxic_flame",
        name = "Toxic Flame",
        desc = "Poisoned monsters explode into flames upon death!",
        icon = "damage",
        req1 = "fire_element",
        req2 = "poison_element",
        onActivate = function(p)
            p.hasSynergyToxicFlame = true
        end,
    },
    magnetic_storm = {
        id = "magnetic_storm",
        name = "Magnetic Storm",
        desc = "Chain lightning arcs leave electric zones on the ground!",
        icon = "speed",
        req1 = "lightning_element",
        req2 = "ricochet",
        onActivate = function(p)
            p.hasSynergyMagneticStorm = true
        end,
    },
    blade_vortex = {
        id = "blade_vortex",
        name = "Blade Vortex",
        desc = "Shields and blades fuse: destroying missiles and shredding in melee!",
        icon = "shield",
        reqOrbital = true,
        reqShield = true,
        onActivate = function(p)
            p.hasSynergyBladeVortex = true
            if p.orbitals then
                for _, orb in ipairs(p.orbitals) do
                    orb.isShield = true
                    orb.dmg = (orb.dmg or 15) * 2.5
                    orb.dist = 30
                end
            end
        end,
    },
}

function Skills.checkSynergies(player, acquiredSkills)
    if not player or not acquiredSkills then return {} end

    local hasSkill = {}
    local hasRotatingSword = false
    local hasShieldOrbital = false

    for _, sk in ipairs(acquiredSkills) do
        hasSkill[sk.id] = true
        if sk.id == "rotating_sword_fire" or sk.id == "rotating_sword_ice" or sk.id == "rotating_sword_poison" then
            hasRotatingSword = true
        end
        if sk.id == "shield_guard" or sk.id == "shield_orb" then
            hasShieldOrbital = true
        end
    end

    player.activeSynergies = player.activeSynergies or {}
    local newlyUnlocked = {}

    -- 1. Flammes Toxiques (Feu + Poison)
    if (hasSkill["fire_element"] or (player.elements and player.elements.fire)) and
       (hasSkill["poison_element"] or (player.elements and player.elements.poison)) then
        if not player.activeSynergies["toxic_flame"] then
            player.activeSynergies["toxic_flame"] = true
            Skills.SYNERGIES.toxic_flame.onActivate(player)
            table.insert(newlyUnlocked, Skills.SYNERGIES.toxic_flame)
        end
    end

    -- 2. Tempête Magnétique (Foudre + Ricochet)
    if (hasSkill["lightning_element"] or (player.elements and player.elements.lightning)) and
       (hasSkill["ricochet"] or player.hasRicochet) then
        if not player.activeSynergies["magnetic_storm"] then
            player.activeSynergies["magnetic_storm"] = true
            Skills.SYNERGIES.magnetic_storm.onActivate(player)
            table.insert(newlyUnlocked, Skills.SYNERGIES.magnetic_storm)
        end
    end

    -- 3. Vortex de Lames (Bouclier + Épée orbitale)
    if hasRotatingSword and hasShieldOrbital then
        if not player.activeSynergies["blade_vortex"] then
            player.activeSynergies["blade_vortex"] = true
            Skills.SYNERGIES.blade_vortex.onActivate(player)
            table.insert(newlyUnlocked, Skills.SYNERGIES.blade_vortex)
        end
    end

    return newlyUnlocked
end

return Skills
