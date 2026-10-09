-- src/ui/hud.lua
-- Combat touch screen (320x240), built for the 3DS:
--   * top bar: level, experience, gold, pause
--   * hero strip: portrait, HP, combat stats, kills
--   * floor path of the current world (angel, champion, devil and boss floors)
--   * ultimate (L, left) and dash (R, right) as big touch buttons with charge rings
--   * room map in the middle, replaced by the boss panel during a boss fight
--   * acquired skills (touch a card = tooltip)
-- Icons and texts in white or in a baked colour are merged by the auto-batcher
-- (src/core/gpu.lua), so each zone draws its flat rects first, then its sprites.

local Config = require("src.data.config")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Skin = require("src.ui.skin")
local Art = require("src.render.art")
local Icons = require("src.render.sprites.icons")
local HeroSprites = require("src.render.sprites.heroes")
local Heroes = require("src.data.heroes")
local Skills = require("src.data.skills")
local Bestiary = require("src.data.bestiary")
local Perf = require("src.core.perf")
local WorldManager = require("src.core.world_manager")
local Gpu = require("src.core.gpu")
local PxColors = require("src.render.px_colors")
local Encounters = require("src.data.encounters")

-- Nearest named palette colour (theme colours are hexadecimal)
local nearestCache = {}
local function PxNearest(c)
    local key = math.floor(c[1] * 255) * 65536 + math.floor(c[2] * 255) * 256 + math.floor(c[3] * 255)
    local hit = nearestCache[key]
    if hit then return hit end
    local best, bestD = Palette.C.moss, math.huge
    for _, pc in pairs(PxColors.list()) do
        local dr, dg, db = pc[1] - c[1], pc[2] - c[2], pc[3] - c[3]
        local d = dr * dr + dg * dg + db * db
        if d < bestD then best, bestD = pc, d end
    end
    nearestCache[key] = best
    return best
end

local C = Palette.C
local floor = math.floor
local W, H = Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT

local HUD = {}
HUD.__index = HUD

local RARITY_THEME = {
    common = "gray", uncommon = "green", rare = "blue", epic = "purple", legendary = "gold", forbidden = "red",
}

-- Screen zones. Ultimate (L) sits on the left and dash (R) on the right, like the shoulder
-- buttons; the middle shows the room map, or the boss panel during a boss fight.
local HERO = { x = 4, y = 27, w = 312, h = 38 }
local TRACK = { x = 4, y = 67, w = 312, h = 30 }
local ULT = { x = 4, y = 99, w = 100, h = 100 }
local MAP = { x = 107, y = 99, w = 106, h = 100 }
local DASH = { x = 216, y = 99, w = 100, h = 100 }
local SKILLS = { x = 4, y = 201, w = 312, h = 37, slots = 10, step = 31 }
local XP_BAR = { x = 29, y = 6, w = 200, h = 13 }
local HP_BAR = { x = HERO.x + 113, y = HERO.y + 3, w = HERO.w - 117, h = 15 }
local BOSS_BAR = { x = MAP.x + 6, y = MAP.y + 30, w = MAP.w - 12, h = 16 }
local BUTTON_RADIUS = 28
local HP_NOTCHES = 10
local TOOLTIP_TIME = 2.5
local FLOORS = WorldManager.ROOMS_PER_WORLD

-- Floor path: special floors get a coloured node and an icon
local NODE_SPRITE = { angel = "npc_angel", devil = "npc_devil", champion = "icon_affix_enraged", boss = "icon_skull" }
local NODE_BG = { angel = C.navy, devil = C.wine, champion = C.plum, boss = C.wine }

-- Display name of a monster type (bestiary), cached
local monsterNames = {}
for _, m in ipairs(Bestiary.ENTRIES) do
    monsterNames[m.type] = m.name
end

function HUD.new()
    local self = setmetatable({}, HUD)
    self.displayXp = 0
    self.displayHp = 100
    self.displayBossHp = 1
    self.ultPulse = 0
    self.tooltip = nil
    self.tooltipTimer = 0
    self.skillView = {} -- acquired skills grouped by id: { skill, count }

    self.cards = {
        { x = 8,   y = 46, w = 96, h = 156 },
        { x = 112, y = 46, w = 96, h = 156 },
        { x = 216, y = 46, w = 96, h = 156 },
    }
    self.ultCircle = { cx = ULT.x + floor(ULT.w / 2), cy = ULT.y + 44, radius = BUTTON_RADIUS }
    self.dashCircle = { cx = DASH.x + floor(DASH.w / 2), cy = DASH.y + 44, radius = BUTTON_RADIUS }
    return self
