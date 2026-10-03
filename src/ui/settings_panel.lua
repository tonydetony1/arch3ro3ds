-- src/ui/settings_panel.lua
-- Onglet SETTINGS de l'écran tactile : réglages du joueur, puis (une fois débloqué par 7
-- touchers sur le titre) le panneau admin de production : équilibrage, triches, outils.
-- Le panneau ne change pas d'état lui-même : il renvoie des requêtes au menu
-- ({ launch = { startRoom = N } }, { refresh = true }).

local Config = require("src.data.config")
local Save = require("src.data.save")
local Admin = require("src.data.admin")
local Audio = require("src.audio.audio")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Art = require("src.render.art")
local Skin = require("src.ui.skin")
local UI = require("src.ui.ui_components")

local Panel = {}
Panel.__index = Panel

local C = Palette.C
local floor = math.floor
local W = Config.BOTTOM_WIDTH

local UNLOCK_TAPS = 7
local UNLOCK_WINDOW = 4.0   -- secondes pour enchaîner les 7 touchers
local TOAST_TIME = 1.6
local ROW_Y, ROW_H, ROW_STEP = 32, 26, 28
local TITLE_ZONE = { x = 6, y = 4, w = 86, h = 24 }
local HEROES = { "atreus", "urasil", "phoren", "helix", "rolla" }

local PAGES = {
    { id = "game", label = "GAME" },
    { id = "tuning", label = "TUNE" },
    { id = "cheats", label = "CHEAT" },
    { id = "tools", label = "TOOLS" },
}

function Panel.new()
    local self = setmetatable({}, Panel)
    self.page = "game"
    self.cursor = 1
    self.pressed = nil
    self.taps = {}
    self.toast, self.toastTimer = nil, 0
    self.confirm = nil
    self.steps = { startRoom = 1, testBoss = 1 }
    return self
end

function Panel:open()
    self.page, self.cursor, self.confirm, self.pressed = "game", 1, nil, nil
end

local function settings()
    local d = Save.get()
    d.settings = d.settings or {}
    return d.settings
end

function Panel:isAdminUnlocked()
    return settings().adminUnlocked == true
end

local function persistAdmin()
    Save.get().admin = Admin.export()
    Save.save()
end

function Panel:showToast(text)
    self.toast, self.toastTimer = text, TOAST_TIME
end

-- ---------------------------------------------------------------------------
-- Lignes de chaque page
-- ---------------------------------------------------------------------------
local function gameRows()
    local d = Save.get()
    local st = settings()
    d.audio = d.audio or {}
    return {
        { id = "music", label = "MUSIC", kind = "slider",
          get = function() return d.audio.music or 0.55 end, max = 1,
          change = function(dir)
              d.audio.music = math.max(0, math.min(1, (d.audio.music or 0.55) + dir * 0.1))
              Audio.setMusicVolume(d.audio.music)
          end },
        { id = "sfx", label = "SOUND EFFECTS", kind = "slider",
          get = function() return d.audio.sfx or 0.85 end, max = 1,
          change = function(dir)
              d.audio.sfx = math.max(0, math.min(1, (d.audio.sfx or 0.85) + dir * 0.1))
              Audio.setSfxVolume(d.audio.sfx)
          end },
        { id = "depth3d", label = "3D DEPTH", kind = "slider",
          get = function() return st.depth3d or 1.0 end, max = 1.5,
          change = function(dir) st.depth3d = math.max(0, math.min(1.5, (st.depth3d or 1.0) + dir * 0.25)) end },
        { id = "showDamage", label = "DAMAGE NUMBERS", kind = "toggle",
          get = function() return st.showDamage ~= false end,
          change = function() st.showDamage = not (st.showDamage ~= false) end },
        { id = "lowPower", label = "BATTERY SAVER", kind = "toggle",
          get = function() return st.lowPower == true end,
          change = function() st.lowPower = not (st.lowPower == true) end },
        { id = "reset", label = "RESET SAVE DATA", kind = "action", button = "RESET", confirm = true,
          run = function()
              Save.reset()
              return { refresh = true }
          end },
    }
end

