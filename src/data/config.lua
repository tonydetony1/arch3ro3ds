-- src/data/config.lua
-- Paramètres globaux, dimensions matérielles et drapeaux de débogage

local Config = {
    VERSION = "1.1", -- shown on the title screen and in the hub settings

    -- Dimensions natives Nintendo 3DS
    TOP_WIDTH = 400,
    TOP_HEIGHT = 240,
    BOTTOM_WIDTH = 320,
    BOTTOM_HEIGHT = 240,

    -- Mode Développeur (Requis dès l'itération 1)
    DEBUG_MODE = false,
    SHOW_GPU_STATS = false, -- overlay FPS / sommets (F3, SELECT, panneau admin)

    -- Capacités maximales des pools (Zéro allocation pendant le gameplay)
    POOL = {
        PROJECTILES = 200,
        DUMMIES = 30,
        PARTICLES = 100,
        FCT = 40, -- Floating Combat Text
        LOOT = 120, -- Pièces d'or, Gemmes XP, Cœurs, Parchemins
    },

    -- Contrôles
    INPUT = {
        DEADZONE = 0.20,     -- Seuil de sensibilité pour le Circle Pad
        KEYBOARD_SPEED = 1.0, -- Multiplicateur pour les touches PC
    },

    -- Cible de performance
    TARGET_FPS = 60,
}

return Config
