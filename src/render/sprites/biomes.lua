-- src/render/sprites/biomes.lua
-- World-specific scenery: the single-cell obstacle of each world (cactus, ice spike,
-- obsidian rock, floating stone, void monolith; same 40 px footprint as the forest stump)
-- and extra ground details baked into each world's ground tiles.

local PixGen = require("src.render.sprites.pixgen")

local Biomes = {}

local INK = "181425"
local VOL = { depth = 5, strength = 1.0 }
local SIZE = 40

-- Desert: saguaro cactus with two arms on a sand mound
local function cactus()
    local g = PixGen.new(SIZE, SIZE, 21)
    g:ellipse(20, 35, 17, 5, "S")
    g:rect(16, 6, 8, 30, "G")
    g:ellipse(20, 6, 4, 4, "G")
    g:rect(6, 14, 4, 12, "G")
    g:ellipse(8, 14, 2, 2, "G")
    g:rect(6, 24, 10, 4, "G")
    g:rect(30, 10, 4, 12, "G")
    g:ellipse(32, 10, 2, 2, "G")
    g:rect(24, 20, 8, 4, "G")
    g:edge("G", "g", 1, 0)
    g:rect(18, 7, 1, 27, "L", "G")
    g:sprinkle("s", 0.08, "G")
    g:edge("S", "d", 0, 1)
    return g:toGrid()
end

-- Crystal: cluster of three ice shards
local function iceSpike()
    local g = PixGen.new(SIZE, SIZE, 33)
    local function shard(cx, top, half)
        for y = top, 36 do
            local w = math.floor(half * (y - top) / (36 - top)) + 1
            g:rect(cx - math.floor(w / 2), y, w, 1, "I")
        end
    end
    shard(13, 12, 9)
    shard(27, 10, 9)
    shard(20, 2, 12)
    g:edge("I", "i", 1, 0)
    g:rect(19, 6, 1, 26, "W", "I")
    g:rect(12, 16, 1, 16, "W", "I")
    g:ellipse(20, 37, 17, 3, "d")
    return g:toGrid()
end

-- Volcano: jagged obsidian rock with glowing veins
local function obsidianRock()
    local g = PixGen.new(SIZE, SIZE, 47)
    g:ellipse(20, 26, 17, 12, "O")
    g:ellipse(14, 17, 8, 10, "O")
    g:ellipse(27, 15, 7, 11, "O")
    g:edge("O", "o", 1, 0)
    g:edge("O", "o", 0, 1)
    g:ellipse(16, 13, 3, 4, "L", "O")
    g:rect(12, 24, 9, 1, "R", "O")
    g:rect(20, 25, 1, 6, "R", "O")
    g:rect(24, 18, 1, 6, "R", "O")
    g:rect(21, 28, 6, 1, "F", "R")
    g:ellipse(20, 37, 17, 3, "d")
    return g:toGrid()
end

-- Sky: small floating stone with grass on top and a shadow gap below
local function floatStone()
    local g = PixGen.new(SIZE, SIZE, 59)
    g:ellipse(20, 17, 17, 7, "T")
    for y = 18, 32 do
        local half = math.floor(15 * (1 - (y - 18) / 15))
        if half > 0 then g:rect(20 - half, y, half * 2, 1, "T") end
    end
    g:edge("T", "t", 1, 0)
    g:edge("T", "t", 0, 1)
    g:ellipse(20, 12, 16, 4, "M")
    g:ellipse(15, 11, 6, 2, "m", "M")
    g:ellipse(20, 38, 12, 2, "d")
    return g:toGrid()
end

-- Void: dark standing slab with a glowing purple eye
local function monolith()
    local g = PixGen.new(SIZE, SIZE, 71)
    g:rect(11, 4, 18, 32, "V")
    g:ellipse(20, 5, 9, 3, "V")
    g:edge("V", "v", 1, 0)
    g:rect(12, 6, 1, 28, "L", "V")
    g:ellipse(20, 17, 6, 4, "E", "Vv")
    g:ellipse(20, 17, 3, 3, "P", "E")
    g:ellipse(20, 17, 1, 1, "W", "P")
    g:ellipse(20, 37, 15, 3, "d")
    return g:toGrid()
end

local DRY_GRASS = {
    "y...y.",
    ".y.y..",
    "..yy.y",
    ".yyyy.",
}
local CRYSTAL_SHARD = {
    "..C..",
    ".CW..",
    ".CCc.",
    "cCCc.",
}
local FROST = {
    "w.....w",
    ".w.w.w.",
    "..wWw..",
    ".w.w.w.",
    "w.....w",
}
local ASH_PILE = {
    "..aaa..",
    ".aAaaa.",
    "aaAaAaa",
}
local CHARRED_TWIG = {
    "k......",
    ".kk..k.",
    "...kk..",
    "....kF.",
}
local VOID_DEBRIS = {
    ".v...v",
    "vVv...",
    ".v..vV",
    "....v.",
}
local RUNE_MARK = {
    ".p.p.",
    "ppPpp",
    ".p.p.",
    "..p..",
}
local VOID_GRASS = {
    "p...p.",
    ".p.p.p",
    "..pP..",
    ".pPPp.",
}

function Biomes.define(atlas)
    local function d(name, frames, pal, outline, anchor, shade)
        atlas:define(name, {
            frames = frames, palette = pal, outline = outline,
            anchor = anchor or "center", shade = shade, -- obstacles: centred like stump_l
        })
    end
    d("obstacle_cactus", { cactus() },
        { G = "3e8948", g = "265c42", L = "63c74d", s = "ead4aa", S = "e4c48c", d = "b98f5c" }, INK, nil, VOL)
    d("obstacle_ice", { iceSpike() },
        { I = "6fd0ff", i = "2f63c2", W = "ffffff", d = "323a63" }, "1b2038", nil, VOL)
    d("obstacle_obsidian", { obsidianRock() },
        { O = "2a2030", o = "16101c", L = "5a4a6a", R = "d64a11", F = "fee761", d = "140f0f" }, INK, nil, VOL)
    d("obstacle_floatstone", { floatStone() },
        { T = "a9b6ca", t = "6d7c96", M = "63c74d", m = "a2dc6e", d = "5a6988" }, "3a4466", nil, VOL)
    d("obstacle_monolith", { monolith() },
        { V = "2a1f3d", v = "140d24", L = "4a3566", E = "5c2a7a", P = "b06ce0", W = "ffffff", d = "0f0a18" },
        INK, nil, VOL)
    d("dry_grass", { DRY_GRASS }, { y = "c9a06a" }, nil, "bottom")
    d("crystal_shard", { CRYSTAL_SHARD }, { C = "6fd0ff", c = "2f63c2", W = "ffffff" }, nil, "bottom")
    d("frost", { FROST }, { w = "8fa0d6", W = "ffffff" }, nil, "center")
    d("ash_pile", { ASH_PILE }, { a = "4a3b3b", A = "6b5450" }, nil, "bottom")
    d("charred_twig", { CHARRED_TWIG }, { k = "1c1515", F = "f77622" }, nil, "center")
    d("void_debris", { VOID_DEBRIS }, { v = "36264d", V = "5c4580" }, nil, "center")
    d("rune_mark", { RUNE_MARK }, { p = "7a3ea8", P = "b06ce0" }, nil, "center")
    d("void_grass", { VOID_GRASS }, { p = "5c2a7a", P = "b06ce0" }, nil, "bottom")
end

return Biomes
