-- src/ui/menu_top.lua
-- Hub top screen (400x240): the selected world's sky and floating island, the page's star
-- element on the island's stone dais (hero, item, chest or talent seal), two small cards
-- and a strip with the page title and the 3DS buttons to use.
--
-- Draw order keeps the auto-batcher happy on Old 3DS: flat primitives first (sky bands,
-- far shapes, card backgrounds, discs), then atlas sprites and texts.

local Config = require("src.data.config")
local Save = require("src.data.save")
local Heroes = require("src.data.heroes")
local Items = require("src.data.items")
local Talents = require("src.data.talents")
local Balance = require("src.data.balance")
local Quests = require("src.data.quests")
local WorldManager = require("src.core.world_manager")
local Art = require("src.render.art")
local Palette = require("src.render.palette")
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local UI = require("src.ui.ui_components")
local HeroSprites = require("src.render.sprites.heroes")
local MenuArt = require("src.render.sprites.menu_art")
local Pet = require("src.entities.pet")

local MenuTop = {}

local C = Palette.C
local floor = math.floor
local W, H = Config.TOP_WIDTH, Config.TOP_HEIGHT

local SKY_BANDS = 12
local ISLAND_SCALE = 2
local FEET_Y = 116                 -- y of the dais top, where the star element stands
local HEADER_H = 22
local STRIP_Y = 206                -- title + button hints strip
local CARD_Y, CARD_W = 28, 104
local LEFT_X, RIGHT_X = 6, W - 6 - CARD_W
local CARD_ALPHA = 0.62
local DROP_RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

-- Per world: far scenery, airborne layer and particle colour (WorldManager.CHAPTERS order)
local WORLD_LOOK = {
    { far = "islands", air = "clouds" },
    { far = "dunes", air = "clouds" },
    { far = "stalactites", air = "sparks", spark = C.cyan },
    { far = "volcano", air = "sparks", spark = C.amber },
    { far = "islands", air = "clouds" },
    { far = "towers", air = "sparks", spark = C.pink },
}

local skyCache = {}
local function skyColors(world)
    local c = skyCache[world]
    if c then return c end
    local theme = WorldManager.THEMES[world] or WorldManager.THEMES[1]
    local top, bottom = Palette.hex(theme.skyTop), Palette.hex(theme.skyBottom)
    c = {}
    for i = 0, SKY_BANDS - 1 do
        local f = i / (SKY_BANDS - 1)
        c[i + 1] = { top[1] + (bottom[1] - top[1]) * f, top[2] + (bottom[2] - top[2]) * f, top[3] + (bottom[3] - top[3]) * f }
    end
    skyCache[world] = c
    return c
end

-- ----------------------------------------------------------------------------
-- BACKDROP
-- ----------------------------------------------------------------------------
local function drawSky(world)
    local bands = skyColors(world)
    local bh = H / SKY_BANDS
    for i = 1, SKY_BANDS do
        local c = bands[i]
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", 0, floor((i - 1) * bh), W, floor(bh) + 1)
    end
end

local function drawFarShapes(look)
    if look.far == "dunes" then
        love.graphics.setColor(0.89, 0.77, 0.55, 0.55)
        love.graphics.ellipse("fill", 60, 196, 110, 46)
        love.graphics.ellipse("fill", 336, 206, 130, 52)
        love.graphics.ellipse("fill", 200, 236, 170, 40)
    elseif look.far == "stalactites" then
        love.graphics.setColor(0.05, 0.07, 0.14, 1)
        for i = 0, 9 do
            local x = 10 + i * 42
            local h = 22 + (i * 17) % 28
            love.graphics.polygon("fill", x, 0, x + 18, 0, x + 9, h)
        end
    elseif look.far == "volcano" then
        love.graphics.setColor(0.23, 0.09, 0.07, 1)
        love.graphics.polygon("fill", 216, 240, 330, 70, 444, 240)
        Skin.rect(C.orange, 322, 70, 16, 3)
    elseif look.far == "towers" then
        love.graphics.setColor(0.10, 0.07, 0.16, 1)
        love.graphics.rectangle("fill", 20, 120, 22, 120)
        love.graphics.rectangle("fill", 52, 150, 22, 90)
        love.graphics.rectangle("fill", 300, 100, 22, 140)
        love.graphics.rectangle("fill", 340, 140, 22, 100)
        love.graphics.rectangle("fill", 372, 110, 22, 130)
    end