end

function HUD:update(dt, player, ultCharge)
    if player then
        local targetXp = player.xp / player.nextLevelXp
        self.displayXp = self.displayXp + (targetXp - self.displayXp) * math.min(1.0, dt * 10)
        self.displayHp = self.displayHp + (player.hp - self.displayHp) * math.min(1.0, dt * 12)
    end
    if ultCharge >= 1.0 then
        self.ultPulse = self.ultPulse + dt * 8
    else
        self.ultPulse = 0
    end
    if self.tooltipTimer > 0 then
        self.tooltipTimer = self.tooltipTimer - dt
        if self.tooltipTimer <= 0 then self.tooltip = nil end
    end
end

-- ============================================================================
-- FULL DASHBOARD: recorded fixed layer + live layer
-- ============================================================================
-- On Old 3DS every draw operation costs (GPU call ~80 µs, and as much in Lua for a run of
-- sprites). The fixed layer (backgrounds, panels, labels, icons, pause button, room map,
-- floor path, skills) is recorded into a SpriteBatch (Gpu.beginRecord) and redrawn in 1
-- call while nothing changes. Only live values (gauges, counters, map dots, charge rings)
-- are drawn every time. The fixed layer must only use sprites: primitives (discs, arcs)
-- are not recorded.
local STATIC_FIELDS = { "heroId", "room", "chapter", "skills", "boss", "bossType", "dmg", "crit",
    "arrows", "dodge", "maxHp", "level", "gate", "ultReady", "mapW", "mapH", "theme", "mode", "wave" }

local function playerStats(player)
    local w = player.currentWeapon
    local dmg = floor(w.damage * (player.damageMult or 1.0))
    local arrows = (player.frontArrows or 1) + (player.diagArrows or 0) * 2 + (player.rearArrows or 0) + (player.sideArrows or 0) * 2
    return dmg, floor((player.critChance or 0) * 100), arrows, floor(player:effectiveDodge() * 100)
end

-- Reads the state behind the fixed layer; true if it must be recorded again
function HUD:staticChanged(game, boss)
    local st = self.staticState
    if not st then
        st = {}
        self.staticState = st
    end
    local player = game.player
    local dmg, crit, arrows, dodge = playerStats(player)
    local cur = self.staticCur or {}
    self.staticCur = cur
    cur.heroId = player.heroId
    cur.room = game.roomNumber or 1
    cur.chapter = game.currentChapter and game.currentChapter.name or false
    cur.skills = #(game.acquiredSkills or {})
    cur.boss = boss ~= nil
    cur.bossType = boss and boss.type or false
    cur.dmg, cur.crit, cur.arrows, cur.dodge = dmg, crit, arrows, dodge
    cur.maxHp = player.maxHp
    cur.level = player.level or 1
    cur.gate = game.isGateOpen and true or false
    cur.ultReady = (game.ultimateCharge or 0) >= 1.0
    cur.mapW, cur.mapH = game.mapW or 600, game.mapH or 460
    cur.theme = game.arena and game.arena.theme or false
    cur.mode = game.gameMode or "ascension"
    cur.wave = game.waveCount or 0
    local changed = false
    for _, k in ipairs(STATIC_FIELDS) do
        if st[k] ~= cur[k] then
            st[k] = cur[k]
            changed = true
        end
    end
    return changed
end

function HUD:drawDashboard(game, pauseBtn)
    local boss = self:findBoss(game)
    if not self.staticBatch then
        self.staticBatch = love.graphics.newSpriteBatch(Art.image, 3000, "static")
    end
    if self:staticChanged(game, boss) or self.staticPause ~= pauseBtn then
        self.staticPause = pauseBtn
        Perf.event("hud")
        Gpu.beginRecord(self.staticBatch)
        self:drawStatic(game, boss, pauseBtn)
        Gpu.endRecord()
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.staticBatch)
    Perf.sec("b:fixe")
    self:drawLive(game, boss)
    Perf.sec("b:vivant")
    if self.tooltip then self:drawTooltip(self.tooltip) end
end

