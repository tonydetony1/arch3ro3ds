-- src/states/pause.lua
-- Menu de pause accessible via START ou icône tactile
-- Affiche le récapitulatif de la run (Top) et les boutons d'action (Bottom)

local Config = require("src.data.config")
local Save = require("src.data.save")
local Audio = require("src.audio.audio")
local UI = require("src.ui.ui_components")
local Skin = require("src.ui.skin")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Art = require("src.render.art")
local Icons = require("src.render.sprites.icons")

local C = Palette.C

local PauseState = {}
PauseState.__index = PauseState

function PauseState.new(stateMachine)
    local self = setmetatable({}, PauseState)
    self.sm = stateMachine
    self.runData = nil
    self.confirmQuit = false

    -- Géométrie des boutons de l'écran inférieur (320x240)
    self.buttons = {
        resume   = { x = 20, y = 14,  w = 280, h = 56 },
        music    = { x = 20, y = 80,  w = 136, h = 44 },
        sfx      = { x = 164, y = 80, w = 136, h = 44 },
        abandon  = { x = 20, y = 134, w = 280, h = 44 },
        settings = { x = 90, y = 196, w = 140, h = 30 }, -- hitboxes, admin panel only
    }

    -- Confirmation of the abandon
    self.modal = {
        box     = { x = 12, y = 34,  w = 296, h = 172 },
        confirm = { x = 22, y = 146, w = 132, h = 48 },
        cancel  = { x = 166, y = 146, w = 132, h = 48 },
    }

    return self
end

function PauseState:enter(runData)
    self.runData = runData or {}
    self.confirmQuit = false
end

function PauseState:update(dt)
    -- dt = 0 lors de la pause, aucune mise à jour du jeu
end

local MODE_NAMES = { infinite = "THE ABYSS", boss_rush = "BOSS RUSH", survival = "ARENA" }
local SKILL_ROWS, SKILL_COLS = 5, 2

-- Admin panel unlocked: debug toggles (hitboxes) are shown
local function adminUnlocked()
    local settings = Save.get().settings
    return settings and settings.adminUnlocked == true
end

-- Console button glyph and label centred in a button rectangle
local function buttonLabel(r, glyph, label, pressed)
    local gw = glyph and 22 or 0
    local w = gw + PixelFont.getWidth(label, "main")
    local x = math.floor(r.x + (r.w - w) / 2)
    local y = math.floor(r.y + (r.h - 3 - 14) / 2) + (pressed and 2 or 0)
    if glyph then
        Skin.disc(C.ink, x + 8, y + 7, 9)
        Skin.disc(C.slate, x + 8, y + 7, 8)
        PixelFont.printf(glyph, x + 1, y + 1, 15, "center", C.white, "main")
    end
    PixelFont.print(label, x + gw, y + 1, C.white, "main")
end

