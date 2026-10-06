-- src/data/rooms.lua
-- Salles dessinées à la main, façon Archero : grilles ASCII de 13 x 9 cases (45 à 50 px).
-- La salle épouse exactement la grille : ce qui touche le bord de la grille touche le mur.
-- La porte de sortie est au nord (case centrale de la 1re ligne), le héros entre par le
-- sud (case centrale de la dernière ligne). Chaque grille est validée par Rooms.validate
-- (autotest) : porte atteignable à pied, aucune poche fermée par des rochers.
--
-- Légende :
--   .  sol              #  rocher (bloque déplacements ET tirs)
--   ~  eau (bloque la marche, tirs et volants passent)
--   ^  plaque de pics   h  zone du biome (sable, glace, lave, vent, vide ; sol au chapitre 1)
--   b  baril explosif   o  urne (cœur / or)
--   m  repère d'apparition d'un monstre
--
-- Familles :
--   combat    : salles de vague ordinaires (minRoom = première salle où elle apparaît)
--   arena     : centre dégagé (boss, roue, boss rush, survie)
--   sanctuary : sanctuaires de l'Ange et du Démon, un écran sans obstacle

local Rooms = {}

Rooms.COLS = 13
Rooms.ROWS = 9
Rooms.CELL_SIZES = { 45, 46, 48, 50 } -- même grille, salles plus ou moins vastes
-- Bandes de murs autour de la grille : doivent rester égales aux limites du héros
-- (Player:setBounds : 22 px sur les côtés et en bas, 36 px en haut)
Rooms.MARGIN_X = 22
Rooms.MARGIN_TOP = 36
Rooms.MARGIN_BOTTOM = 22
Rooms.MAX_ROCK_RECTS = 10 -- au-delà, les tests de collision coûtent trop sur Old 3DS

local VALID_CHARS = { ["."] = true, ["#"] = true, ["~"] = true, ["^"] = true,
                      h = true, b = true, o = true, m = true }
local GATE_COL = 7

