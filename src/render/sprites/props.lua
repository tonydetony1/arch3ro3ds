-- src/render/sprites/props.lua
-- Décor pixel art : végétation, souches, nuages, dalles, falaise, porte, pièges, nénuphars.
-- Formes organiques générées par PixGen (déterministe), détails fins dessinés à la main.

local PixGen = require("src.render.sprites.pixgen")

local Props = {}

local FOLIAGE = { D = "265c42", M = "3e8948", L = "63c74d", W = "a2dc6e" }
local FOLIAGE_INK = "193c3e"

-- ---------------------------------------------------------------------------
-- Générateurs procéduraux
-- ---------------------------------------------------------------------------
local function canopy(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local cx, cy = w / 2, h / 2
    g:ellipse(cx, cy + 1, w * 0.47, h * 0.45, "D")
    for _ = 1, 5 do
        local a = g:rand() * math.pi * 2
        g:circle(cx + math.cos(a) * w * 0.26, cy + math.sin(a) * h * 0.22 + 1, w * (0.18 + g:rand() * 0.06), "D")
    end
    g:ellipse(cx - 1, cy - 1, w * 0.40, h * 0.37, "M", "D")
    g:circle(cx - w * 0.22, cy + h * 0.05, w * 0.17, "M", "D")
    g:circle(cx + w * 0.2, cy - h * 0.02, w * 0.16, "M", "D")
    g:ellipse(cx - w * 0.12, cy - h * 0.16, w * 0.24, h * 0.2, "L", "M")
    g:circle(cx + w * 0.18, cy - h * 0.1, w * 0.1, "L", "M")
    g:circle(cx - w * 0.2, cy + h * 0.1, w * 0.08, "L", "M")
    g:circle(cx - w * 0.17, cy - h * 0.24, w * 0.08, "W", "L")
    g:sprinkle("M", 0.10, "L")
    g:sprinkle("D", 0.07, "M")
    g:sprinkle("L", 0.05, "W")
    return g:toGrid()
end

local function stump(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local cx = w / 2
    local topY = math.floor(h * 0.36)
    local rx, ry = w * 0.44, h * 0.28
    g:ellipse(cx, h - ry - 1, rx, ry, "B")
    g:rect(math.floor(cx - rx), topY, math.ceil(rx * 2), h - ry - topY, "B")
    g:edge("B", "b", 1, 0)
    for i = 1, 3 do
        local x = math.floor(cx - rx * 0.6 + i * rx * 0.4)
        g:rect(x, topY + 3, 1, h - topY - 6, "b", "B")
    end
    g:ellipse(cx - rx * 0.95, h - 4, 4, 3, "B")
    g:ellipse(cx + rx * 0.95, h - 4, 4, 3, "b")
    g:ellipse(cx, topY, rx, ry, "T")
    g:ellipse(cx, topY, rx - 1, ry - 1, "t", "T")
    g:ellipse(cx, topY, rx - 2, ry - 2, "T", "t")
    g:ellipse(cx, topY, rx * 0.62, ry * 0.62, "t", "T")
    g:ellipse(cx, topY, rx * 0.62 - 1, ry * 0.62 - 1, "T", "t")
    g:ellipse(cx, topY, rx * 0.28, ry * 0.3, "t", "T")
    g:rect(math.floor(cx), topY, math.floor(rx * 0.7), 1, "b", "Tt")
    g:ellipse(cx - rx * 0.6, topY - ry * 0.35, 5, 3, "M", "Tt")
    g:ellipse(cx - rx * 0.85, topY + 3, 3, 4, "M", "Bb")
    g:sprinkle("L", 0.35, "M")
    return g:toGrid()
end

local function cloud(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local base = h - 3
    local j = function(v) return v * (0.9 + g:rand() * 0.2) end
    g:circle(j(w * 0.52), base - h * 0.42, h * 0.46, "W")
    g:circle(j(w * 0.30), base - h * 0.28, h * 0.34, "W")
    g:circle(j(w * 0.74), base - h * 0.30, h * 0.36, "W")
    g:circle(w * 0.13, base - h * 0.12, h * 0.22, "W")
    g:circle(w * 0.88, base - h * 0.14, h * 0.22, "W")
    g:ellipse(w / 2, base - 2, w * 0.49, 3, "W")
    g:rect(0, base + 1, w, h - base - 1, ".")
    g:edge("W", "S", 0, 1)
    g:edge("W", "S", 0, 2)
    return g:toGrid()
end

local function blob(w, h, seed, ch)
    local g = PixGen.new(w, h, seed)
    g:ellipse(w / 2, h / 2, w * 0.36, h * 0.34, ch)
    for _ = 1, 4 do
        g:ellipse(w * (0.25 + g:rand() * 0.5), h * (0.3 + g:rand() * 0.4), w * (0.12 + g:rand() * 0.14), h * (0.15 + g:rand() * 0.15), ch)
    end
    return g:toGrid()
end

local function slab(seed)
    local g = PixGen.new(15, 15, seed)
    g:rect(0, 0, 15, 15, "S")
    g:rect(0, 0, 15, 1, "L")
    g:rect(0, 0, 1, 15, "L")
    g:rect(0, 14, 15, 1, "D")
    g:rect(14, 1, 1, 14, "D")
    g:sprinkle("s", 0.06, "S")
    if g:rand() < 0.5 then
        local x, y = 3 + math.floor(g:rand() * 7), 3 + math.floor(g:rand() * 7)
        g:set(x, y, "D"); g:set(x + 1, y + 1, "D"); g:set(x + 1, y + 2, "D")
    end
    if g:rand() < 0.45 then
        g:ellipse(g:rand() < 0.5 and 2 or 12, g:rand() < 0.5 and 2 or 12, 3, 2, "M", "SsLD")
    end
    return g:toGrid()
end

local function cliff(seed)
    local g = PixGen.new(16, 30, seed)
    g:rect(0, 0, 16, 9, "d")
    g:rect(0, 9, 16, 16, "r")
    g:rect(0, 9, 16, 1, "k")
    for x = 0, 15 do
        local bottom = 24 + math.floor(g:rand() * 5)
        g:rect(x, 25, 1, bottom - 25, "r")
    end
    g:sprinkle("D", 0.12, "d")
    g:sprinkle("R", 0.10, "r")
    for y = 12, 22, 5 do
        local x0 = math.floor(g:rand() * 8)
        g:rect(x0, y, 5 + math.floor(g:rand() * 6), 1, "h", "rR")
        g:rect(x0 + 1, y + 1, 4, 1, "R", "rR")
    end
    g:edge("rR", "R", 0, 1)
    g:edge("rRh", "k", 0, 1)
    for x = 0, 15, 3 do
        if g:rand() < 0.4 then g:rect(x, 0, 1, 1 + math.floor(g:rand() * 3), "G", "dD") end
    end
    return g:toGrid()
end

local function gateArch()
    local W, H = 80, 58
    local g = PixGen.new(W, H, 77)
    g:ellipse(40, 30, 38, 30, "S")
    g:rect(2, 30, 18, 28, "S")
    g:rect(60, 30, 18, 28, "S")
    g:ellipse(40, 30, 22, 20, ".")
    g:rect(18, 30, 44, 28, ".")
    g:rect(0, 50, 22, 8, "B")
    g:rect(58, 50, 22, 8, "B")
    for y = 34, 48, 7 do
        g:rect(2, y, 18, 1, "j", "S")
        g:rect(60, y, 18, 1, "j", "S")
    end
    g:rect(10, 38, 1, 6, "j", "S"); g:rect(68, 41, 1, 6, "j", "S")
    g:edge("S", "L", -1, 0)
    g:edge("S", "L", 0, -1)
    g:edge("S", "D", 1, 0)
    g:rect(34, 0, 12, 12, "K")
    g:rect(34, 0, 12, 1, "L")
    g:rect(38, 3, 4, 5, "g")
    g:rect(38, 3, 2, 2, "G")
    g:circle(12, 14, 5, "V")
    g:circle(7, 22, 4, "V")
    g:circle(70, 16, 4, "V")
    g:circle(5, 34, 3, "V")
    g:circle(75, 30, 3, "V")
    g:sprinkle("v", 0.3, "V")
    g:rect(19, 40, 1, 8, "V", ".")
    g:rect(60, 38, 1, 10, "V", ".")
    return g:toGrid()
end

local function gateBars(frame)
    local W, H = 44, 48
    local g = PixGen.new(W, H, 5)
    g:ellipse(22, 20, 22, 20, "P")
    g:rect(0, 20, 44, 28, "P")
    for x = 5, 40, 7 do g:rect(x, 0, 1, 48, "p", "P") end
    g:rect(0, 16, 44, 3, "I", "Pp")
    g:rect(0, 36, 44, 3, "I", "Pp")
    g:circle(22, 27, 7, "r")
    g:circle(22, 27, 5, frame == 1 and "R" or "Y")
    g:circle(22, 27, 2, "W")
    return g:toGrid()
end

local function portal(frame)
    local W, H = 44, 48
    local g = PixGen.new(W, H, 9)
    g:ellipse(22, 20, 22, 20, "a")
    g:rect(0, 20, 44, 28, "a")
    local ph = frame * 2.1
    for i = 1, 6 do
        local rx = 22 - i * 3.2
        local ry = 20 - i * 2.8
        if rx > 1 and ry > 1 then
            g:ellipse(22 + math.cos(ph + i) * 1.5, 28 + math.sin(ph + i) * 1.2, rx, ry, (i % 2 == 0) and "b" or "c", "abc")
        end
    end
    g:ellipse(22, 29, 4, 5, "W", "abc")
    return g:toGrid()
end

-- Arbre complet (tronc + feuillage) pour les murs d'arbres : ancré au pied du tronc
local function tallTree(w, h, seed)
    local crown = canopy(w, h, seed)
    local trunkH = 12
    local g = PixGen.new(w, h + trunkH - 6, seed)
    local tx = math.floor(w / 2) - 3
    g:rect(tx, h - 10, 6, trunkH + 4, "K")
    g:rect(tx + 4, h - 10, 2, trunkH + 4, "k")
    g:rect(tx - 2, h + trunkH - 8, 10, 2, "K")
    for y, line in ipairs(crown) do
        for x = 1, #line do
            local ch = line:sub(x, x)
            if ch ~= "." then g:set(x - 1, y - 1, ch) end
        end
    end
    return g:toGrid()
end

-- Face avant texturée de la haie (tuile horizontale)
local function hedgeFront(seed)
    local g = PixGen.new(16, 16, seed)
    g:rect(0, 0, 16, 16, "D")
    for _ = 1, 5 do
        g:circle(g:rand() * 16, g:rand() * 12, 2 + g:rand() * 2, "M")
    end
    g:sprinkle("L", 0.08, "M")
    g:rect(0, 12, 16, 4, "d")
    g:sprinkle("D", 0.25, "d")
    g:rect(0, 15, 16, 1, "k")
    return g:toGrid()
end

-- Île flottante lointaine (silhouette atmosphérique)
local function farIsland(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local top = math.floor(h * 0.3)
    g:ellipse(w / 2, top, w * 0.48, h * 0.16, "g")
    for y = top, h - 1 do
        local t = (y - top) / (h - top)
        local half = (w * 0.46) * (1 - t) ^ 1.3
        local jitter = g:rand() * 2
        g:rect(math.floor(w / 2 - half + jitter), y, math.max(1, math.floor(half * 2 - jitter)), 1, "r")
    end
    g:ellipse(w / 2, top - 2, w * 0.3, h * 0.14, "G")
    g:edge("r", "R", 1, 0)
    return g:toGrid()
end

local SPIKE_FULL = { ".H.", ".H.", "HHM", "HMM", "HMM" }
local SPIKE_TIP = { ".H.", "HMM" }

local function spikes(extent)
    local g = PixGen.new(14, 14, 3)
    local src = (extent == 2) and SPIKE_FULL or SPIKE_TIP
    local spots = { { 2, 1 }, { 9, 1 }, { 2, 8 }, { 9, 8 } }
    for _, p in ipairs(spots) do
        local oy = p[2] + (5 - #src)
        for ry, line in ipairs(src) do
            for rx = 1, #line do
                local ch = line:sub(rx, rx)
                if ch ~= "." then g:set(p[1] + rx - 1, oy + ry - 1, ch) end
            end
        end
    end
    return g:toGrid()
end

-- ---------------------------------------------------------------------------
-- Sprites dessinés à la main
-- ---------------------------------------------------------------------------
local POT = {
    "..PPPPP..",
    ".PpppppP.",
    "PPPPPPPPP",
    ".PPPPPPP.",
    "PPPPPPPPP",
    "PpPPPPPPP",
    "PPPYYYPPP",
    "PPPYYYPPP",
    "PPPPPPPPP",
    ".PPPPPPP.",
    ".pPPPPPp.",
    "..ppppp..",
}

local POT_BROKEN = {
    ".p.....p..",
    "pp..p..pp.",
    "ppppppppp.",
    ".ppPppPp..",
    "..ppp.p...",
}

local function cactus(seed)
    local g = PixGen.new(20, 30, seed)
    g:rect(8, 4, 5, 26, "M")
    g:ellipse(10, 5, 2.5, 3, "M")
    g:rect(3, 12, 4, 2, "M"); g:rect(3, 8, 2, 6, "M"); g:ellipse(4, 8, 1.6, 2, "M")
    g:rect(13, 17, 4, 2, "M"); g:rect(15, 12, 2, 7, "M"); g:ellipse(16, 12, 1.6, 2, "M")
    g:edge("M", "D", 1, 0)
    g:sprinkle("L", 0.10, "M")
    for y = 6, 28, 4 do g:set(8, y, "S"); g:set(12, y + 2, "S") end
    g:ellipse(10, 29, 6, 2, "d")
    return g:toGrid()
end

local function crystalSpire(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local cx = w / 2
    for i = 0, h - 1 do
        local t = i / (h - 1)
        local half = (w * 0.42) * (t ^ 0.7)
        g:rect(math.floor(cx - half), i, math.max(1, math.floor(half * 2)), 1, "C")
    end
    g:rect(math.floor(cx), 2, 1, h - 4, "L", "C")
    g:edge("C", "D", 1, 0)
    g:ellipse(cx - w * 0.28, h * 0.62, w * 0.16, h * 0.22, "c", "C")
    g:ellipse(cx + w * 0.3, h * 0.72, w * 0.13, h * 0.16, "c", "C")
    g:ellipse(cx, h - 1, w * 0.45, 2, "d")
    return g:toGrid()
end

local BONES = {
    "..B...B..",
    ".BBB.BBB.",
    "..B...B..",
    "..BBBBB..",
    "..B...B..",
    ".BBB.BBB.",
}

local LAVA_CRACK = {
    "...LLL....",
    "..LFFFL...",
    ".LFFFFFL..",
    "..LFFFFL..",
    "...LFFL...",
    "....LL....",
}

local ICE_PATCH = {
    "..IIIIII..",
    ".IIiiiiII.",
    "IIiiWWiiII",
    "IiiWWWWiiI",
    "IIiiWWiiII",
    ".IIiiiiII.",
    "..IIIIII..",
}

local BARREL = {
    "..RRRRRR..",
    ".RRRRRRRR.",
    "IIIIIIIIII",
    "RrRRRRRRrR",
    "RrRRRRRRrR",
    "YYYYYYYYYY",
    "YYkYYYYkYY",
    "YYYYkkYYYY",
    "YYYYYYYYYY",
    "RrRRRRRRrR",
    "IIIIIIIIII",
    "RrRRRRRRrR",
    ".RRRRRRRR.",
    "..rrrrrr..",
}

local CRATER = {
    "..kkkkkkkk..",
    ".kddddddddk.",
    "kdddkkddkddk",
    "kddkkddddddk",
    ".kddddddddk.",
    "..kkkkkkkk..",
}

local TUFT_A = { "..l..", "l.d.l", "d.d.d", ".ddd." }
local TUFT_B = { ".l....", ".d..l.", "ld..d.", "dd.dd." }
local TUFT_C = { "l...", "d.l.", "dd.d" }
local FLOWERS_W = { ".w.....", "wyw..w.", ".w..wyw", ".....w." }
local FLOWERS_Y = { ".y....", "yoy.y.", ".y.yoy", "....y." }
local FLOWERS_P = { "..p....", ".pwp...", "..p..p.", ".....pw", "......p" }
local PEBBLES = { ".ss..", "sSs..", "..ss.", "..sS." }
local MUSHROOM = { ".RRR.", "RwRRR", "..s..", "..s.." }
local LILY = { "..GGGGG.", ".GGGLGGG", "GGGLG.GG", "GGGGGG..", ".GGGGGG." }
local LILY_FLOWER = { "..GGGGG.", ".GGpwpGG", "GGGpppGG", "GGGGGG..", ".GGGGGG." }
local REEDS = { ".b...", ".b..b", "Rb..b", "R.RRb", "R.R.R", "RRR.R", ".RRRR" }
local ROOT = { "b.", "b.", ".b", ".b", "b.", "b." }
local RIPPLE = { ".WWW.", "W...W" }

function Props.define(atlas)
    local function d(name, frames, pal, outline, anchor, shade, variants)
        atlas:define(name, {
            frames = frames, palette = pal, outline = outline,
            anchor = anchor or "center", shade = shade, variants = variants,
        })
    end
    local THEME_WALL = {
        sand    = { D = "8a6437", M = "b98f5c", L = "d6ac72", W = "e4c48c" },
        crystal = { D = "2c3459", M = "4a5488", L = "6f7cb8", W = "2ce8f5" },
        lava    = { D = "241c1c", M = "3d3030", L = "5a4444", W = "f77622" },
        sky     = { D = "5a6988", M = "8b9bb4", L = "c0cbdc", W = "2ce8f5" },
        void    = { D = "18102a", M = "2a1f3d", L = "4a3566", W = "b06ce0" },
    }
    local THEME_TREE = {
        sand    = { D = "8a6437", M = "b98f5c", L = "d6ac72", W = "e4c48c", K = "7a5a32", k = "4a3720" },
        crystal = { D = "2c3459", M = "4a5488", L = "6f7cb8", W = "2ce8f5", K = "323a63", k = "1b2038" },
        lava    = { D = "241c1c", M = "3d3030", L = "5a4444", W = "f77622", K = "332828", k = "140f0f" },
        sky     = { D = "5a6988", M = "8b9bb4", L = "c0cbdc", W = "2ce8f5", K = "6d7c96", k = "3a4466" },
        void    = { D = "18102a", M = "2a1f3d", L = "4a3566", W = "b06ce0", K = "231838", k = "0f0a18" },
    }
    local THEME_FRONT = {
        sand    = { D = "8a6437", M = "9a7442", L = "b98f5c", d = "6b4b28", k = "4a3720" },
        crystal = { D = "2c3459", M = "3a4470", L = "4a5488", d = "1b2038", k = "12172a" },
        lava    = { D = "241c1c", M = "332828", L = "4a3b3b", d = "140f0f", k = "0c0808" },
        sky     = { D = "5a6988", M = "6d7c96", L = "8b9bb4", d = "46536b", k = "323c50" },
        void    = { D = "18102a", M = "231838", L = "3d2c57", d = "120c1f", k = "0a0714" },
    }
    local VOL = { depth = 5, strength = 1.0 }
    local SOFT = { depth = 5, strength = 0.55 }

    local TREE_PAL = { D = "265c42", M = "3e8948", L = "63c74d", W = "a2dc6e", K = "733e39", k = "3e2731" }
    d("tall_tree_a", { tallTree(34, 30, 11) }, TREE_PAL, FOLIAGE_INK, "bottom", VOL, THEME_TREE)
    d("tall_tree_b", { tallTree(28, 26, 29) }, TREE_PAL, FOLIAGE_INK, "bottom", VOL, THEME_TREE)
    d("hedge_front", { hedgeFront(3), hedgeFront(8) }, { D = "265c42", M = "2f7045", L = "3e8948", d = "193c3e", k = "0f2a2b" }, nil, "topleft", nil, THEME_FRONT)
    -- Îles flottantes du fond : recolorées par biome (plus de verdure dans le Vide)
    local THEME_ISLAND = {
        sand    = { g = "d6ac72", G = "e4c48c", r = "b98f5c", R = "8a6437" },
        crystal = { g = "6f7cb8", G = "8fa0d6", r = "4a5488", R = "323a63" },
        lava    = { g = "a2432a", G = "d64a11", r = "5a4444", R = "3a2e2e" },
        sky     = { g = "c0cbdc", G = "e8f0ff", r = "9fb2cc", R = "7d8ca6" },
        void    = { g = "4a3566", G = "7a3ea8", r = "2a1f3d", R = "18102a" },
    }
    d("far_island_a", { farIsland(46, 30, 4) }, { g = "9fcfb0", G = "b6e0c2", r = "8fa9cc", R = "7b93b8" }, nil, "center", nil, THEME_ISLAND)
    d("far_island_b", { farIsland(28, 20, 9) }, { g = "9fcfb0", G = "b6e0c2", r = "8fa9cc", R = "7b93b8" }, nil, "center", nil, THEME_ISLAND)
    d("px", { { "W" } }, { W = "ffffff" }, nil, "topleft")
    d("tree_a", { canopy(34, 30, 11) }, FOLIAGE, FOLIAGE_INK, nil, VOL)
    d("tree_b", { canopy(28, 26, 29) }, FOLIAGE, FOLIAGE_INK, nil, VOL)
    d("bush_a", { canopy(20, 16, 41) }, FOLIAGE, FOLIAGE_INK, nil, VOL, THEME_WALL)
    d("bush_b", { canopy(16, 14, 53) }, FOLIAGE, FOLIAGE_INK, nil, VOL, THEME_WALL)

    local stumpPal = { B = "733e39", b = "3e2731", T = "e4a672", t = "b86f50", M = "3e8948", L = "63c74d" }
    -- Souches : recolorées par biome (la mousse verte n'a rien à faire dans le Vide)
    local THEME_STUMP = {
        sand    = { B = "8a6437", b = "4a3720", T = "e4c48c", t = "c09a63", M = "b98f5c", L = "d6ac72" },
        crystal = { B = "2c3459", b = "12172a", T = "8fa0d6", t = "4a5488", M = "323a63", L = "2ce8f5" },
        lava    = { B = "4a2a20", b = "1c1010", T = "f77622", t = "a2432a", M = "6b3a24", L = "fee761" },
        sky     = { B = "6d7c96", b = "3a4466", T = "e8f0ff", t = "a9b6ca", M = "8b9bb4", L = "2ce8f5" },
        void    = { B = "2a1f3d", b = "0f0a18", T = "5c4580", t = "3d2c57", M = "231838", L = "b06ce0" },
    }
    d("stump_s", { stump(30, 28, 3) }, stumpPal, "181425", nil, VOL, THEME_STUMP)
    d("stump_l", { stump(40, 38, 8) }, stumpPal, "181425", nil, VOL, THEME_STUMP)

    local cloudPal = { W = "ffffff", S = "c7e3f5" }
    d("cloud_a", { cloud(52, 20, 12) }, cloudPal, nil, nil, SOFT)
    d("cloud_b", { cloud(38, 16, 31) }, cloudPal, nil, nil, SOFT)
    d("cloud_c", { cloud(70, 24, 45) }, cloudPal, nil, nil, SOFT)

    d("patch_light", { blob(30, 16, 5, "P") }, { P = "5dac4d" }, nil, nil, nil,
        { sand = { P = "e4c48c" }, crystal = { P = "4d5a90" }, lava = { P = "5c4747" },
          sky = { P = "c0cbdc" }, void = { P = "3d2c57" } })
    d("patch_dark", { blob(34, 18, 17, "P") }, { P = "438a3e" }, nil, nil, nil,
        { sand = { P = "c09a63" }, crystal = { P = "323a63" }, lava = { P = "3a2e2e" },
          sky = { P = "8b9bb4" }, void = { P = "2a1f3d" } })
    d("patch_dirt", { blob(26, 14, 23, "P") }, { P = "8a6a45" }, nil, nil, nil,
        { sand = { P = "b98f5c" }, crystal = { P = "2c3459" }, lava = { P = "6b3a24" },
          sky = { P = "9fb2cc" }, void = { P = "4a3566" } })

    local grassPal = { d = "356f39", l = "74c05a" }
    d("tuft_a", { TUFT_A }, grassPal, nil, "bottom")
    d("tuft_b", { TUFT_B }, grassPal, nil, "bottom")
    d("tuft_c", { TUFT_C }, grassPal, nil, "bottom")
    d("flowers_w", { FLOWERS_W }, { w = "ffffff", y = "feae34" }, nil)
    d("flowers_y", { FLOWERS_Y }, { y = "fee761", o = "f77622" }, nil)
    d("flowers_p", { FLOWERS_P }, { p = "f6757a", w = "ffffff" }, nil)
    d("pebbles", { PEBBLES }, { s = "8b9bb4", S = "c0cbdc" }, nil)
    d("mushroom", { MUSHROOM }, { R = "e43b44", w = "ffffff", s = "ead4aa" }, "181425", "bottom", VOL)

    local slabPal = { S = "8b9bb4", s = "7d8ca6", L = "a9b6ca", D = "5a6988", M = "3e8948" }
    d("slab", { slab(1), slab(2), slab(3), slab(4) }, slabPal, nil, "topleft", nil, {
        sand    = { S = "c9a06a", s = "b98f5c", L = "e4c48c", D = "8a6437", M = "9a7a3a" },
        crystal = { S = "5c6a9e", s = "4e5a88", L = "8fa0d6", D = "323a63", M = "2ce8f5" },
        lava    = { S = "4a3b3b", s = "3d3030", L = "6b5450", D = "241c1c", M = "f77622" },
        sky     = { S = "c0cbdc", s = "a9b6ca", L = "e8f0ff", D = "8b9bb4", M = "2ce8f5" },
        void    = { S = "3d2c57", s = "2a1f3d", L = "5c4580", D = "18102a", M = "b06ce0" },
    })

    local cliffPal = { d = "9a6a48", D = "7a4f38", r = "5a6988", R = "3a4466", h = "8b9bb4", k = "262b44", G = "3e8948" }
    d("cliff", { cliff(1), cliff(2), cliff(3), cliff(4) }, cliffPal, nil, "topleft", nil, {
        sand    = { d = "d6ac72", D = "b98f5c", r = "c9a06a", R = "9a7442", h = "e4c48c", k = "6b4b28", G = "c0954f" },
        crystal = { d = "3f4a7a", D = "2c3459", r = "4a5488", R = "323a63", h = "8fa0d6", k = "1b2038", G = "2ce8f5" },
        lava    = { d = "4a3b3b", D = "332828", r = "3d3030", R = "241c1c", h = "6b5450", k = "140f0f", G = "f77622" },
        sky     = { d = "a9b6ca", D = "8b9bb4", r = "c0cbdc", R = "7d8ca6", h = "e8f0ff", k = "5a6988", G = "2ce8f5" },
        void    = { d = "3d2c57", D = "2a1f3d", r = "4a3566", R = "231838", h = "5c4580", k = "0f0a18", G = "b06ce0" },
    })
    d("root", { ROOT }, { b = "3e2731" }, nil, "topleft")

    d("gate_arch", { gateArch() }, {
        S = "8b9bb4", L = "c0cbdc", D = "5a6988", j = "5a6988", B = "5a6988",
        K = "c0cbdc", g = "0099db", G = "2ce8f5", V = "3e8948", v = "63c74d",
    }, "262b44", { 40, 57 }, { depth = 4, strength = 0.8 })
    d("gate_bars", { gateBars(1), gateBars(2) }, {
        P = "733e39", p = "3e2731", I = "5a6988", r = "3e2731", R = "e43b44", Y = "f77622", W = "fee761",
    }, "262b44", { 22, 47 })
    d("portal", { portal(1), portal(2), portal(3) }, {
        a = "193c3e", b = "2ce8f5", c = "0099db", W = "ffffff",
    }, nil, { 22, 47 })

    d("spikes_up", { spikes(2) }, { M = "c0cbdc", H = "ffffff" }, "181425", "topleft")
    d("spikes_mid", { spikes(1) }, { M = "8b9bb4", H = "c0cbdc" }, "181425", "topleft")

    d("pot", { POT }, { P = "b86f50", p = "733e39", Y = "ead4aa" }, "181425", "bottom", VOL)
    d("pot_broken", { POT_BROKEN }, { P = "b86f50", p = "733e39" }, "181425", "bottom")
    d("cactus", { cactus(3), cactus(17) }, { M = "3e8948", D = "265c42", L = "63c74d", S = "ead4aa", d = "9a7442" }, "181425", "bottom", VOL)
    d("crystal_spire", { crystalSpire(18, 30, 5), crystalSpire(14, 22, 9) }, { C = "0099db", L = "2ce8f5", D = "124e89", c = "b55088", d = "262b44" }, "181425", "bottom", VOL)
    d("bones", { BONES }, { B = "ead4aa" }, "3e2731", "center")
    d("lava_crack", { LAVA_CRACK }, { L = "f77622", F = "fee761" }, nil, "center")
    d("ice_patch", { ICE_PATCH }, { I = "0099db", i = "2ce8f5", W = "ffffff" }, nil, "center")
    d("barrel", { BARREL }, { R = "e43b44", r = "a22633", I = "8b9bb4", Y = "fee761", k = "3e2731" }, "181425", "bottom", VOL)
    d("barrel_crater", { CRATER }, { k = "3e2731", d = "5a3a2a" }, nil, "center")
    d("lily", { LILY, LILY_FLOWER }, { G = "63c74d", L = "3e8948", p = "f6757a", w = "ffffff" }, "193c3e")
    d("reeds", { REEDS }, { R = "3e8948", b = "733e39" }, nil, "bottom")
    d("ripple", { RIPPLE }, { W = "ffffff" }, nil)
end

return Props
