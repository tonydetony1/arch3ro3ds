-- src/data/player_stats.lua
-- Statistiques de base et configuration du joueur

local PlayerStats = {
    base_speed = 115,          -- Vitesse de marche (pixels par seconde)
    max_hp = 100,              -- Points de vie maximum
    hitbox_radius = 7,         -- Rayon AABB de la boîte de collision
    detection_radius = 350,    -- Rayon max pour l'auto-aim
    initial_weapon = "starter_bow",
}

return PlayerStats