Rooms.COMBAT = {
    { id = "pillars", minRoom = 1, grid = {
        "o....m.m....o",
        ".............",
        "..#...b...#..",
        ".m.........m.",
        "......#......",
        "..#.......#..",
        ".............",
        ".............",
        "o...........o",
    } },
    { id = "twin_ponds", minRoom = 1, grid = {
        ".....m.m.....",
        ".............",
        ".~~~.....~~~.",
        ".~~~..#..~~~.",
        "..m.......m..",
        "......b......",
        "..#.......#..",
        "o...........o",
        ".............",
    } },
    { id = "bunkers", minRoom = 1, grid = {
        "o...m...m...o",
        ".............",
        ".##.......##.",
        ".#...m.m...#.",
        ".............",
        "....^^.^^....",
        ".#.........#.",
        ".##...b...##.",
        ".............",
    } },
    { id = "river", minRoom = 1, grid = {
        "...m.....m...",
        "..m.......m..",
        ".............",
        "~~~~~.#.~~~~~",
        "~~~~~...~~~~~",
        "...b.....b...",
        "..#.......#..",
        ".............",
        "o...........o",
    } },
    { id = "hazard_field", minRoom = 1, grid = {
        "o....m.m....o",
        ".............",
        ".hhh.....hhh.",
        ".hhh..#..hhh.",
        "......m......",
        "..#.......#..",
        "....hhhhh....",
        ".............",
        ".............",
    } },
    { id = "spike_corridor", minRoom = 1, grid = {
        "o....m.m....o",
        ".............",
        "..###...###..",
        "..^^^...^^^..",
        ".m....b....m.",
        "..^^^...^^^..",
        "..###...###..",
        ".............",
        ".............",
    } },
    { id = "cross", minRoom = 1, grid = {
        "o....m.m....o",
        ".............",
        "..m...#...m..",
        "......#......",
        "..###...###..",
        "......#......",
        ".b....#....b.",
        ".............",
        ".............",
    } },
    { id = "islands", minRoom = 1, grid = {
        "..m.......m..",
        ".~~~.....~~~.",
        ".~m~.....~m~.",
        ".~~~..o..~~~.",
        "......#......",
        "....#...#....",
        "..b.......b..",
        ".............",
        "o...........o",
    } },
    { id = "maze_light", minRoom = 11, grid = {
        "o...m...m...o",
        ".####...####.",
        ".............",
        "...m.###.m...",
        ".............",
        ".####...####.",
        "......b......",
        "..^^.....^^..",
        ".............",
    } },
    { id = "diagonal", minRoom = 11, grid = {
        "o..........m.",
        ".#.......m...",
        "..#..........",
        "...#...m.....",
        "....#....#...",
        ".m.......#...",
        ".........#.b.",
        "..b..........",
        "o...........o",
    } },
    { id = "moat", minRoom = 11, grid = {
        "o....m.m....o",
        ".............",
        "...~~~.~~~...",
        ".m.~.....~.m.",
        "...~..m..~...",
        "...~~~.~~~...",
        ".............",
        "....b...b....",
        ".............",
    } },
    { id = "hazard_lanes", minRoom = 11, grid = {
        "o..m.....m..o",
        ".............",
        "hh..#...#..hh",
        "hh.........hh",
        "hh...m.m...hh",
        "hh.........hh",
        "....#.b.#....",
        ".............",
        ".............",
    } },
    { id = "fortress", minRoom = 11, grid = {
        "o...m...m...o",
        ".............",
        "..#.......#..",
        "..#..m.m..#..",
        "..###...###..",
        ".............",
        "....^.b.^....",
        ".............",
        ".............",
    } },
    { id = "checker", minRoom = 21, grid = {
        "o....m.m....o",
        "..#...#...#..",
        ".............",
        "m...#...#...m",
        ".............",
        "..#...#...#..",
        ".............",
        "....#...#....",
        ".b.........b.",
    } },
    { id = "gauntlet", minRoom = 21, grid = {
        ".m.........m.",
        ".###.....###.",
        ".#...^^^...#.",
        ".#..m...m..#.",
        ".#...^^^...#.",
        ".###.....###.",
        "o.....b.....o",
        ".............",
        ".............",
    } },
    { id = "lakes_center", minRoom = 21, grid = {
        "o...m...m...o",
        ".............",
        "..~~~...~~~..",
        "..~~~.#.~~~..",
        ".m.........m.",
        "..~~~...~~~..",
        "..~~~.b.~~~..",
        ".............",
        ".............",
    } },
    { id = "turret_nest", minRoom = 21, grid = {
        "o.m.......m.o",
        ".~~~~...~~~~.",
        ".............",
        "..#..m.m..#..",
        "..#.......#..",
        "......#......",
        "..b.......b..",
        "....^^.^^....",
        ".............",
    } },
    { id = "zigzag", minRoom = 21, grid = {
        "o.m.......m.o",
        ".............",
        "#####........",
        "........m....",
        "........#####",
        "..m..........",
        "#####...b....",
        ".............",
        ".............",
    } },
}

Rooms.ARENA = {
    { id = "arena_open", minRoom = 1, grid = {
        "o...........o",
        ".............",
        ".#.........#.",
        ".............",
        ".............",
        ".............",
        ".#.........#.",
        ".............",
        "o...........o",
    } },
    { id = "arena_ponds", minRoom = 1, grid = {
        "o...........o",
        ".~~.......~~.",
        ".~~.......~~.",
        ".............",
        ".............",
        ".............",
        ".~~.......~~.",
        ".~~.......~~.",
        ".............",
    } },
    { id = "arena_spikes", minRoom = 1, grid = {
        ".............",
        ".^^.......^^.",
        ".............",
        "#...........#",
        "#...........#",
        ".............",
        ".^^b.....b^^.",
        ".............",
        "o...........o",
    } },
    { id = "arena_hazard", minRoom = 1, grid = {
        "o...........o",
        ".............",
        ".hh.......hh.",
        ".hh.......hh.",
        ".............",
        "..#.......#..",
        ".............",
        "....hh.hh....",
        ".............",
    } },
}

