-- src/data/weapons.lua
-- Définition data-driven des armes et caractéristiques des projectiles

local Weapons = {
    starter_bow = {
        id = "starter_bow",
        name = "Brave's Bow",
        fire_rate = 0.35,          -- Cooldown (seconds) between shots when standing still
        projectile_speed = 260,     -- Velocity in pixels per second
        damage = 15,                -- Raw damage per arrow
        range = 300,                -- Maximum range in pixels
        radius = 3,                 -- AABB collision radius
        color = {1.0, 0.85, 0.25, 1.0}, -- Golden yellow
        sprite = "arrow",
    },

    rapid_daggers = {
        id = "rapid_daggers",
        name = "Wind Daggers",
        fire_rate = 0.16,
        projectile_speed = 340,
        damage = 8,
        range = 200,
        radius = 2.5,
        color = {0.3, 0.9, 1.0, 1.0},  -- Celestial cyan
        sprite = "dagger",
    },

    heavy_ballista = {
        id = "heavy_ballista",
        name = "Heavy Ballista",
        fire_rate = 0.75,
        projectile_speed = 210,
        damage = 45,
        range = 380,
        radius = 4.5,
        color = {1.0, 0.35, 0.2, 1.0},  -- Ember red
    },
    saw_blade = {
        id = "saw_blade",
        name = "Saw Blade",
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
        name = "Death Scythe",
        type = "scythe",
        fire_rate = 0.55,
        projectile_speed = 200,
        damage = 38,
        range = 340,
        radius = 6.5,
        knockback_mult = 3.2,
        execute_threshold = 0.30, -- Instantly executes any monster below 30% HP
        color = {0.85, 0.20, 0.25, 1.0},
        sprite = "scythe",
    },

    stalker_staff = {
        id = "stalker_staff",
        name = "Stalker Staff",
        type = "staff",
        fire_rate = 0.38,
        projectile_speed = 220,
        damage = 22,
        range = 420,
        radius = 5.0,
        tracking_speed = 7.0, -- Angular tracking speed towards enemies (rad/s)
        color = {0.75, 0.35, 0.95, 1.0},
        sprite = "magic_orb",
    },

    tornado_boomerang = {
        id = "tornado_boomerang",
        name = "Tornado Boomerang",
        type = "boomerang",
        fire_rate = 0.40,
        projectile_speed = 280,
        damage = 20,
        return_damage_mult = 0.65, -- Return damage multiplier back to player
        range = 260,
        radius = 5.5,
        pierce_all = true, -- Pierces through all enemies forward and backward
        color = {0.95, 0.70, 0.25, 1.0},
        sprite = "boomerang",
    },

    brightspear = {
        id = "brightspear",
        name = "Brightspear",
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
