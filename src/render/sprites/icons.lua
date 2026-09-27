-- src/render/sprites/icons.lua
-- Icônes d'interface pixel art (monnaies, statistiques, compétences). Contour encre, couleurs pleines.

local Icons = {}

local INK = "181425"

local ICONS = {
    coin = {
        grid = { "..ooooo..", ".oyyyyYo.", "oyYYYYYYo", "oyYYyYYYo", "oyYYyYYYo", "oyYYyYYYo", "oYYYYYYYo", ".oYYYYYo.", "..ooooo.." },
        pal = { o = "f77622", y = "fee761", Y = "feae34" },
    },
    gem = {
        grid = { "..LLLLL..", ".LWLLLGG.", "LWLLLLGGG", "GGGGGGGGd", ".GGGGGGd.", "..GGGGd..", "...GGd...", "....d...." },
        pal = { L = "63c74d", G = "3e8948", d = "265c42", W = "ffffff" },
    },
    heart = {
        grid = { ".RRR.RRR.", "RWWRRRRRr", "RWRRRRRRr", "RRRRRRRRr", ".RRRRRRr.", "..RRRRr..", "...RRr...", "....r...." },
        pal = { R = "e43b44", W = "f6757a", r = "a22633" },
    },
    bolt = {
        grid = { "....YYYY", "...YYYY.", "..YYYY..", ".YYYYYYY", "....YYY.", "...YYY..", "..YYo...", ".Yo.....", "o......." },
        pal = { Y = "fee761", o = "feae34" },
    },
    sword = {
        grid = { "....W....", "...WWW...", "...WsW...", "...WsW...", "...WsW...", "...WsW...", ".GGGGGGG.", "....b....", "....b....", "...GGG..." },
        pal = { W = "c0cbdc", s = "ffffff", G = "feae34", b = "733e39" },
    },
    skull = {
        grid = { "..WWWWW..", ".WWWWWWW.", "WWWWWWWWW", "WkkWWWkkW", "WkkWWWkkW", "WWWWkWWWW", ".WWWWWWW.", "..WkWkW..", "..WWWWW.." },
        pal = { W = "ead4aa", k = INK },
    },
    pause = {
        grid = { "WWW.WWW", "WWW.WWW", "WWW.WWW", "WWW.WWW", "WWW.WWW", "WWW.WWW", "WWW.WWW", "WWW.WWW" },
        pal = { W = "ffffff" },
    },
    star = {
        grid = { "....Y....", "....Y....", "...YYY...", "YYYYWYYYY", ".YYYYYYY.", "..YYYYY..", "..YYoYY..", ".YYo.oYY.", ".Yo...oY." },
        pal = { Y = "fee761", W = "ffffff", o = "feae34" },
    },
    door = {
        grid = { "..DDDD..", ".DddddD.", "DddddddD", "DddddddD", "DdddddyD", "DddddddD", "DddddddD", "DDDDDDDD" },
        pal = { D = "733e39", d = "b86f50", y = "feae34" },
    },
    lock = {
        grid = { "..sss..", ".s...s.", ".s...s.", "YYYYYYY", "YYYkYYY", "YYYkYYY", "oYYYYYo", "ooooooo" },
        pal = { s = "c0cbdc", Y = "feae34", o = "f77622", k = INK },
    },
    check = {
        grid = { "......G", ".....GG", "G...GG.", "GG.GG..", ".GGG...", "..G...." },
        pal = { G = "63c74d" },
    },
    -- Compétences
    skill_multishot = {
        grid = { ".H...H...H.", "HHH.HHH.HHH", ".s...s...s.", ".s...s...s.", ".s...s...s.", ".s...s...s.", "fsf.fsf.fsf", "f.f.f.f.f.f" },
        pal = { H = "ffffff", s = "feae34", f = "e43b44" },
    },
    skill_ricochet = {
        grid = { "........HHH", "s........HH", ".s......s.H", "..s....s...", "...s..s....", "....ss.....", "WWWWWWWWWWW", "wwwwwwwwwww" },
        pal = { s = "feae34", H = "ffffff", W = "8b9bb4", w = "5a6988" },
    },
    skill_crit = {
        grid = { "...RRRRR...", ".RRWWWWWRR.", ".RWWRRRWWR.", "RWWRRRRRWWR", "RWRRRWRRRWR", "RWRRWWWRRWR", "RWRRRWRRRWR", "RWWRRRRRWWR", ".RWWRRRWWR.", ".RRWWWWWRR.", "...RRRRR..." },
        pal = { R = "e43b44", W = "ffffff" },
    },
    skill_speed = {
        grid = { "....YYYY", "...YYYY.", "..YYYY..", ".YYYYYYY", "....YYY.", "...YYY..", "..YYo...", ".Yo.....", "o......." },
        pal = { Y = "2ce8f5", o = "0099db" },
    },
    skill_damage = {
        grid = { "....W....", "...WWW...", "...WsW...", "...WsW...", "...WsW...", "...WsW...", ".GGGGGGG.", "....b....", "....b....", "...GGG..." },
        pal = { W = "f6757a", s = "ffffff", G = "e43b44", b = "3e2731" },
    },
    skill_boots = {
        grid = { "....BBB...", "....BBB...", "....BBB.ww", "....BBBwww", "...BBBBww.", "..BBBBBw..", "BBBBBBBB..", "BBBBBBBB..", "ssssssss.." },
        pal = { B = "b86f50", w = "ffffff", s = "3e2731" },
    },
    skill_heal = {
        grid = { ".RRR.RRR.", "RRRRRRRRR", "RRRRWRRRR", "RRRWWWRRR", ".RRRWRRR.", "..RRRRR..", "...RRR...", "....R...." },
        pal = { R = "63c74d", W = "ffffff" },
    },
    arrow_l = {
        grid = { "..W", ".WW", "WWW", ".WW", "..W" },
        pal = { W = "ffffff" },
    },
    arrow_r = {
        grid = { "W..", "WW.", "WWW", "WW.", "W.." },
        pal = { W = "ffffff" },
    },
    skill_meteor = {
        grid = { "..ff....", ".fFFf...", "fFRRFf..", "fFRRRFf.", ".fRRRf..", "..fff...", "....s...", ".....s.." },
        pal = { f = "fee761", F = "f77622", R = "e43b44", s = "feae34" },
    },
    skill_swords = {
        grid = { "W.......W", ".W.....W.", "..W...W..", "...W.W...", "....X....", "...G.G...", "..b...b..", ".y.....y." },
        pal = { W = "c0cbdc", X = "ffffff", G = "feae34", b = "733e39", y = "fee761" },
    },
    skill_star = {
        grid = { "....Y....", "....Y....", "...YYY...", "YYYYWYYYY", ".YYYYYYY.", "..YYYYY..", "..YYoYY..", ".YYo.oYY.", ".Yo...oY." },
        pal = { Y = "fee761", W = "ffffff", o = "feae34" },
    },
    -- Mini-carte de l'écran tactile (points lisibles à 1:4)
    mm_player = {
        grid = { ".BBB.", "BWWWB", "BWBWB", "BWWWB", ".BBB." },
        pal = { B = "0099db", W = "2ce8f5" },
    },
    mm_enemy = {
        grid = { "RRR", "RrR", "RRR" },
        pal = { R = "e43b44", r = "f6757a" },
    },
    mm_boss = {
        grid = { ".RRRRR.", "RRWRWRR", "RRRRRRR", "RWRRRWR", ".RWWWR.", "..RRR.." },
        pal = { R = "e43b44", W = "ffffff" },
    },
    mm_gate_open = {
        grid = { "..G..", ".GGG.", "GGGGG", ".GGG.", ".GGG." },
        pal = { G = "63c74d" },
    },
    mm_gate_closed = {
        grid = { "SSSSS", "S.S.S", "S.S.S", "SSSSS" },
        pal = { S = "8b9bb4" },
    },
    skill_shield = {
        grid = { "GGGGGGGGG", "GBBBBBBBG", "GBWBBBBBG", "GBWBBBBBG", "GBBBBBBBG", ".GBBBBBG.", ".GBBBBBG.", "..GBBBG..", "...GBG...", "....G...." },
        pal = { G = "feae34", B = "0099db", W = "2ce8f5" },
    },
}

function Icons.define(atlas)
    for name, icon in pairs(ICONS) do
        atlas:define("icon_" .. name, { frames = { icon.grid }, palette = icon.pal, outline = INK, anchor = "center" })
    end
end

function Icons.skillIcon(iconType)
    local key = "skill_" .. tostring(iconType)
    if ICONS[key] then return "icon_" .. key end
    return "icon_star"
end

return Icons
