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
    name = "Flèche Frontale +1",
    desc = "Tire une flèche supplémentaire vers l'avant",
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
    name = "Flèches Diagonales",
    desc = "Tire 2 flèches supplémentaires à 45°",
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
    name = "Flèche Arrière",
    desc = "Tire 1 flèche directement vers l'arrière",
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
    name = "Flèches Latérales",
    desc = "Tire 2 flèches sur les côtés à 90°",
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
    desc = "Les flèches bondissent vers un monstre proche",
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
    name = "Tir Transperçant",
    desc = "Les flèches traversent tous les ennemis",
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
    name = "Rebond Mural",
    desc = "Les flèches ricochent sur les murs de l'arène",
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
    name = "Flèche Géante",
    desc = "Rayon +60% et Dégâts +35%",
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
    name = "Brasier Ardent",
    desc = "Enflamme les ennemis (Dégâts continus 3s)",
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
    name = "Morsure de Givre",
    desc = "Ralentit les monstres touchés de 40%",
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
    name = "Foudre Céleste",
    desc = "Déclenche un arc électrique de zone au contact",
    rarity = "epic",
    category = "elements",
    icon = "speed",
    hooks = {
        onApply = function(p) p.elements = p.elements or {}; p.elements.lightning = true end,
    }
})

Skills.register({
    id = "poison_element",
    name = "Venin Mortel",
    desc = "Empoisonne la cible jusqu'à son élimination",
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
    name = "Épée Flamboyante",
    desc = "Une épée de feu tourne autour de vous",
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
    name = "Épée de Givre",
    desc = "Une épée glacée tourne et blesse au contact",
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
    name = "Épée Toxique",
    desc = "Une lame verte empoisonnée en rotation",
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
    name = "Orbe Protecteur",
    desc = "Un bouclier flottant bloque les tirs adverses",
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
    name = "Garde Sacrée",
    desc = "Deux boucliers dorés orbitaux bloquent tous les projectiles ennemis",
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
    name = "Force Héroïque",
    desc = "+30% de Dégâts d'attaque",
    rarity = "common",
    category = "stats",
    icon = "damage",
    hooks = {
        onApply = function(p) p.damageMult = p.damageMult * 1.30 end,
    }
})

Skills.register({
    id = "attack_speed_boost",
    name = "Frénésie Martiale",
    desc = "+35% Vitesse d'attaque",
    rarity = "common",
    category = "stats",
    icon = "speed",
    hooks = {
        onApply = function(p) p.attackSpeedMult = p.attackSpeedMult * 1.35 end,
    }
})

Skills.register({
    id = "max_hp_boost",
    name = "Vitalité de Titan",
    desc = "+25% PV Maximum et soigne 40 PV",
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
    name = "Grâce Céleste",
    desc = "+15% de Chances d'Esquiver les coups",
    rarity = "rare",
    category = "stats",
    icon = "boots",
    hooks = {
        onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.15 end,
    }
})

Skills.register({
    id = "crit_master",
    name = "Maître Critique",
    desc = "+25% Critique et Dégâts Critiques doublés",
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
    name = "Ailes d'Hermès",
    desc = "+25% Vitesse de marche",
    rarity = "common",
    category = "stats",
    icon = "boots",
    hooks = {
        onApply = function(p) p.speed = p.speed * 1.25 end,
    }
})

Skills.register({
    id = "first_aid",
    name = "Potion d'Urgence",
    desc = "Restaure 45% des PV immédiatement",
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
    name = "Pacte de Midas",
    desc = "+50% de pièces d'or récoltées",
    rarity = "rare",
    category = "stats",
    icon = "multishot",
    hooks = {
        onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1.0) * 1.5 end,
    }
})

