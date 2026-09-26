-- src/render/sprites/monsters.lua
-- Bestiaire pixel art : contour encre, 3 tons, lumière venant du haut-gauche.
-- Tous les monstres regardent vers la droite par défaut (miroir vers la gauche).

local PixGen = require("src.render.sprites.pixgen")

local Monsters = {}

local INK = "181425"

-- ---------------------------------------------------------------------------
-- SLIME (G corps | g ombre | d base sombre | W reflet | e yeux | m bouche)
-- ---------------------------------------------------------------------------
local SLIME_IDLE = {
    "......GGGG......",
    "....GGGGGGGG....",
    "...GWWGGGGGGG...",
    "..GWWGGGGGGGGG..",
    ".GGGGGGGGGGGGGG.",
    ".GGGGGeGGGGeGGGg",
    "GGGGGWeGGGWeGGGg",
    "GGGGGGGGmmGGGGgg",
    "gGGGGGGGGGGGGGgg",
    ".ggGGGGGGGGGGggg",
    "..dddggggggdddd.",
}

local SLIME_SQUASH = {
    ".......GGGG.......",
    "....GGGGGGGGGG....",
    "..GWWGGGGGGGGGGG..",
    ".GWWGGGGGGGGGGGGG.",
    "GGGGGGeGGGGGeGGGGg",
    "GGGGGWeGGGGWeGGGgg",
    "gGGGGGGGGmmGGGGGgg",
    ".ggGGGGGGGGGGGGggg",
    "..ddddgggggggdddd.",
}

local SLIME_STRETCH = {
    ".....GGG.....",
    "....GGGGG....",
    "...GWGGGGG...",
    "..GWWGGGGGG..",
    "..GGGGGGGGG..",
    ".GGGGeGGGeGg.",
    ".GGGWeGGWeGg.",
    ".GGGGGmmGGgg.",
    ".gGGGGGGGGgg.",
    "..ggGGGGGgg..",
    "...ggggggg...",
    "....ddddd....",
}

local SLIME_PAL = { G = "63c74d", g = "3e8948", d = "265c42", W = "ffffff", e = INK, m = "265c42" }

-- ---------------------------------------------------------------------------
-- CHAUVE-SOURIS (B corps | b ombre | w aile | v membrane sombre | r yeux | f crocs)
-- ---------------------------------------------------------------------------
local BAT_UP = {
    "ww..............ww",
    "vww....b..b....wwv",
    ".vww...BbbB...wwv.",
    "..vwwwBBBBBBwwwv..",
    "...vvwBrBBrBwvv...",
    ".....BBBBBBBB.....",
    "......BfBBfB......",
    ".......BBBB.......",
}

local BAT_MID = {
    ".......b..b.......",
    ".......BbbB.......",
    ".wwwwwBBBBBBwwwww.",
    "wvvvvwBrBBrBwvvvvw",
    "v....vBBBBBBv....v",
    "......BfBBfB......",
    ".......BBBB.......",
}

local BAT_DOWN = {
    ".......b..b.......",
    ".......BbbB.......",
    "......BBBBBB......",
    "....wwBrBBrBww....",
    "..wwvvBBBBBBvvww..",
    ".wvv..BfBBfB..vvw.",
    "wv.....BBBB.....vw",
    "v................v",
}

local BAT_PAL = { B = "68386c", b = "3e2731", w = "3e2731", v = "262b44", r = "ff0044", f = "ffffff" }

-- ---------------------------------------------------------------------------
-- SQUELETTE ARCHER (O os | o os ombre | k orbites | r lueur | R haillons | q haillons ombre)
-- ---------------------------------------------------------------------------
local SKELETON_A = {
    "...OOOOO...",
    "..OOOOOOO..",
    ".OOOOOOOOo.",
    ".OkkOOkkOo.",
    ".OkrOOkrOo.",
    ".oOOOkOOoo.",
    "..oOkOkOo..",
    "...ooooo...",
    "..RRoOoRR..",
    ".RRqOoOqRR.",
    ".RqOoOoOqR.",
    "..qRoOoRq..",
    "..RRRqRRR..",
    ".RqR...RqR.",
    "..o.....o..",
    ".oo.....oo.",
}