local function tuningRows()
    local rows = {}
    for _, def in ipairs(Admin.TUNING) do
        rows[#rows + 1] = { id = def.id, label = def.label, kind = "slider", tuning = true, persists = true,
            min = def.min, max = def.max, get = function() return Admin.get(def.id) end,
            change = function(dir) Admin.step(def.id, dir); persistAdmin() end }
    end
    return rows
end

local function cheatRows()
    local rows = {}
    for _, def in ipairs(Admin.CHEATS) do
        rows[#rows + 1] = { id = def.id, label = def.label, kind = "toggle", persists = true,
            get = function() return Admin.get(def.id) end,
            change = function() Admin.toggle(def.id); persistAdmin() end }
    end
    rows[#rows + 1] = { id = "gold", label = "+10K GOLD", kind = "action", button = "+10K",
        run = function() Save.addGold(10000); return { refresh = true } end }
    rows[#rows + 1] = { id = "gems", label = "+1K GEMS", kind = "action", button = "+1K",
        run = function() Save.addGems(1000); return { refresh = true } end }
    rows[#rows + 1] = { id = "heroes", label = "UNLOCK HEROES", kind = "action", button = "UNLOCK",
        run = function()
            local d = Save.get()
            d.unlockedHeroes = d.unlockedHeroes or {}
            for _, id in ipairs(HEROES) do d.unlockedHeroes[id] = true end
            Save.save()
            return { refresh = true }
        end }
    return rows
end

function Panel:toolRows()
    local steps = self.steps
    return {
        { id = "startRoom", label = "START ROOM", kind = "stepper", min = 1, max = 150, persists = true,
          get = function() return steps.startRoom end,
          change = function(dir)
              local v = steps.startRoom
              local step = ((dir > 0 and v >= 10) or (dir < 0 and v > 10)) and 5 or 1
              steps.startRoom = math.max(1, math.min(150, v + dir * step))
          end,
          run = function() return { launch = { startRoom = steps.startRoom } } end },
        { id = "testBoss", label = "TEST BOSS", kind = "stepper", min = 1, max = 6, persists = true,
          get = function() return steps.testBoss end,
          change = function(dir) steps.testBoss = math.max(1, math.min(6, steps.testBoss + dir)) end,
          run = function() return { launch = { startRoom = steps.testBoss * 10 } } end },
        { id = "hitboxes", label = "HITBOXES", kind = "toggle", persists = true,
          get = function() return Config.DEBUG_MODE end,
          change = function() Config.DEBUG_MODE = not Config.DEBUG_MODE end },
        { id = "perf", label = "PERF OVERLAY", kind = "toggle", persists = true,
          get = function() return Config.SHOW_GPU_STATS end,
          change = function() Config.SHOW_GPU_STATS = not Config.SHOW_GPU_STATS end },
        { id = "resetTuning", label = "RESET TUNING", kind = "action", button = "RESET", confirm = true,
          run = function() Admin.resetTuning(); persistAdmin() end },
        { id = "lock", label = "LOCK ADMIN", kind = "action", button = "LOCK",
          run = function(panel)
              settings().adminUnlocked = false
              Save.save()
              panel.page, panel.cursor = "game", 1
          end },
    }
end

function Panel:rows()
    if self.page == "tuning" then return tuningRows() end
    if self.page == "cheats" then return cheatRows() end
    if self.page == "tools" then return self:toolRows() end
    return gameRows()
end

-- ---------------------------------------------------------------------------
-- Géométrie des contrôles (partagée par le dessin et le toucher)
-- ---------------------------------------------------------------------------
local function rowY(i) return ROW_Y + (i - 1) * ROW_STEP end

local function controlsOf(row, y)
    if row.kind == "slider" then
        return { dec = { W - 104, y + 3, 22, 20 }, inc = { W - 30, y + 3, 22, 20 } }
    elseif row.kind == "toggle" then
        return { toggle = { W - 78, y + 3, 70, 20 } }
    elseif row.kind == "stepper" then
        return { dec = { W - 150, y + 3, 22, 20 }, inc = { W - 80, y + 3, 22, 20 }, go = { W - 54, y + 3, 46, 20 } }
    end
    return { action = { W - 90, y + 3, 82, 20 } }