-- Sanctuaires de l'Ange (salles 5, 15…) et du Démon (9, 19…) : salle d'un écran, sans
-- obstacle ; autel et décor viennent de src/render/sanctuary.lua
Rooms.SANCTUARY_W = 400
Rooms.SANCTUARY_H = 240
Rooms.SANCTUARY = {
    { id = "shrine", minRoom = 1, grid = {
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
    } },
}

-- Rooms of each world (chapter 1 forest, 2 desert, 3 crystal, 4 volcano, 5 sky, 6 void):
-- 4 per world, one "total" room covered by the world's hazard. 'h' is the world hazard
-- (plain ground in the forest). Damaging total rooms keep a hazard-free path and safe spawns.
Rooms.WORLDS = {
    [1] = {
        { id = "marsh", total = true, grid = {
            "o....m.m....o",
            ".~~~~...~~~~.",
            ".~~~~.m.~~~~.",
            "..m.......m..",
            "~~~~..#..~~~~",
            "~~~~.....~~~~",
            "..~~~...~~~..",
            "..~~~...~~~..",
            ".....o.o.....",
        } },
        { id = "stump_clearing", grid = {
            ".....m.m.....",
            "..#.......#..",
            "....#...#....",
            ".m....o....m.",
            "..#.......#..",
            "....#...#....",
            "......b......",
            "..#.......#..",
            ".............",
        } },
        { id = "winding_stream", grid = {
            "....m...m....",
            "~~~~~~.~~~~~~",
            "......m......",
            ".#.........#.",
            "~~~.~~~~~~~~~",
            ".....m.......",
            "~~~~~~~~~.~~~",
            ".............",
            ".............",
        } },
        { id = "grove", grid = {
            ".....m.m.....",
            ".###.....###.",
            ".............",
            "..m.#####.m..",
            ".............",
            ".###.....###.",
            "......o......",
            "....##.##....",
            ".............",
        } },
    },
    [2] = {
        { id = "sand_sea", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhh.hhhhhh",
            "hm.........mh",
            "hh.hhh.hhh.hh",
            "hh.hh#.#hh.hh",
            "hh.hhh.hhh.hh",
            "hh.........hh",
            "hhhhhh.hhhhhh",
            "hhhhhh.hhhhhh",
        } },
        { id = "oasis", grid = {
            ".....m.m.....",
            "..hh.....hh..",
            ".m.#.~~~.#.m.",
            "...~~~~~~~...",
            "..#~~~~~~~#..",
            "...~~~~~~~...",
            "..h.#...#.h..",
            "..hh.....hh..",
            ".............",
        } },
        { id = "canyon", grid = {
            ".....m.m.....",
            "..###...###..",
            "..#.......#..",
            "..#.m...m.#..",
            "......h......",
            "..#..hhh..#..",
            "..#.......#..",
            "..###...###..",
            ".............",
        } },
        { id = "dunes", grid = {
            "hh...m.m.....",
            ".hh.......#..",
            "..hh..m......",
            "...hh....hh..",
            ".#..hh..hh...",
            ".m...hhhh..m.",
            "......hh.....",
            "...#.....hh..",
            "..........hh.",
        } },
    },
    [3] = {
        { id = "ice_rink", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhhhhhhhhh",
            "hhm#hhhhh#mhh",
            "hhhhhhhhhhhhh",
            "hhhhh#h#hhhhh",
            "hhmhhhhhhhmhh",
            "hh#hhhhhhh#hh",
            "hhhhhhhhhhhhh",
            "hhhhhh.hhhhhh",
        } },
        { id = "frozen_lake", grid = {
            ".....m.m.....",
            ".hhhhhhhhhhh.",
            ".hh~~~~~~~hh.",
            ".hh~~~~~~~hh.",
            ".m..~~~~~..m.",
            ".hh~~~~~~~hh.",
            ".hhhhhhhhhhh.",
            "..#.......#..",
            ".............",
        } },
        { id = "crystal_forest", grid = {
            ".....m.m.....",
            "..#.......#..",
            ".m....h....m.",
            "....#...#....",
            "..#..hhh..#..",
            ".m..#...#..m.",
            "......h......",
            "..#.......#..",
            ".............",
        } },
        { id = "ice_lanes", grid = {
            ".....m.m.....",
            "hhhhhhhhhhhhh",
            "....#...#....",
            "hhhhhhhhhhhhh",
            ".m....b....m.",
            "hhhhhhhhhhhhh",
            "...#.....#...",
            "hhhhhhhhhhhhh",
            ".............",
        } },
    },
    [4] = {
        { id = "lava_rivers", total = true, grid = {
            "...m.....m...",
            "hhhhh...hhhhh",
            "h..hh...hh..h",
            "..m.......m..",
            "hhhhh...hhhhh",
            "hhhhh...hhhhh",
            "..b.......b..",
            "hhhh.....hhhh",
            "hhhh.....hhhh",
        } },
        { id = "caldera", grid = {
            ".....m.m.....",
            "..hhhhhhhhh..",
            ".mh.......hm.",
            "..h..#.#..h..",
            "..h...m...h..",
            "..hhhh.hhhh..",
            ".............",
            "..#.......#..",
            ".............",
        } },
        { id = "lava_flows", grid = {
            ".....m.m.....",
            "hh...........",
            ".hhh....#..m.",
            "...hhh.......",
            ".m...hhh..#..",
            "...#...hhh...",
            ".........hhh.",
            "...........hh",
            ".............",
        } },
        { id = "forge", grid = {
            ".....m.m.....",
            "..b.......b..",
            ".hh..#.#..hh.",
            ".hh.......hh.",
            "...m..b..m...",
            ".hh.......hh.",
            ".hh..#.#..hh.",
            "..b.......b..",
            ".............",
        } },
    },
    [5] = {
        { id = "storm", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhhhhhhhhh",
            "hhm#hhhhh#mhh",
            "hhhhhh.hhhhhh",
            ".....h.h.....",
            "hhmhhhhhhhmhh",
            "hhhhhhhhhhhhh",
            "hh#hhhhhhh#hh",
            "hhhhhh.hhhhhh",
        } },
        { id = "archipelago", grid = {
            ".....m.m.....",
            ".~~~.....~~~.",
            ".~~~.~~~.~~~.",
            ".m...hhh...m.",
            "~~~.~~.~~.~~~",
            "...m.....m...",
            ".~~~.~~~.~~~.",
            ".~~~.....~~~.",
            ".............",
        } },
        { id = "wind_corridor", grid = {
            ".....m.m.....",
            "hh..#...#..hh",
            "hh.........hh",
            "hhm..#.#..mhh",
            "hh.........hh",
            "hh.m.....m.hh",
            "hh..#...#..hh",
            "hh.........hh",
            ".............",
        } },
        { id = "floating_temple", grid = {
            ".....m.m.....",
            ".#.........#.",
            "...#.....#...",
            ".m...h.h...m.",
            "..#..~~~..#..",
            "...m.....m...",
            "...#.....#...",
            ".#.........#.",
            ".............",
        } },
    },
    [6] = {
        { id = "fracture", total = true, grid = {
            "..m.......m..",
            "hh..h...h..hh",
            "hh..h...h..hh",
            ".............",
            ".m.........m.",
            "hh..h...h..hh",
            "hh..h...h..hh",
            ".............",
            ".............",
        } },
        { id = "spiral", grid = {
            ".....m.m.....",
            ".hhhhh..hhhh.",
            ".h.........h.",
            ".h.hhh.hh..h.",
            ".h.hm...h..h.",
            ".h.hhhhhh..h.",
            ".h.........h.",
            ".hhhh...hhhh.",
            ".............",
        } },
        { id = "eye", grid = {
            ".....m.m.....",
            ".............",
            "...hhhhhhh...",
            ".m.h.....h.m.",
            "...h..#..h...",
            "...hhh.hhh...",
            ".............",
            "..#.......#..",
            ".............",
        } },
        { id = "monoliths", grid = {
            ".....m.m.....",
            ".##.......##.",
            ".............",
            "...##.h.##...",
            ".m...hhh...m.",
            "...##.h.##...",
            ".............",
            ".##.......##.",
            ".............",
        } },
    },
}