local SKELETON_B = {
    "...OOOOO...",
    "..OOOOOOO..",
    ".OOOOOOOOo.",
    ".OkkOOkkOo.",
    ".OkrOOkrOo.",
    ".oOOOkOOoo.",
    "..oOkOkOo..",
    "...ooooo...",
    "..RRoOoRR..",
    ".RRqOoOqRR.",
    ".RqOoOoOqR.",
    "..qRoOoRq..",
    "..RRRqRRR..",
    "..RqR.RqR..",
    "...o...o...",
    "..oo...oo..",
}

local SKELETON_PAL = { O = "ead4aa", o = "c0cbdc", k = INK, r = "e43b44", R = "68386c", q = "3e2731" }

-- ---------------------------------------------------------------------------
-- LOUP (F fourrure | f ombre | L ventre clair | r oeil | W crocs | n truffe)
-- ---------------------------------------------------------------------------
local WOLF_A = {
    "..........f.f.....",
    ".........fFfF.....",
    "........fFFFFF....",
    ".......fFFFrFFFF..",
    "ff....fFFFFFFFFFnn",
    ".fFFFFFFFFFFFLLWW.",
    "..fFFFFFFFFFFLL...",
    "..fFFFFFFFFFLLL...",
    "...fFFfffFFFfL....",
    "...fF.....fF......",
    "..fF.......fF.....",
    "..ff.......ff.....",
}

local WOLF_B = {
    "..........f.f.....",
    ".........fFfF.....",
    "........fFFFFF....",
    ".......fFFFrFFFF..",
    ".f....fFFFFFFFFFnn",
    "ffFFFFFFFFFFFLLWW.",
    "..fFFFFFFFFFFLL...",
    "..fFFFFFFFFFLLL...",
    "...fFFfffFFFfL....",
    "....fF...fF.......",
    ".....fF.fF........",
    ".....ff.ff........",
}

local WOLF_PAL = { F = "8b9bb4", f = "5a6988", L = "c0cbdc", r = "ff0044", W = "ffffff", n = INK }

-- ---------------------------------------------------------------------------
-- PLANTE CRACHEUSE (P bulbe | p ombre | x taches | M gueule | T dents | V feuilles | v ombre feuilles)
-- ---------------------------------------------------------------------------
local PLANT_CLOSED = {
    "....PPPPP.....",
    "..PPxPPPPPP...",
    ".PPPPPPPxPPP..",
    ".PxPPPPPPPPPp.",
    "PPPPPPPPPTTTTp",
    "PPPPPPPPPMMMMp",
    "pPPPPPPPPTTTTp",
    ".pPPPPPPPPPPp.",
    "..ppPPPPPPpp..",
    "....ppVVpp....",
    "..VV..VV..VV..",
    ".VVvV.Vv.VvVV.",
    "VVv..vVVv..vVV",
    ".....vVVv.....",
}

local PLANT_OPEN = {
    "....PPPPP.....",
    "..PPxPPPPPPT..",
    ".PPPPPPPxPPMT.",
    ".PxPPPPPPPMMMT",
    "PPPPPPPPPMMMMM",
    "PPPPPPPPPMMrMM",
    "pPPPPPPPPMMMMM",
    ".pPPPPPPPPMMMT",
    "..ppPPPPPPpMT.",
    "....ppVVppT...",
    "..VV..VV..VV..",
    ".VVvV.Vv.VvVV.",
    "VVv..vVVv..vVV",
    ".....vVVv.....",
}

local PLANT_PAL = { P = "b55088", p = "68386c", x = "f6757a", M = "3e2731", T = "ffffff", r = "63c74d", V = "3e8948", v = "265c42" }