Skills.register({
    id = "giant_form",
    name = "Forme de Colosse",
    desc = "Taille +15%, Dégâts +40%, PV Max +30%",
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
    name = "Explosion Macabre",
    desc = "Les ennemis explosent en mourant (Dégâts de zone)",
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
    name = "Étoile Funeste",
    desc = "Décoche 8 aiguilles radiales à la mort d'un monstre",
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
    name = "Soif de Sang",
    desc = "Récupère 25 PV à chaque élimination",
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
    name = "Tir Fatal",
    desc = "3% de chance de tuer instantanément un ennemi",
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
    name = "Rage Berserker",
    desc = "Plus vos PV baissent, plus l'ATQ augmente (jusqu'à +75%)",
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
    name = "Tir Obscur +1",
    desc = "Tire une flèche frontale supplémentaire",
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
    name = "Fureur Démoniaque",
    desc = "+35% de Dégâts bruts permanents",
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
    name = "Célérité Infernale",
    desc = "+30% de Vitesse de déplacement et d'attaque",
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
    name = "Forme Spectrale",
    desc = "Permet de traverser les obstacles et fossés",
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
    meteor_fire    = { key = "fire",      color = { 1.00, 0.45, 0.12, 1.0 }, name = "Météore Ardent",  desc = "Un météore enflammé s'écrase toutes les 4 s" },
    meteor_ice     = { key = "ice",       color = { 0.45, 0.85, 1.00, 1.0 }, name = "Météore Glacial", desc = "Un météore de glace s'écrase et gèle la zone" },
    meteor_thunder = { key = "lightning", color = { 1.00, 0.90, 0.30, 1.0 }, name = "Météore Foudre",  desc = "Un météore électrique s'écrase et électrocute" },
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
    name = "Épées Volantes",
    desc = "2 dagues plongent sur l'ennemi le plus proche",
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
    desc = "Les familiers interceptent les tirs ennemis",
    rarity = "rare",
    category = "defense",
    icon = "shield",
    hooks = {
        onApply = function(p) p.hasWingman = true end,
    }
})

Skills.register({
    id = "invincible_star",
    name = "Étoile d'Invincibilité",
    desc = "Bouclier doré de 2 s toutes les 10 s",
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
    name = "Toucher Obscur",
    desc = "Les ennemis touchés subissent +25% de dégâts",
    rarity = "rare",
    category = "debuff",
    icon = "damage",
    hooks = {
        onApply = function(p) p.hasDarkTouch = true end,
    }
})

Skills.register({
    id = "shadow_clone",
    name = "Clone d'Ombre",
    desc = "Un double vous suit et tire à 45% des dégâts",
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
    name = "Vie Supplémentaire",
    desc = "Ressuscite une fois avec la moitié des PV",
    rarity = "epic",
    category = "defense",
    icon = "heal",
    hooks = {
        onApply = function(p) p.extraLives = (p.extraLives or 0) + 1 end,
    }
})

Skills.register({
    id = "death_nova",
    name = "Nova de Mort",
    desc = "Les monstres explosent en mourant (zone)",
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
    name = "Toucher Sacré",
    desc = "Chaque tir qui touche rend 1% des PV max",
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
    id = "sharp_arrows", name = "Pointes Affûtées", desc = "+8% de dégâts",
    rarity = "common", category = "stats", icon = "damage", maxStacks = 6,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.08 end }
})

Skills.register({
    id = "quick_draw", name = "Tir Rapide", desc = "+8% de vitesse d'attaque",
    rarity = "common", category = "stats", icon = "speed", maxStacks = 6,
    hooks = { onApply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.08 end }
})

Skills.register({
    id = "light_step", name = "Pas Léger", desc = "+6% de vitesse de déplacement",
    rarity = "common", category = "stats", icon = "boots", maxStacks = 6,
    hooks = { onApply = function(p) p.speed = p.speed * 1.06 end }
})

Skills.register({
    id = "vitality_training", name = "Entraînement", desc = "+25 PV maximum",
    rarity = "common", category = "stats", icon = "heal", maxStacks = 6,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 25; p.hp = p.hp + 25 end }
})

Skills.register({
    id = "keen_eye", name = "Œil Aiguisé", desc = "+4% de chance critique",
    rarity = "common", category = "stats", icon = "crit", maxStacks = 6,
    hooks = { onApply = function(p) p.critChance = (p.critChance or 0) + 0.04 end }
})

Skills.register({
    id = "heavy_tip", name = "Pointe Lourde", desc = "+15% de dégâts critiques",
    rarity = "common", category = "stats", icon = "crit", maxStacks = 6,
    hooks = { onApply = function(p) p.critMultiplier = (p.critMultiplier or 1.5) + 0.15 end }
})

Skills.register({
    id = "agile_dodge", name = "Esquive Agile", desc = "+3% d'esquive",
    rarity = "common", category = "stats", icon = "boots", maxStacks = 6,
    hooks = { onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.03 end }
})

Skills.register({
    id = "broad_head", name = "Fer Large", desc = "Flèches plus grosses (+1 rayon)",
    rarity = "common", category = "shots", icon = "multishot", maxStacks = 5,
    hooks = { onApply = function(p) p.arrowRadiusBonus = (p.arrowRadiusBonus or 0) + 1 end }
})

Skills.register({
    id = "coin_charm", name = "Porte-Bonheur", desc = "+10% d'or ramassé",
    rarity = "common", category = "utility", icon = "star", maxStacks = 6,
    hooks = { onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1) + 0.10 end }
})

