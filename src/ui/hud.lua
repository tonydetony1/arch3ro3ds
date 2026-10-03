-- src/ui/hud.lua
-- Écran tactile de combat (320x240) : tableau de bord façon Archero, pensé pour la 3DS.
--   * barre du haut : niveau, expérience, or, pause
--   * mini-carte de la salle (murs, rochers, eau, dangers, porte, monstres, boss, héros)
--   * fiche héros : PV, statistiques, salle / chapitre, ou barre de vie du boss
--   * compétences acquises (toucher une icône = infobulle)
--   * esquive (R) et ultime (L) avec anneaux de charge
-- Budget : ~70 appels GPU. Les icônes et les textes blancs ou en couleur précuite sont
-- regroupés par l'auto-batcher (src/core/gpu.lua), donc on dessine d'abord les aplats
-- d'une zone, puis ses sprites.

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
local Gpu = require("src.core.gpu")
local PxColors = require("src.render.px_colors")

-- Couleur nommée de la palette la plus proche (les couleurs de thème sont en hexadécimal)
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

-- Zones de l'écran
local MAP = { x = 4, y = 28, w = 196, h = 122 }
local SIDE = { x = 204, y = 28, w = 112, h = 122 }
local SKILLS = { x = 4, y = 153, w = 312, h = 34, slots = 10, step = 31 }
local TOOLTIP_TIME = 2.5

-- Nom affiché d'un type de monstre (bestiaire), mis en cache
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

    self.cards = {
        { x = 8,   y = 46, w = 96, h = 156 },
        { x = 112, y = 46, w = 96, h = 156 },
        { x = 216, y = 46, w = 96, h = 156 },
    }
    self.dashCircle = { cx = 34, cy = 214, radius = 21 }
    self.ultCircle = { cx = 160, cy = 214, radius = 23 }
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
-- TABLEAU DE BORD COMPLET : couche fixe enregistrée + couche vivante
-- ============================================================================
-- Sur Old 3DS chaque opération de dessin coûte (appel GPU ~80 µs, et autant en Lua pour une
-- suite de sprites). La couche fixe (fonds, panneaux, libellés, icônes, bouton pause, carte
-- de la salle, compétences) est enregistrée dans un SpriteBatch (Gpu.beginRecord) et
-- réaffichée en 1 appel tant que rien ne change. Seules les valeurs vivantes (jauges,
-- compteurs, points de la mini-carte, anneaux de charge) sont dessinées à chaque fois.
local STATIC_FIELDS = { "heroId", "room", "chapter", "skills", "boss", "bossType", "dmg", "crit",
    "arrows", "dodge", "maxHp", "level", "gate", "ultReady", "mapW", "mapH", "theme" }

local function playerStats(player)
    local w = player.currentWeapon
    local dmg = floor(w.damage * (player.damageMult or 1.0))
    local arrows = (player.frontArrows or 1) + (player.diagArrows or 0) * 2 + (player.rearArrows or 0) + (player.sideArrows or 0) * 2
    return dmg, floor((player.critChance or 0) * 100), arrows, floor((player.dodgeChance or 0) * 100)
end

-- Relève l'état qui détermine la couche fixe ; vrai si elle doit être réenregistrée
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

-- Barre de jauge : fond fixe / remplissage vivant (2 aplats)
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
end

-- ----------------------------------------------------------------------------
-- COUCHE FIXE (enregistrée)
-- ----------------------------------------------------------------------------
function HUD:drawStatic(game, boss, pb)
    local player = game.player
    local cur = self.staticCur

    -- Fond
    Skin.rect(C.night, 0, 0, W, H)
    Skin.rect(C.ink, 0, 0, W, 25)
    Skin.rect(C.ink, 0, 189, W, 51, 0.55)

    -- Barre du haut : badge de niveau, cadre d'XP, pièce, bouton pause
    Skin.roundRect(C.cyan, 2, 1, 23, 23, 3)
    Skin.roundRect(C.navy, 3, 2, 21, 21, 3)
    Skin.roundRect(C.blue, 4, 3, 19, 18, 3)
    PixelFont.printf(tostring(cur.level), 1, 7, 25, "center", C.white, "main")
    barFrame(28, 6, 196, 13)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, 236, 12)
    if pb then
        local oy = Skin.button(pb.x, pb.y, pb.w, pb.h, "blue", false)
        love.graphics.setColor(1, 1, 1, 1)
        Art.draw("icon_pause", 1, pb.x + floor(pb.w / 2), pb.y + oy + floor((pb.h - 3) / 2))
    end

    self:drawMinimapStatic(game)
    if boss then
        self:drawBossStatic(boss)
    else
        self:drawHeroStatic(player, cur)
    end
    self:drawSkillStrip(game.acquiredSkills)
    self:drawActionsStatic(cur.ultReady)