-- ============================================================================
-- TOP SCREEN (400x240): run summary and the skills taken so far
-- ============================================================================
function PauseState:drawTop()
    local w, h = Config.TOP_WIDTH, Config.TOP_HEIGHT
    Skin.rect(C.ink, 0, 0, w, h, 0.9)
    Skin.panel(6, 6, w - 12, 30, "dark")
    local stats = {
        { icon = "icon_door", label = "ROOM", value = tostring(self.runData.room or 1) },
        { icon = "icon_coin", label = "GOLD", value = "+" .. (self.runData.goldEarned or 0) },
        { icon = "icon_skull", label = "KILLS", value = tostring(self.runData.kills or 0) },
    }
    for i = 1, #stats do Skin.panel(6 + (i - 1) * 130, 40, 128, 44, "raised") end
    Skin.panel(6, 88, w - 12, 146, "inset")
    love.graphics.setColor(1, 1, 1, 1)
    PixelFont.print("PAUSE", 14, 14, C.yellow, "main")
    PixelFont.printf(MODE_NAMES[self.runData.mode] or "ASCENSION", 6, 14, w - 20, "right", C.cyan, "main")
    for i, st in ipairs(stats) do
        local sx = 6 + (i - 1) * 130
        Art.drawEx(st.icon, 1, sx + 18, 62, 0, 2, 2)
        PixelFont.print(st.label, sx + 36, 46, C.fog, "main")
        PixelFont.print(st.value, sx + 36, 58, C.white, "main", 2)
    end

    -- Skills grouped by id, two columns, name in the main font with a stack count
    local skills = self.runData.skills or {}
    if #skills == 0 then
        PixelFont.printf("NO SKILLS YET", 6, 150, w - 12, "center", C.steel, "main")
        return
    end
    local order, count = {}, {}
    for _, sk in ipairs(skills) do
        if not count[sk.id] then order[#order + 1] = sk end
        count[sk.id] = (count[sk.id] or 0) + 1
    end
    for i, sk in ipairs(order) do
        if i > SKILL_ROWS * SKILL_COLS then break end
        local col, row = (i - 1) % SKILL_COLS, math.floor((i - 1) / SKILL_COLS)
        local sx, sy = 14 + col * 190, 96 + row * 27
        Art.drawEx(Icons.skillIcon(sk.icon), 1, sx + 10, sy + 11, 0, 2, 2)
        PixelFont.printf(sk.name, sx + 26, sy + 5, 140, "left", C.white, "main", 1, nil, 1)
        if count[sk.id] > 1 then PixelFont.print("x" .. count[sk.id], sx + 168, sy + 5, C.yellow, "main") end
    end
    if #order > SKILL_ROWS * SKILL_COLS then
        PixelFont.printf("+" .. (#order - SKILL_ROWS * SKILL_COLS) .. " MORE", 6, 220, w - 20, "right", C.silver, "main")
    end
end

-- Volume button: label, percentage and a 10-step gauge (tap cycles the volume)
local function volumeButton(r, label, volume, theme, pressed)
    local oy = Skin.button(r.x, r.y, r.w, r.h, theme, pressed)
    local steps = math.floor(volume * 10 + 0.5)
    for i = 1, 10 do
        local x = r.x + 13 + (i - 1) * 11
        Skin.rect(C.ink, x, r.y + oy + 25, 9, 8)
        Skin.rect(i <= steps and C.white or C.slate, x + 1, r.y + oy + 26, 7, 6)
    end
    PixelFont.printf(string.format("%s %d%%", label, math.floor(volume * 100 + 0.5)), r.x, r.y + oy + 7, r.w, "center",
        C.white, "main")
end

-- ============================================================================
-- BOTTOM SCREEN (320x240): buttons and the abandon confirmation
-- ============================================================================
function PauseState:drawBottom()
    local botW, botH = Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT
    Skin.background(botW, botH)
    if not self.confirmQuit then
        local b = self.buttons
        Skin.button(b.resume.x, b.resume.y, b.resume.w, b.resume.h, "green", self.pressed == "resume")
        volumeButton(b.music, "MUSIC", Audio.musicVolume, "blue", self.pressed == "music")
        volumeButton(b.sfx, "SFX", Audio.sfxVolume, "purple", self.pressed == "sfx")
        Skin.button(b.abandon.x, b.abandon.y, b.abandon.w, b.abandon.h, "red", self.pressed == "abandon")
        if adminUnlocked() then
            Skin.button(b.settings.x, b.settings.y, b.settings.w, b.settings.h, "gray", self.pressed == "settings")
            buttonLabel(b.settings, nil, Config.DEBUG_MODE and "HITBOXES ON" or "HITBOXES OFF", self.pressed == "settings")
        end
        love.graphics.setColor(1, 1, 1, 1)
        buttonLabel(b.resume, "A", "RESUME", self.pressed == "resume")
        buttonLabel(b.abandon, nil, "ABANDON RUN", self.pressed == "abandon")
    else
        local m = self.modal.box
        Skin.rect(C.ink, 0, 0, botW, botH, 0.75)
        Skin.panel(m.x, m.y, m.w, m.h, "dark")
        Skin.roundRect(C.wine, m.x + 1, m.y + 1, m.w - 2, 24, 2)
        local bc, bk = self.modal.confirm, self.modal.cancel
        Skin.button(bc.x, bc.y, bc.w, bc.h, "red", self.pressed == "confirm")
        Skin.button(bk.x, bk.y, bk.w, bk.h, "green", self.pressed == "cancel")
        love.graphics.setColor(1, 1, 1, 1)
        PixelFont.printf("ABANDON RUN?", m.x, m.y + 7, m.w, "center", C.white, "main")
        PixelFont.printf("The gold of this run goes to your chest.", m.x + 16, m.y + 44, m.w - 32, "center",
            C.silver, "main", 1, nil, 3, 13)
        buttonLabel(bc, nil, "ABANDON", self.pressed == "confirm")
        buttonLabel(bk, "B", "CANCEL", self.pressed == "cancel")
    end
end

-- ============================================================================
-- ENTRÉES TACTILES (STYLUS / CLIC SOURIS)
-- ============================================================================
function PauseState:touchpressed(id, tx, ty)
    Audio.play("ui_click", 0.05, 0.5)
    if not self.confirmQuit then
        -- 1. Reprendre
        local bRes = self.buttons.resume
        if tx >= bRes.x and tx <= bRes.x + bRes.w and ty >= bRes.y and ty <= bRes.y + bRes.h then
            self.sm:pop()
            return
        end

        -- 2. Volumes (cycle 0 -> 30 -> 60 -> 100 %)
        local function cycle(v)
            if v < 0.05 then return 0.30 elseif v < 0.45 then return 0.60 elseif v < 0.75 then return 1.0 end
            return 0.0
        end
        local bMus = self.buttons.music
        if tx >= bMus.x and tx <= bMus.x + bMus.w and ty >= bMus.y and ty <= bMus.y + bMus.h then
            Audio.setMusicVolume(cycle(Audio.musicVolume))
            local d = Save.get()
            d.audio = d.audio or {}
            d.audio.music = Audio.musicVolume
            Save.save()
            return
        end
        local bSfx = self.buttons.sfx
        if tx >= bSfx.x and tx <= bSfx.x + bSfx.w and ty >= bSfx.y and ty <= bSfx.y + bSfx.h then
            Audio.setSfxVolume(cycle(Audio.sfxVolume))
            Audio.play("ui_confirm", 0, 0.8)
            local d = Save.get()
            d.audio = d.audio or {}
            d.audio.sfx = Audio.sfxVolume
            Save.save()
            return
        end

        -- 3. Affichage des hitboxes (debug)
        local bSet = self.buttons.settings
        if adminUnlocked() and tx >= bSet.x and tx <= bSet.x + bSet.w and ty >= bSet.y and ty <= bSet.y + bSet.h then
            Config.DEBUG_MODE = not Config.DEBUG_MODE
            return
        end

        -- 3. Abandonner
        local bAb = self.buttons.abandon
        if tx >= bAb.x and tx <= bAb.x + bAb.w and ty >= bAb.y and ty <= bAb.y + bAb.h then
            self.confirmQuit = true
            return
        end
    else
        -- Bouton Confirmer abandon
        local bConf = self.modal.confirm
        if tx >= bConf.x and tx <= bConf.x + bConf.w and ty >= bConf.y and ty <= bConf.y + bConf.h then
            -- Sauvegarde de l'or récolté
            if self.runData.goldEarned and self.runData.goldEarned > 0 then
                Save.addGold(self.runData.goldEarned)
            end
            -- Dépile la pause et bascule sur le Menu Hub
            self.sm:pop()
            Save.clearRun() -- quitter = abandonner la course
            self.sm:switch("menu")
            return
        end

        -- Bouton Annuler
        local bCanc = self.modal.cancel
        if tx >= bCanc.x and tx <= bCanc.x + bCanc.w and ty >= bCanc.y and ty <= bCanc.y + bCanc.h then
            self.confirmQuit = false
            return
        end
    end
end

-- Boutons physiques 3DS (A / B / START) : la pause ne doit pas être tactile-only
function PauseState:gamepadpressed(joystick, button)
    if button == "a" then
        self:keypressed("return")
    elseif button == "b" then
        if self.confirmQuit then
            self.confirmQuit = false
        else
            self.sm:pop()
        end
    else
        self:keypressed(button)
    end
end

function PauseState:keypressed(key)
    if key == "return" or key == "start" or key == "p" or key == "escape" then
        if self.confirmQuit then
            self.confirmQuit = false
        else
            self.sm:pop()
        end
    end
end

return PauseState
