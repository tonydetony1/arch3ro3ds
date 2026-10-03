-- src/render/sprites/overlays.lua
-- Voiles translucides et ombres PRÉ-COLORÉS (couleur + transparence cuites dans l'atlas).
--
-- Sur 3DS, SpriteBatch ignore setColor : un aplat teinté ou une ombre teintée devait être
-- dessiné à part, et chaque appel de dessin coûte ~80 µs sur Old 3DS. Ces sprites se
-- dessinent en blanc : ils entrent dans le même lot que le décor (1 seul appel au total).
-- Les dégradés sont des bandes de 1 pixel étirées à la taille voulue.

local Palette = require("src.render.palette")

local Overlays = {}

local C = Palette.C
local CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local function rgba(c, a)
    return { c[1], c[2], c[3], a }
end

-- Dégradé de n pas : alpha(i) pour i = 0..n-1 ; vertical (1 x n) ou horizontal (n x 1)
local function gradient(atlas, name, color, n, alphaAt, horizontal)
    local pal, row, grid = {}, {}, {}
    for i = 0, n - 1 do
        local ch = CHARS:sub(i + 1, i + 1)
        pal[ch] = rgba(color, alphaAt(i / math.max(1, n - 1)))
        row[#row + 1] = ch
        grid[#grid + 1] = ch
    end
    local frame = horizontal and { table.concat(row) } or grid
    atlas:define(name, { frames = { frame }, palette = pal, anchor = "topleft" })
end

local function flat(atlas, name, color, alpha)
    atlas:define(name, { frames = { { "W" } }, palette = { W = rgba(color, alpha) }, anchor = "topleft" })
end

local SHADOW = {
    "...WWWW...",
    ".WWWWWWWW.",
    "WWWWWWWWWW",
    "WWWWWWWWWW",
    ".WWWWWWWW.",
    "...WWWW...",
}

-- Projectiles pré-teintés : flèche et orbe déclinées dans les teintes de la palette. La
-- couleur d'un tir (arme, élément, monstre) est ramenée à la teinte la plus proche et le
-- sprite est dessiné en blanc (même lot que le reste au lieu d'1 appel GPU par tir).
Overlays.TINTS = { "white", "red", "orange", "amber", "yellow", "leaf", "cyan", "blue", "magenta",
    "pink", "silver", "wine", "plum", "ember", "crimson", "sand" }

local ARROW = { "ff.....H..", ".SSSSSSHHH", "ff.....H.." }
local SPARK = { "..W..", "..W..", "WWWWW", "..W..", "..W.." }
local RING = { "..WWW..", ".W...W.", "W.....W", "W.....W", "W.....W", ".W...W.", "..WWW.." }
-- Orbe ennemie avec son cœur blanc (C) intégré : un seul sprite par tir au lieu de deux
local ORB = { ".WWW.", "WCCWW", "WCCWW", "WWWWW", ".WWW." }

local function mul(hexOrC, t)
    local c = type(hexOrC) == "string" and Palette.hex(hexOrC) or hexOrC
    return { c[1] * t[1], c[2] * t[2], c[3] * t[3], 1 }
end

-- Télégraphe des bombes : anneau fin (rayon 15) et disque translucide (rayon 7), étirés au
-- rayon d'impact. Sprites dessinés en blanc dans le lot du décor au lieu de 6 primitives
-- (cercles à nombreux sommets) par bombe.
local function circleGrid(size, inside)
    local grid, c = {}, (size - 1) / 2
    for y = 0, size - 1 do
        local row = {}
        for x = 0, size - 1 do
            local d = math.sqrt((x - c) ^ 2 + (y - c) ^ 2)
            row[#row + 1] = inside(d, c) and "W" or "."
        end
        grid[#grid + 1] = table.concat(row)
    end
    return grid
end
local TELEGRAPH_RING = circleGrid(31, function(d, c) return math.abs(d - (c - 0.5)) < 0.75 end)
local TELEGRAPH_DISC = circleGrid(15, function(d, c) return d <= c + 0.2 end)

function Overlays.define(atlas)
    for _, name in ipairs(Overlays.TINTS) do
        local t = C[name]
        atlas:define("fx_arrow_" .. name, {
            frames = { ARROW },
            palette = { f = mul("8b9bb4", t), S = mul("c0cbdc", t), H = mul("ffffff", t) },
            outline = mul("181425", t), anchor = { 6, 1 },
        })
        atlas:define("fx_orb_" .. name, {
            frames = { ORB }, palette = { W = mul("ffffff", t), C = { 1, 1, 1, 1 } }, outline = mul("181425", t), anchor = "center",
        })
        atlas:define("fx_spark_" .. name, { frames = { SPARK }, palette = { W = mul("ffffff", t) }, anchor = "center" })
        atlas:define("fx_ring_" .. name, { frames = { RING }, palette = { W = mul("ffffff", t) }, anchor = "center" })
    end
    for _, t in ipairs({ { "red", C.red }, { "amber", C.amber } }) do
        atlas:define("fx_tg_ring_" .. t[1], { frames = { TELEGRAPH_RING }, palette = { W = rgba(t[2], 0.85) }, anchor = "center" })
        atlas:define("fx_tg_disc_" .. t[1], { frames = { TELEGRAPH_DISC }, palette = { W = rgba(t[2], 0.40) }, anchor = "center" })
    end
    -- Pixels pré-colorés de l'interface (src/render/px_colors.lua)
    require("src.render.px_colors").define(atlas)
    -- Brume froide qui descend du haut de l'île, pénombre qui monte du bas
    gradient(atlas, "ov_haze", C.cyan, 16, function(t) return 0.075 * (1 - t) end)
    gradient(atlas, "ov_dark", C.abyss, 16, function(t) return 0.09 * t end)
    -- Ombres portées des murs (haie du haut, bord gauche), pan d'ombre à droite
    gradient(atlas, "ov_wall_top", C.abyss, 12, function(t) return 0.34 * (1 - t) + 0.02 end)
    gradient(atlas, "ov_wall_left", C.abyss, 12, function(t) return 0.30 * (1 - t) + 0.02 end, true)
    flat(atlas, "ov_abyss12", C.abyss, 0.12)
    -- Ombrage de la falaise sous l'île
    gradient(atlas, "ov_cliff", C.night, 30, function(t) return 0.12 + 0.35 * t end)
    -- Lumière chaude (haut-gauche) et froide (bas-droite)
    flat(atlas, "ov_yellow", C.yellow, 0.05)
    flat(atlas, "ov_navy", C.navy, 0.05)
    -- Ombres portées des rochers
    flat(atlas, "ov_shadow", C.abyss, 0.38)
    -- Dégradé du ciel de chaque thème (1 sprite étiré au lieu de 8 bandes de couleur)
    local WorldManager = require("src.core.world_manager")
    for i = 1, 6 do
        local theme = WorldManager.getTheme(i)
        local top = Palette.hex(theme.skyTop or "4f9be8")
        local bottom = Palette.hex(theme.skyBottom or "cdeeff")
        local pal, grid = {}, {}
        local n = 30
        for k = 0, n - 1 do
            local f = k / (n - 1)
            local ch = CHARS:sub(k + 1, k + 1)
            pal[ch] = { top[1] + (bottom[1] - top[1]) * f, top[2] + (bottom[2] - top[2]) * f, top[3] + (bottom[3] - top[3]) * f, 1 }
            grid[#grid + 1] = ch
        end
        atlas:define("ov_sky_" .. i, { frames = { grid }, palette = pal, anchor = "topleft" })
    end
    -- Ombres des personnages et du butin : 3 intensités (l'altitude choisit la plus proche)
    local ink = { 0.04, 0.05, 0.08 }
    atlas:define("fx_shadow_d1", { frames = { SHADOW }, palette = { W = rgba(ink, 0.40) }, anchor = "center" })
    atlas:define("fx_shadow_d2", { frames = { SHADOW }, palette = { W = rgba(ink, 0.26) }, anchor = "center" })
    atlas:define("fx_shadow_d3", { frames = { SHADOW }, palette = { W = rgba(ink, 0.14) }, anchor = "center" })
end

return Overlays