end

local function inside(r, x, y)
    return x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4]
end

local function pageTab(i)
    return { 96 + (i - 1) * 56, 6, 52, 20 }
end

-- ---------------------------------------------------------------------------
-- Dessin
-- ---------------------------------------------------------------------------
local function sliderText(row, value)
    if row.tuning then return string.format("x%.2f", value):gsub("0$", "") end
    return string.format("%d%%", floor(value / (row.max or 1) * 100 + 0.5))
end

function Panel:draw()
    UI.drawBentoCard(6, 4, W - 12, 24, {})
    local title = (self.toastTimer > 0 and self.toast) or "SETTINGS"
    UI.drawText(title, 14, 8, (self.toastTimer > 0) and C.mint or C.yellow)
    if self:isAdminUnlocked() then
        for i, page in ipairs(PAGES) do
            local r = pageTab(i)
            UI.drawPillButton(r[1], r[2], r[3], r[4], page.label, (self.page == page.id) and "amber" or "dark",
                self.pressed == ("page_" .. page.id))
        end
    end

    for i, row in ipairs(self:rows()) do
        local y = rowY(i)
        UI.drawBentoCard(6, y, W - 12, ROW_H, {})
        if i == self.cursor then
            Skin.roundRect(C.yellow, 6, y, 3, ROW_H, 0, 0.9)
        end
        UI.drawText(row.label, 14, y + 8, C.silver)
        local ctl = controlsOf(row, y)
        local value = row.get and row.get()
        if row.kind == "slider" then
            UI.drawPillButton(ctl.dec[1], ctl.dec[2], ctl.dec[3], ctl.dec[4], "-", "gray", self.pressed == (row.id .. ":dec"))
            local lo, hi = row.min or 0, row.max or 1
            local ratio = math.max(0, math.min(1, (value - lo) / math.max(1e-9, hi - lo)))
            local bx, bw = W - 78, 44
            Art.px("slate", bx, y + 7, bw, 5)
            Art.px(row.tuning and (value == 1 and "leaf" or "amber") or "leaf", bx, y + 7, floor(bw * ratio + 0.5), 5)
            UI.setFont("tiny")
            UI.drawTextAligned(sliderText(row, value), bx, y + 15, bw, "center", C.fog)
            UI.setFont("main")
            UI.drawPillButton(ctl.inc[1], ctl.inc[2], ctl.inc[3], ctl.inc[4], "+", "gray", self.pressed == (row.id .. ":inc"))
        elseif row.kind == "toggle" then
            local t = ctl.toggle
            UI.drawPillButton(t[1], t[2], t[3], t[4], value and "ON" or "OFF", value and "green" or "gray",
                self.pressed == (row.id .. ":toggle"))
        elseif row.kind == "stepper" then
            UI.drawPillButton(ctl.dec[1], ctl.dec[2], ctl.dec[3], ctl.dec[4], "-", "gray", self.pressed == (row.id .. ":dec"))
            UI.drawTextAligned(tostring(value), ctl.dec[1] + 22, y + 8, 48, "center", C.white)
            UI.drawPillButton(ctl.inc[1], ctl.inc[2], ctl.inc[3], ctl.inc[4], "+", "gray", self.pressed == (row.id .. ":inc"))
            UI.drawPillButton(ctl.go[1], ctl.go[2], ctl.go[3], ctl.go[4], "GO", "green", self.pressed == (row.id .. ":go"))
        else
            local a = ctl.action
            local confirming = (self.confirm == row.id)
            UI.drawPillButton(a[1], a[2], a[3], a[4], confirming and "CONFIRM?" or row.button,
                confirming and "red" or "gray", self.pressed == (row.id .. ":action"))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
local function afterChange()
    Save.save()
    Save.applySettings()
end