Skills.register({
    id = "scholar", name = "Studieux", desc = "+12% d'expérience",
    rarity = "common", category = "utility", icon = "star", maxStacks = 6,
    hooks = { onApply = function(p) p.xpMultiplier = (p.xpMultiplier or 1) + 0.12 end }
})

Skills.register({
    id = "field_bandage", name = "Bandage", desc = "Régénère 0.4 PV par seconde",
    rarity = "common", category = "survival", icon = "heal", maxStacks = 6,
    hooks = { onApply = function(p) p.hpRegen = (p.hpRegen or 0) + 0.4 end }
})

Skills.register({
    id = "iron_skin", name = "Peau de Fer", desc = "+18 PV maximum et soin immédiat",
    rarity = "common", category = "survival", icon = "shield", maxStacks = 6,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 18) end }
})

-- -------------------------------------------------------------------- RARES --
Skills.register({
    id = "vampiric_edge", name = "Lame Vampirique", desc = "Vol de vie : 2% des dégâts infligés",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.lifeSteal = (p.lifeSteal or 0) + 0.02 end }
})

Skills.register({
    id = "titan_slayer", name = "Tueur de Titans", desc = "+18% de dégâts contre les boss",
    rarity = "rare", category = "stats", icon = "swords", maxStacks = 4,
    hooks = { onApply = function(p) p.bossDamageMult = (p.bossDamageMult or 1) + 0.18 end }
})

Skills.register({
    id = "crit_surge", name = "Montée Critique", desc = "+8% de chance critique",
    rarity = "rare", category = "stats", icon = "crit", maxStacks = 4,
    hooks = { onApply = function(p) p.critChance = (p.critChance or 0) + 0.08 end }
})

Skills.register({
    id = "deep_wound", name = "Plaie Profonde", desc = "+30% de dégâts critiques",
    rarity = "rare", category = "stats", icon = "crit", maxStacks = 4,
    hooks = { onApply = function(p) p.critMultiplier = (p.critMultiplier or 1.5) + 0.30 end }
})

Skills.register({
    id = "swift_recovery", name = "Convalescence", desc = "Régénère 1 PV par seconde",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.hpRegen = (p.hpRegen or 0) + 1.0 end }
})

Skills.register({
    id = "gold_rush", name = "Ruée vers l'Or", desc = "+22% d'or ramassé",
    rarity = "rare", category = "utility", icon = "star", maxStacks = 4,
    hooks = { onApply = function(p) p.goldMultiplier = (p.goldMultiplier or 1) + 0.22 end }
})

Skills.register({
    id = "arcane_study", name = "Étude Arcanique", desc = "+25% d'expérience",
    rarity = "rare", category = "utility", icon = "star", maxStacks = 4,
    hooks = { onApply = function(p) p.xpMultiplier = (p.xpMultiplier or 1) + 0.25 end }
})

Skills.register({
    id = "thick_hide", name = "Cuir Épais", desc = "+7% d'esquive",
    rarity = "rare", category = "survival", icon = "shield", maxStacks = 4,
    hooks = { onApply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.07 end }
})

Skills.register({
    id = "war_drums", name = "Tambours de Guerre", desc = "+15% de vitesse d'attaque",
    rarity = "rare", category = "stats", icon = "speed", maxStacks = 4,
    hooks = { onApply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.15 end }
})

Skills.register({
    id = "brutal_force", name = "Force Brutale", desc = "+16% de dégâts",
    rarity = "rare", category = "stats", icon = "damage", maxStacks = 4,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.16 end }
})

Skills.register({
    id = "marathon", name = "Marathonien", desc = "+12% de vitesse de déplacement",
    rarity = "rare", category = "stats", icon = "boots", maxStacks = 4,
    hooks = { onApply = function(p) p.speed = p.speed * 1.12 end }
})

Skills.register({
    id = "giant_growth", name = "Croissance", desc = "+60 PV maximum et soin immédiat",
    rarity = "rare", category = "survival", icon = "heal", maxStacks = 4,
    hooks = { onApply = function(p) p.maxHp = p.maxHp + 60; p.hp = math.min(p.maxHp, p.hp + 60) end }
})

Skills.register({
    id = "hunters_mark", name = "Marque du Chasseur", desc = "+22% de dégâts",
    rarity = "rare", category = "stats", icon = "damage", maxStacks = 3,
    hooks = { onApply = function(p) p.damageMult = (p.damageMult or 1) * 1.22 end }
})

