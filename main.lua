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
    selectedCharacter = 1,
    selectedObjective = 1,
    danger = 0,
    freeRefresh = 1,
    levelChoices = {},
    objectiveProgress = 0,
    objectiveText = "",
    enemyShots = {},
    runStats = {damage = 0, damageByWeapon = {}, coinsEarned = 0, highestWave = 1, rerolls = 0},
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
            luck = 0,
            armor = 0,
            dodge = 0.03,
            lifesteal = 0,
            engineering = 0,
            harvest = 0
        },
        weapons = {},
        gear = {}
    },
    fonts = {},
    images = {},
    sounds = {}
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
    kinetic = {name = "动能", color = C.white, desc = "直接伤害"},
    burn = {name = "灼烧", color = C.orange, desc = "持续伤害"},
    arc = {name = "电弧", color = C.cyan, desc = "连锁闪电"},
    corrode = {name = "腐蚀", color = C.green, desc = "削弱护甲"},
    ice = {name = "霜冻", color = C.ice, desc = "减速冻结"},
    void = {name = "虚空", color = C.purple, desc = "牵引异常"}
}

local brands = {
    starforge = {name = "星铸", color = C.gold, tag = "精准暴击"},
    swarm = {name = "蜂群", color = C.green, tag = "多弹清场"},
    molten = {name = "熔火", color = C.orange, tag = "爆燃轰击"},
    echo = {name = "回声", color = C.cyan, tag = "弹射连锁"},
    blackbox = {name = "黑箱", color = C.purple, tag = "异常代价"}
}

local weaponDefs = {
    needle = {
        id = "needle", projectileSprite = "projectile_star_needle",
        name = "星针", brand = "starforge", element = "kinetic", price = 22,
        damage = 9, cooldown = 0.34, speed = 720, count = 1, spread = 0, range = 760,
        desc = "高速精准射击，暴击 +8%",
        apply = function(p) p.stats.crit = p.stats.crit + 0.08 end
    },
    swarm = {
        id = "swarm", projectileSprite = "projectile_swarm_missile",
        name = "蜂群发射器", brand = "swarm", element = "kinetic", price = 28,
        damage = 4, cooldown = 0.62, speed = 560, count = 5, spread = 0.42, range = 650,
        desc = "发射多枚低伤弹体"
    },
    molten = {
        id = "molten", projectileSprite = "projectile_molten_orb",
        name = "熔火炮", brand = "molten", element = "burn", price = 34,
        damage = 22, cooldown = 1.10, speed = 420, count = 1, spread = 0, range = 700, splash = 58,
        desc = "慢速爆炸灼烧弹"
    },
    echo = {
        id = "echo", projectileSprite = "projectile_echo_blade",
        name = "回声刃", brand = "echo", element = "arc", price = 32,
        damage = 11, cooldown = 0.54, speed = 620, count = 1, spread = 0, range = 680, bounce = 2,
        desc = "命中后弹向附近敌人"
    },
    coil = {
        id = "coil", projectileSprite = "projectile_arc_bolt",
        name = "电弧线圈", brand = "echo", element = "arc", price = 36,
        damage = 15, cooldown = 0.88, speed = 0, count = 1, spread = 0, range = 420, chain = 3,
        desc = "周期性连锁闪电"
    },
    void = {
        id = "void", projectileSprite = "projectile_void_orb",
        name = "虚空球", brand = "blackbox", element = "void", price = 38,
        damage = 8, cooldown = 1.25, speed = 210, count = 1, spread = 0, range = 620, aura = 48,
        desc = "缓慢牵引并造成伤害"
    }
}

local itemPool = {
    {name = "校准透镜", kind = "item", rarity = "rare", price = 18, desc = "伤害 +10%，暴击 +4%", apply = function(p) p.stats.damage = p.stats.damage + 0.10; p.stats.crit = p.stats.crit + 0.04 end},
    {name = "脉冲节拍器", kind = "item", rarity = "rare", price = 20, desc = "射速 +14%，伤害 -4%", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.14; p.stats.damage = p.stats.damage - 0.04 end},
    {name = "拾荒者戒环", kind = "item", rarity = "common", price = 14, desc = "拾取范围 +30，幸运 +1", apply = function(p) p.pickup = p.pickup + 30; p.stats.luck = p.stats.luck + 1 end},
    {name = "轻型心壳", kind = "shield", rarity = "rare", price = 24, desc = "护盾 +20，移速 +8%", apply = function(p) p.maxShield = p.maxShield + 20; p.shield = p.shield + 20; p.speed = p.speed + 20 end},
    {name = "重型心甲", kind = "shield", rarity = "rare", price = 24, desc = "生命 +30，移速 -5%", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = p.hp + 30; p.speed = p.speed - 13 end},
    {name = "弹射棱镜", kind = "mod", rarity = "epic", price = 42, desc = "弹射 +1，射程 +8%", apply = function(p) p.stats.bounce = p.stats.bounce + 1; p.stats.range = p.stats.range + 0.08 end},
    {name = "空尖核心", kind = "mod", rarity = "epic", price = 44, desc = "穿透 +1，弹速 +12%", apply = function(p) p.stats.pierce = p.stats.pierce + 1; p.stats.projectileSpeed = p.stats.projectileSpeed + 0.12 end},
    {name = "修补凝胶", kind = "item", rarity = "common", price = 16, desc = "最大生命 +18，立即治疗 25", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 25) end},
    {name = "晶币回流器", kind = "relic", rarity = "epic", price = 48, desc = "拾取晶币后短暂提高射速", flag = "coinHaste", apply = function(p) p.gear.coinHaste = true end},
    {name = "别眨眼", kind = "legend", rarity = "legend", price = 64, desc = "暴击击杀后，下一击必定暴击", flag = "blink", apply = function(p) p.gear.blink = true end},
    {name = "善意有价", kind = "legend", rarity = "legend", price = 68, desc = "护盾破裂释放脉冲，但回复更慢", flag = "shieldBurst", apply = function(p) p.gear.shieldBurst = true; p.shieldRegen = p.shieldRegen - 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", price = 66, desc = "弹射 +2，伤害 -6%", flag = "endlessEcho", apply = function(p) p.stats.bounce = p.stats.bounce + 2; p.stats.damage = p.stats.damage - 0.06 end},
    {name = "陶瓷装甲片", kind = "shield", rarity = "common", price = 18, desc = "护甲 +2，移速 -2%", apply = function(p) p.stats.armor = p.stats.armor + 2; p.speed = p.speed - 5 end},
    {name = "神经闪避器", kind = "mod", rarity = "rare", price = 26, desc = "闪避 +7%，生命 -8", apply = function(p) p.stats.dodge = p.stats.dodge + 0.07; p.maxHp = p.maxHp - 8; p.hp = math.min(p.hp, p.maxHp) end},
    {name = "虹吸针管", kind = "relic", rarity = "rare", price = 30, desc = "生命偷取 +3%，暴击 -2%", apply = function(p) p.stats.lifesteal = p.stats.lifesteal + 0.03; p.stats.crit = p.stats.crit - 0.02 end},
    {name = "工程无人机", kind = "relic", rarity = "epic", price = 46, desc = "工程 +1：周期电击附近敌人", apply = function(p) p.stats.engineering = p.stats.engineering + 1 end},
    {name = "收获协议", kind = "relic", rarity = "epic", price = 44, desc = "收获 +4：战后额外晶币", apply = function(p) p.stats.harvest = p.stats.harvest + 4 end},
    {name = "赌徒电容", kind = "legend", rarity = "legend", price = 70, desc = "幸运 +6，闪避 +8%，护甲 -2", apply = function(p) p.stats.luck = p.stats.luck + 6; p.stats.dodge = p.stats.dodge + 0.08; p.stats.armor = p.stats.armor - 2 end}
}

local enemyDefs = {
    drifter = {name = "漂移噪声", sprite = "enemy_drifter", hp = 18, speed = 78, damage = 9, r = 14, color = C.red, xp = 3, coin = 2, behavior = "chase"},
    splinter = {name = "裂片", sprite = "enemy_splinter", hp = 12, speed = 130, damage = 7, r = 10, color = C.orange, xp = 2, coin = 1, behavior = "charger"},
    shell = {name = "壳层记忆", sprite = "enemy_shell", hp = 44, speed = 50, damage = 13, r = 20, color = C.green, armor = 2, xp = 5, coin = 4, behavior = "guard"},
    wisp = {name = "电弧游魂", sprite = "enemy_wisp", hp = 24, speed = 105, damage = 8, r = 13, color = C.cyan, xp = 4, coin = 3, behavior = "shooter"},
    elite = {name = "失控阴影", sprite = "enemy_elite", hp = 190, speed = 64, damage = 18, r = 28, color = C.purple, armor = 3, xp = 16, coin = 12, elite = true, behavior = "aura"},
    boss = {name = "碎心核心", sprite = "boss_heartbreak", hp = 3200, speed = 44, damage = 24, r = 46, color = C.pink, armor = 4, xp = 80, coin = 60, boss = true, behavior = "boss"}
}

