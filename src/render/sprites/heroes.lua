-- src/render/sprites/heroes.lua
-- Héros chibi (vue 3/4, tourné vers la droite ; miroir pour la gauche).
-- Corps et jambes séparés : le corps rebondit pendant la course, les jambes s'animent.
-- Chaque héros = variante de palette + accessoire de tête.

local Heroes = {}

local INK = "181425"

-- H capuche | L reflet capuche | h ombre capuche | S peau | s peau ombre | e yeux
-- T tunique | t tunique ombre | C cape | c cape ombre | B ceinture | b boucle
local BODY = {
    "....HHHHHH....",
    "..HHHHHHHHHH..",
    ".HHLLHHHHHHHH.",
    ".HLLHHHHHHHHHH",
    "HHHHHhhhhhhhHH",
    "HHHHhSSSSSSShH",
    "hHHHhSSSSSSSSh",
    "hHHhSSeSSSeSSh",
    "hhHhSSeSSSeSSh",
    ".hhhsSSSSSSSs.",
    "..cCChTTTTTT..",
    ".cCCTTTTTTTTt.",
    ".cCCtTBBbBBBt.",
    ".ccCtTTTTTTt..",
    "..cc.tTTTTt...",
}

local BODY_BLINK = {
    "....HHHHHH....",
    "..HHHHHHHHHH..",
    ".HHLLHHHHHHHH.",
    ".HLLHHHHHHHHHH",
    "HHHHHhhhhhhhHH",
    "HHHHhSSSSSSShH",
    "hHHHhSSSSSSSSh",
    "hHHhSSSSSSSSSh",
    "hhHhSSeSSSeSSh",
    ".hhhsSSSSSSSs.",
    "..cCChTTTTTT..",
    ".cCCTTTTTTTTt.",
    ".cCCtTBBbBBBt.",
    ".ccCtTTTTTTt..",
    "..cc.tTTTTt...",
}

-- P pantalon | K bottes
local LEGS = {
    idle = {
        "..PP..PP..",
        "..KK..KK..",
        ".KKK..KKK.",
    },
    run1 = {
        ".PP....PP.",
        "KK......KK",
        "KK.......K",
    },
    run2 = {
        "...PPPP...",
        "...KKKK...",
        "..KKKKK...",
    },
    run3 = {
        "..PP.PP...",
        ".KK...KK..",
        ".KK....KK.",
    },
}

local BASE_PALETTE = {
    H = "3e8948", L = "63c74d", h = "265c42",
    S = "e8b796", s = "c28569", e = INK,
    T = "b86f50", t = "733e39",
    C = "265c42", c = "193c3e",
    B = "3e2731", b = "feae34",
}

local LEG_PALETTE = { P = "3a4466", K = "733e39" }

-- Variantes par héros (clé = id du héros dans src/data/heroes.lua)
Heroes.VARIANTS = {
    urasil = { H = "68386c", L = "b55088", h = "3e2731", T = "262b44", t = "181425", C = "68386c", c = "3e2731", b = "63c74d" },
    phoren = { H = "e43b44", L = "f77622", h = "a22633", T = "3e2731", t = "181425", C = "a22633", c = "3e2731", b = "feae34" },
    helix  = { H = "b86f50", L = "e4a672", h = "733e39", T = "733e39", t = "3e2731", C = "be4a2f", c = "733e39", b = "c0cbdc" },
    rolla  = { H = "0099db", L = "2ce8f5", h = "124e89", T = "c0cbdc", t = "8b9bb4", C = "124e89", c = "262b44", b = "2ce8f5" },
}

-- Accessoires (ancrés sur le haut de la capuche)
local ACCESSORIES = {
    feather = {
        grid = { "..Y", ".YA", "YA.", "A.." },
        palette = { Y = "fee761", A = "feae34" },
        anchor = { 0, 3 },
    },
    mask = {
        grid = { "MMMMMMM", "MgMMMgM", "MMMMMMM" },
        palette = { M = "262b44", g = "63c74d" },
        anchor = { 0, 0 },
    },
    crest = {
        grid = { ".Y..", ".YO.", "YOOY", "OORO" },
        palette = { Y = "fee761", O = "f77622", R = "e43b44" },
        anchor = { 1, 3 },
    },
    horns = {
        grid = { "B..........B", "BB........BB", ".BB......BB." },
        palette = { B = "ead4aa" },
        anchor = { 6, 2 },
    },
    tiara = {
        grid = { "..C..", ".CWC.", "CCCCC" },
        palette = { C = "2ce8f5", W = "ffffff" },
        anchor = { 2, 2 },
    },
}

Heroes.ACCESSORY_BY_HERO = {
    atreus = "feather",
    urasil = "mask",
    phoren = "crest",
    helix = "horns",
    rolla = "tiara",
}

-- Arc tenu en main (pointe vers +X, corde côté archer)
local BOW = {
    "WW...",
    "s.W..",
    "s..W.",
    "s..W.",
    "s...W",
    "s...W",
    "s...g",
    "s...W",
    "s...W",
    "s..W.",
    "s..W.",
    "s.W..",
    "WW...",
}

function Heroes.define(atlas)
    local legPal = LEG_PALETTE
    atlas:define("hero_body", {
        frames = { BODY, BODY_BLINK },
        palette = BASE_PALETTE,
        outline = INK,
        flash = true,
        anchor = { 7, 14 },
        variants = Heroes.VARIANTS,
        shade = { depth = 4, strength = 1.0 },
    })
    atlas:define("hero_legs", {
        frames = { LEGS.idle, LEGS.run1, LEGS.run2, LEGS.run3 },
        palette = legPal,
        outline = INK,
        flash = true,
        anchor = { 5, 0 },
        shade = { depth = 2, strength = 0.8 },
    })
    for name, acc in pairs(ACCESSORIES) do
        atlas:define("hero_acc_" .. name, {
            frames = { acc.grid },
            palette = acc.palette,
            outline = INK,
            anchor = acc.anchor,
        })
    end
    atlas:define("bow", {
        frames = { BOW },
        palette = { W = "b86f50", s = "c0cbdc", g = "3e2731" },
        outline = INK,
        anchor = { 4, 6 },
        variants = {
            bone = { W = "ead4aa", g = "8b9bb4", s = "8b9bb4" },
        },
    })
end

return Heroes