-- Gauge: fixed frame / live fill (2 flat rects)
local function barFrame(x, y, w, h)
    Skin.roundRect(C.ink, x, y, w, h, 2)
    Skin.rect(C.night, x + 1, y + 1, w - 2, h - 2)
end

local function barFill(x, y, w, h, ratio, themeName)
    local fw = floor((w - 2) * math.max(0, math.min(1, ratio)) + 0.5)
    if fw <= 0 then return end
    local th = Skin.theme(themeName)
    Skin.rect(th.main, x + 1, y + 1, fw, h - 2)
    Skin.rect(th.light, x + 1, y + 1, fw, 1)
    Skin.rect(th.dark, x + 1, y + h - 2, fw, 1)
end

-- Notches every 1/n of a bar (drawn over the fill, so in the live layer)
local function barNotches(x, y, w, h, n)
    for i = 1, n - 1 do
        Skin.rect(C.ink, x + 1 + floor((w - 2) * i / n), y + 1, 1, h - 2, 0.5)
    end
end

-- ----------------------------------------------------------------------------
-- FIXED LAYER (recorded)
-- ----------------------------------------------------------------------------
function HUD:drawStatic(game, boss, pb)
    local cur = self.staticCur
    Skin.rect(C.night, 0, 0, W, H)
    self:drawTopBarStatic(cur, pb)
    self:drawHeroStatic(game.player, cur)
    self:drawTrackStatic(cur)
    self:drawActionsStatic(cur.ultReady)
    if boss then
        self:drawBossStatic(boss)
    else
        self:drawMinimapStatic(game)
    end
    self:drawSkillStrip(game.acquiredSkills)
end

-- Top bar: level badge, XP frame, coin, pause button
function HUD:drawTopBarStatic(cur, pb)
    Skin.rect(C.ink, 0, 0, W, 25)
    Skin.roundRect(C.cyan, 2, 1, 23, 23, 3)
    Skin.roundRect(C.navy, 3, 2, 21, 21, 3)
    Skin.roundRect(C.blue, 4, 3, 19, 18, 3)
    PixelFont.printf(tostring(cur.level), 2, 6, 23, "center", C.white, "main")
    barFrame(XP_BAR.x, XP_BAR.y, XP_BAR.w, XP_BAR.h)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, 240, 12)
    if pb then
        local oy = Skin.button(pb.x, pb.y, pb.w, pb.h, "blue", false)
        love.graphics.setColor(1, 1, 1, 1)
        Art.draw("icon_pause", 1, pb.x + floor(pb.w / 2), pb.y + oy + floor((pb.h - 3) / 2))
    end
end

