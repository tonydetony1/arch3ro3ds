-- src/render/sprites/fx.lua
-- Projectiles, butin et particules. Les sprites "teintables" sont en tons clairs
-- (la couleur de l'arme / de l'effet est appliquée via SpriteBatch:setColor).

local Fx = {}

local INK = "181425"

local ARROW = {
    "ff.....H..",
    ".SSSSSSHHH",
    "ff.....H..",
}

local ORB = {
    ".WWW.",
    "WWWWW",
    "WWWWW",
    "WWWWW",
    ".WWW.",
}

local ORB_CORE = { "WW", "WW" }

local SPORE = {
    ".GG.",
    "GWGG",
    "GGGd",
    ".Gd.",
}

local COIN = {
    ".oooo.",
    "oyyYYo",
    "oyYYYo",
    "oyYYYo",
    "oYYYYo",
    ".oooo.",
}

local COIN_EDGE = {
    ".oo.",
    "oyYo",
    "oyYo",
    "oyYo",
    "oYYo",
    ".oo.",
}

local GEM = {
    "..g..",
    ".gGG.",
    "gWGGd",
    "gGGGd",
    ".GGd.",
    "..d..",
}

local HEART = {
    ".RR.RR.",
    "RWRRRRr",
    "RRRRRRr",
    ".RRRRr.",
    "..RRr..",
    "...r...",
}

local SCROLL = {
    "s.....s",
    "sPPPPPs",
    "sPlllPs",
    "sPPPPPs",
    "sPllPPs",
    "s..R..s",
}

local SWORD = {
    "..W..",
    "..W..",
    ".WWW.",
    "..W..",
    "..W..",
    "..W..",
    "GGGGG",
    "..b..",
    "..b..",
    "..y..",
}

local METEOR = {
    "...ff...",
    "..fFFf..",
    ".fFRRFf.",
    "fFRRRRFf",
    "fFRrrRFf",
    ".fRrrRf.",
    "..fRRf..",
    "...ff...",
}

local SPARK = {
    "..W..",
    "..W..",
    "WWWWW",
    "..W..",
    "..W..",
}

local RING = {
    "..WWW..",
    ".W...W.",
    "W.....W",
    "W.....W",
    "W.....W",
    ".W...W.",
    "..WWW..",
}

local PIXEL = { "W" }

local SHADOW = {
    "...WWWW...",
    ".WWWWWWWW.",
    "WWWWWWWWWW",
    "WWWWWWWWWW",
    ".WWWWWWWW.",
    "...WWWW...",
}

function Fx.define(atlas)
    local function d(name, frames, pal, outline, anchor)
        atlas:define(name, { frames = frames, palette = pal, outline = outline, anchor = anchor or "center" })
    end
    d("fx_pixel", { PIXEL }, { W = "ffffff" }, nil, "topleft")
    d("fx_shadow", { SHADOW }, { W = "ffffff" }, nil, "center")
    d("fx_arrow", { ARROW }, { f = "8b9bb4", S = "c0cbdc", H = "ffffff" }, INK, { 6, 1 })
    d("fx_orb", { ORB }, { W = "ffffff" }, INK)
    d("fx_orb_core", { ORB_CORE }, { W = "ffffff" }, nil)
    d("fx_spore", { SPORE }, { G = "63c74d", W = "ffffff", d = "3e8948" }, INK)
    d("fx_coin", { COIN, COIN_EDGE }, { o = "f77622", y = "fee761", Y = "feae34" }, INK)
    d("fx_gem", { GEM }, { g = "2ce8f5", G = "0099db", W = "ffffff", d = "124e89" }, INK)
    d("fx_heart", { HEART }, { R = "e43b44", W = "f6757a", r = "a22633" }, INK)
    d("fx_scroll", { SCROLL }, { s = "c28569", P = "ead4aa", l = "b86f50", R = "e43b44" }, INK)
    d("fx_sword", { SWORD }, { W = "c0cbdc", G = "feae34", b = "733e39", y = "fee761" }, INK, { 2, 4 })
    d("fx_meteor", { METEOR }, { f = "fee761", F = "f77622", R = "e43b44", r = "a22633" }, INK, "center")
    d("fx_spark", { SPARK }, { W = "ffffff" }, nil)
    d("fx_ring", { RING }, { W = "ffffff" }, nil)
end

return Fx
