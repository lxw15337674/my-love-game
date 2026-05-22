-- main.lua
-- Robot War prototype
-- LOVE 11.x arena roguelite inspired by short-wave survivor games and loot-driven builds.

local VERSION = "v2026.05.22.18"
local VIRTUAL_W, VIRTUAL_H = 1920, 1080
local ACTIVE_SKILL_CD = 3.0
local ACTIVE_SKILL_DURATION = 0.5
local ACTIVE_SKILL_SPEED_MULT = 2.1

local Game = {
    w = VIRTUAL_W,
    h = VIRTUAL_H,
    state = "menu", -- menu, playing, paused, levelup, shop, gameover, victory
    time = 0,
    wave = 1,
    waveTime = 30,
    maxWave = 10,
    coins = 0,
    kills = 0,
    shopRefresh = 0,
    shop = {},
    locked = {},
    tempBuffs = {},
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
    selectedObjective = 1,
    danger = 0,
    freeRefresh = 1,
    slotFreeUsed = {},
    slotPaidSpins = 0,
    slotResult = nil,
    shopTab = "shop",
    buildPanelTab = "stats",
    hoveredShopItem = nil,
    selectedWeaponIndex = 1,
    shopRollTimer = 0,
    shopGhost = nil,
    levelChoices = {},
    pendingRewardNextState = nil,
    objectiveProgress = 0,
    objectiveText = "",
    waveRewards = nil,
    enemyShots = {},
    fireZones = {},
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
        activeSkill = {name = "推进冲刺", cd = 0, cooldown = ACTIVE_SKILL_CD, duration = 0, maxDuration = ACTIVE_SKILL_DURATION, speedMult = ACTIVE_SKILL_SPEED_MULT, dirX = 0, dirY = -1},
        stats = {
            damage = 1.00,
            fireRate = 1.00,
            crit = 0.06,
            critDamage = 1.65,
            range = 1.00,
            projectileSpeed = 1.00,
            bounce = 0,
            luck = 0,
            armor = 0,
            dodge = 0.03,
            lifesteal = 0,
            harvest = 0,
            elementChance = 0,
            elementDamage = 1.00,
            shieldDamage = 1.00,
            armorDamage = 1.00,
            fleshDamage = 1.00,
            explosiveDamage = 1.00,
            lowHpDamage = 0,
            economy = 1.00,
            rarityLuck = 0
        },
        weapons = {},
        items = {},
        shieldItem = nil,
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
    {name = "结算戒环", kind = "item", rarity = "common", price = 14, desc = "结算材料 +10%，幸运 +1", apply = function(p) p.stats.economy = p.stats.economy + 0.10; p.stats.luck = p.stats.luck + 1 end},
    {name = "轻型心壳", kind = "shield", rarity = "rare", price = 24, desc = "护盾 +20，移速 +8%", apply = function(p) p.maxShield = p.maxShield + 20; p.shield = p.shield + 20; p.speed = p.speed + 20 end},
    {name = "重型心甲", kind = "shield", rarity = "rare", price = 24, desc = "生命 +30，移速 -5%", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = p.hp + 30; p.speed = p.speed - 13 end},
    {name = "弹射棱镜", kind = "mod", rarity = "epic", price = 42, desc = "弹射 +1，射程 +8%", apply = function(p) p.stats.bounce = p.stats.bounce + 1; p.stats.range = p.stats.range + 0.08 end},
    {name = "超导弹芯", kind = "mod", rarity = "epic", price = 44, desc = "弹速 +12%，元素伤害 +10%", apply = function(p) p.stats.projectileSpeed = p.stats.projectileSpeed + 0.12; p.stats.elementDamage = p.stats.elementDamage + 0.10 end},
    {name = "修补凝胶", kind = "item", rarity = "common", price = 16, desc = "最大生命 +18，立即治疗 25", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 25) end},
    {name = "材料回收器", kind = "relic", rarity = "epic", price = 48, desc = "结算材料 +18%，射速 +5%", apply = function(p) p.stats.economy = p.stats.economy + 0.18; p.stats.fireRate = p.stats.fireRate + 0.05 end},
    {name = "别眨眼", kind = "legend", rarity = "legend", price = 64, desc = "暴击击杀后，下一击必定暴击", flag = "blink", apply = function(p) p.gear.blink = true end},
    {name = "善意有价", kind = "legend", rarity = "legend", price = 68, desc = "护盾破裂释放脉冲，但回复更慢", flag = "shieldBurst", apply = function(p) p.gear.shieldBurst = true; p.shieldRegen = p.shieldRegen - 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", price = 66, desc = "弹射 +2，伤害 -6%", flag = "endlessEcho", apply = function(p) p.stats.bounce = p.stats.bounce + 2; p.stats.damage = p.stats.damage - 0.06 end},
    {name = "陶瓷装甲片", kind = "shield", rarity = "common", price = 18, desc = "护甲 +2，移速 -2%", apply = function(p) p.stats.armor = p.stats.armor + 2; p.speed = p.speed - 5 end},
    {name = "神经闪避器", kind = "mod", rarity = "rare", price = 26, desc = "闪避 +7%，生命 -8", apply = function(p) p.stats.dodge = p.stats.dodge + 0.07; p.maxHp = p.maxHp - 8; p.hp = math.min(p.hp, p.maxHp) end},
    {name = "虹吸针管", kind = "relic", rarity = "rare", price = 30, desc = "生命偷取 +3%，暴击 -2%", apply = function(p) p.stats.lifesteal = p.stats.lifesteal + 0.03; p.stats.crit = p.stats.crit - 0.02 end},
    {name = "自动索敌芯片", kind = "relic", rarity = "epic", price = 46, desc = "电弧伤害 +18%，弹射 +1", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.18; p.stats.bounce = p.stats.bounce + 1 end},
    {name = "收获协议", kind = "relic", rarity = "epic", price = 44, desc = "收获 +4：战后额外材料", apply = function(p) p.stats.harvest = p.stats.harvest + 4 end},
    {name = "幸运电容", kind = "legend", rarity = "legend", price = 70, desc = "幸运 +6，闪避 +8%，护甲 -2", apply = function(p) p.stats.luck = p.stats.luck + 6; p.stats.dodge = p.stats.dodge + 0.08; p.stats.armor = p.stats.armor - 2 end}
}

local tempItemPool = {
    {name = "兴奋剂针剂", kind = "temp", rarity = "common", price = 12, desc = "下一波伤害 +18%", buff = {damage = 0.18}},
    {name = "战术电池", kind = "temp", rarity = "common", price = 12, desc = "下一波护盾上限 +25，开局满盾", buff = {shield = 25}},
    {name = "赏金合约", kind = "temp", rarity = "rare", price = 18, desc = "下一波结算材料 +30%", buff = {economy = 0.30}},
    {name = "低温弹匣", kind = "temp", rarity = "rare", price = 20, desc = "下一波子弹附带霜冻概率", buff = {elementChance = 0.18, element = "ice"}},
    {name = "腐蚀涂层", kind = "temp", rarity = "rare", price = 20, desc = "下一波对护甲 +35%", buff = {armorDamage = 0.35}},
    {name = "过载保险", kind = "temp", rarity = "epic", price = 30, desc = "下一波射速 +22%，护盾回复 -20%", buff = {fireRate = 0.22, shieldRegenMult = -0.20}}
}

local enemyDefs = {
    drifter = {name = "漂移噪声", sprite = "enemy_drifter", defense = "flesh", hp = 18, speed = 78, damage = 9, r = 14, color = C.red, xp = 3, coin = 2, behavior = "chase"},
    splinter = {name = "裂片", sprite = "enemy_splinter", defense = "flesh", hp = 12, speed = 130, damage = 7, r = 10, color = C.orange, xp = 2, coin = 1, behavior = "charger"},
    shell = {name = "壳层记忆", sprite = "enemy_shell", defense = "armor", hp = 44, speed = 50, damage = 13, r = 20, color = C.green, armor = 3, xp = 5, coin = 4, behavior = "guard"},
    wisp = {name = "电弧游魂", sprite = "enemy_wisp", defense = "shield", hp = 18, shield = 26, shieldRegen = 2.2, speed = 105, damage = 8, r = 13, color = C.cyan, xp = 4, coin = 3, behavior = "shooter"},
    elite = {name = "坏蛋精英", sprite = "enemy_elite", defense = "shield", hp = 150, shield = 90, shieldRegen = 3.0, speed = 64, damage = 18, r = 28, color = C.purple, armor = 2, xp = 16, coin = 12, elite = true, behavior = "aura"},
    treasure = {name = "宝藏信标", sprite = "pickup_coin", defense = "flesh", hp = 32, speed = 112, damage = 0, r = 16, color = C.gold, xp = 1, coin = 5, treasureCoin = 18, treasure = true, behavior = "treasure"},
    bomber = {name = "燃烧投手", sprite = "enemy_splinter", defense = "flesh", hp = 38, speed = 72, damage = 10, r = 15, color = C.orange, xp = 4, coin = 4, behavior = "bomber"},
    boss = {name = "裂心机核", sprite = "boss_heartbreak", defense = "armor", hp = 2800, shield = 850, shieldRegen = 4.0, speed = 44, damage = 24, r = 46, color = C.pink, armor = 5, xp = 80, coin = 60, boss = true, behavior = "boss"}
}

local wavePlans = {
    {name = "裂片试探", duration = 30, interval = 1.10, pack = 1, sides = {"left", "right"}, enemies = {{"splinter", 70}, {"drifter", 30}}},
    {name = "双翼骚扰", duration = 30, interval = 1.02, pack = 2, sides = {"left", "right", "top"}, enemies = {{"splinter", 50}, {"drifter", 37}, {"wisp", 10}, {"treasure", 3}}},
    {name = "电弧乱流", duration = 32, interval = 0.92, pack = 2, sides = {"top", "right", "left"}, enemies = {{"splinter", 38}, {"drifter", 28}, {"wisp", 28}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 18, enemy = "elite", side = "right", toast = "精英信号：右侧突破"}}},
    {name = "装甲推进", duration = 32, interval = 0.88, pack = 2, sides = {"left", "right", "bottom"}, enemies = {{"splinter", 30}, {"drifter", 26}, {"wisp", 18}, {"shell", 20}, {"bomber", 3}, {"treasure", 3}}},
    {name = "交叉包围", duration = 34, interval = 0.80, pack = 3, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 28}, {"drifter", 28}, {"wisp", 23}, {"shell", 15}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 12, enemy = "elite", side = "left", toast = "精英压境：左侧"}}},
    {name = "重壳浪潮", duration = 34, interval = 0.78, pack = 3, sides = {"right", "bottom", "top"}, enemies = {{"drifter", 23}, {"wisp", 23}, {"shell", 36}, {"splinter", 12}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 22, enemy = "elite", side = "bottom", toast = "底线精英出现"}}},
    {name = "高速撕裂", duration = 36, interval = 0.70, pack = 3, sides = {"left", "right"}, enemies = {{"splinter", 39}, {"drifter", 36}, {"wisp", 12}, {"shell", 7}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 16, enemy = "elite", side = "right"}}},
    {name = "四面噪声", duration = 36, interval = 0.64, pack = 4, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 26}, {"drifter", 26}, {"wisp", 24}, {"shell", 18}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 10, enemy = "elite", side = "top"}, {time = 25, enemy = "elite", side = "bottom"}}},
    {name = "核心前夜", duration = 38, interval = 0.58, pack = 4, sides = {"right", "left", "top", "bottom"}, enemies = {{"splinter", 22}, {"drifter", 26}, {"wisp", 26}, {"shell", 20}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 9, enemy = "elite", side = "left"}, {time = 21, enemy = "elite", side = "right"}}},
    {name = "裂心机核", duration = 60, interval = 0.95, pack = 2, sides = {"left", "right", "top", "bottom"}, boss = true, enemies = {{"splinter", 26}, {"drifter", 24}, {"wisp", 24}, {"shell", 20}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 0.2, enemy = "boss", side = "right", toast = "Boss：裂心机核接入"}, {time = 20, enemy = "elite", side = "left"}, {time = 40, enemy = "elite", side = "right"}}}
}