-- ---------------------------------------------------------------------------
-- BOMBARDIER SPECTRAL (R robe | r robe ombre | H capuche | k visage | c yeux | b bombe | y mèche)
-- ---------------------------------------------------------------------------
local BOMBER_A = {
    "....HHHHH.....",
    "...HHHHHHH....",
    "..HHHHHHHHH...",
    "..HHkkkkkHH...",
    "..HkkckkckH...",
    "..HkkkkkkkH...",
    "..RHkkkkkHR...",
    ".RRRHHHHHRRR..",
    ".RRRRRRRRRRRr.",
    "RRrRRRRRRRRrr.",
    "RRrRRRRRRRrrr.",
    ".rrRRRRRRRrr..",
    ".rrRrRRRrRrr..",
    "..r.rrRrr.r...",
    "......r.......",
}

local BOMBER_B = {
    "....HHHHH.....",
    "...HHHHHHH....",
    "..HHHHHHHHH...",
    "..HHkkkkkHH...",
    "..HkkckkckH...",
    "..HkkkkkkkH...",
    "..RHkkkkkHR...",
    ".RRRHHHHHRRR..",
    ".RRRRRRRRRRRr.",
    "RRrRRRRRRRRrr.",
    "RRrRRRRRRRrrr.",
    ".rrRRRRRRRrr..",
    "..rRrRRRrRr...",
    "...r.rRr.r....",
    ".......r......",
}

local BOMBER_PAL = { H = "68386c", R = "b55088", r = "68386c", k = "181425", c = "2ce8f5" }

local BOMB = {
    "....y.",
    "...Yy.",
    "..bbb.",
    ".bWbbb",
    "bWbbbb",
    "bbbbbb",
    "bbbbbb",
    ".bbbb.",
}
local BOMB_PAL = { b = "3a4466", W = "8b9bb4", y = "fee761", Y = "f77622" }

-- ---------------------------------------------------------------------------
-- VER FOUISSEUR (S corps | s ombre | M gueule | T crocs | y yeux | d terre | k trou)
-- ---------------------------------------------------------------------------
local function worm(frame)
    local g = PixGen.new(18, 21, 6)
    local sway = (frame == 2) and 1 or 0
    g:ellipse(9, 18, 9, 3, "d")
    g:ellipse(9, 18, 6, 2, "k")
    g:ellipse(9, 15, 4, 3, "S")
    g:ellipse(9 + sway, 11, 4.5, 3, "S")
    g:ellipse(9 + sway, 6, 5.5, 4, "S")
    g:rect(5 + sway, 9, 9, 1, "s", "S")
    g:rect(5, 13, 9, 1, "s", "S")
    g:edge("S", "s", 1, 0)
    g:ellipse(9 + sway, 4, 3, 2, "M", "Ss")
    g:set(7 + sway, 3, "T"); g:set(11 + sway, 3, "T"); g:set(9 + sway, 5, "T")
    g:set(6 + sway, 6, "y"); g:set(12 + sway, 6, "y")
    g:set(4 + sway, 1, "M"); g:set(5 + sway, 2, "M"); g:set(14 + sway, 1, "M"); g:set(13 + sway, 2, "M")
    g:sprinkle("o", 0.25, "d")
    return g:toGrid()
end

local WORM_PAL = { S = "e4a672", s = "b86f50", M = "3e2731", T = "ffffff", y = "fee761", d = "9a6a48", k = "3e2731", o = "7a4f38" }

local MOUND = {
    ".....DD.....",
    "...DDDDDD...",
    "..DoDDDDoD..",
    ".DDDDDDDDDD.",
    "dDDDoDDDDDDd",
    ".dddddddddd.",
}
local MOUND_PAL = { D = "9a6a48", d = "733e39", o = "c0cbdc" }

-- ---------------------------------------------------------------------------
-- MINI SLIME & SPLITTER (tons chauds)
-- ---------------------------------------------------------------------------
local MINI_A = {
    "...GGGG...",
    "..GWGGGG..",
    ".GGGGGGGG.",
    "GGeGGGeGGg",
    "GGeGGGeGgg",
    "gGGGmGGGgg",
    ".gggggggg.",
}
local MINI_B = {
    "....GG....",
    "...GGGG...",
    "..GWGGGG..",
    ".GGeGGeGG.",
    ".GGeGGeGg.",
    ".gGGGmGgg.",
    "..gggggg..",
    "...dddd...",
}
local MINI_PAL = { G = "f77622", g = "be4a2f", d = "733e39", W = "fee761", e = INK, m = "733e39" }

