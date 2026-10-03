-- src/render/title_layout.lua
-- Généré par tools/make_title_assets.py : ne pas modifier à la main.
-- Rectangles (x, y, w, h) dans les textures de l'écran titre.

return {
    bg = { 0, 0, 426, 256 },
    letters = { 0, 0, 221, 67 },
    halo = { 0, 112, 237, 83 },
    glow = { 224, 0, 32, 32 },
    spark = { 224, 32, 32, 32 },
    dot = { 224, 64, 16, 16 },
    mote = { 240, 64, 8, 8 },
    ring = { 328, 0, 176, 176 },
    bottomBg = { 0, 0, 320, 240 },
    -- Position du titre dans le décor (pixels du décor 426x256)
    titleX = 102, titleY = 8,
    -- Points les plus brillants des lettres (repère du titre)
    gleams = { { 167, 22 }, { 117, 34 }, { 22, 15 }, { 89, 22 }, { 58, 22 }, { 194, 21 }, { 11, 35 } },
    -- Lumières du décor (pixels du décor) ; flèches : x, y, couleur
    moon = { 277, 15 },
    torches = { { 108, 155 }, { 348, 145 }, { 417, 95 } },
    runes = { { 27, 110 }, { 27, 150 }, { 50, 47 }, { 110, 117 }, { 347, 100 }, { 410, 30 }, { 360, 187 } },
    stars = { { 130, 86 }, { 166, 76 }, { 252, 82 }, { 345, 62 }, { 94, 74 }, { 300, 10 } },
    arrows = {
        { 327, 90, { 1.00, 0.45, 0.10 } },
        { 330, 115, { 1.00, 0.85, 0.35 } },
        { 333, 146, { 0.75, 0.30, 1.00 } },
    },
}
