-- src/render/sprites/monsters_extra.lua
-- Monstres des chapitres célestes et du Vide.
-- Module séparé : LuaJIT limite une fonction à 60 upvalues et monsters.lua
-- a atteint ce plafond.

local PixGen = require("src.render.sprites.pixgen")

local MonstersExtra = {}

local INK = "181425"

-- ============================================================================
-- MONSTRES DES MONDES CÉLESTES ET DU VIDE (chapitres 5 et 6)
-- ============================================================================

-- RAPACE DES CIMES : oiseau plongeur, ailes en V
local function raven(frame)
    local g = PixGen.new(26, 20, 11)
    local wing = (frame == 2) and 3 or 0
    g:ellipse(13, 12, 6, 5, "B")                 -- corps
    g:ellipse(13, 13, 4, 3, "l")                 -- ventre plus clair
    g:ellipse(3, 8 + wing, 6, 3, "B")            -- aile gauche déployée
    g:ellipse(23, 8 + wing, 6, 3, "B")           -- aile droite déployée
    g:edge("B", "b", 0, 1)
    g:edge("B", "l", 0, -1)
    g:circle(13, 6, 4, "B")                      -- tête
    g:rect(12, 3, 3, 2, "y")                     -- bec
    g:rect(10, 5, 2, 2, "r")                     -- œil gauche
    g:rect(15, 5, 2, 2, "r")                     -- œil droit
    g:rect(11, 16, 2, 3, "y")                    -- serres
    g:rect(14, 16, 2, 3, "y")
    return g:toGrid()
end

-- FEU FOLLET : sphère flottante entourée d'un halo
local function wisp(frame)
    local g = PixGen.new(20, 22, 21)
    local bob = (frame == 2) and 1 or 0
    g:circle(10, 9 + bob, 6, "H")                -- halo
    g:circle(10, 9 + bob, 4, "C")                -- cœur
    g:circle(10, 8 + bob, 2, "W")                -- point chaud
    g:sprinkle("W", 0.18, "C")
    g:ellipse(10, 17 + bob, 3, 2, "H")           -- traînée
    g:rect(8, 7 + bob, 1, 1, "e")
    g:rect(11, 7 + bob, 1, 1, "e")
    return g:toGrid()
end

-- GARGOUILLE : statue trapue aux ailes repliées
local function gargoyle(frame)
    local g = PixGen.new(30, 28, 31)
    local crouch = (frame == 2) and 1 or 0
    g:rect(9, 20 + crouch, 5, 8 - crouch, "S")   -- jambes
    g:rect(17, 20 + crouch, 5, 8 - crouch, "S")
    g:ellipse(15, 16, 9, 7, "S")                 -- torse
    g:ellipse(3, 12, 4, 7, "s")                  -- ailes
    g:ellipse(27, 12, 4, 7, "s")
    g:circle(15, 7, 6, "S")                      -- tête
    g:rect(10, 2, 2, 4, "s")                     -- cornes
    g:rect(19, 2, 2, 4, "s")
    g:edge("S", "d", 0, 1)
    g:edge("S", "L", 0, -1)
    g:rect(12, 6, 2, 2, "r")                     -- yeux
    g:rect(17, 6, 2, 2, "r")
    g:rect(12, 10, 7, 1, "d")                    -- gueule
    g:sprinkle("d", 0.18, "S")                   -- éclats de pierre
    return g:toGrid()
end

-- SPECTRE GIVRÉ : fantôme bleu à la traîne effilochée
local function frostWraith(frame)
    local g = PixGen.new(24, 30, 41)
    local sway = (frame == 2) and 1 or -1
    g:ellipse(12, 10, 8, 9, "R")                 -- capuche
    g:ellipse(12, 22, 7, 8, "r")                 -- voile
    g:ellipse(12 + sway, 28, 5, 3, "r")          -- traîne
    g:circle(12, 11, 5, "k")                     -- visage creux
    g:rect(9, 10, 2, 2, "i")                     -- yeux de glace
    g:rect(13, 10, 2, 2, "i")
    g:rect(3, 16, 3, 6, "R")                     -- bras
    g:rect(18, 16, 3, 6, "R")
    g:sprinkle("i", 0.12, "R")                   -- cristaux
    return g:toGrid()
end