local SPLITTER_A = {
    "..........GGGG..........",
    "........GGGGGGGG........",
    "......GGGGGGGGGGGG......",
    ".....GWWGGGGGGGGGGGG....",
    "....GWWWGGGGGGGGGGGGG...",
    "...GGWWGGGGGGGGGGGGGGG..",
    "..GGGGGGGGGGGGGGGGGGGGg.",
    "..GGGGGEEEGGGGGEEEGGGGg.",
    ".GGGGGEEEeEGGGEEEeEGGGgg",
    ".GGGGGEEeeEGGGEEeeEGGGgg",
    "GGGGGGGEEEGGGGGEEEGGGGgg",
    "GGGGGGGGGGGGGGGGGGGGGggg",
    "GGGGGGGGGmmmmmmGGGGGGggg",
    "gGGGGGGGGGmmmmGGGGGGgggg",
    "gGGGGGGGGGGGGGGGGGGGgggg",
    ".ggGGGGGGGGGGGGGGGGggggg",
    "..gggGGGGGGGGGGGGGgggg..",
    "...ddddggggggggggdddd...",
}
local SPLITTER_B = {
    "..........GGGG..........",
    ".......GGGGGGGGGG.......",
    ".....GGGGGGGGGGGGGG.....",
    "....GWWGGGGGGGGGGGGGG...",
    "...GWWWGGGGGGGGGGGGGGG..",
    "..GGWWGGGGGGGGGGGGGGGGG.",
    "..GGGGGEEEGGGGGEEEGGGGg.",
    ".GGGGGEEEeEGGGEEEeEGGGgg",
    ".GGGGGEEeeEGGGEEeeEGGGgg",
    "GGGGGGGEEEGGGGGEEEGGGGgg",
    "GGGGGGGGGGGGGGGGGGGGGggg",
    "GGGGGGGGGmmmmmmGGGGGGggg",
    "gGGGGGGGGGmmmmGGGGGGgggg",
    ".ggGGGGGGGGGGGGGGGGggggg",
    "..gggGGGGGGGGGGGGGgggg..",
    "...ddddggggggggggdddd...",
}
local SPLITTER_PAL = { G = "e43b44", g = "a22633", d = "3e2731", W = "f6757a", E = "ffffff", e = INK, m = "3e2731" }

-- ---------------------------------------------------------------------------
-- GOLEM (S pierre | s ombre | L reflet | D pierre sombre | M mousse | O fissures | Y noyau)
-- ---------------------------------------------------------------------------
local function golem(frame)
    local g = PixGen.new(40, 36, 4)
    local legShift = (frame == 2) and 1 or 0
    g:rect(10, 27 - legShift, 8, 9 + legShift, "D")
    g:rect(22, 27 + legShift - 1, 8, 9 - legShift + 1, "D")
    g:ellipse(20, 18, 14, 12, "S")
    g:circle(7, 12, 7, "S")
    g:circle(33, 12, 7, "S")
    local armY = (frame == 2) and 1 or 0
    g:ellipse(4, 21 + armY, 4, 8, "S")
    g:ellipse(36, 21 - armY, 4, 8, "S")
    g:circle(4, 29 + armY, 4, "D")
    g:circle(36, 29 - armY, 4, "D")
    g:ellipse(20, 6, 7, 6, "S")
    g:edge("S", "s", 1, 0)
    g:edge("S", "s", 0, 1)
    g:edge("S", "L", -1, 0)
    g:edge("S", "L", 0, -1)
    g:edge("D", "s", 0, -1)
    g:ellipse(7, 6, 6, 2, "M", "SLs")
    g:ellipse(33, 6, 5, 2, "M", "SLs")
    g:sprinkle("m", 0.3, "M")
    g:rect(16, 5, 8, 2, "O")
    g:rect(17, 5, 6, 1, "Y")
    g:rect(19, 13, 3, 9, "O", "SsL")
    g:rect(20, 15, 1, 5, "Y")
    g:set(18, 12, "O"); g:set(17, 11, "O"); g:set(22, 21, "O"); g:set(23, 22, "O")
    g:set(12, 16, "D"); g:set(13, 17, "D"); g:set(27, 19, "D"); g:set(28, 18, "D")
    return g:toGrid()
