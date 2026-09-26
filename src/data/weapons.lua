-- src/data/weapons.lua
-- Définition data-driven des armes et caractéristiques des projectiles

local Weapons = {
    starter_bow = {
        id = "starter_bow",
        name = "Arc de Vagabond",
        fire_rate = 0.35,          -- Temps (en secondes) entre chaque tir à l'arrêt
        projectile_speed = 260,     -- Vitesse en pixels par seconde
        damage = 15,                -- Dégâts bruts par flèche
        range = 300,                -- Portée maximale en pixels
        radius = 3,                 -- Rayon de collision pour AABB
        color = {1.0, 0.85, 0.25, 1.0}, -- Jaune or
        sprite = "arrow",
    },

    rapid_daggers = {
        id = "rapid_daggers",
        name = "Dagues de Vent",
        fire_rate = 0.16,
        projectile_speed = 340,
        damage = 8,
        range = 200,
        radius = 2.5,
        color = {0.3, 0.9, 1.0, 1.0},  -- Cyan céleste
        sprite = "dagger",
    },

    heavy_ballista = {
        id = "heavy_ballista",
        name = "Carreau Lourd",
        fire_rate = 0.75,
        projectile_speed = 210,
        damage = 45,
        range = 380,
        radius = 4.5,
        color = {1.0, 0.35, 0.2, 1.0},  -- Rouge braise
    },
    saw_blade = {
        id = "saw_blade",
        name = "Lame Circulaire",
        type = "saw",
        fire_rate = 0.22,
        projectile_speed = 320,
        damage = 16,
        range = 320,
        radius = 4.0,
        color = {0.85, 0.88, 0.95, 1.0},
        sprite = "saw",
    },

    death_scythe = {
        id = "death_scythe",
        name = "Faux de la Mort",
        type = "scythe",
        fire_rate = 0.55,
        projectile_speed = 200,
        damage = 38,
        range = 340,
        radius = 6.5,
        knockback_mult = 3.2,
        execute_threshold = 0.30, -- Exécute immédiatement tout monstre sous 30% PV
        color = {0.85, 0.20, 0.25, 1.0},
        sprite = "scythe",
    },

    stalker_staff = {
        id = "stalker_staff",
        name = "Bâton de Rôdeur",
        type = "staff",
        fire_rate = 0.38,
        projectile_speed = 220,
        damage = 22,
        range = 420,
        radius = 5.0,
        tracking_speed = 7.0, -- Vitesse angulaire de poursuite vers l'ennemi (rad/s)
        color = {0.75, 0.35, 0.95, 1.0},
        sprite = "magic_orb",
    },

    tornado_boomerang = {
        id = "tornado_boomerang",
        name = "Tornade Boomerang",
        type = "boomerang",
        fire_rate = 0.40,
        projectile_speed = 280,
        damage = 20,
        return_damage_mult = 0.65, -- Dégâts au retour vers le joueur
        range = 260,
        radius = 5.5,
        pierce_all = true, -- Traverse tous les monstres à l'aller et au retour
        color = {0.95, 0.70, 0.25, 1.0},
        sprite = "boomerang",
    },

    brightspear = {
        id = "brightspear",
        name = "Lance Brillante",
        type = "spear",
        fire_rate = 0.48,
        projectile_speed = 1800, -- Rayon instantané quasi-hitscan
        damage = 32,
        range = 450,
        radius = 3.5,
        is_hitscan = true,
        color = {1.0, 0.95, 0.50, 1.0},
        sprite = "laser_beam",
    },
}

function Weapons.get(id)
    return Weapons[id] or Weapons.starter_bow
end

return Weapons