-- Applique l'action `part` ("dec", "inc", "toggle", "go", "action") sur la ligne.
-- Les lignes `persists` sauvegardent elles-mêmes (ou n'ont rien à sauvegarder) : une seule
-- écriture sur la carte SD par appui (~0,1 s chacune sur 3DS)
function Panel:activate(row, part)
    if part == "dec" or part == "inc" then
        row.change(part == "inc" and 1 or -1)
        if not row.persists then afterChange() end
        return nil
    elseif part == "toggle" then
        row.change()
        if not row.persists then afterChange() end
        return nil
    elseif part == "go" then
        Audio.play("ui_confirm", 0, 0.8)
        return row.run(self)
    elseif part == "action" then
        if row.confirm and self.confirm ~= row.id then
            self.confirm = row.id
            return nil
        end
        self.confirm = nil
        Audio.play("ui_confirm", 0, 0.8)
        local request = row.run(self)
        self:showToast(row.label .. " OK")
        return request
    end
    return nil
end

function Panel:registerTitleTap()
    if self:isAdminUnlocked() then return end
    local now = love.timer.getTime()
    local kept = {}
    for _, t in ipairs(self.taps) do
        if now - t <= UNLOCK_WINDOW then kept[#kept + 1] = t end
    end
    kept[#kept + 1] = now
    self.taps = kept
    if #kept >= UNLOCK_TAPS then
        settings().adminUnlocked = true
        Save.save()
        self.taps = {}
        self:showToast("ADMIN UNLOCKED")
        Audio.play("level_up", 0, 0.8)
    end
end

function Panel:update(dt)
    if self.toastTimer > 0 then self.toastTimer = self.toastTimer - dt end
end

-- Toucher : on retient le contrôle pressé, l'action part au relâchement dessus
function Panel:touchpressed(tx, ty)
    self.pressed = nil
    if inside({ TITLE_ZONE.x, TITLE_ZONE.y, TITLE_ZONE.w, TITLE_ZONE.h }, tx, ty) then
        self:registerTitleTap()
        return
    end
    if self:isAdminUnlocked() then
        for i, page in ipairs(PAGES) do
            if inside(pageTab(i), tx, ty) then
                self.pressed = "page_" .. page.id
                return
            end
        end
    end
    for i, row in ipairs(self:rows()) do
        local y = rowY(i)
        if ty >= y and ty <= y + ROW_H then
            self.cursor = i
            for part, r in pairs(controlsOf(row, y)) do
                if inside(r, tx, ty) then
                    self.pressed = row.id .. ":" .. part
                    return
                end
            end
            return
        end
    end
end

function Panel:touchreleased()
    local pressed = self.pressed
    self.pressed = nil
    if not pressed then return nil end
    local page = pressed:match("^page_(.+)$")
    if page then
        self.page, self.cursor, self.confirm = page, 1, nil
        return nil
    end
    local id, part = pressed:match("^(.-):(.+)$")
    for _, row in ipairs(self:rows()) do
        if row.id == id then return self:activate(row, part) end
    end
    return nil
end

-- Manette : haut/bas = ligne, gauche/droite = valeur, A = action, L/R = page admin
function Panel:gamepadpressed(button)
    local rows = self:rows()
    if button == "dpup" then
        self.cursor = (self.cursor - 2) % #rows + 1
    elseif button == "dpdown" then
        self.cursor = self.cursor % #rows + 1
    elseif button == "leftshoulder" or button == "rightshoulder" then
        if not self:isAdminUnlocked() then return nil end
        local idx = 1
        for i, page in ipairs(PAGES) do if page.id == self.page then idx = i end end
        idx = (idx - 1 + (button == "rightshoulder" and 1 or -1)) % #PAGES + 1
        self.page, self.cursor, self.confirm = PAGES[idx].id, 1, nil
    else
        local row = rows[self.cursor]
        if not row then return nil end
        if button == "dpleft" or button == "dpright" then
            if row.kind == "slider" or row.kind == "stepper" then
                return self:activate(row, button == "dpright" and "inc" or "dec")
            elseif row.kind == "toggle" then
                return self:activate(row, "toggle")
            end
        elseif button == "a" then
            if row.kind == "toggle" then return self:activate(row, "toggle") end
            if row.kind == "stepper" then return self:activate(row, "go") end
            if row.kind == "action" then return self:activate(row, "action") end
        end
    end
    return nil
end

return Panel