end

local GOLEM_PAL = { S = "8b9bb4", s = "5a6988", D = "3a4466", L = "c0cbdc", M = "3e8948", m = "63c74d", O = "f77622", Y = "fee761" }

-- ---------------------------------------------------------------------------
-- INVOCATEUR (R robe | r ombre | H capuche | k visage | g lueur | S bâton | o orbe)
-- ---------------------------------------------------------------------------
local SUMMONER_A = {
    "....HHHHH.....",
    "...HHHHHHH..o.",
    "..HHkkkkkHHoo.",
    "..HkgkkkgkH.o.",
    "..HkkkkkkkH.S.",
    "..RHkkkkkHR.S.",
    ".RRRHHHHHRRRS.",
    ".RRRRRRRRRRRS.",
    "RRrRRRRRRRRrS.",
    "RRrRRRRRRRrrS.",
    ".rrRRRRRRRrr..",
    ".rrRrRRRrRrr..",
    "..rrrrrrrrr...",
    "...rr...rr....",
}
local SUMMONER_B = {
    "....HHHHH.....",
    "...HHHHHHH.oo.",
    "..HHkkkkkHHooo",
    "..HkgkkkgkH.oo",
    "..HkkkkkkkH.o.",
    "..RHkkkkkHR.S.",
    ".RRRHHHHHRRRS.",
    ".RRRRRRRRRRRS.",
    "RRrRRRRRRRRrS.",
    "RRrRRRRRRRrrS.",
    ".rrRRRRRRRrr..",
    "..rRrRRRrRr...",
    "...rrrrrrr....",
    "....r...r.....",
}
local SUMMONER_PAL = { R = "265c42", r = "193c3e", H = "3e8948", k = "181425", g = "63c74d", S = "733e39", o = "a8e890" }

-- ---------------------------------------------------------------------------
-- TOURELLE DE PIERRE (S pierre | s ombre | L reflet | B canon | y oeil)
-- ---------------------------------------------------------------------------
local TURRET_A = {
    "....SSSSSS....",
    "...SLLSSSSs...",
    "..SLSSSSSSSs..",
    "BBSSSSyySSSSBB",
    "BBSSSyyyySSSBB",
    "..SSSSyySSSs..",
    "..sSSSSSSSss..",
    "...ssSSSSss...",
    "....ssssss....",
    "...DDDDDDDD...",
}
local TURRET_B = {
    "....SSSSSS....",
    "...SLLSSSSs...",
    "..SLSSSSSSSs..",
    ".BSSSSyySSSSB.",
    ".BSSSyyyySSSB.",
    "..SSSSyySSSs..",
    "..sSSSSSSSss..",
    "...ssSSSSss...",
    "....ssssss....",
    "...DDDDDDDD...",
}
local TURRET_PAL = { S = "8b9bb4", s = "5a6988", L = "c0cbdc", D = "3a4466", B = "3e2731", y = "f77622" }