-- DRAKE DES TEMPÊTES : boss du chapitre céleste
local function stormDrake(frame)
    local g = PixGen.new(40, 36, 51)
    local wing = (frame == 2) and 3 or 0

    -- Ailes largement déployées, en arrière-plan
    g:ellipse(5, 16 - wing, 6, 10, "w")
    g:ellipse(35, 16 - wing, 6, 10, "w")
    g:edge("w", "W", 0, -1)
    g:edge("w", "W", 0, 1)

    -- Corps sombre, ventre clair pour détacher la silhouette
    g:ellipse(20, 24, 11, 9, "D")
    g:ellipse(20, 27, 7, 5, "L")
    g:ellipse(20, 33, 5, 3, "D")                 -- queue

    -- Cou puis tête nettement plus claire que le corps
    g:rect(18, 14, 5, 6, "D")
    g:ellipse(20, 10, 8, 6, "L")
    g:ellipse(20, 12, 6, 3, "h")                 -- museau
    g:rect(13, 2, 3, 6, "h")                     -- cornes
    g:rect(24, 2, 3, 6, "h")
    g:rect(16, 8, 3, 2, "y")                     -- yeux lumineux
    g:rect(22, 8, 3, 2, "y")
    g:rect(17, 13, 7, 2, "k")                    -- gueule
    g:edge("D", "d", 0, 1)
    g:sprinkle("y", 0.10, "D")                   -- arcs électriques
    return g:toGrid()
end

-- ŒIL DU VIDE : boss du chapitre final, iris unique et tentacules
local function voidWatcher(frame)
    local g = PixGen.new(36, 36, 61)
    local pulse = (frame == 2) and 1 or 0
    g:circle(18, 18, 14 + pulse, "V")            -- globe
    g:edge("V", "v", 0, 1)
    g:edge("V", "L", 0, -1)
    g:circle(18, 18, 8, "W")                     -- sclère
    g:circle(18, 18, 5, "I")                     -- iris
    g:circle(18, 18, 2, "k")                     -- pupille
    for i = 0, 5 do
        local a = i * 1.05
        g:ellipse(18 + math.floor(math.cos(a) * 15), 18 + math.floor(math.sin(a) * 15), 3, 3, "v")
    end
    g:sprinkle("I", 0.10, "V")
    return g:toGrid()
end

-- Regroupé dans une seule table : LuaJIT limite une fonction à 60 upvalues,
-- et Monsters.define en utilise déjà beaucoup.
local EXTRA = {
    { name = "raven",        frames = { raven(1), raven(2) },             palette = { B = "3e2731", b = "262b44", l = "68386c", r = "ff0044", y = "fee761" }, anchor = "center" },
    { name = "wisp",         frames = { wisp(1), wisp(2) },               palette = { H = "2ce8f5", C = "0099db", W = "ffffff", e = INK }, anchor = "center" },
    { name = "gargoyle",     frames = { gargoyle(1), gargoyle(2) },       palette = { S = "8b9bb4", s = "5a6988", d = "3a4466", L = "c0cbdc", r = "fee761" }, anchor = "bottom" },
    { name = "frost_wraith", frames = { frostWraith(1), frostWraith(2) }, palette = { R = "0099db", r = "2ce8f5", k = "181425", i = "ffffff" }, anchor = "bottom" },
    { name = "storm_drake",  frames = { stormDrake(1), stormDrake(2) },   palette = { D = "3a4466", d = "262b44", L = "8b9bb4", w = "68386c", W = "b55088", y = "fee761", h = "c0cbdc", k = "181425" }, anchor = "bottom",
      variants = { rage = { D = "68386c", d = "3e2731", y = "ff0044" } } },
    { name = "void_watcher", frames = { voidWatcher(1), voidWatcher(2) }, palette = { V = "68386c", v = "3e2731", L = "b55088", W = "c0cbdc", I = "2ce8f5", k = "181425" }, anchor = "bottom",
      variants = { rage = { I = "ff0044", W = "fee761" } } },
}


function MonstersExtra.define(atlas)
    for _, extra in ipairs(EXTRA) do
        atlas:define(extra.name, {
            frames = extra.frames, palette = extra.palette, outline = INK, flash = true,
            anchor = extra.anchor or "bottom", variants = extra.variants,
            shade = { depth = 4, strength = 1.0 },
        })
    end
end

return MonstersExtra
