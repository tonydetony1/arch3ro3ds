-- src/audio/audio.lua
-- Gestion du son : effets (sources pré-allouées, aucune allocation en combat) et musiques en boucle.
-- Tolérant aux pannes : si le module audio ou un fichier manque, le jeu continue sans son.

local Audio = {
    ready = false,
    enabled = true,
    sfxVolume = 0.85,
    musicVolume = 0.55,
    sources = {},      -- [nom] = { sources..., index }
    music = {},        -- [nom] = Source
    currentMusic = nil,
    fade = nil,        -- { from, to, t, dur, nextName }
}

local SFX_PATH = "assets/audio/sfx/"
local MUSIC_PATH = "assets/audio/music/"
local VOICES = 3 -- nombre de voix simultanées par effet

local SFX_LIST = {
    "shoot_bow", "shoot_heavy", "shoot_fast", "hit", "crit", "monster_die", "player_hurt",
    "pickup_coin", "pickup_gem", "pickup_heart", "level_up", "gate_open", "explosion",
    "pot_break", "dash", "ultimate", "boss_roar", "ui_click", "ui_confirm", "ui_cancel",
    "wheel_tick", "victory", "defeat",
}

local MUSIC_LIST = { "hub", "battle", "boss" }

local function fileExists(path)
    if love.filesystem and love.filesystem.getInfo then
        return love.filesystem.getInfo(path) ~= nil
    end
    return true
end

function Audio.init()
    if Audio.ready then return end
    if not love.audio or not love.audio.newSource then
        Audio.enabled = false
        Audio.ready = true
        return
    end

    -- Effets en WAV (PCM brut : aucun décodage Vorbis sur le processeur 3DS). Chaque son est
    -- décodé une fois en SoundData ; ses voix partagent ces échantillons en mémoire.
    for _, name in ipairs(SFX_LIST) do
        local path = SFX_PATH .. name .. ".wav"
        if not fileExists(path) then path = SFX_PATH .. name .. ".ogg" end
        if fileExists(path) then
            local okData, data = false, nil
            if love.sound and love.sound.newSoundData then
                okData, data = pcall(love.sound.newSoundData, path)
            end
            local voices = { index = 1 }
            for i = 1, VOICES do
                local ok, src = pcall(love.audio.newSource, okData and data or path, "static")
                if ok and src then
                    voices[i] = src
                end
            end
            if voices[1] then Audio.sources[name] = voices end
        end
    end

    require("src.core.boot_profile").mark("  audio: effets")
    for _, name in ipairs(MUSIC_LIST) do
        local path = MUSIC_PATH .. name .. ".ogg"
        if fileExists(path) then
            local ok, src = pcall(love.audio.newSource, path, "stream")
            if ok and src then
                src:setLooping(true)
                Audio.music[name] = src
            end
        end
    end

    Audio.ready = true
end

-- Joue un effet ; pitch : variation aléatoire (ex : 0.08 = +/-8 %)
function Audio.play(name, pitchVar, volumeScale)
    if not Audio.enabled then return end
    if not Audio.ready then Audio.init() end
    local voices = Audio.sources[name]
    if not voices then return end

    local src = voices[voices.index]
    voices.index = (voices.index % VOICES) + 1
    if not src then return end

    pcall(function()
        if src:isPlaying() then src:stop() end
        src:setVolume(Audio.sfxVolume * (volumeScale or 1.0))
        if pitchVar and src.setPitch then
            src:setPitch(1.0 + (math.random() * 2 - 1) * pitchVar)
        end
        src:play()
    end)
end

-- Lance une musique (fondu enchaîné si une autre tourne déjà)
function Audio.playMusic(name, fadeTime)
    if not Audio.enabled then return end
    if not Audio.ready then Audio.init() end
    if Audio.currentMusic == name then return end

    local target = Audio.music[name]
    if not target then return end

    if Audio.music[Audio.currentMusic] and (fadeTime or 0) > 0 then
        Audio.fade = { t = 0, dur = fadeTime, nextName = name }
    else
        Audio.stopMusic()
        Audio.currentMusic = name
        pcall(function()
            target:setVolume(Audio.musicVolume)
            target:play()
        end)
    end
end

function Audio.stopMusic()
    local cur = Audio.music[Audio.currentMusic]
    if cur then pcall(function() cur:stop() end) end
    Audio.currentMusic = nil
    Audio.fade = nil
end

function Audio.update(dt)
    local fade = Audio.fade
    if not fade then return end
    fade.t = fade.t + dt
    local ratio = math.min(1.0, fade.t / fade.dur)

    local cur = Audio.music[Audio.currentMusic]
    if cur then pcall(function() cur:setVolume(Audio.musicVolume * (1 - ratio)) end) end

    if ratio >= 1.0 then
        Audio.stopMusic()
        local nextSrc = Audio.music[fade.nextName]
        Audio.currentMusic = fade.nextName
        if nextSrc then
            pcall(function()
                nextSrc:setVolume(Audio.musicVolume)
                nextSrc:play()
            end)
        end
        Audio.fade = nil
    end
end

function Audio.setMusicVolume(v)
    Audio.musicVolume = math.max(0, math.min(1, v))
    local cur = Audio.music[Audio.currentMusic]
    if cur then pcall(function() cur:setVolume(Audio.musicVolume) end) end
end

function Audio.setSfxVolume(v)
    Audio.sfxVolume = math.max(0, math.min(1, v))
end

-- Effet associé à une arme (utilisé à chaque tir)
local WEAPON_SFX = {
    starter_bow = "shoot_bow",
    rapid_daggers = "shoot_fast",
    heavy_ballista = "shoot_heavy",
}

function Audio.playWeapon(weaponId)
    Audio.play(WEAPON_SFX[weaponId] or "shoot_bow", 0.08, 0.7)
end

return Audio