-- ---------------------------------------------------------------------------
-- MAGE TÉLÉPORTEUR (R robe | r ombre | H chapeau | k visage | c yeux | o orbe)
-- ---------------------------------------------------------------------------
local MAGE_A = {
    "......HH......",
    ".....HHHH.....",
    "....HHHHHH....",
    "...HHHHHHHH...",
    "..HHHHHHHHHH..",
    ".HHHHHHHHHHHH.",
    "...kkkkkkk....",
    "...kckkkck....",
    "...kkkkkkk...o",
    "..RRRRRRRRR.oo",
    ".RRrRRRRRrRR.o",
    ".RRrRRRRRrRR..",
    "..rrRRRRRrr...",
    "...rrrrrrr....",
}
local MAGE_B = {
    "......HH......",
    ".....HHHH.....",
    "....HHHHHH....",
    "...HHHHHHHH...",
    "..HHHHHHHHHH..",
    ".HHHHHHHHHHHH.",
    "...kkkkkkk....",
    "...kckkkck....",
    "...kkkkkkk..oo",
    "..RRRRRRRRRooo",
    ".RRrRRRRRrRRoo",
    ".RRrRRRRRrRR..",
    "...rRRRRRr....",
    "....rrrrr.....",
}
local MAGE_PAL = { R = "68386c", r = "3e2731", H = "b55088", k = "181425", c = "2ce8f5", o = "f6757a" }

-- ---------------------------------------------------------------------------
-- BOSS : ROI SQUELETTE (couronne, épaulières, cape, cage thoracique)
-- ---------------------------------------------------------------------------
local function skeletonKing(frame)
    local g = PixGen.new(34, 32, 11 + frame)
    local sway = (frame == 2) and 1 or 0

    -- Cape
    g:ellipse(17, 21, 16, 11, "C")
    g:rect(2, 21, 30, 9, "C")
    g:edge("C", "c", 1, 0)
    g:edge("C", "c", 0, 1)

    -- Épaulières et bras
    g:circle(6, 15, 5, "O")
    g:circle(28, 15, 5, "O")
    g:rect(4, 19, 3, 8, "o")
    g:rect(27, 19, 3, 8, "o")

    -- Torse / cage thoracique
    g:ellipse(17, 20, 9, 9, "O")
    for y = 16, 24, 3 do
        g:rect(10, y, 15, 1, "o", "O")
    end
    g:rect(16, 16, 3, 10, "o", "O")

    -- Crâne
    g:ellipse(17, 8, 9, 8, "O")
    g:rect(12, 6, 4, 4, "k")
    g:rect(19, 6, 4, 4, "k")
    g:set(13, 7, "r"); g:set(14, 7, "r"); g:set(20, 7, "r"); g:set(21, 7, "r")
    g:rect(14, 12, 7, 3, "o")
    for x = 14, 20, 2 do g:set(x, 13, "k") end

    -- Couronne
    g:rect(9, 2, 17, 3, "Y")
    for x = 9, 25, 4 do g:rect(x, 0, 2, 3, "Y") end
    g:set(17, 0, "W")

    -- Jambes
    g:rect(11 - sway, 28, 4, 4, "o")
    g:rect(19 + sway, 28, 4, 4, "o")
    return g:toGrid()
end

local KING_PAL = { O = "ead4aa", o = "c0cbdc", k = INK, r = "ff0044", C = "68386c", c = "3e2731", Y = "fee761", W = "ffffff" }

-- ---------------------------------------------------------------------------
-- BOSS : SORCIÈRE DE CRISTAL (chapeau pointu, robe, bâton à orbe)
-- ---------------------------------------------------------------------------
local function witchBoss(frame)
    local g = PixGen.new(32, 34, 29 + frame)
    local float = (frame == 2) and 1 or 0

    -- Robe
    g:ellipse(15, 26 - float, 12, 9, "R")
    g:rect(4, 24 - float, 23, 9, "R")
    g:edge("R", "r", 1, 0)
    g:edge("R", "r", 0, 1)
    for x = 5, 25, 5 do g:rect(x, 32 - float, 3, 2, "r") end

    -- Bâton et orbe
    g:rect(25, 12 - float, 2, 18, "B")
    g:circle(26, 10 - float, 4, "o")
    g:circle(26, 9 - float, 2, "W")

    -- Tête
    g:ellipse(15, 15 - float, 6, 5, "S")
    g:set(12, 15 - float, "e"); g:set(13, 15 - float, "e")
    g:set(17, 15 - float, "e"); g:set(18, 15 - float, "e")
    g:rect(13, 18 - float, 5, 1, "s")

    -- Chapeau pointu
    g:rect(5, 10 - float, 21, 2, "h")
    for i = 0, 8 do
        local half = math.max(1, 6 - i * 0.7)
        g:rect(math.floor(15 - half), 10 - float - i, math.ceil(half * 2), 1, "H")
    end
    g:rect(9, 8 - float, 13, 2, "H")
    g:set(20, 6 - float, "o")
    return g:toGrid()
