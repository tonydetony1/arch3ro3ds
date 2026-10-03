-- src/data/bosses.lua
-- Fiches des boss : 3 phases (seuils PHASE_AT), un déplacement et un cycle d'attaques par
-- phase ; catalogue d'attaques exécutées par src/core/boss_brain.lua. Module pur.
-- Dégâts : valeurs du chapitre 1, multipliées par (1 + DAMAGE_PER_CHAPTER x (chapitre - 1)).

local Bosses = {
    PHASE_AT = { 0.66, 0.33 },   -- passage en phase 2 puis 3 (part des PV restants)
    STAGGER_TIME = 1.0,          -- étourdissement invulnérable au changement de phase
    INITIAL_DELAY = 1.2,         -- délai avant la première attaque
    AIM_LOCK = 0.3,              -- la visée se fige pendant les dernières secondes du télégraphe
    MAX_SHOTS = 60,              -- tirs ennemis simultanés au plus (performances Old 3DS)
    DAMAGE_PER_CHAPTER = 0.25,
    SHOT_RADIUS = 4,
}

Bosses.MOVES = { chase = true, keep = true, hover = true, anchor = true }

local ORANGE = { 1.0, 0.45, 0.15, 1.0 }
local GOLD = { 1.0, 0.85, 0.35, 1.0 }
local VIOLET = { 0.65, 0.35, 1.0, 1.0 }
local LAVA = { 1.0, 0.30, 0.10, 1.0 }
local STORM = { 0.40, 0.85, 1.0, 1.0 }
local VOID = { 0.85, 0.30, 0.95, 1.0 }

