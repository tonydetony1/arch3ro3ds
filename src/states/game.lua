-- src/states/game.lua
-- Boucle de gameplay Archero complète : Biomes, Loot physique, Magnétisme, Leveling exponentiel & 200 Skills Hook

local Config = require("src.data.config")
local Weapons = require("src.data.weapons")
local Items = require("src.data.items")
local Skills = require("src.data.skills")
local Save = require("src.data.save")
local WorldManager = require("src.core.world_manager")
local Rooms = require("src.data.rooms")
local Pool = require("src.core.pool")
local Camera = require("src.core.camera")
local ObstacleManager = require("src.core.obstacle_manager")
local RunLoop = require("src.core.runloop")
local WaveRunner = require("src.core.wave_runner")
local EliteAffixes = require("src.core.elite_affixes")
local Encounters = require("src.data.encounters")
local Player = require("src.entities.player")
local Projectile = require("src.entities.projectile")
local Dummy = require("src.entities.dummy")
local Loot = require("src.entities.loot")
local FCT = require("src.entities.fct")
local Arena = require("src.render.arena")
local HUD = require("src.ui.hud")
local AIController = require("src.core.ai_controller")
local VFX = require("src.render.vfx_manager")
local SpecialRoomManager = require("src.core.special_room_manager")
local Depth = require("src.render.depth")
local Audio = require("src.audio.audio")
local Banner = require("src.ui.banner")
local Bestiary = require("src.data.bestiary")
local Perf = require("src.core.perf")
local Bestiary = require("src.data.bestiary")
local Balance = require("src.data.balance")

-- Temps processeur par image accordé à la préparation de la salle suivante (secondes).
-- Sur console, le budget est la marge laissée par l'image précédente avant 1/60 s ; hors
-- console (pas de mesure), budgets fixes.
local PREFETCH_BUDGET_COMBAT = 0.002
local PREFETCH_BUDGET_CALM = 0.008
local PREFETCH_MIN_COMBAT = 0.0005 -- avance garantie même quand l'image est pleine
local PREFETCH_MIN_CALM = 0.002
local FRAME_TARGET = 0.0155        -- 1/60 s moins une marge pour le present()

