-- src/core/gpu.lua
-- Garde-fous du GPU PICA200 (LÖVE Potion 3.x) et outils de rendu portables.
--
-- Deux limites de LÖVE Potion sur 3DS causaient l'écran noir en combat :
--   1. Le tampon de sommets fait 6 * 0x1000 = 24576 sommets PAR IMAGE (les deux écrans,
--      et l'écran du haut compte double en 3D). Il n'est pas borné : le dépasser écrase
--      la mémoire linéaire (textures, framebuffers) -> écran noir ou gel.
--   2. SpriteBatch ignore setColor sur 3DS (couleur forcée à blanc opaque) : les aplats
--      teintés et translucides deviennent des rectangles blancs.
--
-- Ce module :
--   * estime le coût en sommets de chaque appel de dessin et, sur 3DS, refuse les appels
--     qui feraient déborder le tampon (on perd un détail au lieu de corrompre la mémoire) ;
--   * fournit Gpu.newBatch : un SpriteBatch qui respecte les couleurs partout ;
--   * expose des statistiques (sommets, appels) pour l'overlay de debug (touche F3 sur PC).

local Gpu = {}

Gpu.is3DS = (love._console == "3DS" or love._os == "3DS"
    or (love.graphics ~= nil and love.graphics.setActiveScreen ~= nil))

local guard = Gpu.is3DS -- le garde-fou ne coupe des dessins que sur 3DS (ou 3DS simulée)

-- Banc de test PC : `love . --sim3ds` applique les contraintes 3DS (budget, lots ordonnés)
function Gpu.simulate3DS()
    Gpu.is3DS = true
    guard = true
end

-- Capacité réelle du tampon moins une marge pour le texte d'erreur éventuel
Gpu.VERTEX_CAPACITY = 6 * 0x1000
Gpu.VERTEX_LIMIT = Gpu.VERTEX_CAPACITY - 1024

Gpu.frameSkipped = 0
Gpu.stats = { vertices = 0, calls = 0, skipped = 0, peak = 0, batched = 0 }

local g = love.graphics
local installed = false

-- Réserve `n` sommets ; renvoie false si l'appel doit être abandonné.
-- Chemin chaud (appelé à chaque dessin) : aucune branche de profilage ici.
local frameVertices = 0
local frameCalls = 0
local limit = Gpu.VERTEX_LIMIT
local function reserve(n)
    local total = frameVertices + n
    if guard and total > limit then
        Gpu.frameSkipped = Gpu.frameSkipped + 1
        return false
    end
    frameVertices = total
    frameCalls = frameCalls + 1
    return true
end

-- Variante profilée (banc PC `--profile`) : origine de l'appel dans le code du jeu
local function reserveProfiled(n)
    if not reserve(n) then return false end
    local lvl = 3
    local info = debug.getinfo(lvl, "Sl")
    while info and (info.short_src:find("gpu.lua") or info.short_src:find("sprite_atlas") or info.short_src:find("art.lua") or info.short_src:find("pixel_font") or info.short_src:find("skin.lua")) do
        lvl = lvl + 1
        info = debug.getinfo(lvl, "Sl")
    end
    local key = info and (info.short_src .. ":" .. info.currentline) or "?"
    local prof = Gpu.profile
    local e = prof[key]
    if not e then e = { 0, 0 }; prof[key] = e end
    e[1] = e[1] + 1
    e[2] = e[2] + n
    return true
end
Gpu.reserve = reserve

local function ellipsePoints(r)
    local p = math.sqrt(math.max(r, 0) * 20)
    if p < 8 then p = 8 end
    return math.floor(p)
end

-- Début d'image : appelé une fois par image avant le premier écran
function Gpu.beginFrame()
    local st = Gpu.stats
    st.vertices = frameVertices
    st.calls = frameCalls
    st.skipped = Gpu.frameSkipped
    st.batched = Gpu.batchedSprites or 0
    Gpu.batchedSprites = 0
    if frameVertices > st.peak then st.peak = frameVertices end
    frameVertices = 0
    frameCalls = 0
    Gpu.frameSkipped = 0
end

-- ============================================================================
-- Auto-batcher : les sprites de l'atlas dessinés en blanc opaque à la suite sont fusionnés
-- dans un SpriteBatch et envoyés en UN appel. Sur 3DS chaque appel de dessin coûte
-- ~40 µs de processeur (allocations dans LÖVE Potion) : c'est le vrai goulot des FPS.
-- Le lot est vidé dès qu'un autre dessin, un changement de transformation ou d'écran arrive,
-- donc l'ordre de superposition est strictement conservé.
-- ============================================================================
local AUTO_SIZE = 512
local auto = nil        -- SpriteBatch réutilisé
local autoImage = nil   -- texture de l'atlas (Art.image)
local autoCount = 0
local colorIsWhite = true
local rawDraw = nil
local rawSetColor = nil
local cr, cg, cb, ca = 1, 1, 1, 1 -- couleur courante (suivie par l'enveloppe de setColor)

-- ============================================================================
-- Enregistrement : pendant Gpu.beginRecord(sb) … Gpu.endRecord(), les sprites blancs de
-- l'atlas sont ajoutés au SpriteBatch `sb` (persistant) au lieu d'être dessinés. Toute
-- autre primitive est ignorée : le contenu enregistré doit être fait de sprites
-- (pixels pré-colorés, glyphes, icônes). Sert aux parties fixes de l'interface, affichées
-- ensuite en 1 seul appel GPU tant qu'elles ne changent pas.
-- ============================================================================
local recordSB = nil

function Gpu.isRecording()
    return recordSB ~= nil
end

function Gpu.setAutoBatchImage(image)
    autoImage = image
    auto = nil
    autoCount = 0
end

local function flush()
    if autoCount == 0 or recordSB then return end
    local n = autoCount
    autoCount = 0
    local cost = n * 6
    if guard and frameVertices + cost > limit then
        Gpu.frameSkipped = Gpu.frameSkipped + 1
        auto:clear()
        return
    end
    frameVertices = frameVertices + cost
    frameCalls = frameCalls + 1
    Gpu.batchedSprites = (Gpu.batchedSprites or 0) + n
    local prof = Gpu.profile
    if prof then
        local lvl, info = 3, debug.getinfo(3, "Sl")
        while info and (info.short_src:find("gpu.lua") or info.short_src:find("skin.lua") or info.short_src:find("pixel_font")) do
            lvl = lvl + 1
            info = debug.getinfo(lvl, "Sl")
        end
        local key = "FLUSH " .. (info and (info.short_src .. ":" .. info.currentline) or "?")
        local e = prof[key]
        if not e then e = { 0, 0 }; prof[key] = e end
        e[1] = e[1] + 1
        e[2] = e[2] + n
    end
    -- Le lot contient des sprites blancs : la couleur courante (qui a pu changer depuis leur
    -- ajout, ex. une ombre teintée) ne doit pas les teinter au moment du dessin.
    if colorIsWhite then
        rawDraw(auto)
    else
        rawSetColor(1, 1, 1, 1)
        rawDraw(auto)
        rawSetColor(cr, cg, cb, ca)
    end
    auto:clear()
end
Gpu.flush = flush

-- Chemin direct pour les sprites de l'atlas (personnages, lettres, pixels pré-colorés) :
-- même effet que love.graphics.draw(image, quad, …) mais sans l'enveloppe générique, dont le
-- coût Lua par sprite comptait sur Old 3DS.
function Gpu.addSprite(image, quad, x, y, r, sx, sy, ox, oy)
    if image ~= autoImage or not colorIsWhite then
        return g.draw(image, quad, x, y, r, sx, sy, ox, oy)
    end
    if recordSB then
        recordSB:add(quad, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    if not auto then auto = g.newSpriteBatch(autoImage, AUTO_SIZE, "stream") end
    auto:add(quad, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    autoCount = autoCount + 1
    if autoCount >= AUTO_SIZE then flush() end
end

function Gpu.beginRecord(sb)
    flush()
    sb:clear()
    recordSB = sb
end

function Gpu.endRecord()
    recordSB = nil
end

-- Enveloppe les fonctions de dessin de love.graphics (idempotent)
function Gpu.install()
    if installed or not g then return end
    installed = true
    local reserve = Gpu.profile and reserveProfiled or reserve

    rawDraw = g.draw

    rawSetColor = g.setColor
    g.setColor = function(r, gr, b, a)
        if type(r) == "table" then
            r, gr, b, a = r[1], r[2], r[3], r[4]
        end
        a = a or 1
        -- Couleur inchangée (cas le plus fréquent : remise au blanc) : aucun appel C
        if r == cr and gr == cg and b == cb and a == ca then return end
        cr, cg, cb, ca = r, gr, b, a
        colorIsWhite = (r == 1 and gr == 1 and b == 1 and a == 1)
        return rawSetColor(r, gr, b, a)
    end

    g.draw = function(obj, a, ...)
        if recordSB then
            if obj == autoImage and colorIsWhite and type(a) == "userdata" then recordSB:add(a, ...) end
            return
        end
        if obj == autoImage and colorIsWhite and type(a) == "userdata" then
            if not auto then auto = g.newSpriteBatch(autoImage, AUTO_SIZE, "stream") end
            auto:add(a, ...)
            autoCount = autoCount + 1
            if autoCount >= AUTO_SIZE then flush() end
            return
        end
        if autoCount > 0 then flush() end
        local cost = 4
        if type(obj) == "userdata" and obj.typeOf and obj:typeOf("SpriteBatch") then
            cost = obj:getCount() * 6
        end
        if reserve(cost) then return rawDraw(obj, a, ...) end
    end

    -- Toute primitive ou changement d'état qui affecte le rendu vide d'abord le lot
    local function flushing(name)
        local raw = g[name]
        if not raw then return end
        g[name] = function(...)
            if autoCount > 0 then flush() end
            return raw(...)
        end
    end
    for _, name in ipairs({ "push", "pop", "translate", "scale", "rotate", "shear", "origin",
        "applyTransform", "replaceTransform", "setScissor", "intersectScissor", "setCanvas",
        "setActiveScreen", "setScreen", "present", "clear", "setBlendMode", "setShader",
        "setColorMask", "stencil", "setStencilTest" }) do
        flushing(name)
    end

    local rawRect = g.rectangle
    g.rectangle = function(mode, x, y, w, h, rx, ...)
        if recordSB then return end
        if autoCount > 0 then flush() end
        local cost = (mode == "line") and 24 or 4
        if rx and rx > 0 then cost = cost + 16 end
        if reserve(cost) then return rawRect(mode, x, y, w, h, rx, ...) end
    end

    local rawCircle = g.circle
    g.circle = function(mode, x, y, r, seg)
        if recordSB then return end
        if autoCount > 0 then flush() end
        local n = seg or ellipsePoints(r)
        local cost = (mode == "line") and n * 6 or n + 2
        if reserve(cost) then return rawCircle(mode, x, y, r, seg) end
    end

    local rawEllipse = g.ellipse
    if rawEllipse then
        g.ellipse = function(mode, x, y, rx, ry, seg)
            if autoCount > 0 then flush() end
            local n = seg or ellipsePoints((rx + (ry or rx)) / 2)
            local cost = (mode == "line") and n * 6 or n + 2
            if reserve(cost) then return rawEllipse(mode, x, y, rx, ry, seg) end
        end
    end

    local rawArc = g.arc
    if rawArc then
        g.arc = function(mode, ...)
            if recordSB then return end
            if autoCount > 0 then flush() end
            if reserve(48) then return rawArc(mode, ...) end
        end
    end

    local rawPolygon = g.polygon
    g.polygon = function(mode, ...)
        if recordSB then return end
        if autoCount > 0 then flush() end
        local n = select("#", ...)
        local first = ...
        if type(first) == "table" then n = #first end
        local pts = math.floor(n / 2)
        local cost = (mode == "line") and pts * 6 or pts + 1
        if reserve(cost) then return rawPolygon(mode, ...) end
    end

    local rawLine = g.line
    g.line = function(...)
        if recordSB then return end
        if autoCount > 0 then flush() end
        local n = select("#", ...)
        local first = ...
        if type(first) == "table" then n = #first end
        local cost = math.max(1, math.floor(n / 2) - 1) * 8
        if reserve(cost) then return rawLine(...) end
    end

    local rawPoints = g.points
    if rawPoints then
        g.points = function(...)
            if autoCount > 0 then flush() end
            if reserve(8) then return rawPoints(...) end
        end
    end

    local rawPrint = g.print
    g.print = function(text, ...)
        if autoCount > 0 then flush() end
        local str = tostring(text or "")
        if reserve(#str * 6) then return rawPrint(text, ...) end
    end

    local rawPrintf = g.printf
    g.printf = function(text, ...)
        if autoCount > 0 then flush() end
        local str = tostring(text or "")
        if reserve(#str * 6) then return rawPrintf(text, ...) end
    end
end

-- ============================================================================
-- Batch portable : couleurs et ordre de dessin respectés partout
-- ============================================================================
-- Sur PC : SpriteBatch LÖVE classique (setColor fonctionne).
-- Sur 3DS : les entrées sont mémorisées dans l'ordre (tableau plat réutilisé, zéro allocation
-- par image). Au dessin :
--   * lot "dynamic" : chaque sprite est dessiné avec son setColor (4 sommets, même texture) ;
--   * lot "static"  : compilé une fois en segments ; les suites de sprites blancs opaques
--     deviennent un vrai SpriteBatch (1 appel), les sprites teintés restent individuels.
local Batch = {}
Batch.__index = Batch

local function isPlain(e)
    return e[9] == 1 and e[10] == 1 and e[11] == 1 and e[12] == 1
end

function Gpu.newBatch(image, size, usage)
    local self = setmetatable({}, Batch)
    self.image = image
    self.size = size or 256
    self.static = (usage == "static")
    self.split = Gpu.is3DS
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
    if self.split then
        self.entries = {}
        self.count = 0
        self.segments = nil
        self.sbPool = {}
    else
        self.sb = g.newSpriteBatch(image, self.size, usage or "dynamic")
        self.count = 0
    end
    return self
end

function Batch:clear()
    self.count = 0
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
    if self.split then
        self.segments = nil
    else
        self.sb:clear()
        self.sb:setColor(1, 1, 1, 1)
    end
end

function Batch:setColor(r, gr, b, a)
    self.r, self.g, self.b, self.a = r or 1, gr or 1, b or 1, a or 1
    if not self.split then self.sb:setColor(self.r, self.g, self.b, self.a) end
end

function Batch:add(quad, x, y, rot, sx, sy, ox, oy)
    if self.count >= self.size then return end
    self.count = self.count + 1
    if not self.split then
        self.sb:add(quad, x, y, rot or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    local e = self.entries[self.count]
    if not e then
        e = {}
        self.entries[self.count] = e
    end
    e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8] = quad, x, y, rot or 0, sx or 1, sy or 1, ox or 0, oy or 0
    e[9], e[10], e[11], e[12] = self.r, self.g, self.b, self.a
    self.segments = nil
end

function Batch:getCount()
    return self.count
end

-- Regroupe les entrées statiques en segments { sb = SpriteBatch } ou { from, to } (teintés)
function Batch:compile()
    local segs = {}
    local used = 0
    local i = 1
    local list = self.entries
    while i <= self.count do
        local e = list[i]
        if isPlain(e) then
            used = used + 1
            local sb = self.sbPool[used]
            if not sb then
                sb = g.newSpriteBatch(self.image, self.size, "static")
                self.sbPool[used] = sb
            end
            sb:clear()
            while i <= self.count and isPlain(list[i]) do
                local p = list[i]
                sb:add(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
                i = i + 1
            end
            segs[#segs + 1] = { sb = sb }
        else
            local from = i
            while i <= self.count and not isPlain(list[i]) do i = i + 1 end
            segs[#segs + 1] = { from = from, to = i - 1 }
        end
    end
    self.segments = segs
end

local function drawEntries(img, list, from, to)
    for i = from, to do
        local e = list[i]
        g.setColor(e[9], e[10], e[11], e[12])
        g.draw(img, e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8])
    end
end

function Batch:draw()
    if self.count == 0 then return end
    if not self.split then
        g.setColor(1, 1, 1, 1)
        g.draw(self.sb)
        return
    end
    if self.static then
        if not self.segments then self:compile() end
        for _, seg in ipairs(self.segments) do
            if seg.sb then
                g.setColor(1, 1, 1, 1)
                g.draw(seg.sb)
            else
                drawEntries(self.image, self.entries, seg.from, seg.to)
            end
        end
    else
        drawEntries(self.image, self.entries, 1, self.count)
    end
    g.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- Lot découpé en tuiles et en couches (décor statique) : seul ce que voit la caméra est dessiné
-- ============================================================================
-- Couches : l'ordre des couches est global (toutes les tuiles de la couche 1, puis de la 2...),
-- donc un motif qui déborde sur la tuile voisine n'est jamais recouvert par le fond de celle-ci.
-- Les grands aplats (addRect) sont découpés aux bords des tuiles.
local Chunked = {}
Chunked.__index = Chunked

function Gpu.newChunkedBatch(image, chunkSize, perChunk)
    local self = setmetatable({}, Chunked)
    self.image = image
    self.chunk = chunkSize or 128
    self.perChunk = perChunk or 160
    self.layers = {}
    self.layer = 1
    self.cols, self.rows = 0, 0
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
    return self
end

function Chunked:reset(worldW, worldH, originX, originY)
    self.ox = originX or -64
    self.oy = originY or -64
    self.cols = math.max(1, math.ceil((worldW - self.ox + 64) / self.chunk))
    self.rows = math.max(1, math.ceil((worldH - self.oy + 96) / self.chunk))
    -- pairs et non ipairs : la table des tuiles est creuse (index = ligne * colonnes + col),
    -- ipairs s'arrêtait au premier trou et laissait les tuiles de la salle précédente à l'écran
    for _, cells in pairs(self.layers) do
        for _, c in pairs(cells) do c:clear() end
    end
    self.layer = 1
    self.maxLayer = 1
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
end

function Chunked:setLayer(n)
    self.layer = n
    if n > self.maxLayer then self.maxLayer = n end
end

function Chunked:setColor(r, gr, b, a)
    self.r, self.g, self.b, self.a = r or 1, gr or 1, b or 1, a or 1
end

function Chunked:cell(cx, cy)
    local cells = self.layers[self.layer]
    if not cells then
        cells = {}
        self.layers[self.layer] = cells
    end
    local idx = cy * self.cols + cx + 1
    local c = cells[idx]
    if not c then
        c = Gpu.newBatch(self.image, self.perChunk, "static")
        cells[idx] = c
    end
    return c
end

function Chunked:cellCoords(x, y)
    local cx = math.floor((x - self.ox) / self.chunk)
    local cy = math.floor((y - self.oy) / self.chunk)
    if cx < 0 then cx = 0 elseif cx >= self.cols then cx = self.cols - 1 end
    if cy < 0 then cy = 0 elseif cy >= self.rows then cy = self.rows - 1 end
    return cx, cy
end

function Chunked:add(quad, x, y, rot, sx, sy, ox, oy)
    local c = self:cell(self:cellCoords(x, y))
    c:setColor(self.r, self.g, self.b, self.a)
    c:add(quad, x, y, rot, sx, sy, ox, oy)
end

-- Aplat rectangulaire (quad d'un pixel étiré) découpé aux bords des tuiles
function Chunked:addRect(quad, x, y, w, h)
    local cs = self.chunk
    local x1, y1 = x + w, y + h
    local cy = y
    while cy < y1 do
        local rowEnd = self.oy + (math.floor((cy - self.oy) / cs) + 1) * cs
        local ny = math.min(y1, rowEnd)
        local cx = x
        while cx < x1 do
            local colEnd = self.ox + (math.floor((cx - self.ox) / cs) + 1) * cs
            local nx = math.min(x1, colEnd)
            self:add(quad, cx, cy, 0, nx - cx, ny - cy, 0, 0)
            cx = nx
        end
        cy = ny
    end
end

function Chunked:getCount()
    local n = 0
    for _, cells in pairs(self.layers) do
        for _, c in pairs(cells) do n = n + c:getCount() end
    end
    return n
end

-- Dessine les tuiles qui recoupent le rectangle monde [x0, x1] x [y0, y1]
function Chunked:drawView(x0, y0, x1, y1, margin)
    margin = margin or 40
    local cs = self.chunk
    local c0 = math.max(0, math.floor((x0 - margin - self.ox) / cs))
    local c1 = math.min(self.cols - 1, math.floor((x1 + margin - self.ox) / cs))
    local r0 = math.max(0, math.floor((y0 - margin - self.oy) / cs))
    local r1 = math.min(self.rows - 1, math.floor((y1 + margin - self.oy) / cs))
    for l = 1, self.maxLayer do
        local cells = self.layers[l]
        if cells then
            for r = r0, r1 do
                for c = c0, c1 do
                    local cell = cells[r * self.cols + c + 1]
                    if cell then cell:draw() end
                end
            end
        end
    end
end

return Gpu