end

local WITCH_PAL = { H = "68386c", h = "b55088", R = "124e89", r = "0d3563", S = "e8b796", s = "c28569",
                    e = INK, o = "2ce8f5", W = "ffffff", B = "733e39" }

-- ---------------------------------------------------------------------------
-- FAMILIERS
-- ---------------------------------------------------------------------------
local PET_BAT_A = {
    "w....b..b....w",
    "ww...BbbB...ww",
    "vwwwBBBBBBwwwv",
    ".vvwBWeBWeBwv.",
    "....BBBBBBB...",
    ".....BpBpB....",
}
local PET_BAT_B = {
    ".....b..b.....",
    "....BbbBB.....",
    "...BBBBBBB....",
    "wwwBWeBWeBwww.",
    "vvwBBBBBBBwvv.",
    "v..vBpBpBv..v.",
}
local PET_BAT_PAL = { B = "b55088", b = "68386c", w = "68386c", v = "3e2731", W = "ffffff", e = INK, p = "f6757a" }

local PET_GHOST_A = {
    "....NN....",
    "...NNNN...",
    "..NNNNNN..",
    ".YYYYYYYY.",
    "..GGGGGG..",
    ".GGeGGeGG.",
    ".GGGGGGGg.",
    ".GGGGGGGg.",
    ".GgGGgGgg.",
    "..g..g.g..",
}
local PET_GHOST_B = {
    "...NN.....",
    "...NNNN...",
    "..NNNNNN..",
    ".YYYYYYYY.",
    "..GGGGGG..",
    ".GGeGGeGG.",
    ".GGGGGGGg.",
    ".GGGGGGGg.",
    ".gGGgGGgg.",
    ".g..g..g..",
}
local PET_GHOST_PAL = { N = "124e89", Y = "feae34", G = "ffffff", g = "c0cbdc", e = "124e89" }

-- ---------------------------------------------------------------------------
-- PNJ DES SALLES SPÉCIALES (ange, démon, marchand)
-- ---------------------------------------------------------------------------
local ANGEL = {
    "......YYYY......",
    ".....YWWWWY.....",
    "......YYYY......",
    "......SSSS......",
    ".....SSSSSS.....",
    ".W...SeSSeS...W.",
    "WWW..SSSSSS..WWW",
    "WWWW.SSSSSS.WWWW",
    "WWWWWRRRRRRWWWWW",
    ".WWWRRRRRRRRWWW.",
    "..W.RRYYYYRR.W..",
    "....RRRRRRRR....",
    "....RRRRRRRR....",
    ".....RRRRRR.....",
    ".....rrrrrr.....",
    "......rrrr......",
}
local ANGEL_PAL = { Y = "fee761", W = "ffffff", S = "e8b796", e = INK, R = "ffffff", r = "c0cbdc" }

local DEVIL = {
    "H............H..",
    "HH..........HH..",
    ".HH...RRR..HH...",
    "..HHRRRRRRHH....",
    "...RRRRRRRRR....",
    "...RyRRRRyRR....",
    "...RRRRRRRRR....",
    "....RRkkkRR.....",
    "..DDDDDDDDDD....",
    ".DDDDDDDDDDDD...",
    "DDDDdDDDDdDDDD..",
    "DDDDDDDDDDDDDD..",
    ".DDDDDDDDDDDD...",
    "..DDDDDDDDDD....",
    "...dd....dd.....",
    "..dd......dd....",
}
local DEVIL_PAL = { H = "ead4aa", R = "e43b44", y = "fee761", k = "3e2731", D = "68386c", d = "3e2731" }