-- Hero strip: portrait, name, HP frame, combat stats
function HUD:drawHeroStatic(player, cur)
    local x, y, w, h = HERO.x, HERO.y, HERO.w, HERO.h
    Skin.panel(x, y, w, h, "dark")
    Skin.roundRect(C.ink, x + 3, y + 3, 28, h - 6, 2)
    Skin.rect(C.moss, x + 4, y + 4, 26, h - 8)
    Skin.rect(C.pine, x + 4, y + h - 9, 26, 5)
    barFrame(HP_BAR.x, HP_BAR.y, HP_BAR.w, HP_BAR.h)

    local hero = Heroes.get(player.heroId)
    PixelFont.print(hero.name:upper(), x + 36, y + 5, C.yellow, "main")
    love.graphics.setColor(1, 1, 1, 1)
    local px, py = x + 17, y + h - 7
    local variant = (player.heroId ~= "atreus") and player.heroId or nil
    Art.drawEx("hero_body", 1, px, py, 0, 1, 1, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[player.heroId]
    if acc then
        local o = HeroSprites.ACCESSORY_OFFSETS[acc]
        Art.drawEx("hero_acc_" .. acc, 1, px + o[1], py + o[2], 0, 1, 1)
    end
    Art.draw("icon_heart", 1, x + 106, y + 10)
    Art.draw("icon_sword", 1, x + 41, y + 27)
    Art.draw("icon_star", 1, x + 101, y + 27)
    Art.draw("icon_skill_multishot", 1, x + 169, y + 27)
    Art.draw("icon_skill_boots", 1, x + 223, y + 27)
    Art.draw("icon_skull", 1, x + 279, y + 27)
    PixelFont.print(tostring(cur.dmg), x + 49, y + 21, C.white, "main")
    PixelFont.print(cur.crit .. "%", x + 109, y + 21, C.white, "main")
    PixelFont.print("×" .. cur.arrows, x + 177, y + 21, C.white, "main")
    PixelFont.print(cur.dodge .. "%", x + 231, y + 21, C.white, "main")
end

-- Kind of a floor on the path: combat, angel, champion, devil or boss
local function floorKind(mode, room)
    if mode == "boss_rush" then return "boss" end
    local t = WorldManager.getRoomType(room)
    if t ~= "combat" then return t end
    if Encounters.isChampionRoom(room) then return "champion" end
    return "combat"
end

-- Header of the floor path: mode or world on the left, progress on the right
local function trackLabels(cur)
    local room, mode = cur.room, cur.mode
    if mode == "boss_rush" then return "BOSS RUSH", "BOSS " .. room end
    if mode == "survival" then return "ARENA", "WAVE " .. cur.wave end
    local total = WorldManager.floorTotal(mode, room)
    return string.format("WORLD %d/%d", WorldManager.worldOfRoom(room), #WorldManager.CHAPTERS),
        "FLOOR " .. room .. (total and ("/" .. total) or "")
end

-- Floor path of the current world (10 floors: angel 5, champion 7, devil 9, boss 10)
function HUD:drawTrackStatic(cur)
    local x, y, w, h = TRACK.x, TRACK.y, TRACK.w, TRACK.h
    Skin.panel(x, y, w, h, "dark")
    local left, right = trackLabels(cur)
    PixelFont.print(left, x + 6, y + 4, C.fog, "tiny")
    PixelFont.printf(cur.chapter or "", x, y + 4, w, "center", C.cyan, "tiny")
    PixelFont.printf(right, x + w - 96, y + 4, 90, "right", C.white, "tiny")
    if cur.mode == "survival" then return end

    local slot = (cur.room - 1) % FLOORS + 1
    local first = cur.room - slot + 1
    local x0, ly = x + 14, y + h - 11
    local step = (w - 30) / (FLOORS - 1)
    Skin.rect(C.slate, x0, ly, w - 30, 2)
    if slot > 1 then Skin.rect(C.leaf, x0, ly, floor(step * (slot - 1)), 2) end
    for i = 1, FLOORS do
        local nx = floor(x0 + step * (i - 1))
        local kind = floorKind(cur.mode, first + i - 1)
        local ring = (i == slot) and C.yellow or ((i < slot) and C.leaf or C.ink)
        if kind == "combat" then
            Skin.roundRect(C.ink, nx - 5, ly - 4, 11, 11, 3)
            Skin.roundRect(ring == C.ink and C.slate or ring, nx - 4, ly - 3, 9, 9, 3)
        else
            local r = (kind == "boss") and 9 or 8
            Skin.roundRect(ring, nx - r, ly + 1 - r, r * 2 + 1, r * 2 + 1, 3)
            Skin.roundRect(NODE_BG[kind], nx - r + 1, ly + 2 - r, r * 2 - 1, r * 2 - 1, 3)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, FLOORS do
        local spr = NODE_SPRITE[floorKind(cur.mode, first + i - 1)]
        if spr then
            local nx = floor(x0 + step * (i - 1))
            -- angel / devil sprites are anchored at their feet
            local dy = (spr == "npc_angel" or spr == "npc_devil") and 8 or 0
            Art.draw(spr, 1, nx, ly + 1 + dy)
        end
    end
end

function HUD:minimapFrame(game)
    local m = MAP
    local mapW, mapH = game.mapW or 600, game.mapH or 460
    local s = math.min((m.w - 12) / mapW, (m.h - 12) / mapH)
    local ox = floor(m.x + (m.w - mapW * s) / 2)
    local oy = floor(m.y + (m.h - mapH * s) / 2)
    return s, ox, oy, mapW, mapH
end

function HUD:drawMinimapStatic(game)
    local m = MAP
    Skin.panel(m.x, m.y, m.w, m.h, "dark")
    local s, ox, oy, mapW, mapH = self:minimapFrame(game)
    local theme = game.arena and game.arena.theme
    local ground = C.moss
    if theme and theme.groundDark then
        -- off-palette colour: take the nearest named ground tone
        ground = PxNearest(Palette.hex(theme.groundDark))
    end
    Skin.rect(C.ink, ox - 1, oy - 1, floor(mapW * s) + 2, floor(mapH * s) + 2)
    Skin.rect(ground, ox, oy, floor(mapW * s), floor(mapH * s))
    local om = game.obstacleManager
    if om then
        for _, r in ipairs(om.waters or {}) do
            Skin.rect(C.navy, ox + floor(r.x * s), oy + floor(r.y * s), math.max(1, floor(r.w * s)), math.max(1, floor(r.h * s)))
        end
        for _, r in ipairs(om.hazards or {}) do
            local col = (r.kind == "lava") and C.orange or ((r.kind == "ice") and C.cyan or C.sand)
            Skin.rect(col, ox + floor(r.x * s), oy + floor(r.y * s), math.max(1, floor(r.w * s)), math.max(1, floor(r.h * s)))
        end
        for _, r in ipairs(om.rocks or {}) do
            Skin.rect(C.fog, ox + floor(r.x * s), oy + floor(r.y * s), math.max(2, floor(r.w * s)), math.max(2, floor(r.h * s)))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw(game.isGateOpen and "icon_mm_gate_open" or "icon_mm_gate_closed", 1, ox + floor(mapW * s / 2), oy + 3)
end

function HUD:findBoss(game)
    local pool = game.dummyPool
    if not pool then return nil end
    for i = 1, pool.activeCount do
        local d = pool.items[pool.activeList[i]]
        if d and d.alive and d.isBoss then return d end
    end
    return nil
end

-- Boss panel (replaces the map during a boss fight)
function HUD:drawBossStatic(boss)
    local x, y, w, h = MAP.x, MAP.y, MAP.w, MAP.h
    Skin.panel(x, y, w, h, "dark")
    Skin.roundRect(C.wine, x + 1, y + 1, w - 2, 14, 2)
    barFrame(BOSS_BAR.x, BOSS_BAR.y, BOSS_BAR.w, BOSS_BAR.h)
    PixelFont.printf("BOSS", x, y + 3, w, "center", C.white, "main")
    PixelFont.printf((monsterNames[boss.type] or boss.type or "?"):upper(), x + 2, y + 19, w - 4, "center", C.yellow, "tiny", 1, nil, 1)
    PixelFont.printf("DODGE (R)", x, y + h - 12, w, "center", C.silver, "tiny")
end

-- ============================================================================
-- ACQUIRED SKILLS (fixed layer): one card per skill, ×n when picked several times
-- ============================================================================
function HUD:refreshSkillView(skills)
    local view = self.skillView
    for i = #view, 1, -1 do view[i] = nil end
    local byId = {}
    for _, sk in ipairs(skills or {}) do
        local entry = byId[sk.id]
        if entry then
            entry.count = entry.count + 1
        else
            entry = { skill = sk, count = 1 }
            byId[sk.id] = entry
            view[#view + 1] = entry
        end
    end
    return view
end

function HUD:drawSkillStrip(skills)
    local st = SKILLS
    Skin.panel(st.x, st.y, st.w, st.h, "inset")
    local view = self:refreshSkillView(skills)
    local cw, ch = st.step - 3, st.h - 8
    for i = 1, st.slots do
        local sx, sy = st.x + 4 + (i - 1) * st.step, st.y + 4
        local entry = view[i]
        if entry then
            local th = Skin.theme(RARITY_THEME[entry.skill.rarity] or "gray")
            Skin.roundRect(C.ink, sx, sy, cw, ch, 2)
            Skin.roundRect(th.dark, sx + 1, sy + 1, cw - 2, ch - 2, 2)
            Skin.rect(th.main, sx + 1, sy + ch - 4, cw - 2, 2)
        else
            Skin.roundRect(C.slate, sx, sy, cw, ch, 2)
            Skin.rect(C.night, sx + 1, sy + 1, cw - 2, ch - 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, math.min(#view, st.slots) do
        local sx = st.x + 4 + (i - 1) * st.step
        Art.drawEx(Icons.skillIcon(view[i].skill.icon), 1, sx + floor(cw / 2), st.y + 4 + floor(ch / 2) - 1, 0, 2, 2)
    end
    for i = 1, math.min(#view, st.slots) do
        if view[i].count > 1 then
            local sx = st.x + 4 + (i - 1) * st.step
            PixelFont.print("×" .. view[i].count, sx + cw - 13, st.y + ch - 9, C.white, "tiny")
        end
    end
    if #view > st.slots then
        PixelFont.print("+" .. (#view - st.slots), st.x + st.w - 22, st.y + 12, C.yellow, "main")
    end
end

function HUD:checkSkillTouch(tx, ty)
    local st = SKILLS
    if ty < st.y or ty > st.y + st.h or tx < st.x or tx > st.x + st.w then return false end
    local i = floor((tx - st.x - 4) / st.step) + 1
    local entry = self.skillView[i]
    if entry and i <= st.slots then
        self.tooltip = entry.skill
        self.tooltipTimer = TOOLTIP_TIME
    end
    return true
end

function HUD:drawTooltip(sk)
    local x, y, w, h = 20, ULT.y + 18, W - 40, 62
    local th = Skin.theme(RARITY_THEME[sk.rarity] or "gray")
    Skin.roundRect(C.ink, x, y, w, h, 3)
    Skin.roundRect(th.dark, x + 1, y + 1, w - 2, h - 2, 2)
    Skin.rect(C.night, x + 3, y + 15, w - 6, h - 18)
    PixelFont.printf(sk.name, x, y + 3, w, "center", C.white, "main", 1, nil, 1)
    PixelFont.printf(sk.desc or "", x + 6, y + 19, w - 12, "center", C.silver, "main", 1, nil, 3, 12)
end

-- ============================================================================
-- ACTIONS: ultimate (L, left) and dash (R, right)
-- ============================================================================
function HUD:drawActionsStatic(ready)
    for _, p in ipairs({ ULT, DASH }) do
        Skin.panel(p.x, p.y, p.w, p.h, "raised")
    end
    local uc, dc = self.ultCircle, self.dashCircle
    Skin.pill(uc.cx - BUTTON_RADIUS - 4, uc.cy + BUTTON_RADIUS - 12, 14, 11, "gold", nil)
    Skin.pill(dc.cx + BUTTON_RADIUS - 10, dc.cy + BUTTON_RADIUS - 12, 14, 11, "blue", nil)
    PixelFont.print("L", uc.cx - BUTTON_RADIUS + 1, uc.cy + BUTTON_RADIUS - 10, C.white, "tiny")
    PixelFont.print("R", dc.cx + BUTTON_RADIUS - 5, dc.cy + BUTTON_RADIUS - 10, C.white, "tiny")
    PixelFont.printf("ULTIMATE", ULT.x, ULT.y + 5, ULT.w, "center", ready and C.amber or C.fog, "tiny")
    PixelFont.printf("DASH", DASH.x, DASH.y + 5, DASH.w, "center", C.fog, "tiny")
end

-- Charge ring: lit sector + unlit sector (2 calls)
local function ringGauge(cx, cy, r, ratio, lit, dim)
    ratio = math.min(1, math.max(0, ratio))
    local top = -math.pi / 2
    local split = top + ratio * math.pi * 2
    if ratio < 1 then
        love.graphics.setColor(dim[1], dim[2], dim[3], 1)
        love.graphics.arc("fill", cx, cy, r + 1, split, top + math.pi * 2, 24)
    end
    if ratio > 0 then
        love.graphics.setColor(lit[1], lit[2], lit[3], 1)
        love.graphics.arc("fill", cx, cy, r + 1, top, split, 24)
    end
end

-- ----------------------------------------------------------------------------
-- LIVE LAYER (every time the bottom screen is redrawn)
-- ----------------------------------------------------------------------------
function HUD:drawLive(game, boss)
    local player = game.player
    local t = love.timer.getTime()

    -- Gauges: XP, HP, boss HP
    barFill(XP_BAR.x, XP_BAR.y, XP_BAR.w, XP_BAR.h, self.displayXp, "gold")
    local hpRatio = math.max(0, math.min(1, self.displayHp / math.max(1, player.maxHp)))
    barFill(HP_BAR.x, HP_BAR.y, HP_BAR.w, HP_BAR.h, hpRatio, hpRatio < 0.3 and "red" or "green")
    barNotches(HP_BAR.x, HP_BAR.y, HP_BAR.w, HP_BAR.h, HP_NOTCHES)
    local bossRatio
    if boss then
        bossRatio = math.max(0, math.min(1, boss.hp / math.max(1, boss.maxHp)))
        self.displayBossHp = self.displayBossHp + (bossRatio - self.displayBossHp) * 0.25
        local b = BOSS_BAR
        barFill(b.x, b.y, b.w, b.h, self.displayBossHp, "red")
        barNotches(b.x, b.y, b.w, b.h, HP_NOTCHES)
    end

    -- Rings and round buttons (primitives)
    local dc, uc = self.dashCircle, self.ultCircle
    local cd = player.dashCooldownTimer or 0
    local dashReady = cd <= 0
    local dashRatio = dashReady and 1 or (1 - cd / (player.dashCooldown or 1.5))
    local ultCharge = game.ultimateCharge or 0
    local ready = ultCharge >= 1.0
    if ready then
        local pulse = floor((math.sin(self.ultPulse) + 1) * 2)
        Skin.disc(C.amber, uc.cx, uc.cy, uc.radius + 3 + pulse, 0.3)
    end
    -- Unlit parts in night blue: slate would melt into the raised panel
    ringGauge(dc.cx, dc.cy, dc.radius, dashRatio, dashReady and C.cyan or C.blue, C.night)
    Skin.disc(dashReady and C.blue or C.night, dc.cx, dc.cy, dc.radius - 5)
    ringGauge(uc.cx, uc.cy, uc.radius, ultCharge, ready and C.yellow or C.amber, C.night)
    Skin.disc(ready and C.orange or C.night, uc.cx, uc.cy, uc.radius - 5)

    -- Sprites: icons, map dots, texts (merged by the auto-batcher)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("icon_bolt", 1, dc.cx, dc.cy, 0, 3, 3)
    local bob = ready and floor(math.sin(t * 6) * 1.5 + 0.5) or 0
    Art.drawEx("icon_star", 1, uc.cx, uc.cy + bob, 0, 3, 3)

    if not boss then
        local s, ox, oy = self:minimapFrame(game)
        local pool = game.dummyPool
        if pool then
            for i = 1, pool.activeCount do
                local d = pool.items[pool.activeList[i]]
                if d and d.alive then
                    Art.draw(d.isBoss and "icon_mm_boss" or "icon_mm_enemy", 1, ox + floor(d.x * s), oy + floor(d.y * s))
                end
            end
        end
        if floor(t * 4) % 4 ~= 0 then
            Art.draw("icon_mm_player", 1, ox + floor(player.x * s), oy + floor(player.y * s))
        end
    end

    PixelFont.print(tostring(floor(game.goldEarnedRun or 0)), 248, 7, C.yellow, "main")
    PixelFont.printf(floor(player.xp or 0) .. "/" .. floor(player.nextLevelXp or 0) .. " XP", XP_BAR.x, XP_BAR.y + 4,
        XP_BAR.w, "center", C.white, "tiny")
    -- Digit rows 2-8 of the cell: drawing at y + 2 puts them on the bar's middle row
    PixelFont.printf(string.format("%d/%d", math.max(0, floor(player.hp)), player.maxHp), HP_BAR.x, HP_BAR.y + 2,
        HP_BAR.w, "center", C.white, "main")
    PixelFont.print(tostring(game.kills or 0), HERO.x + 287, HERO.y + 21, C.white, "main")

    local labelY = ULT.y + ULT.h - 17
    PixelFont.printf(ready and "READY!" or (floor(math.min(1, ultCharge) * 100) .. "%"), ULT.x, labelY, ULT.w, "center",
        ready and C.yellow or C.amber, "main")
    PixelFont.printf(dashReady and "READY" or string.format("%.1f", cd), DASH.x, labelY, DASH.w, "center",
        dashReady and C.cyan or C.white, "main")

    if boss then
        local x, w = MAP.x, MAP.w
        PixelFont.printf(floor(bossRatio * 100) .. "%", x, BOSS_BAR.y + BOSS_BAR.h + 6, w, "center", C.white, "main", 2)
        if boss.enraged or bossRatio < 0.5 then
            PixelFont.printf("ENRAGED!", x, MAP.y + MAP.h - 26, w, "center", C.red, "main")
        end
    else
        local waves = game.waveRunner
        if waves and waves:total() > 1 then
            PixelFont.printf(waves:label(), MAP.x, MAP.y + 3, MAP.w, "center", C.amber, "tiny")
        end
    end
end

-- ============================================================================
-- ALERTE PV CRITIQUES
-- ============================================================================
function HUD:drawLowHpOverlay(player)
    if not player or player.hp <= 0 then return end
    if (player.hp / player.maxHp) >= 0.20 then return end
    local pulse = (math.sin(love.timer.getTime() * 9) + 1) * 0.5
    local a = 0.35 + pulse * 0.4
    Skin.rect(C.red, 0, 0, W, 3, a)
    Skin.rect(C.red, 0, H - 3, W, 3, a)
    Skin.rect(C.red, 0, 0, 3, H, a)
    Skin.rect(C.red, W - 3, 0, 3, H, a)
end

-- ============================================================================
-- CHOIX DE COMPÉTENCE (montée de niveau) : toucher une carte, ou croix + A
-- ============================================================================
local function drawRays(cx, cy, t)
    local C2 = Palette.C.amber
    love.graphics.setColor(C2[1], C2[2], C2[3], 0.07)
    for i = 0, 7 do
        local a = t * 0.4 + i * math.pi / 4
        love.graphics.polygon("fill", cx, cy,
            cx + math.cos(a - 0.14) * 260, cy + math.sin(a - 0.14) * 260,
            cx + math.cos(a + 0.14) * 260, cy + math.sin(a + 0.14) * 260)
    end
end

function HUD:drawDraftModal(draftOptions, acquiredSkills, cursor)
    local t = love.timer.getTime()
    Skin.rect(C.ink, 0, 0, W, H, 0.93)
    drawRays(W / 2, 18, t)

    Skin.ribbon(W / 2, 5, 244, 28, "gold")
    PixelFont.printf("LEVEL UP!", 0, 6, W, "center", C.white, "main", 2, "shadow")
    PixelFont.printf("TOUCH A CARD  ·  D-PAD + A", 0, 37, W, "center", C.silver, "tiny")

    for i = 1, math.min(3, #draftOptions) do
        local skill = draftOptions[i]
        local card = self.cards[i]
        local x, y, w, h = card.x, card.y, card.w, card.h
        local selected = (cursor == i)
        if selected then y = y - 3 end
        local themeName = RARITY_THEME[skill.rarity] or "gray"
        local th = Skin.theme(themeName)
        local rarity = Palette.rarity(skill.rarity)

        if selected then
            local glow = 0.55 + 0.35 * math.sin(t * 8)
            Skin.roundRect(C.yellow, x - 2, y - 2, w + 4, h + 4, 3, glow)
        end
        Skin.panel(x, y, w, h, "dark")
        Skin.roundRect(th.dark, x + 1, y + 1, w - 2, 15, 2)
        Skin.rect(th.main, x + 3, y + 1, w - 6, 13)
        Skin.rect(th.light, x + 3, y + 1, w - 6, 1)
        local bob = floor(math.sin(t * 3 + i) * 1.5 + 0.5)
        Skin.iconDisc(x + floor(w / 2), y + 38 + bob, 18, themeName)
        Skin.rect(C.slate, x + 10, y + 84, w - 20, 1)
        local owned = Skills.stackCount(acquiredSkills, skill.id)
        if owned > 0 then
            Skin.pill(x + 3, y + 18, 34, 12, "gold", "LV." .. (owned + 1), "tiny")
        end
        Skin.pill(x + floor(w / 2) - 10, y + h - 16, 20, 12, selected and "gold" or themeName, tostring(i), "tiny")

        PixelFont.printf(rarity.name, x, y + 5, w, "center", C.white, "tiny")
        love.graphics.setColor(1, 1, 1, 1)
        Art.drawEx(Icons.skillIcon(skill.icon), 1, x + floor(w / 2), y + 38 + bob, 0, 2, 2)
        PixelFont.printf(skill.name, x + 3, y + 60, w - 6, "center", C.yellow, "main", 1, nil, 2, 11)
        PixelFont.printf(skill.desc, x + 4, y + 88, w - 8, "center", C.silver, "main", 1, nil, 4, 11)
    end
end

-- ============================================================================
-- ZONES TACTILES
-- ============================================================================
function HUD:checkCardTouch(tx, ty)
    for i = 1, #self.cards do
        local c = self.cards[i]
        if tx >= c.x and tx <= c.x + c.w and ty >= c.y - 4 and ty <= c.y + c.h then
            return i
        end
    end
    return nil
end

-- The whole side panel is the button: easy to hit with a thumb
local function inRect(r, tx, ty)
    return tx >= r.x and tx <= r.x + r.w and ty >= r.y and ty <= r.y + r.h
end

function HUD:checkDashTouch(tx, ty)
    return inRect(DASH, tx, ty)
end

function HUD:checkUltimateTouch(tx, ty)
    return inRect(ULT, tx, ty)
end

return HUD
