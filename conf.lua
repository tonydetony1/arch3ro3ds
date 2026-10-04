function love.conf(t)
    t.identity = "arch3ro"
    -- Game files searched BEFORE the save directory: otherwise every require and
    -- asset lookup checks the SD card first (~85 ms per file on 3DS, taking
    -- multiple seconds on boot). Save file names do not exist in the game archive,
    -- so they are still found in the save directory.
    t.appendidentity = true

    -- IMPORTANT: On 3DS LÖVE-Potion, t.window MUST exist for love.window.setMode() to initialize the PICA200 GPU
    if t.window then
        t.window.title = "Arch3ro"
        t.window.width = 400
        t.window.height = 240
        t.window.resizable = false
        t.window.vsync = 1
        if not (love._console or love._os == "3DS") then
            t.window.height = 480
            t.window.icon = "assets/icon.png"
        else
            t.window.icon = nil
        end
    end

    -- Old 3DS memory optimization: disable unused heavy modules
    if t.modules then
        t.modules.physics = false
        t.modules.video = false
        t.modules.thread = false
        -- Without DSP firmware (sdmc:/3ds/dspfirm.cdc, DSP1 dump), the audio module fails
        -- and LÖVE Potion exits before opening the window: boot without sound in that case
        if love._console or love._os == "3DS" then
            local dsp = io.open("sdmc:/3ds/dspfirm.cdc", "rb")
            if dsp then dsp:close() else t.modules.audio = false end
        end
    end
end