-- ------------------------------------------------------------------ ÉPIQUES --
Skills.register({
    id = "blood_pact", name = "Pacte de Sang", desc = "Vol de vie : 5% des dégâts infligés",
    rarity = "epic", category = "survival", icon = "heal", maxStacks = 3,
    hooks = { onApply = function(p) p.lifeSteal = (p.lifeSteal or 0) + 0.05 end }
})

Skills.register({
    id = "titan_bane", name = "Fléau des Titans", desc = "+35% de dégâts contre les boss",
    rarity = "epic", category = "stats", icon = "swords", maxStacks = 3,
    hooks = { onApply = function(p) p.bossDamageMult = (p.bossDamageMult or 1) + 0.35 end }
})

Skills.register({
    id = "precision_strike", name = "Frappe de Précision", desc = "+12% critique et +25% dégâts critiques",
    rarity = "epic", category = "stats", icon = "crit", maxStacks = 3,
    hooks = { onApply = function(p)
        p.critChance = (p.critChance or 0) + 0.12
        p.critMultiplier = (p.critMultiplier or 1.5) + 0.25
    end }
})

Skills.register({
    id = "phantom_step", name = "Pas Fantôme", desc = "+12% d'esquive et +6% de vitesse",
    rarity = "epic", category = "survival", icon = "boots", maxStacks = 3,
    hooks = { onApply = function(p)
        p.dodgeChance = (p.dodgeChance or 0) + 0.12
        p.speed = p.speed * 1.06
    end }
})

Skills.register({
    id = "arrow_rain", name = "Pluie de Flèches", desc = "+1 flèche frontale supplémentaire",
    rarity = "epic", category = "shots", icon = "multishot", maxStacks = 3,
    hooks = { onApply = function(p) p.frontArrows = (p.frontArrows or 1) + 1 end }
})

Skills.register({
    id = "wind_blades", name = "Lames de Vent", desc = "+1 flèche latérale de chaque côté",
    rarity = "epic", category = "shots", icon = "multishot", maxStacks = 3,
    hooks = { onApply = function(p) p.sideArrows = (p.sideArrows or 0) + 1 end }
})

Skills.register({
    id = "war_machine", name = "Machine de Guerre", desc = "+20% dégâts et +10% vitesse d'attaque",
    rarity = "epic", category = "stats", icon = "damage", maxStacks = 3,
    hooks = { onApply = function(p)
        p.damageMult = (p.damageMult or 1) * 1.20
        p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.10
    end }
})

-- -------------------------------------------------------------- LÉGENDAIRES --
Skills.register({
    id = "dragon_heart", name = "Cœur de Dragon", desc = "+40% PV max et régénère 2 PV/s",
    rarity = "legendary", category = "survival", icon = "heal", maxStacks = 1,
    hooks = { onApply = function(p)
        local bonus = math.floor(p.maxHp * 0.40)
        p.maxHp = p.maxHp + bonus
        p.hp = math.min(p.maxHp, p.hp + bonus)
        p.hpRegen = (p.hpRegen or 0) + 2.0
    end }
})

Skills.register({
    id = "time_dilation", name = "Dilatation Temporelle", desc = "+20% vitesse d'attaque et de déplacement",
    rarity = "legendary", category = "stats", icon = "speed", maxStacks = 1,
    hooks = { onApply = function(p)
        p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.20
        p.speed = p.speed * 1.20
    end }
})

Skills.register({
    id = "midas_touch", name = "Toucher de Midas", desc = "+50% d'or et +25% d'expérience",
    rarity = "legendary", category = "utility", icon = "star", maxStacks = 1,
    hooks = { onApply = function(p)
        p.goldMultiplier = (p.goldMultiplier or 1) + 0.50
        p.xpMultiplier = (p.xpMultiplier or 1) + 0.25
    end }
})

Skills.register({
    id = "soul_harvest", name = "Moisson d'Âmes", desc = "Vol de vie : 8% des dégâts infligés",
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
        name = "Flammes Toxiques",
        desc = "Les monstres empoisonnés explosent en flammes à leur mort !",
        icon = "damage",
        req1 = "fire_element",
        req2 = "poison_element",
        onActivate = function(p)
            p.hasSynergyToxicFlame = true
        end,
    },
    magnetic_storm = {
        id = "magnetic_storm",
        name = "Tempête Magnétique",
        desc = "Les arcs électriques laissent des zones de foudre au sol !",
        icon = "speed",
        req1 = "lightning_element",
        req2 = "ricochet",
        onActivate = function(p)
            p.hasSynergyMagneticStorm = true
        end,
    },
    blade_vortex = {
        id = "blade_vortex",
        name = "Vortex de Lames",
        desc = "Les boucliers et lames fusionnent : détruit les tirs et déchiquette au corps-à-corps !",
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