local wavePlans = {
    {name = "裂片试探", duration = 30, interval = 1.10, pack = 1, sides = {"left", "right"}, enemies = {{"splinter", 70}, {"drifter", 30}}},
    {name = "双翼骚扰", duration = 30, interval = 1.02, pack = 2, sides = {"left", "right", "top"}, enemies = {{"splinter", 52}, {"drifter", 38}, {"wisp", 10}}},
    {name = "电弧乱流", duration = 32, interval = 0.92, pack = 2, sides = {"top", "right", "left"}, enemies = {{"splinter", 40}, {"drifter", 30}, {"wisp", 30}}, events = {{time = 18, enemy = "elite", side = "right", toast = "精英信号：右侧突破"}}},
    {name = "装甲推进", duration = 32, interval = 0.88, pack = 2, sides = {"left", "right", "bottom"}, enemies = {{"splinter", 32}, {"drifter", 28}, {"wisp", 18}, {"shell", 22}}},
    {name = "交叉包围", duration = 34, interval = 0.80, pack = 3, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 30}, {"drifter", 30}, {"wisp", 25}, {"shell", 15}}, events = {{time = 12, enemy = "elite", side = "left", toast = "精英压境：左侧"}}},
    {name = "重壳浪潮", duration = 34, interval = 0.78, pack = 3, sides = {"right", "bottom", "top"}, enemies = {{"drifter", 25}, {"wisp", 25}, {"shell", 38}, {"splinter", 12}}, events = {{time = 22, enemy = "elite", side = "bottom", toast = "底线精英出现"}}},
    {name = "高速撕裂", duration = 36, interval = 0.70, pack = 3, sides = {"left", "right"}, enemies = {{"splinter", 42}, {"drifter", 38}, {"wisp", 12}, {"shell", 8}}, events = {{time = 16, enemy = "elite", side = "right"}}},
    {name = "四面噪声", duration = 36, interval = 0.64, pack = 4, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 28}, {"drifter", 28}, {"wisp", 26}, {"shell", 18}}, events = {{time = 10, enemy = "elite", side = "top"}, {time = 25, enemy = "elite", side = "bottom"}}},
    {name = "核心前夜", duration = 38, interval = 0.58, pack = 4, sides = {"right", "left", "top", "bottom"}, enemies = {{"splinter", 24}, {"drifter", 28}, {"wisp", 28}, {"shell", 20}}, events = {{time = 9, enemy = "elite", side = "left"}, {time = 21, enemy = "elite", side = "right"}}},
    {name = "碎心核心", duration = 60, interval = 0.95, pack = 2, sides = {"left", "right", "top", "bottom"}, boss = true, enemies = {{"splinter", 28}, {"drifter", 26}, {"wisp", 26}, {"shell", 20}}, events = {{time = 0.2, enemy = "boss", side = "right", toast = "Boss：碎心核心降临"}, {time = 20, enemy = "elite", side = "left"}, {time = 40, enemy = "elite", side = "right"}}}
}