local function wavePlanAt(wave)
    return wavePlans[wave] or wavePlans[#wavePlans]
end

local function currentWavePlan()
    return wavePlanAt(Game.wave)
end
local affixDefs = {
    bounty = {name = "赏金", kind = "reward", desc = "材料 +25%", coinMult = 1.25},
    overcharge = {name = "过载", kind = "reward", desc = "伤害 +10%", playerDamage = 1.10},
    magnet = {name = "磁场", kind = "reward", desc = "材料 +15%", coinMult = 1.15},
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

local function affixesAt(wave)
    local pair = waveAffixes[wave] or waveAffixes[#waveAffixes] or {}
    return affixDefs[pair.reward], affixDefs[pair.penalty]
end

local function currentAffixes()
    return affixesAt(Game.wave)
end

local function currentAffixBonuses()
    local bonus = {
        coinMult = 1, playerDamage = 1, critBonus = 0,
        shieldRegenMult = 1, enemyHp = 1, enemySpeed = 1, enemyDamage = 1, enemyArmor = 0,
        extraPack = 0, intervalMult = 1
    }
    local reward, penalty = currentAffixes()
    for _, affix in ipairs({reward, penalty}) do
        if affix then
            bonus.coinMult = bonus.coinMult * (affix.coinMult or 1)
            bonus.playerDamage = bonus.playerDamage * (affix.playerDamage or 1)
            bonus.critBonus = bonus.critBonus + (affix.critBonus or 0)
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

local function affixDetailLines(affix)
    local lines = {affix.desc or "下一波生效"}
    if affix.coinMult then lines[#lines + 1] = "材料获取倍率 ×" .. string.format("%.2f", affix.coinMult) end
    if affix.playerDamage then lines[#lines + 1] = "玩家伤害倍率 ×" .. string.format("%.2f", affix.playerDamage) end
    if affix.critBonus then lines[#lines + 1] = "暴击率 +" .. string.format("%d%%", math.floor(affix.critBonus * 100 + 0.5)) end
    if affix.shieldRegenMult then lines[#lines + 1] = "护盾回复倍率 ×" .. string.format("%.2f", affix.shieldRegenMult) end
    if affix.enemyHp then lines[#lines + 1] = "敌人生命倍率 ×" .. string.format("%.2f", affix.enemyHp) end
    if affix.enemySpeed then lines[#lines + 1] = "敌人速度倍率 ×" .. string.format("%.2f", affix.enemySpeed) end
    if affix.enemyDamage then lines[#lines + 1] = "敌人伤害倍率 ×" .. string.format("%.2f", affix.enemyDamage) end
    if affix.enemyArmor then lines[#lines + 1] = "敌人护甲 +" .. affix.enemyArmor end
    if affix.extraPack then lines[#lines + 1] = "每轮刷怪数量 +" .. affix.extraPack end
    if affix.intervalMult then lines[#lines + 1] = "刷怪间隔倍率 ×" .. string.format("%.2f", affix.intervalMult) end
    lines[#lines + 1] = "只影响下一波，用来决定商店购买。"
    return lines
end

local basePlayerDef = {
    name = "机体白板",
    weapon = "needle",
    desc = "没有固定职业。每关奖励会把你污染成不同怪物。",
    hp = 76,
    shield = 36,
    speed = 250,
    coins = 18,
    stats = {
        damage = 1.00, fireRate = 1.00, crit = 0.06, critDamage = 1.65,
        range = 1.00, projectileSpeed = 1.00, bounce = 0,
        luck = 0, armor = 0, dodge = 0.03, lifesteal = 0, harvest = 0,
        elementChance = 0, elementDamage = 1.00, shieldDamage = 1.00, armorDamage = 1.00,
        fleshDamage = 1.00, explosiveDamage = 1.00, lowHpDamage = 0,
        economy = 1.00, rarityLuck = 0
    }
}

local characterDefs = {basePlayerDef}

local SURVIVAL_DURATION = 30

local objectiveDefs = {
    {name = "生存模式", desc = "生存 30 秒，撑到计时结束", mode = "survive"}
}

local levelRewardPool = {
    {name = "白板校准", kind = "item", rarity = "common", family = "基础", desc = "伤害 +8%", apply = function(p) p.stats.damage = p.stats.damage + 0.08 end},
    {name = "脉冲节拍", kind = "item", rarity = "common", family = "基础", desc = "射速 +10%", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.10 end},
    {name = "生命扩容", kind = "shield", rarity = "common", family = "生存", desc = "最大生命 +18，治疗 12", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 12) end},
    {name = "护盾增幅", kind = "shield", rarity = "common", family = "护盾", desc = "最大护盾 +16，回复 +1", apply = function(p) p.maxShield = p.maxShield + 16; p.shield = p.shield + 16; p.shieldRegen = p.shieldRegen + 1 end},
    {name = "陶瓷叠甲", kind = "shield", rarity = "common", family = "护甲", desc = "护甲 +2", apply = function(p) p.stats.armor = p.stats.armor + 2 end},
    {name = "闪避步态", kind = "mod", rarity = "common", family = "生存", desc = "闪避 +5%", apply = function(p) p.stats.dodge = p.stats.dodge + 0.05 end},
    {name = "暴击透镜", kind = "mod", rarity = "rare", family = "暴击", desc = "暴击率 +6%，暴伤 +10%", apply = function(p) p.stats.crit = p.stats.crit + 0.06; p.stats.critDamage = p.stats.critDamage + 0.10 end},
    {name = "弱点猎杀", kind = "mod", rarity = "epic", family = "暴击", desc = "暴击率 +4%，暴击击杀使下一击必暴", flag = "blink", apply = function(p) p.stats.crit = p.stats.crit + 0.04; p.gear.blink = true end},
    {name = "射程校准", kind = "mod", rarity = "rare", family = "武器", desc = "射程 +12%，弹速 +8%", apply = function(p) p.stats.range = p.stats.range + 0.12; p.stats.projectileSpeed = p.stats.projectileSpeed + 0.08 end},
    {name = "回声预案", kind = "mod", rarity = "rare", family = "武器", desc = "弹射 +1，电弧伤害 +8%", apply = function(p) p.stats.bounce = p.stats.bounce + 1; p.stats.elementDamage = p.stats.elementDamage + 0.08 end},
    {name = "燃烧弹芯", kind = "item", rarity = "rare", family = "元素", desc = "元素伤害 +12%，对红血 +15%", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.12; p.stats.fleshDamage = p.stats.fleshDamage + 0.15 end},
    {name = "电击电容", kind = "item", rarity = "rare", family = "元素", desc = "对护盾 +25%，护盾破裂释放电弧", flag = "shieldBurst", apply = function(p) p.stats.shieldDamage = p.stats.shieldDamage + 0.25; p.gear.shieldBurst = true end},
    {name = "腐蚀针剂", kind = "item", rarity = "rare", family = "元素", desc = "对护甲 +25%，腐蚀叠层上限提高", apply = function(p) p.stats.armorDamage = p.stats.armorDamage + 0.25; p.gear.deepCorrode = true end},
    {name = "冰裂准星", kind = "mod", rarity = "epic", family = "元素", desc = "冻结/减速目标更容易被暴击", apply = function(p) p.gear.freezeCrit = true; p.stats.crit = p.stats.crit + 0.03 end},
    {name = "爆炸协议", kind = "mod", rarity = "epic", family = "爆炸", desc = "爆炸伤害 +22%，击杀小范围爆裂", apply = function(p) p.stats.explosiveDamage = p.stats.explosiveDamage + 0.22; p.gear.killBurst = true end},
    {name = "追踪电弧", kind = "relic", rarity = "epic", family = "元素", desc = "电弧命中后周期追踪", apply = function(p) p.gear.autoArc = true; p.stats.bounce = p.stats.bounce + 1; p.stats.elementDamage = p.stats.elementDamage + 0.10 end},
    {name = "护盾回流", kind = "relic", rarity = "epic", family = "护盾", desc = "击杀回复护盾，满盾时伤害 +8%", apply = function(p) p.gear.killShield = true; p.gear.fullShieldDamage = true end},
    {name = "血线狂热", kind = "relic", rarity = "epic", family = "低血", desc = "生命越低伤害越高，吸血 +2%", apply = function(p) p.stats.lowHpDamage = p.stats.lowHpDamage + 0.45; p.stats.lifesteal = p.stats.lifesteal + 0.02 end},
    {name = "收获协议", kind = "relic", rarity = "rare", family = "经济", desc = "关卡结算材料 +15%，收获 +3", apply = function(p) p.stats.economy = p.stats.economy + 0.15; p.stats.harvest = p.stats.harvest + 3 end},
    {name = "赏金猎犬", kind = "legend", rarity = "legend", family = "经济", desc = "奖励稀有度提高，商店免费刷新 +1", apply = function(p) p.stats.rarityLuck = p.stats.rarityLuck + 2; Game.freeRefresh = Game.freeRefresh + 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", family = "武器", desc = "弹射 +2，伤害 -5%", flag = "endlessEcho", apply = function(p) p.stats.bounce = p.stats.bounce + 2; p.stats.damage = p.stats.damage - 0.05 end},
    {name = "腐蚀瘟疫", kind = "legend", rarity = "legend", family = "元素", desc = "腐蚀击杀会向附近敌人扩散", apply = function(p) p.gear.corrosionSpread = true; p.stats.armorDamage = p.stats.armorDamage + 0.15 end},
    {name = "坏心眼弹匣", kind = "legend", rarity = "legend", family = "暴击", desc = "暴击击杀触发弹射爆裂", apply = function(p) p.gear.critRicochet = true; p.stats.critDamage = p.stats.critDamage + 0.18 end}
}

local function selectedCharacter() return basePlayerDef end
local function selectedObjective() return objectiveDefs[Game.selectedObjective] or objectiveDefs[1] end

local rarityColor = {
    common = {0.82, 0.86, 0.94},
    rare = {0.25, 0.66, 1.00},
    epic = {0.74, 0.40, 1.00},
    legend = {1.00, 0.62, 0.16}
}

local rarityLabel = {common = "普通", rare = "稀有", epic = "史诗", legend = "传说"}
local kindLabel = {weapon = "武器", item = "强化", shield = "护盾", mod = "模组", relic = "遗物", legend = "传说", temp = "战术"}
local rarityPower = {common = 1.00, rare = 1.18, epic = 1.42, legend = 1.78}
local rarityAffixes = {common = 1, rare = 2, epic = 3, legend = 4}

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

local function randf(lo, hi)
    return lo + rnd() * (hi - lo)
end

local function rollRarity(luck)
    luck = luck or 0
    local r = rnd()
    local legend = 0.045 + luck * 0.008
    local epic = 0.16 + luck * 0.014
    local rare = 0.36 + luck * 0.018
    if r < legend then return "legend" end
    if r < legend + epic then return "epic" end
    if r < legend + epic + rare then return "rare" end
    return "common"
end

local function priced(base, rarity)
    return math.max(8, math.floor(base * (rarityPower[rarity] or 1) + 0.5))
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

local function loadSound(path, fallbackFreq, fallbackDuration, volume)
    if love.audio then
        local ok, src = pcall(love.audio.newSource, path, "static")
        if ok and src then
            src:setVolume(volume or 0.35)
            return src
        end
    end
    return makeTone(fallbackFreq, fallbackDuration, volume)
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
    local brand = b.brand or "starforge"
    local pulse = 0.5 + 0.5 * math.sin((Game.time or 0) * 10 + (b.x + b.y) * 0.015)
    love.graphics.push()
    love.graphics.translate(b.x, b.y)
    love.graphics.rotate(rot)

    -- 统一尾迹/外发光：高速战斗里弹体必须先被看见
    love.graphics.setBlendMode("add")
    color(b.color, brand == "swarm" and 0.22 or 0.30)
    love.graphics.rectangle("fill", brand == "starforge" and -54 or -40, -5, brand == "starforge" and 50 or 36, 10, 5, 5)
    color(b.color, 0.18 + pulse * 0.10)
    love.graphics.circle("fill", 0, 0, b.aura and (20 + pulse * 6) or (12 + pulse * 3))
    love.graphics.setBlendMode("alpha")

    if brand == "blackbox" or b.aura then
        love.graphics.setLineWidth(2)
        color(b.color, 0.42)
        love.graphics.circle("line", 0, 0, b.aura)
        color(b.color, 0.18 + pulse * 0.18)
        love.graphics.circle("line", 0, 0, 24 + pulse * 10)
        love.graphics.setLineWidth(1)
        color(b.color, 0.95)
        love.graphics.circle("fill", 0, 0, 10 + pulse * 3)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.circle("fill", -3, -3, 4)
    elseif brand == "molten" or b.splash then
        color(b.color, 0.92)
        love.graphics.circle("fill", 0, 0, 9 + pulse * 3)
        love.graphics.setColor(1, 0.92, 0.45, 0.88)
        love.graphics.circle("fill", 0, 0, 4)
        color(b.color, 0.35)
        love.graphics.circle("line", 0, 0, 14 + pulse * 8)
        love.graphics.setBlendMode("add")
        color(C.orange, 0.35)
        love.graphics.circle("fill", -15, 0, 4 + pulse * 3)
        love.graphics.setBlendMode("alpha")
    elseif brand == "echo" or b.element == "arc" then
        color(b.color, 0.95)
        love.graphics.setLineWidth(3)
        love.graphics.line(-14, -3, -4, 4, 4, -4, 14, 2)
        color(b.color, 0.42)
        love.graphics.polygon("line", -18, -9, 16, 0, -18, 9)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.line(-14, -3, -4, 4, 4, -4, 14, 2)
        love.graphics.setLineWidth(1)
    elseif brand == "swarm" then
        color(b.color, 0.92)
        love.graphics.polygon("fill", -12, -6, 12, 0, -12, 6)
        love.graphics.setBlendMode("add")
        color(C.green, 0.55)
        love.graphics.circle("fill", -18, 0, 5 + pulse * 2)
        love.graphics.setBlendMode("alpha")
    elseif brand == "starforge" then
        color(C.gold, 0.30)
        love.graphics.rectangle("fill", -42, -2, 48, 4, 2, 2)
        color(b.crit and C.gold or b.color, 1)
        love.graphics.polygon("fill", -18, -4, 18, 0, -18, 4)
        love.graphics.setColor(1, 1, 1, b.crit and 0.95 or 0.75)
        love.graphics.line(-20, 0, 18, 0)
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
    local shield = (def.shield or 0) * scale
    Game.enemies[#Game.enemies + 1] = {
        name = def.name, x = x, y = y, r = def.r,
        hp = hp, maxHp = hp, shield = shield, maxShield = shield, defense = def.defense or (shield > 0 and "shield" or ((def.armor or 0) > 0 and "armor" or "flesh")), shieldRegen = def.shieldRegen or 0,
        speed = (def.speed + Game.wave * 2) * bonus.enemySpeed * (1 + Game.danger * 0.025),
        damage = def.damage * bonus.enemyDamage * (1 + Game.danger * 0.06), armor = (def.armor or 0) + bonus.enemyArmor,
        color = def.color, xp = def.xp, coin = def.coin, treasureCoin = def.treasureCoin, sprite = def.sprite, behavior = def.behavior or "chase",
        elite = def.elite, boss = def.boss, treasure = def.treasure,
        shootTimer = rnd() * 1.2, dashTimer = rnd() * 1.6, wanderTimer = rnd() * 1.4, wanderAngle = rnd() * TAU,
        burn = 0, slow = 0, corrosion = 0, lastHit = 0
    }
end

local function spawnPack(plan)
    plan = plan or currentWavePlan()
    local side = pickSpawnSide(plan)
    local bonus = currentAffixBonuses()
    local pack = (plan.pack or 1) + bonus.extraPack
    for _ = 1, pack do spawnEnemy(weightedEnemy(plan), {side = side}) end
end

local function nearestEnemy(x, y, range)
    local best, bestD = nil, range or 999999
    for _, e in ipairs(Game.enemies) do
        local d = distance(x, y, e.x, e.y)
        if d < bestD then best, bestD = e, d end
    end
    return best, bestD
end

local rebuildPlayerBuildStats

local function applyItem(item)
    item.apply(Game.player)
    Game.player.items = Game.player.items or {}
    Game.player.items[#Game.player.items + 1] = item
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
    if #p.weapons >= 4 then
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

local function applyShieldStats(p, item)
    p.maxShield = p.maxShield + (item.shieldCap or 0)
    p.shield = math.min(p.maxShield, p.shield + (item.shieldCap or 0))
    p.shieldRegen = p.shieldRegen + (item.shieldRegen or 0)
    p.stats.armor = p.stats.armor + (item.armor or 0)
    p.maxHp = p.maxHp + (item.hp or 0)
    p.hp = math.min(p.maxHp, p.hp + (item.hp or 0))
    if item.flag then p.gear[item.flag] = true end
end

local function equipShield(item)
    local p = Game.player
    local oldHp, oldShield = p.hp, p.shield
    p.shieldItem = item
    rebuildPlayerBuildStats()
    p.hp = math.min(p.maxHp, oldHp + (item.hp or 0))
    p.shield = math.min(p.maxShield, oldShield + (item.shieldCap or 0))
    playCue("shop"); toast("护盾安装：" .. item.name)
    return true
end

local function addTempBuff(item)
    local buff = item.buff or {}
    Game.tempBuffs[#Game.tempBuffs + 1] = buff
    playCue("shop"); toast("战术道具已备好：" .. item.name)
    return true
end

rebuildPlayerBuildStats = function()
    local p = Game.player
    local ch = selectedCharacter()
    local hp, shield = p.hp, p.shield
    local weapons, items, shieldItem = p.weapons or {}, p.items or {}, p.shieldItem
    p.maxHp, p.maxShield = ch.hp, ch.shield
    p.shieldDelay, p.shieldRegen = p.shieldDelay or 0, 7
    p.speed, p.pickup = ch.speed, p.pickup or 0
    p.stats = {}
    for k, v in pairs(ch.stats) do p.stats[k] = v end
    p.gear = {}
    for _, weapon in ipairs(weapons) do
        if weapon.apply then weapon.apply(p) end
    end
    if shieldItem then applyShieldStats(p, shieldItem) end
    for _, item in ipairs(items) do
        if item.effects then
            for _, e in ipairs(item.effects) do e.roll.apply(p, e.value) end
        elseif item.apply then
            item.apply(p)
        end
        if item.flag then p.gear[item.flag] = true end
    end
    p.hp = math.min(math.max(1, hp), p.maxHp)
    p.shield = math.min(math.max(0, shield), p.maxShield)
end

local weaponAffixRolls = {
    {text = "高伤", apply = function(w, power) w.damage = math.floor(w.damage * (1.10 + power * 0.08) + 0.5) end},
    {text = "速射", apply = function(w, power) w.cooldown = w.cooldown / (1.08 + power * 0.05) end},
    {text = "远射", apply = function(w, power) w.range = w.range * (1.10 + power * 0.05) end},
    {text = "高速弹", apply = function(w, power) if w.speed > 0 then w.speed = w.speed * (1.12 + power * 0.06) end end},
    {text = "扩容", apply = function(w, power) if w.count and w.count < 7 then w.count = w.count + 1; w.spread = (w.spread or 0) + 0.06 end end},
    {text = "弹射", apply = function(w, power) w.bounce = (w.bounce or 0) + 1 end},
    {text = "爆裂", apply = function(w, power) w.splash = (w.splash or 0) + 22 + math.floor(power * 10) end},
    {text = "连锁", apply = function(w, power) w.chain = (w.chain or 0) > 0 and (w.chain + 1) or w.chain end}
}

local function makeWeaponItem(id)
    local base = weaponDefs[id]
    local rarity = rollRarity(Game.player.stats.luck + (Game.player.stats.rarityLuck or 0))
    local power = rarityPower[rarity] or 1
    local def = {}
    for k, v in pairs(base) do def[k] = v end
    def.rolled = true
    def.damage = math.max(1, math.floor(def.damage * randf(0.84, 1.22) * power + 0.5))
    def.cooldown = math.max(0.16, def.cooldown / randf(0.88, 1.12))
    def.range = def.range * randf(0.90, 1.14)
    if def.speed > 0 then def.speed = def.speed * randf(0.88, 1.18) end
    local tags = {}
    for _ = 1, rarityAffixes[rarity] or 1 do
        local affix = weaponAffixRolls[rnd(1, #weaponAffixRolls)]
        affix.apply(def, power)
        tags[#tags + 1] = affix.text
    end
    local brand = brands[def.brand]
    local elem = elements[def.element]
    def.name = (rarityLabel[rarity] or rarity) .. " " .. base.name
    def.price = priced(base.price or 24, rarity)
    local item = {kind = "weapon", id = id, name = def.name, price = def.price, rarity = rarity, desc = brand.name .. " / " .. elem.name .. " / " .. table.concat(tags, "、"), weaponDef = def}
    item.buy = function() return addWeapon(def) end
    return item
end

local function cloneItem(src)
    local item = {}
    for k, v in pairs(src) do item[k] = v end
    if item.kind == "temp" then
        item.buy = function() return addTempBuff(item) end
    elseif item.kind == "shield" then
        item.buy = function() return equipShield(item) end
    else
        item.buy = function() applyItem(item) end
    end
    return item
end

local statRolls = {
    {label = "伤害", desc = function(v) return "伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.damage = p.stats.damage + v end},
    {label = "射速", desc = function(v) return "射速 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.fireRate = p.stats.fireRate + v end},
    {label = "暴击", desc = function(v) return "暴击率 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.crit = p.stats.crit + v end},
    {label = "暴伤", desc = function(v) return "暴击伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.critDamage = p.stats.critDamage + v end},
    {label = "元素", desc = function(v) return "元素伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.elementDamage = p.stats.elementDamage + v end},
    {label = "经济", desc = function(v) return "结算材料 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.economy = p.stats.economy + v end},
    {label = "生命", desc = function(v) return "最大生命 +" .. math.floor(v) end, apply = function(p, v) p.maxHp = p.maxHp + math.floor(v); p.hp = math.min(p.maxHp, p.hp + math.floor(v * 0.5)) end},
    {label = "护甲", desc = function(v) return "护甲 +" .. math.floor(v) end, apply = function(p, v) p.stats.armor = p.stats.armor + math.floor(v) end}
}

local function makeStatItem()
    local rarity = rollRarity(Game.player.stats.luck + (Game.player.stats.rarityLuck or 0))
    local power = rarityPower[rarity] or 1
    local count = math.min(3, rarityAffixes[rarity] or 1)
    local effects, desc = {}, {}
    for _ = 1, count do
        local roll = statRolls[rnd(1, #statRolls)]
        local value = roll.label == "生命" and randf(12, 24) * power or (roll.label == "护甲" and randf(1, 2.4) * power or randf(0.05, 0.12) * power)
        effects[#effects + 1] = {roll = roll, value = value}
        desc[#desc + 1] = roll.desc(value)
    end
    local item = {kind = rarity == "legend" and "legend" or "item", rarity = rarity, name = (rarityLabel[rarity] or rarity) .. " 构筑芯片", price = priced(18 + count * 8, rarity), desc = table.concat(desc, " / "), effects = effects}
    item.buy = function()
        for _, e in ipairs(effects) do e.roll.apply(Game.player, e.value) end
        Game.player.items = Game.player.items or {}
        Game.player.items[#Game.player.items + 1] = item
        playCue("shop"); toast("获得：" .. item.name)
        return true
    end
    return item
end

local function makeShieldItem()
    local rarity = rollRarity(Game.player.stats.luck + (Game.player.stats.rarityLuck or 0))
    local power = rarityPower[rarity] or 1
    local cap = math.floor(randf(18, 38) * power)
    local regen = randf(0.8, 2.0) * power
    local armor = rarity == "common" and 0 or math.floor(randf(1, 2.8) * power)
    local flags = {"shieldBurst", "killShield", "fullShieldDamage"}
    local flag = (rarity == "epic" or rarity == "legend") and flags[rnd(1, #flags)] or nil
    local special = flag == "shieldBurst" and "破盾脉冲" or (flag == "killShield" and "击杀回盾" or (flag == "fullShieldDamage" and "满盾增伤" or "稳定护盾"))
    local item = {kind = "shield", rarity = rarity, name = (rarityLabel[rarity] or rarity) .. " " .. special, price = priced(22, rarity), desc = "护盾 +" .. cap .. " / 回复 +" .. string.format("%.1f", regen) .. (armor > 0 and (" / 护甲 +" .. armor) or "") .. (flag and (" / " .. special) or ""), shieldCap = cap, shieldRegen = regen, armor = armor, flag = flag}
    item.buy = function() return equipShield(item) end
    return item
end

local function makeTempItem()
    local item = cloneItem(tempItemPool[rnd(1, #tempItemPool)])
    local rarity = rollRarity(Game.player.stats.luck)
    item.rarity = rarity
    item.price = priced(item.price or 14, rarity)
    item.name = (rarityLabel[rarity] or rarity) .. " " .. item.name
    return item
end

local function randomWeaponShopItem()
    local keys = {"needle", "swarm", "molten", "echo", "coil", "void"}
    return makeWeaponItem(keys[rnd(1, #keys)])
end

local function randomSupportShopItem()
    local roll = rnd()
    if roll < 0.34 then return makeShieldItem() end
    if roll < 0.58 then return makeTempItem() end
    return makeStatItem()
end

local function randomShopItem()
    return rnd() < 0.36 and randomWeaponShopItem() or randomSupportShopItem()
end

local function randomShopItemForSlot(i)
    return i <= 3 and randomWeaponShopItem() or randomSupportShopItem()
end

local function preferredSlotRangeForItem(item)
    if item and item.kind == "weapon" then return 1, 3 end
    return 4, 6
end

local function rollShop(keepLocks)
    local used = {}
    if keepLocks then
        for i = 1, 6 do
            if Game.locked[i] and Game.shop[i] then used[Game.shop[i].name] = true end
        end
    end
    for i = 1, 6 do
        if not keepLocks or not Game.locked[i] then
            local item = randomShopItemForSlot(i)
            for _ = 1, 10 do
                if not used[item.name] then break end
                item = randomShopItemForSlot(i)
            end
            Game.shop[i] = item
            Game.locked[i] = false
            used[item.name] = true
        end
    end
end

local addCoins

local slotSymbols = {
    {id = "coin", name = "材料", mark = "◆", color = C.gold, weight = 28},
    {id = "weapon", name = "武器", mark = "⚙", color = C.cyan, weight = 18},
    {id = "temp", name = "战术", mark = "战", color = C.purple, weight = 18},
    {id = "shield", name = "护盾", mark = "盾", color = C.green, weight = 14},
    {id = "heal", name = "修复", mark = "❤", color = C.pink, weight = 14},
    {id = "rare", name = "稀有", mark = "稀", color = C.orange, weight = 8}
}

local function clearedWaveCount()
    if Game.state == "shop" or Game.state == "levelup" then return math.max(0, Game.wave - 1) end
    return math.max(0, Game.wave)
end

local function slotMilestone()
    return math.floor(clearedWaveCount() / 5) * 5
end

local function slotUnlocked()
    return slotMilestone() >= 5
end

local function slotHasFreeUse()
    local milestone = slotMilestone()
    return milestone >= 5 and not (Game.slotFreeUsed and Game.slotFreeUsed[milestone])
end

local function slotSpinCost()
    return 18 + slotMilestone() * 2 + (Game.slotPaidSpins or 0) * 4
end

local function rollSlotSymbol()
    local total = 0
    for _, s in ipairs(slotSymbols) do total = total + s.weight end
    local roll = rnd() * total
    for _, s in ipairs(slotSymbols) do
        roll = roll - s.weight
        if roll <= 0 then return s end
    end
    return slotSymbols[1]
end

local function placeSlotPrize(item)
    item.price = 0
    item.name = "补给转轮 " .. item.name
    local startSlot, endSlot = preferredSlotRangeForItem(item)
    for i = startSlot, endSlot do
        if not Game.locked[i] then
            Game.shop[i] = item
            Game.locked[i] = false
            return
        end
    end
    for i = 1, 6 do
        if not Game.locked[i] then
            Game.shop[i] = item
            Game.locked[i] = false
            return
        end
    end
    Game.shop[startSlot] = item
    Game.locked[startSlot] = false
end

local function slotPrizeItem(kind)
    if kind == "weapon" then
        local keys = {"needle", "swarm", "molten", "echo", "coil", "void"}
        return makeWeaponItem(keys[rnd(1, #keys)])
    elseif kind == "shield" then
        return makeShieldItem()
    elseif kind == "temp" then
        return makeTempItem()
    end
    return makeStatItem()
end

local function grantSlotReward(reels)
    local counts = {}
    for _, s in ipairs(reels) do counts[s.id] = (counts[s.id] or 0) + 1 end
    local bestId, bestCount = reels[1].id, 0
    for id, count in pairs(counts) do
        if count > bestCount then bestId, bestCount = id, count end
    end
    local jackpot = bestCount == 3
    local label = jackpot and "三符奖励" or (bestCount == 2 and "双符奖励" or "基础补给")
    if jackpot then
        if bestId == "coin" then
            addCoins(90, "slot"); return label .. "：材料 +90"
        elseif bestId == "heal" then
            local p = Game.player
            p.hp = p.maxHp; p.shield = p.maxShield
            return label .. "：生命与护盾回满"
        else
            placeSlotPrize(slotPrizeItem(bestId == "rare" and "stat" or bestId))
            return label .. "：免费奖品进商店"
        end
    elseif bestCount == 2 then
        if bestId == "coin" then
            addCoins(34, "slot"); return label .. "：材料 +34"
        elseif bestId == "heal" then
            local p = Game.player
            p.hp = math.min(p.maxHp, p.hp + 35); p.shield = math.min(p.maxShield, p.shield + 25)
            return label .. "：修复生命与护盾"
        elseif bestId == "rare" then
            Game.freeRefresh = (Game.freeRefresh or 0) + 1
            return label .. "：免费刷新 +1"
        else
            placeSlotPrize(slotPrizeItem(bestId))
            return label .. "：免费奖品进商店"
        end
    end
    addCoins(10, "slot")
    return label .. "：材料 +10"
end

local function spinSlotMachine()
    if not slotUnlocked() then toast("清完第 5 波后解锁补给转轮"); return end
    local free = slotHasFreeUse()
    local cost = slotSpinCost()
    if free then
        Game.slotFreeUsed[slotMilestone()] = true
    else
        if Game.coins < cost then toast("材料不足，补给转轮需要 " .. cost); return end
        Game.coins = Game.coins - cost
        Game.slotPaidSpins = (Game.slotPaidSpins or 0) + 1
    end
    local reels = {rollSlotSymbol(), rollSlotSymbol(), rollSlotSymbol()}
    local rewardText = grantSlotReward(reels)
    Game.slotResult = {reels = reels, text = rewardText, free = free}
    playCue("shop")
    toast("补给转轮：" .. rewardText)
end

local function startWave()
    local plan = currentWavePlan()
    Game.state = "playing"
    Game.waveTime = SURVIVAL_DURATION
    Game.waveElapsed = 0
    Game.waveEventIndex = 1
    Game.waveStartKills = Game.kills
    Game.objectiveProgress = 0
    Game.objectiveText = "生存 " .. SURVIVAL_DURATION .. "秒"
    Game.enemies, Game.bullets, Game.pickups = {}, {}, {}
    Game.enemyShots, Game.fireZones = {}, {}
    Game.pendingRewardNextState = nil
    Game.waveRewards = {wave = Game.wave, reason = "", kills = 0, coins = 0, harvest = 0, clear = 0}
    local p = Game.player
    p.waveDamageBonus = 0
    p.waveFireRateBonus = 0
    p.waveElementChance = 0
    p.waveElement = nil
    p.waveArmorDamage = 0
    p.waveEconomyBonus = 0
    p.waveShieldRegenMult = 0
    for _, buff in ipairs(Game.tempBuffs or {}) do
        p.waveDamageBonus = p.waveDamageBonus + (buff.damage or 0)
        p.waveFireRateBonus = p.waveFireRateBonus + (buff.fireRate or 0)
        p.waveElementChance = p.waveElementChance + (buff.elementChance or 0)
        p.waveArmorDamage = p.waveArmorDamage + (buff.armorDamage or 0)
        p.waveEconomyBonus = p.waveEconomyBonus + (buff.economy or 0)
        p.waveShieldRegenMult = p.waveShieldRegenMult + (buff.shieldRegenMult or 0)
        if buff.element then p.waveElement = buff.element end
        if buff.shield then p.maxShield = p.maxShield + buff.shield; p.shield = p.maxShield; p.tempShieldBonus = (p.tempShieldBonus or 0) + buff.shield end
    end
    Game.tempBuffs = {}
    Game.spawnTimer = 0.25
    Game.player.shieldDelay = 0
    toast("第 " .. Game.wave .. " 波：" .. (plan.name or "战斗") .. " / " .. affixLabel())
end

local function enterShop()
    Game.state = "shop"
    Game.shopTab = "shop"
    Game.shopRefresh = 0
    rollShop(true)
    toast("商店开启：认真构筑")
end

local function resetRun()
    local ch = selectedCharacter()
    Game.time = 0
    Game.wave = 1
    Game.coins = ch.coins or 18
    Game.kills = 0
    Game.freeRefresh = 1 + math.floor((ch.stats and ch.stats.luck or 0) / 3)
    Game.slotFreeUsed = {}
    Game.slotPaidSpins = 0
    Game.slotResult = nil
    Game.shopTab = "shop"
    Game.buildPanelTab = "stats"
    Game.hoveredShopItem = nil
    Game.shopRollTimer = 0
    Game.shopGhost = nil
    Game.levelChoices = {}
    Game.pendingRewardNextState = nil
    Game.objectiveProgress = 0
    Game.objectiveText = ""
    Game.message = ""
    Game.enemyShots = {}
    Game.waveRewards = nil
    Game.runStats = {damage = 0, damageByWeapon = {}, coinsEarned = 0, highestWave = 1, rerolls = 0}
    Game.player.x, Game.player.y = Game.w / 2, Game.h / 2
    Game.player.hp, Game.player.maxHp = ch.hp, ch.hp
    Game.player.shield, Game.player.maxShield = ch.shield, ch.shield
    Game.player.shieldDelay, Game.player.shieldRegen = 0, 7
    Game.player.speed, Game.player.pickup = ch.speed, 0
    Game.player.invuln = 0
    Game.player.activeSkill = {name = "推进冲刺", cd = 0, cooldown = ACTIVE_SKILL_CD, duration = 0, maxDuration = ACTIVE_SKILL_DURATION, speedMult = ACTIVE_SKILL_SPEED_MULT, dirX = 0, dirY = -1}
    Game.player.engineerTimer = 0
    Game.player.waveDamageBonus = 0
    Game.player.waveFireRateBonus = 0
    Game.player.waveElementChance = 0
    Game.player.waveElement = nil
    Game.player.waveArmorDamage = 0
    Game.player.waveEconomyBonus = 0
    Game.player.waveShieldRegenMult = 0
    Game.player.tempShieldBonus = 0
    Game.player.stats = {}
    for k, v in pairs(ch.stats) do Game.player.stats[k] = v end
    Game.player.weapons = {}
    Game.selectedWeaponIndex = 1
    Game.player.items = {}
    Game.player.shieldItem = nil
    Game.player.gear = {}
    Game.tempBuffs = {}
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
    toast("关卡奖励：" .. reward.name)
    Game.levelChoices = {}
    local nextState = Game.pendingRewardNextState or "shop"
    Game.pendingRewardNextState = nil
    if nextState == "victory" then
        Game.state = "victory"
    else
        enterShop()
    end
end

function addCoins(amount, bucket)
    local mult = (Game.player and Game.player.stats and Game.player.stats.economy or 1) + (Game.player and Game.player.waveEconomyBonus or 0)
    local gain = math.max(0, math.floor((amount or 0) * mult + 0.5))
    if gain <= 0 then return 0 end
    Game.coins = Game.coins + gain
    Game.runStats.coinsEarned = (Game.runStats.coinsEarned or 0) + gain
    if Game.waveRewards then
        Game.waveRewards.coins = (Game.waveRewards.coins or 0) + gain
        if bucket then Game.waveRewards[bucket] = (Game.waveRewards[bucket] or 0) + gain end
    end
    if Game.player and Game.player.gear and Game.player.gear.coinHaste then Game.player.gear.coinHasteTimer = 2.2 end
    return gain
end

local function killEnemy(e)
    local bonus = currentAffixBonuses()
    Game.kills = Game.kills + 1
    if Game.waveRewards then Game.waveRewards.kills = (Game.waveRewards.kills or 0) + 1 end
    local coinGain = math.max(1, math.floor(e.coin * bonus.coinMult + 0.5))
    addCoins(coinGain)
    if rnd() < 0.52 then addCoins(math.max(1, math.floor(e.coin / 2))) end
    if e.elite and rnd() < 0.72 then addCoins(e.coin + 8) end
    if e.treasure then
        local treasureGain = addCoins((e.treasureCoin or 18) + Game.wave * 2, "treasure")
        addText(e.x, e.y - e.r - 18, "+" .. treasureGain .. " 材料", C.gold)
        toast("击破宝藏信标：材料 +" .. treasureGain)
    end
    local p = Game.player
    if p.gear.killShield then p.shield = math.min(p.maxShield, p.shield + 6 + Game.wave) end
    if p.gear.killBurst then
        for _, other in ipairs(Game.enemies) do
            if other ~= e and distance(e.x, e.y, other.x, other.y) < 90 then damageEnemy(other, 18 * (p.stats.explosiveDamage or 1), "burn", false, "击杀爆裂") end
        end
        burst(e.x, e.y, C.orange, 18, 180)
    end
    if p.gear.corrosionSpread and (e.corrosion or 0) > 0 then
        for _, other in ipairs(Game.enemies) do
            if other ~= e and distance(e.x, e.y, other.x, other.y) < 120 then other.corrosion = math.min(6, (other.corrosion or 0) + 2) end
        end
    end
    if p.gear.critRicochet and e.lastCrit then
        local other = nearestEnemy(e.x, e.y, 180)
        if other and other ~= e then damageEnemy(other, 24 * p.stats.damage, "kinetic", true, "暴击弹射") end
    end
    playCue(e.elite and "elite" or "pickup"); burst(e.x, e.y, e.color, e.boss and 44 or 12, e.boss and 260 or 150)
end

local function damageEnemy(e, amount, element, crit, source)
    local p = Game.player
    local elem = element or "kinetic"
    local elemMult = elem ~= "kinetic" and (p.stats.elementDamage or 1) or 1
    local defenseMult = 1
    if e.shield and e.shield > 0 then
        defenseMult = elem == "arc" and 1.65 or (p.stats.shieldDamage or 1)
    elseif e.defense == "armor" then
        defenseMult = elem == "corrode" and 1.65 or ((p.stats.armorDamage or 1) + (p.waveArmorDamage or 0))
    elseif e.defense == "flesh" then
        defenseMult = elem == "burn" and 1.45 or (p.stats.fleshDamage or 1)
    end
    if e.slow and e.slow > 0 and p.gear.freezeCrit then defenseMult = defenseMult * 1.18 end
    local armor = math.max(0, (e.armor or 0) - (e.corrosion or 0))
    local dmg = math.max(1, amount * elemMult * defenseMult - armor)
    e.lastHit = 1.4
    e.lastCrit = crit
    e.lastElement = elem
    if e.shield and e.shield > 0 then
        local used = math.min(e.shield, dmg)
        e.shield = e.shield - used
        dmg = dmg - used
        if e.shield <= 0 then burst(e.x, e.y, C.cyan, 12, 160) end
    end
    if dmg > 0 then e.hp = e.hp - dmg end
    Game.runStats.damage = (Game.runStats.damage or 0) + dmg
    local src = source or "未知"
    Game.runStats.damageByWeapon[src] = (Game.runStats.damageByWeapon[src] or 0) + dmg
    if Game.player.stats.lifesteal > 0 and rnd() < Game.player.stats.lifesteal then Game.player.hp = math.min(Game.player.maxHp, Game.player.hp + 1) end
    addText(e.x, e.y - e.r, tostring(math.floor(dmg)) .. (crit and "!" or ""), crit and C.gold or elements[elem].color)
    if element == "burn" then e.burn = math.max(e.burn or 0, 3.0) end
    if element == "corrode" then e.corrosion = math.min(p.gear.deepCorrode and 8 or 5, (e.corrosion or 0) + 1) end
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
    local lowHp = 1 + ((1 - clamp(p.hp / math.max(1, p.maxHp), 0, 1)) * (p.stats.lowHpDamage or 0))
    local fullShield = (p.gear.fullShieldDamage and p.shield >= p.maxShield) and 1.08 or 1
    local dmg = w.damage * (p.stats.damage + (p.waveDamageBonus or 0)) * bonus.playerDamage * lowHp * fullShield * (crit and p.stats.critDamage or 1)
    local elem = w.element
    if p.waveElement and rnd() < (p.waveElementChance or 0) then elem = p.waveElement end
    Game.bullets[#Game.bullets + 1] = {
        x = p.x, y = p.y, vx = math.cos(angle) * w.speed * p.stats.projectileSpeed, vy = math.sin(angle) * w.speed * p.stats.projectileSpeed,
        r = w.splash and 7 or 4, damage = dmg, element = elem, range = w.range * p.stats.range,
        traveled = 0, pierce = (w.pierce or 0), bounce = (w.bounce or 0) + p.stats.bounce,
        splash = w.splash, aura = w.aura, color = elements[elem].color, sprite = w.projectileSprite, crit = crit, target = target, source = w.name, brand = w.brand
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
        local lowHp = 1 + ((1 - clamp(p.hp / math.max(1, p.maxHp), 0, 1)) * (p.stats.lowHpDamage or 0))
        local fullShield = (p.gear.fullShieldDamage and p.shield >= p.maxShield) and 1.08 or 1
        local elem = (p.waveElement and rnd() < (p.waveElementChance or 0)) and p.waveElement or w.element
        local dmg = w.damage * (p.stats.damage + (p.waveDamageBonus or 0)) * bonus.playerDamage * lowHp * fullShield * (crit and p.stats.critDamage or 1)
        if damageEnemy(hit, dmg, elem, crit, w.name) then used[hit] = true end
        burst(hit.x, hit.y, elements[elem].color, 5, 90)
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
        local cooldown = w.cooldown / math.max(0.25, (p.stats.fireRate + (p.waveFireRateBonus or 0)) * haste)
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

local function igniteFireZone(x, y, radius, duration, damage)
    Game.fireZones = Game.fireZones or {}
    Game.fireZones[#Game.fireZones + 1] = {x = x, y = y, r = radius or 82, life = duration or 4.6, maxLife = duration or 4.6, damage = damage or 8, tick = 0, color = C.orange}
    burst(x, y, C.orange, 22, 220)
end

local function throwFireBomb(e, targetX, targetY)
    local travel = 0.85
    Game.enemyShots[#Game.enemyShots + 1] = {
        kind = "firebomb", x = e.x, y = e.y,
        targetX = targetX, targetY = targetY,
        vx = (targetX - e.x) / travel, vy = (targetY - e.y) / travel,
        r = 8, damage = e.damage * 0.65, color = C.orange, life = travel,
        zoneRadius = 86, zoneDuration = 4.8
    }
    addText(e.x, e.y - e.r - 10, "燃烧弹", C.orange)
end

local function updateEnemyShots(dt)
    local p = Game.player
    for i = #Game.enemyShots, 1, -1 do
        local b = Game.enemyShots[i]
        b.life = b.life - dt
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        if b.kind == "firebomb" and b.life <= 0 then
            igniteFireZone(b.targetX or b.x, b.targetY or b.y, b.zoneRadius, b.zoneDuration, b.damage)
            table.remove(Game.enemyShots, i)
        elseif distance(b.x, b.y, p.x, p.y) < b.r + p.r then
            damagePlayer(b.damage)
            burst(b.x, b.y, b.color, 5, 80)
            if b.kind == "firebomb" then igniteFireZone(b.x, b.y, b.zoneRadius, b.zoneDuration, b.damage) end
            table.remove(Game.enemyShots, i)
        elseif b.life <= 0 or b.x < -40 or b.x > Game.w + 40 or b.y < -40 or b.y > Game.h + 40 then
            table.remove(Game.enemyShots, i)
        end
    end
end

local function updateFireZones(dt)
    local p = Game.player
    for i = #Game.fireZones, 1, -1 do
        local z = Game.fireZones[i]
        z.life = z.life - dt
        z.tick = (z.tick or 0) - dt
        if distance(z.x, z.y, p.x, p.y) < z.r + p.r * 0.35 and z.tick <= 0 then
            damagePlayer(z.damage or 6)
            z.tick = 0.45
        end
        if z.life <= 0 then table.remove(Game.fireZones, i) end
    end
end

local function updateAutoArc(dt)
    local p = Game.player
    local eng = p.stats.bounce or 0
    if eng <= 0 or not p.gear.autoArc then return end
    p.engineerTimer = (p.engineerTimer or 0) - dt
    if p.engineerTimer > 0 then return end
    p.engineerTimer = math.max(0.45, 1.15 - eng * 0.06)
    local target = nearestEnemy(p.x, p.y, 420)
    if target then
        damageEnemy(target, 8 + eng * 5, "arc", false, "追踪电弧")
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
        local distToPlayer = distance(e.x, e.y, p.x, p.y)
        local moveAngle = a
        local behavior = e.behavior or "chase"
        if behavior == "treasure" then
            e.wanderTimer = (e.wanderTimer or 0) - dt
            if e.wanderTimer <= 0 then
                e.wanderTimer = randf(0.55, 1.35)
                e.wanderAngle = rnd() * TAU
            end
            moveAngle = distToPlayer < 360 and (a + math.pi) or (e.wanderAngle or a)
            spd = spd * (distToPlayer < 360 and 1.35 or 0.82)
        elseif behavior == "shooter" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if distToPlayer < 560 and e.shootTimer <= 0 then
                fireEnemyShot(e, a)
                e.shootTimer = 1.65
            end
            e.wanderTimer = (e.wanderTimer or 0) - dt
            if e.wanderTimer <= 0 then
                e.wanderTimer = randf(0.65, 1.45)
                e.wanderAngle = a + (rnd() < 0.5 and 1 or -1) * randf(1.25, 1.85)
            end
            if distToPlayer < 330 then
                moveAngle = a + math.pi
                spd = spd * 0.95
            else
                moveAngle = e.wanderAngle or a
                spd = spd * 0.36
            end
        elseif behavior == "bomber" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if distToPlayer < 620 and e.shootTimer <= 0 then
                local leadX = p.x + (p.lastMoveX or 0) * 54 + randf(-36, 36)
                local leadY = p.y + (p.lastMoveY or 0) * 54 + randf(-36, 36)
                throwFireBomb(e, clamp(leadX, 70, Game.w - 70), clamp(leadY, 150, Game.h - 70))
                e.shootTimer = randf(2.2, 3.2)
            end
            if distToPlayer < 360 then
                moveAngle = a + math.pi
                spd = spd * 0.78
            else
                e.wanderTimer = (e.wanderTimer or 0) - dt
                if e.wanderTimer <= 0 then e.wanderTimer = randf(0.8, 1.6); e.wanderAngle = a + (rnd() < 0.5 and 1 or -1) * randf(1.1, 1.7) end
                moveAngle = e.wanderAngle or a
                spd = spd * 0.30
            end
        elseif behavior == "charger" then
            e.dashTimer = (e.dashTimer or 0) - dt
            if e.dashTimer <= 0 and distToPlayer < 360 then
                spd = spd * 2.4
                e.dashTimer = 2.2
                addText(e.x, e.y - e.r - 8, "突进", C.orange)
            end
        elseif behavior == "guard" then
            spd = spd * 0.78
            e.armor = math.max(e.armor or 0, 3 + math.floor(Game.wave / 3))
        elseif behavior == "aura" and distToPlayer < 135 then
            damagePlayer(e.damage * 0.22)
        elseif behavior == "boss" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if e.shootTimer <= 0 then
                for k = -1, 1 do fireEnemyShot(e, a + k * 0.22) end
                e.shootTimer = 1.25
            end
        end
        e.x = e.x + math.cos(moveAngle) * spd * dt
        e.y = e.y + math.sin(moveAngle) * spd * dt
        if distance(e.x, e.y, p.x, p.y) < e.r + p.r then
            if (e.damage or 0) > 0 then damagePlayer(e.damage) end
            e.x = e.x - math.cos(a) * 18
            e.y = e.y - math.sin(a) * 18
        end
        if e.lastHit and e.lastHit > 0 then e.lastHit = e.lastHit - dt end
        if e.shield and e.shield < (e.maxShield or 0) and (e.lastHit or 0) <= 0 then
            e.shield = math.min(e.maxShield, e.shield + (e.shieldRegen or 0) * dt)
        end
        if e.hp <= 0 then
            killEnemy(e)
            table.remove(Game.enemies, i)
        end
    end
end

local function updatePlayer(dt)
    local p = Game.player
    local skill = p.activeSkill
    if skill then
        skill.cd = math.max(0, (skill.cd or 0) - dt)
        skill.duration = math.max(0, (skill.duration or 0) - dt)
    end
    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
        if not skill or (skill.duration or 0) <= 0 then
            p.lastMoveX, p.lastMoveY = dx, dy
        end
    end
    local moveX, moveY, speedMult = dx, dy, 1
    if skill and (skill.duration or 0) > 0 then
        moveX = skill.dirX or p.lastMoveX or 0
        moveY = skill.dirY or p.lastMoveY or -1
        speedMult = skill.speedMult or 1
    end
    p.x = clamp(p.x + moveX * p.speed * speedMult * dt, 24, Game.w - 24)
    p.y = clamp(p.y + moveY * p.speed * speedMult * dt, 30, Game.h - 24)
    p.invuln = math.max(0, p.invuln - dt)
    local bonus = currentAffixBonuses()
    if p.shieldDelay > 0 then
        p.shieldDelay = p.shieldDelay - dt
    else
        p.shield = math.min(p.maxShield, p.shield + p.shieldRegen * bonus.shieldRegenMult * dt)
    end
end

local function useActiveSkill()
    if Game.state ~= "playing" then return false end
    local skill = Game.player.activeSkill
    if not skill then return false end
    if (skill.cd or 0) > 0 then
        toast(skill.name .. " 冷却中：" .. string.format("%.1f", skill.cd) .. "s")
        return false
    end
    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if dx == 0 and dy == 0 then
        dx, dy = Game.player.lastMoveX or 0, Game.player.lastMoveY or -1
    else
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end
    skill.dirX, skill.dirY = dx, dy
    skill.duration = skill.maxDuration or ACTIVE_SKILL_DURATION
    skill.cd = skill.cooldown or ACTIVE_SKILL_CD
    playCue("level")
    toast(skill.name .. "：冲刺")
    return true
end

local function completeWave(reason)
    local p = Game.player
    local finishedWave = Game.wave
    local summary = Game.waveRewards or {wave = finishedWave, kills = 0, coins = 0, harvest = 0, clear = 0}
    summary.wave = finishedWave
    summary.reason = reason or "波次完成"
    Game.waveRewards = summary
    local harvest = math.max(0, p.stats.harvest or 0)
    if harvest > 0 then
        local gain = harvest + math.floor(Game.wave / 2)
        addCoins(gain, "harvest")
        toast((reason or "波次完成") .. "：收获 +" .. gain .. " 材料")
    end
    generateLevelChoices()
    if Game.wave >= Game.maxWave then
        Game.pendingRewardNextState = "victory"
        Game.state = "levelup"
        return
    end
    Game.wave = Game.wave + 1
    Game.runStats.highestWave = math.max(Game.runStats.highestWave or 1, Game.wave)
    local base = 10 + Game.wave * 2 + Game.danger * 2
    addCoins(base, "clear")
    Game.pendingRewardNextState = "shop"
    Game.state = "levelup"
end

local function updatePlaying(dt)
    local plan = currentWavePlan()
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
        local pressure = math.max(0, Game.waveElapsed / SURVIVAL_DURATION)
        local bonus = currentAffixBonuses()
        Game.spawnTimer = math.max(0.30, ((plan.interval or 1.0) * bonus.intervalMult) - pressure * 0.16)
    end
    updatePlayer(dt)
    updateWeapons(dt)
    updateAutoArc(dt)
    updateBullets(dt)
    updateEnemyShots(dt)
    updateFireZones(dt)
    updateEnemies(dt)

    Game.objectiveText = "生存 " .. math.max(0, math.ceil(Game.waveTime)) .. "秒"

    if Game.waveTime <= 0 and Game.state == "playing" then
        Game.waveTime = 0
        completeWave(Game.wave >= Game.maxWave and "生存完成" or "波次完成")
    end
end

local function uiFont(size)
    local fullBundled = "assets/fonts/NotoSansCJK-Regular.ttc"
    if love.filesystem.getInfo(fullBundled) then
        return love.graphics.newFont(fullBundled, size)
    end
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

local function viewportTransform()
    local sw, sh = love.graphics.getDimensions()
    local scale = math.min(sw / VIRTUAL_W, sh / VIRTUAL_H)
    local ox = math.floor((sw - VIRTUAL_W * scale) / 2 + 0.5)
    local oy = math.floor((sh - VIRTUAL_H * scale) / 2 + 0.5)
    return scale, ox, oy, sw, sh
end

local function screenToGame(x, y)
    local scale, ox, oy = viewportTransform()
    return (x - ox) / scale, (y - oy) / scale
end

local function gameToScreen(x, y)
    local scale, ox, oy = viewportTransform()
    return ox + x * scale, oy + y * scale
end

local function mousePosition()
    local x, y = love.mouse.getPosition()
    return screenToGame(x, y)
end

function love.load()
    love.window.setTitle("机器人大战 原型")
    if os.getenv("LOVE_WINDOW_W") and os.getenv("LOVE_WINDOW_H") then
        love.window.setMode(tonumber(os.getenv("LOVE_WINDOW_W")) or 1920, tonumber(os.getenv("LOVE_WINDOW_H")) or 1080, {resizable = true, highdpi = true, usedpiscale = true})
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.math.setRandomSeed(os.time())
    Game.w, Game.h = VIRTUAL_W, VIRTUAL_H
    Game.fonts = {tiny = uiFont(18), subtitle = uiFont(22), small = uiFont(24), normal = uiFont(31), big = uiFont(50), title = uiFont(84)}
    loadImages()
    Game.sounds = {
        pickup = loadSound("assets/sfx/ui_select.ogg", 880, 0.06, 0.18),
        hit = loadSound("assets/sfx/player_hit.ogg", 180, 0.05, 0.28),
        level = loadSound("assets/sfx/level_open.ogg", 660, 0.16, 0.30),
        shop = loadSound("assets/sfx/shop_confirm.ogg", 520, 0.10, 0.26),
        elite = loadSound("assets/sfx/elite_down.ogg", 120, 0.22, 0.34)
    }
    for _ = 1, 130 do
        Game.stars[#Game.stars + 1] = {x = rnd() * Game.w, y = rnd() * Game.h, r = rnd(7, 21) / 10, speed = rnd(8, 38), phase = rnd() * TAU}
    end
end

function love.update(dt)
    Game.w, Game.h = VIRTUAL_W, VIRTUAL_H
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
    Game.shopRollTimer = math.max(0, (Game.shopRollTimer or 0) - dt)
    if Game.state == "shop" and (Game.shopTab or "shop") == "shop" then
        local mx, my = mousePosition()
        local marginX, gap, sideW, sideGap = 96, 28, 430, 32
        local sideX = Game.w - marginX - sideW
        local cardW = (sideX - marginX - gap * 2 - sideGap) / 3
        local cardH = 268
        local weaponY, supportY = 254, 604
        local hovered = nil
        for i = 1, 6 do
            local col = (i - 1) % 3
            local x = marginX + col * (cardW + gap)
            local y = i <= 3 and weaponY or supportY
            if mx >= x and mx <= x + cardW and my >= y and my <= y + cardH then hovered = i end
        end
        if hovered and hovered ~= Game.hoveredShopItem then playCue("pickup") end
        Game.hoveredShopItem = hovered
    else
        Game.hoveredShopItem = nil
    end
    if Game.state == "playing" then updatePlaying(dt) end
    if os.getenv("LOVE_AUTOACTIVE") == "1" and Game.state == "playing" and not Game.autoActiveDone and Game.time > 0.35 then
        Game.autoActiveDone = true
        useActiveSkill()
    end
    if os.getenv("LOVE_AUTOPAUSE") == "1" and not Game.autoPauseDone then
        if Game.state == "menu" then resetRun() end
        Game.autoPauseClock = (Game.autoPauseClock or 0) + dt
        if Game.autoPauseClock > 0.7 and Game.state == "playing" then Game.state = "paused" end
        if Game.autoPauseClock > 1.0 then
            Game.autoPauseDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-pause.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOMENU") == "1" and not Game.autoMenuDone then
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
        if os.getenv("LOVE_AUTOSHOP_TAB") then Game.shopTab = os.getenv("LOVE_AUTOSHOP_TAB") end
        if os.getenv("LOVE_AUTOSOLDOUT_SLOT") and not Game.autoSoldoutApplied then
            local slot = tonumber(os.getenv("LOVE_AUTOSOLDOUT_SLOT")) or 1
            if slot >= 1 and slot <= 6 then Game.shop[slot] = nil; Game.locked[slot] = false end
            Game.autoSoldoutApplied = true
        end
        if os.getenv("LOVE_AUTOHOVER_X") and os.getenv("LOVE_AUTOHOVER_Y") then
            local sx, sy = gameToScreen(tonumber(os.getenv("LOVE_AUTOHOVER_X")) or 0, tonumber(os.getenv("LOVE_AUTOHOVER_Y")) or 0)
            love.mouse.setPosition(sx, sy)
        end
        Game.autoShopClock = (Game.autoShopClock or 0) + dt
        if Game.autoShopClock > 0.4 then
            Game.autoShopDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-shop.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOFIREZONE") == "1" and not Game.autoFireZoneDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoFireZoneSpawned then
            Game.autoFireZoneSpawned = true
            spawnEnemy(enemyDefs.treasure, {side = "right", scale = 1})
            spawnEnemy(enemyDefs.bomber, {side = "left", scale = 1})
            igniteFireZone(Game.player.x + 120, Game.player.y + 40, 90, 4.8, 8)
        end
        Game.autoFireZoneClock = (Game.autoFireZoneClock or 0) + dt
        if Game.autoFireZoneClock > 1.0 then
            Game.autoFireZoneDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-firezone.png")
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

local function drawCapsule(text, x, y, w, h, opts)
    opts = opts or {}
    local bg = opts.bg or C.panel
    local border = opts.border or C.line
    local fg = opts.fg or C.white
    local font = opts.font or Game.fonts.tiny
    local align = opts.align or "center"
    local radius = opts.radius or 10
    local padX = opts.padX or 12
    color(bg, opts.bgAlpha or 0.54)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    color(border, opts.borderAlpha or 0.34)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, radius, radius)
    love.graphics.setFont(font)
    color(fg, opts.fgAlpha or 1)
    local textY = y + math.floor((h - font:getHeight()) / 2)
    love.graphics.printf(text, x + padX, textY, w - padX * 2, align)
end

local function drawTwoLineCapsule(label, value, x, y, w, h, accent, opts)
    opts = opts or {}
    color(opts.bg or C.panel, opts.bgAlpha or 0.54)
    love.graphics.rectangle("fill", x, y, w, h, opts.radius or 12, opts.radius or 12)
    color(accent or C.cyan, opts.borderAlpha or 0.42)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, opts.radius or 12, opts.radius or 12)
    local labelFont = opts.labelFont or Game.fonts.tiny
    local valueFont = opts.valueFont or Game.fonts.small
    local gap = opts.gap or 2
    local totalH = labelFont:getHeight() + valueFont:getHeight() + gap
    local yy = y + math.floor((h - totalH) / 2)
    love.graphics.setFont(labelFont)
    color(C.muted)
    love.graphics.printf(label, x + 10, yy, w - 20, opts.align or "center")
    love.graphics.setFont(valueFont)
    color(accent or C.white)
    love.graphics.printf(value, x + 10, yy + labelFont:getHeight() + gap, w - 20, opts.align or "center")
end

local function drawBarCapsule(label, value, x, y, w, h, pct, accent)
    color(C.panel, 0.58)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    color(accent, 0.40)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 12, 12)
    love.graphics.setFont(Game.fonts.tiny)
    local labelW = 54
    local valueW = 72
    color(C.muted)
    love.graphics.printf(label, x + 12, y + math.floor((h - Game.fonts.tiny:getHeight()) / 2), labelW, "left")
    local barX, barY = x + 70, y + math.floor((h - 10) / 2)
    local barW = w - 70 - valueW - 14
    bar(barX, barY, barW, 10, pct, accent, {0.02, 0.024, 0.05})
    color(C.white)
    love.graphics.printf(value, x + w - valueW - 12, y + math.floor((h - Game.fonts.tiny:getHeight()) / 2), valueW, "right")
end

local function drawHud()
    local p = Game.player
    local hudY, hudH = 14, 100
    panel(18, hudY, Game.w - 36, hudH)

    -- 左：生存状态。只展示玩家战斗中最需要扫一眼的内容。
    local lx = 36
    drawBarCapsule("生命", math.ceil(p.hp) .. "/" .. p.maxHp, lx, hudY + 10, 292, 28, p.hp / p.maxHp, C.pink)
    drawBarCapsule("护盾", math.ceil(p.shield) .. "/" .. p.maxShield, lx, hudY + 46, 292, 28, p.shield / p.maxShield, C.cyan)
    drawCapsule("材料 " .. Game.coins, lx + 310, hudY + 10, 112, 28, {fg = C.gold, border = C.gold, align = "center", padX = 14})
    drawCapsule("击杀 " .. Game.kills, lx + 310, hudY + 46, 112, 28, {fg = C.white, border = C.white, align = "center", padX = 14})

    -- 中：战斗焦点。倒计时是唯一主视觉，波次/目标弱化成辅助标签。
    local midX = Game.w / 2
    local timerW, timerH = 126, 62
    local timerX, timerY = midX - timerW / 2, hudY + 12
    color(C.white, 0.085)
    love.graphics.rectangle("fill", timerX, timerY, timerW, timerH, 16, 16)
    color(C.cyan, 0.32)
    love.graphics.rectangle("line", timerX + 0.5, timerY + 0.5, timerW - 1, timerH - 1, 16, 16)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf(string.format("%02d", math.max(0, math.ceil(Game.waveTime))), timerX, timerY + math.floor((timerH - Game.fonts.big:getHeight()) / 2) + 1, timerW, "center")

    drawCapsule("第 " .. Game.wave .. " 波", midX - 218, hudY + 18, 122, 28, {fg = C.gold, border = C.gold, borderAlpha = 0.18})
    drawCapsule(currentWavePlan().name or "生存波次", midX - 218, hudY + 52, 122, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.gold, bgAlpha = 0.32, borderAlpha = 0.16})
    drawCapsule(Game.objectiveText or selectedObjective().name, midX + 96, hudY + 18, 150, 28, {fg = C.cyan, border = C.cyan, borderAlpha = 0.18})
    drawCapsule("危险 " .. Game.danger, midX + 96, hudY + 52, 150, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.cyan, bgAlpha = 0.32, borderAlpha = 0.16})

    -- 右：当前影响。只保留词缀、主动技能和一行武器摘要，不再堆列表。
    local rx, rw = Game.w - 392, 354
    local reward, penalty = currentAffixes()
    drawCapsule("奖励 " .. (reward and reward.name or "无"), rx, hudY + 10, 168, 28, {fg = C.green, border = C.green, borderAlpha = 0.16, align = "left", padX = 14})
    drawCapsule("惩罚 " .. (penalty and penalty.name or "无"), rx + 180, hudY + 10, 174, 28, {fg = C.red, border = C.red, borderAlpha = 0.16, align = "left", padX = 14})

    local skill = p.activeSkill or {}
    local skillText = "空格 " .. (skill.name or "主动技能")
    local skillFg = C.cyan
    if (skill.duration or 0) > 0 then
        skillText = "空格 冲刺中 " .. string.format("%.1f", skill.duration) .. "s"
        skillFg = C.gold
    elseif (skill.cd or 0) > 0 then
        skillText = "空格 冷却 " .. string.format("%.1f", skill.cd) .. "s"
        skillFg = C.muted
    end
    drawCapsule(skillText, rx, hudY + 42, rw, 24, {font = Game.fonts.tiny, fg = skillFg, border = skillFg, bgAlpha = 0.26, borderAlpha = 0.18, align = "left", padX = 14})

    local weaponText = "武器 0/4"
    local tagText = "等待构筑"
    if p.weapons[1] then
        local weapon = p.weapons[1]
        local brand = brands[weapon.brand]
        weaponText = "武器 " .. #p.weapons .. "/4 · " .. weapon.name .. " Lv" .. weapon.level
        tagText = brand and brand.tag or "构筑中"
    end
    drawCapsule(weaponText, rx, hudY + 66, rw, 24, {font = Game.fonts.tiny, fg = C.white, border = C.cyan, align = "left", padX = 14})
    drawCapsule(tagText, rx + rw - 150, hudY + 68, 140, 20, {font = Game.fonts.tiny, fg = C.muted, border = C.white, bgAlpha = 0.20, borderAlpha = 0.10})
end

local function drawWorld()
    for _, z in ipairs(Game.fireZones or {}) do
        local pct = clamp(z.life / math.max(0.1, z.maxLife or z.life), 0, 1)
        love.graphics.setBlendMode("add")
        color(C.orange, 0.10 + pct * 0.18)
        love.graphics.circle("fill", z.x, z.y, z.r)
        color(C.red, 0.12 + pct * 0.12)
        love.graphics.circle("fill", z.x, z.y, z.r * 0.68)
        love.graphics.setBlendMode("alpha")
        color(C.orange, 0.42)
        love.graphics.circle("line", z.x, z.y, z.r)
    end
    for _, b in ipairs(Game.bullets) do
        drawProjectile(b)
    end
    for _, b in ipairs(Game.enemyShots) do
        love.graphics.setBlendMode("add")
        color(b.color or C.red, b.kind == "firebomb" and 0.48 or 0.36)
        love.graphics.circle("fill", b.x, b.y, b.r * (b.kind == "firebomb" and 3.0 or 2.2))
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
        if e.treasure then
            local pulse = 0.55 + 0.45 * math.sin((love.timer.getTime() or 0) * 5)
            love.graphics.setBlendMode("add")
            color(C.gold, 0.20 + pulse * 0.16)
            love.graphics.circle("fill", e.x, e.y, e.r * 2.8)
            color(C.white, 0.70)
            love.graphics.circle("line", e.x, e.y, e.r * 1.9)
            love.graphics.setBlendMode("alpha")
            love.graphics.setFont(Game.fonts.tiny)
            color(C.gold)
            love.graphics.printf("宝", e.x - 16, e.y - e.r - 26, 32, "center")
        end
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
        local skill = p.activeSkill
        if skill and (skill.duration or 0) > 0 then
            love.graphics.setBlendMode("add")
            color(C.gold, 0.22)
            love.graphics.circle("fill", p.x, p.y, p.r + 34)
            color(C.cyan, 0.42)
            love.graphics.circle("line", p.x, p.y, p.r + 28)
            love.graphics.setBlendMode("alpha")
        end
        if not drawSprite("player_heartcore", p.x, p.y, 96, 0, 1) then
            color(C.pink)
            drawHeart(p.x, p.y + 2, 0.78)
        end
        color(C.cyan, 0.58)
        love.graphics.circle("line", p.x, p.y, p.r + 14)
        local barW, barH = 72, 5
        local barX = p.x - barW / 2
        local barY = p.y - p.r - 42
        if p.hp < p.maxHp then
            love.graphics.setColor(0, 0, 0, 0.62)
            love.graphics.rectangle("fill", barX - 1, barY - 8, barW + 2, barH + 2, 3, 3)
            color(C.pink, 0.95)
            love.graphics.rectangle("fill", barX, barY - 7, barW * clamp(p.hp / math.max(1, p.maxHp), 0, 1), barH, 3, 3)
            color(C.white, 0.42)
            love.graphics.rectangle("line", barX - 0.5, barY - 7.5, barW + 1, barH + 1, 3, 3)
        end
        if skill then
            local cdMax = skill.cooldown or ACTIVE_SKILL_CD
            local ready = (skill.cd or 0) <= 0
            local pctReady = ready and 1 or clamp(1 - ((skill.cd or 0) / math.max(0.1, cdMax)), 0, 1)
            love.graphics.setColor(0, 0, 0, 0.64)
            love.graphics.rectangle("fill", barX - 1, barY, barW + 2, barH + 2, 3, 3)
            color(C.white, ready and 0.98 or 0.72)
            love.graphics.rectangle("fill", barX, barY + 1, barW * pctReady, barH, 3, 3)
            color(C.white, 0.42)
            love.graphics.rectangle("line", barX - 0.5, barY + 0.5, barW + 1, barH + 1, 3, 3)
        end
    end

    for _, q in ipairs(Game.particles) do color(q.color, clamp(q.life / q.max, 0, 1)); love.graphics.circle("fill", q.x, q.y, q.r) end
    for _, t in ipairs(Game.damageTexts) do color(t.color, clamp(t.life / 0.72, 0, 1)); love.graphics.setFont(Game.fonts.tiny); love.graphics.print(t.text, t.x, t.y) end
end

local function hitRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function uiButton(text, x, y, w, h, bg, fg, font)
    local c = bg or C.cyan
    local strong = font == Game.fonts.normal
    local pulse = strong and (0.5 + 0.5 * math.sin((love.timer.getTime() or 0) * 3.4)) or 0
    color(c, strong and (0.30 + pulse * 0.10) or 0.20)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    if strong then
        color(c, 0.15 + pulse * 0.12)
        love.graphics.rectangle("fill", x - 16, y - 16, w + 32, h + 32, 22, 22)
        color(C.gold, 0.10 + pulse * 0.10)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 18, y - 18, w + 36, h + 36, 24, 24)
        love.graphics.setLineWidth(1)
    end
    color(c, strong and (0.86 + pulse * 0.14) or 0.74)
    love.graphics.setLineWidth(strong and 3 or 2)
    love.graphics.rectangle("line", x, y, w, h, 14, 14)
    if strong then
        local teeth = 9
        color(C.gold, 0.34 + pulse * 0.14)
        for i = 1, teeth - 2 do
            local tx = x + 18 + i * ((w - 36) / (teeth - 1))
            love.graphics.rectangle("fill", tx - 4, y - 8, 8, 8, 2, 2)
            love.graphics.rectangle("fill", tx - 4, y + h, 8, 8, 2, 2)
        end
        color(C.white, 0.12)
        love.graphics.rectangle("fill", x + 6, y + 6, w - 12, math.max(8, h * 0.36), 10, 10)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setFont(font or Game.fonts.small)
    color(fg or C.white)
    love.graphics.printf(text, x, y + math.floor((h - (font or Game.fonts.small):getHeight()) / 2) + 1, w, "center")
end

local function drawMenu()
    local w, h = Game.w, Game.h
    local t = love.timer.getTime() or 0

    love.graphics.setColor(0.005, 0.007, 0.020, 0.62)
    love.graphics.rectangle("fill", 0, 0, w, h)

    color(C.cyan, 0.10)
    love.graphics.setLineWidth(1)
    for i = -2, 5 do
        local x = 110 + i * 210
        love.graphics.line(x, 120, x + 140, h - 96)
    end
    color(C.pink, 0.08)
    love.graphics.line(96, 124, w - 96, 124)
    love.graphics.line(150, h - 220, w - 150, h - 220)

    -- 顶部机械臂剪影：弱存在感，建立机器人主题动线。
    local armSwing = math.sin(t * 1.4) * 10
    local function mechArm(baseX, flip)
        local y = 96
        local dir = flip and -1 or 1
        color({0.010, 0.014, 0.032}, 0.72)
        love.graphics.setLineWidth(18)
        love.graphics.line(baseX, y, baseX + dir * 145, y + 38 + armSwing * 0.2)
        love.graphics.line(baseX + dir * 145, y + 38 + armSwing * 0.2, baseX + dir * 250, y + 20 + armSwing)
        love.graphics.setLineWidth(1)
        color(C.cyan, 0.20)
        love.graphics.circle("line", baseX, y, 22)
        love.graphics.circle("line", baseX + dir * 145, y + 38 + armSwing * 0.2, 18)
        color(C.gold, 0.22)
        love.graphics.rectangle("fill", baseX + dir * 250 - 18, y + 20 + armSwing - 8, 36, 16, 4, 4)
    end
    mechArm(240, false)
    mechArm(w - 240, true)

    -- 金属质感标题：暗描边 + 金属高光 + 主白字。
    love.graphics.setFont(Game.fonts.title)
    local titleY = 34
    color({0.004, 0.005, 0.014}, 1.00)
    for _, off in ipairs({{-7, 0}, {7, 0}, {0, -7}, {0, 7}, {-6, -6}, {6, 6}, {-6, 6}, {6, -6}, {-4, 0}, {4, 0}, {0, -4}, {0, 4}}) do
        love.graphics.printf("机器人大战", off[1], titleY + off[2], w, "center")
    end
    color({0.34, 0.27, 0.16}, 0.78)
    for _, off in ipairs({{-4, -3}, {4, -2}, {-3, 4}, {3, 4}, {-2, 0}, {2, 0}, {0, -2}, {0, 2}}) do
        love.graphics.printf("机器人大战", off[1], titleY + off[2], w, "center")
    end
    color(C.gold, 0.58)
    for _, off in ipairs({{-2, -2}, {2, -1}, {-1, 2}, {1, 2}}) do
        love.graphics.printf("机器人大战", off[1], titleY + off[2], w, "center")
    end
    color(C.cyan, 0.16)
    love.graphics.printf("机器人大战", 3, titleY + 3, w, "center")
    color({0.72, 0.77, 0.88}, 0.96)
    love.graphics.printf("机器人大战", 0, titleY + 1, w, "center")
    color(C.white)
    love.graphics.printf("机器人大战", 0, titleY - 2, w, "center")

    love.graphics.setFont(Game.fonts.subtitle or Game.fonts.small)
    color(C.muted, 0.62)
    love.graphics.printf("ROBOT WAR  ·  BUILD / SURVIVE / EVOLVE", 0, 126, w, "center")

    local heroX, heroY = w / 2, h / 2
    local cx, cy = heroX, heroY
    color(C.cyan, 0.08)
    love.graphics.circle("fill", cx, cy, 150)
    color(C.pink, 0.10)
    love.graphics.circle("fill", cx, cy, 108)
    color(C.cyan, 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, 154)
    color(C.pink, 0.48)
    love.graphics.circle("line", cx, cy, 116)
    color(C.gold, 0.26)
    love.graphics.circle("line", cx, cy, 72)
    love.graphics.setLineWidth(1)
    color(C.cyan, 0.18)
    love.graphics.polygon("line", cx, cy - 180, cx + 165, cy + 94, cx - 165, cy + 94)
    color(C.pink, 0.16)
    love.graphics.polygon("line", cx, cy + 180, cx + 165, cy - 94, cx - 165, cy - 94)

    color(C.pink)
    drawHeart(cx, cy + 5, 1.22)
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf("白板开局，构筑成怪物", cx - 260, cy + 160, 520, "center")

    local deckX, deckY, deckW, deckH = 90, h - 168, w - 180, 126
    love.graphics.setColor(0.012, 0.016, 0.040, 0.78)
    love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 16, 16)
    color(C.cyan, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", deckX, deckY, deckW, deckH, 16, 16)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Game.fonts.small)
    color(C.cyan)
    love.graphics.printf("模式  生存模式 · 30秒", deckX + 28, deckY + 32, 360, "left")

    local dangerText = Game.danger == 0 and "难度  基础" or ("难度  危险 " .. Game.danger)
    color(C.gold)
    love.graphics.printf(dangerText, deckX + deckW - 358, deckY + 32, 330, "right")

    uiButton("开始实验", w / 2 - 140, deckY + 30, 280, 62, C.gold, C.white, Game.fonts.normal)
    -- 首页不再提供模式切换，只保留生存模式；难度仍可调整。
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("唯一目标：生存 30 秒", deckX + 28, deckY + 86, 260, "left")
    uiButton("-", deckX + deckW - 158, deckY + 82, 58, 32, C.cyan, C.white, Game.fonts.tiny)
    uiButton("+", deckX + deckW - 86, deckY + 82, 58, 32, C.cyan, C.white, Game.fonts.tiny)
end

local function drawLevelUp()
    love.graphics.setColor(0, 0, 0, 0.58)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    panel(Game.w / 2 - 620, 145, 1240, 500)
    love.graphics.setFont(Game.fonts.big)
    color(C.gold)
    love.graphics.printf("关卡完成：选择奖励", Game.w / 2 - 620, 182, 1240, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    local wr = Game.waveRewards or {}
    local settlement = string.format(
        "第 %d 波结算：%s｜击杀 %d｜材料 +%d",
        wr.wave or Game.wave,
        wr.reason or "波次完成",
        wr.kills or 0,
        wr.coins or 0
    )
    love.graphics.printf(settlement, Game.w / 2 - 560, 258, 1120, "center")
    local detail = string.format("收获 +%d｜通关奖励 +%d｜按 1 / 2 / 3 或点击卡牌选择，随后进入商店。", wr.harvest or 0, wr.clear or 0)
    love.graphics.printf(detail, Game.w / 2 - 560, 296, 1120, "center")
    local w, h, gap = 330, 210, 34
    local sx = Game.w / 2 - (w * 3 + gap * 2) / 2
    for i, r in ipairs(Game.levelChoices) do
        local x = sx + (i - 1) * (w + gap)
        panel(x, 350, w, h)
        local rc = rarityColor[r.rarity or "rare"] or C.cyan
        color(rc, 0.95)
        love.graphics.rectangle("fill", x, 350, w, 6, 6, 6)
        love.graphics.setFont(Game.fonts.normal)
        color(C.white)
        love.graphics.printf(i .. ". " .. r.name, x + 16, 386, w - 32, "center")
        love.graphics.setFont(Game.fonts.small)
        color(C.cyan)
        love.graphics.printf(r.desc, x + 22, 462, w - 44, "center")
    end
end

local function statText(label, value)
    return label .. " " .. value
end

local function pct(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

local function modText(text)
    return text
end

local function textInBox(text, x, y, w, h, font, c, align)
    font = font or Game.fonts.tiny
    love.graphics.setFont(font)
    color(c or C.white)
    love.graphics.printf(tostring(text or ""), x, y + math.floor((h - font:getHeight()) / 2), w, align or "center")
end

local function centeredText(text, x, y, w, h, font, c, align)
    textInBox(text, x, y, w, h, font, c, align or "center")
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

local function shopItemAccent(item)
    if item.kind == "weapon" then return C.orange end
    if item.kind == "shield" then return C.cyan end
    if item.kind == "temp" then return C.purple end
    if item.kind == "legend" then return C.gold end
    return rarityColor[item.rarity or "common"] or C.white
end

local function drawKindIcon(kind, x, y, accent)
    color(accent, 0.18)
    love.graphics.circle("fill", x, y, 12, 18)
    color(accent, 0.82)
    love.graphics.setLineWidth(2)
    if kind == "weapon" then
        love.graphics.line(x - 7, y + 7, x + 7, y - 7)
        love.graphics.line(x + 2, y - 7, x + 7, y - 7, x + 7, y - 2)
        love.graphics.line(x - 6, y + 4, x - 3, y + 7)
    elseif kind == "shield" then
        love.graphics.polygon("line", x, y - 9, x + 8, y - 5, x + 6, y + 6, x, y + 10, x - 6, y + 6, x - 8, y - 5)
    elseif kind == "temp" then
        love.graphics.polygon("line", x, y - 10, x + 4, y - 2, x + 11, y, x + 4, y + 2, x, y + 10, x - 4, y + 2, x - 11, y, x - 4, y - 2)
    elseif kind == "legend" then
        love.graphics.circle("line", x, y, 8, 18)
        love.graphics.circle("fill", x, y, 3, 10)
    else
        love.graphics.rectangle("line", x - 7, y - 7, 14, 14, 3, 3)
    end
    love.graphics.setLineWidth(1)
end

local function compactDesc(text, maxLen)
    local s = modText(text or "")
    s = s:gsub("下一波", "下波"):gsub("本局永久生效", "永久"):gsub("材料", "材")
    s = s:gsub("护盾回复", "回盾"):gsub("暴击伤害", "暴伤"):gsub("元素伤害", "元素")
    s = s:gsub("最大生命", "生命"):gsub("冷却", "CD")
    local chars, cut = 0, nil
    local i = 1
    while i <= #s do
        chars = chars + 1
        if chars == maxLen then cut = i; break end
        local b = s:byte(i)
        if b >= 240 then i = i + 4
        elseif b >= 224 then i = i + 3
        elseif b >= 192 then i = i + 2
        else i = i + 1 end
    end
    if cut then
        s = s:sub(1, cut - 1) .. "..."
    end
    return s
end

local function drawMetalCard(x, y, w, h, accent, hover, locked, rare)
    local lift = hover and -6 or 0
    y = y + lift
    love.graphics.setColor(0, 0, 0, hover and 0.54 or 0.38)
    love.graphics.rectangle("fill", x + 10, y + h + (hover and 12 or 8), w - 20, 18, 14, 14)
    color(C.white, hover and 0.10 or 0.04)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 18, 18)
    color({0.006, 0.007, 0.012}, locked and 0.96 or 0.90)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    color(C.white, hover and 0.10 or 0.055)
    love.graphics.rectangle("fill", x + 4, y + 4, w - 8, math.max(18, h * 0.28), 14, 14)
    color(C.white, hover and 0.74 or 0.30)
    love.graphics.setLineWidth(hover and 2 or 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 16, 16)
    love.graphics.setLineWidth(1)
    color(C.white, hover and 0.18 or 0.10)
    love.graphics.polygon("fill", x + 16, y + 8, x + 84, y + 8, x + 64, y + 13, x + 18, y + 13)
    color(C.white, hover and 0.40 or 0.20)
    love.graphics.rectangle("fill", x + 10, y + h - 7, w - 20, 2, 2, 2)
    if rare then
        local t = love.timer.getTime() or 0
        local sweep = (math.sin(t * 3.2) + 1) / 2
        color(C.white, 0.10 + sweep * 0.12)
        love.graphics.rectangle("fill", x + 8 + sweep * (w - 72), y + 3, 56, 2, 2, 2)
        color(C.white, 0.12 + sweep * 0.12)
        love.graphics.rectangle("line", x + 5.5, y + 5.5, w - 11, h - 11, 13, 13)
    end
    if locked then
        color(C.white, 0.12)
        love.graphics.rectangle("fill", x, y, w, h, 16, 16)
        love.graphics.setFont(Game.fonts.big)
        color(C.white, 0.34)
        love.graphics.printf("锁", x, y + h / 2 - 28, w, "center")
    end
    return y
end

local Tooltip = {}

local function wrappedLineCount(font, text, width)
    local _, wrapped = font:getWrap(tostring(text or ""), width)
    return math.max(1, #wrapped)
end

function Tooltip.measure(tip, width)
    local title = tip.title or "详情"
    local lines = tip.lines or {}
    local fontTitle, fontBody = Game.fonts.tiny, Game.fonts.tiny
    local innerW = width - 32
    local height = 18 + wrappedLineCount(fontTitle, title, innerW) * 20 + 8
    for _, entry in ipairs(lines) do
        local text = type(entry) == "table" and entry.text or entry
        local gap = type(entry) == "table" and entry.gap or 0
        height = height + gap + wrappedLineCount(fontBody, text, innerW) * 19
    end
    return height + 14
end

function Tooltip.draw(tip, mx, my)
    if not tip then return end
    local title = tip.title or "详情"
    local lines = tip.lines or {}
    local fontTitle, fontBody = Game.fonts.tiny, Game.fonts.tiny
    local width = clamp(tip.width or 380, 300, 460)
    local height = math.min(Tooltip.measure(tip, width), Game.h - 24)
    local anchor = tip.anchor
    local x, y
    if anchor then
        -- 商品卡 tooltip 固定贴到右侧详情区，避免盖住货架和购买按钮。
        x = Game.w - width - 32
        if anchor.x < x + width and anchor.x + anchor.w > x then
            x = anchor.x - width - 22
        end
        y = anchor.y + 4
    else
        x = mx + 22
        if x + width > Game.w - 12 then x = mx - width - 22 end
        y = my + 22
        if y + height > Game.h - 12 then y = my - height - 22 end
    end
    x = clamp(x, 12, Game.w - width - 12)
    y = clamp(y, 12, Game.h - height - 12)

    color(C.bgA, 0.97)
    love.graphics.rectangle("fill", x, y, width, height, 12, 12)
    color(C.gold, 0.58)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 12, 12)
    color(C.white, 0.07)
    love.graphics.rectangle("fill", x + 8, y + 8, width - 16, 28, 9, 9)

    local innerX, innerW = x + 16, width - 32
    local cy = y + 13
    love.graphics.setFont(fontTitle)
    color(C.gold)
    love.graphics.printf(title, innerX, cy, innerW, "left")
    cy = cy + wrappedLineCount(fontTitle, title, innerW) * 20 + 10

    love.graphics.setFont(fontBody)
    for i, entry in ipairs(lines) do
        local text = type(entry) == "table" and entry.text or entry
        local lineColor = type(entry) == "table" and entry.color or (i == 1 and C.white or C.muted)
        local gap = type(entry) == "table" and entry.gap or 0
        cy = cy + gap
        color(lineColor)
        love.graphics.printf(tostring(text or ""), innerX, cy, innerW, "left")
        cy = cy + wrappedLineCount(fontBody, text, innerW) * 19
    end
end

local function drawTooltip(tip)
    if not tip then return end
    local mx, my = mousePosition()
    Tooltip.draw(tip, mx, my)
end

local weaponCompareValue
local compareColor

local function diffText(delta, suffix)
    if math.abs(delta) < 0.001 then return "（±0" .. (suffix or "") .. "）" end
    local sign = delta > 0 and "+" or ""
    return "（" .. sign .. delta .. (suffix or "") .. "）"
end

local function weaponTooltip(weapon, titlePrefix, compareWeapon)
    local p = Game.player
    local brand = brands[weapon.brand]
    local elem = elements[weapon.element] or elements.kinetic
    local v = weaponCompareValue(weapon)
    local base = compareWeapon and weaponCompareValue(compareWeapon) or nil
    local function attr(label, value, key, higherBetter, suffix, gap)
        if not base then return {text = label .. "：" .. value .. (suffix or ""), color = C.white, gap = gap} end
        local delta = key == "cooldown" and tonumber(string.format("%.2f", v[key] - base[key])) or (v[key] - base[key])
        return {text = label .. "：" .. value .. (suffix or "") .. " " .. diffText(delta, suffix), color = compareColor(delta, higherBetter), gap = gap}
    end
    local lines = {
        {text = "品牌：" .. (brand and brand.name or "武器"), color = brand and brand.color or C.white},
        {text = "元素：" .. elem.name, color = elem.color},
        {text = "标签：" .. (brand and brand.tag or elem.desc), color = C.muted},
        attr("单发伤害", v.damage, "damage", true, nil, 6),
        attr("弹体数量", v.count, "count", true),
        attr("总伤害", v.totalDamage, "totalDamage", true),
        attr("冷却", string.format("%.2f", v.cooldown), "cooldown", false, "s"),
        attr("射程", v.range, "range", true),
        attr("弹速", v.speed, "speed", true),
        attr("穿透", v.pierce, "pierce", true),
        attr("弹射", v.bounce, "bounce", true),
        {text = "散布：" .. string.format("%.2f", weapon.spread or 0), color = C.white}
    }
    if compareWeapon then lines[#lines + 1] = {text = "差值基准：" .. (compareWeapon.name or "当前武器"), color = C.gold, gap = 6} end
    if weapon.splash then lines[#lines + 1] = {text = "特殊：爆炸半径 " .. weapon.splash, color = C.gold, gap = 6} end
    if weapon.chain then lines[#lines + 1] = {text = "特殊：连锁 " .. (weapon.chain + math.floor((p.stats.bounce or 0) / 2)) .. " 次", color = C.gold, gap = 6} end
    if weapon.aura then lines[#lines + 1] = {text = "特殊：牵引光环 " .. weapon.aura, color = C.gold, gap = 6} end
    if weapon.desc then lines[#lines + 1] = {text = "说明：" .. weapon.desc, color = C.muted, gap = 6} end
    return {title = (titlePrefix or "武器") .. "：" .. (weapon.name or "未知武器"), lines = lines, width = compareWeapon and 430 or 400}
end

weaponCompareValue = function(weapon)
    local p = Game.player
    return {
        damage = math.floor((weapon.damage or 0) * (p.stats.damage or 1) + 0.5),
        totalDamage = math.floor((weapon.damage or 0) * (p.stats.damage or 1) * (weapon.count or 1) + 0.5),
        cooldown = (weapon.cooldown or 0) / math.max(0.25, p.stats.fireRate or 1),
        range = math.floor((weapon.range or 0) * (p.stats.range or 1)),
        speed = math.floor((weapon.speed or 0) * (p.stats.projectileSpeed or 1)),
        pierce = weapon.pierce or 0,
        bounce = (weapon.bounce or 0) + (p.stats.bounce or 0),
        count = weapon.count or 1
    }
end

compareColor = function(delta, higherBetter)
    if math.abs(delta) < 0.001 then return C.muted end
    local good = higherBetter and delta > 0 or delta < 0
    return good and C.green or C.red
end

local function weaponComparisonLines(current, candidate)
    local a, b = weaponCompareValue(current), weaponCompareValue(candidate)
    local function line(label, old, new, delta, higherBetter, suffix)
        local sign = delta > 0 and "+" or ""
        return {text = label .. "  当前 " .. old .. " → 商品 " .. new .. "  (" .. sign .. delta .. (suffix or "") .. ")", color = compareColor(delta, higherBetter)}
    end
    return {
        {text = "对比选中武器：" .. (current.name or "当前武器"), color = C.gold, gap = 8},
        line("总伤", a.totalDamage, b.totalDamage, b.totalDamage - a.totalDamage, true),
        line("单发", a.damage, b.damage, b.damage - a.damage, true),
        line("冷却", string.format("%.2fs", a.cooldown), string.format("%.2fs", b.cooldown), tonumber(string.format("%.2f", b.cooldown - a.cooldown)), false, "s"),
        line("射程", a.range, b.range, b.range - a.range, true),
        line("弹速", a.speed, b.speed, b.speed - a.speed, true),
        line("穿透", a.pierce, b.pierce, b.pierce - a.pierce, true),
        line("弹射", a.bounce, b.bounce, b.bounce - a.bounce, true),
        line("数量", a.count, b.count, b.count - a.count, true)
    }
end

local function itemTooltip(item)
    if not item then return nil end
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local selected = Game.player.weapons[Game.selectedWeaponIndex or 1]
        local tip = weaponTooltip(def, "商品武器", selected)
        table.insert(tip.lines, 1, (rarityLabel[item.rarity] or item.rarity or "普通") .. " · 价格 " .. item.price .. " 材料")
        if not selected then
            tip.lines[#tip.lines + 1] = {text = "提示：先点击右侧武器槽，选择要对比的武器。", color = C.muted, gap = 8}
        end
        return tip
    end
    local kindText = kindLabel[item.kind] or item.kind or "道具"
    local rarityText = rarityLabel[item.rarity] or item.rarity or "普通"
    local lines = {
        rarityText .. " · " .. kindText .. (item.price and (" · 价格 " .. item.price .. " 材料") or ""),
        "效果：" .. modText(item.desc or "无说明")
    }
    if item.kind == "temp" then lines[#lines + 1] = "生效：仅下一波" else lines[#lines + 1] = "生效：本局永久" end
    if item.flag then lines[#lines + 1] = "特殊协议：" .. item.flag end
    return {title = "商品：" .. (item.name or "未知道具"), lines = lines}
end

local function drawShopCard(item, i, x, y, w, h)
    local mx, my = mousePosition()
    local hover = Game.state == "shop" and (Game.shopTab or "shop") == "shop" and hitRect(mx, my, x, y, w, h)
    if not item then
        local label = i <= 3 and ("武器架 " .. i) or ("装备箱 " .. (i - 3))
        drawMetalCard(x, y, w, h, C.white, false, false, false)
        love.graphics.setFont(Game.fonts.tiny)
        color(C.muted)
        love.graphics.printf(label, x + 18, y + 20, w - 36, "left")
        color(C.white, 0.045)
        love.graphics.rectangle("fill", x + 18, y + 72, w - 36, 92, 14, 14)
        color(C.white, 0.18)
        love.graphics.rectangle("line", x + 18.5, y + 72.5, w - 37, 91, 14, 14)
        love.graphics.setFont(Game.fonts.normal)
        color(C.muted, 0.80)
        love.graphics.printf("售罄", x + 18, y + 101, w - 36, "center")
        love.graphics.setFont(Game.fonts.tiny)
        color(C.muted)
        love.graphics.printf("刷新商店后补货", x + 18, y + 144, w - 36, "center")
        color(C.white, 0.05)
        love.graphics.rectangle("fill", x + 18, y + h - 36, w - 36, 28, 10, 10)
        color(C.muted, 0.34)
        love.graphics.rectangle("line", x + 18, y + h - 36, w - 36, 28, 10, 10)
        centeredText("已售罄", x + 18, y + h - 36, w - 36, 28, Game.fonts.tiny, C.muted, "center")
        return nil
    end

    local rarity = item.rarity or "common"
    local rc = rarityColor[rarity] or C.white
    local affordable = Game.coins >= item.price
    local accent = shopItemAccent(item)
    local drawnY = drawMetalCard(x, y, w, h, accent, hover, Game.locked[i], rarity == "rare" or rarity == "epic" or rarity == "legend")
    y = drawnY

    local rarityText = rarityLabel[rarity] or rarity
    local kindText = kindLabel[item.kind] or item.kind
    local shelfText = item.kind == "weapon" and ("武器架 " .. i) or ("装备箱 " .. (i - 3))
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(shelfText, x + 18, y + 19, 68, "left")
    local tagX = x + 86
    tagX = tagX + tagPill(rarityText, tagX, y + 13, rc, C.bgA) + 6
    tagPill(kindText, tagX, y + 13, accent, C.bgA)
    color(affordable and C.gold or C.muted)
    love.graphics.printf(item.price .. " 材", x + w - 128, y + 19, 72, "right")
    local topLockX, topLockY = x + w - 48, y + 13
    color(C.white, Game.locked[i] and 0.16 or 0.05)
    love.graphics.rectangle("fill", topLockX, topLockY, 30, 24, 8, 8)
    color(Game.locked[i] and C.white or C.muted, Game.locked[i] and 0.82 or 0.42)
    if Game.locked[i] then
        love.graphics.setFont(Game.fonts.tiny)
        love.graphics.printf("锁", topLockX, topLockY + 5, 30, "center")
    else
        love.graphics.rectangle("line", topLockX + 9, topLockY + 7, 12, 10, 2, 2)
        love.graphics.arc("line", topLockX + 15, topLockY + 8, 5, math.pi, TAU)
    end

    local identityY = y + 48
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local brand = brands[def.brand]
        local elem = elements[def.element]
        local tx = x + 18
        tx = tx + tagPill(brand.name, tx, identityY, brand.color, C.bgA) + 8
        tagPill(elem.name, tx, identityY, elem.color, C.bgA)
    else
        tagPill(item.kind == "shield" and "护盾组件" or "构筑装备", x + 18, identityY, accent, C.bgA)
    end

    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(compactDesc(item.name, 16), x + 18, y + 80, w - 36, "left")
    love.graphics.setFont(Game.fonts.tiny)
    local desc = compactDesc(item.desc, 30)
    color(C.muted)
    love.graphics.printf(desc, x + 18, y + 112, w - 36, "left")

    local displayY, displayH = y + 144, 36
    color(C.white, 0.045)
    love.graphics.rectangle("fill", x + 18, displayY, w - 36, displayH, 12, 12)
    color(C.white, 0.18)
    love.graphics.rectangle("line", x + 18.5, displayY + 0.5, w - 37, displayH - 1, 12, 12)

    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        color(C.white)
        love.graphics.printf(def.damage .. " 伤害", x + 34, displayY + 11, 88, "left")
        color(C.muted)
        love.graphics.printf(string.format("%.2f", def.cooldown) .. " CD", x + 122, displayY + 11, 82, "left")
        love.graphics.printf(math.floor(def.range or 0) .. " 射程", x + 204, displayY + 11, w - 238, "left")
    else
        color(C.white)
        love.graphics.printf(compactDesc(item.desc, 34), x + 34, displayY + 11, w - 68, "left")
    end

    local buyY = y + h - 36
    local buyColor = affordable and C.gold or C.muted
    color(buyColor, hover and 0.18 or 0.075)
    love.graphics.rectangle("fill", x + 18, buyY, w - 36, 28, 10, 10)
    color(buyColor, hover and 0.64 or 0.30)
    love.graphics.rectangle("line", x + 18, buyY, w - 36, 28, 10, 10)
    centeredText("购买 " .. i, x + 18, buyY, w - 36, 28, Game.fonts.tiny, buyColor, "center")

    if Game.shopRollTimer and Game.shopRollTimer > 0 then
        local a = clamp(Game.shopRollTimer / 0.55, 0, 1)
        color(C.cyan, 0.08 + a * 0.14)
        for yy = y + 18, y + h - 20, 24 do love.graphics.rectangle("fill", x + 10, yy, w - 20, 2, 2, 2) end
    end

    if not affordable then
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    end
    if hover then
        local tip = itemTooltip(item)
        if tip then tip.anchor = {x = x, y = y, w = w, h = h}; tip.width = 400 end
        return tip
    end
    return nil
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
        {"元素", pct(p.stats.elementDamage or 1)}, {"经济", pct(p.stats.economy or 1)}, {"幸运", p.stats.luck}
    }
    for i, row in ipairs(rows) do
        local rowY = y + 54 + (i - 1) * 32
        local rowH = 24
        color(C.white, 0.08)
        love.graphics.rectangle("fill", x + 14, rowY, w - 28, rowH, 7, 7)
        centeredText(row[1], x + 26, rowY, 76, rowH, Game.fonts.tiny, C.muted, "left")
        centeredText(tostring(row[2]), x + 104, rowY, w - 138, rowH, Game.fonts.tiny, C.white, "right")
    end

    local wy = y + h - 84
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, wy - 12, w - 28, 1)
    color(C.gold)
    love.graphics.printf("武器", x, wy, w, "center")
    color(C.muted)
    local names = {}
    for i, weapon in ipairs(p.weapons) do
        names[#names + 1] = weapon.name .. " 等级" .. weapon.level
        if i >= 4 then break end
    end
    love.graphics.printf(table.concat(names, " / "), x + 16, wy + 22, w - 32, "center")
end

local sellWeapon, sellShield, sellItem

local function drawCompactBuildPanel(x, y, w, h, opts)
    local p = Game.player
    opts = opts or {}
    local showSell = opts.showSell ~= false
    love.graphics.setColor(0.04, 0.08, 0.14, 0.58)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    color(C.cyan, 0.18)
    love.graphics.rectangle("fill", x + 6, y + 6, w - 12, h - 12, 16, 16)
    color(C.cyan, 0.34)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 18, 18)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("当前构筑", x + 14, y + 8, w - 28, "left")
    local slotX = x + w - 108
    for i = 1, 4 do
        local filled = i <= #p.weapons
        color(filled and C.orange or C.white, filled and 0.76 or 0.12)
        love.graphics.rectangle("fill", slotX + (i - 1) * 22, y + 12, 16, 8, 4, 4)
    end
    love.graphics.setFont(Game.fonts.tiny)
    local vitalW = (w - 36) / 2
    color(C.pink, 0.26)
    love.graphics.rectangle("fill", x + 14, y + 34, vitalW, 32, 10, 10)
    color(C.cyan, 0.26)
    love.graphics.rectangle("fill", x + 22 + vitalW, y + 34, vitalW, 32, 10, 10)
    love.graphics.setFont(Game.fonts.small)
    color(C.pink)
    love.graphics.printf(math.ceil(p.hp) .. "/" .. p.maxHp, x + 18, y + 40, vitalW - 8, "center")
    color(C.cyan)
    love.graphics.printf(math.ceil(p.shield) .. "/" .. p.maxShield, x + 26 + vitalW, y + 40, vitalW - 8, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("生命", x + 18, y + 66, vitalW - 8, "center")
    love.graphics.printf("护盾", x + 26 + vitalW, y + 66, vitalW - 8, "center")
    local mx, my = mousePosition()
    local activeBuildTab = Game.buildPanelTab or "stats"
    local tabY, tabW, tabH = y + 92, 108, 26
    local tabs = {{id = "stats", label = "基础属性"}, {id = "items", label = "道具槽"}}
    love.graphics.setFont(Game.fonts.tiny)
    for i, tab in ipairs(tabs) do
        local tx = x + 14 + (i - 1) * (tabW + 8)
        local active = activeBuildTab == tab.id
        color(active and C.gold or C.white, active and 0.20 or 0.06)
        love.graphics.rectangle("fill", tx, tabY, tabW, tabH, 8, 8)
        color(active and C.gold or C.muted, active and 0.72 or 0.36)
        love.graphics.rectangle("line", tx + 0.5, tabY + 0.5, tabW - 1, tabH - 1, 8, 8)
        textInBox(tab.label, tx, tabY, tabW, tabH, Game.fonts.tiny, active and C.gold or C.muted, "center")
    end

    local slotW = (w - 44) / 2
    local slotGap = 12
    if activeBuildTab == "items" then
        local items = p.items or {}
        local itemY = y + 146
        color(C.gold)
        love.graphics.printf("道具槽 " .. #items, x + 14, itemY - 28, w - 28, "left")
        color(C.muted)
        love.graphics.printf("道具槽已单独分页；卖出按钮只在本页显示。", x + 118, itemY - 28, w - 132, "right")
        for i = 1, math.min(#items, 18) do
            local item = items[i]
            local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
            local sy = itemY + math.floor((i - 1) / 2) * 38
            local accent = shopItemAccent(item)
            color(accent, 0.12)
            love.graphics.rectangle("fill", sx, sy, slotW, 30, 8, 8)
            color(accent, 0.40)
            love.graphics.rectangle("line", sx + 0.5, sy + 0.5, slotW - 1, 29, 8, 8)
            color(C.white)
            textInBox(compactDesc(item.name, showSell and 9 or 13), sx + 10, sy, slotW - (showSell and 54 or 20), 30, Game.fonts.tiny, C.white, "left")
            if showSell then
                color(C.red, 0.14)
                love.graphics.rectangle("fill", sx + slotW - 40, sy + 5, 30, 20, 7, 7)
                color(C.red, 0.58)
                love.graphics.rectangle("line", sx + slotW - 40, sy + 5, 30, 20, 7, 7)
                textInBox("卖", sx + slotW - 40, sy + 5, 30, 20, Game.fonts.tiny, C.red, "center")
            end
            if hitRect(mx, my, sx, sy, slotW, 30) then
                local tip = itemTooltip(item)
                tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击右侧“卖”出售道具。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
                return tip
            end
        end
        if #items == 0 then
            color(C.white, 0.05)
            love.graphics.rectangle("fill", x + 14, itemY, w - 28, 34, 8, 8)
            color(C.muted)
            textInBox("暂无道具", x + 26, itemY, w - 52, 34, Game.fonts.tiny, C.muted, "left")
        end
        return nil
    end

    local stats = {
        {"伤害", pct(p.stats.damage)}, {"射速", pct(p.stats.fireRate)},
        {"暴击", pct(p.stats.crit)}, {"暴伤", pct(p.stats.critDamage)},
        {"元素", pct(p.stats.elementDamage or 1)}, {"对盾", pct(p.stats.shieldDamage or 1)},
        {"对甲", pct(p.stats.armorDamage or 1)}, {"对肉", pct(p.stats.fleshDamage or 1)},
        {"护甲", tostring(p.stats.armor)}, {"闪避", pct(p.stats.dodge)},
        {"吸血", pct(p.stats.lifesteal)}, {"幸运", tostring(p.stats.luck or 0)},
        {"材料", "×" .. string.format("%.2f", p.stats.economy or 1)}, {"收获", tostring(p.stats.harvest or 0)},
        {"弹射", tostring(p.stats.bounce or 0)}, {"弹速", pct(p.stats.projectileSpeed or 1)}
    }
    for i, row in ipairs(stats) do
        local sx = x + 14 + ((i - 1) % 2) * ((w - 36) / 2 + 8)
        local sy = y + 130 + math.floor((i - 1) / 2) * 22
        color(C.white, 0.06)
        love.graphics.rectangle("fill", sx, sy, (w - 44) / 2, 18, 6, 6)
        color(C.muted)
        textInBox(row[1], sx + 8, sy, 46, 18, Game.fonts.tiny, C.muted, "left")
        color(C.white)
        textInBox(row[2], sx + 58, sy, (w - 132) / 2, 18, Game.fonts.tiny, C.white, "right")
    end

    love.graphics.setFont(Game.fonts.tiny)

    local weaponLabelY = y + 326
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, weaponLabelY - 12, w - 28, 1)
    color(C.orange)
    love.graphics.printf("武器槽 " .. #p.weapons .. "/4", x + 14, weaponLabelY, w - 28, "left")
    local weaponY = weaponLabelY + 30
    for i = 1, 4 do
        local weapon = p.weapons[i]
        local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
        local sy = weaponY + math.floor((i - 1) / 2) * 42
        local accent = weapon and (elements[weapon.element] or elements.kinetic).color or C.white
        local selected = weapon and i == (Game.selectedWeaponIndex or 1)
        color(accent, weapon and 0.13 or 0.05)
        love.graphics.rectangle("fill", sx, sy, slotW, 34, 9, 9)
        color(selected and C.gold or accent, selected and 0.78 or (weapon and 0.44 or 0.18))
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", sx + 0.5, sy + 0.5, slotW - 1, 33, 9, 9)
        love.graphics.setLineWidth(1)
        color(weapon and C.white or C.muted)
        textInBox(weapon and compactDesc(weapon.name .. " Lv" .. weapon.level, showSell and 10 or 14) or "空武器", sx + 10, sy, slotW - (showSell and 56 or 20), 34, Game.fonts.tiny, weapon and C.white or C.muted, "left")
        if weapon and showSell then
            color(C.red, 0.14)
            love.graphics.rectangle("fill", sx + slotW - 42, sy + 6, 32, 22, 7, 7)
            color(C.red, 0.58)
            love.graphics.rectangle("line", sx + slotW - 42, sy + 6, 32, 22, 7, 7)
            textInBox("卖", sx + slotW - 42, sy + 6, 32, 22, Game.fonts.tiny, C.red, "center")
        end
        if weapon and hitRect(mx, my, sx, sy, slotW, 34) then
            local tip = weaponTooltip(weapon, selected and "当前武器 · 对比中" or "当前武器")
            tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击槽位选中；点击右侧“卖”出售。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
            return tip
        end
    end

    local shieldLabelY = y + 466
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, shieldLabelY - 12, w - 28, 1)
    color(C.cyan)
    love.graphics.printf("护盾槽", x + 14, shieldLabelY, w - 28, "left")
    local shieldY = shieldLabelY + 30
    local shield = p.shieldItem
    color(C.cyan, shield and 0.16 or 0.07)
    love.graphics.rectangle("fill", x + 14, shieldY, w - 28, 42, 10, 10)
    color(C.cyan, shield and 0.52 or 0.22)
    love.graphics.rectangle("line", x + 14.5, shieldY + 0.5, w - 29, 41, 10, 10)
    color(shield and C.white or C.muted)
    textInBox(shield and compactDesc(shield.name, showSell and 16 or 22) or "空护盾槽", x + 26, shieldY, w - (showSell and 118 or 92), 42, Game.fonts.tiny, shield and C.white or C.muted, "left")
    if shield and showSell then
        color(C.red, 0.14)
        love.graphics.rectangle("fill", x + w - 66, shieldY + 9, 38, 24, 7, 7)
        color(C.red, 0.58)
        love.graphics.rectangle("line", x + w - 66, shieldY + 9, 38, 24, 7, 7)
        textInBox("卖", x + w - 66, shieldY + 9, 38, 24, Game.fonts.tiny, C.red, "center")
    else
        color(C.cyan)
        textInBox(shield and "1/1" or "0/1", x + w - 72, shieldY, 44, 42, Game.fonts.tiny, C.cyan, "right")
    end
    if shield and hitRect(mx, my, x + 14, shieldY, w - 28, 42) then
        local tip = itemTooltip(shield)
        tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击右侧“卖”出售护盾。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
        return tip
    end

end

local function handleBuildPanelClick(px, py, x, y, w, h)
    local p = Game.player
    local slotW = (w - 44) / 2
    local slotGap = 12
    local tabY, tabW, tabH = y + 92, 108, 26
    if hitRect(px, py, x + 14, tabY, tabW, tabH) then Game.buildPanelTab = "stats"; playCue("shop"); return true end
    if hitRect(px, py, x + 14 + tabW + 8, tabY, tabW, tabH) then Game.buildPanelTab = "items"; playCue("shop"); return true end
    if (Game.buildPanelTab or "stats") == "items" then
        local itemY = y + 146
        for i = 1, math.min(#(p.items or {}), 18) do
            local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
            local sy = itemY + math.floor((i - 1) / 2) * 38
            if hitRect(px, py, sx + slotW - 40, sy + 5, 30, 20) then return sellItem(i) end
        end
        return false
    end
    local weaponLabelY = y + 326
    local weaponY = weaponLabelY + 30
    for i = 1, 4 do
        local weapon = p.weapons[i]
        local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
        local sy = weaponY + math.floor((i - 1) / 2) * 42
        if weapon and hitRect(px, py, sx, sy, slotW, 34) then
            if hitRect(px, py, sx + slotW - 42, sy + 6, 32, 22) then return sellWeapon(i) end
            Game.selectedWeaponIndex = i
            playCue("shop"); toast("已选中武器槽 " .. i .. "：" .. weapon.name)
            return true
        end
    end

    local shieldLabelY = y + 466
    local shieldY = shieldLabelY + 30
    if p.shieldItem and hitRect(px, py, x + w - 66, shieldY + 9, 38, 24) then return sellShield() end
    return false
end

local function defenseText(def)
    if def.defense == "armor" then return "护甲" end
    if def.defense == "shield" then return "护盾" end
    if def.defense == "flesh" then return "轻甲" end
    return "普通"
end

local function drawAffixInfoPill(affix, label, x, y, w, h, mx, my)
    local accent = affix.kind == "penalty" and C.red or C.green
    color(accent, 0.16)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    color(accent, 0.58)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 10, 10)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(label, x + 12, y + 7, w - 24, "left")
    color(accent)
    love.graphics.printf(affix.name .. " · " .. affix.desc, x + 12, y + 27, w - 24, "left")
    color(C.white, 0.55)
    love.graphics.printf("?", x + w - 26, y + 7, 16, "center")
    if hitRect(mx, my, x, y, w, h) then
        return {title = label .. "词条：" .. affix.name, lines = affixDetailLines(affix)}
    end
end

local function drawNextWavePanel(x, y, w, h)
    local mx, my = mousePosition()
    local tip = nil
    local plan = wavePlanAt(Game.wave)
    local reward, penalty = affixesAt(Game.wave)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("下一波情报", x + 24, y + 18, w - 48, "left")
    color(C.gold)
    love.graphics.printf("第 " .. Game.wave .. " 波 · " .. (plan.name or "生存波次"), x + 24, y + 54, w - 48, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("生存 30 秒 · 根据词条和敌群选择临时道具", x + 24, y + 84, w - 48, "left")

    local pillW = (w - 62) / 2
    if reward then tip = drawAffixInfoPill(reward, "奖励", x + 24, y + 122, pillW, 58, mx, my) or tip end
    if penalty then tip = drawAffixInfoPill(penalty, "惩罚", x + 38 + pillW, y + 122, pillW, 58, mx, my) or tip end

    love.graphics.setFont(Game.fonts.tiny)
    color(C.white)
    love.graphics.printf("敌人构成", x + 24, y + 208, w - 48, "left")
    local rowY = y + 236
    local total = 0
    for _, entry in ipairs(plan.enemies or {}) do total = total + (entry[2] or 0) end
    for i, entry in ipairs(plan.enemies or {}) do
        local key, weight = entry[1], entry[2]
        local def = enemyDefs[key]
        if def and i <= 3 then
            local chance = total > 0 and math.floor(weight / total * 100 + 0.5) or weight
            color(def.color, 0.16)
            love.graphics.rectangle("fill", x + 24, rowY, w - 48, 24, 7, 7)
            color(def.color)
            love.graphics.printf(def.name, x + 36, rowY + 6, 112, "left")
            color(C.muted)
            love.graphics.printf(chance .. "% · " .. defenseText(def) .. " · 伤害 " .. def.damage, x + 156, rowY + 6, w - 196, "left")
            rowY = rowY + 32
        end
    end
    local events = plan.events or {}
    if #events > 0 then
        color(C.gold)
        local parts = {}
        for i, event in ipairs(events) do
            local def = enemyDefs[event.enemy]
            if def and i <= 3 then parts[#parts + 1] = math.floor(event.time) .. "s " .. def.name end
        end
        love.graphics.printf("事件敌人：" .. table.concat(parts, " / "), x + 24, y + h - 44, w - 48, "left")
    else
        color(C.muted)
        love.graphics.printf("无固定事件敌人", x + 24, y + h - 44, w - 48, "left")
    end
    return tip
end

local function drawSlotMachinePanel(x, y, w, h)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.white)
    love.graphics.printf("补给转轮", x + 12, y + 8, 64, "left")
    local milestone = slotMilestone()
    local unlocked = slotUnlocked()
    local free = slotHasFreeUse()
    color(unlocked and C.gold or C.muted)
    local status = unlocked and ("第 " .. milestone .. " 关奖励机 · " .. (free and "本轮免费" or ("消耗 " .. slotSpinCost() .. " 材料"))) or "第 5 关后解锁"
    love.graphics.printf(status, x + 72, y + 8, w - 140, "left")

    local reels = Game.slotResult and Game.slotResult.reels or nil
    local reelW, reelH, gap = 36, 30, 6
    local rx = x + 12
    local ry = y + 32
    for i = 1, 3 do
        local sym = reels and reels[i]
        color(sym and sym.color or C.white, sym and 0.20 or 0.08)
        love.graphics.rectangle("fill", rx + (i - 1) * (reelW + gap), ry, reelW, reelH, 10, 10)
        color(sym and sym.color or C.muted, unlocked and 0.74 or 0.30)
        love.graphics.rectangle("line", rx + (i - 1) * (reelW + gap), ry, reelW, reelH, 10, 10)
        love.graphics.setFont(Game.fonts.tiny)
        love.graphics.printf(sym and sym.mark or "?", rx + (i - 1) * (reelW + gap), ry + 8, reelW, "center")
    end
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(Game.slotResult and Game.slotResult.text or "三符奖励 / 双符奖励 / 基础补给返材料", x + 142, y + 34, w - 246, "left")

    local by = y + 28
    local label = unlocked and (free and "免费启动" or ("启动 · " .. slotSpinCost())) or "未解锁"
    uiButton(label, x + w - 94, by, 80, 34, unlocked and C.gold or C.white, C.white, Game.fonts.tiny)
end

local function drawSlotTabContent(x, y, w, h)
    panel(x, y, w, h)
    local milestone = slotMilestone()
    local unlocked = slotUnlocked()
    local free = slotHasFreeUse()
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf("补给转轮", x + 28, y + 26, w - 56, "left")
    love.graphics.setFont(Game.fonts.small)
    color(unlocked and C.gold or C.muted)
    local status = unlocked and ("第 " .. milestone .. " 关奖励机 · " .. (free and "本轮免费 1 次" or ("本次消耗 " .. slotSpinCost() .. " 材料"))) or "清完第 5 关后解锁；之后每 5 关补 1 次免费启动"
    love.graphics.printf(status, x + 28, y + 66, w - 56, "left")

    local reels = Game.slotResult and Game.slotResult.reels or nil
    local reelW, reelH, gap = 116, 96, 22
    local totalW = reelW * 3 + gap * 2
    local rx = x + w / 2 - totalW / 2
    local ry = y + 126
    for i = 1, 3 do
        local sym = reels and reels[i]
        local sx = rx + (i - 1) * (reelW + gap)
        color(sym and sym.color or C.white, sym and 0.22 or 0.08)
        love.graphics.rectangle("fill", sx, ry, reelW, reelH, 18, 18)
        color(sym and sym.color or C.muted, unlocked and 0.80 or 0.36)
        love.graphics.rectangle("line", sx + 0.5, ry + 0.5, reelW - 1, reelH - 1, 18, 18)
        love.graphics.setFont(Game.fonts.big)
        love.graphics.printf(sym and sym.mark or "?", sx, ry + 18, reelW, "center")
        love.graphics.setFont(Game.fonts.tiny)
        color(sym and sym.color or C.muted)
        love.graphics.printf(sym and sym.name or "待转动", sx, ry + 70, reelW, "center")
    end

    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(Game.slotResult and Game.slotResult.text or "三符奖励，双符奖励，基础补给返材料。奖励会直接给材料/治疗，或以 0 材料商品放入商店。", x + 28, y + 248, w - 56, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("符号：材料、武器、战术、护盾、修复、稀有。补给转轮只影响商店阶段，不会替你自动进入下一波。", x + 28, y + 292, w - 56, "center")

    local buttonW, buttonH = 320, 64
    local label = unlocked and (free and "免费启动" or ("启动 · " .. slotSpinCost() .. " 材料")) or "未解锁"
    uiButton(label, x + w / 2 - buttonW / 2, y + h - 96, buttonW, buttonH, unlocked and C.gold or C.white, C.white, Game.fonts.normal)
end

local function drawVersion()
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted, 0.72)
    love.graphics.printf(VERSION, 0, Game.h - 28, Game.w - 30, "right")
end

local shopTabs = {
    {id = "shop", label = "商店"},
    {id = "intel", label = "下一波情报"},
    {id = "slot", label = "补给转轮"}
}

local function drawShopTabs(x, y)
    local active = Game.shopTab or "shop"
    local tabW, tabH, gap = 168, 44, 12
    for i, tab in ipairs(shopTabs) do
        local tx = x + (i - 1) * (tabW + gap)
        local isActive = active == tab.id
        color(isActive and C.gold or C.white, isActive and 0.24 or 0.08)
        love.graphics.rectangle("fill", tx, y, tabW, tabH, 11, 11)
        color(isActive and C.gold or C.muted, isActive and 0.74 or 0.40)
        love.graphics.rectangle("line", tx + 0.5, y + 0.5, tabW - 1, tabH - 1, 11, 11)
        centeredText(tab.label, tx, y, tabW, tabH, Game.fonts.small, isActive and C.gold or C.muted, "center")
    end
end

local function shopTabHit(x, y)
    local startX, startY = 40, 38
    local tabW, tabH, gap = 168, 44, 12
    for i, tab in ipairs(shopTabs) do
        local tx = startX + (i - 1) * (tabW + gap)
        if hitRect(x, y, tx, startY, tabW, tabH) then return tab.id end
    end
end

local function drawBuildTabContent(x, y, w, h)
    local p = Game.player
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf("当前构筑数值", x + 18, y + 16, w - 36, "left")

    love.graphics.setFont(Game.fonts.tiny)
    local rows = {
        {"生命", math.ceil(p.hp) .. " / " .. p.maxHp}, {"护盾", math.ceil(p.shield) .. " / " .. p.maxShield},
        {"护盾回复", string.format("%.1f/s", p.shieldRegen)}, {"护甲", tostring(p.stats.armor)},
        {"移速", tostring(math.floor(p.speed))}, {"闪避", pct(p.stats.dodge)},
        {"暴击", pct(p.stats.crit)}, {"暴伤", pct(p.stats.critDamage)},
        {"元素伤", pct(p.stats.elementDamage or 1)}, {"材料率", "×" .. string.format("%.2f", p.stats.economy or 1)}
    }
    local sx, sy = x + 18, y + 56
    local cellW, cellH = 166, 26
    for i, row in ipairs(rows) do
        local col = (i - 1) % 5
        local line = math.floor((i - 1) / 5)
        local rx, ry = sx + col * (cellW + 8), sy + line * (cellH + 8)
        color(C.white, 0.07)
        love.graphics.rectangle("fill", rx, ry, cellW, cellH, 8, 8)
        centeredText(row[1], rx + 10, ry, 58, cellH, Game.fonts.tiny, C.muted, "left")
        centeredText(row[2], rx + 70, ry, cellW - 82, cellH, Game.fonts.tiny, C.white, "right")
    end

    color(C.gold)
    love.graphics.printf("武器卡片", x + 18, y + 142, w - 36, "left")
    local cardW, cardH, gap = (w - 54) / 2, 88, 16
    for i, weapon in ipairs(p.weapons) do
        if i > 4 then break end
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local wx, wy = x + 18 + col * (cardW + gap), y + 174 + row * (cardH + 14)
        local elem = elements[weapon.element] or elements.kinetic
        local brand = brands[weapon.brand]
        color(elem.color, 0.12)
        love.graphics.rectangle("fill", wx, wy, cardW, cardH, 12, 12)
        color(elem.color, 0.48)
        love.graphics.rectangle("line", wx + 0.5, wy + 0.5, cardW - 1, cardH - 1, 12, 12)
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf(weapon.name .. " Lv" .. weapon.level, wx + 14, wy + 10, cardW - 28, "left")
        love.graphics.setFont(Game.fonts.tiny)
        color(brand and brand.color or C.gold)
        love.graphics.printf((brand and brand.name or "武器") .. " · " .. elem.name, wx + 14, wy + 36, cardW - 28, "left")
        color(C.muted)
        local actualDamage = math.floor((weapon.damage or 0) * (p.stats.damage or 1) + 0.5)
        local detail = "伤害 " .. actualDamage .. "×" .. (weapon.count or 1) .. "  冷却 " .. string.format("%.2f", weapon.cooldown or 0) .. "s  范围 " .. math.floor(weapon.range or 0)
        local extra = "穿透 " .. (weapon.pierce or p.stats.pierce or 0) .. "  弹射 " .. (weapon.bounce or 0) .. "  弹速 " .. math.floor(weapon.speed or 0)
        love.graphics.printf(detail, wx + 14, wy + 56, cardW - 28, "left")
        love.graphics.printf(extra, wx + 14, wy + 72, cardW - 28, "left")
    end
end

local function drawShop()
    panel(18, 18, Game.w - 36, Game.h - 36)
    local clearedWave = math.max(1, Game.wave - 1)
    local marginX = 40
    local tabY = 38
    local contentY, contentH = 154, Game.h - 200
    local actionY, actionH = 38, 42
    local refreshW, nextW, sellW, actionGap = 210, 220, 220, 12
    local actionX = Game.w - marginX - refreshW - nextW - sellW - actionGap * 2
    drawShopTabs(marginX, tabY)

    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    local infoX, infoW = 590, actionX - 610
    love.graphics.printf("商店 / 第 " .. clearedWave .. " 波战后补给", infoX, 38, infoW, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    local shieldText = Game.player.shieldItem and "护盾槽 1/1" or "护盾槽 0/1"
    love.graphics.printf("武器槽 " .. #Game.player.weapons .. "/4 · " .. shieldText .. " · 道具槽 " .. #(Game.player.items or {}) .. " · 购买后售罄，刷新后补货", infoX, 74, infoW, "center")

    local rerollCost = 3 + Game.shopRefresh * 2
    local refreshText = Game.freeRefresh > 0 and ("免费刷新 " .. Game.freeRefresh .. " 次") or ("刷新 " .. rerollCost .. " 材料")
    uiButton(refreshText, actionX, actionY, refreshW, actionH, C.cyan)
    uiButton("进入下一波", actionX + refreshW + actionGap, actionY, nextW, actionH, C.gold, C.white, Game.fonts.small)
    uiButton("卖出选中武器", actionX + refreshW + actionGap + nextW + actionGap, actionY, sellW, actionH, C.white)

    color(C.white, 0.08)
    love.graphics.rectangle("fill", marginX, 108, Game.w - marginX * 2, 1)

    love.graphics.setFont(Game.fonts.small)
    local active = Game.shopTab or "shop"
    local tip = nil

    if active == "intel" then
        tip = drawNextWavePanel(marginX, contentY, Game.w - marginX * 2, contentH)
    elseif active == "slot" then
        drawSlotTabContent(marginX, contentY, Game.w - marginX * 2, contentH)
    else
        local gap = 28
        local sideW = 430
        local sideGap = 32
        local sideX = Game.w - marginX - sideW
        local shelfW = sideX - marginX - sideGap
        local cardW = (shelfW - gap * 2) / 3
        local cardH = 268
        local weaponY = 204
        local supportY = 554
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf("武器架 · 3 选 1", marginX, weaponY - 34, shelfW, "left")
        color(C.white, 0.08)
        love.graphics.rectangle("fill", marginX, weaponY - 8, shelfW, 10, 5, 5)
        color(C.white, 0.16)
        love.graphics.rectangle("fill", marginX, weaponY + cardH + 10, shelfW, 8, 4, 4)
        color(C.white)
        love.graphics.printf("装备箱 · 道具 / 护盾 / 战术", marginX, supportY - 34, shelfW, "left")
        color(C.white, 0.07)
        love.graphics.rectangle("fill", marginX, supportY - 8, shelfW, 10, 5, 5)
        color(C.white, 0.14)
        love.graphics.rectangle("fill", marginX, supportY + cardH + 10, shelfW, 8, 4, 4)
        for i = 1, 6 do
            local item = Game.shop[i]
            local col = (i - 1) % 3
            local rowY = i <= 3 and weaponY or supportY
            local x = marginX + col * (cardW + gap)
            local y = rowY
            tip = drawShopCard(item, i, x, y, cardW, cardH) or tip
        end
        tip = drawCompactBuildPanel(sideX, contentY, sideW, contentH) or tip
    end

    drawTooltip(tip)
end

local function drawPauseOverlay()
    love.graphics.setColor(0, 0, 0, 0.58)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    local x, y, w, h = Game.w / 2 - 510, Game.h / 2 - 345, 1020, 690
    panel(x, y, w, h)
    local leftW, gap = 420, 28
    local rightX, rightW = x + leftW + gap, w - leftW - gap - 24

    love.graphics.setFont(Game.fonts.big)
    color(C.gold)
    love.graphics.printf("暂停", x + 28, y + 38, leftW - 56, "left")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("战斗已冻结 · Esc 继续", x + 28, y + 104, leftW - 56, "left")
    uiButton("继续游戏", x + 40, y + 180, leftW - 80, 58, C.cyan, C.white, Game.fonts.normal)
    uiButton("设置", x + 40, y + 260, leftW - 80, 52, C.white, C.white, Game.fonts.small)
    uiButton("退出本局", x + 40, y + 334, leftW - 80, 52, C.red, C.white, Game.fonts.small)

    color(C.white, 0.10)
    love.graphics.rectangle("fill", x + leftW + 10, y + 28, 1, h - 56)
    drawCompactBuildPanel(rightX, y + 28, rightW, h - 56, {showSell = false})
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
    love.graphics.printf("波次 " .. Game.wave .. "   击杀 " .. Game.kills .. "   材料 " .. Game.coins, Game.w / 2 - 300, 355, 600, "center")
    color(C.cyan)
    love.graphics.printf("总伤害 " .. math.floor(Game.runStats.damage or 0) .. "   收入 " .. math.floor(Game.runStats.coinsEarned or 0) .. "   危险 " .. Game.danger, Game.w / 2 - 300, 388, 600, "center")
    color(C.muted)
    love.graphics.printf("回车回到选择界面 / Esc 退出", Game.w / 2 - 300, 425, 600, "center")
end

function love.draw()
    love.graphics.clear(C.bgA)
    local scale, vx, vy, sw, sh = viewportTransform()
    if vx > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, vx, sh)
        love.graphics.rectangle("fill", vx + VIRTUAL_W * scale, 0, sw - vx - VIRTUAL_W * scale, sh)
    end
    if vy > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, sw, vy)
        love.graphics.rectangle("fill", 0, vy + VIRTUAL_H * scale, sw, sh - vy - VIRTUAL_H * scale)
    end

    local ox, oy = 0, 0
    if Game.shake > 0 then ox, oy = rnd(-5, 5) * Game.shake * 3, rnd(-5, 5) * Game.shake * 3 end
    love.graphics.push()
    love.graphics.translate(vx, vy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(ox, oy)
    drawBackground()
    if Game.state == "menu" then drawMenu(); drawVersion(); love.graphics.pop(); return end
    if Game.state == "shop" then drawShop(); drawVersion(); love.graphics.pop(); return end
    if Game.state == "levelup" then drawWorld(); drawHud(); drawLevelUp(); drawVersion(); love.graphics.pop(); return end
    drawWorld()
    drawHud()
    if Game.state == "paused" then drawPauseOverlay(); love.graphics.pop(); return end
    if Game.messageTimer > 0 then
        local toastY = 140
        panel(Game.w / 2 - 260, toastY, 520, 40)
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf(Game.message, Game.w / 2 - 250, toastY + 11, 500, "center")
    end
    if Game.state == "gameover" then drawEnd("机体失控", "构筑失败。虚空可没那么温柔。", C.red) end
    if Game.state == "victory" then drawEnd("通关完成", "核心稳定，战场清空。", C.gold) end
    drawVersion()
    love.graphics.pop()
end

local function buySlot(i)
    local item = Game.shop[i]
    if not item then toast("该商品已售罄：刷新商店后补货"); return end
    if Game.coins < item.price then toast("材料不足") return end
    local ok = true
    if item.buy then ok = item.buy() ~= false end
    if not ok then return end
    Game.coins = Game.coins - item.price
    Game.shop[i] = nil
    Game.locked[i] = false
end

local function sellValue(item, fallback)
    return math.max(1, math.floor(((item and item.price) or fallback or 12) * 0.45 + 0.5))
end

sellWeapon = function(index)
    local p = Game.player
    index = index or Game.selectedWeaponIndex or #p.weapons
    local w = p.weapons[index]
    if not w then toast("该武器槽为空") return false end
    table.remove(p.weapons, index)
    local value = math.max(8, sellValue(w, 20) + (w.level or 1) * 4)
    Game.coins = Game.coins + value
    Game.selectedWeaponIndex = #p.weapons > 0 and clamp(math.min(index, #p.weapons), 1, #p.weapons) or 1
    rebuildPlayerBuildStats()
    playCue("shop"); toast("卖出武器 " .. w.name .. "：+" .. value .. " 材料")
    return true
end

sellShield = function()
    local p = Game.player
    local shield = p.shieldItem
    if not shield then toast("护盾槽为空") return false end
    p.shieldItem = nil
    local value = sellValue(shield, 18)
    Game.coins = Game.coins + value
    rebuildPlayerBuildStats()
    playCue("shop"); toast("卖出护盾 " .. shield.name .. "：+" .. value .. " 材料")
    return true
end

sellItem = function(index)
    local p = Game.player
    local item = p.items and p.items[index]
    if not item then toast("该道具槽为空") return false end
    table.remove(p.items, index)
    local value = sellValue(item, 14)
    Game.coins = Game.coins + value
    rebuildPlayerBuildStats()
    playCue("shop"); toast("卖出道具 " .. item.name .. "：+" .. value .. " 材料")
    return true
end

local function recycleWeapon()
    return sellWeapon(Game.selectedWeaponIndex or #Game.player.weapons)
end

local function refreshShop()
    if Game.freeRefresh and Game.freeRefresh > 0 then
        Game.freeRefresh = Game.freeRefresh - 1
        Game.shopGhost = {}
        for i, item in ipairs(Game.shop or {}) do Game.shopGhost[i] = item.name end
        Game.shopRollTimer = 0.55
        rollShop(true)
        toast("免费刷新")
        return
    end
    local cost = 3 + Game.shopRefresh * 2
    if Game.coins >= cost then
        Game.coins = Game.coins - cost
        Game.shopRefresh = Game.shopRefresh + 1
        Game.runStats.rerolls = (Game.runStats.rerolls or 0) + 1
        Game.shopGhost = {}
        for i, item in ipairs(Game.shop or {}) do Game.shopGhost[i] = item.name end
        Game.shopRollTimer = 0.55
        rollShop(true)
        toast("商店已刷新")
    else
        toast("材料不足，无法刷新")
    end
end

local function handlePointer(x, y)
    if Game.state == "menu" then
        local deckX, deckY, deckW = 90, Game.h - 168, Game.w - 180
        if hitRect(x, y, deckX + deckW - 158, deckY + 82, 58, 32) then Game.danger = math.max(0, Game.danger - 1); return true end
        if hitRect(x, y, deckX + deckW - 86, deckY + 82, 58, 32) then Game.danger = math.min(6, Game.danger + 1); return true end
        if hitRect(x, y, Game.w / 2 - 140, deckY + 30, 280, 62) then resetRun(); return true end
    elseif Game.state == "levelup" then
        local w, h, gap = 330, 210, 34
        local sx = Game.w / 2 - (w * 3 + gap * 2) / 2
        for i = 1, 3 do
            local cx = sx + (i - 1) * (w + gap)
            if hitRect(x, y, cx, 350, w, h) then chooseLevelReward(i); return true end
        end
    elseif Game.state == "shop" then
        local marginX = 40
        local actionY, actionH = 38, 42
        local refreshW, nextW, sellW, actionGap = 210, 220, 220, 12
        local actionX = Game.w - marginX - refreshW - nextW - sellW - actionGap * 2
        if hitRect(x, y, actionX, actionY, refreshW, actionH) then refreshShop(); return true end
        if hitRect(x, y, actionX + refreshW + actionGap, actionY, nextW, actionH) then startWave(); return true end
        if hitRect(x, y, actionX + refreshW + actionGap + nextW + actionGap, actionY, sellW, actionH) then recycleWeapon(); return true end

        local tab = shopTabHit(x, y)
        if tab then Game.shopTab = tab; return true end

        if (Game.shopTab or "shop") == "shop" then
            local gap = 28
            local sideW = 430
            local sideGap = 32
            local sideX = Game.w - marginX - sideW
            local shelfW = sideX - marginX - sideGap
            local cardW = (shelfW - gap * 2) / 3
            local cardH = 268
            local weaponY = 204
            local supportY = 554
            if handleBuildPanelClick(x, y, sideX, 154, sideW, Game.h - 200) then return true end
            for i = 1, 6 do
                local col = (i - 1) % 3
                local cardX = marginX + col * (cardW + gap)
                local cardTop = i <= 3 and weaponY or supportY
                local buyY = cardTop + cardH - 36
                if hitRect(x, y, cardX + 18, buyY, cardW - 36, 28) then buySlot(i); return true end
                if Game.shop[i] and hitRect(x, y, cardX + cardW - 48, cardTop + 13, 30, 24) then Game.locked[i] = not Game.locked[i]; playCue("shop"); toast(Game.locked[i] and "已锁定商品" or "已取消锁定"); return true end
            end
        elseif Game.shopTab == "slot" then
            local buttonW, buttonH = 320, 64
            if hitRect(x, y, Game.w / 2 - buttonW / 2, 190 + 430 - 96, buttonW, buttonH) then spinSlotMachine(); return true end
        end
    elseif Game.state == "paused" then
        local px, py = Game.w / 2 - 510, Game.h / 2 - 345
        if hitRect(x, y, px + 40, py + 180, 340, 58) then Game.state = "playing"; toast("继续战斗"); return true end
        if hitRect(x, y, px + 40, py + 260, 340, 52) then toast("设置面板待接入"); return true end
        if hitRect(x, y, px + 40, py + 334, 340, 52) then Game.state = "menu"; toast("已退出本局"); return true end
    elseif Game.state == "gameover" or Game.state == "victory" then
        if hitRect(x, y, Game.w / 2 - 300, 205, 600, 260) then Game.state = "menu"; return true end
    end
    return false
end

function love.mousepressed(x, y, button)
    if button == 1 then
        local gx, gy = screenToGame(x, y)
        handlePointer(gx, gy)
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    local gx, gy = screenToGame(x, y)
    handlePointer(gx, gy)
end

function love.keypressed(key)
    if key == "escape" then
        if Game.state == "playing" then Game.state = "paused"; toast("已暂停"); return end
        if Game.state == "paused" then Game.state = "playing"; toast("继续战斗"); return end
        if Game.state == "gameover" or Game.state == "victory" then Game.state = "menu"; return end
        love.event.quit()
    end

    if key == "space" and Game.state == "playing" then useActiveSkill(); return end

    if Game.state == "paused" then return end

    if Game.state == "menu" then
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
        if key == "5" then buySlot(5) end
        if key == "6" then buySlot(6) end
        if key == "e" then recycleWeapon() end
        if key == "s" then spinSlotMachine(); return end
        if key == "r" then
            if not (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then toast("刷新需按 Shift+R，避免误触"); return end
            refreshShop()
        end
    end
end