end

-- Sprites of the far layer and the airborne layer (clouds drift, sparks rise)
local function drawFarSprites(look, t, particles)
    if look.far == "islands" then
        Art.draw("far_island_b", 1, 60, 96)
        Art.draw("far_island_a", 1, 348, 120)
    elseif look.far == "stalactites" then
        Art.draw("crystal_spire", 1, 40, 110)
        Art.draw("crystal_spire", 1, 360, 130)
    elseif look.far == "towers" then
        for _, x in ipairs({ 25, 57, 305, 345, 377 }) do
            for y = 130, 230, 14 do
                Skin.rect(C.magenta, x, y, 3, 4)
            end
        end
    end
    if look.air == "clouds" then
        Art.draw("cloud_c", 1, floor((96 + t * 5) % (W + 140)) - 70, 118)
        Art.draw("cloud_a", 1, floor((316 - t * 4) % (W + 140)) - 70, 108)
        Art.draw("cloud_b", 1, floor((200 + t * 3) % (W + 140)) - 70, 36)
    elseif particles then
        for i = 1, #particles do
            local p = particles[i]
            Skin.rect(look.spark, floor(p.x), floor(p.y), 2, 2)
        end
    end
end

local function islandOrigin()
    local s = ISLAND_SCALE
    return W / 2 - MenuArt.DAIS_X * s, FEET_Y - MenuArt.DAIS_Y * s
end

local function drawIsland(world)
    local name = MenuArt.ISLANDS[world] or MenuArt.ISLANDS[1]
    local left, top = islandOrigin()
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx(name, 1, left, top, 0, ISLAND_SCALE, ISLAND_SCALE)
    local theme = WorldManager.THEMES[world] or WorldManager.THEMES[1]
    Art.draw(theme.wallTree or "tall_tree_a", 1, left + 54, top + 20)
    Art.draw(theme.wallTreeSmall or "tall_tree_b", 1, left + 188, top + 22)
end