end

function HUD:minimapFrame(game)
    local m = MAP
    local mapW, mapH = game.mapW or 600, game.mapH or 460
    local s = math.min((m.w - 12) / mapW, (m.h - 18) / mapH)
    local ox = floor(m.x + (m.w - mapW * s) / 2)
    local oy = floor(m.y + 13 + ((m.h - 18) - mapH * s) / 2)
    return s, ox, oy, mapW, mapH
end

function HUD:drawMinimapStatic(game)
    local m = MAP
    Skin.panel(m.x, m.y, m.w, m.h, "dark")
    local s, ox, oy, mapW, mapH = self:minimapFrame(game)
    local theme = game.arena and game.arena.theme
    local ground = C.moss
    if theme and theme.groundDark then
        ground = Palette.hex(theme.groundDark)
        -- couleur hors palette nommée : on prend la plus proche des tons de sol nommés
        ground = PxNearest(ground)
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
    PixelFont.print("STAGE " .. (game.roomNumber or 1), m.x + 6, m.y + 3, C.silver, "tiny")
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw(game.isGateOpen and "icon_mm_gate_open" or "icon_mm_gate_closed", 1, ox + floor(mapW * s / 2), oy + 3)
end

function HUD:drawHeroStatic(player, cur)
    local x, y = SIDE.x, SIDE.y
    Skin.panel(x, y, SIDE.w, SIDE.h, "dark")
    barFrame(x + 4, y + 16, SIDE.w - 8, 13)
    Skin.rect(C.slate, x + 6, y + 64, SIDE.w - 12, 1)
    local hero = Heroes.get(player.heroId)
    PixelFont.printf(hero.name:upper(), x, y + 3, SIDE.w, "center", C.yellow, "main")
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_sword", 1, x + 10, y + 39)
    Art.draw("icon_star", 1, x + 62, y + 39)
    Art.draw("icon_skill_multishot", 1, x + 10, y + 54)
    Art.draw("icon_skill_boots", 1, x + 62, y + 54)
    PixelFont.print(tostring(cur.dmg), x + 18, y + 33, C.white, "main")
    PixelFont.print(cur.crit .. "%", x + 70, y + 33, C.white, "main")
    PixelFont.print("×" .. cur.arrows, x + 18, y + 48, C.white, "main")
    PixelFont.print(cur.dodge .. "%", x + 70, y + 48, C.white, "main")

    local room = cur.room
    PixelFont.print("STAGE", x + 6, y + 70, C.silver, "tiny")
    PixelFont.print(tostring(room), x + 6, y + 77, C.white, "main", 2, "shadow")
    PixelFont.print("/50", x + 8 + PixelFont.getWidth(tostring(room), "main", 2), y + 87, C.fog, "main")
    local toBoss = 10 - (room % 10)
    local bossText = (room % 10 == 0) and "BOSS !" or ("BOSS : " .. toBoss)
    PixelFont.printf(bossText, x + 52, y + 72, SIDE.w - 56, "right", (room % 10 == 0) and C.red or C.silver, "tiny")
    PixelFont.printf(cur.chapter or "Verdant Forest", x + 4, y + 104, SIDE.w - 8, "center", C.cyan, "tiny", 1, nil, 1)
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

