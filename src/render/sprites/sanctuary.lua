-- src/render/sprites/sanctuary.lua
-- Décor des sanctuaires : colonne de marbre et banc de nuages (Ange), flèche d'obsidienne
-- (Démon), autels, brasero animé, nuage dérivant et détails au sol (plume, éclat, volute de
-- nuage, crâne, pierre à braise). Formes générées par PixGen (déterministe).

local PixGen = require("src.render.sprites.pixgen")

local Sanctuary = {}

local INK = "181425"
local VOL = { depth = 5, strength = 1.0 }

-- Colonne de marbre : fût cannelé, chapiteau et base dorés
local function marbleColumn(w, h)
    local g = PixGen.new(w, h, 7)
    g:rect(2, 5, w - 4, h - 10, "M")
    for x = 3, w - 4, 3 do g:rect(x, 6, 1, h - 12, "m", "M") end
    g:edge("M", "s", 1, 0)
    g:rect(1, 0, w - 2, 4, "G")
    g:rect(0, 3, w, 2, "G")
    g:rect(1, 0, w - 2, 1, "Y", "G")
    g:rect(0, h - 5, w, 2, "G")
    g:rect(1, h - 3, w - 2, 3, "g")
    return g:toGrid()
end

-- Banc de nuages posé au sol (bords du sanctuaire de l'Ange)
local function cloudBank(w, h, seed)
    local g = PixGen.new(w, h, seed)
    g:ellipse(w * 0.5, h * 0.62, w * 0.48, h * 0.38, "C")
    g:circle(w * 0.3, h * 0.48, h * 0.34, "C")
    g:circle(w * 0.62, h * 0.4, h * 0.4, "C")
    g:edge("C", "c", 0, 1)
    g:ellipse(w * 0.55, h * 0.3, w * 0.18, h * 0.14, "W", "C")
    return g:toGrid()
end

-- Flèche d'obsidienne à runes rouges (bords de l'antre du Démon)
local function obsidianSpire(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local cx = w / 2
    for i = 0, h - 1 do
        local t = i / (h - 1)
        local half = (w * 0.46) * (t ^ 0.6)
        g:rect(math.floor(cx - half), i, math.max(1, math.floor(half * 2)), 1, "O")
    end
    g:edge("O", "o", 1, 0)
    g:rect(math.floor(cx) - 1, 4, 1, h - 8, "L", "O")
    for k = 0, 2 do
        local y = math.floor(h * (0.35 + k * 0.18))
        g:rect(math.floor(cx) - 1, y, 3, 1, "R", "Oo")
        g:rect(math.floor(cx), y - 1, 1, 1, "R", "Oo")
    end
    g:ellipse(cx, h - 1, w * 0.48, 2, "d")
    return g:toGrid()
end

-- Autel rond vu de trois quarts : socle, bord, plateau et anneau intérieur
local function altar(w, h, rim, inner, mark)
    local g = PixGen.new(w, h, 3)
    local cx, cy = w / 2, h / 2
    g:ellipse(cx, cy + 2, w * 0.49, h * 0.46, "S")
    g:ellipse(cx, cy, w * 0.49, h * 0.42, rim)
    g:ellipse(cx, cy, w * 0.43, h * 0.34, inner)
    g:ellipse(cx, cy, w * 0.30, h * 0.22, mark, inner)
    g:ellipse(cx, cy, w * 0.27, h * 0.18, inner, mark)
    return g:toGrid()
end

-- Brasero mural : flamme oscillante (3 images) au-dessus d'une coupe de fer
local function brazier(frame)
    local g = PixGen.new(14, 26, 11 + frame)
    local sway = ({ 0, 1, -1 })[frame]
    g:ellipse(7 + sway * 0.5, 8, 4.5, 5, "F")
    g:ellipse(7 + sway, 5, 3, 4.5, "F")
    g:ellipse(7 + sway, 8, 3, 3.5, "Y", "F")
    g:ellipse(7 + sway * 0.5, 9, 1.5, 2, "W", "Y")
    g:rect(7 + sway * 2, 1, 1, 1, "F")
    g:rect(1, 12, 12, 3, "i")
    g:ellipse(7, 15, 6, 3, "I")
    g:rect(6, 16, 2, 8, "I")
    g:rect(4, 24, 6, 2, "I")
    g:edge("I", "k", 1, 0)
    return g:toGrid()
end

-- Petit nuage qui dérive au-dessus du sanctuaire de l'Ange
local function cloudPuff(w, h, seed)
    local g = PixGen.new(w, h, seed)
    g:ellipse(w * 0.5, h * 0.6, w * 0.48, h * 0.38, "C")
    g:circle(w * 0.36, h * 0.45, h * 0.36, "C")
    g:circle(w * 0.62, h * 0.4, h * 0.42, "C")
    g:edge("C", "c", 0, 1)
    return g:toGrid()
end

local FEATHER = {
    "......w",
    "....wW.",
    "..wwW..",
    ".wWw...",
    "g......",
}
local SPARKLE = {
    "..y..",
    "..Y..",
    "yYWYy",
    "..Y..",
    "..y..",
}
local CLOUD_WISP = {
    "...cccc.....",
    ".ccCCCCcc...",
    "cCCCCCCCCccc",
    ".cccccccc...",
}
local SKULL = {
    ".BBBBB.",
    "BBBBBBB",
    "BkBBBkB",
    "BBBkBBB",
    ".BBBBB.",
    ".B.B.B.",
}
local EMBER_ROCK = {
    "..RRR..",
    ".RFFRR.",
    "RRFYFRR",
    ".RRFRR.",
    "..RRR..",
}

function Sanctuary.define(atlas)
    local function d(name, frames, pal, outline, anchor, shade)
        atlas:define(name, {
            frames = frames, palette = pal, outline = outline,
            anchor = anchor or "center", shade = shade,
        })
    end
    local MARBLE = { M = "e8ecf4", m = "c3cad8", s = "9aa3b8", G = "e0a83a", g = "b07a26", Y = "fee761" }
    d("marble_column", { marbleColumn(14, 44) }, MARBLE, "5a6988", "bottom", VOL)
    d("cloud_bank", { cloudBank(30, 18, 5), cloudBank(26, 16, 9) },
        { C = "f4f8ff", c = "b9c6dc", W = "ffffff" }, "9fb2cc", "bottom")
    d("obsidian_spire", { obsidianSpire(16, 44, 4), obsidianSpire(12, 34, 8) },
        { O = "2a2030", o = "16101c", L = "5a4a6a", R = "e43b44", d = "0c0808" }, INK, "bottom", VOL)
    d("altar_angel", { altar(56, 28, "G", "M", "Y") },
        { S = "9aa3b8", G = "e0a83a", M = "e8ecf4", Y = "fee761" }, "5a6988", "center")
    d("altar_devil", { altar(56, 28, "R", "O", "F") },
        { S = "0c0808", R = "a82814", O = "2a2030", F = "f77622" }, INK, "center")
    d("brazier", { brazier(1), brazier(2), brazier(3) },
        { I = "3a3a4a", i = "5a5a6e", k = "1c1c26", F = "e43b44", Y = "f77622", W = "fee761" }, INK, "bottom")
    d("cloud_puff", { cloudPuff(24, 11, 3), cloudPuff(18, 9, 12) }, { C = "ffffff", c = "dfe8f5" }, nil, "center")
    d("feather", { FEATHER }, { w = "f4f8ff", W = "c3cad8", g = "9aa3b8" }, nil, "center")
    d("sparkle", { SPARKLE }, { y = "e0a83a", Y = "fee761", W = "ffffff" }, nil, "center")
    d("cloud_wisp", { CLOUD_WISP }, { c = "c3cad8", C = "f4f8ff" }, nil, "center")
    d("skull", { SKULL }, { B = "d9c8a8", k = "1c1010" }, "3e2731", "center")
    d("ember_rock", { EMBER_ROCK }, { R = "3a2424", F = "f77622", Y = "fee761" }, nil, "center")
end

return Sanctuary
