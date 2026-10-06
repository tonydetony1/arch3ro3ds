-- src/data/player_stats.lua
-- Statistiques de base et configuration du joueur

local PlayerStats = {
    base_speed = 115,          -- Vitesse de marche (pixels par seconde)
    max_hp = 100,              -- Points de vie maximum
    hitbox_radius = 7,         -- Rayon AABB de la boîte de collision
    detection_radius = 350,    -- Rayon max pour l'auto-aim
    initial_weapon = "starter_bow",
    dodge_cap = 0.60,          -- dodge chance never goes above this (talents and skills stack)
    heart_heal_ratio = 0.10,   -- a heart heals at least this share of max HP
    max_front_arrows = 3,      -- Player:shoot fans at most this many front arrows
}

return PlayerStats
