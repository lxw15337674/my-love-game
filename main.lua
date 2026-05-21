-- main.lua
-- Heartcore Survivor prototype
-- LOVE 11.x arena roguelite inspired by short-wave survivor games and loot-driven builds.

local Game = {
    w = 1280,
    h = 720,
    state = "menu", -- menu, playing, shop, gameover, victory
    time = 0,
    wave = 1,
    waveTime = 30,
    maxWave = 10,
    coins = 0,
    xp = 0,
    level = 1,
    xpNeed = 24,
    kills = 0,
    shopRefresh = 0,
    shop = {},
    locked = {},
    enemies = {},
    bullets = {},
    pickups = {},
    particles = {},
    damageTexts = {},
    stars = {},
    message = "",
    messageTimer = 0,
    shake = 0,
    autoShotDone = false,
    player = {
        x = 640,
        y = 360,
        r = 17,
        hp = 70,
        maxHp = 70,
        shield = 35,
        maxShield = 35,
        shieldDelay = 0,
        shieldRegen = 7,
        speed = 250,
        pickup = 82,
        invuln = 0,
        stats = {
            damage = 1.00,
            fireRate = 1.00,
            crit = 0.06,
            critDamage = 1.65,
            range = 1.00,
            projectileSpeed = 1.00,
            pierce = 0,
            bounce = 0,
            luck = 0
        },
        weapons = {},
        gear = {}
    },
    fonts = {},
    images = {}
}

local TAU = math.pi * 2
local rnd = love.math.random

local C = {
    bgA = {0.025, 0.028, 0.065},
    bgB = {0.090, 0.045, 0.125},
    panel = {0.035, 0.040, 0.085, 0.84},
    line = {0.70, 0.76, 1.00, 0.16},
    white = {0.94, 0.96, 1.00},
    muted = {0.58, 0.64, 0.78},
    pink = {1.00, 0.25, 0.50},
    cyan = {0.25, 0.82, 1.00},
    gold = {1.00, 0.73, 0.25},
    red = {1.00, 0.18, 0.25},
    green = {0.30, 0.92, 0.55},
    purple = {0.62, 0.35, 1.00},
    orange = {1.00, 0.45, 0.18},
    ice = {0.60, 0.90, 1.00}
}

local elements = {
    kinetic = {name = "Kinetic", color = C.white, desc = "Direct damage"},
    burn = {name = "Burn", color = C.orange, desc = "Damage over time"},
    arc = {name = "Arc", color = C.cyan, desc = "Chain lightning"},
    corrode = {name = "Corrode", color = C.green, desc = "Armor shred"},
    ice = {name = "Frost", color = C.ice, desc = "Slow and freeze"},
    void = {name = "Void", color = C.purple, desc = "Pull and anomaly"}
}

local brands = {
    starforge = {name = "Starforge", color = C.gold, tag = "Crit precision"},
    swarm = {name = "Swarm", color = C.green, tag = "Multi-shot clear"},
    molten = {name = "Molten", color = C.orange, tag = "Explosive burn"},
    echo = {name = "Echo", color = C.cyan, tag = "Bounce chain"},
    blackbox = {name = "Blackbox", color = C.purple, tag = "Anomaly cost"}
}

local weaponDefs = {
    needle = {
        id = "needle", projectileSprite = "projectile_star_needle",
        name = "Star Needle", brand = "starforge", element = "kinetic", price = 22,
        damage = 9, cooldown = 0.34, speed = 720, count = 1, spread = 0, range = 760,
        desc = "Fast precision shots, +8% crit",
        apply = function(p) p.stats.crit = p.stats.crit + 0.08 end
    },
    swarm = {
        id = "swarm", projectileSprite = "projectile_swarm_missile",
        name = "Swarm Launcher", brand = "swarm", element = "kinetic", price = 28,
        damage = 4, cooldown = 0.62, speed = 560, count = 5, spread = 0.42, range = 650,
        desc = "Fires many low-damage projectiles"
    },
    molten = {
        id = "molten", projectileSprite = "projectile_molten_orb",
        name = "Molten Cannon", brand = "molten", element = "burn", price = 34,
        damage = 22, cooldown = 1.10, speed = 420, count = 1, spread = 0, range = 700, splash = 58,
        desc = "Slow explosive burn shots"
    },
    echo = {
        id = "echo", projectileSprite = "projectile_echo_blade",
        name = "Echo Blade", brand = "echo", element = "arc", price = 32,
        damage = 11, cooldown = 0.54, speed = 620, count = 1, spread = 0, range = 680, bounce = 2,
        desc = "Bounces to nearby enemies"
    },
    coil = {
        id = "coil", projectileSprite = "projectile_arc_bolt",
        name = "Arc Coil", brand = "echo", element = "arc", price = 36,
        damage = 15, cooldown = 0.88, speed = 0, count = 1, spread = 0, range = 420, chain = 3,
        desc = "Periodic chain lightning"
    },
    void = {
        id = "void", projectileSprite = "projectile_void_orb",
        name = "Void Orb", brand = "blackbox", element = "void", price = 38,
        damage = 8, cooldown = 1.25, speed = 210, count = 1, spread = 0, range = 620, aura = 48,
        desc = "Slow orb that pulls and damages"
    }
}

