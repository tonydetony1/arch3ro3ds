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
        resume   = { x = 40, y = 40,  w = 240, h = 40 },
        music    = { x = 40, y = 90,  w = 116, h = 34 },
        sfx      = { x = 164, y = 90, w = 116, h = 34 },
        abandon  = { x = 40, y = 132, w = 240, h = 38 },
        settings = { x = 90, y = 178, w = 140, h = 24 },
    }

    -- Boutons de la modale de confirmation
    self.modal = {
        box     = { x = 20, y = 50,  w = 280, h = 140 },
        confirm = { x = 35, y = 135, w = 115, h = 38 },
        cancel  = { x = 170, y = 135, w = 115, h = 38 },
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

-- ============================================================================
-- TOP SCREEN (400x240) : RÉCAPITULATIF DE LA RUN & COMPÉTENCES DRAFT
-- ============================================================================
function PauseState:drawTop()
    local w = Config.TOP_WIDTH
    local h = Config.TOP_HEIGHT

    Skin.rect(C.ink, 0, 0, w, h, 0.93)
    Skin.panel(10, 8, w - 20, h - 16, "dark")

    -- Titre
    Skin.ribbon(w / 2, 4, 120, 20, "gold")
    PixelFont.printf("PAUSE", 0, 7, w, "center", C.white, "main", 1, "shadow")

    -- Résumé de la run
    local modeLabels = {
        infinite = "LE GOUFFRE (INFINI)", boss_rush = "BOSS RUSH", survival = "ARÈNE DE SURVIE",
    }
    local modeName = modeLabels[self.runData.mode] or "ASCENSION (50 SALLES)"
    PixelFont.printf(modeName, 18, 30, w - 36, "center", C.cyan, "main")

    local stats = {
        { icon = "icon_door", label = "SALLE", value = tostring(self.runData.room or 1) },
        { icon = "icon_coin", label = "OR", value = "+" .. (self.runData.goldEarned or 0) },
        { icon = "icon_skull", label = "VAINCUS", value = tostring(self.runData.kills or 0) },
    }
    for i, st in ipairs(stats) do
        local sx = 20 + (i - 1) * 122
        Skin.panel(sx, 46, 116, 34, "inset")
        love.graphics.setColor(1, 1, 1, 1)
        Art.draw(st.icon, 1, sx + 16, 63)
        PixelFont.print(st.label, sx + 28, 50, C.fog, "tiny")
        PixelFont.print(st.value, sx + 28, 59, C.white, "main")
    end

    -- Compétences acquises
    PixelFont.print("COMPÉTENCES ACTIVES", 20, 86, C.yellow, "main")
    local skills = self.runData.skills or {}
    if #skills == 0 then
        PixelFont.print("Aucune compétence acquise pour l'instant.", 20, 104, C.steel, "main")
    else
        for i, sk in ipairs(skills) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local sx = 18 + col * 184
            local sy = 102 + row * 32
            if sy + 30 < h - 10 then
                Skin.panel(sx, sy, 180, 30, "inset")
                love.graphics.setColor(1, 1, 1, 1)
                Art.draw(Icons.skillIcon(sk.icon), 1, sx + 14, sy + 15)
                PixelFont.printf(sk.name, sx + 26, sy + 3, 150, "left", C.white, "main", 1, nil, 1)
                PixelFont.printf(sk.desc, sx + 26, sy + 15, 150, "left", C.fog, "tiny", 1, nil, 2, 8)
            end
        end
        if #skills > 8 then
            PixelFont.printf("+" .. (#skills - 8) .. " autres", 18, h - 22, w - 36, "right", C.silver, "tiny")
        end
    end
end

-- ============================================================================
-- BOTTOM SCREEN (320x240) : BOUTONS TACTILES & CONFIRMATION D'ABANDON
-- ============================================================================
function PauseState:drawBottom()
    local botW = Config.BOTTOM_WIDTH
    local botH = Config.BOTTOM_HEIGHT

    Skin.background(botW, botH)

    if not self.confirmQuit then
        local bRes = self.buttons.resume
        UI.drawGummyButton(bRes.x, bRes.y, bRes.w, bRes.h, "REPRENDRE LA PARTIE", "emerald", self.pressed == "resume", "check")

        local bMus = self.buttons.music
        UI.drawGummyButton(bMus.x, bMus.y, bMus.w, bMus.h,
            string.format("MUSIQUE %d%%", math.floor(Audio.musicVolume * 100 + 0.5)), "sapphire", self.pressed == "music", "rune")
        local bSfx = self.buttons.sfx
        UI.drawGummyButton(bSfx.x, bSfx.y, bSfx.w, bSfx.h,
            string.format("SONS %d%%", math.floor(Audio.sfxVolume * 100 + 0.5)), "violet", self.pressed == "sfx", "sparkles")

        local bSet = self.buttons.settings
        local debugText = Config.DEBUG_MODE and "HITBOXES : ON" or "HITBOXES : OFF"
        UI.drawGummyButton(bSet.x, bSet.y, bSet.w, bSet.h, debugText, "gray", self.pressed == "settings")

        local bAb = self.buttons.abandon
        UI.drawGummyButton(bAb.x, bAb.y, bAb.w, bAb.h, "ABANDONNER LA RUN", "ruby", self.pressed == "abandon", "skull")

        PixelFont.printf("[START] pour reprendre", 0, 208, botW, "center", C.steel, "tiny")
    else
        local m = self.modal.box
        Skin.rect(C.ink, 0, 0, botW, botH, 0.75)
        Skin.panel(m.x, m.y, m.w, m.h, "dark")
        Skin.ribbon(botW / 2, m.y - 8, 200, 20, "red")
        PixelFont.printf("ABANDONNER LA RUN ?", 0, m.y - 5, botW, "center", C.white, "main", 1, "shadow")
        PixelFont.printf("L'or récolté dans cette run sera conservé dans votre coffre.",
            m.x + 14, m.y + 34, m.w - 28, "center", C.silver, "main")

        local bConf = self.modal.confirm
        UI.drawGummyButton(bConf.x, bConf.y, bConf.w, bConf.h, "CONFIRMER", "ruby", self.pressed == "confirm")
        local bCanc = self.modal.cancel
        UI.drawGummyButton(bCanc.x, bCanc.y, bCanc.w, bCanc.h, "ANNULER", "emerald", self.pressed == "cancel")
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
        if tx >= bSet.x and tx <= bSet.x + bSet.w and ty >= bSet.y and ty <= bSet.y + bSet.h then
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