local POOLS = { combat = Rooms.COMBAT, arena = Rooms.ARENA, sanctuary = Rooms.SANCTUARY }
-- Zone centrale (colonnes, lignes) qui doit rester libre pour le boss et les PNJ
local CENTER = { c0 = 5, c1 = 9, r0 = 3, r1 = 7 }
Rooms.CENTER = CENTER

-- Dimensions (en px) de la salle n : la grille plus les bandes de murs
function Rooms.roomSize(roomNumber)
    local sizes = Rooms.CELL_SIZES
    local cell = sizes[((roomNumber or 1) - 1) % #sizes + 1]
    return Rooms.COLS * cell + Rooms.MARGIN_X * 2,
           Rooms.ROWS * cell + Rooms.MARGIN_TOP + Rooms.MARGIN_BOTTOM
end

-- Taille de case et origine de la grille pour une salle de mapW x mapH (grille centrée
-- si la salle n'a pas été taillée par Rooms.roomSize)
function Rooms.fit(mapW, mapH)
    local innerH = mapH - Rooms.MARGIN_TOP - Rooms.MARGIN_BOTTOM
    local cell = math.min(math.floor((mapW - Rooms.MARGIN_X * 2) / Rooms.COLS),
                          math.floor(innerH / Rooms.ROWS))
    local ox = math.floor((mapW - Rooms.COLS * cell) / 2)
    local oy = Rooms.MARGIN_TOP + math.floor((innerH - Rooms.ROWS * cell) / 2)
    return cell, ox, oy
end

function Rooms.pool(kind)
    return POOLS[kind] or Rooms.COMBAT
end

function Rooms.byId(id)
    for _, pool in pairs(POOLS) do
        for _, layout in ipairs(pool) do
            if layout.id == id then return layout end
        end
    end
    return nil
end

-- Symétrie gauche-droite : double la variété sans nouvelle grille
function Rooms.mirror(grid)
    local out = {}
    for i, row in ipairs(grid) do out[i] = row:reverse() end
    return out
end

local ROOMS_PER_BLOCK = 10 -- un chapitre = 10 salles : 7 combats, ange (5e), démon (9e), boss (10e)
local ANGEL_SLOT = 5

-- Mélange de Fisher-Yates à graine fixe (LCG) : même bloc -> même ordre
local function shuffled(list, seed)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    local s = (seed * 2654435 + 12345) % 4294967296
    for i = #out, 2, -1 do
        s = (s * 1664525 + 1013904223) % 4294967296
        local j = math.floor(s / 4294967296 * i) + 1
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- Deterministic pick by room number: a resumed run finds the same room again.
-- Combat: the 7 combat slots of a chapter (rooms 1-4 and 6-8) get, when the world is
-- known, its 4 own rooms (the total one at slot 5, right after the angel) and 3 common
-- rooms; the common pool of the 10-room block is shuffled once, so no grid repeats within a
-- chapter. Every other room is played mirrored left-right.
local WORLD_SLOTS = { [2] = 1, [4] = 2, [5] = "total", [7] = 3 }
local COMMON_SLOTS = { [1] = 1, [3] = 2, [6] = 3 }

local function worldRooms(world)
    local total, others = nil, {}
    for _, l in ipairs(Rooms.WORLDS[world] or {}) do
        if l.total then total = l else others[#others + 1] = l end
    end
    return total, others
end

function Rooms.pick(kind, roomNumber, world)
    roomNumber = math.max(1, roomNumber or 1)
    local block = math.floor((roomNumber - 1) / ROOMS_PER_BLOCK)
    local slot = (roomNumber - 1) % ROOMS_PER_BLOCK + 1
    local firstRoom = block * ROOMS_PER_BLOCK + 1

    local eligible = {}
    for _, layout in ipairs(Rooms.pool(kind)) do
        if (layout.minRoom or 1) <= firstRoom then eligible[#eligible + 1] = layout end
    end
    if #eligible == 0 then eligible = { Rooms.pool(kind)[1] } end
    local n = #eligible

    if kind == "combat" then
        local combatIndex = slot > ANGEL_SLOT and slot - 1 or slot
        local mirrored = (combatIndex + block) % 2 == 0
        local total, others = worldRooms(world)
        local own = total and WORLD_SLOTS[combatIndex]
        if own == "total" then return total, mirrored end
        if own then return shuffled(others, block + 1)[own], mirrored end
        local index = (total and COMMON_SLOTS[combatIndex]) or combatIndex
        return shuffled(eligible, block + 1)[(index - 1) % n + 1], mirrored
    end
    -- Arenas and sanctuaries: simple rotation (boss rush chains neighbouring rooms)
    return eligible[(roomNumber - 1 + block) % n + 1], block % 2 == 1
end

-- Fusion gloutonne des cases identiques en rectangles (moins d'objets = collisions plus rapides)
local function mergeRects(grid, char)
    local rects, used = {}, {}
    for r = 1, #grid do
        used[r] = {}
    end
    for r = 1, #grid do
        local row = grid[r]
        for c = 1, #row do
            if row:sub(c, c) == char and not used[r][c] then
                local w = 1
                while c + w <= #row and row:sub(c + w, c + w) == char and not used[r][c + w] do
                    w = w + 1
                end
                local h = 1
                local canGrow = true
                while canGrow and r + h <= #grid do
                    for k = c, c + w - 1 do
                        if grid[r + h]:sub(k, k) ~= char or used[r + h][k] then
                            canGrow = false
                            break
                        end
                    end
                    if canGrow then h = h + 1 end
                end
                for rr = r, r + h - 1 do
                    for k = c, c + w - 1 do used[rr][k] = true end
                end
                rects[#rects + 1] = { col = c, row = r, w = w, h = h }
            end
        end
    end
    return rects
end

-- Voisinage de chaque case d'un rectangle (autotile) : la berge est dessinée DANS la case,
-- côté terre uniquement, pour que deux rectangles d'eau voisins se raccordent sans couture.
local NEIGHBOURS = {
    { "n", 0, -1 }, { "e", 1, 0 }, { "s", 0, 1 }, { "w", -1, 0 },
    { "ne", 1, -1 }, { "se", 1, 1 }, { "sw", -1, 1 }, { "nw", -1, -1 },
}

local function withNeighbours(grid, rects, char)
    local function same(col, row)
        local line = grid[row]
        return line ~= nil and line:sub(col, col) == char
    end
    for _, r in ipairs(rects) do
        local cells, key = {}, {}
        for dr = 0, r.h - 1 do
            for dc = 0, r.w - 1 do
                local c = { dc = dc, dr = dr }
                for _, nb in ipairs(NEIGHBOURS) do
                    c[nb[1]] = same(r.col + dc + nb[2], r.row + dr + nb[3])
                    key[#key + 1] = c[nb[1]] and "1" or "0"
                end
                cells[#cells + 1] = c
            end
        end
        r.cells = cells
        r.shapeKey = table.concat(key) -- identifie la forme pour le cache de textures
    end
    return rects
end

local function cellsOf(grid, char)
    local cells = {}
    for r = 1, #grid do
        local row = grid[r]
        for c = 1, #row do
            if row:sub(c, c) == char then cells[#cells + 1] = { col = c, row = r } end
        end
    end
    return cells
end

-- Grille -> listes en unités de cases (la conversion en pixels est faite par ObstacleManager)
function Rooms.parse(grid)
    return {
        rocks = mergeRects(grid, "#"),
        waters = withNeighbours(grid, mergeRects(grid, "~"), "~"),
        spikes = mergeRects(grid, "^"),
        hazards = mergeRects(grid, "h"),
        barrels = cellsOf(grid, "b"),
        pots = cellsOf(grid, "o"),
        spawns = cellsOf(grid, "m"),
    }
end

local function charAt(grid, col, row)
    local line = grid[row]
    return line and line:sub(col, col) or nil
end

-- Remplissage depuis l'entrée sud ; `passable(ch)` décide des cases traversables
local function flood(grid, passable)
    local seen = {}
    local startCol, startRow = GATE_COL, Rooms.ROWS
    if not passable(charAt(grid, startCol, startRow)) then return seen end
    local stack = { { startCol, startRow } }
    seen[startRow * 100 + startCol] = true
    while #stack > 0 do
        local cell = table.remove(stack)
        local neighbours = {
            { cell[1] + 1, cell[2] }, { cell[1] - 1, cell[2] },
            { cell[1], cell[2] + 1 }, { cell[1], cell[2] - 1 },
        }
        for _, nb in ipairs(neighbours) do
            local ch = charAt(grid, nb[1], nb[2])
            local key = nb[2] * 100 + nb[1]
            if ch and ch ~= "" and not seen[key] and passable(ch) then
                seen[key] = true
                stack[#stack + 1] = nb
            end
        end
    end
    return seen
end

local function walkable(ch) return ch ~= "#" and ch ~= "~" and ch ~= "b" end
local function notRock(ch) return ch ~= "#" end

-- Vérifie qu'une grille est jouable. Retourne true, ou false + message d'erreur.
function Rooms.validate(layout, kind)
    local grid = layout.grid
    local id = layout.id or "?"
    if #grid ~= Rooms.ROWS then
        return false, id .. ": " .. #grid .. " rows instead of " .. Rooms.ROWS
    end
    for r, row in ipairs(grid) do
        if #row ~= Rooms.COLS then
            return false, string.format("%s: row %d has %d cols instead of %d", id, r, #row, Rooms.COLS)
        end
        for c = 1, #row do
            local ch = row:sub(c, c)
            if not VALID_CHARS[ch] then
                return false, string.format("%s: unknown char '%s' at %d,%d", id, ch, c, r)
            end
        end
    end
    if charAt(grid, GATE_COL, 1) ~= "." or charAt(grid, GATE_COL, Rooms.ROWS) ~= "." then
        return false, id .. ": gate (top centre) and entry (bottom centre) cells must be floor"
    end
    local walk = flood(grid, walkable)
    if not walk[1 * 100 + GATE_COL] then
        return false, id .. ": gate is not reachable on foot from the entry"
    end
    -- Aucune poche scellée par des rochers : les tirs doivent pouvoir atteindre chaque case
    local open = flood(grid, notRock)
    for r = 1, Rooms.ROWS do
        for c = 1, Rooms.COLS do
            if notRock(charAt(grid, c, r)) and not open[r * 100 + c] then
                return false, string.format("%s: cell %d,%d is sealed off by rocks", id, c, r)
            end
        end
    end
    local parsed = Rooms.parse(grid)
    if #parsed.rocks > Rooms.MAX_ROCK_RECTS then
        return false, string.format("%s: %d rock blocks (max %d)", id, #parsed.rocks, Rooms.MAX_ROCK_RECTS)
    end
    for _, s in ipairs(parsed.spawns) do
        if s.row > Rooms.ROWS - 3 then
            return false, string.format("%s: spawn marker at %d,%d too close to the entry", id, s.col, s.row)
        end
    end
    if kind == "arena" or kind == "sanctuary" then
        for r = CENTER.r0, CENTER.r1 do
            for c = CENTER.c0, CENTER.c1 do
                if charAt(grid, c, r) ~= "." then
                    return false, string.format("%s: centre cell %d,%d must stay clear", id, c, r)
                end
            end
        end
    end
    return true
end

-- Valide toutes les grilles, en version normale et miroir. Retourne la liste des erreurs.
function Rooms.validateAll()
    local errors = {}
    for kind, pool in pairs(POOLS) do
        for _, layout in ipairs(pool) do
            for _, grid in ipairs({ layout.grid, Rooms.mirror(layout.grid) }) do
                local ok, err = Rooms.validate({ id = layout.id, grid = grid }, kind)
                if not ok then errors[#errors + 1] = err end
            end
        end
    end
    for _, pool in pairs(Rooms.WORLDS) do
        for _, layout in ipairs(pool) do
            for _, grid in ipairs({ layout.grid, Rooms.mirror(layout.grid) }) do
                local ok, err = Rooms.validate({ id = layout.id, grid = grid }, "combat")
                if not ok then errors[#errors + 1] = err end
            end
        end
    end
    return errors
end

return Rooms
