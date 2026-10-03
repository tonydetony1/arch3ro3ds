function love.conf(t)
    t.identity = "arch3ro"
    -- Fichiers du jeu cherchés AVANT le dossier de sauvegarde : sinon chaque require et
    -- chaque ressource commence par une recherche sur la carte SD (~85 ms par fichier sur
    -- 3DS, soit plusieurs secondes au démarrage). Les noms des fichiers de sauvegarde
    -- n'existent pas dans le jeu, ils restent trouvés dans le dossier de sauvegarde.
    t.appendidentity = true

    -- IMPORTANT : Sur 3DS LÖVE-Potion, t.window DOIT exister pour que love.window.setMode() initialise le GPU PICA200
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

    -- Optimisation mémoire Old 3DS : désactiver les modules lourds inutilisés
    if t.modules then
        t.modules.physics = false
        t.modules.video = false
        t.modules.thread = false
    end
end