-- ----------------------------------------------------------------------------
-- STAR ELEMENTS ON THE DAIS
-- ----------------------------------------------------------------------------
local function drawHero(heroId, t, equipped)
    local bob = floor(math.sin(t * 2.2) * 2)
    local bottom = FEET_Y - 1 + bob
    local x = W / 2
    local variant = (heroId ~= "atreus") and heroId or nil
    Palette.set(C.ink, 0.30)
    love.graphics.ellipse("fill", x, FEET_Y + 2, 22 - bob, 5)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_legs", 1, x, bottom, 0, 3, 3)
    Art.drawEx("hero_body", 1, x, bottom - 9, 0, 3, 3, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[heroId]
    if acc then
        local o = HeroSprites.ACCESSORY_OFFSETS[acc]
        Art.drawEx("hero_acc_" .. acc, 1, x + o[1] * 3, bottom - 9 + o[2] * 3, 0, 3, 3)
    end
    Art.drawEx("bow", 1, x + 26, bottom - 34, 0.35, 2, 2)
    if equipped then
        local float = floor(math.sin(t * 4.6) * 3)
        if equipped.pet1 then Pet.drawSprite(equipped.pet1, x - 58, bottom - 44 + float, t, false, 2) end
        if equipped.pet2 then Pet.drawSprite(equipped.pet2, x + 58, bottom - 44 - float, t, true, 2) end
    end
end

local function drawGlow(color, y, r, alpha)
    Skin.disc(color, W / 2, y, r, alpha)
    Skin.disc(color, W / 2, y, floor(r * 0.65), alpha)
end

local function drawFloatingItem(item, rarity, t)
    local rData = Items.getRarityData(rarity)
    local y = FEET_Y - 34 + floor(math.sin(t * 2.5) * 2)
    love.graphics.setColor(rData.color[1], rData.color[2], rData.color[3], 0.22)
    love.graphics.circle("fill", W / 2, y, 30)
    UI.drawItemIcon(item.icon, W / 2, y, 30)
end

local function drawChest(chestType, t)
    local name = (chestType == "obsidian") and "menu_chest_obsidian" or "menu_chest_gold"
    local frame = Art.frame(name, 1)
    local glow = (chestType == "obsidian") and C.magenta or C.amber
    drawGlow(glow, FEET_Y - 30, 40, 0.16)
    love.graphics.setColor(1, 1, 1, 1)
    local bob = floor(math.sin(t * 2.5) * 1.5)
    Art.drawEx(name, 1, W / 2 - frame.w, FEET_Y - frame.h * 2 - 2 + bob, 0, 2, 2)
end

local TALENT_ICONS = { strength = "icon_sword", vitality = "icon_heart", agility = "icon_skill_boots", recovery = "icon_skill_heal" }

local SEAL_ICONS = {
    { dx = 0, dy = -36, theme = "red", icon = "icon_sword" },
    { dx = 36, dy = 0, theme = "green", icon = "icon_heart" },
    { dx = 0, dy = 34, theme = "blue", icon = "icon_skill_boots" },
    { dx = -36, dy = 0, theme = "gold", icon = "icon_skill_heal" },
}

local function drawSeal(totalLevel)
    local cx, cy = W / 2, FEET_Y - 50
    Skin.disc(C.magenta, cx, cy, 44, 0.18)
    Skin.disc(C.ink, cx, cy, 25)
    Skin.disc(C.plum, cx, cy, 24)
    Skin.disc(C.magenta, cx, cy - 1, 20)
    Skin.disc(C.plum, cx, cy, 17)
    for _, s in ipairs(SEAL_ICONS) do
        local th = Skin.theme(s.theme)
        Skin.disc(C.ink, cx + s.dx, cy + s.dy, 12)
        Skin.disc(th.dark, cx + s.dx, cy + s.dy, 11)
        Skin.disc(th.main, cx + s.dx, cy + s.dy - 1, 9)
    end
    love.graphics.setColor(1, 1, 1, 1)
    for _, s in ipairs(SEAL_ICONS) do
        Art.draw(s.icon, 1, cx + s.dx, cy + s.dy - 1)
    end
    PixelFont.printf(tostring(totalLevel), cx - 30, cy - 15, 60, "center", C.white, "main", 2)
    PixelFont.printf("LV", cx - 30, cy + 4, 60, "center", C.pink, "main")
end

-- ----------------------------------------------------------------------------
-- HEADER, CARDS AND HINT STRIP
-- ----------------------------------------------------------------------------
local function drawHeaderBack()
    Skin.rect(C.ink, 0, 0, W, HEADER_H, 0.8)
end

local function drawHeaderFront(save)
    Skin.pill(4, 3, 50, 16, "gold")
    PixelFont.printf("LV " .. (save.accountLevel or 1), 4, 5, 50, "center", C.white, "main")
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, 68, 11)
    PixelFont.print(tostring(save.gold or 0), 78, 5, C.yellow, "main")
    Art.draw("icon_gem", 1, 146, 11)
    PixelFont.print(tostring(save.gems or 0), 156, 5, C.mint, "main")
    Art.draw("icon_bolt", 1, 212, 11)
    local energy, maxEnergy = save.energy or 0, math.max(1, save.maxEnergy or 1)
    Skin.roundRect(C.ink, 222, 5, 50, 12, 2)
    Skin.rect(C.night, 223, 6, 48, 10)
    local fw = floor(48 * math.min(1, energy / maxEnergy))
    if fw > 0 then
        Skin.rect(C.blue, 223, 6, fw, 10)
        Skin.rect(C.cyan, 223, 6, fw, 1)
    end
    PixelFont.print(energy .. "/" .. maxEnergy, 276, 5, C.cyan, "main")
    Skin.disc(C.slate, 386, 11, 8)
    PixelFont.printf("Y", 378, 5, 16, "center", C.white, "main")