local function currentWavePlan()
    return wavePlans[Game.wave] or wavePlans[#wavePlans]
end
local affixDefs = {
    bounty = {name = "赏金", kind = "reward", desc = "晶币 +25%", coinMult = 1.25},
    overcharge = {name = "过载", kind = "reward", desc = "伤害 +10%", playerDamage = 1.10},
    magnet = {name = "磁场", kind = "reward", desc = "经验 +15%", xpMult = 1.15, pickupBonus = 18},
    calibrate = {name = "校准", kind = "reward", desc = "暴击 +6%", critBonus = 0.06},
    repair = {name = "修复", kind = "reward", desc = "护盾回复 +30%", shieldRegenMult = 1.30},

    swarm = {name = "蜂拥", kind = "penalty", desc = "敌群 +1", extraPack = 1, intervalMult = 0.94},
    rage = {name = "激怒", kind = "penalty", desc = "敌速 +12%", enemySpeed = 1.12},
    carapace = {name = "坚壳", kind = "penalty", desc = "敌血 +16%", enemyHp = 1.16, enemyArmor = 1},
    volatile = {name = "易爆", kind = "penalty", desc = "敌伤 +12%", enemyDamage = 1.12},
    drought = {name = "枯竭", kind = "penalty", desc = "护盾回复 -25%", shieldRegenMult = 0.75}
}

local waveAffixes = {
    {reward = "bounty", penalty = "swarm"},
    {reward = "magnet", penalty = "rage"},
    {reward = "calibrate", penalty = "volatile"},
    {reward = "repair", penalty = "carapace"},
    {reward = "overcharge", penalty = "swarm"},
    {reward = "bounty", penalty = "drought"},
    {reward = "magnet", penalty = "carapace"},
    {reward = "calibrate", penalty = "rage"},
    {reward = "repair", penalty = "volatile"},
    {reward = "overcharge", penalty = "carapace"}
}

local function currentAffixes()
    local pair = waveAffixes[Game.wave] or waveAffixes[#waveAffixes] or {}
    return affixDefs[pair.reward], affixDefs[pair.penalty]
end

local function currentAffixBonuses()
    local bonus = {
        coinMult = 1, xpMult = 1, playerDamage = 1, critBonus = 0, pickupBonus = 0,
        shieldRegenMult = 1, enemyHp = 1, enemySpeed = 1, enemyDamage = 1, enemyArmor = 0,
        extraPack = 0, intervalMult = 1
    }
    local reward, penalty = currentAffixes()
    for _, affix in ipairs({reward, penalty}) do
        if affix then
            bonus.coinMult = bonus.coinMult * (affix.coinMult or 1)
            bonus.xpMult = bonus.xpMult * (affix.xpMult or 1)
            bonus.playerDamage = bonus.playerDamage * (affix.playerDamage or 1)
            bonus.critBonus = bonus.critBonus + (affix.critBonus or 0)
            bonus.pickupBonus = bonus.pickupBonus + (affix.pickupBonus or 0)
            bonus.shieldRegenMult = bonus.shieldRegenMult * (affix.shieldRegenMult or 1)
            bonus.enemyHp = bonus.enemyHp * (affix.enemyHp or 1)
            bonus.enemySpeed = bonus.enemySpeed * (affix.enemySpeed or 1)
            bonus.enemyDamage = bonus.enemyDamage * (affix.enemyDamage or 1)
            bonus.enemyArmor = bonus.enemyArmor + (affix.enemyArmor or 0)
            bonus.extraPack = bonus.extraPack + (affix.extraPack or 0)
            bonus.intervalMult = bonus.intervalMult * (affix.intervalMult or 1)
        end
    end
    return bonus
end

local function affixLabel()
    local reward, penalty = currentAffixes()
    if reward and penalty then return "奖励 " .. reward.name .. " / 惩罚 " .. penalty.name end
    if reward then return "奖励 " .. reward.name end
    if penalty then return "惩罚 " .. penalty.name end
    return "无词缀"
end

local characterDefs = {
    {name = "心核原型", weapon = "needle", desc = "均衡机体，稳定上手", hp = 70, shield = 35, speed = 250, coins = 18, stats = {damage = 1, fireRate = 1, crit = 0.06, critDamage = 1.65, range = 1, projectileSpeed = 1, pierce = 0, bounce = 0, luck = 0, armor = 0, dodge = 0.03, lifesteal = 0, engineering = 0, harvest = 0}},
    {name = "蜂群指挥", weapon = "swarm", desc = "多弹清场，单发偏弱", hp = 62, shield = 28, speed = 262, coins = 20, stats = {damage = 0.90, fireRate = 1.12, crit = 0.04, critDamage = 1.55, range = 0.96, projectileSpeed = 1.05, pierce = 0, bounce = 0, luck = 1, armor = 0, dodge = 0.06, lifesteal = 0, engineering = 0, harvest = 1}},
    {name = "重壳堡垒", weapon = "molten", desc = "高护甲高生命，移动迟缓", hp = 96, shield = 46, speed = 214, coins = 16, stats = {damage = 1.08, fireRate = 0.88, crit = 0.03, critDamage = 1.70, range = 1, projectileSpeed = 0.96, pierce = 0, bounce = 0, luck = 0, armor = 4, dodge = 0.00, lifesteal = 0, engineering = 0, harvest = 0}},
    {name = "回声术士", weapon = "echo", desc = "弹射连锁，身板偏脆", hp = 58, shield = 32, speed = 246, coins = 22, stats = {damage = 0.96, fireRate = 1.02, crit = 0.08, critDamage = 1.65, range = 1.08, projectileSpeed = 1, pierce = 0, bounce = 1, luck = 2, armor = -1, dodge = 0.05, lifesteal = 0, engineering = 0, harvest = 0}}
}

local objectiveDefs = {
    {name = "生存清剿", desc = "撑到计时结束，稳定推进", mode = "survive"},
    {name = "精英悬赏", desc = "每波击杀指定数量敌人可提前收工", mode = "bounty"},
    {name = "核心充能", desc = "站在中央区域充能，满值后结束本波", mode = "charge"}
}

local levelRewardPool = {
    {name = "伤害校准", desc = "伤害 +8%", apply = function(p) p.stats.damage = p.stats.damage + 0.08 end},
    {name = "射速同步", desc = "射速 +10%", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.10 end},
    {name = "生命扩容", desc = "最大生命 +14，治疗 10", apply = function(p) p.maxHp = p.maxHp + 14; p.hp = math.min(p.maxHp, p.hp + 10) end},
    {name = "护盾增幅", desc = "最大护盾 +12，回复 +1", apply = function(p) p.maxShield = p.maxShield + 12; p.shield = p.shield + 12; p.shieldRegen = p.shieldRegen + 1 end},
    {name = "护甲叠层", desc = "护甲 +2", apply = function(p) p.stats.armor = p.stats.armor + 2 end},
    {name = "闪避步态", desc = "闪避 +5%", apply = function(p) p.stats.dodge = p.stats.dodge + 0.05 end},
    {name = "虹吸回路", desc = "生命偷取 +2%", apply = function(p) p.stats.lifesteal = p.stats.lifesteal + 0.02 end},
    {name = "拾荒算法", desc = "幸运 +2，拾取 +16", apply = function(p) p.stats.luck = p.stats.luck + 2; p.pickup = p.pickup + 16 end},
    {name = "工程协议", desc = "工程 +1", apply = function(p) p.stats.engineering = p.stats.engineering + 1 end},
    {name = "收获模块", desc = "收获 +3", apply = function(p) p.stats.harvest = p.stats.harvest + 3 end},
    {name = "穿透校准", desc = "穿透 +1", apply = function(p) p.stats.pierce = p.stats.pierce + 1 end},
    {name = "弹射预案", desc = "弹射 +1", apply = function(p) p.stats.bounce = p.stats.bounce + 1 end}
}

local function selectedCharacter() return characterDefs[Game.selectedCharacter] or characterDefs[1] end
local function selectedObjective() return objectiveDefs[Game.selectedObjective] or objectiveDefs[1] end

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
    player_heartcore = "assets/nano_banana_pro_mapped/player_heartcore.png",
    enemy_splinter = "assets/nano_banana_pro_mapped/enemy_splinter.png",
    enemy_drifter = "assets/nano_banana_pro_mapped/enemy_drifter.png",
    enemy_shell = "assets/nano_banana_pro_mapped/enemy_shell.png",
    enemy_wisp = "assets/nano_banana_pro_mapped/enemy_wisp.png",
    enemy_elite = "assets/nano_banana_pro_mapped/enemy_elite.png",
    boss_heartbreak = "assets/nano_banana_pro_mapped/boss_heartbreak.png",
    pickup_coin = "assets/nano_banana_pro_mapped/pickup_coin.png",
    pickup_xp = "assets/nano_banana_pro_mapped/pickup_xp.png",
    pickup_shield = "assets/nano_banana_pro_mapped/pickup_shield.png",
    projectile_star_needle = "assets/nano_banana_pro_mapped/projectile_star_needle.png",
    projectile_swarm_missile = "assets/nano_banana_pro_mapped/projectile_swarm_missile.png",
    projectile_molten_orb = "assets/nano_banana_pro_mapped/projectile_molten_orb.png",
    projectile_echo_blade = "assets/nano_banana_pro_mapped/projectile_echo_blade.png",
    projectile_arc_bolt = "assets/nano_banana_pro_mapped/projectile_arc_bolt.png",
    projectile_void_orb = "assets/nano_banana_pro_mapped/projectile_void_orb.png",
    arena_background = "assets/backgrounds/robot_war_arena.png"
}

local function loadImages()
    Game.images = {}
    for key, path in pairs(assetFiles) do
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            if key == "arena_background" then
                img:setFilter("linear", "linear")
            else
                img:setFilter("nearest", "nearest")
            end
            Game.images[key] = img
        end
    end
end

local function makeTone(freq, duration, volume)
    if not love.sound or not love.audio then return nil end
    local rate = 22050
    local samples = math.max(1, math.floor(rate * duration))
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / rate
        local fade = math.min(1, (duration - t) / math.max(0.001, duration * 0.35))
        data:setSample(i, math.sin(TAU * freq * t) * (volume or 0.18) * fade)
    end
    return love.audio.newSource(data, "static")
end

local function playCue(name)
    local src = Game.sounds and Game.sounds[name]
    if src then
        local ok, clone = pcall(function() return src:clone() end)
        if ok and clone then clone:play() end
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

local function drawProjectile(b)
    local rot = math.atan2(b.vy, b.vx)
    love.graphics.push()
    love.graphics.translate(b.x, b.y)
    love.graphics.rotate(rot)

    -- 统一尾迹/外发光：高速战斗里弹体必须先被看见
    love.graphics.setBlendMode("add")
    color(b.color, 0.30)
    love.graphics.rectangle("fill", -40, -5, 36, 10, 5, 5)
    color(b.color, 0.22)
    love.graphics.circle("fill", 0, 0, b.aura and 19 or 13)
    love.graphics.setBlendMode("alpha")

    if b.aura then
        love.graphics.setLineWidth(2)
        color(b.color, 0.42)
        love.graphics.circle("line", 0, 0, b.aura)
        love.graphics.setLineWidth(1)
        color(b.color, 0.95)
        love.graphics.circle("fill", 0, 0, 12)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.circle("fill", -3, -3, 4)
    elseif b.splash then
        color(b.color, 0.92)
        love.graphics.circle("fill", 0, 0, 9)
        love.graphics.setColor(1, 0.92, 0.45, 0.88)
        love.graphics.circle("fill", 0, 0, 4)
        color(b.color, 0.35)
        love.graphics.circle("line", 0, 0, 14)
    elseif b.element == "arc" then
        color(b.color, 0.95)
        love.graphics.setLineWidth(3)
        love.graphics.line(-14, -3, -4, 4, 4, -4, 14, 2)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.line(-14, -3, -4, 4, 4, -4, 14, 2)
        love.graphics.setLineWidth(1)
    else
        color(b.color, 0.32)
        love.graphics.rectangle("fill", -17, -5, 26, 10, 5, 5)
        color(b.color, 1)
        love.graphics.polygon("fill", -10, -6, 14, 0, -10, 6)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.line(-8, 0, 10, 0)
    end

    love.graphics.pop()
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

local function weightedEnemy(plan)
    plan = plan or currentWavePlan()
    local total = 0
    for _, entry in ipairs(plan.enemies or {{"splinter", 1}}) do total = total + entry[2] end
    local roll = rnd() * total
    for _, entry in ipairs(plan.enemies or {{"splinter", 1}}) do
        roll = roll - entry[2]
        if roll <= 0 then return enemyDefs[entry[1]] end
    end
    return enemyDefs.splinter
end

local function spawnPoint(side)
    local marginTop, marginBottom = 160, 92
    if side == "left" then return -58, rnd(marginTop, Game.h - marginBottom) end
    if side == "right" then return Game.w + 58, rnd(marginTop, Game.h - marginBottom) end
    if side == "top" then return rnd(120, Game.w - 120), -58 end
    if side == "bottom" then return rnd(120, Game.w - 120), Game.h + 58 end
    local n = rnd(1, 4)
    if n == 1 then return spawnPoint("left") elseif n == 2 then return spawnPoint("right") elseif n == 3 then return spawnPoint("top") end
    return spawnPoint("bottom")
end

local function pickSpawnSide(plan)
    local sides = plan and plan.sides or {"left", "right", "top", "bottom"}
    return sides[rnd(1, #sides)]
end

local function spawnEnemy(def, opts)
    opts = opts or {}
    local plan = currentWavePlan()
    def = def or weightedEnemy(plan)
    local x, y = spawnPoint(opts.side or pickSpawnSide(plan))
    local bonus = currentAffixBonuses()
    local dangerScale = 1 + Game.danger * 0.08
    local scale = (opts.scale or 1) * (1 + (Game.wave - 1) * 0.14) * bonus.enemyHp * dangerScale
    local hp = def.hp * scale
    Game.enemies[#Game.enemies + 1] = {
        name = def.name, x = x, y = y, r = def.r,
        hp = hp, maxHp = hp,
        speed = (def.speed + Game.wave * 2) * bonus.enemySpeed * (1 + Game.danger * 0.025),
        damage = def.damage * bonus.enemyDamage * (1 + Game.danger * 0.06), armor = (def.armor or 0) + bonus.enemyArmor,
        color = def.color, xp = def.xp, coin = def.coin, sprite = def.sprite, behavior = def.behavior or "chase",
        elite = def.elite, boss = def.boss,
        shootTimer = rnd() * 1.2, dashTimer = rnd() * 1.6,
        burn = 0, slow = 0, corrosion = 0
    }
end

local function spawnPack(plan)
    plan = plan or currentWavePlan()
    local side = pickSpawnSide(plan)
    local bonus = currentAffixBonuses()
    local pack = (plan.pack or 1) + bonus.extraPack
    for _ = 1, pack do spawnEnemy(weightedEnemy(plan), {side = side}) end
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
    playCue("shop"); toast("获得：" .. item.name)
    return true
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
        found.tier = 1 + math.floor((found.level - 1) / 2)
        playCue("shop"); toast(def.name .. " 合成至等级 " .. found.level)
        return true
    end
    if #p.weapons >= 6 then
        toast("武器槽已满：先回收一把")
        return false
    end
    local w = {}
    for k, v in pairs(def) do w[k] = v end
    w.timer = 0
    w.level = 1
    w.tier = 1
    p.weapons[#p.weapons + 1] = w
    if w.apply then w.apply(p) end
    playCue("shop"); toast("已装备：" .. w.name)
    return true
end

local function makeWeaponItem(id)
    local def = weaponDefs[id]
    local item = {kind = "weapon", id = id, name = def.name, price = def.price, rarity = "rare", desc = brands[def.brand].name .. " / " .. elements[def.element].name .. " / " .. def.desc}
    item.buy = function() return addWeapon(def) end
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
    local used = {}
    if keepLocks then
        for i = 1, 4 do
            if Game.locked[i] and Game.shop[i] then used[Game.shop[i].name] = true end
        end
    end
    for i = 1, 4 do
        if not keepLocks or not Game.locked[i] then
            local item = randomShopItem()
            for _ = 1, 10 do
                if not used[item.name] then break end
                item = randomShopItem()
            end
            Game.shop[i] = item
            Game.locked[i] = false
            used[item.name] = true
        end
    end
end

local function startWave()
    local plan = currentWavePlan()
    Game.state = "playing"
    Game.waveTime = plan.duration or 30
    Game.waveElapsed = 0
    Game.waveEventIndex = 1
    Game.waveStartKills = Game.kills
    Game.objectiveProgress = selectedObjective().mode == "charge" and math.min(35, (Game.objectiveProgress or 0) * 0.25) or 0
    Game.objectiveText = selectedObjective().name
    Game.enemies, Game.bullets, Game.pickups = {}, {}, {}
    Game.spawnTimer = 0.25
    Game.player.shieldDelay = 0
    toast("第 " .. Game.wave .. " 波：" .. (plan.name or "战斗") .. " / " .. affixLabel())
end

local function enterShop()
    Game.state = "shop"
    Game.shopRefresh = 0
    rollShop(true)
    toast("商店开启：认真构筑")
end

local function resetRun()
    local ch = selectedCharacter()
    Game.time = 0
    Game.wave = 1
    Game.coins = ch.coins or 18
    Game.xp = 0
    Game.level = 1
    Game.xpNeed = 24
    Game.kills = 0
    Game.freeRefresh = 1 + math.floor((ch.stats and ch.stats.luck or 0) / 3)
    Game.levelChoices = {}
    Game.objectiveProgress = 0
    Game.objectiveText = ""
    Game.message = ""
    Game.enemyShots = {}
    Game.runStats = {damage = 0, damageByWeapon = {}, coinsEarned = 0, highestWave = 1, rerolls = 0}
    Game.player.x, Game.player.y = Game.w / 2, Game.h / 2
    Game.player.hp, Game.player.maxHp = ch.hp, ch.hp
    Game.player.shield, Game.player.maxShield = ch.shield, ch.shield
    Game.player.shieldDelay, Game.player.shieldRegen = 0, 7
    Game.player.speed, Game.player.pickup = ch.speed, 82
    Game.player.pickupBonus = 0
    Game.player.invuln = 0
    Game.player.engineerTimer = 0
    Game.player.stats = {}
    for k, v in pairs(ch.stats) do Game.player.stats[k] = v end
    Game.player.weapons = {}
    Game.player.gear = {}
    Game.shop, Game.locked = {}, {}
    addWeapon(weaponDefs[ch.weapon or "needle"])
    rollShop(false)
    startWave()
end

local function generateLevelChoices()
    local used = {}
    Game.levelChoices = {}
    for i = 1, 3 do
        local pick = levelRewardPool[rnd(1, #levelRewardPool)]
        for _ = 1, 12 do
            if not used[pick.name] then break end
            pick = levelRewardPool[rnd(1, #levelRewardPool)]
        end
        used[pick.name] = true
        Game.levelChoices[i] = pick
    end
end

local function chooseLevelReward(i)
    local reward = Game.levelChoices[i]
    if not reward then return end
    reward.apply(Game.player)
    toast("升级选择：" .. reward.name)
    Game.levelChoices = {}
    Game.state = "playing"
end

local function gainXp(n)
    local bonus = currentAffixBonuses()
    Game.xp = Game.xp + math.max(1, math.floor(n * bonus.xpMult + 0.5))
    if Game.state ~= "playing" then return end
    if Game.xp >= Game.xpNeed then
        Game.xp = Game.xp - Game.xpNeed
        Game.level = Game.level + 1
        Game.xpNeed = math.floor(Game.xpNeed * 1.25 + 8)
        generateLevelChoices()
        Game.state = "levelup"
        playCue("level"); toast("等级 " .. Game.level .. "：选择一项强化")
    end
end

local function killEnemy(e)
    local bonus = currentAffixBonuses()
    Game.kills = Game.kills + 1
    local coinGain = math.max(1, math.floor(e.coin * bonus.coinMult + 0.5))
    Game.coins = Game.coins + coinGain
    Game.runStats.coinsEarned = (Game.runStats.coinsEarned or 0) + coinGain
    spawnPickup("xp", e.x, e.y, e.xp)
    if rnd() < 0.52 then spawnPickup("coin", e.x + rnd(-14, 14), e.y + rnd(-14, 14), math.max(1, math.floor(e.coin / 2))) end
    if e.elite and rnd() < 0.72 then spawnPickup("coin", e.x, e.y, e.coin + 8) end
    playCue(e.elite and "elite" or "pickup"); burst(e.x, e.y, e.color, e.boss and 44 or 12, e.boss and 260 or 150)
    if e.boss then Game.state = "victory" end
end

local function damageEnemy(e, amount, element, crit, source)
    local armor = math.max(0, (e.armor or 0) - (e.corrosion or 0))
    local dmg = math.max(1, amount - armor)
    e.hp = e.hp - dmg
    Game.runStats.damage = (Game.runStats.damage or 0) + dmg
    local src = source or "未知"
    Game.runStats.damageByWeapon[src] = (Game.runStats.damageByWeapon[src] or 0) + dmg
    if Game.player.stats.lifesteal > 0 and rnd() < Game.player.stats.lifesteal then Game.player.hp = math.min(Game.player.maxHp, Game.player.hp + 1) end
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
    local bonus = currentAffixBonuses()
    local crit = rnd() < math.min(0.85, p.stats.crit + bonus.critBonus) or p.gear.nextCrit
    p.gear.nextCrit = false
    local dmg = w.damage * p.stats.damage * bonus.playerDamage * (crit and p.stats.critDamage or 1)
    Game.bullets[#Game.bullets + 1] = {
        x = p.x, y = p.y, vx = math.cos(angle) * w.speed * p.stats.projectileSpeed, vy = math.sin(angle) * w.speed * p.stats.projectileSpeed,
        r = w.splash and 7 or 4, damage = dmg, element = w.element, range = w.range * p.stats.range,
        traveled = 0, pierce = (w.pierce or 0) + p.stats.pierce, bounce = (w.bounce or 0) + p.stats.bounce,
        splash = w.splash, aura = w.aura, color = elements[w.element].color, sprite = w.projectileSprite, crit = crit, target = target, source = w.name
    }
end

local function useChainWeapon(w, target)
    local p = Game.player
    local hit = target
    local used = {}
    local chains = (w.chain or 1) + math.floor(p.stats.bounce / 2)
    for _ = 1, chains do
        if not hit then break end
        local bonus = currentAffixBonuses()
        local crit = rnd() < math.min(0.85, p.stats.crit + bonus.critBonus)
        local dmg = w.damage * p.stats.damage * bonus.playerDamage * (crit and p.stats.critDamage or 1)
        if damageEnemy(hit, dmg, w.element, crit, w.name) then used[hit] = true end
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
    local bonus = currentAffixBonuses()
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
                        damageEnemy(e, b.damage * 0.38, b.element, false, b.source)
                    end
                end
            end
        end
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        b.traveled = b.traveled + math.sqrt(b.vx * b.vx + b.vy * b.vy) * dt
        local remove = b.traveled > b.range
        for _, e in ipairs(Game.enemies) do
            if not remove and distance(b.x, b.y, e.x, e.y) < b.r + e.r then
                local dead = damageEnemy(e, b.damage, b.element, b.crit, b.source)
                burst(b.x, b.y, b.color, 4, 90)
                if b.splash then
                    for _, other in ipairs(Game.enemies) do
                        if other ~= e and distance(e.x, e.y, other.x, other.y) < b.splash then
                            damageEnemy(other, b.damage * 0.45, b.element, false, b.source)
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
    if p.stats.dodge and rnd() < clamp(p.stats.dodge, 0, 0.65) then
        p.invuln = 0.35
        addText(p.x - 18, p.y - 28, "闪避", C.cyan)
        return
    end
    p.invuln = 0.55
    p.shieldDelay = 2.4
    playCue("hit"); Game.shake = 0.25
    amount = math.max(1, amount - math.max(0, p.stats.armor or 0))
    local hadShield = p.shield > 0
    if p.shield > 0 then
        local used = math.min(p.shield, amount)
        p.shield = p.shield - used
        amount = amount - used
    end
    if amount > 0 then p.hp = p.hp - amount end
    if hadShield and p.shield <= 0 and p.gear.shieldBurst then
        for _, e in ipairs(Game.enemies) do
            if distance(p.x, p.y, e.x, e.y) < 165 then damageEnemy(e, 32 * p.stats.damage, "arc", false, "护盾脉冲") end
        end
        burst(p.x, p.y, C.cyan, 38, 240)
    end
    if p.hp <= 0 then Game.state = "gameover" end
end

local function fireEnemyShot(e, a)
    Game.enemyShots[#Game.enemyShots + 1] = {x = e.x, y = e.y, vx = math.cos(a) * 250, vy = math.sin(a) * 250, r = 6, damage = e.damage * 0.75, color = e.color, life = 3.0}
end

local function updateEnemyShots(dt)
    local p = Game.player
    for i = #Game.enemyShots, 1, -1 do
        local b = Game.enemyShots[i]
        b.life = b.life - dt
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        if distance(b.x, b.y, p.x, p.y) < b.r + p.r then
            damagePlayer(b.damage)
            burst(b.x, b.y, b.color, 5, 80)
            table.remove(Game.enemyShots, i)
        elseif b.life <= 0 or b.x < -40 or b.x > Game.w + 40 or b.y < -40 or b.y > Game.h + 40 then
            table.remove(Game.enemyShots, i)
        end
    end
end

local function updateEngineering(dt)
    local p = Game.player
    local eng = p.stats.engineering or 0
    if eng <= 0 then return end
    p.engineerTimer = (p.engineerTimer or 0) - dt
    if p.engineerTimer > 0 then return end
    p.engineerTimer = math.max(0.45, 1.15 - eng * 0.06)
    local target = nearestEnemy(p.x, p.y, 420)
    if target then
        damageEnemy(target, 8 + eng * 5, "arc", false, "工程无人机")
        burst(target.x, target.y, C.cyan, 6, 90)
    end
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
        local behavior = e.behavior or "chase"
        if behavior == "shooter" and distance(e.x, e.y, p.x, p.y) < 420 then
            e.shootTimer = (e.shootTimer or 0) - dt
            if e.shootTimer <= 0 then
                fireEnemyShot(e, a)
                e.shootTimer = 1.65
            end
            spd = spd * 0.52
        elseif behavior == "charger" then
            e.dashTimer = (e.dashTimer or 0) - dt
            if e.dashTimer <= 0 and distance(e.x, e.y, p.x, p.y) < 360 then
                spd = spd * 2.4
                e.dashTimer = 2.2
                addText(e.x, e.y - e.r - 8, "突进", C.orange)
            end
        elseif behavior == "guard" then
            spd = spd * 0.78
            e.armor = math.max(e.armor or 0, 3 + math.floor(Game.wave / 3))
        elseif behavior == "aura" and distance(e.x, e.y, p.x, p.y) < 135 then
            damagePlayer(e.damage * 0.22)
        elseif behavior == "boss" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if e.shootTimer <= 0 then
                for k = -1, 1 do fireEnemyShot(e, a + k * 0.22) end
                e.shootTimer = 1.25
            end
        end
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
        if d < p.pickup + (p.pickupBonus or 0) then
            item.x = item.x + (p.x - item.x) * dt * 5.5
            item.y = item.y + (p.y - item.y) * dt * 5.5
        end
        if d < p.r + item.r + 4 then
            if item.kind == "xp" then gainXp(item.value) end
            if item.kind == "coin" then
                Game.coins = Game.coins + item.value
                Game.runStats.coinsEarned = (Game.runStats.coinsEarned or 0) + item.value
                playCue("pickup")
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
    local bonus = currentAffixBonuses()
    p.pickupBonus = bonus.pickupBonus
    if p.shieldDelay > 0 then
        p.shieldDelay = p.shieldDelay - dt
    else
        p.shield = math.min(p.maxShield, p.shield + p.shieldRegen * bonus.shieldRegenMult * dt)
    end
end

local function completeWave(reason)
    local p = Game.player
    local harvest = math.max(0, p.stats.harvest or 0)
    if harvest > 0 then
        local gain = harvest + math.floor(Game.wave / 2)
        Game.coins = Game.coins + gain
        Game.runStats.coinsEarned = (Game.runStats.coinsEarned or 0) + gain
        toast((reason or "波次完成") .. "：收获 +" .. gain .. " 晶币")
    end
    if Game.wave >= Game.maxWave then
        Game.state = "victory"
        return
    end
    Game.wave = Game.wave + 1
    Game.runStats.highestWave = math.max(Game.runStats.highestWave or 1, Game.wave)
    local base = 10 + Game.wave * 2 + Game.danger * 2
    Game.coins = Game.coins + base
    Game.runStats.coinsEarned = (Game.runStats.coinsEarned or 0) + base
    enterShop()
end

local function updatePlaying(dt)
    local plan = currentWavePlan()
    local obj = selectedObjective()
    Game.time = Game.time + dt
    Game.waveElapsed = (Game.waveElapsed or 0) + dt
    Game.waveTime = Game.waveTime - dt

    local events = plan.events or {}
    while Game.waveEventIndex and events[Game.waveEventIndex] and Game.waveElapsed >= events[Game.waveEventIndex].time do
        local event = events[Game.waveEventIndex]
        spawnEnemy(enemyDefs[event.enemy] or weightedEnemy(plan), {side = event.side, scale = event.enemy == "boss" and 1 or 1.08})
        if event.toast then toast(event.toast) end
        Game.waveEventIndex = Game.waveEventIndex + 1
    end

    Game.spawnTimer = (Game.spawnTimer or 0) - dt
    if Game.spawnTimer <= 0 and not (plan.boss and Game.waveElapsed < 4) then
        spawnPack(plan)
        local pressure = math.max(0, Game.waveElapsed / math.max(1, plan.duration or 30))
        local bonus = currentAffixBonuses()
        Game.spawnTimer = math.max(0.30, ((plan.interval or 1.0) * bonus.intervalMult) - pressure * 0.16)
    end
    updatePlayer(dt)
    updateWeapons(dt)
    updateEngineering(dt)
    updateBullets(dt)
    updateEnemyShots(dt)
    updateEnemies(dt)
    updatePickups(dt)

    if obj.mode == "charge" then
        local d = distance(Game.player.x, Game.player.y, Game.w / 2, Game.h / 2)
        if d < 120 then Game.objectiveProgress = math.min(100, (Game.objectiveProgress or 0) + dt * (16 + Game.danger * 1.5)) end
        Game.objectiveText = "充能 " .. math.floor(Game.objectiveProgress or 0) .. "%"
        if (Game.objectiveProgress or 0) >= 100 and Game.state == "playing" then completeWave("核心充能完成") end
    elseif obj.mode == "bounty" then
        local target = 12 + Game.wave * 3 + Game.danger
        local done = Game.kills - (Game.waveStartKills or 0)
        Game.objectiveText = "悬赏 " .. math.min(done, target) .. "/" .. target
        if done >= target and Game.state == "playing" then completeWave("悬赏完成") end
    else
        Game.objectiveText = "生存 " .. math.max(0, math.ceil(Game.waveTime)) .. "秒"
    end

    if Game.waveTime <= 0 and Game.state == "playing" then
        if plan.boss then
            Game.waveTime = 0
            if #Game.enemies == 0 then Game.state = "victory" end
        else
            completeWave("波次完成")
        end
    end
end

local function uiFont(size)
    local bundled = "assets/fonts/HeartcoreCJK-Regular.otf"
    if love.filesystem.getInfo(bundled) then
        return love.graphics.newFont(bundled, size)
    end
    local system = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
    local f = io.open(system, "rb")
    if f then
        f:close()
        return love.graphics.newFont(system, size)
    end
    return love.graphics.newFont(size)
end

function love.load()
    love.window.setTitle("心核幸存者 原型")
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.math.setRandomSeed(os.time())
    Game.w, Game.h = love.graphics.getDimensions()
    Game.fonts = {tiny = uiFont(13), small = uiFont(17), normal = uiFont(22), big = uiFont(36), title = uiFont(60)}
    loadImages()
    Game.sounds = {
        pickup = makeTone(880, 0.06, 0.12),
        hit = makeTone(180, 0.05, 0.10),
        level = makeTone(660, 0.16, 0.14),
        shop = makeTone(520, 0.10, 0.12),
        elite = makeTone(120, 0.22, 0.16)
    }
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
    if os.getenv("LOVE_AUTOMENU") == "1" and not Game.autoMenuDone then
        Game.autoMenuClock = (Game.autoMenuClock or 0) + dt
        if Game.autoMenuClock > 0.4 then
            Game.autoMenuDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-menu.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOLEVEL") == "1" and not Game.autoLevelDone then
        if Game.state == "menu" then resetRun() end
        Game.autoLevelClock = (Game.autoLevelClock or 0) + dt
        if Game.autoLevelClock > 0.8 and Game.state == "playing" then
            generateLevelChoices()
            Game.state = "levelup"
        end
        if Game.autoLevelClock > 1.1 then
            Game.autoLevelDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-levelup.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOSHOP") == "1" and not Game.autoShopDone then
        if Game.state == "menu" then
            resetRun()
            enterShop()
        end
        Game.autoShopClock = (Game.autoShopClock or 0) + dt
        if Game.autoShopClock > 0.4 then
            Game.autoShopDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-shop.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOSHOT") == "1" and not Game.autoShotDone then
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

    local bg = Game.images.arena_background
    if bg then
        local iw, ih = bg:getWidth(), bg:getHeight()
        local scale = math.max(Game.w / iw, Game.h / ih)
        local dw, dh = iw * scale, ih * scale
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bg, (Game.w - dw) / 2, (Game.h - dh) / 2, 0, scale, scale)

        -- Keep the generated map atmospheric but below gameplay objects.
        love.graphics.setColor(0.015, 0.018, 0.040, 0.30)
        love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
        love.graphics.setColor(0.02, 0.04, 0.08, 0.18)
        love.graphics.rectangle("fill", Game.w * 0.18, Game.h * 0.18, Game.w * 0.64, Game.h * 0.64, 28, 28)
    else
        for i = 0, 18 do
            local t = i / 18
            love.graphics.setColor(C.bgA[1] + (C.bgB[1] - C.bgA[1]) * t, C.bgA[2] + (C.bgB[2] - C.bgA[2]) * t, C.bgA[3] + (C.bgB[3] - C.bgA[3]) * t, 1)
            love.graphics.rectangle("fill", 0, Game.h * t, Game.w, Game.h / 18 + 1)
        end
    end

    for _, s in ipairs(Game.stars) do
        love.graphics.setColor(0.75, 0.86, 1, 0.045 + math.sin(s.phase) * 0.025)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end
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
    local hudY, hudH = 14, 86
    panel(18, hudY, Game.w - 36, hudH)

    -- 左：玩家状态，只保留战斗中最该扫一眼的数值
    local lx = 38
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.print("生命", lx, hudY + 13)
    bar(lx + 44, hudY + 16, 190, 11, p.hp / p.maxHp, C.pink)
    color(C.white)
    love.graphics.printf(math.ceil(p.hp) .. "/" .. p.maxHp, lx + 242, hudY + 9, 78, "right")

    color(C.muted)
    love.graphics.print("护盾", lx, hudY + 39)
    bar(lx + 44, hudY + 42, 190, 10, p.shield / p.maxShield, C.cyan)
    color(C.white)
    love.graphics.printf(math.ceil(p.shield) .. "/" .. p.maxShield, lx + 242, hudY + 35, 78, "right")

    color(C.gold)
    love.graphics.print("晶币 " .. Game.coins, lx, hudY + 63)
    color(C.muted)
    love.graphics.print("击杀 " .. Game.kills, lx + 112, hudY + 63)
    color(C.green)
    love.graphics.print("等级 " .. Game.level, lx + 224, hudY + 63)

    -- 中：倒计时做唯一视觉核心，波次/目标拆到两侧，避免三行堆叠
    local midX = Game.w / 2
    local timerW, timerH = 118, 58
    local timerX, timerY = midX - timerW / 2, hudY + 15
    color(C.white, 0.08)
    love.graphics.rectangle("fill", timerX, timerY, timerW, timerH, 16, 16)
    color(C.cyan, 0.20)
    love.graphics.rectangle("line", timerX + 0.5, timerY + 0.5, timerW - 1, timerH - 1, 16, 16)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf(string.format("%02d", math.max(0, math.ceil(Game.waveTime))), timerX, timerY + 6, timerW, "center")

    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("波次", midX - 250, hudY + 18, 145, "center")
    color(C.gold)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.printf("第 " .. Game.wave .. " 波", midX - 250, hudY + 39, 145, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(currentWavePlan().name or "生存波次", midX - 250, hudY + 64, 145, "center")

    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("目标", midX + 96, hudY + 18, 130, "center")
    color(C.cyan)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.printf(Game.objectiveText or selectedObjective().name, midX + 96, hudY + 39, 130, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("危险 " .. Game.danger, midX + 96, hudY + 64, 130, "center")

    -- 右：武器与当前词缀，压低存在感，避免抢中央计时
    local rx, rw = Game.w - 388, 348
    love.graphics.setFont(Game.fonts.tiny)
    local reward, penalty = currentAffixes()
    color(C.green)
    love.graphics.printf("奖励 " .. (reward and reward.name or "无"), rx, hudY + 10, rw / 2 - 8, "left")
    color(C.red)
    love.graphics.printf("惩罚 " .. (penalty and penalty.name or "无"), rx + rw / 2, hudY + 10, rw / 2 - 10, "right")

    local y = hudY + 40
    for i, w in ipairs(p.weapons) do
        if i > 2 then break end
        local brand = brands[w.brand]
        color(brand.color, 0.14)
        love.graphics.rectangle("fill", rx, y - 3, rw, 21, 7, 7)
        love.graphics.setFont(Game.fonts.small)
        color(brand.color)
        love.graphics.print(w.name .. " Lv" .. w.level, rx + 10, y - 1)
        love.graphics.setFont(Game.fonts.tiny)
        color(C.white, 0.78)
        love.graphics.printf(brand.tag, rx + 156, y + 1, rw - 168, "right")
        y = y + 23
    end
end

local function drawWorld()
    if Game.state == "playing" and selectedObjective().mode == "charge" then
        love.graphics.setBlendMode("add")
        color(C.cyan, 0.10)
        love.graphics.circle("fill", Game.w / 2, Game.h / 2, 120)
        color(C.cyan, 0.40)
        love.graphics.circle("line", Game.w / 2, Game.h / 2, 120)
        love.graphics.setBlendMode("alpha")
    end
    for _, item in ipairs(Game.pickups) do
        local bobY = item.y + math.sin(item.t) * 2
        local size = item.kind == "xp" and 32 or 34
        local c = item.kind == "xp" and C.green or C.gold
        love.graphics.setBlendMode("add")
        color(c, 0.26)
        love.graphics.circle("fill", item.x, bobY, size * 0.62)
        color(c, 0.40)
        love.graphics.circle("line", item.x, bobY, size * 0.46)
        love.graphics.setBlendMode("alpha")
        if not drawSprite(item.sprite, item.x, bobY, size, 0, 0.98) then
            color(c)
            love.graphics.circle("fill", item.x, bobY, item.r + 1)
        end
    end

    for _, b in ipairs(Game.bullets) do
        drawProjectile(b)
    end
    for _, b in ipairs(Game.enemyShots) do
        love.graphics.setBlendMode("add")
        color(b.color or C.red, 0.36)
        love.graphics.circle("fill", b.x, b.y, b.r * 2.2)
        love.graphics.setBlendMode("alpha")
        color(b.color or C.red, 0.95)
        love.graphics.circle("fill", b.x, b.y, b.r)
    end

    local p = Game.player
    for _, e in ipairs(Game.enemies) do
        if e.x < 82 or e.x > Game.w - 82 or e.y < 178 or e.y > Game.h - 82 then
            local wx = clamp(e.x, 44, Game.w - 44)
            local wy = clamp(e.y, 162, Game.h - 46)
            local a = math.atan2(e.y - p.y, e.x - p.x)
            love.graphics.push()
            love.graphics.translate(wx, wy)
            love.graphics.rotate(a)
            love.graphics.setBlendMode("add")
            color(e.color, 0.26)
            love.graphics.circle("fill", 0, 0, 17)
            love.graphics.setBlendMode("alpha")
            color(e.color, 0.92)
            love.graphics.polygon("fill", 15, 0, -7, -8, -4, 0, -7, 8)
            love.graphics.setColor(0.02, 0.025, 0.04, 0.72)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", 15, 0, -7, -8, -4, 0, -7, 8)
            love.graphics.setLineWidth(1)
            love.graphics.pop()
        end
        love.graphics.setColor(0, 0, 0, 0.34)
        love.graphics.ellipse("fill", e.x, e.y + e.r * 1.35, e.r * 2.2, e.r * 0.52)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], e.boss and 0.30 or 0.24)
        love.graphics.circle("fill", e.x, e.y, e.r * 2.35)
        love.graphics.setBlendMode("alpha")
        love.graphics.setLineWidth(e.boss and 3 or 2)
        love.graphics.setColor(0.02, 0.025, 0.045, 0.88)
        love.graphics.circle("line", e.x, e.y, e.r * 1.90)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.80)
        love.graphics.circle("line", e.x, e.y, e.r * 1.62)
        love.graphics.setLineWidth(1)
        local size = e.boss and e.r * 3.55 or math.max(62, e.r * 5.20)
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

    if not (p.invuln > 0 and math.floor(p.invuln * 16) % 2 == 0) then
        love.graphics.setColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.020)
        love.graphics.circle("fill", p.x, p.y, p.pickup)
        if not drawSprite("player_heartcore", p.x, p.y, 96, 0, 1) then
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
    local ch = selectedCharacter()
    local obj = selectedObjective()
    love.graphics.setFont(Game.fonts.title)
    color(C.white)
    love.graphics.printf("心核幸存者", 0, 58, Game.w, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("1-4 选择机体  ·  A/D 选择关卡目标  ·  Q/E 调整危险等级  ·  回车开始", 0, 144, Game.w, "center")

    local cardW, cardH, gap = 270, 150, 18
    local startX = Game.w / 2 - (cardW * 4 + gap * 3) / 2
    for i, cdef in ipairs(characterDefs) do
        local x = startX + (i - 1) * (cardW + gap)
        panel(x, 185, cardW, cardH)
        if i == Game.selectedCharacter then
            color(C.gold, 0.22)
            love.graphics.rectangle("fill", x + 6, 191, cardW - 12, cardH - 12, 12, 12)
            color(C.gold)
            love.graphics.rectangle("line", x + 5, 190, cardW - 10, cardH - 10, 12, 12)
        end
        love.graphics.setFont(Game.fonts.normal)
        color(i == Game.selectedCharacter and C.gold or C.white)
        love.graphics.printf(i .. ". " .. cdef.name, x + 12, 206, cardW - 24, "center")
        love.graphics.setFont(Game.fonts.tiny)
        color(C.muted)
        love.graphics.printf(cdef.desc, x + 18, 248, cardW - 36, "center")
        color(C.white)
        love.graphics.printf("初始武器：" .. weaponDefs[cdef.weapon].name, x + 18, 292, cardW - 36, "center")
    end

    panel(Game.w / 2 - 390, 390, 780, 185)
    love.graphics.setFont(Game.fonts.big)
    color(C.cyan)
    love.graphics.printf(obj.name, Game.w / 2 - 390, 416, 780, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(obj.desc, Game.w / 2 - 350, 466, 700, "center")
    color(C.gold)
    local dangerText = Game.danger == 0 and "危险等级 0：基础难度，无额外修正" or ("危险等级 " .. Game.danger .. "：敌人强化，战后补给增加")
    love.graphics.printf(dangerText, Game.w / 2 - 350, 514, 700, "center")

    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("当前：" .. ch.name .. " / " .. obj.name .. " / 危险 " .. Game.danger, 0, 622, Game.w, "center")
end

local function drawLevelUp()
    love.graphics.setColor(0, 0, 0, 0.58)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    panel(Game.w / 2 - 420, 160, 840, 360)
    love.graphics.setFont(Game.fonts.big)
    color(C.gold)
    love.graphics.printf("等级提升：选择强化", Game.w / 2 - 420, 190, 840, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("按 1 / 2 / 3 选择，本波暂停，选完继续。", Game.w / 2 - 420, 252, 840, "center")
    local w, h, gap = 240, 165, 28
    local sx = Game.w / 2 - (w * 3 + gap * 2) / 2
    for i, r in ipairs(Game.levelChoices) do
        local x = sx + (i - 1) * (w + gap)
        panel(x, 318, w, h)
        love.graphics.setFont(Game.fonts.normal)
        color(C.white)
        love.graphics.printf(i .. ". " .. r.name, x + 12, 356, w - 24, "center")
        love.graphics.setFont(Game.fonts.small)
        color(C.cyan)
        love.graphics.printf(r.desc, x + 18, 412, w - 36, "center")
    end
end

local function statText(label, value)
    return label .. " " .. value
end

local function pct(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

local function modText(text)
    return text:gsub("%+", "↑"):gsub("%-", "↓")
end

local function centeredText(text, x, y, w, h, font, c, align)
    love.graphics.setFont(font)
    color(c or C.white)
    love.graphics.printf(text, x, y + math.floor((h - font:getHeight()) / 2) + 1, w, align or "center")
end

local function tagPill(text, x, y, bg, fg)
    local font = Game.fonts.tiny
    local tw = math.max(50, font:getWidth(text) + 24)
    local th = 24
    color(bg, 0.92)
    love.graphics.rectangle("fill", x, y, tw, th, 8, 8)
    centeredText(text, x, y, tw, th, font, fg or C.bgA, "center")
    return tw
end

local rarityLabel = {common = "普通", rare = "稀有", epic = "史诗", legend = "传说"}
local kindLabel = {weapon = "武器", item = "强化", shield = "护盾", mod = "模组", relic = "遗物", legend = "传说"}

local function drawShopCard(item, i, x, y, w, h)
    local rarity = item.rarity or "common"
    local rc = rarityColor[rarity] or C.white
    local affordable = Game.coins >= item.price

    panel(x, y, w, h)
    color(rc, 0.95)
    love.graphics.rectangle("fill", x, y, w, 5, 5, 5)
    if Game.locked[i] then
        color(C.cyan, 0.32)
        love.graphics.rectangle("fill", x + 6, y + 6, w - 12, h - 12, 12, 12)
        color(C.cyan, 0.85)
        love.graphics.rectangle("line", x + 5, y + 5, w - 10, h - 10, 12, 12)
    end

    local rarityText = rarityLabel[rarity] or rarity
    local kindText = kindLabel[item.kind] or item.kind
    local tagX = x + 14
    tagX = tagX + tagPill(rarityText, tagX, y + 18, rc, C.bgA) + 8
    tagPill(kindText, tagX, y + 18, item.kind == "weapon" and C.gold or C.cyan, C.bgA)

    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf(item.name, x + 14, y + 56, w - 28, "center")

    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(modText(item.desc), x + 14, y + 94, w - 28, "center")
    love.graphics.setFont(Game.fonts.tiny)

    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = weaponDefs[item.id]
        local brand = brands[def.brand]
        local elem = elements[def.element]
        color(brand.color)
        love.graphics.printf(brand.name .. " / " .. brand.tag, x + 14, y + 166, w - 28, "center")
        color(elem.color)
        love.graphics.printf(elem.name .. " 属性", x + 14, y + 188, w - 28, "center")
        color(C.muted)
        love.graphics.printf("伤害 " .. def.damage .. "   冷却 " .. string.format("%.2f", def.cooldown) .. " 秒", x + 14, y + 210, w - 28, "center")
    else
        color(rc, 0.88)
        love.graphics.printf("构筑强化", x + 14, y + 174, w - 28, "center")
        color(C.muted)
        love.graphics.printf("本局永久生效", x + 14, y + 198, w - 28, "center")
    end

    local buyY = y + h - 74
    color(affordable and C.gold or C.red, 0.16)
    love.graphics.rectangle("fill", x + 16, buyY, w - 32, 34, 10, 10)
    color(affordable and C.gold or C.red, 0.55)
    love.graphics.rectangle("line", x + 16, buyY, w - 32, 34, 10, 10)
    love.graphics.setFont(Game.fonts.small)
    centeredText("晶币 " .. item.price .. "  ·  购买 " .. i, x + 16, buyY, w - 32, 34, Game.fonts.small, affordable and C.gold or C.red, "center")

    local lockY = y + h - 34
    color(Game.locked[i] and C.cyan or C.white, Game.locked[i] and 0.18 or 0.07)
    love.graphics.rectangle("fill", x + 16, lockY, w - 32, 28, 9, 9)
    color(Game.locked[i] and C.cyan or C.muted)
    love.graphics.rectangle("line", x + 16, lockY, w - 32, 28, 9, 9)
    centeredText(Game.locked[i] and "已锁定" or "点按锁定", x + 16, lockY, w - 32, 28, Game.fonts.tiny, Game.locked[i] and C.cyan or C.muted, "center")

    if not affordable then
        love.graphics.setColor(0, 0, 0, 0.34)
        love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    end
end

local function drawBuildPanel(x, y, w, h)
    local p = Game.player
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("当前构筑", x, y + 14, w, "center")

    love.graphics.setFont(Game.fonts.tiny)
    local rows = {
        {"伤害", pct(p.stats.damage)}, {"射速", pct(p.stats.fireRate)}, {"暴击", pct(p.stats.crit)},
        {"护甲", p.stats.armor}, {"闪避", pct(p.stats.dodge)}, {"吸血", pct(p.stats.lifesteal)},
        {"工程", p.stats.engineering}, {"收获", p.stats.harvest}, {"幸运", p.stats.luck}
    }
    for i, row in ipairs(rows) do
        local rowY = y + 42 + (i - 1) * 22
        local rowH = 18
        color(C.white, 0.08)
        love.graphics.rectangle("fill", x + 14, rowY, w - 28, rowH, 7, 7)
        centeredText(row[1], x + 26, rowY, 76, rowH, Game.fonts.tiny, C.muted, "left")
        centeredText(tostring(row[2]), x + 104, rowY, w - 138, rowH, Game.fonts.tiny, C.white, "right")
    end

    local wy = y + h - 58
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, wy - 12, w - 28, 1)
    color(C.gold)
    love.graphics.printf("武器", x, wy, w, "center")
    color(C.muted)
    local names = {}
    for i, weapon in ipairs(p.weapons) do
        names[#names + 1] = weapon.name .. " 等级" .. weapon.level
        if i >= 6 then break end
    end
    love.graphics.printf(table.concat(names, " / "), x + 16, wy + 22, w - 32, "center")
end

local function drawShop()
    panel(54, 78, Game.w - 108, Game.h - 100)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    local clearedWave = math.max(1, Game.wave - 1)
    love.graphics.printf("商店 / 第 " .. clearedWave .. " 波战后补给", 70, 102, Game.w - 140, "center")
    love.graphics.setFont(Game.fonts.small)
    local rerollCost = 3 + Game.shopRefresh * 2
    local refreshText = Game.freeRefresh > 0 and ("免费刷新 " .. Game.freeRefresh .. " 次") or ("刷新 " .. rerollCost .. " 晶币")
    color(C.gold)
    love.graphics.printf("武器槽 " .. #Game.player.weapons .. "/6  ·  " .. refreshText .. "  ·  回车下一波", 70, 150, Game.w - 140, "center")
    color(C.muted)
    love.graphics.printf("1-4 购买/合成  ·  点按锁定  ·  Shift+R 刷新  ·  E 回收最后武器", 70, 176, Game.w - 140, "center")

    local sideW = 292
    local cardY = 226
    local cardW = (Game.w - 190 - sideW) / 4
    for i, item in ipairs(Game.shop) do
        local x = 72 + (i - 1) * (cardW + 10)
        drawShopCard(item, i, x, cardY, cardW, 325)
    end

    drawBuildPanel(Game.w - 72 - sideW, cardY, sideW, 325)
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
    love.graphics.printf("波次 " .. Game.wave .. "   击杀 " .. Game.kills .. "   晶币 " .. Game.coins, Game.w / 2 - 300, 355, 600, "center")
    color(C.cyan)
    love.graphics.printf("总伤害 " .. math.floor(Game.runStats.damage or 0) .. "   收入 " .. math.floor(Game.runStats.coinsEarned or 0) .. "   危险 " .. Game.danger, Game.w / 2 - 300, 388, 600, "center")
    color(C.muted)
    love.graphics.printf("回车回到选择界面 / Esc 退出", Game.w / 2 - 300, 425, 600, "center")
end

function love.draw()
    local ox, oy = 0, 0
    if Game.shake > 0 then ox, oy = rnd(-5, 5) * Game.shake * 3, rnd(-5, 5) * Game.shake * 3 end
    love.graphics.push()
    love.graphics.translate(ox, oy)
    drawBackground()
    if Game.state == "menu" then drawMenu(); love.graphics.pop(); return end
    if Game.state == "shop" then drawShop(); love.graphics.pop(); return end
    if Game.state == "levelup" then drawWorld(); drawHud(); drawLevelUp(); love.graphics.pop(); return end
    drawWorld()
    drawHud()
    if Game.messageTimer > 0 then
        local toastY = 132
        panel(Game.w / 2 - 260, toastY, 520, 40)
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf(Game.message, Game.w / 2 - 250, toastY + 11, 500, "center")
    end
    if Game.state == "gameover" then drawEnd("心核破碎", "构筑失败。虚空可没那么温柔。", C.red) end
    if Game.state == "victory" then drawEnd("通关完成", "心核稳定，虚空退潮。", C.gold) end
    love.graphics.pop()
end

local function buySlot(i)
    local item = Game.shop[i]
    if not item then return end
    if Game.coins < item.price then toast("晶币不足") return end
    local ok = true
    if item.buy then ok = item.buy() ~= false end
    if not ok then return end
    Game.coins = Game.coins - item.price
    Game.shop[i] = randomShopItem()
    Game.locked[i] = false
end

local function recycleWeapon()
    local p = Game.player
    local w = table.remove(p.weapons)
    if not w then toast("没有可回收武器") return end
    local value = math.max(8, math.floor((w.price or 20) * 0.45 + (w.level or 1) * 4))
    Game.coins = Game.coins + value
    toast("回收 " .. w.name .. "：+" .. value .. " 晶币")
end

function love.mousepressed(x, y, button)
    if button == 1 and Game.state == "shop" then
        local sideW = 282
        local cardY = 234
        local cardW = (Game.w - 190 - sideW) / 4
        for i = 1, 4 do
            local cardX = 72 + (i - 1) * (cardW + 10)
            if x >= cardX and x <= cardX + cardW and y >= cardY and y <= cardY + 285 then
                Game.locked[i] = not Game.locked[i]
                toast(Game.locked[i] and "已锁定商品" or "已取消锁定")
                return
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end

    if Game.state == "menu" then
        if key == "1" or key == "2" or key == "3" or key == "4" then Game.selectedCharacter = tonumber(key); return end
        if key == "a" or key == "left" then Game.selectedObjective = Game.selectedObjective - 1; if Game.selectedObjective < 1 then Game.selectedObjective = #objectiveDefs end; return end
        if key == "d" or key == "right" then Game.selectedObjective = Game.selectedObjective + 1; if Game.selectedObjective > #objectiveDefs then Game.selectedObjective = 1 end; return end
        if key == "q" then Game.danger = math.max(0, Game.danger - 1); return end
        if key == "e" then Game.danger = math.min(6, Game.danger + 1); return end
    end

    if Game.state == "levelup" then
        if key == "1" then chooseLevelReward(1) end
        if key == "2" then chooseLevelReward(2) end
        if key == "3" then chooseLevelReward(3) end
        return
    end

    if key == "return" or key == "kpenter" then
        if Game.state == "menu" then resetRun()
        elseif Game.state == "gameover" or Game.state == "victory" then Game.state = "menu"
        elseif Game.state == "shop" then startWave() end
    end
    if Game.state == "shop" then
        if key == "1" then buySlot(1) end
        if key == "2" then buySlot(2) end
        if key == "3" then buySlot(3) end
        if key == "4" then buySlot(4) end
        if key == "e" then recycleWeapon() end
        if key == "r" then
            if not (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then toast("刷新需按 Shift+R，避免误触"); return end
            if Game.freeRefresh and Game.freeRefresh > 0 then
                Game.freeRefresh = Game.freeRefresh - 1
                rollShop(true)
                toast("免费刷新")
                return
            end
            local cost = 3 + Game.shopRefresh * 2
            if Game.coins >= cost then Game.coins = Game.coins - cost; Game.shopRefresh = Game.shopRefresh + 1; Game.runStats.rerolls = (Game.runStats.rerolls or 0) + 1; rollShop(true); toast("商店已刷新") else toast("晶币不足，无法刷新") end
        end
    end
end