local MERCHANT = {
    "....HHHHHHH.....",
    "...HHHHHHHHH....",
    "..HHHHHHHHHHH...",
    ".....SSSSS......",
    ".....SeSeS......",
    ".....SSSSS......",
    "...CCCCCCCCC....",
    "..CCCCCCCCCCC...",
    ".CCCCbbbbbCCCC..",
    ".CCCbYYYYYbCCC..",
    ".CCCbYYYYYbCCC..",
    "..CCbbbbbbbCC...",
    "..CCCCCCCCCC....",
    "...CCCCCCCC.....",
    "....cc..cc......",
    "...cc....cc.....",
}
local MERCHANT_PAL = { H = "733e39", S = "e8b796", e = INK, C = "124e89", c = "0d3563", b = "b86f50", Y = "feae34" }

function Monsters.define(atlas)
    local function def(name, frames, pal, anchor, variants)
        atlas:define(name, {
            frames = frames, palette = pal, outline = INK, flash = true,
            anchor = anchor or "bottom", variants = variants,
            shade = { depth = 4, strength = 1.0 },
        })
    end

    def("slime", { SLIME_IDLE, SLIME_SQUASH, SLIME_STRETCH }, SLIME_PAL, "bottom", {
        charge = { G = "f77622", g = "be4a2f", d = "733e39", m = "733e39" },
    })
    def("bat", { BAT_UP, BAT_MID, BAT_DOWN, BAT_MID }, BAT_PAL, "center", {
        charge = { B = "e43b44", b = "a22633" },
    })
    def("skeleton", { SKELETON_A, SKELETON_B }, SKELETON_PAL, "bottom")
    def("wolf", { WOLF_A, WOLF_B }, WOLF_PAL, "bottom", {
        charge = { F = "e43b44", f = "a22633", L = "f6757a" },
    })
    def("plant", { PLANT_CLOSED, PLANT_OPEN }, PLANT_PAL, "bottom")
    def("bomber", { BOMBER_A, BOMBER_B }, BOMBER_PAL, "bottom")
    def("bomber_bomb", { BOMB }, BOMB_PAL, "center")
    def("burrower", { worm(1), worm(2) }, WORM_PAL, "bottom")
    def("burrow_mound", { MOUND }, MOUND_PAL, "bottom")
    def("mini_slime", { MINI_A, MINI_B }, MINI_PAL, "bottom")
    def("splitter", { SPLITTER_A, SPLITTER_B }, SPLITTER_PAL, "bottom")
    def("golem", { golem(1), golem(2) }, GOLEM_PAL, "bottom", {
        rage = { O = "ff0044", Y = "ffffff" },
        lava = { S = "6b3a2a", s = "4a2a20", D = "2e1c16", L = "8a4c36", M = "f77622", m = "fee761", O = "ff0044", Y = "ffffff" },
    })
    def("summoner", { SUMMONER_A, SUMMONER_B }, SUMMONER_PAL, "bottom")
    def("turret", { TURRET_A, TURRET_B }, TURRET_PAL, "bottom")
    def("mage", { MAGE_A, MAGE_B }, MAGE_PAL, "bottom")
    def("skeleton_king", { skeletonKing(1), skeletonKing(2) }, KING_PAL, "bottom", {
        rage = { C = "a22633", c = "3e2731", r = "fee761" },
    })
    def("witch", { witchBoss(1), witchBoss(2) }, WITCH_PAL, "bottom", {
        rage = { R = "68386c", r = "3e2731", o = "ff0044" },
    })
    def("npc_angel", { ANGEL }, ANGEL_PAL, "bottom")
    def("npc_devil", { DEVIL }, DEVIL_PAL, "bottom")
    def("npc_merchant", { MERCHANT }, MERCHANT_PAL, "bottom")
    def("pet_bat", { PET_BAT_A, PET_BAT_B }, PET_BAT_PAL, "center")
    def("pet_ghost", { PET_GHOST_A, PET_GHOST_B }, PET_GHOST_PAL, "center")
end

return Monsters