end

local function cardBack(x, h)
    Skin.roundRect(C.ink, x, CARD_Y, CARD_W, h, 3, CARD_ALPHA)
end

local function cardTitle(x, text, color)
    PixelFont.printf(text, x, CARD_Y + 4, CARD_W, "center", color or C.fog, "main")
end

-- 3DS button glyph followed by its action; returns the next x
local function hint(x, y, btn, label, color)
    local bw
    if #btn == 1 and btn ~= "L" and btn ~= "R" then
        bw = 17
        Skin.disc(C.ink, x + 8, y + 6, 9)
        Skin.disc(C.slate, x + 8, y + 6, 8)
        PixelFont.printf(btn, x + 1, y + 1, 15, "center", C.white, "main")
    else
        bw = PixelFont.getWidth(btn, "main") + 10
        Skin.pill(x, y - 1, bw, 16, "dark")
        PixelFont.printf(btn, x, y + 1, bw, "center", C.white, "main")
    end
    if not label or label == "" then return x + bw + 4 end
    return x + bw + 4 + PixelFont.print(label, x + bw + 4, y + 1, color or C.white, "main") + 14
end

local function hintsWidth(hints)
    local total = 0
    for _, h in ipairs(hints) do
        local bw = (#h[1] == 1 and h[1] ~= "L" and h[1] ~= "R") and 17 or (PixelFont.getWidth(h[1], "main") + 10)
        total = total + bw + 4
        if h[2] and h[2] ~= "" then total = total + PixelFont.getWidth(h[2], "main") + 14 end
    end
    return total - 14
end

local function drawStrip(title, titleColor, hints)
    PixelFont.printf(title, 0, STRIP_Y + 4, W, "center", titleColor or C.yellow, "main", 1, nil, 1)
    local x = floor((W - hintsWidth(hints)) / 2)
    for _, h in ipairs(hints) do
        x = hint(x, STRIP_Y + 18, h[1], h[2], h[3])
    end
end

local TABS_HINT = { "L", "" }
local TABS_HINT_R = { "R", "TABS" }

-- ----------------------------------------------------------------------------
-- PAGES
-- ----------------------------------------------------------------------------
-- Each page returns: star element kind, left card height, right card height, a function
-- drawing the card texts, the strip title, its colour and the button hints.
local PAGES = {}

function PAGES.play(menu, save, t)
    local heroId = save.selectedHero or "atreus"
    local atk, hp = menu:powerTotals(heroId, Heroes.get(heroId), t)
    local records = save.records or {}
    local best = records.ascensionMax or 1
    local chap = menu.chapters[save.selectedChapter or 1] or menu.chapters[1]
    return {
        star = "hero", leftH = 52, rightH = 52,
        cards = function()
            cardTitle(LEFT_X, "POWER")
            PixelFont.print("ATK", LEFT_X + 8, CARD_Y + 20, C.pink, "main")
            PixelFont.printf(tostring(atk), LEFT_X, CARD_Y + 20, CARD_W - 8, "right", C.white, "main")
            PixelFont.print("HP", LEFT_X + 8, CARD_Y + 35, C.mint, "main")
            PixelFont.printf(tostring(hp), LEFT_X, CARD_Y + 35, CARD_W - 8, "right", C.white, "main")
            cardTitle(RIGHT_X, "BEST")
            PixelFont.printf(best .. "/" .. WorldManager.ASCENSION_FLOORS, RIGHT_X, CARD_Y + 20, CARD_W, "center", C.white, "main", 2)
        end,
        title = string.format("WORLD %d - %s", chap.id, chap.name:upper()),
        hints = { TABS_HINT, TABS_HINT_R, { "START", "PLAY", C.mint } },
    }
end

function PAGES.quests(menu, save, t)
    local q = Save.getDailyQuests()
    local list = Save.getDailyQuestList()
    local done = 0
    for _, quest in ipairs(list) do
        local _, isDone = Quests.state(quest, q)
        if isDone then done = done + 1 end
    end
    local now = os.date("*t")
    local left = (23 - now.hour) * 3600 + (59 - now.min) * 60 + (60 - now.sec)
    return {
        star = "hero", leftH = 52, rightH = 52,
        cards = function()
            cardTitle(LEFT_X, "RESET IN")
            PixelFont.printf(string.format("%02d:%02d", floor(left / 3600), floor(left / 60) % 60), LEFT_X, CARD_Y + 20,
                CARD_W, "center", C.white, "main", 2)
            cardTitle(RIGHT_X, "TODAY")
            PixelFont.printf(done .. "/" .. #list, RIGHT_X, CARD_Y + 20, CARD_W, "center", C.mint, "main", 2)
        end,
        title = string.format("DAILY POINTS %d/%d", q.points or 0, Quests.MAX_POINTS),
        hints = { TABS_HINT, TABS_HINT_R, { "A", "CLAIM", C.mint } },
    }
end

function PAGES.heroes(menu, save, t)
    local heroId = menu.selectedHeroPreview or save.selectedHero or "atreus"
    local h = Heroes.get(heroId)
    local atk, hp = menu:powerTotals(heroId, h, t)
    local unlocked = save.unlockedHeroes and save.unlockedHeroes[heroId]
    local ult = h.ultimate or {}
    return {
        star = "hero", heroId = heroId, leftH = 70, rightH = 84,
        cards = function()
            cardTitle(LEFT_X, "STATS")
            PixelFont.print("ATK", LEFT_X + 8, CARD_Y + 22, C.pink, "main")
            PixelFont.printf(tostring(atk), LEFT_X, CARD_Y + 22, CARD_W - 8, "right", C.white, "main")
            PixelFont.print("HP", LEFT_X + 8, CARD_Y + 38, C.mint, "main")
            PixelFont.printf(tostring(hp), LEFT_X, CARD_Y + 38, CARD_W - 8, "right", C.white, "main")
            PixelFont.printf(unlocked and "UNLOCKED" or (h.cost .. " " .. (h.costType or ""):upper()), LEFT_X, CARD_Y + 54,
                CARD_W, "center", unlocked and C.fog or C.yellow, "main")
            cardTitle(RIGHT_X, "ULTIMATE", C.amber)
            PixelFont.printf(ult.name or "", RIGHT_X + 4, CARD_Y + 19, CARD_W - 8, "center", C.white, "main", 1, nil, 2, 11)
            PixelFont.printf(ult.desc or "", RIGHT_X + 4, CARD_Y + 45, CARD_W - 8, "center", C.silver, "main", 1, nil, 3, 11)
        end,
        title = string.format("%s - %s", h.name, h.title),
        hints = { TABS_HINT, TABS_HINT_R, { "A", unlocked and "SELECT" or "UNLOCK", C.mint } },
    }
end

function PAGES.equipment(menu, save, t)
    local inv = menu.inventory
    local itemId = inv.modalItemId
    if not itemId then
        local heroId = save.selectedHero or "atreus"
        local atk, hp = menu:powerTotals(heroId, Heroes.get(heroId), t)
        return {
            star = "hero", leftH = 52, rightH = 52,
            cards = function()
                cardTitle(LEFT_X, "ATTACK")
                PixelFont.printf(tostring(atk), LEFT_X, CARD_Y + 20, CARD_W, "center", C.pink, "main", 2)
                cardTitle(RIGHT_X, "HEALTH")
                PixelFont.printf(tostring(hp), RIGHT_X, CARD_Y + 20, CARD_W, "center", C.mint, "main", 2)
            end,
            title = "TAP AN ITEM TO SEE IT HERE",
            titleColor = C.silver,
            hints = { TABS_HINT, TABS_HINT_R },
        }
    end
    local item = inv.modalItem
    local rarity = Save.getItemRarity(itemId)
    local rData = Items.getRarityData(rarity)
    local level = save.itemLevels[itemId] or 1
    local stats = Save.getItemStats(itemId)
    local cost = Save.getUpgradeCost(itemId)
    return {
        star = "item", item = item, rarity = rarity, leftH = 70, rightH = 70,
        cards = function()
            PixelFont.printf(rData.name:upper(), LEFT_X, CARD_Y + 4, CARD_W, "center", rData.color, "main")
            PixelFont.printf(item.name, LEFT_X + 4, CARD_Y + 20, CARD_W - 8, "center", C.yellow, "main", 1, nil, 2, 12)
            PixelFont.printf("LV " .. level, LEFT_X, CARD_Y + 48, CARD_W, "center", C.white, "main")
            cardTitle(RIGHT_X, "STATS")
            PixelFont.print("ATK", RIGHT_X + 8, CARD_Y + 22, C.pink, "main")
            PixelFont.printf("+" .. stats.atk, RIGHT_X, CARD_Y + 22, CARD_W - 8, "right", C.white, "main")
            PixelFont.print("HP", RIGHT_X + 8, CARD_Y + 38, C.mint, "main")
            PixelFont.printf("+" .. stats.hp, RIGHT_X, CARD_Y + 38, CARD_W - 8, "right", C.white, "main")
            PixelFont.printf(cost .. " G", RIGHT_X, CARD_Y + 54, CARD_W, "center", C.yellow, "main")
        end,
        title = item.name,
        hints = { { "A", "EQUIP", C.mint }, { "X", "UPGRADE" }, { "Y", "FUSE" }, { "B", "CLOSE" } },
    }
end

function PAGES.talents(menu, save, t)
    local levels = Save.getTalents()
    local cost, totalLevel = Save.getTalentCost()
    local sel = Talents.get(menu.selectedTalent)
    return {
        star = "seal", totalLevel = totalLevel, leftH = 84, rightH = 84,
        cards = function()
            cardTitle(LEFT_X, "BONUSES")
            for i, talent in ipairs(Talents.LIST) do
                local x = LEFT_X + 4 + ((i - 1) % 2) * 50
                local y = CARD_Y + 20 + floor((i - 1) / 2) * 30
                local value = Talents.totalText(talent, levels[talent.id] or 0):match("^(%S+)")
                Art.draw(TALENT_ICONS[talent.id] or "icon_star", 1, x + 23, y + 4)
                PixelFont.printf(value, x, y + 12, 46, "center", talent.color, "main")
            end
            cardTitle(RIGHT_X, "NEXT")
            if sel then
                PixelFont.printf(sel.name, RIGHT_X, CARD_Y + 20, CARD_W, "center", C.white, "main")
                local lvl = levels[sel.id] or 0
                if Talents.isMaxed(sel.id, levels) then
                    PixelFont.printf("MAX", RIGHT_X, CARD_Y + 36, CARD_W, "center", C.mint, "main")
                else
                    PixelFont.printf(string.format("LV %d > %d", lvl, lvl + 1), RIGHT_X, CARD_Y + 36, CARD_W, "center", C.silver, "main")
                    PixelFont.printf(tostring(cost), RIGHT_X + 14, CARD_Y + 54, CARD_W - 14, "center", C.yellow, "main", 2)
                end
            end
        end,
        title = "TOTAL LEVEL " .. totalLevel,
        hints = { TABS_HINT, TABS_HINT_R, { "A", "UPGRADE", C.mint } },
    }
end

function PAGES.chests(menu, save, t)
    local chestType = menu.openingChest or menu.selectedChest or "gold"
    local isGold = chestType ~= "obsidian"
    local price = isGold and Balance.COSTS.goldChest or Balance.COSTS.obsidianChest
    return {
        star = "chest", chestType = chestType, leftH = 84, rightH = 70,
        cards = function()
            cardTitle(LEFT_X, "DROPS")
            for i, r in ipairs(DROP_RARITIES) do
                local rData = Items.getRarityData(r)
                local pct = Items.dropChance(chestType, r) * 100
                local y = CARD_Y + 18 + (i - 1) * 12
                PixelFont.print(rData.name:upper(), LEFT_X + 6, y, rData.color, "main")
                PixelFont.printf(pct >= 1 and string.format("%d%%", floor(pct + 0.5)) or string.format("%.1f%%", pct),
                    LEFT_X, y, CARD_W - 6, "right", C.white, "main")
            end
            cardTitle(RIGHT_X, "PRICE")
            PixelFont.printf(tostring(price), RIGHT_X + 14, CARD_Y + 22, CARD_W - 14, "center", isGold and C.yellow or C.mint, "main", 2)
            PixelFont.printf("YOU HAVE", RIGHT_X, CARD_Y + 42, CARD_W, "center", C.fog, "main")
            PixelFont.printf(tostring(isGold and save.gold or save.gems), RIGHT_X, CARD_Y + 54, CARD_W, "center",
                isGold and C.yellow or C.mint, "main")
        end,
        title = isGold and "GOLDEN CHEST" or "OBSIDIAN CHEST",
        hints = { TABS_HINT, TABS_HINT_R, { "A", "OPEN", C.mint } },
        priceIcon = isGold and "icon_coin" or "icon_gem",
    }
end

function PAGES.settings(menu, save, t)
    return {
        star = "logo", leftH = 0, rightH = 0,
        title = "VERSION " .. Config.VERSION,
        titleColor = C.silver,
        hints = { TABS_HINT, TABS_HINT_R, { "B", "BACK" } },
    }
end

-- ----------------------------------------------------------------------------
-- ENTRY POINT
-- ----------------------------------------------------------------------------
function MenuTop.draw(menu, t)
    local save = menu.saveData
    local world = save.selectedChapter or 1
    local look = WORLD_LOOK[world] or WORLD_LOOK[1]
    local pageFn = PAGES[menu.currentTab] or PAGES.play
    local page = pageFn(menu, save, t)
    if menu.openingChest then page = PAGES.chests(menu, save, t) end

    -- 1. Primitives: sky, far shapes, dimming, header and card backgrounds, glows
    drawSky(world)
    drawFarShapes(look)
    love.graphics.setColor(1, 1, 1, 1)
    drawFarSprites(look, t, menu.bgParticles)
    if page.star ~= "logo" then drawIsland(world) end

    if page.star == "logo" then
        Skin.rect(C.ink, 0, HEADER_H, W, STRIP_Y - HEADER_H, 0.45)
    end
    drawHeaderBack()
    if page.leftH > 0 then cardBack(LEFT_X, page.leftH) end
    if page.rightH > 0 then cardBack(RIGHT_X, page.rightH) end
    Skin.rect(C.ink, 0, STRIP_Y, W, H - STRIP_Y, 0.75)

    -- 2. Star element on the dais
    if page.star == "hero" then
        drawHero(page.heroId or save.selectedHero or "atreus", t, save.equipped)
    elseif page.star == "item" then
        drawFloatingItem(page.item, page.rarity, t)
    elseif page.star == "chest" then
        drawChest(page.chestType, t)
    elseif page.star == "seal" then
        drawSeal(page.totalLevel)
    elseif page.star == "logo" then
        PixelFont.printf("ARCH3RO", 0, 62, W, "center", C.yellow, "main", 4)
        PixelFont.printf("3DS", 0, 106, W, "center", C.cyan, "main", 3)
    end

    -- 3. Sprites and texts
    love.graphics.setColor(1, 1, 1, 1)
    drawHeaderFront(save)
    if page.cards then page.cards() end
    if page.priceIcon then Art.draw(page.priceIcon, 1, RIGHT_X + 20, CARD_Y + 29) end
    drawStrip(page.title, page.titleColor, page.hints)
end

return MenuTop