-- kind : radial | fan | ring_gap | spiral | rain | charge | summon | teleport
Bosses.ATTACKS = {
    -- Golem de granit (chapitre 1) : apprend les bases
    golem_star8 = { kind = "radial", count = 8, speed = 150, damage = 16, color = ORANGE, windup = 0.7, recover = 1.4 },
    golem_star10x2 = { kind = "radial", count = 10, speed = 155, damage = 16, color = ORANGE, bursts = 2, interval = 0.45,
        alternate = true, windup = 0.7, recover = 1.3 },
    golem_rain3 = { kind = "rain", count = 3, spread = 55, flight = 1.1, aoe = 30, damage = 18, color = ORANGE,
        windup = 0.5, recover = 1.0 },
    golem_star12x3 = { kind = "radial", count = 12, speed = 160, damage = 16, color = ORANGE, bursts = 3, interval = 0.4,
        alternate = true, windup = 0.8, recover = 1.4 },
    golem_charge = { kind = "charge", speed = 230, duration = 0.8, repeats = 1, damage = 20, windup = 0.8, recover = 1.2 },
    golem_rain5 = { kind = "rain", count = 5, spread = 70, flight = 1.0, aoe = 30, damage = 18, color = ORANGE,
        windup = 0.5, recover = 1.0 },

    -- Roi squelette (chapitre 2) : volées visées, renforts
    king_volley3 = { kind = "fan", count = 3, spread = 0.22, speed = 300, damage = 22, color = GOLD, windup = 0.9, recover = 1.2 },
    king_volley5 = { kind = "fan", count = 5, spread = 0.20, speed = 300, damage = 22, color = GOLD, windup = 0.9, recover = 1.2 },
    king_volley5x2 = { kind = "fan", count = 5, spread = 0.20, speed = 300, damage = 22, color = GOLD, bursts = 2,
        interval = 0.5, windup = 0.9, recover = 1.3 },
    king_summon = { kind = "summon", type = "skeleton", count = 2, hpRatio = 0.08, maxMinions = 4, windup = 0.6, recover = 0.8 },
    king_rain4 = { kind = "rain", count = 4, spread = 60, flight = 1.2, aoe = 28, damage = 20, color = GOLD,
        windup = 0.5, recover = 1.0 },
    king_rain6 = { kind = "rain", count = 6, spread = 80, flight = 1.2, aoe = 28, damage = 20, color = GOLD,
        windup = 0.5, recover = 1.0 },
    king_ring = { kind = "ring_gap", count = 18, gap = 4, speed = 140, damage = 20, color = GOLD, windup = 0.8, recover = 1.2 },

    -- Sorcière de cristal (chapitre 3) : téléportations et spirales
    witch_blink = { kind = "teleport", mode = "near", minDist = 110, maxDist = 170, windup = 0.3, recover = 0.3 },
    witch_center = { kind = "teleport", mode = "center", windup = 0.3, recover = 0.3 },
    witch_fan5 = { kind = "fan", count = 5, spread = 0.32, speed = 215, damage = 20, color = VIOLET, windup = 0.55, recover = 1.0 },
    witch_spiral3 = { kind = "spiral", arms = 3, duration = 2.0, interval = 0.14, turn = 2.2, speed = 150, damage = 18,
        color = VIOLET, windup = 0.6, recover = 1.0 },
    witch_ring = { kind = "ring_gap", count = 16, gap = 3, speed = 150, damage = 20, color = VIOLET, windup = 0.7, recover = 1.0 },
    witch_bats = { kind = "summon", type = "bat", count = 2, hpRatio = 0.06, maxMinions = 4, windup = 0.5, recover = 0.6 },
    witch_spiral4 = { kind = "spiral", arms = 4, duration = 2.4, interval = 0.16, turn = -2.4, speed = 155, damage = 18,
        color = VIOLET, windup = 0.6, recover = 1.0 },

    -- Titan de lave (chapitre 4) : poursuite, charges et pluies de lave
    titan_star10 = { kind = "radial", count = 10, speed = 150, damage = 22, color = LAVA, windup = 0.7, recover = 1.3 },
    titan_rain4 = { kind = "rain", count = 4, spread = 60, flight = 1.1, aoe = 36, damage = 24, color = LAVA,
        windup = 0.5, recover = 1.0 },
    titan_charge = { kind = "charge", speed = 250, duration = 0.7, repeats = 1, damage = 26, windup = 0.8, recover = 1.0 },
    titan_star12x2 = { kind = "radial", count = 12, speed = 155, damage = 22, color = LAVA, bursts = 2, interval = 0.45,
        alternate = true, windup = 0.8, recover = 1.3 },
    titan_rain6 = { kind = "rain", count = 6, spread = 80, flight = 1.1, aoe = 36, damage = 24, color = LAVA,
        windup = 0.5, recover = 1.0 },
    titan_charge2 = { kind = "charge", speed = 260, duration = 0.65, repeats = 2, damage = 26, windup = 0.8, recover = 1.2 },
    titan_star14 = { kind = "radial", count = 14, speed = 160, damage = 22, color = LAVA, windup = 0.8, recover = 1.3 },
    titan_rain8 = { kind = "rain", count = 8, spread = 95, flight = 1.0, aoe = 36, damage = 24, color = LAVA,
        windup = 0.5, recover = 1.1 },

    -- Drake des tempêtes (chapitre 5) : garde ses distances, éclairs et ruées
    drake_bolt3 = { kind = "fan", count = 3, spread = 0.18, speed = 280, damage = 22, color = STORM, windup = 0.5, recover = 0.9 },
    drake_dash = { kind = "charge", speed = 300, duration = 0.6, repeats = 1, damage = 24, windup = 0.7, recover = 0.9 },
    drake_bolt5x2 = { kind = "fan", count = 5, spread = 0.20, speed = 280, damage = 22, color = STORM, bursts = 2,
        interval = 0.4, windup = 0.55, recover = 1.0 },
    drake_ring = { kind = "ring_gap", count = 20, gap = 4, speed = 170, damage = 22, color = STORM, windup = 0.7, recover = 1.0 },
    drake_spiral = { kind = "spiral", arms = 4, duration = 2.4, interval = 0.16, turn = 3.0, speed = 170, damage = 20,
        color = STORM, windup = 0.6, recover = 1.0 },
    drake_bolt7 = { kind = "fan", count = 7, spread = 0.16, speed = 290, damage = 22, color = STORM, windup = 0.55, recover = 1.0 },

    -- Œil du vide (chapitre 6) : ancré au centre, spirales permanentes
    void_spiral4 = { kind = "spiral", arms = 4, duration = 2.5, interval = 0.18, turn = 1.8, speed = 140, damage = 22,
        color = VOID, windup = 0.6, recover = 0.8 },
    void_fan5 = { kind = "fan", count = 5, spread = 0.28, speed = 220, damage = 24, color = VOID, windup = 0.6, recover = 0.9 },
    void_ring2 = { kind = "ring_gap", count = 22, gap = 4, speed = 150, damage = 24, color = VOID, bursts = 2, interval = 0.7,
        windup = 0.7, recover = 1.0 },
    void_wisps = { kind = "summon", type = "wisp", count = 2, hpRatio = 0.05, maxMinions = 3, windup = 0.5, recover = 0.6 },
    void_spiral5 = { kind = "spiral", arms = 5, duration = 2.6, interval = 0.18, turn = -2.0, speed = 145, damage = 22,
        color = VOID, windup = 0.6, recover = 0.8 },
    void_spiral6 = { kind = "spiral", arms = 6, duration = 3.0, interval = 0.2, turn = 2.4, speed = 150, damage = 22,
        color = VOID, windup = 0.6, recover = 0.8 },
    void_fan9 = { kind = "fan", count = 9, spread = 0.12, speed = 240, damage = 24, color = VOID, windup = 0.6, recover = 0.9 },
    void_ring = { kind = "ring_gap", count = 24, gap = 3, speed = 160, damage = 24, color = VOID, windup = 0.7, recover = 1.0 },
}