local itemPool = {
    {name = "Calibrated Lens", kind = "item", rarity = "rare", price = 18, desc = "+10% damage, +4% crit", apply = function(p) p.stats.damage = p.stats.damage + 0.10; p.stats.crit = p.stats.crit + 0.04 end},
    {name = "Pulse Metronome", kind = "item", rarity = "rare", price = 20, desc = "+14% fire rate, -4% damage", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.14; p.stats.damage = p.stats.damage - 0.04 end},
    {name = "Scavenger Ring", kind = "item", rarity = "common", price = 14, desc = "+30 pickup range, +1 luck", apply = function(p) p.pickup = p.pickup + 30; p.stats.luck = p.stats.luck + 1 end},
    {name = "Light Heart Shell", kind = "shield", rarity = "rare", price = 24, desc = "+20 shield, +8% move speed", apply = function(p) p.maxShield = p.maxShield + 20; p.shield = p.shield + 20; p.speed = p.speed + 20 end},
    {name = "Heavy Heartplate", kind = "shield", rarity = "rare", price = 24, desc = "+30 HP, -5% move speed", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = p.hp + 30; p.speed = p.speed - 13 end},
    {name = "Ricochet Prism", kind = "mod", rarity = "epic", price = 42, desc = "+1 bounce, +8% range", apply = function(p) p.stats.bounce = p.stats.bounce + 1; p.stats.range = p.stats.range + 0.08 end},
    {name = "Hollowpoint Core", kind = "mod", rarity = "epic", price = 44, desc = "+1 pierce, +12% projectile speed", apply = function(p) p.stats.pierce = p.stats.pierce + 1; p.stats.projectileSpeed = p.stats.projectileSpeed + 0.12 end},
    {name = "Mending Gel", kind = "item", rarity = "common", price = 16, desc = "+18 max HP, heal 25 now", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 25) end},
    {name = "Coin Refluxer", kind = "relic", rarity = "epic", price = 48, desc = "Picking coins briefly raises fire rate", flag = "coinHaste", apply = function(p) p.gear.coinHaste = true end},
    {name = "Do Not Blink", kind = "legend", rarity = "legend", price = 64, desc = "After a crit kill, next shot always crits", flag = "blink", apply = function(p) p.gear.blink = true end},
    {name = "Kindness Has a Price", kind = "legend", rarity = "legend", price = 68, desc = "Shield break releases a pulse, longer delay", flag = "shieldBurst", apply = function(p) p.gear.shieldBurst = true; p.shieldRegen = p.shieldRegen - 1 end},
    {name = "Echoes Never End", kind = "legend", rarity = "legend", price = 66, desc = "+2 bounce, -6% damage", flag = "endlessEcho", apply = function(p) p.stats.bounce = p.stats.bounce + 2; p.stats.damage = p.stats.damage - 0.06 end}
}

local enemyDefs = {
    drifter = {name = "Drifting Noise", sprite = "enemy_drifter", hp = 18, speed = 78, damage = 9, r = 14, color = C.red, xp = 3, coin = 2},
    splinter = {name = "Splinter", sprite = "enemy_splinter", hp = 12, speed = 130, damage = 7, r = 10, color = C.orange, xp = 2, coin = 1},
    shell = {name = "Shell Memory", sprite = "enemy_shell", hp = 44, speed = 50, damage = 13, r = 20, color = C.green, armor = 2, xp = 5, coin = 4},
    wisp = {name = "Arc Wisp", sprite = "enemy_wisp", hp = 24, speed = 105, damage = 8, r = 13, color = C.cyan, xp = 4, coin = 3},
    elite = {name = "Runaway Shade", sprite = "enemy_elite", hp = 190, speed = 64, damage = 18, r = 28, color = C.purple, armor = 3, xp = 16, coin = 12, elite = true},
    boss = {name = "Heartbreak Core", sprite = "boss_heartbreak", hp = 3200, speed = 44, damage = 24, r = 46, color = C.pink, armor = 4, xp = 80, coin = 60, boss = true}
}

local rarityColor = {
    common = {0.82, 0.86, 0.94},
    rare = {0.25, 0.66, 1.00},
    epic = {0.74, 0.40, 1.00},
    legend = {1.00, 0.62, 0.16}
}