function HUD:drawBossStatic(boss)
    local x, y = SIDE.x, SIDE.y
    Skin.panel(x, y, SIDE.w, SIDE.h, "dark")
    Skin.roundRect(C.wine, x + 1, y + 1, SIDE.w - 2, 14, 2)
    barFrame(x + 4, y + 36, SIDE.w - 8, 16)
    PixelFont.printf("BOSS", x, y + 4, SIDE.w, "center", C.white, "main")
    PixelFont.printf((monsterNames[boss.type] or boss.type or "?"):upper(), x + 2, y + 20, SIDE.w - 4, "center", C.yellow, "tiny", 1, nil, 1)
    PixelFont.printf("Dodge attacks (R)", x + 4, y + 104, SIDE.w - 8, "center", C.silver, "tiny", 1, nil, 1)
end

-- ============================================================================
-- COMPÉTENCES ACQUISES (couche fixe)
-- ============================================================================
function HUD:drawSkillStrip(skills)
    local st = SKILLS
    Skin.panel(st.x, st.y, st.w, st.h, "inset")
    skills = skills or {}
    local n = math.min(#skills, st.slots)
    for i = 1, n do
        local th = Skin.theme(RARITY_THEME[skills[i].rarity] or "gray")
        Skin.rect(th.main, st.x + 6 + (i - 1) * st.step, st.y + st.h - 6, 24, 2)
    end
    if #skills == 0 then
        PixelFont.printf("Level up to choose skills", st.x, st.y + 14, st.w, "center", C.steel, "tiny")
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, n do
        Art.drawEx(Icons.skillIcon(skills[i].icon), 1, st.x + 18 + (i - 1) * st.step, st.y + 15, 0, 2, 2)
    end
    if #skills > st.slots then
        PixelFont.print("+" .. (#skills - st.slots), st.x + st.w - 20, st.y + 12, C.yellow, "main")
    end
end

function HUD:checkSkillTouch(tx, ty, skills)
    local st = SKILLS
    if ty < st.y or ty > st.y + st.h or tx < st.x or tx > st.x + st.w then return false end
    local i = floor((tx - st.x - 3) / st.step) + 1
    local sk = skills and skills[i]
    if sk and i <= st.slots then
        self.tooltip = sk
        self.tooltipTimer = TOOLTIP_TIME
    end
    return true
end

function HUD:drawTooltip(sk)
    local x, y, w, h = MAP.x + 4, MAP.y + 36, MAP.w - 8, 62
    local th = Skin.theme(RARITY_THEME[sk.rarity] or "gray")
    Skin.roundRect(C.ink, x, y, w, h, 3)
    Skin.roundRect(th.dark, x + 1, y + 1, w - 2, h - 2, 2)
    Skin.rect(C.night, x + 3, y + 14, w - 6, h - 17)
    PixelFont.printf(sk.name, x, y + 3, w, "center", C.white, "main", 1, nil, 1)
    PixelFont.printf(sk.desc or "", x + 6, y + 18, w - 12, "center", C.silver, "main", 1, nil, 3, 11)
end

-- ============================================================================
-- ACTIONS : esquive (R) et ultime (L)
-- ============================================================================
function HUD:drawActionsStatic(ready)
    local dc, uc = self.dashCircle, self.ultCircle
    Skin.pill(dc.cx + 12, dc.cy + 10, 14, 11, "gray", nil)
    Skin.pill(uc.cx + 14, uc.cy + 12, 14, 11, "gray", nil)
    PixelFont.print("R", dc.cx + 17, dc.cy + 12, C.white, "tiny")
    PixelFont.print("L", uc.cx + 19, uc.cy + 14, C.white, "tiny")
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_skull", 1, 78, 206)
    PixelFont.print("KILLS", 78, 216, C.fog, "tiny")
    PixelFont.printf("ULTIMATE", 196, 226, 120, "center", ready and C.amber or C.fog, "tiny")
end

-- Anneau de charge : secteur allumé + secteur éteint (2 appels)
local function ringGauge(cx, cy, r, ratio, lit, dim)
    ratio = math.min(1, math.max(0, ratio))
    local top = -math.pi / 2
    local split = top + ratio * math.pi * 2
    if ratio < 1 then
        love.graphics.setColor(dim[1], dim[2], dim[3], 1)
        love.graphics.arc("fill", cx, cy, r + 1, split, top + math.pi * 2, 20)
    end
    if ratio > 0 then
        love.graphics.setColor(lit[1], lit[2], lit[3], 1)
        love.graphics.arc("fill", cx, cy, r + 1, top, split, 20)
    end
end

-- ----------------------------------------------------------------------------
-- COUCHE VIVANTE (chaque fois que l'écran du bas est redessiné)
-- ----------------------------------------------------------------------------
function HUD:drawLive(game, boss)
    local player = game.player
    local t = love.timer.getTime()

    -- Jauges : XP, PV ou vie du boss
    barFill(28, 6, 196, 13, self.displayXp, "gold")
    local x, y = SIDE.x, SIDE.y
    local bossRatio
    if boss then
        bossRatio = math.max(0, math.min(1, boss.hp / math.max(1, boss.maxHp)))
        self.displayBossHp = self.displayBossHp + (bossRatio - self.displayBossHp) * 0.25
        barFill(x + 4, y + 36, SIDE.w - 8, 16, self.displayBossHp, "red")
    else
        local ratio = math.max(0, math.min(1, self.displayHp / math.max(1, player.maxHp)))
        barFill(x + 4, y + 16, SIDE.w - 8, 13, ratio, ratio < 0.3 and "red" or "green")
    end

    -- Anneaux et boutons ronds (primitives)
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
    ringGauge(dc.cx, dc.cy, dc.radius, dashRatio, dashReady and C.cyan or C.blue, C.slate)
    Skin.disc(dashReady and C.blue or C.slate, dc.cx, dc.cy, dc.radius - 4)
    ringGauge(uc.cx, uc.cy, uc.radius, ultCharge, ready and C.yellow or C.amber, C.slate)
    Skin.disc(ready and C.orange or C.slate, uc.cx, uc.cy, uc.radius - 4)

    -- Sprites : icônes, points de la mini-carte, textes (fusionnés par l'auto-batcher)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("icon_bolt", 1, dc.cx, dc.cy, 0, 2, 2)
    local bob = ready and floor(math.sin(t * 6) * 1.5 + 0.5) or 0
    Art.drawEx("icon_star", 1, uc.cx, uc.cy + bob, 0, 2, 2)

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

    PixelFont.print(tostring(floor(game.goldEarnedRun or 0)), 244, 7, C.yellow, "main")
    PixelFont.printf("LEVEL " .. (player.level or 1), 28, 3, 196, "center", C.white, "tiny")
    PixelFont.print(tostring(game.kills or 0), 86, 201, C.white, "main")
    if not dashReady then
        PixelFont.printf(string.format("%.1f", cd), dc.cx - 20, dc.cy - 5, 40, "center", C.white, "main")
    end
    PixelFont.printf(ready and "READY!" or (floor(math.min(1, ultCharge) * 100) .. "%"), 196, 200, 120, "center",
        ready and C.yellow or C.white, "main", 2, "shadow")
    if boss then
        PixelFont.printf(floor(bossRatio * 100) .. "%", x, y + 58, SIDE.w, "center", C.white, "main", 2, "shadow")
        if boss.enraged or bossRatio < 0.5 then
            PixelFont.printf("ENRAGED!", x, y + 86, SIDE.w, "center", C.red, "main")
        end
    else
        PixelFont.printf(string.format("%d/%d", math.max(0, floor(player.hp)), player.maxHp), x + 4, y + 19, SIDE.w - 8, "center", C.white, "tiny")
        PixelFont.printf("KILLS " .. (game.kills or 0), x + 52, y + 84, SIDE.w - 56, "right", C.white, "tiny")
        local waves = game.waveRunner
        if waves and waves:total() > 1 then
            PixelFont.printf(waves:label(), x + 4, y + 84, 60, "left", C.amber, "tiny")
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

local function inCircle(c, tx, ty)
    local dx, dy = tx - c.cx, ty - c.cy
    local r = c.radius + 6
    return dx * dx + dy * dy <= r * r
end

function HUD:checkDashTouch(tx, ty)
    return inCircle(self.dashCircle, tx, ty)
end

function HUD:checkUltimateTouch(tx, ty)
    return inCircle(self.ultCircle, tx, ty)
end

return HUD