Bosses.DEFS = {
    golem = { phases = {
        { move = { kind = "chase", speed = 1.0 }, attacks = { "golem_star8" } },
        { move = { kind = "chase", speed = 1.1 }, attacks = { "golem_star10x2", "golem_rain3" } },
        { move = { kind = "chase", speed = 1.2 }, attacks = { "golem_star12x3", "golem_charge", "golem_rain5" } },
    } },
    skeleton_king = { phases = {
        { move = { kind = "keep", min = 140, max = 220 }, attacks = { "king_volley3" } },
        { move = { kind = "keep", min = 140, max = 220 }, attacks = { "king_volley5", "king_summon", "king_rain4" } },
        { move = { kind = "keep", min = 130, max = 210 }, attacks = { "king_volley5x2", "king_ring", "king_rain6", "king_summon" } },
    } },
    witch = { phases = {
        { move = { kind = "hover", radius = 90 }, attacks = { "witch_blink", "witch_fan5" } },
        { move = { kind = "hover", radius = 90 }, attacks = { "witch_blink", "witch_spiral3", "witch_fan5" } },
        { move = { kind = "hover", radius = 70 }, attacks = { "witch_center", "witch_ring", "witch_bats", "witch_spiral4" } },
    } },
    lava_titan = { phases = {
        { move = { kind = "chase", speed = 0.9 }, attacks = { "titan_star10", "titan_rain4" } },
        { move = { kind = "chase", speed = 1.0 }, attacks = { "titan_charge", "titan_star12x2", "titan_rain6" } },
        { move = { kind = "chase", speed = 1.1 }, attacks = { "titan_charge2", "titan_star14", "titan_rain8" } },
    } },
    storm_drake = { phases = {
        { move = { kind = "keep", min = 160, max = 240 }, attacks = { "drake_bolt3", "drake_dash" } },
        { move = { kind = "keep", min = 160, max = 240 }, attacks = { "drake_dash", "drake_bolt5x2", "drake_ring" } },
        { move = { kind = "keep", min = 150, max = 230 }, attacks = { "drake_spiral", "drake_dash", "drake_bolt7" } },
    } },
    void_watcher = { phases = {
        { move = { kind = "anchor" }, attacks = { "void_spiral4", "void_fan5" } },
        { move = { kind = "anchor" }, attacks = { "void_ring2", "void_wisps", "void_spiral5" } },
        { move = { kind = "anchor" }, attacks = { "void_spiral6", "void_fan9", "void_ring" } },
    } },
}

return Bosses