local function color(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function distance(a, b, c, d)
    local dx, dy = a - c, b - d
    return math.sqrt(dx * dx + dy * dy)
end

local function angleTo(ax, ay, bx, by)
    return math.atan2(by - ay, bx - ax)
end

local function drawHeart(x, y, s, mode)
    local points = {}
    for i = 0, 42 do
        local t = i / 42 * TAU
        points[#points + 1] = x + (16 * math.sin(t) ^ 3) * s
        points[#points + 1] = y - (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * s
    end
    love.graphics.polygon(mode or "fill", points)
end

local assetFiles = {
    player_heartcore = "assets/player_heartcore.png",
    enemy_splinter = "assets/enemy_splinter.png",
    enemy_drifter = "assets/enemy_drifter.png",
    enemy_shell = "assets/enemy_shell.png",
    enemy_wisp = "assets/enemy_wisp.png",
    enemy_elite = "assets/enemy_elite.png",
    boss_heartbreak = "assets/boss_heartbreak.png",
    pickup_coin = "assets/pickup_coin.png",
    pickup_xp = "assets/pickup_xp.png",
    pickup_shield = "assets/pickup_shield.png",
    projectile_star_needle = "assets/projectile_star_needle.png",
    projectile_swarm_missile = "assets/projectile_swarm_missile.png",
    projectile_molten_orb = "assets/projectile_molten_orb.png",
    projectile_echo_blade = "assets/projectile_echo_blade.png",
    projectile_arc_bolt = "assets/projectile_arc_bolt.png",
    projectile_void_orb = "assets/projectile_void_orb.png"
}

local function loadImages()
    Game.images = {}
    for key, path in pairs(assetFiles) do
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("linear", "linear")
            Game.images[key] = img
        end
    end
end

local function drawSprite(name, x, y, size, rotation, alpha)
    local img = name and Game.images[name]
    if not img then return false end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    local scale = size / math.max(img:getWidth(), img:getHeight())
    love.graphics.draw(img, x, y, rotation or 0, scale, scale, img:getWidth() / 2, img:getHeight() / 2)
    return true
end

local function addText(x, y, text, c)
    Game.damageTexts[#Game.damageTexts + 1] = {x = x, y = y, text = text, color = c or C.white, life = 0.72}
end

local function burst(x, y, c, count, power)
    for _ = 1, count or 8 do
        local a = rnd() * TAU
        local v = rnd(40, power or 170)
        Game.particles[#Game.particles + 1] = {x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v, r = rnd(2, 5), color = c, life = rnd(28, 72) / 100, max = 0.72}
    end
end

local function toast(text)
    Game.message = text
    Game.messageTimer = 2.0
end

local function chooseEnemyDef()
    if Game.wave >= 10 and #Game.enemies == 0 then return enemyDefs.boss end
    local roll = rnd()
    if Game.wave >= 4 and roll < 0.12 then return enemyDefs.shell end
    if Game.wave >= 3 and roll < 0.25 then return enemyDefs.wisp end
    if Game.wave >= 6 and roll > 0.92 then return enemyDefs.elite end
    if roll < 0.46 then return enemyDefs.splinter end
    return enemyDefs.drifter
end

local function spawnEnemy(def)
    def = def or chooseEnemyDef()
    local side = rnd(1, 4)
    local x, y
    if side == 1 then x, y = -40, rnd(40, Game.h - 40)
    elseif side == 2 then x, y = Game.w + 40, rnd(40, Game.h - 40)
    elseif side == 3 then x, y = rnd(40, Game.w - 40), -40
    else x, y = rnd(40, Game.w - 40), Game.h + 40 end
    local scale = 1 + (Game.wave - 1) * 0.18
    Game.enemies[#Game.enemies + 1] = {
        name = def.name, x = x, y = y, r = def.r,
        hp = def.hp * scale, maxHp = def.hp * scale,
        speed = def.speed + Game.wave * 2,
        damage = def.damage, armor = def.armor or 0,
        color = def.color, xp = def.xp, coin = def.coin, sprite = def.sprite,
        elite = def.elite, boss = def.boss,
        burn = 0, slow = 0, corrosion = 0
    }
end

local function spawnPickup(kind, x, y, value)
    local sprite = kind == "xp" and "pickup_xp" or "pickup_coin"
    Game.pickups[#Game.pickups + 1] = {kind = kind, x = x, y = y, r = kind == "xp" and 5 or 6, value = value or 1, t = rnd() * TAU, sprite = sprite}
end

local function nearestEnemy(x, y, range)
    local best, bestD = nil, range or 999999
    for _, e in ipairs(Game.enemies) do
        local d = distance(x, y, e.x, e.y)
        if d < bestD then best, bestD = e, d end
    end
    return best, bestD
end

local function applyItem(item)
    item.apply(Game.player)
    toast("Gained: " .. item.name)
end

local function addWeapon(def)
    local p = Game.player
    local found = nil
    for _, w in ipairs(p.weapons) do
        if w.id == def.id then found = w break end
    end
    if found then
        found.level = found.level + 1
        found.damage = found.damage + math.max(1, math.floor(def.damage * 0.28))
        found.cooldown = found.cooldown * 0.94
        toast(def.name .. " upgraded to Lv." .. found.level)
    else
        local w = {}
        for k, v in pairs(def) do w[k] = v end
        w.timer = 0
        w.level = 1
        p.weapons[#p.weapons + 1] = w
        if w.apply then w.apply(p) end
        toast("Equipped: " .. w.name)
    end
end

local function makeWeaponItem(id)
    local def = weaponDefs[id]
    local item = {kind = "weapon", id = id, name = def.name, price = def.price, rarity = "rare", desc = brands[def.brand].name .. " / " .. elements[def.element].name .. " / " .. def.desc}
    item.buy = function() addWeapon(def) end
    return item
end

local function cloneItem(src)
    local item = {}
    for k, v in pairs(src) do item[k] = v end
    item.buy = function() applyItem(item) end
    return item
end

local function randomShopItem()
    local luck = Game.player.stats.luck
    if rnd() < 0.48 then
        local keys = {"needle", "swarm", "molten", "echo", "coil", "void"}
        return makeWeaponItem(keys[rnd(1, #keys)])
    end
    local candidates = {}
    for _, item in ipairs(itemPool) do
        local weight = 1
        if item.rarity == "legend" then weight = 0.25 + luck * 0.02 end
        if item.rarity == "epic" then weight = 0.55 + luck * 0.03 end
        if rnd() < weight then candidates[#candidates + 1] = item end
    end
    if #candidates == 0 then candidates = itemPool end
    return cloneItem(candidates[rnd(1, #candidates)])
end

local function rollShop(keepLocks)
    for i = 1, 4 do
        if not keepLocks or not Game.locked[i] then
            Game.shop[i] = randomShopItem()
            Game.locked[i] = false
        end
    end
end

local function startWave()
    Game.state = "playing"
    Game.waveTime = 30
    Game.enemies, Game.bullets, Game.pickups = {}, {}, {}
    Game.spawnTimer = 0.25
    Game.player.shieldDelay = 0
    toast("Wave " .. Game.wave .. ": survive 30s")
    if Game.wave == 10 then spawnEnemy(enemyDefs.boss) end
end

local function enterShop()
    Game.state = "shop"
    Game.shopRefresh = 0
    rollShop(true)
    toast("Shop open: build with intent")
end

local function resetRun()
    Game.time = 0
    Game.wave = 1
    Game.coins = 18
    Game.xp = 0
    Game.level = 1
    Game.xpNeed = 24
    Game.kills = 0
    Game.message = ""
    Game.player.x, Game.player.y = Game.w / 2, Game.h / 2
    Game.player.hp, Game.player.maxHp = 70, 70
    Game.player.shield, Game.player.maxShield = 35, 35
    Game.player.shieldDelay, Game.player.shieldRegen = 0, 7
    Game.player.speed, Game.player.pickup = 250, 82
    Game.player.invuln = 0
    Game.player.stats = {damage = 1, fireRate = 1, crit = 0.06, critDamage = 1.65, range = 1, projectileSpeed = 1, pierce = 0, bounce = 0, luck = 0}
    Game.player.weapons = {}
    Game.player.gear = {}
    Game.shop, Game.locked = {}, {}
    addWeapon(weaponDefs.needle)
    rollShop(false)
    startWave()
end

local function gainXp(n)
    Game.xp = Game.xp + n
    while Game.xp >= Game.xpNeed do
        Game.xp = Game.xp - Game.xpNeed
        Game.level = Game.level + 1
        Game.xpNeed = math.floor(Game.xpNeed * 1.25 + 8)
        Game.player.maxHp = Game.player.maxHp + 5
        Game.player.hp = math.min(Game.player.maxHp, Game.player.hp + 12)
        Game.player.stats.damage = Game.player.stats.damage + 0.04
        toast("Level " .. Game.level .. ": damage and HP up")
    end
end

local function killEnemy(e)
    Game.kills = Game.kills + 1
    Game.coins = Game.coins + e.coin
    spawnPickup("xp", e.x, e.y, e.xp)
    if rnd() < 0.52 then spawnPickup("coin", e.x + rnd(-14, 14), e.y + rnd(-14, 14), math.max(1, math.floor(e.coin / 2))) end
    if e.elite and rnd() < 0.72 then spawnPickup("coin", e.x, e.y, e.coin + 8) end
    burst(e.x, e.y, e.color, e.boss and 44 or 12, e.boss and 260 or 150)
    if e.boss then Game.state = "victory" end
end

local function damageEnemy(e, amount, element, crit)
    local armor = math.max(0, (e.armor or 0) - (e.corrosion or 0))
    local dmg = math.max(1, amount - armor)
    e.hp = e.hp - dmg
    addText(e.x, e.y - e.r, tostring(math.floor(dmg)) .. (crit and "!" or ""), crit and C.gold or elements[element or "kinetic"].color)
    if element == "burn" then e.burn = math.max(e.burn or 0, 3.0) end
    if element == "corrode" then e.corrosion = math.min(5, (e.corrosion or 0) + 1) end
    if element == "ice" then e.slow = math.max(e.slow or 0, 2.2) end
    if element == "void" then
        for _, other in ipairs(Game.enemies) do
            local d = distance(e.x, e.y, other.x, other.y)
            if other ~= e and d < 90 then
                other.x = other.x + (e.x - other.x) * 0.035
                other.y = other.y + (e.y - other.y) * 0.035
            end
        end
    end
    if e.hp <= 0 then return true end
    return false
end

local function fireProjectile(w, target, angle)
    local p = Game.player
    local crit = rnd() < p.stats.crit or p.gear.nextCrit
    p.gear.nextCrit = false
    local dmg = w.damage * p.stats.damage * (crit and p.stats.critDamage or 1)
    Game.bullets[#Game.bullets + 1] = {
        x = p.x, y = p.y, vx = math.cos(angle) * w.speed * p.stats.projectileSpeed, vy = math.sin(angle) * w.speed * p.stats.projectileSpeed,
        r = w.splash and 7 or 4, damage = dmg, element = w.element, range = w.range * p.stats.range,
        traveled = 0, pierce = (w.pierce or 0) + p.stats.pierce, bounce = (w.bounce or 0) + p.stats.bounce,
        splash = w.splash, aura = w.aura, color = elements[w.element].color, sprite = w.projectileSprite, crit = crit, target = target
    }
end

local function useChainWeapon(w, target)
    local p = Game.player
    local hit = target
    local used = {}
    local chains = (w.chain or 1) + math.floor(p.stats.bounce / 2)
    for _ = 1, chains do
        if not hit then break end
        local crit = rnd() < p.stats.crit
        local dmg = w.damage * p.stats.damage * (crit and p.stats.critDamage or 1)
        if damageEnemy(hit, dmg, w.element, crit) then used[hit] = true end
        burst(hit.x, hit.y, elements[w.element].color, 5, 90)
        used[hit] = true
        local nextHit, bestD = nil, 170
        for _, e in ipairs(Game.enemies) do
            local d = distance(hit.x, hit.y, e.x, e.y)
            if not used[e] and d < bestD then nextHit, bestD = e, d end
        end
        hit = nextHit
    end
end

local function updateWeapons(dt)
    local p = Game.player
    if p.gear.coinHasteTimer and p.gear.coinHasteTimer > 0 then p.gear.coinHasteTimer = p.gear.coinHasteTimer - dt end
    local haste = p.gear.coinHasteTimer and p.gear.coinHasteTimer > 0 and 1.22 or 1
    for _, w in ipairs(p.weapons) do
        w.timer = (w.timer or 0) - dt
        local cooldown = w.cooldown / math.max(0.25, p.stats.fireRate * haste)
        if w.timer <= 0 then
            local target = nearestEnemy(p.x, p.y, w.range * p.stats.range)
            if target then
                if w.chain then
                    useChainWeapon(w, target)
                else
                    local base = angleTo(p.x, p.y, target.x, target.y)
                    local count = w.count or 1
                    for i = 1, count do
                        local offset = count == 1 and 0 or ((i - (count + 1) / 2) / math.max(1, count - 1)) * (w.spread or 0)
                        fireProjectile(w, target, base + offset)
                    end
                end
                w.timer = cooldown
            end
        end
    end
end

local function updateBullets(dt)
    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if b.aura then
            b.vx, b.vy = b.vx * 0.997, b.vy * 0.997
            for _, e in ipairs(Game.enemies) do
                local d = distance(b.x, b.y, e.x, e.y)
                if d < b.aura then
                    e.x = e.x + (b.x - e.x) * dt * 0.9
                    e.y = e.y + (b.y - e.y) * dt * 0.9
                    if not e._voidTick or e._voidTick <= 0 then
                        e._voidTick = 0.28
                        damageEnemy(e, b.damage * 0.38, b.element, false)
                    end
                end
            end
        end
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        b.traveled = b.traveled + math.sqrt(b.vx * b.vx + b.vy * b.vy) * dt
        local remove = b.traveled > b.range
        for _, e in ipairs(Game.enemies) do
            if not remove and distance(b.x, b.y, e.x, e.y) < b.r + e.r then
                local dead = damageEnemy(e, b.damage, b.element, b.crit)
                burst(b.x, b.y, b.color, 4, 90)
                if b.splash then
                    for _, other in ipairs(Game.enemies) do
                        if other ~= e and distance(e.x, e.y, other.x, other.y) < b.splash then
                            damageEnemy(other, b.damage * 0.45, b.element, false)
                        end
                    end
                    burst(e.x, e.y, b.color, 14, 150)
                end
                if dead and Game.player.gear.blink and b.crit then Game.player.gear.nextCrit = true end
                if b.bounce and b.bounce > 0 then
                    local nextE = nil
                    local best = 190
                    for _, other in ipairs(Game.enemies) do
                        local d = distance(e.x, e.y, other.x, other.y)
                        if other ~= e and d < best then nextE, best = other, d end
                    end
                    if nextE then
                        local a = angleTo(b.x, b.y, nextE.x, nextE.y)
                        b.vx = math.cos(a) * math.max(260, math.sqrt(b.vx * b.vx + b.vy * b.vy))
                        b.vy = math.sin(a) * math.max(260, math.sqrt(b.vx * b.vx + b.vy * b.vy))
                        b.bounce = b.bounce - 1
                    else
                        remove = true
                    end
                elseif b.pierce and b.pierce > 0 then
                    b.pierce = b.pierce - 1
                else
                    remove = true
                end
            end
        end
        if remove then table.remove(Game.bullets, i) end
    end
end

local function damagePlayer(amount)
    local p = Game.player
    if p.invuln > 0 then return end
    p.invuln = 0.55
    p.shieldDelay = 2.4
    Game.shake = 0.25
    local hadShield = p.shield > 0
    if p.shield > 0 then
        local used = math.min(p.shield, amount)
        p.shield = p.shield - used
        amount = amount - used
    end
    if amount > 0 then p.hp = p.hp - amount end
    if hadShield and p.shield <= 0 and p.gear.shieldBurst then
        for _, e in ipairs(Game.enemies) do
            if distance(p.x, p.y, e.x, e.y) < 165 then damageEnemy(e, 32 * p.stats.damage, "arc", false) end
        end
        burst(p.x, p.y, C.cyan, 38, 240)
    end
    if p.hp <= 0 then Game.state = "gameover" end
end

local function updateEnemies(dt)
    local p = Game.player
    for i = #Game.enemies, 1, -1 do
        local e = Game.enemies[i]
        if e._voidTick then e._voidTick = e._voidTick - dt end
        if e.burn and e.burn > 0 then
            e.burn = e.burn - dt
            e.hp = e.hp - 5 * dt
        end
        if e.slow and e.slow > 0 then e.slow = e.slow - dt end
        local spd = e.speed * ((e.slow and e.slow > 0) and 0.58 or 1)
        local a = angleTo(e.x, e.y, p.x, p.y)
        e.x = e.x + math.cos(a) * spd * dt
        e.y = e.y + math.sin(a) * spd * dt
        if distance(e.x, e.y, p.x, p.y) < e.r + p.r then
            damagePlayer(e.damage)
            e.x = e.x - math.cos(a) * 18
            e.y = e.y - math.sin(a) * 18
        end
        if e.hp <= 0 then
            killEnemy(e)
            table.remove(Game.enemies, i)
        end
    end
end

local function updatePickups(dt)
    local p = Game.player
    for i = #Game.pickups, 1, -1 do
        local item = Game.pickups[i]
        item.t = item.t + dt * 4
        local d = distance(p.x, p.y, item.x, item.y)
        if d < p.pickup then
            item.x = item.x + (p.x - item.x) * dt * 5.5
            item.y = item.y + (p.y - item.y) * dt * 5.5
        end
        if d < p.r + item.r + 4 then
            if item.kind == "xp" then gainXp(item.value) end
            if item.kind == "coin" then
                Game.coins = Game.coins + item.value
                if p.gear.coinHaste then p.gear.coinHasteTimer = 2.2 end
            end
            table.remove(Game.pickups, i)
        end
    end
end

local function updatePlayer(dt)
    local p = Game.player
    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end
    p.x = clamp(p.x + dx * p.speed * dt, 24, Game.w - 24)
    p.y = clamp(p.y + dy * p.speed * dt, 30, Game.h - 24)
    p.invuln = math.max(0, p.invuln - dt)
    if p.shieldDelay > 0 then
        p.shieldDelay = p.shieldDelay - dt
    else
        p.shield = math.min(p.maxShield, p.shield + p.shieldRegen * dt)
    end
end

local function updatePlaying(dt)
    Game.time = Game.time + dt
    Game.waveTime = Game.waveTime - dt
    Game.spawnTimer = (Game.spawnTimer or 0) - dt
    if Game.spawnTimer <= 0 and not (Game.wave == 10 and #Game.enemies > 0) then
        local packs = math.min(5, 1 + math.floor(Game.wave / 3))
        for _ = 1, packs do spawnEnemy() end
        Game.spawnTimer = math.max(0.38, 1.18 - Game.wave * 0.065)
    end
    updatePlayer(dt)
    updateWeapons(dt)
    updateBullets(dt)
    updateEnemies(dt)
    updatePickups(dt)
    if Game.waveTime <= 0 and Game.state == "playing" then
        if Game.wave >= Game.maxWave then
            Game.state = "victory"
        else
            Game.wave = Game.wave + 1
            Game.coins = Game.coins + 10 + Game.wave * 2
            enterShop()
        end
    end
end

function love.load()
    love.window.setTitle("Heartcore Survivor Prototype")
    love.graphics.setDefaultFilter("linear", "linear")
    love.math.setRandomSeed(os.time())
    Game.w, Game.h = love.graphics.getDimensions()
    Game.fonts = {tiny = love.graphics.newFont(13), small = love.graphics.newFont(17), normal = love.graphics.newFont(22), big = love.graphics.newFont(36), title = love.graphics.newFont(60)}
    loadImages()
    for _ = 1, 130 do
        Game.stars[#Game.stars + 1] = {x = rnd() * Game.w, y = rnd() * Game.h, r = rnd(7, 21) / 10, speed = rnd(8, 38), phase = rnd() * TAU}
    end
end

function love.update(dt)
    Game.w, Game.h = love.graphics.getDimensions()
    for _, s in ipairs(Game.stars) do
        s.x = s.x - s.speed * dt
        s.phase = s.phase + dt * 2
        if s.x < -8 then s.x = Game.w + 8; s.y = rnd() * Game.h end
    end
    for i = #Game.particles, 1, -1 do
        local p = Game.particles[i]
        p.life = p.life - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.vx, p.vy = p.vx * (1 - dt * 1.8), p.vy * (1 - dt * 1.8)
        if p.life <= 0 then table.remove(Game.particles, i) end
    end
    for i = #Game.damageTexts, 1, -1 do
        local t = Game.damageTexts[i]
        t.life = t.life - dt
        t.y = t.y - 34 * dt
        if t.life <= 0 then table.remove(Game.damageTexts, i) end
    end
    Game.messageTimer = math.max(0, Game.messageTimer - dt)
    Game.shake = math.max(0, Game.shake - dt)
    if Game.state == "playing" then updatePlaying(dt) end
    if os.getenv("LOVE_AUTOSHOT") == "1" and not Game.autoShotDone then
        if Game.state == "menu" then resetRun() end
        if Game.time > 2.0 then
            Game.autoShotDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-prototype.png")
            love.event.quit()
        end
    end
end

local function drawBackground()
    love.graphics.clear(C.bgA)
    for i = 0, 18 do
        local t = i / 18
        love.graphics.setColor(C.bgA[1] + (C.bgB[1] - C.bgA[1]) * t, C.bgA[2] + (C.bgB[2] - C.bgA[2]) * t, C.bgA[3] + (C.bgB[3] - C.bgA[3]) * t, 1)
        love.graphics.rectangle("fill", 0, Game.h * t, Game.w, Game.h / 18 + 1)
    end
    for _, s in ipairs(Game.stars) do
        love.graphics.setColor(0.75, 0.86, 1, 0.28 + math.sin(s.phase) * 0.16)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end
    love.graphics.setColor(0.20, 0.48, 0.95, 0.10)
    love.graphics.circle("fill", Game.w * 0.18, Game.h * 0.70, 220)
    love.graphics.setColor(0.80, 0.20, 0.58, 0.10)
    love.graphics.circle("fill", Game.w * 0.82, Game.h * 0.22, 190)
end

local function panel(x, y, w, h)
    color(C.panel)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    color(C.line)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 14, 14)
end

local function bar(x, y, w, h, pct, c, bg)
    love.graphics.setColor(bg and bg[1] or 0, bg and bg[2] or 0, bg and bg[3] or 0, 0.42)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    color(c)
    love.graphics.rectangle("fill", x, y, w * clamp(pct, 0, 1), h, 5, 5)
end

local function drawHud()
    local p = Game.player
    panel(18, 14, 420, 108)
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.print("Wave " .. Game.wave .. "/" .. Game.maxWave, 36, 26)
    color(C.gold)
    love.graphics.print("$" .. Game.coins, 165, 26)
    color(C.muted)
    love.graphics.print("Kills " .. Game.kills, 260, 26)
    bar(36, 62, 190, 12, p.hp / p.maxHp, C.pink)
    bar(36, 82, 190, 10, p.shield / p.maxShield, C.cyan)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.print("HP " .. math.ceil(p.hp) .. "/" .. p.maxHp, 236, 57)
    love.graphics.print("SH " .. math.ceil(p.shield) .. "/" .. p.maxShield, 236, 77)
    bar(312, 65, 94, 10, Game.xp / Game.xpNeed, C.green)
    color(C.muted)
    love.graphics.print("Lv." .. Game.level, 315, 82)

    panel(Game.w / 2 - 135, 14, 270, 74)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf(string.format("%02d", math.max(0, math.ceil(Game.waveTime))), Game.w / 2 - 135, 25, 270, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("30s survival wave", Game.w / 2 - 135, 62, 270, "center")

    panel(Game.w - 390, 14, 370, 108)
    love.graphics.setFont(Game.fonts.tiny)
    local y = 28
    for i, w in ipairs(p.weapons) do
        local brand = brands[w.brand]
        color(brand.color)
        love.graphics.print(w.name .. " Lv." .. w.level, Game.w - 370, y)
        color(C.muted)
        love.graphics.print(brand.tag, Game.w - 210, y)
        y = y + 19
        if i >= 4 then break end
    end
end

local function drawWorld()
    for _, item in ipairs(Game.pickups) do
        local size = item.kind == "xp" and 26 or 28
        if not drawSprite(item.sprite, item.x, item.y + math.sin(item.t) * 2, size, 0, 0.95) then
            if item.kind == "xp" then color(C.green) else color(C.gold) end
            love.graphics.circle("fill", item.x, item.y + math.sin(item.t) * 2, item.r)
        end
    end

    for _, b in ipairs(Game.bullets) do
        if b.aura then
            color(b.color, 0.22)
            love.graphics.circle("line", b.x, b.y, b.aura)
        end
        local rot = math.atan2(b.vy, b.vx)
        local size = b.aura and 46 or (b.splash and 34 or 28)
        if not drawSprite(b.sprite, b.x, b.y, size, rot, 0.95) then
            color(b.color, 0.90)
            love.graphics.circle("fill", b.x, b.y, b.r)
        end
    end

    for _, e in ipairs(Game.enemies) do
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], e.boss and 0.16 or 0.08)
        love.graphics.circle("fill", e.x, e.y, e.r * 1.55)
        local size = e.boss and e.r * 3.15 or math.max(42, e.r * 3.95)
        if not drawSprite(e.sprite, e.x, e.y, size, 0, 0.96) then
            color(e.color)
            if e.boss then
                love.graphics.rectangle("fill", e.x - e.r, e.y - e.r, e.r * 2, e.r * 2, 10, 10)
            elseif e.elite then
                love.graphics.polygon("fill", e.x, e.y - e.r, e.x + e.r, e.y, e.x, e.y + e.r, e.x - e.r, e.y)
            else
                love.graphics.circle("fill", e.x, e.y, e.r)
            end
        end
        if e.hp < e.maxHp then bar(e.x - e.r, e.y - e.r - 13, e.r * 2, 4, e.hp / e.maxHp, C.red) end
    end

    local p = Game.player
    if not (p.invuln > 0 and math.floor(p.invuln * 16) % 2 == 0) then
        love.graphics.setColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.055)
        love.graphics.circle("fill", p.x, p.y, p.pickup)
        if not drawSprite("player_heartcore", p.x, p.y, 72, 0, 1) then
            color(C.pink)
            drawHeart(p.x, p.y + 2, 0.78)
        end
        color(C.cyan, 0.58)
        love.graphics.circle("line", p.x, p.y, p.r + 14)
    end

    for _, q in ipairs(Game.particles) do color(q.color, clamp(q.life / q.max, 0, 1)); love.graphics.circle("fill", q.x, q.y, q.r) end
    for _, t in ipairs(Game.damageTexts) do color(t.color, clamp(t.life / 0.72, 0, 1)); love.graphics.setFont(Game.fonts.tiny); love.graphics.print(t.text, t.x, t.y) end
end

local function drawMenu()
    love.graphics.setFont(Game.fonts.title)
    color(C.white)
    love.graphics.printf("HEARTCORE", 0, 165, Game.w, "center")
    color(C.pink)
    love.graphics.printf("SURVIVOR", 0, 225, Game.w, "center")
    love.graphics.setFont(Game.fonts.normal)
    color(C.muted)
    love.graphics.printf("30s waves / auto aim / readable builds", 0, 315, Game.w, "center")
    panel(Game.w / 2 - 255, 390, 510, 120)
    color(C.white)
    love.graphics.printf("Enter to start prototype", Game.w / 2 - 255, 416, 510, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("WASD / arrows move. Weapons auto-fire. Shop after each wave.", Game.w / 2 - 225, 462, 450, "center")
end

local function drawShop()
    drawHud()
    panel(120, 126, Game.w - 240, Game.h - 172)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf("Shop: Wave " .. (Game.wave - 1) .. " cleared", 120, 148, Game.w - 240, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("1-4 buy | Z/X/C/V lock | R reroll | Enter next wave", 120, 190, Game.w - 240, "center")
    for i, item in ipairs(Game.shop) do
        local x = 160 + (i - 1) * ((Game.w - 320) / 4)
        local y = 250
        local w = (Game.w - 380) / 4
        panel(x, y, w, 250)
        color(rarityColor[item.rarity or "common"] or C.white)
        love.graphics.setFont(Game.fonts.normal)
        love.graphics.printf(i .. ". " .. item.name, x + 16, y + 22, w - 32, "left")
        love.graphics.setFont(Game.fonts.tiny)
        color(C.muted)
        love.graphics.printf(item.kind .. " / " .. (item.rarity or "common"), x + 16, y + 58, w - 32, "left")
        color(C.white)
        love.graphics.printf(item.desc, x + 16, y + 92, w - 32, "left")
        color(C.gold)
        love.graphics.printf("Cost $" .. item.price, x + 16, y + 192, w - 32, "left")
        if Game.locked[i] then color(C.cyan); love.graphics.printf("LOCKED", x + 16, y + 218, w - 32, "left") end
    end
end

local function drawEnd(title, subtitle, c)
    love.graphics.setColor(0, 0, 0, 0.56)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    panel(Game.w / 2 - 300, 205, 600, 260)
    love.graphics.setFont(Game.fonts.big)
    color(c)
    love.graphics.printf(title, Game.w / 2 - 300, 245, 600, "center")
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf(subtitle, Game.w / 2 - 300, 305, 600, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.gold)
    love.graphics.printf("Wave " .. Game.wave .. "   Kills " .. Game.kills .. "   Coins $" .. Game.coins, Game.w / 2 - 300, 360, 600, "center")
    color(C.muted)
    love.graphics.printf("Enter restart / Esc quit", Game.w / 2 - 300, 405, 600, "center")
end

function love.draw()
    local ox, oy = 0, 0
    if Game.shake > 0 then ox, oy = rnd(-5, 5) * Game.shake * 3, rnd(-5, 5) * Game.shake * 3 end
    love.graphics.push()
    love.graphics.translate(ox, oy)
    drawBackground()
    if Game.state == "menu" then drawMenu(); love.graphics.pop(); return end
    if Game.state == "shop" then drawShop(); love.graphics.pop(); return end
    drawWorld()
    drawHud()
    if Game.messageTimer > 0 then
        local toastY = 132
        panel(Game.w / 2 - 260, toastY, 520, 40)
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf(Game.message, Game.w / 2 - 250, toastY + 11, 500, "center")
    end
    if Game.state == "gameover" then drawEnd("HEART BROKEN", "Build failed. The void was less kind than you hoped.", C.red) end
    if Game.state == "victory" then drawEnd("RUN CLEARED", "Heartcore stable. The void retreats.", C.gold) end
    love.graphics.pop()
end

local function buySlot(i)
    local item = Game.shop[i]
    if not item then return end
    if Game.coins < item.price then toast("Not enough coins") return end
    Game.coins = Game.coins - item.price
    if item.buy then item.buy() end
    Game.shop[i] = randomShopItem()
    Game.locked[i] = false
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if key == "return" or key == "kpenter" then
        if Game.state == "menu" or Game.state == "gameover" or Game.state == "victory" then resetRun()
        elseif Game.state == "shop" then startWave() end
    end
    if Game.state == "shop" then
        if key == "1" then buySlot(1) end
        if key == "2" then buySlot(2) end
        if key == "3" then buySlot(3) end
        if key == "4" then buySlot(4) end
        if key == "r" then
            local cost = 3 + Game.shopRefresh * 2
            if Game.coins >= cost then Game.coins = Game.coins - cost; Game.shopRefresh = Game.shopRefresh + 1; rollShop(true) else toast("Not enough coins to reroll") end
        end
        if key == "z" then Game.locked[1] = not Game.locked[1] end
        if key == "x" then Game.locked[2] = not Game.locked[2] end
        if key == "c" then Game.locked[3] = not Game.locked[3] end
        if key == "v" then Game.locked[4] = not Game.locked[4] end
    end
end