-- Renforts (src/core/wave_runner.lua) : runes au sol avant leur arrivée, et distance
-- minimale au héros (sinon renvoyés de l'autre côté du centre de la salle)
local REINFORCE_WARNING = 1.0
local REINFORCE_MIN_DIST = 110
local REINFORCE_CLEARANCE = 16
local VOLATILE_COLOR = { 1.0, 0.45, 0.1, 1.0 }

local function prefetchBudget(busy)
    local work = RunLoop.lastWork
    if not work then return busy and PREFETCH_BUDGET_COMBAT or PREFETCH_BUDGET_CALM end
    local slack = FRAME_TARGET - (work - ObstacleManager.lastPrefetchTime)
    return math.max(busy and PREFETCH_MIN_COMBAT or PREFETCH_MIN_CALM, math.min(PREFETCH_BUDGET_CALM, slack))
end

local GameState = {}
GameState.__index = GameState

local function checkAABB(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x1 + w1 > x2 and
           y1 < y2 + h2 and
           y1 + h1 > y2
end

function GameState.new(stateMachine)
    local self = setmetatable({}, GameState)
    self.sm = stateMachine
    return self
end

function GameState:enter(params)
    params = params or {}
    self.gameMode = params.mode or "ascension"
    Audio.playMusic("battle", 0.6)
    self.waveCount = 0
    self.waveTimer = 0

    -- Initialisation du moteur VFX, Atlas et SpriteBatches matériels 3DS
    VFX.init()
    Banner.clear()
    self.slowmoTimer = 0
    self.flashTimer = 0
    self.bossIntroTimer = 0

    local saveData = Save.get()

    -- 1. Initialisation de l'arène, de la caméra et de l'interface
    self.arena = Arena.new()
    self.hud = HUD.new()
    self.camera = Camera.new()
    self.arena.camera = self.camera
    self.obstacleManager = ObstacleManager.new()
    self.specialRoomManager = SpecialRoomManager.new()
    self.mapW = 640
    self.mapH = 480

    -- 2. Initialisation du joueur et application des équipements de la Forge
    self.player = Player.new(self.mapW / 2, self.mapH - 50)
    -- Bonus de maîtrise du bestiaire (50 / 200 / 500 éliminations par monstre)
    self.player.mastery = Bestiary.buildMasteryTable(Save.getBestiary())
    self.player:setBounds(self.mapW, self.mapH)

    -- Application du Héros sélectionné et de ses passifs uniques Archero 2
    local Heroes = require("src.data.heroes")
    local curHeroId = (saveData and saveData.selectedHero) or "atreus"
    self.heroId = curHeroId
    -- Bonus d'ensembles d'équipement (2 et 4 pièces)
    Items.applySetBonuses(self.player, saveData.equipped)

    Heroes.applyHeroPassives(self.player, curHeroId)

    local Skills = require("src.data.skills")
    Skills.checkSynergies(self.player, self.acquiredSkills)

    if saveData and saveData.equipped then
        local wId = saveData.equipped.weapon or "starter_bow"
        self.player:equipWeapon(wId)

        local aId = saveData.equipped.armor
        if aId then
            local aStats = Items.getStats(aId, Save.getItemLevel(aId), Save.getItemRarity(aId), Save.getItemStars(aId))
            self.player.maxHp = self.player.maxHp + aStats.hp
            self.player.hp = self.player.maxHp
            self.player.dodgeChance = (self.player.dodgeChance or 0) + (aStats.dodge or 0) / 100
        end

        local rId = saveData.equipped.ring
        if rId then
            local rStats = Items.getStats(rId, Save.getItemLevel(rId), Save.getItemRarity(rId), Save.getItemStars(rId))
            self.player.critChance = self.player.critChance + ((rStats.crit or 0) / 100)
            self.player.damageMult = self.player.damageMult + ((rStats.atk or 0) / 30)
        end
    end

    -- 3. Pools universels pré-alloués (Zéro allocation en combat)
    self.projectilePool = Pool.new(Config.POOL.PROJECTILES, Projectile.create)
    self.dummyPool = Pool.new(Config.POOL.DUMMIES, Dummy.create)
    self.lootPool = Pool.new(Config.POOL.LOOT or 120, Loot.create)
    self.fctPool = Pool.new(Config.POOL.FCT or 40, FCT.create)

    -- 4. Économie & Progression de la run
    self.goldEarnedRun = 0
    self.kills = 0
    self.roomNumber = 1
    self.chapterIndex = 1
    self.ultimateCharge = 0.5
    self.acquiredSkills = {}

    -- 5. Machine d'états de la salle (Archero Flow)
    self.phase = "combat" -- "combat", "clear", "transition"
    self.isGateOpen = false
    self.fadeAlpha = 0
    self.fadeDirection = 0 -- 1 = fade out, -1 = fade in
    self.spawnWarningTimer = 0
    self.pendingSpawns = {}

    -- 6. Moteur de Juice sensoriel
    self.shakeTime = 0
    self.shakeIntensity = 0
    self.hitStopTime = 0

    -- 7. Draft de compétences
    self.isDrafting = false
    self.draftOptions = {}

    -- 8. Game Over
    self.isGameOver = false
    self.gameOverTimer = 0
    self.hasSpunStartWheel = false

    -- Application des Talents permanents
    local talents = Save.getTalents()
    if talents then
        if talents.strength and talents.strength > 0 then
            self.player.damageMult = self.player.damageMult + talents.strength * 0.05
        end
        if talents.vitality and talents.vitality > 0 then
            local bonusHp = talents.vitality * 30
            self.player.maxHp = self.player.maxHp + bonusHp
            self.player.hp = self.player.maxHp
        end
        if talents.agility and talents.agility > 0 then
            self.player.dodgeChance = (self.player.dodgeChance or 0) + talents.agility * 0.02
        end
    end

    -- Bouton tactile Pause
    self.pauseBtn = { x = 290, y = 2, w = 28, h = 21 }

    -- Reprise d'une course interrompue (console éteinte en pleine partie)
    if params.resume then
        self:applyResume(params.resume)
    end

    -- Lancement de la première salle
    self:setupRoom(self.roomNumber)

    -- Talent Gloire : offre immédiatement un Draft de départ gratuit !
    -- Si la salle 1 débute par la Roue de la Fortune, différer le Draft juste après la roue
    if talents and (talents.glory or 0) >= 1 then
        if self.phase == "wheel" then
            self.pendingGloryDraft = true
        else
            self:openDraft()
        end
    end
end

-- Restaure une course sauvegardée par Save.saveRun (statistiques du héros, compétences, or)
function GameState:applyResume(run)
    self.hasSpunStartWheel = true
    self.roomNumber = run.room or 1
    self.goldEarnedRun = run.gold or 0
    self.kills = run.kills or 0
    self.ultimateCharge = run.ultimate or 0
    if run.weapon then self.player:equipWeapon(run.weapon) end
    for k, v in pairs(run.player or {}) do
        if type(self.player[k]) ~= "function" then self.player[k] = v end
    end
    self.acquiredSkills = {}
    for _, id in ipairs(run.skills or {}) do
        local sk = Skills.get(id)
        if sk then table.insert(self.acquiredSkills, sk) end
    end
end

function GameState:triggerShake(duration, intensity)
    VFX.shake(intensity * 2.0, duration)
end

-- Préparation et génération de la salle avec dimensions étendues dynamiques
-- Description déterministe d'une salle (type, grille, taille, décor) : partagée par
-- setupRoom et par la préparation anticipée de la salle suivante
function GameState:roomSpec(roomNum)
    local roomType = WorldManager.getRoomType(roomNum)
    if self.gameMode == "boss_rush" then
        roomType = "boss"
    elseif self.gameMode == "survival" then
        roomType = "combat"
    end
    -- Grille de la salle : centre dégagé pour boss / roue / survie, vide pour l'ange
    local kind = "combat"
    if roomType == "boss" or self.gameMode == "survival"
        or (roomNum == 1 and not self.hasSpunStartWheel) then
        kind = "arena"
    elseif roomType == "angel" then
        kind = "sanctuary"
    end
    local chapterIndex = math.min(6, math.floor((roomNum - 1) / 10) + 1)
    local theme = WorldManager.getTheme(chapterIndex)
    -- Dimensions taillées sur la grille de la salle (629x463 à 694x508)
    local mapW, mapH = Rooms.roomSize(roomNum)
    return {
        room = roomNum, roomType = roomType, kind = kind, chapterIndex = chapterIndex,
        mapW = mapW, mapH = mapH, variant = theme.variant, hazard = theme.hazard,
        key = table.concat({ roomNum, kind, mapW, mapH, tostring(theme.variant), tostring(theme.hazard) }, ":"),
    }
end

-- Lance la préparation de la salle suivante (voir ObstacleManager.prefetch)
function GameState:prefetchNextRoom()
    if self.gameMode == "survival" or self.isGameOver then return end
    ObstacleManager.prefetch(self:roomSpec(self.roomNumber + 1))
end

function GameState:setupRoom(roomNum)
    if roomNum > 1 then Save.addQuestProgress("rooms", 1) end
    Audio.playMusic((WorldManager.getRoomType(roomNum) == "boss" or self.gameMode == "boss_rush") and "boss" or "battle", 0.5)
    local spec = self:roomSpec(roomNum)
    -- Salle préparée pendant la précédente : on termine ce qui reste (souvent rien)
    ObstacleManager.settlePrefetch(spec.key)
    self.roomNumber = roomNum
    self.chapterIndex = spec.chapterIndex
    self.roomType = spec.roomType
    self.devilEncountered = false
    self.bossWheelDone = false

    self.mapW, self.mapH = spec.mapW, spec.mapH

    self.camera:setBounds(self.mapW, self.mapH)
    self.player:setBounds(self.mapW, self.mapH)
    self.obstacleManager:setTheme(spec.variant, spec.hazard)
    self.obstacleManager:generate(self.mapW, self.mapH, roomNum, spec.kind)

    local spawns, chap
    self.waveRunner = nil
    if self.gameMode == "boss_rush" then
        spawns, chap = WorldManager.generateBossRush(self.chapterIndex, roomNum, self.mapW, self.mapH)
    elseif self.gameMode == "survival" then
        spawns, chap = WorldManager.generateSurvivalWave(self.chapterIndex, 1, self.mapW, self.mapH)
        self.waveCount = 1
        self.waveTimer = 15.0
    else
        -- Rencontre composée : 1 à 3 vagues, renforts déclenchés en jeu (voir update)
        local enc
        enc, chap = WorldManager.generateEncounter(self.chapterIndex, roomNum, self.mapW, self.mapH)
        self.waveRunner = WaveRunner.new(enc.waves)
        spawns = self.waveRunner:start()
    end
    spawns = self.obstacleManager:placeSpawns(spawns)
    self.currentChapter = chap
    self.roomGoldStart = self.goldEarnedRun or 0

    -- Bannière d'entrée : nouveau chapitre (salles 1, 11, 21…) ou simple rappel de salle
    if self.gameMode == "ascension" and (roomNum - 1) % 10 == 0 then
        Banner.show("chapter", "CHAPTER " .. self.chapterIndex, chap and chap.name or "")
    elseif self.gameMode == "boss_rush" then
        Banner.show("room", "BOSS " .. roomNum)
    elseif self.gameMode ~= "survival" then
        Banner.show("room", "STAGE " .. roomNum .. " / 50")
    end

    -- Décor du chapitre (prairie, désert, cristal, enfer) puis pré-rendu sur Canvas
    self.arena:setTheme(self.chapterIndex)
    self.arena:buildCanvas(self.mapW, self.mapH, self.currentChapter and self.currentChapter.palette or nil, self.obstacleManager)

    -- Nettoyage des ennemis de la salle précédente
    self.dummyPool:clear()
    self.isGateOpen = false

    if self.gameMode == "survival" then
        self.phase = "combat"
        self.specialRoomManager.isActive = false
        self.specialRoomManager.activeType = "none"
        self.spawnWarningTimer = 0.55
        self.pendingSpawns = spawns
    elseif self.roomType == "angel" then
        -- SALLE DE L'ANGE (Sanctuaire sacré de bénédictions sans monstres)
        self.phase = "angel"
        self.spawnWarningTimer = 0
        self.pendingSpawns = {}
        self.specialRoomManager:setup("angel", self.player, self.roomNumber)
    elseif roomNum == 1 and not self.hasSpunStartWheel then
        -- ROUE DE LA FORTUNE DE DÉPART (LUCKY WHEEL)
        self.hasSpunStartWheel = true
        self.phase = "wheel"
        self.spawnWarningTimer = 0
        self.pendingSpawns = spawns
        self.specialRoomManager:setup("wheel", self.player, self.roomNumber)
    else
        self.phase = "combat"
        self.specialRoomManager.isActive = false
        self.specialRoomManager.activeType = "none"
        self.spawnWarningTimer = 0.55
        self.pendingSpawns = spawns
    end

    -- Positionnement du joueur à l'entrée sud de la salle
    self.player.x = self.mapW / 2
    self.player.y = self.mapH - 50
    self.player.vx = 0
    self.player.vy = 0
    self.camera:setPosition(self.player.x, self.player.y)

    -- Sauvegarde automatique : la course reprend ici si la console est éteinte
    if roomNum > 1 and not self.isGameOver then
        Save.saveRun(self)
    end

    self:prefetchNextRoom()
end

-- Renforts : points d'apparition de la salle, mais jamais sur le héros (renvoyés de
-- l'autre côté du centre s'ils tombent à moins de REINFORCE_MIN_DIST), puis case libre
function GameState:placeReinforcements(spawns)
    local placed = self.obstacleManager:placeSpawns(spawns)
    local cx, cy = self.mapW / 2, self.mapH / 2
    local p = self.player
    for _, sp in ipairs(placed) do
        local dx, dy = sp.x - p.x, sp.y - p.y
        if dx * dx + dy * dy < REINFORCE_MIN_DIST * REINFORCE_MIN_DIST then
            sp.x, sp.y = self.obstacleManager:findFreeSpot(cx * 2 - sp.x, cy * 2 - sp.y, REINFORCE_CLEARANCE)
        end
    end
    return placed
end

function GameState:spawnMonstersNow()
    local bossType = nil
    for _, sp in ipairs(self.pendingSpawns) do
        local d = self.dummyPool:obtain()
        if d then
            d:spawn(sp.x, sp.y, sp.hp, sp.type)
            d.isBoss = sp.isBoss or false
            if d.isBoss then bossType = sp.type end
            if sp.affixes then
                EliteAffixes.apply(d, sp.affixes, sp.champion)
                VFX.addFCT(d.x, d.y - 22, sp.champion and "CHAMPION" or Encounters.AFFIXES[sp.affixes[1]].label, true)
                if sp.champion then
                    Banner.show("boss", Bestiary.nameOf(sp.type):upper(), nil, "CHAMPION")
                    Audio.play("boss_roar", 0.1, 0.7)
                end
            end
        end
    end
    self.pendingSpawns = {}
    VFX.shakeLight()

    -- Intro de boss : bannière, rugissement, boss figé le temps de la présentation
    if bossType then
        self.bossName = Bestiary.nameOf(bossType):upper()
        Banner.show("boss", self.bossName)
        Audio.play("boss_roar", 0, 1.0)
        VFX.shakeHeavy()
        self.bossIntroTimer = 1.3
    end
end

function GameState:openDraft()
    Audio.play("level_up", 0, 0.9)
    self.isDrafting = true
    self.draftCursor = 2
    self.draftOptions = Skills.getRandomDraft(3, self.acquiredSkills)
    VFX.shakeLight()
end

-- Fait sauter du butin physique lors de l'élimination d'un monstre
-- Impact d'un météore céleste : dégâts de zone + statut élémentaire
local METEOR_STATUS = {
    meteor_fire = { fire = true },
    meteor_ice = { ice = true },
    meteor_thunder = { lightning = true },
}

-- Dégâts majorés par la maîtrise du bestiaire contre ce type de monstre
function GameState:masteryDamage(target, dmg)
    local p = self.player
    local mult = p.mastery and p.mastery[target.type] or 1
    -- Toucher Obscur : la marque amplifie tous les dégâts reçus
    if (target.darkMark or 0) > 0 then mult = mult * 1.25 end
    -- Spécialisation anti-boss (compétences "Tueur de Titans")
    if target.isBoss and (p.bossDamageMult or 1) ~= 1 then
        mult = mult * p.bossDamageMult
    end

    local out = (mult == 1) and dmg or math.floor(dmg * mult + 0.5)

    -- Vol de vie : soigne une fraction des dégâts infligés
    if (p.lifeSteal or 0) > 0 and p.hp < p.maxHp then
        local heal = out * p.lifeSteal
        p.lifeStealPool = (p.lifeStealPool or 0) + heal
        if p.lifeStealPool >= 1 then
            local whole = math.floor(p.lifeStealPool)
            p.lifeStealPool = p.lifeStealPool - whole
            p.hp = math.min(p.maxHp, p.hp + whole)
        end
    end

    return out
end

function GameState:explodeMeteor(proj)
    local aoe = proj.aoeRadius or 44
    local elements = METEOR_STATUS[proj.lobKind] or { fire = true }
    VFX.shakeHeavy()
    VFX.hitStop(0.04)
    Audio.play("explosion", 0.1, 0.9)
    VFX.addSparks(proj.targetX, proj.targetY, 12, proj.color or { 1, 0.5, 0.15, 1 })

    for i = self.dummyPool.activeCount, 1, -1 do
        local target = self.dummyPool.items[self.dummyPool.activeList[i]]
        if target and target.alive and AIController.canTakeDamage(target) then
            local dx = target.x - proj.targetX
            local dy = target.y - proj.targetY
            local distSq = dx * dx + dy * dy
            if distSq <= aoe * aoe then
                local dist = math.max(1, math.sqrt(distSq))
                local dmgOut = self:masteryDamage(target, proj.damage)
                local isDead = target:takeDamage(dmgOut, dx / dist, dy / dist, elements)
                VFX.triggerHitFlash(target, 3)
                VFX.addFCT(target.x, target.y - 10, dmgOut, true)
                if isDead or not target.alive then
                    self:handleMonsterDeath(target)
                end
            end
        end
    end
end

-- ============================================================================
-- MORT D'UN MONSTRE : partagé par les flèches, les météores et les explosions
-- ============================================================================
function GameState:handleMonsterDeath(target)
    Audio.play(target.isBoss and "explosion" or "monster_die", 0.1, target.isBoss and 1.0 or 0.6)
    Save.recordKill(target.type)
    Save.addQuestProgress("kills", 1)
    if target.isBoss then Save.addQuestProgress("bosses", 1) end
    VFX.shakeHeavy()
    if target.isBoss then
        -- Mort du boss : arrêt sur image, flash blanc puis ralenti
        VFX.hitStop(0.14)
        VFX.addSparks(target.x, target.y, 8, { 1.0, 0.85, 0.3, 1.0 })
        self.slowmoTimer = 0.9
        self.flashTimer = 0.22
    else
        VFX.hitStop(0.04)
        VFX.addSparks(target.x, target.y, 5, { 1.0, 1.0, 1.0, 1.0 })
    end
    AIController.onDeath(target, self.dummyPool, self.fctPool)
    -- Élite "volatile" : explosion télégraphiée à l'endroit de sa mort (bombe ennemie)
    local blast = EliteAffixes.onDeath(target, self.chapterIndex)
    if blast then
        local bomb = self.projectilePool:obtain()
        if bomb then
            bomb:spawnLobbed(blast.x, blast.y, blast.x, blast.y, blast.delay, blast.damage, blast.radius,
                VOLATILE_COLOR, true)
        end
    end
    self.dummyPool:free(target)
    self.kills = self.kills + 1
    self.ultimateCharge = math.min(1.0, self.ultimateCharge + 0.18)

    -- Synergie Flammes Toxiques (Feu + Poison)
    if self.player.hasSynergyToxicFlame and (target.status and target.status.poison and target.status.poison > 0) then
        VFX.shakeMedium()
        VFX.addSparks(target.x, target.y, 16, { 1.0, 0.35, 0.1, 1.0 })
        VFX.addFCT(target.x, target.y - 14, "TOXIC FLAMES!", true)
        for nb = 1, self.dummyPool.activeCount do
            local other = self.dummyPool.items[self.dummyPool.activeList[nb]]
            if other and other.alive and other.id ~= target.id then
                local odx = other.x - target.x
                local ody = other.y - target.y
                if (odx * odx + ody * ody) <= (55 * 55) then
                    other:takeDamage(35, odx / 55, ody / 55, { fire = true })
                    VFX.triggerHitFlash(other, 2)
                    VFX.addFCT(other.x, other.y - 10, 35, true)
                end
            end
        end
    end

    -- Butin physique
    self:dropLoot(target.x, target.y, target.isBoss)

    -- Hooks onMonsterDeath (Explosion macabre, Soif de sang…)
    for _, sk in ipairs(self.acquiredSkills) do
        if sk.hooks and sk.hooks.onMonsterDeath then
            sk.hooks.onMonsterDeath(target, self.player, {
                dummyPool = self.dummyPool,
                projectilePool = self.projectilePool,
                fctPool = self.fctPool,
            })
        end
    end
end

function GameState:dropLoot(x, y, isBoss)
    local dropCount = isBoss and 6 or math.random(1, 3)

    local depth = Balance.depthMultiplier(self.roomNumber)

    -- Un boss garantit un pactole proportionnel à la profondeur atteinte
    if isBoss then
        local bonus = math.random(Balance.LOOT.bossBonusMin, Balance.LOOT.bossBonusMax)
        self.goldEarnedRun = self.goldEarnedRun + math.floor(bonus * depth * 2.5)
    end

    for i = 1, dropCount do
        local l = self.lootPool:obtain()
        if l then
            -- Tirage : Pièces d'or en majorité, Gemmes d'XP, Cœur si blessé
            local r = math.random()
            local lootType = "coin"
            local val = math.random(Balance.LOOT.coinMin, Balance.LOOT.coinMax)
                * (self.player.goldMultiplier or 1.0) * depth

            if r < 0.40 then
                lootType = "xp"
                val = 25 * depth
            elseif r < 0.55 and self.player.hp < self.player.maxHp then
                lootType = "heart"
                val = 30
            elseif r < 0.60 then
                lootType = "scroll"
                val = 1
            end

            l:spawn(x, y, lootType, math.floor(val + 0.5))
        end
    end
end

-- ============================================================================
-- BOUCLE DE MISE À JOUR PRINCIPALE
-- ============================================================================
function GameState:update(dt)
    -- Bannières et flash : temps réel (non affectés par le ralenti ni l'arrêt sur image)
    Banner.update(dt)
    if self.flashTimer > 0 then self.flashTimer = self.flashTimer - dt end

    -- Préparation de la salle suivante : petite tranche en plein combat, plus large au calme
    local busy = self.phase == "combat" and self.dummyPool.activeCount > 0
    ObstacleManager.stepPrefetch(prefetchBudget(busy))

    -- 1. Moteur VFX : Screen Shake, FCT, Particules & Hit-Stop micro-pause (0.05s sur crit / mort)
    if VFX.update(dt) then
        return -- Fige complètement le jeu pendant 0.05s !
    end

    -- Ralenti (mort d'un boss) : tout le gameplay tourne à 30 %
    if self.slowmoTimer > 0 then
        self.slowmoTimer = self.slowmoTimer - dt
        dt = dt * 0.3
    end

    -- Gestion du Game Over (Transition cinématique vers GameOverState)
    if self.isGameOver then
        self.gameOverTimer = self.gameOverTimer + dt
        if self.gameOverTimer >= 1.2 then
            Save.addGold(self.goldEarnedRun)
            Save.addQuestProgress("gold", self.goldEarnedRun)
            Save.addQuestProgress("runs", 1, true)
            local sData = Save.get()
            local isNewRecord = false
            local prevRecord = (self.gameMode == "ascension") and (sData.records.ascensionMax or 1) or (sData.records.infiniteMax or 1)
            if self.roomNumber > prevRecord then
                isNewRecord = true
                if self.gameMode == "ascension" then
                    sData.records.ascensionMax = self.roomNumber
                else
                    sData.records.infiniteMax = self.roomNumber
                end
            end
            Audio.play("defeat", 0, 0.9)
            Audio.playMusic("hub", 0.8)
            Save.clearRun()
            if self.gameMode == "survival" then
                Save.setEventRecord("survival", self.waveCount or 0)
            elseif self.gameMode == "boss_rush" then
                Save.setEventRecord("boss_rush", self.roomNumber)
            end
            Save.save()

            self.sm:switch("gameover", {
                waves = self.waveCount,
                room = self.roomNumber,
                goldEarned = self.goldEarnedRun,
                kills = self.kills,
                skills = self.acquiredSkills,
                mode = self.gameMode,
                isNewRecord = isNewRecord,
                bestRoom = (self.gameMode == "ascension") and sData.records.ascensionMax or sData.records.infiniteMax,
            })
        end
        return
    end

    -- Vie supplémentaire : résurrection avec la moitié des PV
    if self.player.hp <= 0 and (self.player.extraLives or 0) > 0 and not self.isGameOver then
        self.player.extraLives = self.player.extraLives - 1
        self.player.hp = math.floor(self.player.maxHp * 0.5)
        self.player.starActive = math.max(self.player.starActive or 0, 2.0)
        VFX.shakeHeavy()
        VFX.addSparks(self.player.x, self.player.y, 22, { 1.0, 0.9, 0.4, 1.0 })
        VFX.addFCT(self.player.x, self.player.y - 24, "RESURRECTION!", true)
        Audio.play("level_up", 0, 1.0)
    end

    -- Vérification globale de mort du joueur
    if self.player.hp <= 0 and not self.isGameOver then
        self.isGameOver = true
        self.gameOverTimer = 0
        VFX.shakeHeavy()
        VFX.hitStop(0.12)
    end

    -- Gestion de la transition entre salles (Fade Out / Fade In)
    if self.phase == "transition" then
        if self.fadeDirection == 1 then
            self.fadeAlpha = math.min(1.0, self.fadeAlpha + dt * 4)
            if self.fadeAlpha >= 1.0 then
                -- Écran totalement noir : on configure la nouvelle salle !
                self:setupRoom(self.roomNumber + 1)
                -- Maintien de la phase transition pour dérouler le Fade In
                self.phase = "transition"
                self.fadeDirection = -1
            end
        elseif self.fadeDirection == -1 then
            self.fadeAlpha = math.max(0, self.fadeAlpha - dt * 4)
            if self.fadeAlpha <= 0 then
                self.fadeAlpha = 0
                self.fadeDirection = 0
                self.phase = (self.roomType == "angel") and "angel" or "combat"
            end
        end
        return
    end

    -- 0. Mise à jour des Salles Spéciales (Ange Céleste / Démon / Roue de la Fortune)
    -- Toujours exécuté pour garantir que la physique et les animations de la Roue ne soient jamais gelées
    if self.specialRoomManager and self.specialRoomManager.isActive then
        self.specialRoomManager:update(dt)
        if self.specialRoomManager.isResolved and not self.isGateOpen then
            if self.phase == "devil" and self.roomType == "boss" and not self.bossWheelDone then
                -- ROUE DE BOSS : tour de roue exclusif après le grand boss
                self.bossWheelDone = true
                self.phase = "boss_wheel"
                self.specialRoomManager:setup("wheel", self.player, self.roomNumber, "boss")
                self:triggerShake(0.20, 3.0)
            elseif self.phase ~= "wheel" and self.phase ~= "combat" then
                self.isGateOpen = true
                self.phase = "clear"
            end
        end
    end

    -- Si Draft en cours, le jeu est en pause (monstres et combat figés)
    if self.isDrafting then
        self.hud:update(dt, self.player, self.ultimateCharge)
        return
    end

    -- Phase d'anticipation des monstres (runes rouges au sol)
    if self.spawnWarningTimer > 0 then
        self.spawnWarningTimer = self.spawnWarningTimer - dt
        if self.spawnWarningTimer <= 0 then
            self:spawnMonstersNow()
        end
    end

    -- Renforts : vague suivante quand la salle se vide (src/core/wave_runner.lua)
    if self.waveRunner and self.phase == "combat" and not self.isGameOver then
        local spawns, waveNo = self.waveRunner:update(dt, self.dummyPool.activeCount, self.spawnWarningTimer > 0)
        if spawns then
            self.pendingSpawns = self:placeReinforcements(spawns)
            self.spawnWarningTimer = REINFORCE_WARNING
            if waveNo then
                Banner.show("room", self.waveRunner:label())
                VFX.shakeLight()
            end
        end
    end

    -- 1. Mise à jour de l'arène, des obstacles et de l'UI
    self.arena:update(dt, self.isGateOpen)
    self.obstacleManager:update(dt, self.player, self.fctPool, self.dummyPool)
    self.hud:update(dt, self.player, self.ultimateCharge)

    -- 2. Déclencheur des hooks de compétences passives (ex: Rage Berserker)
    for _, sk in ipairs(self.acquiredSkills) do
        if sk.hooks and sk.hooks.onUpdate then
            sk.hooks.onUpdate(self.player, dt, self.dummyPool, self.fctPool, self.projectilePool, self)
        end
    end

    -- 3. Mise à jour du joueur (mouvement avec glissade sur obstacles, squash, tir, orbitaux)
    Perf.sec("u:debut")
    self.player:update(dt, self.projectilePool, self.dummyPool, self.fctPool, self.obstacleManager, self.isGateOpen)
    Perf.sec("u:joueur")

    -- 4. Caméra fluide qui suit le joueur et reste clampée aux parois de l'arène étendue
    self.camera:update(dt, self.player.x, self.player.y)

    -- 5. Mise à jour des projectiles (couverture tactique rocheuse), monstres (IA) et textes
    self.projectilePool:update(dt, self.mapW, self.mapH, self.obstacleManager, self.dummyPool, self.player)
    Perf.sec("u:tirs")
    if self.bossIntroTimer > 0 then
        self.bossIntroTimer = self.bossIntroTimer - dt -- monstres figés pendant l'intro du boss
    else
        self.dummyPool:update(dt, self.player, self.projectilePool, self.obstacleManager, self.dummyPool, self.fctPool, self.mapW, self.mapH)
    end
    Perf.sec("u:monstres")
    self.fctPool:update(dt)

    -- 6. Mise à jour et ramassage du butin physique au sol
    local px, py = self.player.x, self.player.y
    for i = self.lootPool.activeCount, 1, -1 do
        local lIdx = self.lootPool.activeList[i]
        local loot = self.lootPool.items[lIdx]
        local keepAlive, lType, lVal = loot:update(dt, px, py)

        if not keepAlive then
            -- Butin collecté par le joueur !
            if lType == "coin" then
                self.goldEarnedRun = self.goldEarnedRun + lVal
                Audio.play("pickup_coin", 0.12, 0.5)
            elseif lType == "xp" then
                Audio.play("pickup_gem", 0.1, 0.5)
                local leveledUp = self.player:addXp(math.floor(lVal * (self.player.xpMultiplier or 1.0)))
                if leveledUp then
                    self:openDraft()
                end
            elseif lType == "heart" then
                self.player.hp = math.min(self.player.maxHp, self.player.hp + lVal)
                Audio.play("pickup_heart", 0.06, 0.7)
            end
            self.lootPool:free(loot)
        end
    end

    -- 7. Détection des collisions Projectiles (Joueur <-> Monstres et Ennemis <-> Joueur)
    local pCount = self.projectilePool.activeCount
    local dCount = self.dummyPool.activeCount

    for p = pCount, 1, -1 do
        local pIdx = self.projectilePool.activeList[p]
        local proj = self.projectilePool.items[pIdx]

        if proj and proj.alive then
            -- COLLISION PROJECTILE AVEC LES BARILS EXPLOSIFS
            if proj.isLobbed and proj.hasDetonated and not proj.isEnemy then
                self:explodeMeteor(proj)
                self.projectilePool:free(proj)
            elseif self.obstacleManager and self.obstacleManager:checkProjectileHit(proj, self.dummyPool, self.fctPool, self.player, self.lootPool) then
                self.projectilePool:free(proj)
            elseif proj.isEnemy then
                if proj.isLobbed and proj.hasDetonated then
                    -- Explosion AoE de la bombe lobée au sol
                    local pdx = self.player.x - proj.targetX
                    local pdy = self.player.y - proj.targetY
                    local distSq = pdx * pdx + pdy * pdy
                    if distSq <= (proj.aoeRadius * proj.aoeRadius) then
                        local dmg = proj.damage or 20
                        self.player:takeDamage(dmg)
                        if proj.chill then self.player:chill(EliteAffixes.CHILL_TIME) end
                        Audio.play("player_hurt", 0.08, 0.8)
                        VFX.triggerHitFlash(self.player, 3)
                        VFX.shakeMedium()
                        VFX.addFCT(self.player.x, self.player.y - 12, dmg, false)
                        VFX.addSparks(self.player.x, self.player.y, 6, {1, 0.2, 0.2, 1})

                        if self.player.hp <= 0 and not self.isGameOver then
                            self.isGameOver = true
                            self.gameOverTimer = 0
                        end
                    end
                    self.projectilePool:free(proj)
                elseif not proj.isLobbed then
                    -- COLLISION AVEC LES BOUCLIERS ORBITAUX DU JOUEUR (SHIELD GUARD / VORTEX)
                    local blockedByShield = false
                    if self.player.orbitals and #self.player.orbitals > 0 then
                        for _, orb in ipairs(self.player.orbitals) do
                            if orb.isShield then
                                local ox = orb.x or (self.player.x + math.cos(orb.angle) * orb.dist)
                                local oy = orb.y or (self.player.y + math.sin(orb.angle) * orb.dist)
                                local odx = proj.x - ox
                                local ody = proj.y - oy
                                local hitRad = (proj.radius or 3) + 9
                                if (odx * odx + ody * ody) <= (hitRad * hitRad) then
                                    blockedByShield = true
                                    VFX.triggerHitFlash(self.player, 2)
                                    VFX.shakeLight()
                                    VFX.addFCT(ox, oy - 10, "BLOCK", false)
                                    VFX.addSparks(ox, oy, 5, {1.0, 0.9, 0.3, 1.0})
                                    self.projectilePool:free(proj)
                                    break
                                end
                            end
                        end
                    end

                    -- WINGMAN : les familiers s'interposent et interceptent les tirs
                    if not blockedByShield and self.player.hasWingman and self.player.pets then
                        for _, pet in ipairs(self.player.pets) do
                            local pdx = proj.x - pet.x
                            local pdy = proj.y - pet.y
                            local hitRad = (proj.radius or 3) + (pet.radius or 6) + 3
                            if (pdx * pdx + pdy * pdy) <= (hitRad * hitRad) then
                                blockedByShield = true
                                VFX.shakeLight()
                                VFX.addFCT(pet.x, pet.y - 12, "BLOCK", false)
                                VFX.addSparks(pet.x, pet.y, 5, { 0.45, 0.85, 1.0, 1.0 })
                                self.projectilePool:free(proj)
                                break
                            end
                        end
                    end

                    if not blockedByShield then
                        -- COLLISION PROJECTILE DIRECT ENNEMI AVEC LE JOUEUR
                        local pdx = self.player.x - proj.x
                        local pdy = self.player.y - proj.y
                        local pRad = self.player.radius + proj.radius

                        if (pdx * pdx + pdy * pdy) < (pRad * pRad) then
                            -- Test d'esquive (Dash I-Frames ou passif d'armure)
                            if self.player.isDashing or self.player.isInvulnerable or (math.random() < (self.player.dodgeChance or 0)) then
                                VFX.addFCT(self.player.x, self.player.y - 12, "DODGE", false)
                                VFX.addSparks(self.player.x, self.player.y, 5, {0.35, 0.85, 1.0, 1.0})
                            else
                                local dmg = proj.damage or 15
                                self.player.hp = math.max(0, self.player.hp - dmg)
                                if proj.chill then self.player:chill(EliteAffixes.CHILL_TIME) end
                                VFX.triggerHitFlash(self.player, 3)
                                VFX.shakeMedium()
                                VFX.addFCT(self.player.x, self.player.y - 12, dmg, false)
                                VFX.addSparks(self.player.x, self.player.y, 6, {1, 0.2, 0.2, 1})

                                if self.player.hp <= 0 and not self.isGameOver then
                                    self.isGameOver = true
                                    self.gameOverTimer = 0
                                end
                            end
                            self.projectilePool:free(proj)
                        end
                    end
                end
            else
                -- COLLISION PROJECTILE JOUEUR AVEC LES MONSTRES
                local px1, py1, pw1, ph1 = proj:getAABB()

                for d = dCount, 1, -1 do
                    local dIdx = self.dummyPool.activeList[d]
                    local target = self.dummyPool.items[dIdx]

                    if target and target.alive and target.id ~= proj.lastHitTargetId then
                        local dx, dy, dw, dh = target:getAABB()

                        if checkAABB(px1, py1, pw1, ph1, dx, dy, dw, dh) then
                            -- Coup de grâce / Exécution instantanée (Faux de la Mort < 30% PV)
                            local isExecute = false
                            if proj.executeThreshold and not target.isBoss and (target.hp / math.max(1, target.maxHp)) <= proj.executeThreshold then
                                isExecute = true
                                proj.damage = target.hp
                            end

                            -- Dégâts + Knockback physique (amplifié pour la Faux) + Effets Élémentaires
                            local dmgOut = self:masteryDamage(target, proj.damage)
                            Audio.play(proj.isCrit and "crit" or "hit", 0.12, proj.isCrit and 0.75 or 0.45)
                            -- Toucher Obscur (marque) et Toucher Sacré (vol de vie)
                            if self.player.hasDarkTouch then target.darkMark = 3.0 end
                            if (self.player.holyTouch or 0) > 0 and self.player.hp < self.player.maxHp then
                                local heal = math.max(1, math.floor(self.player.maxHp * self.player.holyTouch))
                                self.player.hp = math.min(self.player.maxHp, self.player.hp + heal)
                            end
                            local isDead = target:takeDamage(dmgOut, proj.dirX, proj.dirY, proj.elements, proj.knockbackMult)

                            if isExecute then
                                VFX.addFCT(target.x, target.y - 16, "EXECUTE!", true)
                                VFX.shakeHeavy()
                            end

                            -- Hit-Flash 3 frames blanc pur sur le monstre touché
                            VFX.triggerHitFlash(target, 3)

                            -- Floating Combat Text
                            VFX.addFCT(target.x, target.y - 8, proj.damage, proj.isCrit or isExecute)
                            VFX.addSparks(target.x, target.y, proj.isCrit and 8 or 4, proj.isCrit and {1, 0.85, 0.2, 1} or {1, 1, 1, 1})

                            -- Foudre en chaîne (Arc électrique vers ennemis proches)
                            if proj.elements and proj.elements.lightning then
                                local shocked = 0
                                for nb = 1, dCount do
                                    if shocked >= 2 then break end
                                    local nIdx = self.dummyPool.activeList[nb]
                                    local other = self.dummyPool.items[nIdx]
                                    if other and other.alive and other.id ~= target.id then
                                        local ldx = other.x - target.x
                                        local ldy = other.y - target.y
                                        if (ldx * ldx + ldy * ldy) <= (130 * 130) then
                                            shocked = shocked + 1
                                            local lDmg = math.max(4, math.floor(proj.damage * 0.50))
                                            other:takeDamage(lDmg, ldx / 130, ldy / 130)
                                            VFX.addFCT(other.x, other.y - 10, lDmg, true)
                                            VFX.addSparks(other.x, other.y, 4, {0.45, 0.75, 1.0, 1.0})

                                            -- Synergie Tempête Magnétique : zone électrique au sol
                                            if self.player.hasSynergyMagneticStorm then
                                                VFX.addSparks(other.x, other.y, 6, {0.4, 0.8, 1.0, 1.0})
                                                VFX.addFCT(other.x, other.y - 14, "STORM", true)
                                            end
                                        end
                                    end
                                end
                            end

                            -- Screen Shake et Hit-Stop (Micro-pause 0.05s) sur coup critique
                            if proj.isCrit or isExecute then
                                VFX.shakeHeavy()
                                VFX.hitStop(0.05)
                            end

                            -- Hooks onHit des compétences
                            for _, sk in ipairs(self.acquiredSkills) do
                                if sk.hooks and sk.hooks.onHit then
                                    sk.hooks.onHit(target, proj, self.player, proj.damage, self.fctPool)
                                end
                            end

                            -- 1. Boomerang / Tornade : Traverse tous les monstres à l'aller et au retour
                            if proj.behavior == "boomerang" then
                                proj.lastHitTargetId = target.id
                                VFX.addSparks(target.x, target.y, 4, {1.0, 0.85, 0.2, 1.0})

                            -- 2. Perforation (Piercing Shot) : continue sa course à travers les cibles
                            elseif proj.canPierce and proj.pierceCount and proj.pierceCount > 0 then
                                proj.pierceCount = proj.pierceCount - 1
                                proj.damage = math.max(5, math.floor(proj.damage * 0.75))
                                proj.lastHitTargetId = target.id
                                VFX.addSparks(target.x, target.y, 4, {1, 1, 0.5, 1})

                            -- 3. Ricochet vers une cible proche
                            elseif proj.bouncesLeft > 0 then
                                proj.bouncesLeft = proj.bouncesLeft - 1
                                proj.lastHitTargetId = target.id

                                local nextTarget = nil
                                local closestSq = 200 * 200
                                for nb = 1, dCount do
                                    local nIdx = self.dummyPool.activeList[nb]
                                    local other = self.dummyPool.items[nIdx]
                                    if other and other.alive and other.id ~= target.id then
                                        local ndx = other.x - target.x
                                        local ndy = other.y - target.y
                                        local dsq = ndx * ndx + ndy * ndy
                                        if dsq < closestSq then
                                            closestSq = dsq
                                            nextTarget = other
                                        end
                                    end
                                end

                                if nextTarget then
                                    local rdx = nextTarget.x - proj.x
                                    local rdy = nextTarget.y - proj.y
                                    local rdist = math.sqrt(rdx * rdx + rdy * rdy)
                                    if rdist > 0.1 then
                                        proj.dirX = rdx / rdist
                                        proj.dirY = rdy / rdist
                                        proj.vx = proj.dirX * proj.speed
                                        proj.vy = proj.dirY * proj.speed
                                    end
                                else
                                    self.projectilePool:free(proj)
                                end
                            else
                                self.projectilePool:free(proj)
                            end

                            -- Élimination du monstre & Death Hooks (Splitter, etc.)
                            if isDead then
                                self:handleMonsterDeath(target)
                            end

                            break
                        end
                    end
                end
            end
        end
    end

    -- 7.b ARÈNE DE SURVIE : nouvelle vague toutes les 15 s (ou dès l'arène nettoyée)
    if self.gameMode == "survival" and self.phase == "combat" and not self.isGameOver then
        self.waveTimer = (self.waveTimer or 0) - dt
        local cleared = (self.dummyPool.activeCount == 0 and self.spawnWarningTimer <= 0 and #self.pendingSpawns == 0)
        if self.waveTimer <= 0 or cleared then
            self.waveCount = (self.waveCount or 1) + 1
            self.waveTimer = 15.0
            self.pendingSpawns = self.obstacleManager:placeSpawns(
                WorldManager.generateSurvivalWave(self.chapterIndex, self.waveCount, self.mapW, self.mapH))
            self.spawnWarningTimer = 0.55
            VFX.shakeLight()
            VFX.addFCT(self.player.x, self.player.y - 30, "WAVE " .. self.waveCount, true)
        end
    end

    Perf.sec("u:collisions")
    -- 8. PHASE DE CLEAR & MAGNÉTISME DU BUTIN (OU APPARITION DU DÉMON APRÈS BOSS)
    if self.gameMode ~= "survival" and self.dummyPool.activeCount == 0 and self.spawnWarningTimer <= 0 and not self.isGateOpen and not (self.specialRoomManager and self.specialRoomManager.isActive)
        and (not self.waveRunner or self.waveRunner:isDone()) then
        if self.roomType == "boss" and not self.devilEncountered then
            -- APPARITION DU DÉMON APRÈS LE GRAND BOSS !
            self.devilEncountered = true
            self.phase = "devil"
            self.specialRoomManager:setup("devil", self.player, self.roomNumber)
            self:triggerShake(0.25, 4.0)
            -- Aimantation du butin
            for i = 1, self.lootPool.activeCount do
                local lIdx = self.lootPool.activeList[i]
                local loot = self.lootPool.items[lIdx]
                loot:magnetize()
            end
        else
            self.isGateOpen = true
            self.phase = "clear"
            Audio.play("gate_open", 0, 0.7)
            self:triggerShake(0.18, 2.5)
            Banner.show("clear", "ROOM CLEARED!", "+" .. math.max(0, (self.goldEarnedRun or 0) - (self.roomGoldStart or 0)) .. " GOLD")

            -- TOUT LE BUTIN AU SOL VOLE VERS LE JOUEUR (Effet aimant ultra-satisfaisant !)
            for i = 1, self.lootPool.activeCount do
                local lIdx = self.lootPool.activeList[i]
                local loot = self.lootPool.items[lIdx]
                loot:magnetize()
            end
        end
    end

    -- 9. ENTRÉE DANS LA PORTE NORD D'ARCHERO
    if self.isGateOpen and (self.phase == "clear" or self.phase == "combat") then
        local gateCenterX = self.mapW / 2
        -- Hitbox d'entrée généreuse : contact avec le faisceau lumineux ou le vortex au nord
        if self.player.y <= 55 and math.abs(self.player.x - gateCenterX) <= 38 then
            -- Déclenchement de la transition fondue
            self.phase = "transition"
            self.fadeDirection = 1
            self:triggerShake(0.20, 3.0)
        end
    end
end

-- ============================================================================
-- RENDU TOP SCREEN (400x240) AVEC CAMÉRA 2D FLUIDE ET SPRITEBATCHING 3DS
local SORT_PROP, SORT_MONSTER, SORT_PLAYER, SORT_PET = 1, 2, 3, 4
local C_WIPE = { 0.094, 0.078, 0.145 } -- encre de la palette (transition entre salles)

local function queueSlot(q, n)
    local e = q[n]
    if not e then
        e = {}
        q[n] = e
    end
    return e
end

-- Tri en profondeur (par Y du pied) des obstacles en relief, monstres, héros et familiers.
-- File pré-allouée + tri par insertion : aucune allocation par frame.
function GameState:drawSortedWorld()
    local q = self.drawQueue
    if not q then
        q = {}
        self.drawQueue = q
    end
    local n = 0

    local props = self.obstacleManager.props
    if props then
        for i = 1, #props do
            n = n + 1
            local e = queueSlot(q, n)
            e.key, e.kind, e.ref = props[i].baseY, SORT_PROP, props[i]
        end
    end
    local pool = self.dummyPool
    for i = 1, pool.activeCount do
        local d = pool.items[pool.activeList[i]]
        if d and d.alive then
            n = n + 1
            local e = queueSlot(q, n)
            e.key, e.kind, e.ref = d.y + (d.radius or 10) * 0.8, SORT_MONSTER, d
        end
    end
    local p = self.player
    n = n + 1
    local e = queueSlot(q, n)
    e.key, e.kind, e.ref = p.y + 9, SORT_PLAYER, p
    if p.pets then
        for i = 1, #p.pets do
            n = n + 1
            local pe = queueSlot(q, n)
            pe.key, pe.kind, pe.ref = p.pets[i].y + 10, SORT_PET, p.pets[i]
        end
    end

    for i = 2, n do
        local cur = q[i]
        local j = i - 1
        while j >= 1 and q[j].key > cur.key do
            q[j + 1] = q[j]
            j = j - 1
        end
        q[j + 1] = cur
    end

    local px, py = p.x, p.y
    local timed = Perf.enabled
    local now = love.timer.getTime
    for i = 1, n do
        local it = q[i]
        local t0 = timed and now()
        if it.kind == SORT_PROP then
            self.obstacleManager:drawProp(it.ref)
            if timed then Perf.add("m:objets", now() - t0) end
        elseif it.kind == SORT_MONSTER then
            it.ref:draw(px, py)
            if timed then Perf.add("m:monstres", now() - t0) end
        elseif it.kind == SORT_PLAYER then
            it.ref:drawBody()
            if timed then Perf.add("m:heros", now() - t0) end
        else
            it.ref:draw()
            if timed then Perf.add("m:familiers", now() - t0) end
        end
        it.ref = nil
    end
end

-- ============================================================================
-- RENDU TOP SCREEN (400x240) : couches de profondeur stéréoscopique + tri en Y
-- ============================================================================
function GameState:drawTop(eye)
    Depth.begin(eye)
    local shakeX, shakeY = VFX.getShakeOffset()

    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- 0. Ciel en couches (îles lointaines, nuages)
    Perf.sec("h:debut")
    self.arena:drawSky(self.camera.x, self.camera.y)
    Perf.sec("h:ciel")

    self.camera:attach()

    -- 1. Sol cuit (herbe, falaise, eau, dalles de pièges, ombres portées)
    local pal = self.currentChapter and self.currentChapter.palette or nil
    self.arena:draw(self.isGateOpen, pal, self.pendingSpawns, self.mapW, self.mapH)
    Perf.sec("h:sol")
    self.obstacleManager:draw()
    Perf.sec("h:obstacles")

    -- 2. Entités de salles spéciales
    if self.specialRoomManager and self.specialRoomManager.isActive then
        self.specialRoomManager:drawTop(self.mapW, self.mapH)
    end

    -- 3. Ombres du butin et télégraphes de bombes (au sol)
    for i = 1, self.lootPool.activeCount do
        local l = self.lootPool.items[self.lootPool.activeList[i]]
        if l and l.alive then
            VFX.drawDynamicShadow(l.x, l.y + 3, 5.5, 2.5, l.z or 0, 0.38)
        end
    end
    for pi = 1, self.projectilePool.activeCount do
        local proj = self.projectilePool.items[self.projectilePool.activeList[pi]]
        if proj and proj.alive and proj.isLobbed then
            local progress = math.min(1.0, (proj.flightTimer or 0) / (proj.flightDuration or 1.4))
            VFX.drawBombTelegraph(proj.targetX, proj.targetY, proj.aoeRadius or 30, progress, not proj.isEnemy)
            VFX.drawDynamicShadow(proj.x, proj.y, 6.0, 3.0, proj.arcZ or 0, 0.40)
        end
    end

    -- 4. Murs, arbres et porte (en relief)
    Perf.sec("h:ombres")
    Depth.push(Depth.WALLS)
    self.arena:drawWalls(self.isGateOpen, self.mapW)
    Depth.pop()
    Perf.sec("h:murs")

    -- 5. Monde trié en profondeur : obstacles, butin, monstres, héros, familiers
    Depth.push(Depth.ACTORS)
    VFX.drawLootBatch(self.lootPool)
    self:drawSortedWorld()
    Depth.pop()
    Perf.sec("h:monde")

    -- 6. Projectiles et particules
    Depth.push(Depth.FX)
    VFX.drawProjectileBatch(self.projectilePool)
    VFX.drawParticles()
    Depth.pop()
    Perf.sec("h:tirs")

    -- 7. Jauge du héros et dégâts flottants (au premier plan)
    Depth.push(Depth.TEXT)
    self.player:drawOverlay()
    VFX.drawFCT()
    Depth.pop()
    Perf.sec("h:textes")

    self.camera:detach()

    -- 8. Atmosphère écran (vignettage, lumière)
    self.arena:drawAtmosphere()
    Perf.sec("h:atmo")

    -- 9. Barre de vie du boss, bannières, flash de mort du boss
    local boss = self.hud:findBoss(self)
    if boss then Banner.drawBossBar(boss, self.bossName) end
    Banner.draw()
    if self.flashTimer > 0 then
        love.graphics.setColor(1, 1, 1, math.min(1, self.flashTimer / 0.22) * 0.8)
        love.graphics.rectangle("fill", 0, 0, Config.TOP_WIDTH, Config.TOP_HEIGHT)
    end

    -- 10. Transition entre salles : balayage diagonal (sortie vers la droite, entrée par la gauche)
    if self.fadeAlpha > 0 then
        local W, Hh = Config.TOP_WIDTH, Config.TOP_HEIGHT
        local span = W + Hh + 40
        love.graphics.setColor(C_WIPE[1], C_WIPE[2], C_WIPE[3], 1)
        if self.fadeDirection >= 0 then
            local p = self.fadeAlpha * span
            love.graphics.polygon("fill", -Hh - 20, 0, p - 20, 0, p - Hh - 20, Hh, -Hh - 20, Hh)
        else
            local q = (1 - self.fadeAlpha) * span
            love.graphics.polygon("fill", q - 20, 0, W + Hh + 20, 0, W + Hh + 20, Hh, q - Hh - 20, Hh)
        end
    end
    if self.isGameOver then
        local deathAlpha = math.min(1.0, self.gameOverTimer / 1.0)
        love.graphics.setColor(0.65, 0.05, 0.08, deathAlpha * 0.45)
        love.graphics.rectangle("fill", 0, 0, Config.TOP_WIDTH, Config.TOP_HEIGHT)
    end

    love.graphics.pop()
end

-- ============================================================================
-- RENDU BOTTOM SCREEN (320x240)
-- ============================================================================
function GameState:drawBottom()
    -- Rendu de la Salle Spéciale (Ange, Démon, Roue, Marchand) sur l'écran tactile
    if self.specialRoomManager and self.specialRoomManager.isActive then
        self.specialRoomManager:drawBottom()
        return
    end

    self.hud:drawDashboard(self, self.pauseBtn)
    self.hud:drawLowHpOverlay(self.player)

    -- Choix de compétence en surimpression plein écran
    if self.isDrafting then
        self.hud:drawDraftModal(self.draftOptions, self.acquiredSkills, self.draftCursor)
    end

    -- Voile sombre lors du Game Over
    if self.isGameOver then
        local deathAlpha = math.min(1.0, self.gameOverTimer / 1.0)
        love.graphics.setColor(0.04, 0.04, 0.06, deathAlpha * 0.65)
        love.graphics.rectangle("fill", 0, 0, Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT)
    end
end

-- ============================================================================
-- ENTRÉES TACTILES (ÉCRAN INFÉRIEUR)
-- ============================================================================
function GameState:touchpressed(id, tx, ty)
    local pb = self.pauseBtn
    if tx >= pb.x and tx <= pb.x + pb.w and ty >= pb.y and ty <= pb.y + pb.h then
        self:triggerPause()
        return
    end

    if self.specialRoomManager and self.specialRoomManager.isActive then
        self.specialRoomManager:touchpressed(id, tx, ty)
        return
    end

    if self.isDrafting then
        local cardIdx = self.hud:checkCardTouch(tx, ty)
        if cardIdx then self:pickDraft(cardIdx) end
    else
        if self.hud:checkUltimateTouch(tx, ty) then
            self:tryUltimate()
        elseif self.hud:checkDashTouch(tx, ty) then
            self.player:triggerDash()
        else
            self.hud:checkSkillTouch(tx, ty, self.acquiredSkills)
        end
    end
end

-- Applique la compétence n° idx du tirage (toucher, bouton A ou touches 1-3)
function GameState:pickDraft(idx)
    local skill = self.draftOptions[idx]
    if not skill then return end
    if skill.hooks and skill.hooks.onApply then
        skill.hooks.onApply(self.player)
    end
    table.insert(self.acquiredSkills, skill)
    Save.addQuestProgress("skills", 1)

    -- Vérification des fusions légendaires de compétences (Synergies)
    local newSynergies = Skills.checkSynergies(self.player, self.acquiredSkills)
    if newSynergies and #newSynergies > 0 then
        for _, syn in ipairs(newSynergies) do
            VFX.addFCT(self.player.x, self.player.y - 20, "FUSION: " .. syn.name, true)
            VFX.shakeHeavy()
        end
    end

    Audio.play("ui_confirm", 0, 0.9)
    self.isDrafting = false
    self:triggerShake(0.1, 2.5)
end

-- Ultime : uniquement si la jauge est pleine
function GameState:tryUltimate()
    if self.ultimateCharge >= 1.0 then
        self:triggerUltimate()
        self.ultimateCharge = 0
    end
end

function GameState:touchreleased(id, tx, ty)
    if self.specialRoomManager and self.specialRoomManager.isActive then
        self.specialRoomManager:touchreleased(id, tx, ty, self.player, self.fctPool, function()
            if self.phase == "wheel" then
                self.phase = "combat"
                self.spawnWarningTimer = 0.55
                -- Si le talent Gloire était en attente, ouvrir le draft maintenant que la roue est résolue
                if self.pendingGloryDraft then
                    self.pendingGloryDraft = false
                    self:openDraft()
                end
            else
                self.isGateOpen = true
                self.phase = "clear"
            end
            self:triggerShake(0.18, 2.5)
        end)
        return
    end
end

function GameState:triggerPause()
    self.sm:push("pause", {
        room = self.roomNumber,
        goldEarned = self.goldEarnedRun,
        kills = self.kills,
        skills = self.acquiredSkills,
        mode = self.gameMode,
    })
end

-- ============================================================================
-- 5. ULTIMES DÉDIÉS POUR CHAQUE HÉROS ARCHERO 2
-- ============================================================================
function GameState:triggerUltimate()
    Audio.play("ultimate", 0, 1.0)
    self:triggerShake(0.35, 7.0)
    local heroId = (self.player and self.player.heroId) or self.heroId or "atreus"

    if heroId == "atreus" then
        -- 1. ATREUS : BARRAGE CÉLESTE (Pluie de 16 flèches dorées ciblées)
        VFX.addFCT(self.player.x, self.player.y - 25, "CELESTIAL BARRAGE!", true)
        local count = 16
        for i = 1, count do
            local angle = (i - 1) * ((math.pi * 2) / count)
            local dirX = math.cos(angle)
            local dirY = math.sin(angle)
            local proj = self.projectilePool:obtain()
            if proj then
                proj:spawn(self.player.x, self.player.y, dirX, dirY, {
                    type = "staff",
                    projectile_speed = 340,
                    damage = 50,
                    range = 420,
                    radius = 5.5,
                    tracking_speed = 9.0,
                    color = {1.0, 0.88, 0.25, 1.0},
                }, true, 1, false, { playerRef = self.player })
            end
        end

    elseif heroId == "urasil" then
        -- 2. URASIL : MIASME MORTEL (Nuage d'acide asphyxiant toute la salle)
        VFX.addFCT(self.player.x, self.player.y - 25, "DEADLY MIASMA!", true)
        VFX.shakeHeavy()
        VFX.addSparks(self.player.x, self.player.y, 25, {0.2, 0.95, 0.3, 1.0})
        if self.dummyPool and self.dummyPool.activeCount > 0 then
            for i = 1, self.dummyPool.activeCount do
                local dIdx = self.dummyPool.activeList[i]
                local monster = self.dummyPool.items[dIdx]
                if monster and monster.alive then
                    monster:takeDamage(45, 0, 0, { poison = true })
                    if monster.status then
                        monster.status.poison = 999.0
                    end
                    VFX.triggerHitFlash(monster, 4)
                    VFX.addFCT(monster.x, monster.y - 12, "ACID 45", true)
                end
            end
        end

    elseif heroId == "phoren" then
        -- 3. PHOREN : MÉTÉORE VOLCANIQUE (Impact cataclysmique brûlant le sol)
        VFX.addFCT(self.player.x, self.player.y - 25, "VOLCANIC METEOR!", true)
        VFX.shakeHeavy()
        local targetX = self.player.x + (self.player.aimDirX or 1) * 75
        local targetY = self.player.y + (self.player.aimDirY or 0) * 75
        VFX.addSparks(targetX, targetY, 32, {1.0, 0.35, 0.1, 1.0})
        local meteorRadSq = 95 * 95
        if self.dummyPool and self.dummyPool.activeCount > 0 then
            for i = 1, self.dummyPool.activeCount do
                local dIdx = self.dummyPool.activeList[i]
                local monster = self.dummyPool.items[dIdx]
                if monster and monster.alive then
                    local mdx = monster.x - targetX
                    local mdy = monster.y - targetY
                    local distSq = mdx * mdx + mdy * mdy
                    if distSq <= meteorRadSq then
                        local dist = math.max(1, math.sqrt(distSq))
                        monster:takeDamage(120, mdx / dist, mdy / dist, { fire = true })
                        if monster.status then
                            monster.status.fire = 5.0
                        end
                        VFX.triggerHitFlash(monster, 5)
                        VFX.addFCT(monster.x, monster.y - 14, 120, true)
                    end
                end
            end
        end

    elseif heroId == "helix" then
        -- 4. HELIX : FUREUR BERSERKER (Invulnérabilité 3s + Vitesse d'attaque x2)
        VFX.addFCT(self.player.x, self.player.y - 25, "BERSERKER FURY!", true)
        VFX.shakeHeavy()
        VFX.addSparks(self.player.x, self.player.y, 20, {1.0, 0.2, 0.1, 1.0})
        self.player.isBerserk = true
        self.player.berserkTimer = 3.0
        self.player.isInvulnerable = true
        self.player.attackSpeedMult = self.player.attackSpeedMult * 2.0

    elseif heroId == "rolla" then
        -- 5. ROLLA : ZÉRO ABSOLU (Gèle instantanément toute la salle pendant 3 secondes)
        VFX.addFCT(self.player.x, self.player.y - 25, "ABSOLUTE ZERO!", true)
        VFX.shakeHeavy()
        VFX.addSparks(self.player.x, self.player.y, 25, {0.35, 0.85, 1.0, 1.0})
        if self.dummyPool and self.dummyPool.activeCount > 0 then
            for i = 1, self.dummyPool.activeCount do
                local dIdx = self.dummyPool.activeList[i]
                local monster = self.dummyPool.items[dIdx]
                if monster and monster.alive then
                    monster:takeDamage(40, 0, 0, { ice = true })
                    if monster.status then
                        monster.status.freeze = 3.0
                    end
                    monster.vx = 0
                    monster.vy = 0
                    monster.dashVx = 0
                    monster.dashVy = 0
                    VFX.triggerHitFlash(monster, 4)
                    VFX.addFCT(monster.x, monster.y - 12, "FREEZE 3.0s", true)
                end
            end
        end
    end
end

-- Boutons de la console : Circle Pad / croix = déplacement (tir automatique à l'arrêt),
-- R ou B = esquive, L ou Y = ultime, Start = pause ; tirage de compétence : croix + A.
function GameState:gamepadpressed(joystick, button)
    if button == "start" then
        self:triggerPause()
        return
    end

    if self.specialRoomManager and self.specialRoomManager.isActive then
        local key = ({ a = "a", b = "b", x = "x", y = "b" })[button]
        if key then self:keypressed(key) end
        return
    end

    if self.isDrafting then
        local n = math.max(1, #self.draftOptions)
        self.draftCursor = self.draftCursor or 2
        if button == "dpleft" then
            self.draftCursor = (self.draftCursor - 2) % n + 1
            Audio.play("ui_click", 0, 0.6)
        elseif button == "dpright" then
            self.draftCursor = self.draftCursor % n + 1
            Audio.play("ui_click", 0, 0.6)
        elseif button == "a" then
            self:pickDraft(self.draftCursor)
        end
        return
    end

    if button == "b" or button == "rightshoulder" then
        self.player:triggerDash()
    elseif button == "y" or button == "x" or button == "leftshoulder" then
        self:tryUltimate()
    end
end

function GameState:keypressed(key)
    if key == "return" or key == "start" or key == "p" or key == "escape" then
        if not (self.specialRoomManager and self.specialRoomManager.isActive and (key == "return" or key == "space")) then
            self:triggerPause()
            return
        end
    end

    if self.specialRoomManager and self.specialRoomManager.isActive then
        local onDone = function()
            if self.phase == "wheel" then
                self.phase = "combat"
                self.spawnWarningTimer = 0.55
                if self.pendingGloryDraft then
                    self.pendingGloryDraft = false
                    self:openDraft()
                end
            else
                self.isGateOpen = true
                self.phase = "clear"
            end
            self:triggerShake(0.18, 2.5)
        end

        if key == "1" or key == "a" or key == "space" or key == "return" then
            if self.specialRoomManager.activeType == "angel" then
                self.specialRoomManager.pressedBtn = "angel_1"
            elseif self.specialRoomManager.activeType == "devil" then
                self.specialRoomManager.pressedBtn = "devil_accept"
            elseif self.specialRoomManager.activeType == "wheel" then
                if not self.specialRoomManager.isSpinning and not self.specialRoomManager.wheelStopped then
                    self.specialRoomManager.pressedBtn = "wheel_spin"
                elseif self.specialRoomManager.wheelStopped then
                    self.specialRoomManager.pressedBtn = "wheel_claim"
                end
            elseif self.specialRoomManager.activeType == "merchant" then
                self.specialRoomManager.pressedBtn = "merchant_1"
            end
            self.specialRoomManager:touchreleased(1, 0, 0, self.player, self.fctPool, onDone)
            return
        elseif key == "2" or key == "b" then
            if self.specialRoomManager.activeType == "angel" then
                self.specialRoomManager.pressedBtn = "angel_2"
            elseif self.specialRoomManager.activeType == "devil" then
                self.specialRoomManager.pressedBtn = "devil_refuse"
            elseif self.specialRoomManager.activeType == "merchant" then
                self.specialRoomManager.pressedBtn = "merchant_2"
            end
            self.specialRoomManager:touchreleased(1, 0, 0, self.player, self.fctPool, onDone)
            return
        elseif (key == "3" or key == "x") and self.specialRoomManager.activeType == "merchant" then
            self.specialRoomManager.pressedBtn = "merchant_3"
            self.specialRoomManager:touchreleased(1, 0, 0, self.player, self.fctPool, onDone)
            return
        elseif (key == "space" or key == "escape" or key == "b") and self.specialRoomManager.activeType == "merchant" then
            self.specialRoomManager.pressedBtn = "merchant_exit"
            self.specialRoomManager:touchreleased(1, 0, 0, self.player, self.fctPool, onDone)
            return
        end
    end

    if self.isDrafting then
        local idx = nil
        if key == "1" or key == "a" then idx = 1
        elseif key == "2" or key == "b" then idx = 2
        elseif key == "3" or key == "x" then idx = 3
        elseif key == "left" then
            self.draftCursor = ((self.draftCursor or 2) - 2) % 3 + 1
        elseif key == "right" then
            self.draftCursor = (self.draftCursor or 2) % 3 + 1
        elseif key == "return" or key == "space" or key == "k" then
            idx = self.draftCursor or 2
        end
        if idx then self:pickDraft(idx) end
        return
    end

    -- Clavier PC : esquive (Maj, J, B) et ultime (Espace, K, U)
    if key == "lshift" or key == "rshift" or key == "j" or key == "b" then
        self.player:triggerDash()
        return
    elseif key == "space" or key == "k" or key == "u" then
        self:tryUltimate()
        return
    end

    -- F1 : mode développeur (PC uniquement) ; les raccourcis de triche n'existent qu'en mode dev
    if key == "f1" then
        Config.DEBUG_MODE = not Config.DEBUG_MODE
        return
    end
    if not Config.DEBUG_MODE then return end
    if key == "f2" then
        local types = { "slime", "bat", "skeleton", "plant", "golem" }
        local d = self.dummyPool:obtain()
        if d then d:spawn(math.random(80, self.mapW - 80), math.random(80, self.mapH - 80), 60, types[math.random(1, #types)]) end
    elseif key == "f4" then
        self.dummyPool:clear()
    elseif key == "f5" then
        if self.player:addXp(40) then self:openDraft() end
    elseif key == "f6" then
        self.ultimateCharge = 1.0
    elseif key == "f7" then
        local weapons = { "starter_bow", "death_scythe", "stalker_staff", "tornado_boomerang", "brightspear" }
        self.weaponCycle = (self.weaponCycle or 0) % #weapons + 1
        self.player:equipWeapon(weapons[self.weaponCycle])
    end
end

return GameState
