-- main.lua
-- Robot War prototype
-- LOVE 11.x arena roguelite inspired by short-wave survivor games and loot-driven builds.

function cfgSplit(text, sep)
    local out = {}
    sep = sep or ","
    for part in string.gmatch(text or "", "([^" .. sep .. "]+)") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        out[#out + 1] = part
    end
    return out
end

function cfgReadText(path)
    if love and love.filesystem and love.filesystem.getInfo(path) then
        return love.filesystem.read(path)
    end
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

function loadBalanceConfig()
    local cfg = {moduleStats = {}, moduleBlueprints = {}, affixDefs = {}, waveAffixes = {}}
    local text = cfgReadText("balance.cfg") or ""
    for raw in text:gmatch("[^\r\n]+") do
        local line = raw:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
            if key and value then
                if key == "chapter_names" then
                    cfg.chapterNames = cfgSplit(value, ",")
                elseif key == "module_stat" then
                    local parts = cfgSplit(value, "|")
                    cfg.moduleStats[parts[1]] = {id = parts[1], label = parts[2], min = tonumber(parts[3]) or 0, max = tonumber(parts[4]) or 0, format = parts[5] or "percent"}
                elseif key == "module" then
                    local parts = cfgSplit(value, "|")
                    cfg.moduleBlueprints[#cfg.moduleBlueprints + 1] = {key = parts[1], name = parts[2], kind = parts[3], stats = cfgSplit(parts[4] or "", ",")}
                elseif key == "affix" then
                    local parts = cfgSplit(value, "|")
                    local affix = {id = parts[1], name = parts[2], kind = parts[3], desc = parts[4]}
                    for _, pair in ipairs(cfgSplit(parts[5] or "", ",")) do
                        local k, v = pair:match("^([%w_]+)%s*=%s*([%d%.%-]+)$")
                        if k then affix[k] = tonumber(v) or v end
                    end
                    cfg.affixDefs[affix.id] = affix
                elseif key == "chapter_affix" then
                    local parts = cfgSplit(value, "|")
                    cfg.waveAffixes[tonumber(parts[1]) or (#cfg.waveAffixes + 1)] = {affix = parts[2], reward = parts[2], penalty = parts[3], protocol = parts[4]}
                else
                    local num = tonumber(value)
                    cfg[key] = num or value
                end
            end
        end
    end
    return cfg
end

Balance = loadBalanceConfig()

local VERSION = "v2026.05.23.34"
local VIRTUAL_W, VIRTUAL_H = 1920, 1080
local ACTIVE_SKILL_CD = 3.0
local ACTIVE_SKILL_DURATION = 0.5
local ACTIVE_SKILL_SPEED_MULT = 2.1
local CHAPTER_SIZE = Balance.chapter_size or 3
local CHAPTER_NAMES = Balance.chapterNames or {"铁幕", "赤炉", "断链", "黑箱", "天灾", "归零", "深井", "白噪", "终焉", "重启"}
local SMALL_WAVE_DURATION = Balance.small_wave_duration or 30
local CAMPAIGN_WAVES = CHAPTER_SIZE * #CHAPTER_NAMES
local AVERAGE_RUN_TARGET_WAVE = Balance.average_run_target_wave or 20
ITEM_SLOT_BASE = Balance.item_slot_base or 4
ITEM_SLOT_MAX = Balance.item_slot_max or 12

local Game = {
    w = VIRTUAL_W,
    h = VIRTUAL_H,
    state = "menu", -- menu, playing, clearing, paused, levelup, shop, gameover, victory
    time = 0,
    wave = 1,
    waveTime = SMALL_WAVE_DURATION,
    maxWave = CAMPAIGN_WAVES,
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
    beams = {},
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
    sideObjective = nil,
    dynamicEvents = {},
    dynamicEventIndex = 1,
    blackBoxUsed = false,
    waveRewards = nil,
    enemyShots = {},
    fireZones = {},
    runStats = {damage = 0, damageByWeapon = {}, coinsEarned = 0, highestWave = 1, rerolls = 0},
    player = {
        x = VIRTUAL_W / 2,
        y = VIRTUAL_H / 2,
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
            lifesteal = 0,
            elementChance = 0,
            elementDamage = 1.00,
            explosiveDamage = 1.00,
            lowHpDamage = 0,
            economy = 1.00
        },
        weapons = {},
        items = {},
        itemSlots = ITEM_SLOT_BASE,
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
    {name = "结算戒环", kind = "item", rarity = "common", price = 14, desc = "结算材料 +10%，射速 +4%", apply = function(p) p.stats.economy = p.stats.economy + 0.10; p.stats.fireRate = p.stats.fireRate + 0.04 end},
    {name = "轻型心壳", kind = "shield", rarity = "rare", price = 24, desc = "护盾 +20，移速 +8%", apply = function(p) p.maxShield = p.maxShield + 20; p.shield = p.shield + 20; p.speed = p.speed + 20 end},
    {name = "重型心甲", kind = "shield", rarity = "rare", price = 24, desc = "生命 +30，移速 -5%", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = p.hp + 30; p.speed = p.speed - 13 end},
    {name = "棱镜校准", kind = "mod", rarity = "epic", price = 42, desc = "射程 +12%，弹速 +8%", apply = function(p) p.stats.range = p.stats.range + 0.12; p.stats.projectileSpeed = p.stats.projectileSpeed + 0.08 end},
    {name = "超导弹芯", kind = "mod", rarity = "epic", price = 44, desc = "弹速 +12%，元素伤害 +10%", apply = function(p) p.stats.projectileSpeed = p.stats.projectileSpeed + 0.12; p.stats.elementDamage = p.stats.elementDamage + 0.10 end},
    {name = "修补凝胶", kind = "item", rarity = "common", price = 16, desc = "最大生命 +18，立即治疗 25", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 25) end},
    {name = "材料回收器", kind = "relic", rarity = "epic", price = 48, desc = "结算材料 +18%，射速 +5%", apply = function(p) p.stats.economy = p.stats.economy + 0.18; p.stats.fireRate = p.stats.fireRate + 0.05 end},
    {name = "别眨眼", kind = "legend", rarity = "legend", price = 64, desc = "暴击击杀后，下一击必定暴击", flag = "blink", apply = function(p) p.gear.blink = true end},
    {name = "善意有价", kind = "legend", rarity = "legend", price = 68, desc = "护盾破裂释放脉冲，但回复更慢", flag = "shieldBurst", apply = function(p) p.gear.shieldBurst = true; p.shieldRegen = p.shieldRegen - 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", price = 66, desc = "电弧周期追踪，伤害 -6%", flag = "endlessEcho", apply = function(p) p.gear.echoOverdrive = true; p.stats.damage = p.stats.damage - 0.06 end},
    {name = "陶瓷装甲片", kind = "shield", rarity = "common", price = 18, desc = "护盾 +16，移速 -2%", apply = function(p) p.maxShield = p.maxShield + 16; p.shield = math.min(p.maxShield, p.shield + 16); p.speed = p.speed - 5 end},
    {name = "神经加速器", kind = "mod", rarity = "rare", price = 26, desc = "移速 +10%，生命 -8", apply = function(p) p.speed = p.speed + 26; p.maxHp = p.maxHp - 8; p.hp = math.min(p.hp, p.maxHp) end},
    {name = "虹吸针管", kind = "relic", rarity = "rare", price = 30, desc = "生命偷取 +3%，暴击 -2%", apply = function(p) p.stats.lifesteal = p.stats.lifesteal + 0.03; p.stats.crit = p.stats.crit - 0.02 end},
    {name = "自动索敌芯片", kind = "relic", rarity = "epic", price = 46, desc = "电弧伤害 +18%，周期追踪", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.18; p.gear.autoArc = true end},
    {name = "回收协议", kind = "relic", rarity = "epic", price = 44, desc = "结算材料 +18%，拾取范围 +18", apply = function(p) p.stats.economy = p.stats.economy + 0.18; p.pickup = p.pickup + 18 end},
    {name = "过载电容", kind = "legend", rarity = "legend", price = 70, desc = "射速 +18%，移速 +8%，护盾回复 -1", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.18; p.speed = p.speed + 20; p.shieldRegen = p.shieldRegen - 1 end}
}

local tempItemPool = {
    {name = "兴奋剂针剂", kind = "temp", rarity = "common", price = 12, desc = "下一波伤害 +18%", buff = {damage = 0.18}},
    {name = "战术电池", kind = "temp", rarity = "common", price = 12, desc = "下一波护盾上限 +25，开局满盾", buff = {shield = 25}},
    {name = "赏金合约", kind = "temp", rarity = "rare", price = 18, desc = "下一波结算材料 +30%", buff = {economy = 0.30}},
    {name = "低温弹匣", kind = "temp", rarity = "rare", price = 20, desc = "下一波子弹附带霜冻概率", buff = {elementChance = 0.18, element = "ice"}},
    {name = "腐蚀涂层", kind = "temp", rarity = "rare", price = 20, desc = "下一波元素伤害 +18%", buff = {elementDamage = 0.18}},
    {name = "过载保险", kind = "temp", rarity = "epic", price = 30, desc = "下一波射速 +22%，护盾回复 -20%", buff = {fireRate = 0.22, shieldRegenMult = -0.20}}
}

local enemyDefs = {
    drifter = {name = "漂移噪声", sprite = "enemy_drifter", defense = "flesh", hp = 18, speed = 78, damage = 9, r = 14, color = C.red, xp = 3, coin = 2, behavior = "chase"},
    splinter = {name = "裂片", sprite = "enemy_splinter", defense = "flesh", hp = 12, speed = 130, damage = 7, r = 10, color = C.orange, xp = 2, coin = 1, behavior = "charger"},
    shell = {name = "壳层记忆", sprite = "enemy_shell", defense = "armor", hp = 44, speed = 50, damage = 13, r = 20, color = C.green, armor = 3, xp = 5, coin = 4, behavior = "guard"},
    wisp = {name = "电弧游魂", sprite = "enemy_wisp", defense = "shield", hp = 18, shield = 26, shieldRegen = 2.2, speed = 105, damage = 8, r = 13, color = C.cyan, xp = 4, coin = 3, behavior = "shooter"},
    elite = {name = "坏蛋精英", sprite = "enemy_elite", defense = "shield", hp = 150, shield = 90, shieldRegen = 3.0, speed = 64, damage = 18, r = 28, color = C.purple, armor = 2, xp = 16, coin = 12, elite = true, behavior = "aura"},
    treasure = {name = "宝藏信标", sprite = "pickup_coin", defense = "flesh", hp = 16, speed = 112, damage = 0, r = 16, color = C.gold, xp = 1, coin = 5, treasureCoin = 18, treasure = true, behavior = "treasure"},
    bomber = {name = "燃烧投手", sprite = "enemy_splinter", defense = "flesh", hp = 38, speed = 72, damage = 10, r = 15, color = C.orange, xp = 4, coin = 4, behavior = "bomber"},
    rammer = {name = "突击钻头", sprite = "enemy_splinter", defense = "armor", hp = 52, speed = 96, damage = 16, r = 18, color = C.red, armor = 1, xp = 6, coin = 5, behavior = "rammer"},
    boss = {name = "裂心机核", sprite = "boss_heartbreak", defense = "armor", hp = 1900, shield = 260, shieldRegen = 1.2, speed = 48, damage = 24, r = 46, color = C.pink, armor = 2, xp = 80, coin = 60, boss = true, behavior = "boss"}
}

local wavePlans = {
    {name = "裂片试探", interval = 1.10, pack = 1, sides = {"left", "right"}, enemies = {{"splinter", 70}, {"drifter", 30}}},
    {name = "双翼骚扰", interval = 1.02, pack = 2, sides = {"left", "right", "top"}, enemies = {{"splinter", 47}, {"drifter", 35}, {"rammer", 5}, {"wisp", 10}, {"treasure", 3}}},
    {name = "电弧乱流", interval = 0.92, pack = 2, sides = {"top", "right", "left"}, enemies = {{"splinter", 34}, {"drifter", 27}, {"rammer", 7}, {"wisp", 26}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 18, enemy = "elite", side = "right", toast = "精英信号：右侧突破"}}},
    {name = "装甲推进", interval = 0.88, pack = 2, sides = {"left", "right", "bottom"}, enemies = {{"splinter", 27}, {"drifter", 24}, {"rammer", 8}, {"wisp", 17}, {"shell", 18}, {"bomber", 3}, {"treasure", 3}}},
    {name = "交叉包围", interval = 0.80, pack = 3, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 25}, {"drifter", 25}, {"rammer", 10}, {"wisp", 22}, {"shell", 15}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 12, enemy = "elite", side = "left", toast = "精英压境：左侧"}}},
    {name = "重壳浪潮", interval = 0.78, pack = 3, sides = {"right", "bottom", "top"}, enemies = {{"drifter", 22}, {"wisp", 22}, {"shell", 32}, {"rammer", 10}, {"splinter", 11}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 22, enemy = "elite", side = "bottom", toast = "底线精英出现"}}},
    {name = "高速撕裂", interval = 0.70, pack = 3, sides = {"left", "right"}, enemies = {{"splinter", 34}, {"drifter", 32}, {"rammer", 14}, {"wisp", 11}, {"shell", 6}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 16, enemy = "elite", side = "right"}}},
    {name = "四面噪声", interval = 0.64, pack = 4, sides = {"left", "right", "top", "bottom"}, enemies = {{"splinter", 23}, {"drifter", 24}, {"rammer", 10}, {"wisp", 23}, {"shell", 17}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 10, enemy = "elite", side = "top"}, {time = 25, enemy = "elite", side = "bottom"}}},
    {name = "核心前夜", interval = 0.58, pack = 4, sides = {"right", "left", "top", "bottom"}, enemies = {{"splinter", 20}, {"drifter", 24}, {"rammer", 10}, {"wisp", 25}, {"shell", 18}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 9, enemy = "elite", side = "left"}, {time = 21, enemy = "elite", side = "right"}}},
    {name = "裂心机核", interval = 0.95, pack = 2, sides = {"left", "right", "top", "bottom"}, boss = true, enemies = {{"splinter", 23}, {"drifter", 22}, {"rammer", 8}, {"wisp", 23}, {"shell", 18}, {"bomber", 3}, {"treasure", 3}}, events = {{time = 0.2, enemy = "boss", side = "right", toast = "Boss：裂心机核接入"}, {time = 20, enemy = "elite", side = "left"}, {time = 40, enemy = "elite", side = "right"}}}
}

local function wavePlanAt(wave)
    local safeWave = math.max(1, wave or 1)
    local chapterIndex = math.floor((safeWave - 1) / CHAPTER_SIZE) + 1
    local chapterWave = ((safeWave - 1) % CHAPTER_SIZE) + 1
    local base = wavePlans[((safeWave - 1) % #wavePlans) + 1] or wavePlans[#wavePlans]
    if chapterWave == CHAPTER_SIZE then base = wavePlans[#wavePlans] end
    local plan = {}
    for k, v in pairs(base) do plan[k] = v end
    plan.enemies = {}
    local hasBomber = false
    for i, entry in ipairs(base.enemies or {}) do
        local id, weight = entry[1], entry[2]
        if id == "bomber" and chapterIndex >= 2 then
            hasBomber = true
            weight = math.max(2, weight + math.floor(chapterIndex * 0.75) + (chapterWave == CHAPTER_SIZE and -1 or 1))
        elseif id == "bomber" then
            hasBomber = true
        end
        plan.enemies[i] = {id, weight}
    end
    if chapterIndex >= 2 and not hasBomber then plan.enemies[#plan.enemies + 1] = {"bomber", 3 + math.floor(chapterIndex * 0.75)} end
    plan.duration = chapterWave == CHAPTER_SIZE and nil or SMALL_WAVE_DURATION
    plan.interval = math.max(0.42, (base.interval or 1.0) - (chapterIndex - 1) * 0.030 - (chapterWave == CHAPTER_SIZE and 0.04 or 0))
    plan.pack = (base.pack or 1) + math.floor((chapterIndex - 1) / 2) + (chapterWave == CHAPTER_SIZE and 0 or 0)
    plan.name = chapterWave == CHAPTER_SIZE and ((CHAPTER_NAMES[chapterIndex] or "终局") .. "Boss战") or (base.name or "生存波次")
    if chapterWave == CHAPTER_SIZE then
        plan.boss = true
        plan.events = {
            {time = 0.2, enemy = "boss", side = "right", toast = "关底目标：击败 Boss"}
        }
        if chapterIndex >= 2 then plan.events[#plan.events + 1] = {time = 16, enemy = "bomber", side = "top", toast = "燃烧投手支援入场"} end
        plan.events[#plan.events + 1] = {time = 24, enemy = "elite", side = "left", toast = "Boss护卫：左侧精英"}
    end
    return plan
end

local function chapterInfoAt(wave)
    local safeWave = math.max(1, wave or 1)
    local chapterIndex = math.floor((safeWave - 1) / CHAPTER_SIZE) + 1
    local chapterName = CHAPTER_NAMES[chapterIndex] or CHAPTER_NAMES[#CHAPTER_NAMES]
    local chapterWave = ((safeWave - 1) % CHAPTER_SIZE) + 1
    return chapterName, chapterWave, CHAPTER_SIZE, chapterIndex
end

local function chapterWaveLabel(wave)
    local name, chapterWave, chapterSize = chapterInfoAt(wave)
    return name .. " " .. chapterWave .. "/" .. chapterSize
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
    drought = {name = "枯竭", kind = "penalty", desc = "护盾回复 -25%", shieldRegenMult = 0.75},

    storm = {name = "电磁风暴", kind = "protocol", desc = "电弧 +12%，敌速 +6%", elementDamage = 1.12, enemySpeed = 1.06},
    cryoLeak = {name = "低温泄露", kind = "protocol", desc = "敌速 -8%，护盾回复 -10%", enemySpeed = 0.92, shieldRegenMult = 0.90},
    scrapHarvest = {name = "废料丰收", kind = "protocol", desc = "材料 +18%，敌群 +1", coinMult = 1.18, extraPack = 1},
    blackSignal = {name = "黑箱干扰", kind = "protocol", desc = "伤害 +8%，敌血 +8%", playerDamage = 1.08, enemyHp = 1.08}
}

local waveAffixes = {
    {reward = "bounty", penalty = "swarm", protocol = "storm"},
    {reward = "magnet", penalty = "rage", protocol = "cryoLeak"},
    {reward = "calibrate", penalty = "volatile", protocol = "scrapHarvest"},
    {reward = "repair", penalty = "carapace", protocol = "blackSignal"},
    {reward = "overcharge", penalty = "swarm", protocol = "storm"},
    {reward = "bounty", penalty = "drought", protocol = "scrapHarvest"},
    {reward = "magnet", penalty = "carapace", protocol = "cryoLeak"},
    {reward = "calibrate", penalty = "rage", protocol = "blackSignal"},
    {reward = "repair", penalty = "volatile", protocol = "storm"},
    {reward = "overcharge", penalty = "carapace", protocol = "blackSignal"}
}

if Balance.affixDefs and next(Balance.affixDefs) then affixDefs = Balance.affixDefs end
if Balance.waveAffixes and next(Balance.waveAffixes) then waveAffixes = Balance.waveAffixes end

local function affixesAt(wave)
    local safeWave = math.max(1, wave or 1)
    local chapterIndex = math.floor((safeWave - 1) / CHAPTER_SIZE) + 1
    local pair = waveAffixes[chapterIndex] or waveAffixes[((chapterIndex - 1) % math.max(1, #waveAffixes)) + 1] or {}
    if pair.affix then return nil, affixDefs[pair.affix], nil end
    return affixDefs[pair.reward], affixDefs[pair.penalty], affixDefs[pair.protocol]
end

local function currentAffixes()
    return affixesAt(Game.wave)
end

local function currentAffixBonuses()
    local bonus = {
        coinMult = 1, playerDamage = 1, critBonus = 0,
        shieldRegenMult = 1, enemyHp = 1, enemySpeed = 1, enemyDamage = 1, enemyArmor = 0,
        extraPack = 0, intervalMult = 1, elementDamage = 1
    }
    local reward, penalty, protocol = currentAffixes()
    for _, affix in ipairs({reward, penalty, protocol}) do
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
            bonus.elementDamage = bonus.elementDamage * (affix.elementDamage or 1)
        end
    end
    return bonus
end

local function affixLabel()
    local reward, penalty, protocol = currentAffixes()
    local parts = {}
    if protocol then parts[#parts + 1] = "协议 " .. protocol.name end
    if reward then parts[#parts + 1] = "奖励 " .. reward.name end
    if penalty then parts[#parts + 1] = "大关词缀 " .. penalty.name end
    return #parts > 0 and table.concat(parts, " / ") or "无词缀"
end

local function affixDetailLines(affix)
    local lines = {affix.desc or "下一波生效"}
    if affix.coinMult then lines[#lines + 1] = "材料获取倍率 ×" .. string.format("%.2f", affix.coinMult) end
    if affix.playerDamage then lines[#lines + 1] = "玩家伤害倍率 ×" .. string.format("%.2f", affix.playerDamage) end
    if affix.critBonus then lines[#lines + 1] = "暴击率 +" .. string.format("%d%%", math.floor(affix.critBonus * 100 + 0.5)) end
    if affix.elementDamage then lines[#lines + 1] = "元素伤害倍率 ×" .. string.format("%.2f", affix.elementDamage) end
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
        range = 1.00, projectileSpeed = 1.00,
        lifesteal = 0,
        elementChance = 0, elementDamage = 1.00,
        explosiveDamage = 1.00, lowHpDamage = 0,
        economy = 1.00
    }
}

local characterDefs = {basePlayerDef}

local SURVIVAL_DURATION = SMALL_WAVE_DURATION

local objectiveDefs = {
    {name = "战役模式", desc = "普通小关生存 30 秒，关底击败 Boss", mode = "survive"}
}

local levelRewardPool = {
    {name = "白板校准", kind = "item", rarity = "common", family = "基础", desc = "伤害 +8%", apply = function(p) p.stats.damage = p.stats.damage + 0.08 end},
    {name = "脉冲节拍", kind = "item", rarity = "common", family = "基础", desc = "射速 +10%", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.10 end},
    {name = "生命扩容", kind = "shield", rarity = "common", family = "生存", desc = "最大生命 +18，治疗 12", apply = function(p) p.maxHp = p.maxHp + 18; p.hp = math.min(p.maxHp, p.hp + 12) end},
    {name = "护盾增幅", kind = "shield", rarity = "common", family = "护盾", desc = "最大护盾 +16，回复 +1", apply = function(p) p.maxShield = p.maxShield + 16; p.shield = p.shield + 16; p.shieldRegen = p.shieldRegen + 1 end},
    {name = "陶瓷护盾", kind = "shield", rarity = "common", family = "生存", desc = "护盾上限 +16", apply = function(p) p.maxShield = p.maxShield + 16; p.shield = math.min(p.maxShield, p.shield + 16) end},
    {name = "轻量步态", kind = "mod", rarity = "common", family = "生存", desc = "移速 +8%", apply = function(p) p.speed = p.speed + 20 end},
    {name = "暴击透镜", kind = "mod", rarity = "rare", family = "暴击", desc = "暴击率 +6%，暴伤 +10%", apply = function(p) p.stats.crit = p.stats.crit + 0.06; p.stats.critDamage = p.stats.critDamage + 0.10 end},
    {name = "弱点猎杀", kind = "mod", rarity = "epic", family = "暴击", desc = "暴击率 +4%，暴击击杀使下一击必暴", flag = "blink", apply = function(p) p.stats.crit = p.stats.crit + 0.04; p.gear.blink = true end},
    {name = "射程校准", kind = "mod", rarity = "rare", family = "武器", desc = "射程 +12%，弹速 +8%", apply = function(p) p.stats.range = p.stats.range + 0.12; p.stats.projectileSpeed = p.stats.projectileSpeed + 0.08 end},
    {name = "回声预案", kind = "mod", rarity = "rare", family = "武器", desc = "电弧伤害 +12%", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.12 end},
    {name = "燃烧弹芯", kind = "item", rarity = "rare", family = "元素", desc = "元素伤害 +18%", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.18 end},
    {name = "电击电容", kind = "item", rarity = "rare", family = "元素", desc = "护盾破裂释放电弧，元素伤害 +10%", flag = "shieldBurst", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.10; p.gear.shieldBurst = true end},
    {name = "腐蚀针剂", kind = "item", rarity = "rare", family = "元素", desc = "腐蚀叠层上限提高，元素伤害 +10%", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.10; p.gear.deepCorrode = true end},
    {name = "冰裂准星", kind = "mod", rarity = "epic", family = "元素", desc = "冻结/减速目标更容易被暴击", apply = function(p) p.gear.freezeCrit = true; p.stats.crit = p.stats.crit + 0.03 end},
    {name = "爆炸协议", kind = "mod", rarity = "epic", family = "爆炸", desc = "爆炸伤害 +22%，击杀小范围爆裂", apply = function(p) p.stats.explosiveDamage = p.stats.explosiveDamage + 0.22; p.gear.killBurst = true end},
    {name = "追踪电弧", kind = "relic", rarity = "epic", family = "元素", desc = "电弧命中后周期追踪", apply = function(p) p.gear.autoArc = true; p.stats.elementDamage = p.stats.elementDamage + 0.10 end},
    {name = "护盾回流", kind = "relic", rarity = "epic", family = "护盾", desc = "击杀回复护盾，满盾时伤害 +8%", apply = function(p) p.gear.killShield = true; p.gear.fullShieldDamage = true end},
    {name = "血线狂热", kind = "relic", rarity = "epic", family = "低血", desc = "生命越低伤害越高，吸血 +2%", apply = function(p) p.stats.lowHpDamage = p.stats.lowHpDamage + 0.45; p.stats.lifesteal = p.stats.lifesteal + 0.02 end},
    {name = "回收协议", kind = "relic", rarity = "rare", family = "经济", desc = "关卡结算材料 +18%", apply = function(p) p.stats.economy = p.stats.economy + 0.18 end},
    {name = "赏金猎犬", kind = "legend", rarity = "legend", family = "经济", desc = "商店免费刷新 +1，结算材料 +12%", apply = function(p) p.stats.economy = p.stats.economy + 0.12; Game.freeRefresh = Game.freeRefresh + 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", family = "武器", desc = "电弧周期追踪，伤害 -5%", flag = "endlessEcho", apply = function(p) p.gear.echoOverdrive = true; p.stats.damage = p.stats.damage - 0.05 end},
    {name = "腐蚀瘟疫", kind = "legend", rarity = "legend", family = "元素", desc = "腐蚀击杀会向附近敌人扩散", apply = function(p) p.gear.corrosionSpread = true; p.stats.elementDamage = p.stats.elementDamage + 0.12 end},
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
local rarityRank = {common = 1, rare = 2, epic = 3, legend = 4}
local kindLabel = {weapon = "武器", item = "模块", shield = "护盾", mod = "模块", relic = "核心模块", legend = "传说模块", temp = "战术"}
local rarityPower = {common = 1.00, rare = 1.18, epic = 1.42, legend = 1.78}
local rarityAffixes = {common = 1, rare = 2, epic = 3, legend = 4}
local rarityBudget = {common = 1.00, rare = 1.80, epic = 2.80, legend = 4.20}
local rarityPartCount = {common = 2, rare = 3, epic = 4, legend = 4}
local rarityPrice = {common = 1.00, rare = 1.36, epic = 1.92, legend = 2.85}

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

local function rollRarity()
    local r = rnd()
    local legend = 0.045
    local epic = 0.16
    local rare = 0.36
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

    local img = b.sprite and Game.images[b.sprite]
    if img then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.70)
        local size = b.aura and 34 or (b.splash and 30 or 24)
        local scale = size / math.max(img:getWidth(), img:getHeight())
        love.graphics.draw(img, 0, 0, 0, scale, scale, img:getWidth() / 2, img:getHeight() / 2)
        love.graphics.setBlendMode("alpha")
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

function addBeam(x1, y1, x2, y2, c)
    Game.beams[#Game.beams + 1] = {x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = c or C.cyan, life = 0.36, max = 0.36}
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

local function spawnPoint(side, radius)
    -- 生成必须在界面外，随后自然入场；入场后才被边界锁住。
    local marginTop, marginBottom = 170, 82
    local r = (radius or 18) + 34
    if side == "left" then return -r, rnd(marginTop, Game.h - marginBottom) end
    if side == "right" then return Game.w + r, rnd(marginTop, Game.h - marginBottom) end
    if side == "top" then return rnd(120, Game.w - 120), -r end
    if side == "bottom" then return rnd(120, Game.w - 120), Game.h + r end
    local n = rnd(1, 4)
    if n == 1 then return spawnPoint("left", radius) elseif n == 2 then return spawnPoint("right", radius) elseif n == 3 then return spawnPoint("top", radius) end
    return spawnPoint("bottom", radius)
end

local function pickSpawnSide(plan)
    local sides = plan and plan.sides or {"left", "right", "top", "bottom"}
    return sides[rnd(1, #sides)]
end
function enemyVisualRadius(e)
    local r = e and e.r or 14
    if e and e.boss then return r * 2.35 + 10 end
    if e and e.elite then return r * 2.10 + 8 end
    return r + 14
end

function enemyArenaBounds(e)
    local r = enemyVisualRadius(e)
    return r, 150 + r, Game.w - r, Game.h - 62 - r
end

local function markAndClampEnemyArena(e)
    local left, top, right, bottom = enemyArenaBounds(e)
    if e.x >= left and e.x <= right and e.y >= top and e.y <= bottom then e.enteredArena = true end
    if e.enteredArena then
        e.x = clamp(e.x, left, right)
        e.y = clamp(e.y, top, bottom)
    end
end


function wavePowerScale(wave)
    return 1 + math.max(0, (wave or Game.wave or 1) - 1) * 0.10
end

function shopPowerScale()
    return wavePowerScale(Game.wave or 1)
end

function itemLevelForWave(wave)
    return math.max(1, math.floor(wave or Game.wave or 1))
end

function itemLevelText(item)
    return "Lv." .. tostring(itemLevelForWave(item and item.level or Game.wave or 1))
end

function stampItemLevel(item)
    if item and not item.level then item.level = itemLevelForWave(Game.wave or 1) end
    return item
end

function survivalProgress()
    return clamp((Game.waveElapsed or 0) / math.max(1, SURVIVAL_DURATION), 0, 1)
end

function runProgress()
    return clamp(((Game.wave or 1) - 1 + survivalProgress()) / math.max(1, Game.maxWave or CAMPAIGN_WAVES), 0, 1)
end

function difficultyProgress()
    -- 第一大关是养成段；第二大关开始按小关线性加压。
    -- 第 20 小关约等于平均 10 分钟压力目标，30 小关继续进入高手挑战段。
    local pressureWave = math.max(0, ((Game.wave or 1) - CHAPTER_SIZE - 1) + survivalProgress())
    local pressureSpan = math.max(1, AVERAGE_RUN_TARGET_WAVE - CHAPTER_SIZE)
    return clamp(pressureWave / pressureSpan, 0, 1.45)
end

function chapterGatePressure()
    local _, chapterWave, _, chapterIndex = chapterInfoAt(Game.wave)
    if chapterWave ~= CHAPTER_SIZE then return 0 end
    -- 10 大关后 Boss 更频繁；第一关给警告，第二关开始明显升压。
    return ({0.16, 0.42, 0.58, 0.72, 0.86, 1.00, 1.12, 1.24, 1.36, 1.50})[chapterIndex] or 1.50
end

function survivalEnemyCurve()
    local waveT = survivalProgress()
    local pressureT = difficultyProgress()
    local gateT = chapterGatePressure()
    return {
        hp = 1.00 + 0.08 * waveT + 0.82 * pressureT + gateT * 0.58,
        damage = 1.00 + 0.05 * waveT + 0.48 * pressureT + gateT * 0.36,
        speed = 1.00 + 0.025 * waveT + 0.09 * pressureT + gateT * 0.045,
        armor = math.floor(pressureT * 1.8 + gateT * 1.45),
        pack = math.floor(pressureT * 1.25 + gateT * 2.15),
        interval = 1.00 - 0.045 * waveT - 0.13 * pressureT - gateT * 0.08,
        cap = 40 + math.floor(waveT * 10) + math.floor(pressureT * 50) + math.floor(gateT * 42) + Game.danger * 8
    }
end

function survivalPhaseName()
    local t = clamp(difficultyProgress(), 0, 1)
    local _, chapterWave = chapterInfoAt(Game.wave)
    if chapterWave == CHAPTER_SIZE then return "关底清算" end
    if t < 0.20 then return "侦察期" end
    if t < 0.45 then return "扩张期" end
    if t < 0.70 then return "压迫期" end
    if t < 0.90 then return "淘汰期" end
    return "终局清算"
end

local function spawnEnemy(def, opts)
    opts = opts or {}
    local plan = currentWavePlan()
    def = def or weightedEnemy(plan)
    local x, y = spawnPoint(opts.side or pickSpawnSide(plan), def.r)
    local bonus = currentAffixBonuses()
    local curve = survivalEnemyCurve()
    local dangerScale = 1 + Game.danger * 0.08
    local scale = (opts.scale or 1) * wavePowerScale(Game.wave) * bonus.enemyHp * dangerScale * curve.hp
    local hp = def.hp * scale
    local shield = (def.shield or 0) * scale
    Game.enemies[#Game.enemies + 1] = {
        name = def.name, x = x, y = y, r = def.r,
        hp = hp, maxHp = hp, shield = shield, maxShield = shield, defense = def.defense or (shield > 0 and "shield" or ((def.armor or 0) > 0 and "armor" or "flesh")), shieldRegen = def.shieldRegen or 0,
        speed = (def.speed + Game.wave * 0.85) * bonus.enemySpeed * curve.speed * (1 + Game.danger * 0.025),
        damage = def.damage * wavePowerScale(Game.wave) * bonus.enemyDamage * curve.damage * (1 + Game.danger * 0.06), armor = (def.armor or 0) + bonus.enemyArmor + curve.armor,
        color = def.color, xp = def.xp, coin = def.coin, treasureCoin = def.treasureCoin, sprite = def.sprite, behavior = def.behavior or "chase",
        elite = def.elite, boss = def.boss, treasure = def.treasure,
        shootTimer = rnd() * 1.2, dashTimer = rnd() * 1.6, wanderTimer = rnd() * 1.4, wanderAngle = rnd() * TAU,
        burn = 0, slow = 0, corrosion = 0, lastHit = 0
    }
    local spawned = Game.enemies[#Game.enemies]
    if def.boss then
        toast("Boss 接入：" .. def.name)
        addText(Game.w / 2 - 46, 154, "Boss", C.red)
    elseif def.elite or def.behavior == "bomber" then
        addText(clamp(x, 80, Game.w - 80), clamp(y, 170, Game.h - 90), def.elite and "精英" or "燃烧投手", def.elite and C.purple or C.orange)
    end
end

local function spawnPack(plan)
    plan = plan or currentWavePlan()
    local side = pickSpawnSide(plan)
    local bonus = currentAffixBonuses()
    local curve = survivalEnemyCurve()
    if #Game.enemies >= curve.cap then return end
    local pack = math.min((plan.pack or 1) + bonus.extraPack + curve.pack, math.max(1, curve.cap - #Game.enemies))
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
local applyBuildSynergies

function isPermanentModule(item)
    return item and (item.kind == "item" or item.kind == "mod" or item.kind == "relic" or item.kind == "legend")
end

function mergeKeyForItem(item)
    return item and (item.mergeKey or item.name or item.kind or "module") or "module"
end

function itemSlotUpgradeCost()
    local p = Game.player or {}
    local slots = p.itemSlots or ITEM_SLOT_BASE
    if slots >= ITEM_SLOT_MAX then return nil end
    return (Balance.item_slot_upgrade_base or 22) + (slots - ITEM_SLOT_BASE) * (Balance.item_slot_upgrade_step or 14)
end

function itemFitsOrCanMerge(item)
    local p = Game.player
    if not isPermanentModule(item) then return true end
    local items = p.items or {}
    if #items < (p.itemSlots or ITEM_SLOT_BASE) then return true end
    local key, same = mergeKeyForItem(item), 0
    for _, owned in ipairs(items) do
        if mergeKeyForItem(owned) == key then same = same + 1 end
    end
    return same >= 2
end

function rebuildModuleDesc(item)
    if not item or not item.effects then return end
    local desc = {}
    for _, e in ipairs(item.effects or {}) do
        if e.roll and e.roll.desc then desc[#desc + 1] = e.roll.desc(e.value) end
    end
    item.desc = table.concat(desc, " / ")
end

function makeMergedModule(group)
    local base = group[1]
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    merged.effects = {}
    merged.level = 0
    merged.price = 0
    merged.name = (base.name or "模块"):gsub("^融合 ", "")
    merged.name = "融合 " .. merged.name
    merged.mergeKey = mergeKeyForItem(base)
    for _, item in ipairs(group) do
        merged.level = merged.level + itemLevelForWave(item.level or 1)
        merged.price = merged.price + (item.price or 0)
        for _, e in ipairs(item.effects or {}) do merged.effects[#merged.effects + 1] = {roll = e.roll, value = e.value} end
        if item.flag then merged.flag = item.flag end
    end
    merged.price = math.max(8, math.floor(merged.price * 0.86 + 0.5))
    rebuildModuleDesc(merged)
    merged.buy = nil
    return merged
end

function tryMergeModules()
    local p = Game.player
    local items = p.items or {}
    local changed = false
    while true do
        local buckets = {}
        for idx, item in ipairs(items) do
            local key = mergeKeyForItem(item)
            buckets[key] = buckets[key] or {}
            buckets[key][#buckets[key] + 1] = idx
        end
        local mergeIdx
        for _, list in pairs(buckets) do
            if #list >= 3 then mergeIdx = {list[1], list[2], list[3]}; break end
        end
        if not mergeIdx then break end
        table.sort(mergeIdx, function(a, b) return a > b end)
        local group = {}
        for _, idx in ipairs(mergeIdx) do
            table.insert(group, 1, items[idx])
            table.remove(items, idx)
        end
        local merged = makeMergedModule(group)
        items[#items + 1] = merged
        changed = true
        toast("三合一模块融合：" .. merged.name)
    end
    return changed
end

function addPermanentModule(item)
    local p = Game.player
    p.items = p.items or {}
    stampItemLevel(item)
    if not itemFitsOrCanMerge(item) then
        toast("模块槽已满：升级槽位、卖出或凑三合一")
        return false
    end
    p.items[#p.items + 1] = item
    local merged = tryMergeModules()
    if rebuildPlayerBuildStats then rebuildPlayerBuildStats() end
    playCue("shop")
    if not merged then toast("获得模块：" .. item.name .. " · " .. itemLevelText(item)) end
    return true
end

function upgradeItemSlots()
    local p = Game.player
    local cost = itemSlotUpgradeCost()
    if not cost then toast("模块槽已满级") return false end
    if Game.coins < cost then toast("材料不足，无法升级模块槽") return false end
    Game.coins = Game.coins - cost
    p.itemSlots = math.min(ITEM_SLOT_MAX, (p.itemSlots or ITEM_SLOT_BASE) + 1)
    playCue("shop"); toast("模块槽升级：" .. #p.items .. "/" .. p.itemSlots)
    return true
end

local function applyItem(item)
    if item.apply and not item.effects then item.apply(Game.player) end
    return addPermanentModule(item)
end

local function addWeapon(def)
    stampItemLevel(def)
    local p = Game.player
    if #p.weapons >= 4 then
        toast("武器槽已满：先卖掉一把旧武器")
        return false
    end
    local w = {}
    for k, v in pairs(def) do w[k] = v end
    w.timer = 0
    p.weapons[#p.weapons + 1] = w
    if w.apply then w.apply(p) end
    if applyBuildSynergies then applyBuildSynergies() end
    playCue("shop"); toast("已装备新武器：" .. w.name)
    return true
end

local function applyShieldStats(p, item)
    p.maxShield = p.maxShield + (item.shieldCap or 0)
    p.shield = math.min(p.maxShield, p.shield + (item.shieldCap or 0))
    p.shieldRegen = p.shieldRegen + (item.shieldRegen or 0)
    p.maxHp = p.maxHp + (item.hp or 0)
    p.hp = math.min(p.maxHp, p.hp + (item.hp or 0))
    if item.flag then p.gear[item.flag] = true end
end

local function equipShield(item)
    stampItemLevel(item)
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

applyBuildSynergies = function()
    local p = Game.player
    if not p or not p.stats then return end
    local arc, crit, explosive, burn, shield = 0, 0, 0, 0, p.shieldItem and 1 or 0
    for _, w in ipairs(p.weapons or {}) do
        if w.element == "arc" or w.brand == "echo" then arc = arc + 1 end
        if w.brand == "starforge" or (w.crit or 0) > 0 or (w.name or ""):find("星针") then crit = crit + 1 end
        if w.splash or w.element == "burn" or w.brand == "molten" then explosive = explosive + 1 end
        if w.element == "burn" then burn = burn + 1 end
    end
    for _, item in ipairs(p.items or {}) do
        local desc = (item.name or "") .. " " .. (item.desc or "")
        if desc:find("电弧") or desc:find("弹射") then arc = arc + 1 end
        if desc:find("暴击") or desc:find("暴伤") then crit = crit + 1 end
        if desc:find("爆") or desc:find("燃") then explosive = explosive + 1 end
        if desc:find("护盾") then shield = shield + 1 end
    end
    p.synergies = {}
    if arc >= 2 then
        p.gear.autoArc = true
        p.synergies[#p.synergies + 1] = "电弧2：弹射+1/追踪电弧"
    end
    if crit >= 3 then
        p.gear.critRicochet = true
        p.synergies[#p.synergies + 1] = "暴击3：暴击击杀弹射"
    end
    if shield >= 1 and arc >= 1 then
        p.gear.shieldArcAura = true
        p.synergies[#p.synergies + 1] = "护盾+电弧：满盾周期电击"
    end
    if explosive >= 2 and burn >= 1 then
        p.gear.fireSplash = true
        p.synergies[#p.synergies + 1] = "爆炸+燃烧：爆炸追加灼烧"
    end
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
    if applyBuildSynergies then applyBuildSynergies() end
    p.hp = math.min(math.max(1, hp), p.maxHp)
    p.shield = math.min(math.max(0, shield), p.maxShield)
end

weaponPartPools = {
    barrel = {
        {name = "长距枪管", tag = "远射", cost = 0.45, brands = {starforge = 3, echo = 2}, apply = function(w, p) w.range = w.range * (1.14 + p * 0.03); if w.speed > 0 then w.speed = w.speed * (1.08 + p * 0.02) end; w.cooldown = w.cooldown * 1.04 end},
        {name = "分裂枪管", tag = "多弹", cost = 0.55, brands = {swarm = 4}, apply = function(w, p) if (w.count or 1) < 8 then w.count = (w.count or 1) + 1; w.damage = math.max(1, math.floor(w.damage * 0.90 + 0.5)); w.spread = (w.spread or 0) + 0.08 end end},
        {name = "重炮管", tag = "重击", cost = 0.60, brands = {molten = 4, blackbox = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.16 + p * 0.04) + 0.5); if w.speed > 0 then w.speed = w.speed * 0.86 end; w.cooldown = w.cooldown * 1.08 end},
        {name = "棱镜枪管", tag = "折射", cost = 0.65, brands = {echo = 4, starforge = 2}, apply = function(w, p) w.bounce = (w.bounce or 0) + 1; w.damage = math.max(1, math.floor(w.damage * 0.94 + 0.5)) end}
    },
    core = {
        {name = "暴击核心", tag = "暴击", cost = 0.55, brands = {starforge = 4}, apply = function(w, p) w.critBonus = (w.critBonus or 0) + 0.06 + p * 0.015; w.critDamageBonus = (w.critDamageBonus or 0) + 0.14 + p * 0.025 end},
        {name = "过载核心", tag = "过载", cost = 0.58, brands = {blackbox = 3, molten = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.12 + p * 0.035) + 0.5); w.overloadTax = true end},
        {name = "元素核心", tag = "元素", cost = 0.52, brands = {molten = 3, echo = 2, blackbox = 2}, apply = function(w, p) w.elementPower = (w.elementPower or 1) + 0.14 + p * 0.035; w.damage = math.max(1, math.floor(w.damage * 0.96 + 0.5)) end},
        {name = "稳定核心", tag = "稳定", cost = 0.42, brands = {starforge = 2, swarm = 2}, apply = function(w, p) w.spread = math.max(0, (w.spread or 0) * 0.82); w.cooldown = w.cooldown / (1.04 + p * 0.015) end}
    },
    power = {
        {name = "速射供能", tag = "速射", cost = 0.50, brands = {swarm = 3, starforge = 2}, apply = function(w, p) w.cooldown = w.cooldown / (1.09 + p * 0.025); w.damage = math.max(1, math.floor(w.damage * 0.95 + 0.5)) end},
        {name = "高压供能", tag = "高压", cost = 0.54, brands = {molten = 3, blackbox = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.14 + p * 0.035) + 0.5); w.cooldown = w.cooldown * 1.06 end},
        {name = "回收供能", tag = "回收", cost = 0.48, brands = {swarm = 2, echo = 2}, apply = function(w, p) w.killHaste = true; w.cooldown = w.cooldown / 1.03 end},
        {name = "黑箱供能", tag = "代价", cost = 0.75, brands = {blackbox = 5}, apply = function(w, p) w.damage = math.floor(w.damage * (1.20 + p * 0.04) + 0.5); w.voidSlow = true end}
    },
    calibrator = {
        {name = "穿透校准", tag = "穿透", cost = 0.45, brands = {starforge = 3}, apply = function(w, p) w.pierce = (w.pierce or 0) + 1 end},
        {name = "回声校准", tag = "回声", cost = 0.58, brands = {echo = 5}, apply = function(w, p) w.echoRamp = true; w.bounce = (w.bounce or 0) + 1 end},
        {name = "燃烧校准", tag = "灼烧", cost = 0.52, brands = {molten = 4}, apply = function(w, p) w.fireSplash = true; w.splash = (w.splash or 0) + 16 end},
        {name = "磁吸校准", tag = "牵引", cost = 0.50, brands = {blackbox = 3, echo = 2}, apply = function(w, p) w.aura = (w.aura or 0) + 22 + math.floor(p * 8) end}
    }
}

weaponAffixRolls = {
    highDamage = {text = "高伤", cost = 0.50, brands = {molten = 3, blackbox = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.10 + p * 0.06) + 0.5) end},
    rapid = {text = "速射", cost = 0.48, brands = {swarm = 3, starforge = 2}, apply = function(w, p) w.cooldown = w.cooldown / (1.08 + p * 0.04) end},
    range = {text = "远射", cost = 0.38, brands = {starforge = 3}, apply = function(w, p) w.range = w.range * (1.10 + p * 0.05) end},
    fast = {text = "高速弹", cost = 0.32, brands = {starforge = 2, swarm = 2}, apply = function(w, p) if w.speed > 0 then w.speed = w.speed * (1.12 + p * 0.05) end end},
    sixth = {text = "第六发穿透", cost = 0.70, brands = {starforge = 4}, apply = function(w, p) w.sixthPierce = true; w.shotCount = 0 end},
    orbit = {text = "回旋蜂群", cost = 0.68, brands = {swarm = 5}, apply = function(w, p) if w.count and w.count > 1 then w.orbitShot = true; w.range = w.range * 0.96 end end},
    spark = {text = "火花分裂", cost = 0.72, brands = {molten = 4, swarm = 2}, apply = function(w, p) w.sparkSplit = true; w.splash = (w.splash or 0) + 18 end},
    ramp = {text = "递增弹射", cost = 0.75, brands = {echo = 5}, apply = function(w, p) w.echoRamp = true; w.bounce = (w.bounce or 0) + 1 end},
    voidCost = {text = "虚空代价", cost = 0.78, brands = {blackbox = 5}, apply = function(w, p) if w.element == "void" then w.aura = (w.aura or 48) + 18; w.voidSlow = true else w.aura = (w.aura or 0) + 24 end end},
    execute = {text = "处刑协议", cost = 0.62, brands = {starforge = 3, blackbox = 2}, apply = function(w, p) w.executeLowHp = true end},
    focus = {text = "聚焦", cost = 0.45, brands = {echo = 2, starforge = 2}, apply = function(w, p) w.damage = math.floor(w.damage * 1.09 + 0.5); w.range = w.range * 1.06 end},
    drill = {text = "钻透", cost = 0.45, brands = {molten = 2, blackbox = 2}, apply = function(w, p) w.pierce = (w.pierce or 0) + 1 end},
    bounce = {text = "弹射", cost = 0.45, brands = {echo = 4}, apply = function(w, p) w.bounce = (w.bounce or 0) + 1 end},
    burst = {text = "爆裂", cost = 0.55, brands = {molten = 4}, apply = function(w, p) w.splash = (w.splash or 0) + 22 + math.floor(p * 10) end},
    chain = {text = "连锁", cost = 0.55, brands = {echo = 4}, apply = function(w, p) w.chain = (w.chain or 0) > 0 and (w.chain + 1) or w.chain end},
    heavy = {text = "笨重", cost = -0.36, brands = {molten = 2, blackbox = 2}, apply = function(w, p) w.damage = math.floor(w.damage * 1.16 + 0.5); w.heavy = true end},
    unstable = {text = "不稳定", cost = -0.28, brands = {blackbox = 3}, apply = function(w, p) w.critBonus = (w.critBonus or 0) + 0.12; w.spread = (w.spread or 0) + 0.14 end}
}

legendaryWeaponBlueprints = {
    needle = {title = "处刑星轨", desc = "穿透击杀刷新一次开火节奏", apply = function(w) w.sixthPierce = true; w.executeLowHp = true; w.legendRefundShot = true; w.pierce = (w.pierce or 0) + 1 end},
    swarm = {title = "虫巢协议", desc = "击杀后分裂小导弹", apply = function(w) w.hiveSplit = true; w.count = (w.count or 1) + 2; w.damage = math.max(1, math.floor(w.damage * 0.88 + 0.5)) end},
    molten = {title = "赤炉审判", desc = "爆炸留下燃烧区", apply = function(w) w.fireSplash = true; w.splash = (w.splash or 0) + 34; w.elementPower = (w.elementPower or 1) + 0.18 end},
    echo = {title = "递归切割", desc = "弹射越打越痛", apply = function(w) w.echoRamp = true; w.bounce = (w.bounce or 0) + 2; w.damage = math.max(1, math.floor(w.damage * 0.90 + 0.5)) end},
    coil = {title = "连锁审讯", desc = "连锁叠电痕并爆电", apply = function(w) w.arcMark = true; w.chain = (w.chain or 1) + 2; w.elementPower = (w.elementPower or 1) + 0.12 end},
    void = {title = "黑箱坍缩", desc = "牵引光环周期爆裂", apply = function(w) w.voidCollapse = true; w.aura = (w.aura or 48) + 38; w.voidSlow = true; w.damage = math.floor(w.damage * 1.20 + 0.5) end}
}

function weightedRollByBrand(pool, brand)
    local total = 0
    for _, item in pairs(pool) do total = total + 1 + ((item.brands and item.brands[brand]) or 0) end
    local roll = rnd() * total
    for _, item in pairs(pool) do
        roll = roll - (1 + ((item.brands and item.brands[brand]) or 0))
        if roll <= 0 then return item end
    end
    for _, item in pairs(pool) do return item end
end

function applyWeaponPart(def, slot, power)
    local part = weightedRollByBrand(weaponPartPools[slot], def.brand)
    if part and part.apply then
        part.apply(def, power)
        def.parts = def.parts or {}
        def.parts[#def.parts + 1] = {slot = slot, name = part.name, tag = part.tag, cost = part.cost or 0}
        def.budgetUsed = (def.budgetUsed or 0) + (part.cost or 0)
    end
end

function applyWeaponAffixes(def, rarity, power)
    local budget = rarityBudget[rarity] or 1
    local used = {}
    local guard = 0
    def.affixTags = def.affixTags or {}
    while budget > 0.20 and #def.affixTags < (rarityAffixes[rarity] or 1) + 1 and guard < 18 do
        guard = guard + 1
        local affix = weightedRollByBrand(weaponAffixRolls, def.brand)
        if affix and not used[affix.text] and (affix.cost or 0) <= budget + 0.20 then
            used[affix.text] = true
            affix.apply(def, power)
            budget = budget - (affix.cost or 0)
            def.affixTags[#def.affixTags + 1] = affix.text
        end
    end
    def.budgetLeft = budget
end

function applyLegendaryWeapon(def, base)
    local legend = legendaryWeaponBlueprints[base.id]
    if not legend then return end
    legend.apply(def)
    def.legendaryTitle = legend.title
    def.legendaryDesc = legend.desc
    def.name = legend.title
    def.affixTags = def.affixTags or {}
    table.insert(def.affixTags, 1, "传说协议")
end

local function makeWeaponItem(id)
    local base = weaponDefs[id]
    local rarity = rollRarity()
    local power = (rarityPower[rarity] or 1) * shopPowerScale()
    local def = {}
    for k, v in pairs(base) do def[k] = v end
    def.rolled = true
    def.level = itemLevelForWave(Game.wave or 1)
    def.parts = {}
    def.affixTags = {}
    def.damage = math.max(1, math.floor(def.damage * randf(0.92, 1.10) * (1 + (power - 1) * 0.38) + 0.5))
    def.cooldown = math.max(0.16, def.cooldown / randf(0.94, 1.08))
    def.range = def.range * randf(0.96, 1.08)
    if def.speed > 0 then def.speed = def.speed * randf(0.94, 1.10) end
    local slots = {"barrel", "core", "power", "calibrator"}
    for i = 1, math.min(#slots, rarityPartCount[rarity] or 2) do applyWeaponPart(def, slots[i], power) end
    applyWeaponAffixes(def, rarity, power)
    if rarity == "legend" then applyLegendaryWeapon(def, base) end
    local brand = brands[def.brand]
    local elem = elements[def.element]
    local partTags = {}
    for _, part in ipairs(def.parts or {}) do partTags[#partTags + 1] = part.tag or part.name end
    local affixText = table.concat(def.affixTags or {}, "、")
    local partText = table.concat(partTags, "、")
    def.name = (rarityLabel[rarity] or rarity) .. " " .. (def.name or base.name)
    local budgetSpend = (def.budgetUsed or 0) + ((rarityBudget[rarity] or 1) - (def.budgetLeft or 0))
    def.price = math.max(18, math.floor((base.price or 24) * (rarityPrice[rarity] or 1) * (1 + budgetSpend * 0.08) + 0.5))
    local descParts = {brand.name, elem.name}
    if partText ~= "" then descParts[#descParts + 1] = partText end
    if affixText ~= "" then descParts[#descParts + 1] = affixText end
    if def.legendaryDesc then descParts[#descParts + 1] = def.legendaryDesc end
    local item = {kind = "weapon", id = id, name = def.name, price = def.price, level = def.level, rarity = rarity, desc = table.concat(descParts, " / "), weaponDef = def}
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

moduleStatDefs = {
    damage = {label = "伤害", min = 0.06, max = 0.11, desc = function(v) return "伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.damage = p.stats.damage + v end},
    fireRate = {label = "射速", min = 0.06, max = 0.12, desc = function(v) return "射速 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.fireRate = p.stats.fireRate + v end},
    crit = {label = "暴击", min = 0.025, max = 0.055, desc = function(v) return "暴击率 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.crit = p.stats.crit + v end},
    critDamage = {label = "暴伤", min = 0.10, max = 0.20, desc = function(v) return "暴击伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.critDamage = p.stats.critDamage + v end},
    elementDamage = {label = "元素", min = 0.08, max = 0.16, desc = function(v) return "元素伤害 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.elementDamage = p.stats.elementDamage + v end},
    elementChance = {label = "附着", min = 0.025, max = 0.055, desc = function(v) return "元素附着 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.elementChance = p.stats.elementChance + v end},
    projectileSpeed = {label = "弹速", min = 0.06, max = 0.13, desc = function(v) return "弹速 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.projectileSpeed = p.stats.projectileSpeed + v end},
    range = {label = "射程", min = 0.06, max = 0.12, desc = function(v) return "射程 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.range = p.stats.range + v end},
    economy = {label = "回收", min = 0.06, max = 0.13, desc = function(v) return "结算材料 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.economy = p.stats.economy + v end},
    pickup = {label = "拾取", min = 8, max = 18, integer = true, desc = function(v) return "拾取范围 +" .. math.floor(v) end, apply = function(p, v) p.pickup = p.pickup + math.floor(v) end},
    hp = {label = "生命", min = 14, max = 26, integer = true, desc = function(v) return "最大生命 +" .. math.floor(v) end, apply = function(p, v) p.maxHp = p.maxHp + math.floor(v); p.hp = math.min(p.maxHp, p.hp + math.floor(v * 0.5)) end},
    lifesteal = {label = "吸血", min = 0.008, max = 0.020, desc = function(v) return "生命偷取 +" .. string.format("%.1f", v * 100) .. "%" end, apply = function(p, v) p.stats.lifesteal = p.stats.lifesteal + v end},
    lowHpDamage = {label = "血线", min = 0.10, max = 0.22, desc = function(v) return "低血增伤 +" .. math.floor(v * 100) .. "%" end, apply = function(p, v) p.stats.lowHpDamage = p.stats.lowHpDamage + v end}
}

moduleBlueprints = {
    {key = "fire_control", name = "火控模块", kind = "item", stats = {"damage", "crit"}},
    {key = "pulse_drive", name = "脉冲模块", kind = "mod", stats = {"fireRate", "projectileSpeed"}},
    {key = "scope_core", name = "瞄准模块", kind = "mod", stats = {"range", "critDamage"}},
    {key = "element_core", name = "元素模块", kind = "relic", stats = {"elementDamage", "elementChance"}},
    {key = "recycle_core", name = "回收模块", kind = "relic", stats = {"economy", "pickup"}},
    {key = "survival_core", name = "维生模块", kind = "item", stats = {"hp", "lifesteal"}},
    {key = "berserk_core", name = "狂热模块", kind = "legend", stats = {"critDamage", "lowHpDamage"}}
}

if Balance.moduleStats and next(Balance.moduleStats) then
    for id, cfg in pairs(Balance.moduleStats) do
        if moduleStatDefs[id] then
            moduleStatDefs[id].label = cfg.label or moduleStatDefs[id].label
            moduleStatDefs[id].min = cfg.min or moduleStatDefs[id].min
            moduleStatDefs[id].max = cfg.max or moduleStatDefs[id].max
            moduleStatDefs[id].format = cfg.format or moduleStatDefs[id].format
            moduleStatDefs[id].integer = cfg.format == "integer"
        end
    end
end
if Balance.moduleBlueprints and #Balance.moduleBlueprints > 0 then moduleBlueprints = Balance.moduleBlueprints end

function moduleValueScale(rarity)
    local wave = itemLevelForWave(Game.wave or 1)
    local waveScale = math.min(Balance.module_wave_scale_max or 2.35, 1 + (wave - 1) * (Balance.module_wave_scale_step or 0.055))
    local rarityScale = ({common = 1.00, rare = 1.14, epic = 1.30, legend = 1.48})[rarity] or 1
    return waveScale * rarityScale
end

function rollModuleEffect(statId, scale)
    local roll = moduleStatDefs[statId]
    local value = randf(roll.min, roll.max) * scale
    if roll.integer then value = math.floor(value + 0.5) end
    return {roll = roll, value = value}
end

function makeStatItem()
    local rarity = rollRarity()
    local blueprint = moduleBlueprints[rnd(1, #moduleBlueprints)]
    local scale = moduleValueScale(rarity)
    local effects, desc = {}, {}
    for _, statId in ipairs(blueprint.stats) do
        local effect = rollModuleEffect(statId, scale)
        effects[#effects + 1] = effect
        desc[#desc + 1] = effect.roll.desc(effect.value)
    end
    local item = {kind = blueprint.kind, rarity = rarity, level = itemLevelForWave(Game.wave or 1), mergeKey = blueprint.key, name = (rarityLabel[rarity] or rarity) .. " " .. blueprint.name, price = priced(22 + #effects * 9 + itemLevelForWave(Game.wave or 1), rarity), desc = table.concat(desc, " / "), effects = effects}
    item.buy = function() return applyItem(item) end
    return item
end

local function makeShieldItem()
    local rarity = rollRarity()
    local power = (rarityPower[rarity] or 1) * shopPowerScale()
    local cap = math.floor(randf(18, 38) * power)
    local regen = randf(0.8, 2.0) * power
    local flags = {"shieldBurst", "killShield", "fullShieldDamage"}
    local flag = (rarity == "epic" or rarity == "legend") and flags[rnd(1, #flags)] or nil
    local special = flag == "shieldBurst" and "破盾脉冲" or (flag == "killShield" and "击杀回盾" or (flag == "fullShieldDamage" and "满盾增伤" or "稳定护盾"))
    local item = {kind = "shield", rarity = rarity, level = itemLevelForWave(Game.wave or 1), name = (rarityLabel[rarity] or rarity) .. " " .. special, price = priced(22, rarity), desc = "护盾 +" .. cap .. " / 回复 +" .. string.format("%.1f", regen) .. (flag and (" / " .. special) or ""), shieldCap = cap, shieldRegen = regen, flag = flag}
    item.buy = function() return equipShield(item) end
    return item
end

local function makeTempItem()
    local item = cloneItem(tempItemPool[rnd(1, #tempItemPool)])
    local rarity = rollRarity()
    local scale = shopPowerScale()
    if item.buff then
        local scaled = {}
        for k, v in pairs(item.buff) do
            scaled[k] = type(v) == "number" and v > 0 and v * scale or v
        end
        item.buff = scaled
    end
    item.rarity = rarity
    item.level = itemLevelForWave(Game.wave or 1)
    item.price = priced(item.price or 14, rarity)
    item.name = (rarityLabel[rarity] or rarity) .. " " .. item.name
    item.desc = (item.desc or "") .. " · 强度×" .. string.format("%.1f", scale)
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
    {id = "blackbox", name = "黑箱", mark = "箱", color = C.purple, weight = 8},
    {id = "rare", name = "稀有", mark = "稀", color = C.orange, weight = 6}
}

local function clearedWaveCount()
    if Game.state == "shop" or Game.state == "levelup" then return math.max(0, Game.wave - 1) end
    return math.max(0, Game.wave)
end

local function clearRewardForWave(wave)
    local safeWave = math.max(1, wave or 1)
    return 12 + math.floor(safeWave * 1.5) + Game.danger * 2
end

local function shopBudgetHint()
    local coins = Game.coins or 0
    if coins < 18 then return "预算：优先便宜补强" end
    if coins < 34 then return "预算：约 1 件核心商品" end
    if coins < 56 then return "预算：1 件核心 + 1 次刷新" end
    return "预算：可追组合或锁定关键牌"
end

local function slotMilestone()
    return math.max(0, clearedWaveCount())
end

local function slotUnlocked()
    return slotMilestone() >= 1
end

local function slotHasFreeUse()
    local milestone = slotMilestone()
    return milestone >= 1 and not (Game.slotFreeUsed and Game.slotFreeUsed[milestone])
end

local function slotSpinCost()
    return 14 + slotMilestone() * 2 + (Game.slotPaidSpins or 0) * 4
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

local function grantBlackBoxSlotReward(label, jackpot)
    local roll = rnd(1, 3)
    if roll == 1 then
        local coins = jackpot and 90 or 34
        addCoins(coins, "blackbox-slot")
        Game.danger = math.min(8, Game.danger + (jackpot and 2 or 1))
        return label .. "：黑箱材料 +" .. coins .. "，危险 +" .. (jackpot and 2 or 1)
    elseif roll == 2 then
        local refresh = jackpot and 5 or 3
        local hpCost = jackpot and 25 or 20
        Game.freeRefresh = (Game.freeRefresh or 0) + refresh
        Game.player.hp = math.max(1, Game.player.hp - hpCost)
        return label .. "：黑箱刷新 +" .. refresh .. "，生命 -" .. hpCost
    else
        local item = makeStatItem()
        item.price = 0
        item.name = "黑箱转轮 " .. item.name
        placeSlotPrize(item)
        Game.player.stats.economy = (Game.player.stats.economy or 1) - (jackpot and 0.10 or 0.08)
        return label .. "：黑箱 0 费模块进商店，结算材料 -" .. (jackpot and "10%" or "8%")
    end
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
        elseif bestId == "blackbox" then
            return grantBlackBoxSlotReward(label, true)
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
        elseif bestId == "blackbox" then
            return grantBlackBoxSlotReward(label, false)
        else
            placeSlotPrize(slotPrizeItem(bestId))
            return label .. "：免费奖品进商店"
        end
    end
    if counts.blackbox and counts.blackbox > 0 then
        return grantBlackBoxSlotReward(label, false)
    end
    addCoins(10, "slot")
    return label .. "：材料 +10"
end

local function spinSlotMachine()
    if not slotUnlocked() then toast("通关 1 小关后解锁补给转轮"); return end
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

sideObjectiveDefs = {
    {id = "kill", name = "猎杀指标", desc = "击杀 22 个敌人", target = 22, reward = function() Game.freeRefresh = (Game.freeRefresh or 0) + 1; return "免费刷新 +1" end},
    {id = "treasure", name = "回收信标", desc = "击毁 1 个宝藏信标", target = 1, reward = function() addCoins(24, "objective"); return "材料 +24" end},
    {id = "elite", name = "斩首行动", desc = "击杀 1 个精英", target = 1, reward = function() addCoins(32, "objective"); return "材料 +32" end},
    {id = "nohit", name = "无伤窗口", desc = "连续 10 秒不受击", target = 10, reward = function() Game.player.maxShield = Game.player.maxShield + 16; Game.player.shield = math.min(Game.player.maxShield, Game.player.shield + 16); return "护盾上限 +16" end}
}

function rollSideObjective()
    local def = sideObjectiveDefs[rnd(1, #sideObjectiveDefs)]
    return {id = def.id, name = def.name, desc = def.desc, target = def.target, progress = 0, done = false, paid = false, reward = def.reward, timer = 0}
end

function objectiveTick(dt)
    local obj = Game.sideObjective
    if not obj or obj.done then return end
    if obj.id == "nohit" then
        obj.timer = (obj.timer or 0) + dt
        obj.progress = math.min(obj.target, obj.timer)
        if obj.timer >= obj.target then obj.done = true; toast("小目标完成：" .. obj.name) end
    elseif (obj.progress or 0) >= (obj.target or 1) then
        obj.done = true
        toast("小目标完成：" .. obj.name)
    end
end

function awardSideObjective()
    local obj = Game.sideObjective
    if obj and obj.done and not obj.paid and obj.reward then
        obj.paid = true
        local rewardText = obj.reward() or "奖励已发放"
        if Game.waveRewards then Game.waveRewards.objective = rewardText end
        toast("小目标奖励：" .. rewardText)
    end
end

function addObjectiveProgress(kind, amount)
    local obj = Game.sideObjective
    if not obj or obj.done or obj.id ~= kind then return end
    obj.progress = (obj.progress or 0) + (amount or 1)
    if obj.progress >= obj.target then obj.done = true; toast("小目标完成：" .. obj.name) end
end

dynamicEventPool = {
    {id = "ambush", name = "侧翼伏击", time = 8, run = function()
        local side = ({"left", "right", "top", "bottom"})[rnd(1, 4)]
        for _ = 1, 6 + Game.danger do spawnEnemy(enemyDefs.splinter, {side = side, scale = 1.05}) end
        toast("随机事件：" .. side .. " 侧伏击")
    end},
    {id = "treasure", name = "宝藏空投", time = 16, run = function()
        spawnEnemy(enemyDefs.treasure, {side = "top", scale = 1.10})
        for _ = 1, 3 do spawnEnemy(enemyDefs.drifter, {side = "top", scale = 1.05}) end
        toast("随机事件：宝藏信标带护卫出现")
    end},
    {id = "elite", name = "精英改造", time = 24, run = function()
        local side = ({"left", "right", "bottom"})[rnd(1, 3)]
        spawnEnemy(enemyDefs.elite, {side = side, scale = 0.92 + Game.danger * 0.03})
        toast("随机事件：改造精英接入")
    end}
}

function rollDynamicEvents()
    local used, events = {}, {}
    for _ = 1, math.min(3, #dynamicEventPool) do
        local ev = dynamicEventPool[rnd(1, #dynamicEventPool)]
        for _ = 1, 8 do
            if not used[ev.id] then break end
            ev = dynamicEventPool[rnd(1, #dynamicEventPool)]
        end
        used[ev.id] = true
        events[#events + 1] = ev
    end
    table.sort(events, function(a, b) return a.time < b.time end)
    return events
end

local function startWave()
    local plan = currentWavePlan()
    Game.player.x, Game.player.y = Game.w / 2, Game.h / 2
    Game.player.lastMoveX, Game.player.lastMoveY = 0, -1
    Game.state = "playing"
    Game.waveTime = plan.boss and 0 or SURVIVAL_DURATION
    Game.waveElapsed = 0
    Game.waveEventIndex = 1
    Game.bossDefeated = false
    Game.dynamicEvents = plan.boss and {} or rollDynamicEvents()
    Game.dynamicEventIndex = 1
    Game.sideObjective = rollSideObjective()
    Game.waveStartKills = Game.kills
    Game.objectiveProgress = 0
    Game.objectiveText = plan.boss and "击败 Boss" or ("生存 " .. SURVIVAL_DURATION .. "秒")
    Game.enemies, Game.bullets, Game.pickups = {}, {}, {}
    Game.enemyShots, Game.fireZones, Game.beams = {}, {}, {}
    Game.pendingRewardNextState = nil
    Game.waveRewards = {wave = Game.wave, reason = "", kills = 0, coins = 0, clear = 0}
    local p = Game.player
    p.waveDamageBonus = 0
    p.waveFireRateBonus = 0
    p.waveElementChance = 0
    p.waveElement = nil
    p.waveElementDamageBonus = 0
    p.waveEconomyBonus = 0
    p.waveShieldRegenMult = 0
    for _, buff in ipairs(Game.tempBuffs or {}) do
        p.waveDamageBonus = p.waveDamageBonus + (buff.damage or 0)
        p.waveFireRateBonus = p.waveFireRateBonus + (buff.fireRate or 0)
        p.waveElementChance = p.waveElementChance + (buff.elementChance or 0)
        p.waveElementDamageBonus = p.waveElementDamageBonus + (buff.elementDamage or 0)
        p.waveEconomyBonus = p.waveEconomyBonus + (buff.economy or 0)
        p.waveShieldRegenMult = p.waveShieldRegenMult + (buff.shieldRegenMult or 0)
        if buff.element then p.waveElement = buff.element end
        if buff.shield then p.maxShield = p.maxShield + buff.shield; p.shield = p.maxShield; p.tempShieldBonus = (p.tempShieldBonus or 0) + buff.shield end
    end
    Game.tempBuffs = {}
    Game.spawnTimer = 0.25
    Game.player.shieldDelay = 0
    toast(chapterWaveLabel(Game.wave) .. "：" .. (plan.name or "战斗") .. " / " .. affixLabel() .. " / 小目标 " .. (Game.sideObjective and Game.sideObjective.name or "无"))
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
    Game.freeRefresh = 1
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
    Game.beams = {}
    Game.waveRewards = nil
    Game.lastWaveIncome = nil
    Game.sideObjective = nil
    Game.dynamicEvents = {}
    Game.dynamicEventIndex = 1
    Game.clearTransition = nil
    Game.bossDefeated = false
    Game.blackBoxUsed = false
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
    Game.player.itemSlots = ITEM_SLOT_BASE
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
    addObjectiveProgress("kill", 1)
    if e.elite then addObjectiveProgress("elite", 1) end
    if e.boss then Game.bossDefeated = true; toast("Boss 击破") end
    if e.treasure then addObjectiveProgress("treasure", 1) end
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
    local bonus = currentAffixBonuses()
    local elemMult = elem ~= "kinetic" and ((p.stats.elementDamage or 1) * (bonus.elementDamage or 1)) or 1
    local defenseMult = 1
    if e.shield and e.shield > 0 then
        defenseMult = elem == "arc" and 1.65 or 1
    elseif e.defense == "armor" then
        defenseMult = elem == "corrode" and 1.65 or 1
    elseif e.defense == "flesh" then
        defenseMult = elem == "burn" and 1.45 or 1
    end
    if elem ~= "kinetic" then defenseMult = defenseMult * (1 + (p.waveElementDamageBonus or 0)) end
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
    local crit = rnd() < math.min(0.85, p.stats.crit + bonus.critBonus + (w.critBonus or 0)) or p.gear.nextCrit
    p.gear.nextCrit = false
    local lowHp = 1 + ((1 - clamp(p.hp / math.max(1, p.maxHp), 0, 1)) * (p.stats.lowHpDamage or 0))
    local fullShield = (p.gear.fullShieldDamage and p.shield >= p.maxShield) and 1.08 or 1
    local critMult = crit and ((p.stats.critDamage or 1) + (w.critDamageBonus or 0)) or 1
    local dmg = w.damage * (p.stats.damage + (p.waveDamageBonus or 0)) * bonus.playerDamage * lowHp * fullShield * critMult
    local elem = w.element
    if elem ~= "kinetic" then dmg = dmg * (w.elementPower or 1) end
    if p.waveElement and rnd() < (p.waveElementChance or 0) then elem = p.waveElement end
    w.shotCount = (w.shotCount or 0) + 1
    local pierce = (w.pierce or 0) + ((w.sixthPierce and w.shotCount % 6 == 0) and 1 or 0)
    local vx = math.cos(angle) * w.speed * p.stats.projectileSpeed
    local vy = math.sin(angle) * w.speed * p.stats.projectileSpeed
    if w.orbitShot then
        vx = vx + math.cos(angle + math.pi / 2) * 95
        vy = vy + math.sin(angle + math.pi / 2) * 95
    end
    if w.voidSlow or w.heavy or w.overloadTax then p.waveVoidSlowTimer = math.max(p.waveVoidSlowTimer or 0, w.voidSlow and 0.9 or 0.35) end
    local bulletRange = w.range * p.stats.range
    local baseSpeed = math.sqrt(vx * vx + vy * vy)
    local bulletLife = w.aura and 4.2 or clamp(bulletRange / math.max(180, baseSpeed) + 0.9, 1.2, 4.8)
    Game.bullets[#Game.bullets + 1] = {
        x = p.x, y = p.y, vx = vx, vy = vy,
        r = w.splash and 7 or 4, damage = dmg, element = elem, range = bulletRange,
        traveled = 0, life = bulletLife, pierce = pierce, bounce = (w.bounce or 0) + (p.gear.echoOverdrive and 1 or 0),
        splash = w.splash, aura = w.aura, color = elements[elem].color, sprite = w.projectileSprite, crit = crit, target = target, source = w.name, brand = w.brand,
        sparkSplit = w.sparkSplit, echoRamp = w.echoRamp, hiveSplit = w.hiveSplit, fireSplash = w.fireSplash,
        executeLowHp = w.executeLowHp,
        arcMark = w.arcMark, voidCollapse = w.voidCollapse, legendRefundShot = w.legendRefundShot, killHaste = w.killHaste, weaponRef = w
    }
end

local function useChainWeapon(w, target)
    local p = Game.player
    local hit = target
    local used = {}
    local fromX, fromY = p.x, p.y
    local chains = (w.chain or 1) + (p.gear.echoOverdrive and 1 or 0)
    for _ = 1, chains do
        if not hit then break end
        local bonus = currentAffixBonuses()
        local crit = rnd() < math.min(0.85, p.stats.crit + bonus.critBonus + (w.critBonus or 0))
        local lowHp = 1 + ((1 - clamp(p.hp / math.max(1, p.maxHp), 0, 1)) * (p.stats.lowHpDamage or 0))
        local fullShield = (p.gear.fullShieldDamage and p.shield >= p.maxShield) and 1.08 or 1
        local elem = (p.waveElement and rnd() < (p.waveElementChance or 0)) and p.waveElement or w.element
        local critMult = crit and ((p.stats.critDamage or 1) + (w.critDamageBonus or 0)) or 1
        local hitDamage = w.damage * (p.stats.damage + (p.waveDamageBonus or 0)) * bonus.playerDamage * lowHp * fullShield * critMult * (elem ~= "kinetic" and (w.elementPower or 1) or 1)
        if w.executeLowHp and hit.hp / math.max(1, hit.maxHp or hit.hp) < 0.35 then hitDamage = hitDamage * 1.35 end
        addBeam(fromX, fromY, hit.x, hit.y, elements[elem].color)
        local dead = damageEnemy(hit, hitDamage, elem, crit, w.name)
        if w.arcMark then
            hit.arcMarks = (hit.arcMarks or 0) + 1
            if hit.arcMarks >= 3 then hit.arcMarks = 0; damageEnemy(hit, hitDamage * 0.42, "arc", false, w.name .. "电痕") end
        end
        if w.killHaste and dead then p.gear.coinHasteTimer = math.max(p.gear.coinHasteTimer or 0, 1.4) end
        if w.legendRefundShot and dead then p.gear.nextCrit = true; w.timer = 0 end
        if dead then used[hit] = true end
        burst(hit.x, hit.y, elements[elem].color, 5, 90)
        used[hit] = true
        local nextHit, bestD = nil, 170
        for _, e in ipairs(Game.enemies) do
            local d = distance(hit.x, hit.y, e.x, e.y)
            if not used[e] and d < bestD then nextHit, bestD = e, d end
        end
        if nextHit then fromX, fromY = hit.x, hit.y end
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
                        damageEnemy(e, b.damage * (b.voidCollapse and 0.55 or 0.38), b.element, false, b.source)
                        if b.voidCollapse then burst(e.x, e.y, b.color, 5, 80) end
                    end
                end
            end
        end
        b.life = (b.life or 3.0) - dt
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        b.traveled = b.traveled + math.sqrt(b.vx * b.vx + b.vy * b.vy) * dt
        local remove = b.traveled > b.range or b.life <= 0 or b.x < -120 or b.x > Game.w + 120 or b.y < -120 or b.y > Game.h + 120
        for _, e in ipairs(Game.enemies) do
            if not remove and distance(b.x, b.y, e.x, e.y) < b.r + e.r then
                local hitDamage = b.damage
                if b.executeLowHp and e.hp / math.max(1, e.maxHp or e.hp) < 0.35 then hitDamage = hitDamage * 1.35 end
                local dead = damageEnemy(e, hitDamage, b.element, b.crit, b.source)
                if b.arcMark then
                    e.arcMarks = (e.arcMarks or 0) + 1
                    if e.arcMarks >= 3 then e.arcMarks = 0; damageEnemy(e, hitDamage * 0.42, "arc", false, b.source .. "电痕") end
                end
                burst(b.x, b.y, b.color, 4, 90)
                if (b.sparkSplit or b.hiveSplit) and dead then
                    for _, other in ipairs(Game.enemies) do
                        if other ~= e and distance(e.x, e.y, other.x, other.y) < (b.hiveSplit and 150 or 120) then damageEnemy(other, hitDamage * (b.hiveSplit and 0.36 or 0.30), b.element, false, b.source .. (b.hiveSplit and "虫群" or "火花")) end
                    end
                end
                if b.killHaste and dead then Game.player.gear.coinHasteTimer = math.max(Game.player.gear.coinHasteTimer or 0, 1.4) end
                if b.legendRefundShot and dead then Game.player.gear.nextCrit = true; if b.weaponRef then b.weaponRef.timer = 0 end end
                if b.splash then
                    for _, other in ipairs(Game.enemies) do
                        if other ~= e and distance(e.x, e.y, other.x, other.y) < b.splash then
                            damageEnemy(other, hitDamage * ((Game.player.gear.fireSplash or b.fireSplash) and b.element == "burn" and 0.62 or 0.45), b.element, false, b.source)
                        end
                    end
                    burst(e.x, e.y, b.color, 14, 150)
                    if b.fireSplash and b.element == "burn" then igniteFireZone(e.x, e.y, math.min(110, (b.splash or 58) + 18), 2.8, math.max(4, hitDamage * 0.10)) end
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
                        if b.echoRamp then b.damage = b.damage * 1.12 end
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
    local skill = p.activeSkill
    if p.invuln > 0 or (skill and (skill.duration or 0) > 0) then return end
    if Game.sideObjective and Game.sideObjective.id == "nohit" and not Game.sideObjective.done then
        Game.sideObjective.timer = 0
        Game.sideObjective.progress = 0
    end
    p.invuln = 0.55
    p.shieldDelay = 2.4
    playCue("hit"); Game.shake = 0.25
    amount = math.max(1, amount)
    local hadShield = p.shield > 0
    if p.shield > 0 then
        local used = math.min(p.shield, amount)
        p.shield = p.shield - used
        amount = amount - used
    end
    if amount > 0 then p.hp = p.hp - amount end
    if hadShield and p.shield <= 0 then
        addText(p.x - 34, p.y - 42, "护盾破裂", C.cyan)
        burst(p.x, p.y, C.cyan, 24, 190)
        if p.gear.shieldBurst then
            for _, e in ipairs(Game.enemies) do
                if distance(p.x, p.y, e.x, e.y) < 165 then damageEnemy(e, 32 * p.stats.damage, "arc", false, "护盾脉冲") end
            end
            burst(p.x, p.y, C.cyan, 38, 240)
        end
    end
    if p.hp <= 0 then Game.state = "gameover" end
end

local function fireEnemyShot(e, a)
    Game.enemyShots[#Game.enemyShots + 1] = {x = e.x, y = e.y, vx = math.cos(a) * 250, vy = math.sin(a) * 250, r = 6, damage = e.damage * 0.75, color = e.color, life = 3.0}
end

function igniteFireZone(x, y, radius, duration, damage)
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
    local eng = (p.gear.echoOverdrive and 1 or 0)
    local shieldAura = p.gear.shieldArcAura and p.shield >= p.maxShield and eng <= 0
    if eng <= 0 and not shieldAura then return end
    if not (p.gear.autoArc or shieldAura) then return end
    p.engineerTimer = (p.engineerTimer or 0) - dt
    if p.engineerTimer > 0 then return end
    p.engineerTimer = math.max(0.45, 1.15 - eng * 0.06)
    local target = nearestEnemy(p.x, p.y, 420)
    if target then
        damageEnemy(target, 8 + eng * 5, "arc", false, "追踪电弧")
        burst(target.x, target.y, C.cyan, 6, 90)
    end
end

local function randomWanderAngle(e, dt, minTime, maxTime, fallbackAngle, centerBias)
    e.wanderTimer = (e.wanderTimer or 0) - dt
    if e.wanderTimer <= 0 then
        e.wanderTimer = randf(minTime or 0.65, maxTime or 1.45)
        e.wanderAngle = rnd() * TAU
    end
    -- 屏幕外生成时先自然入场；进入战斗区域后随机漫步。
    if not e.enteredArena then return fallbackAngle end
    e.centerDriftTime = (e.centerDriftTime or 0) + dt
    local wander = e.wanderAngle or fallbackAngle
    local bias = (centerBias or 0) * clamp((e.centerDriftTime or 0) / 5.0, 0.22, 1.0)
    if bias <= 0 then return wander end
    local centerAngle = angleTo(e.x, e.y, Game.w / 2, Game.h / 2 + 40)
    local vx = math.cos(wander) * (1 - bias) + math.cos(centerAngle) * bias
    local vy = math.sin(wander) * (1 - bias) + math.sin(centerAngle) * bias
    return math.atan2(vy, vx)
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
            moveAngle = randomWanderAngle(e, dt, 0.50, 1.15, a, 0.34)
            spd = spd * (e.enteredArena and 0.96 or 1.08)
        elseif behavior == "shooter" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if distToPlayer < 560 and e.shootTimer <= 0 then
                fireEnemyShot(e, a)
                e.shootTimer = 1.65
            end
            moveAngle = randomWanderAngle(e, dt, 0.55, 1.25, a, 0.52)
            spd = spd * (e.enteredArena and 0.62 or 1.02)
        elseif behavior == "bomber" then
            e.shootTimer = (e.shootTimer or 0) - dt
            if distToPlayer < 620 and e.shootTimer <= 0 then
                local leadX = p.x + (p.lastMoveX or 0) * 54 + randf(-36, 36)
                local leadY = p.y + (p.lastMoveY or 0) * 54 + randf(-36, 36)
                throwFireBomb(e, clamp(leadX, 70, Game.w - 70), clamp(leadY, 150, Game.h - 70))
                e.shootTimer = randf(2.2, 3.2)
            end
            moveAngle = randomWanderAngle(e, dt, 0.65, 1.35, a, 0.48)
            spd = spd * (e.enteredArena and 0.56 or 0.98)
        elseif behavior == "charger" then
            e.dashTimer = (e.dashTimer or 0) - dt
            if e.dashTimer <= 0 and distToPlayer < 360 then
                spd = spd * 2.4
                e.dashTimer = 2.2
                addText(e.x, e.y - e.r - 8, "突进", C.orange)
            end
        elseif behavior == "rammer" then
            e.chargeCooldown = math.max(0, (e.chargeCooldown or randf(0.4, 1.2)) - dt)
            if e.chargeState == "windup" then
                e.chargeTimer = (e.chargeTimer or 0) - dt
                moveAngle = e.chargeAngle or a
                spd = spd * 0.10
                if e.chargeTimer <= 0 then
                    e.chargeState = "dash"
                    e.chargeTimer = e.chargeDashTime or 0.44
                    addText(e.x, e.y - e.r - 10, "冲锋", C.red)
                end
            elseif e.chargeState == "dash" then
                e.chargeTimer = (e.chargeTimer or 0) - dt
                moveAngle = e.chargeAngle or a
                spd = spd * (e.chargeSpeedMult or 4.4)
                if e.chargeTimer <= 0 then
                    e.chargeState = "recover"
                    e.chargeTimer = 0.62
                    e.chargeCooldown = randf(1.0, 1.5)
                end
            elseif e.chargeState == "recover" then
                e.chargeTimer = (e.chargeTimer or 0) - dt
                spd = spd * 0.42
                if e.chargeTimer <= 0 then e.chargeState = nil end
            elseif e.enteredArena and e.chargeCooldown <= 0 and distToPlayer < 560 and distToPlayer > 90 then
                e.chargeState = "windup"
                e.chargeTimer = 0.74
                e.chargeAngle = a
                e.chargeWarnLength = clamp(distToPlayer + 160, 260, 520)
                spd = 0
                addText(e.x, e.y - e.r - 10, "蓄力", C.red)
            else
                moveAngle = randomWanderAngle(e, dt, 0.60, 1.20, a, 0.42)
                spd = spd * (e.enteredArena and 0.82 or 1.12)
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
        if not e.enteredArena then spd = spd * (e.boss and 3.4 or (e.elite and 2.5 or 1.7)) end
        e.x = e.x + math.cos(moveAngle) * spd * dt
        e.y = e.y + math.sin(moveAngle) * spd * dt
        markAndClampEnemyArena(e)
        if distance(e.x, e.y, p.x, p.y) < e.r + p.r then
            if (e.damage or 0) > 0 then damagePlayer(e.damage * ((e.behavior == "rammer" and e.chargeState == "dash") and 1.45 or 1)) end
            if e.behavior == "rammer" and e.chargeState == "dash" then e.chargeState = "recover"; e.chargeTimer = 0.72; e.chargeCooldown = 1.4 end
            e.x = e.x - math.cos(a) * 18
            e.y = e.y - math.sin(a) * 18
            markAndClampEnemyArena(e)
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
    p.waveVoidSlowTimer = math.max(0, (p.waveVoidSlowTimer or 0) - dt)
    local moveX, moveY, speedMult = dx, dy, (p.waveVoidSlowTimer and p.waveVoidSlowTimer > 0) and 0.88 or 1
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
    Game.player.invuln = math.max(Game.player.invuln or 0, skill.duration)
    skill.cd = skill.cooldown or ACTIVE_SKILL_CD
    playCue("level")
    toast(skill.name .. "：冲刺")
    return true
end

local function finalizeWaveReward(reason)
    local p = Game.player
    local finishedWave = Game.wave
    local summary = Game.waveRewards or {wave = finishedWave, kills = 0, coins = 0, clear = 0}
    summary.wave = finishedWave
    summary.reason = reason or "波次完成"
    Game.waveRewards = summary
    awardSideObjective()
    local base = clearRewardForWave(finishedWave)
    addCoins(base, "clear")
    Game.lastWaveIncome = (Game.waveRewards and Game.waveRewards.coins) or base
    generateLevelChoices()
    if Game.wave >= Game.maxWave then
        Game.pendingRewardNextState = "victory"
        Game.state = "levelup"
        return
    end
    Game.wave = Game.wave + 1
    Game.runStats.highestWave = math.max(Game.runStats.highestWave or 1, Game.wave)
    Game.pendingRewardNextState = "shop"
    Game.state = "levelup"
end

local function completeWave(reason)
    if Game.state == "clearing" then return end
    Game.clearTransition = {reason = reason or "波次完成", timer = 0, pulse = 0.06}
    Game.state = "clearing"
    Game.objectiveText = "目标达成 · 清场中"
    Game.enemyShots, Game.bullets, Game.fireZones = {}, {}, {}
    Game.spawnTimer = 999
    Game.shake = math.max(Game.shake or 0, 0.36)
    playCue("elite")
    burst(Game.player.x, Game.player.y, C.cyan, 22, 210)
    toast("目标达成：清场")
end

local function updateWaveClear(dt)
    local t = Game.clearTransition
    if not t then finalizeWaveReward("波次完成"); return end
    t.timer = (t.timer or 0) + dt
    t.pulse = (t.pulse or 0) - dt
    Game.objectiveText = "目标达成 · 清场中"
    if t.pulse <= 0 then
        t.pulse = #Game.enemies > 8 and 0.035 or 0.065
        local e = table.remove(Game.enemies)
        if e then
            burst(e.x, e.y, e.color or C.white, e.boss and 64 or (e.elite and 28 or 16), e.boss and 320 or 210)
            addText(e.x, e.y - (e.r or 14), "毁灭", e.boss and C.red or C.gold)
            Game.shake = math.max(Game.shake or 0, e.boss and 0.55 or 0.22)
        elseif t.timer > 0.65 then
            Game.clearTransition = nil
            finalizeWaveReward(t.reason)
        end
    end
    if t.timer > 2.4 then
        Game.enemies = {}
        Game.clearTransition = nil
        finalizeWaveReward(t.reason)
    end
end

local function updatePlaying(dt)
    local plan = currentWavePlan()
    Game.time = Game.time + dt
    Game.waveElapsed = (Game.waveElapsed or 0) + dt
    if not plan.boss then Game.waveTime = Game.waveTime - dt end

    local events = plan.events or {}
    while Game.waveEventIndex and events[Game.waveEventIndex] and Game.waveElapsed >= events[Game.waveEventIndex].time do
        local event = events[Game.waveEventIndex]
        spawnEnemy(enemyDefs[event.enemy] or weightedEnemy(plan), {side = event.side, scale = event.enemy == "boss" and 1 or 1.08})
        if event.toast then toast(event.toast) end
        Game.waveEventIndex = Game.waveEventIndex + 1
    end
    local dynamicEvents = Game.dynamicEvents or {}
    while Game.dynamicEventIndex and dynamicEvents[Game.dynamicEventIndex] and Game.waveElapsed >= dynamicEvents[Game.dynamicEventIndex].time do
        local event = dynamicEvents[Game.dynamicEventIndex]
        if event.run then event.run() end
        Game.dynamicEventIndex = Game.dynamicEventIndex + 1
    end
    objectiveTick(dt)

    Game.spawnTimer = (Game.spawnTimer or 0) - dt
    if Game.spawnTimer <= 0 and not (plan.boss and Game.waveElapsed < 4) then
        spawnPack(plan)
        local pressure = math.max(0, Game.waveElapsed / SURVIVAL_DURATION)
        local bonus = currentAffixBonuses()
        local curve = survivalEnemyCurve()
        Game.spawnTimer = math.max(0.38, ((plan.interval or 1.0) * bonus.intervalMult * curve.interval) - pressure * 0.10)
    end
    updatePlayer(dt)
    updateWeapons(dt)
    updateAutoArc(dt)
    updateBullets(dt)
    updateEnemyShots(dt)
    updateFireZones(dt)
    updateEnemies(dt)

    local obj = Game.sideObjective
    local extra = obj and (" · " .. obj.name .. " " .. math.floor(obj.progress or 0) .. "/" .. obj.target) or ""
    if plan.boss then
        local boss
        for _, e in ipairs(Game.enemies or {}) do if e.boss then boss = e; break end end
        if boss then
            local pct = math.max(0, math.ceil((boss.hp / math.max(1, boss.maxHp or boss.hp)) * 100))
            Game.objectiveText = "击败 Boss · " .. pct .. "%" .. extra
        else
            Game.objectiveText = (Game.bossDefeated and "Boss 已击破" or "击败 Boss") .. extra
        end
        if Game.bossDefeated and Game.state == "playing" then completeWave("Boss击破") end
    else
        local remain = math.max(0, math.ceil(Game.waveTime))
        Game.objectiveText = "生存 " .. math.floor(remain / 60) .. ":" .. string.format("%02d", remain % 60) .. extra
        if Game.waveTime <= 0 and Game.state == "playing" then
            Game.waveTime = 0
            completeWave(Game.wave >= Game.maxWave and "生存完成" or "波次完成")
        end
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
    for i = #Game.beams, 1, -1 do
        local b = Game.beams[i]
        b.life = b.life - dt
        if b.life <= 0 then table.remove(Game.beams, i) end
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
    if Game.state == "playing" then updatePlaying(dt) elseif Game.state == "clearing" then updateWaveClear(dt) end
    if os.getenv("LOVE_AUTOACTIVE") == "1" and Game.state == "playing" and not Game.autoActiveDone and Game.time > 0.35 then
        Game.autoActiveDone = true
        useActiveSkill()
    end
    if os.getenv("LOVE_AUTOCLEARSHOT") == "1" and not Game.autoClearDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoClearStarted then
            Game.autoClearStarted = true
            for _ = 1, 8 do spawnEnemy(enemyDefs.splinter, {side = pickSpawnSide(currentWavePlan()), scale = 0.85}) end
            completeWave("测试清场")
        end
        Game.autoClearClock = (Game.autoClearClock or 0) + dt
        if Game.autoClearClock > 0.55 then
            Game.autoClearDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-clear.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOPAUSE") == "1" and not Game.autoPauseDone then
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
            if os.getenv("LOVE_AUTOWAVE") then
                Game.wave = clamp(tonumber(os.getenv("LOVE_AUTOWAVE")) or Game.wave, 1, Game.maxWave)
                Game.runStats.highestWave = Game.wave
            end
            enterShop()
        end
        if os.getenv("LOVE_AUTOSHOP_TAB") then Game.shopTab = os.getenv("LOVE_AUTOSHOP_TAB") end
        if os.getenv("LOVE_AUTOBUILD_TAB") then Game.buildPanelTab = os.getenv("LOVE_AUTOBUILD_TAB") end
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
    elseif os.getenv("LOVE_AUTOBEAMSHOT") == "1" and not Game.autoBeamDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoBeamStarted then
            Game.autoBeamStarted = true
            Game.player.weapons = {}
            addWeapon(weaponDefs.coil)
            local e = enemyDefs.shell
            for n = 1, 3 do spawnEnemy(e, {side = "right", scale = 0.25}) end
            addBeam(Game.player.x, Game.player.y, Game.player.x + 260, Game.player.y - 80, C.cyan)
        end
        Game.autoBeamClock = (Game.autoBeamClock or 0) + dt
        if Game.autoBeamClock > 0.22 then
            Game.autoBeamDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-beam.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOCHARGERSHOT") == "1" and not Game.autoChargerDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoChargerStarted then
            Game.autoChargerStarted = true
            Game.enemies = {}
            local def = enemyDefs.rammer
            local e = {name = def.name, x = Game.player.x + 250, y = Game.player.y - 80, r = def.r, hp = def.hp, maxHp = def.hp, shield = 0, maxShield = 0, defense = def.defense, shieldRegen = 0, speed = def.speed, damage = def.damage, armor = def.armor or 0, color = def.color, xp = def.xp, coin = def.coin, sprite = def.sprite, behavior = def.behavior, enteredArena = true, chargeState = "windup", chargeTimer = 0.55, chargeAngle = angleTo(Game.player.x + 250, Game.player.y - 80, Game.player.x, Game.player.y), chargeWarnLength = 430}
            Game.enemies[#Game.enemies + 1] = e
        end
        Game.autoChargerClock = (Game.autoChargerClock or 0) + dt
        if Game.autoChargerClock > 0.18 then
            Game.autoChargerDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-charger.png")
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
        if Game.state == "menu" then
            resetRun()
            if os.getenv("LOVE_AUTOWAVE") then
                Game.wave = clamp(tonumber(os.getenv("LOVE_AUTOWAVE")) or Game.wave, 1, Game.maxWave)
                Game.runStats.highestWave = Game.wave
                startWave()
            end
        end
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

local waveThreatSummary

local function drawHud()
    local p = Game.player
    local hpPct = clamp(p.hp / math.max(1, p.maxHp), 0, 1)
    local shieldPct = clamp(p.shield / math.max(1, p.maxShield), 0, 1)
    local dangerPulse = 0.5 + 0.5 * math.sin((love.timer.getTime() or 0) * 8.0)
    local hudY, hudH = 14, 116
    panel(18, hudY, Game.w - 36, hudH)

    -- 左：生存状态必须比材料/击杀更抢眼。原型可以乱，战斗 HUD 不能乱。
    local lx = 36
    local hpColor = hpPct < 0.35 and C.red or C.pink
    drawBarCapsule("生命", math.ceil(p.hp) .. "/" .. p.maxHp, lx, hudY + 12, 346, 34, hpPct, hpColor)
    drawBarCapsule("护盾", math.ceil(p.shield) .. "/" .. p.maxShield, lx, hudY + 54, 346, 30, shieldPct, C.cyan)
    if hpPct < 0.35 then
        color(C.red, 0.16 + dangerPulse * 0.18)
        love.graphics.rectangle("line", lx - 4, hudY + 8, 354, 42, 12, 12)
        love.graphics.setFont(Game.fonts.tiny)
        color(C.red, 0.90)
        love.graphics.printf("核心受损", lx + 236, hudY + 20, 96, "right")
    end
    drawCapsule("材料 " .. Game.coins, lx + 370, hudY + 18, 118, 28, {fg = C.gold, border = C.gold, align = "center", padX = 14, bgAlpha = 0.22, borderAlpha = 0.16})
    drawCapsule("击杀 " .. Game.kills, lx + 370, hudY + 56, 118, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.white, align = "center", padX = 14, bgAlpha = 0.16, borderAlpha = 0.10})

    -- 中：主任务。普通关显示倒计时，关底显示 Boss 击破目标。
    local plan = currentWavePlan()
    local bossMode = plan.boss == true
    local midX = Game.w / 2
    local timerW, timerH = 156, 76
    local timerX, timerY = midX - timerW / 2, hudY + 12
    color(C.white, 0.10)
    love.graphics.rectangle("fill", timerX, timerY, timerW, timerH, 18, 18)
    color(C.cyan, 0.42)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", timerX + 0.5, timerY + 0.5, timerW - 1, timerH - 1, 18, 18)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(bossMode and "关底目标" or "剩余生存", timerX, timerY + 8, timerW, "center")
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf(bossMode and "BOSS" or string.format("%02d", math.max(0, math.ceil(Game.waveTime))), timerX, timerY + 24, timerW, "center")

    drawCapsule(chapterWaveLabel(Game.wave), midX - 252, hudY + 22, 130, 28, {fg = C.gold, border = C.gold, borderAlpha = 0.18})
    drawCapsule(plan.name or "生存波次", midX - 252, hudY + 58, 130, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.gold, bgAlpha = 0.26, borderAlpha = 0.12})
    drawCapsule(Game.objectiveText or selectedObjective().name, midX + 122, hudY + 22, 162, 28, {fg = C.cyan, border = C.cyan, borderAlpha = 0.20})
    drawCapsule(survivalPhaseName() .. " · 危险 " .. Game.danger, midX + 122, hudY + 58, 162, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.cyan, bgAlpha = 0.26, borderAlpha = 0.12})

    -- 右：即时操作/威胁。长说明留给商店情报，战斗中别念小作文。
    local rx, rw = Game.w - 430, 392
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
    drawCapsule(skillText, rx, hudY + 14, rw, 30, {font = Game.fonts.tiny, fg = skillFg, border = skillFg, bgAlpha = 0.28, borderAlpha = 0.22, align = "left", padX = 14})
    drawCapsule("威胁：" .. waveThreatSummary(Game.wave), rx, hudY + 52, rw, 28, {font = Game.fonts.tiny, fg = C.gold, border = C.gold, bgAlpha = 0.24, borderAlpha = 0.16, align = "left", padX = 14})

    local boss = nil
    for _, e in ipairs(Game.enemies or {}) do if e.boss then boss = e; break end end
    if boss then
        if (boss.maxShield or 0) > 0 then
            drawBarCapsule("Boss护盾", math.ceil(math.max(0, boss.shield or 0)) .. "/" .. math.ceil(boss.maxShield or 0), rx, hudY + 84, rw, 18, math.max(0, boss.shield or 0) / math.max(1, boss.maxShield or 1), C.cyan)
            drawBarCapsule("Boss生命", math.ceil(boss.hp) .. "/" .. math.ceil(boss.maxHp or boss.hp), rx, hudY + 106, rw, 18, boss.hp / math.max(1, boss.maxHp or boss.hp), C.red)
        else
            drawBarCapsule("Boss生命", math.ceil(boss.hp) .. "/" .. math.ceil(boss.maxHp or boss.hp), rx, hudY + 86, rw, 22, boss.hp / math.max(1, boss.maxHp or boss.hp), C.red)
        end
    else
        drawCapsule("敌群 " .. #Game.enemies, rx, hudY + 86, rw, 22, {font = Game.fonts.tiny, fg = C.muted, border = C.white, bgAlpha = 0.16, borderAlpha = 0.10, align = "left", padX = 14})
    end
end

local function drawCombatWarningOverlay()
    if Game.state ~= "playing" then return end
    local p = Game.player
    local hpPct = clamp(p.hp / math.max(1, p.maxHp), 0, 1)
    if hpPct >= 0.35 then return end
    local t = love.timer.getTime() or 0
    local pulse = 0.45 + 0.55 * math.sin(t * 8.0)
    love.graphics.setBlendMode("add")
    color(C.red, 0.08 + pulse * 0.08)
    love.graphics.rectangle("fill", 0, 0, Game.w, 38)
    love.graphics.rectangle("fill", 0, Game.h - 38, Game.w, 38)
    love.graphics.rectangle("fill", 0, 0, 38, Game.h)
    love.graphics.rectangle("fill", Game.w - 38, 0, 38, Game.h)
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(Game.fonts.small)
    color(C.red, 0.72 + pulse * 0.18)
    love.graphics.printf("警告：核心生命过低", 0, 142, Game.w, "center")
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
    for _, beam in ipairs(Game.beams or {}) do
        local a = clamp((beam.life or 0) / math.max(0.01, beam.max or 0.16), 0, 1)
        love.graphics.setBlendMode("add")
        love.graphics.setLineWidth(12)
        color(beam.color, 0.28 * a)
        love.graphics.line(beam.x1, beam.y1, beam.x2, beam.y2)
        love.graphics.setLineWidth(4)
        color(beam.color, 0.96 * a)
        love.graphics.line(beam.x1, beam.y1, beam.x2, beam.y2)
        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha")
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
        if e.behavior == "rammer" and e.chargeState == "windup" then
            local a = e.chargeAngle or angleTo(e.x, e.y, p.x, p.y)
            local len = e.chargeWarnLength or 420
            local x2, y2 = e.x + math.cos(a) * len, e.y + math.sin(a) * len
            local pulse = 0.48 + 0.52 * math.sin((love.timer.getTime() or 0) * 16)
            love.graphics.setBlendMode("add")
            love.graphics.setLineWidth(14)
            color(C.red, 0.10 + pulse * 0.10)
            love.graphics.line(e.x, e.y, x2, y2)
            love.graphics.setLineWidth(4)
            color(C.red, 0.54 + pulse * 0.28)
            love.graphics.line(e.x, e.y, x2, y2)
            love.graphics.setLineWidth(1)
            love.graphics.setBlendMode("alpha")
        elseif e.behavior == "rammer" and e.chargeState == "dash" then
            local a = e.chargeAngle or angleTo(e.x, e.y, p.x, p.y)
            love.graphics.setBlendMode("add")
            color(C.red, 0.30)
            love.graphics.polygon("fill", e.x - math.cos(a) * 88 - math.sin(a) * 18, e.y - math.sin(a) * 88 + math.cos(a) * 18, e.x - math.cos(a) * 88 + math.sin(a) * 18, e.y - math.sin(a) * 88 - math.cos(a) * 18, e.x, e.y)
            love.graphics.setBlendMode("alpha")
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
        -- UX：敌人必须从背景里“站出来”，否则玩家不是战死，是被背景谋杀。
        color(C.white, e.boss and 0.72 or (e.elite and 0.56 or 0.30))
        love.graphics.setLineWidth(e.boss and 5 or (e.elite and 4 or 2))
        love.graphics.circle("line", e.x, e.y, e.r * (e.boss and 2.25 or 2.05))
        love.graphics.setLineWidth(1)
        if e.boss or e.elite or e.behavior == "shooter" or e.behavior == "bomber" or e.behavior == "rammer" then
            local tag = e.boss and "BOSS" or (e.elite and "精英" or (e.behavior == "bomber" and "火力" or (e.behavior == "rammer" and "冲锋" or "远程")))
            local tagW = e.boss and 74 or 52
            local tagX = clamp(e.x - tagW / 2, 46, Game.w - tagW - 46)
            local tagY = clamp(e.y - e.r - 34, 156, Game.h - 96)
            color(e.color, 0.82)
            love.graphics.rectangle("fill", tagX, tagY, tagW, 20, 6, 6)
            color(C.bgA, 0.92)
            love.graphics.setFont(Game.fonts.tiny)
            love.graphics.printf(tag, tagX, tagY + 4, tagW, "center")
        end
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
        if e.hp < e.maxHp then
            local bw = e.boss and e.r * 3.0 or e.r * 2.55
            local bh = e.boss and 8 or 6
            local barX = clamp(e.x - bw / 2, 46, Game.w - bw - 46)
            local barY = clamp(e.y - e.r - 16, 178, Game.h - 82)
            bar(barX, barY, bw, bh, e.hp / e.maxHp, C.red)
        end
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
        local hpPct = clamp(p.hp / math.max(1, p.maxHp), 0, 1)
        if hpPct < 0.35 then
            local pulse = 0.45 + 0.55 * math.sin((love.timer.getTime() or 0) * 8)
            love.graphics.setBlendMode("add")
            color(C.red, 0.22 + pulse * 0.18)
            love.graphics.circle("line", p.x, p.y, p.r + 26 + pulse * 8)
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
        if skill and (skill.cd or 0) > 0 then
            local cdMax = skill.cooldown or ACTIVE_SKILL_CD
            local pctReady = clamp(1 - ((skill.cd or 0) / math.max(0.1, cdMax)), 0, 1)
            love.graphics.setColor(0, 0, 0, 0.64)
            love.graphics.rectangle("fill", barX - 1, barY, barW + 2, barH + 2, 3, 3)
            color(C.white, 0.72)
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
    color(C.cyan, 0.78)
    love.graphics.printf("6大关30小关 · 首关养成 · 二关升压", 0, 126, w, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted, 0.70)
    love.graphics.printf("撑住倒计时，收集材料，把一台白板机体养成怪物。", 0, 156, w, "center")

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
    love.graphics.printf("每小关活过 30 秒，撑完整场战役", cx - 300, cy + 160, 600, "center")

    local deckX, deckY, deckW, deckH = 90, h - 168, w - 180, 126
    love.graphics.setColor(0.012, 0.016, 0.040, 0.78)
    love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 16, 16)
    color(C.cyan, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", deckX, deckY, deckW, deckH, 16, 16)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Game.fonts.small)
    color(C.cyan)
    love.graphics.printf("当前模式", deckX + 28, deckY + 26, 360, "left")
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf("战役模式", deckX + 28, deckY + 56, 360, "left")
    love.graphics.setFont(Game.fonts.small)

    local dangerText = Game.danger == 0 and "基础难度" or ("危险等级 " .. Game.danger)
    color(C.gold)
    love.graphics.printf("难度选择", deckX + deckW - 358, deckY + 26, 330, "right")
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(dangerText, deckX + deckW - 358, deckY + 52, 330, "right")

    uiButton("开始实验", w / 2 - 140, deckY + 30, 280, 62, C.gold, C.white, Game.fonts.normal)
    -- 首页不再提供模式切换，只保留战役模式；难度仍可调整。
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("目标：第一大关养成；第二大关起线性变难，关底淘汰。", deckX + 28, deckY + 96, 500, "left")
    uiButton("Q  降低", deckX + deckW - 220, deckY + 88, 94, 30, C.cyan, C.white, Game.fonts.tiny)
    uiButton("E  提高", deckX + deckW - 112, deckY + 88, 94, 30, C.cyan, C.white, Game.fonts.tiny)
end

local function drawSettlementCard(title, value, x, y, w, h, accent, detail)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.tiny)
    color(accent or C.cyan)
    love.graphics.printf(title, x + 16, y + 14, w - 32, "left")
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf(value, x + 16, y + 42, w - 32, "left")
    if detail then
        love.graphics.setFont(Game.fonts.tiny)
        color(C.muted)
        love.graphics.printf(detail, x + 16, y + 76, w - 32, "left")
    end
end

local function drawLevelUp()
    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    panel(Game.w / 2 - 660, 110, 1320, 640)

    love.graphics.setFont(Game.fonts.big)
    color(C.gold)
    love.graphics.printf("关卡完成", Game.w / 2 - 620, 142, 1240, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("选择一个成长奖励，然后进入补给商店。数字该归位，别挤成一坨废铁账单。", Game.w / 2 - 620, 188, 1240, "center")

    local wr = Game.waveRewards or {}
    local cardY, cardH = 232, 112
    local cardW, gap = 278, 22
    local sx = Game.w / 2 - (cardW * 4 + gap * 3) / 2
    drawSettlementCard("本关", chapterWaveLabel(wr.wave or Game.wave), sx, cardY, cardW, cardH, C.gold, wr.reason or "波次完成")
    drawSettlementCard("收益", "+" .. tostring(wr.coins or 0) .. " 材料", sx + (cardW + gap), cardY, cardW, cardH, C.cyan, "通关奖励 +" .. tostring(wr.clear or 0))
    drawSettlementCard("击杀", tostring(wr.kills or 0), sx + (cardW + gap) * 2, cardY, cardW, cardH, C.red, "当前危险 " .. tostring(Game.danger or 0))
    drawSettlementCard("小目标", wr.objective and ("+" .. wr.objective) or "未完成", sx + (cardW + gap) * 3, cardY, cardW, cardH, wr.objective and C.gold or C.muted, Game.sideObjective and Game.sideObjective.name or "本关目标")

    local damageRows = {}
    for name, dmg in pairs(Game.runStats.damageByWeapon or {}) do damageRows[#damageRows + 1] = {name = name, damage = dmg} end
    table.sort(damageRows, function(a, b) return a.damage > b.damage end)
    local dmgText = {}
    for i = 1, math.min(4, #damageRows) do dmgText[#dmgText + 1] = damageRows[i].name .. " " .. math.floor(damageRows[i].damage) end
    panel(Game.w / 2 - 570, 364, 1140, 54)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.cyan)
    love.graphics.printf("武器伤害", Game.w / 2 - 548, 376, 120, "left")
    color(C.white)
    love.graphics.printf(#dmgText > 0 and table.concat(dmgText, "   /   ") or "暂无", Game.w / 2 - 420, 376, 950, "left")

    love.graphics.setFont(Game.fonts.normal)
    color(C.gold)
    love.graphics.printf("选择奖励", Game.w / 2 - 560, 446, 1120, "center")
    local w, h, rewardGap = 330, 190, 34
    local rewardX = Game.w / 2 - (w * 3 + rewardGap * 2) / 2
    for i, r in ipairs(Game.levelChoices) do
        local x = rewardX + (i - 1) * (w + rewardGap)
        panel(x, 500, w, h)
        local rc = rarityColor[r.rarity or "rare"] or C.cyan
        color(rc, 0.95)
        love.graphics.rectangle("fill", x, 500, w, 6, 6, 6)
        love.graphics.setFont(Game.fonts.normal)
        color(C.white)
        love.graphics.printf(i .. ". " .. r.name, x + 16, 532, w - 32, "center")
        love.graphics.setFont(Game.fonts.small)
        color(C.cyan)
        love.graphics.printf(r.desc, x + 22, 598, w - 44, "center")
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

local function tagPill(text, x, y, bg, fg, maxW)
    local font = Game.fonts.tiny
    local tw = math.max(50, font:getWidth(text) + 24)
    if maxW then tw = math.min(tw, maxW) end
    local th = 24
    color(bg, 0.92)
    love.graphics.rectangle("fill", x, y, tw, th, 8, 8)
    centeredText(text, x, y, tw, th, font, fg or C.bgA, "center")
    return tw
end

local function drawTagRow(tags, x, y, maxW)
    local cursor = x
    for _, tag in ipairs(tags) do
        local remain = maxW - (cursor - x)
        if remain < 48 then break end
        cursor = cursor + tagPill(tag.text, cursor, y, tag.color or C.white, tag.fg or C.bgA, remain) + 6
    end
    return cursor - x
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
        {text = "品牌：" .. (brand and brand.name or "武器") .. " · " .. (brand and brand.tag or "影响武器基础风格。"), color = brand and brand.color or C.white},
        {text = "元素：" .. elem.name .. " · " .. elem.desc, color = elem.color},
        attr("单发伤害", v.damage, "damage", true, nil, 6),
        attr("弹体数量", v.count, "count", true),
        attr("总伤害", v.totalDamage, "totalDamage", true),
        attr("射程", v.range, "range", true),
        attr("弹速", v.speed, "speed", true),
        attr("穿透", v.pierce, "pierce", true),
        attr("弹射", v.bounce, "bounce", true)
    }
    if weapon.legendaryDesc then lines[#lines + 1] = {text = "传说机制：" .. weapon.legendaryDesc, color = C.gold, gap = 6} end
    if weapon.parts and #weapon.parts > 0 then
        local partNames = {}
        for _, part in ipairs(weapon.parts) do partNames[#partNames + 1] = part.name end
        lines[#lines + 1] = {text = "随机部件：" .. table.concat(partNames, " / "), color = C.cyan, gap = 6}
    end
    if weapon.affixTags and #weapon.affixTags > 0 then lines[#lines + 1] = {text = "随机词缀：" .. table.concat(weapon.affixTags, " / "), color = C.gold, gap = 6} end
    if compareWeapon then lines[#lines + 1] = {text = "对比对象：当前装备的「" .. (compareWeapon.name or "武器") .. "」", color = C.gold, gap = 6} end
    if weapon.splash then lines[#lines + 1] = {text = "特殊：爆炸半径 " .. weapon.splash, color = C.gold, gap = 6} end
    if weapon.chain then lines[#lines + 1] = {text = "特殊：连锁 " .. (weapon.chain + (p.gear.echoOverdrive and 1 or 0)) .. " 次", color = C.gold, gap = 6} end
    if weapon.aura then lines[#lines + 1] = {text = "特殊：牵引光环 " .. weapon.aura, color = C.gold, gap = 6} end
    if weapon.sixthPierce then lines[#lines + 1] = {text = "性格：每第 6 发 +1 穿透", color = C.gold, gap = 6} end
    if weapon.sparkSplit then lines[#lines + 1] = {text = "性格：击杀分裂火花", color = C.gold, gap = 6} end
    if weapon.echoRamp then lines[#lines + 1] = {text = "性格：弹射后伤害递增", color = C.gold, gap = 6} end
    if weapon.voidSlow or weapon.heavy or weapon.overloadTax then lines[#lines + 1] = {text = "性格：高收益代价，开火短暂拖慢机体", color = C.gold, gap = 6} end
    if weapon.killHaste then lines[#lines + 1] = {text = "性格：击杀后短暂提高射击节奏", color = C.gold, gap = 6} end
    if weapon.executeLowHp then lines[#lines + 1] = {text = "性格：低血处刑增伤", color = C.gold, gap = 6} end
    if weapon.hiveSplit then lines[#lines + 1] = {text = "性格：击杀后虫群分裂", color = C.gold, gap = 6} end
    if weapon.arcMark then lines[#lines + 1] = {text = "性格：连锁叠电痕爆电", color = C.gold, gap = 6} end
    if weapon.voidCollapse then lines[#lines + 1] = {text = "性格：虚空光环周期坍缩", color = C.gold, gap = 6} end
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
        bounce = (weapon.bounce or 0) + (p.gear.echoOverdrive and 1 or 0),
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
        line("射程", a.range, b.range, b.range - a.range, true),
        line("弹速", a.speed, b.speed, b.speed - a.speed, true),
        line("穿透", a.pierce, b.pierce, b.pierce - a.pierce, true),
        line("弹射", a.bounce, b.bounce, b.bounce - a.bounce, true),
        line("数量", a.count, b.count, b.count - a.count, true)
    }
end

local function waveThreatProfile(wave)
    local plan = wavePlanAt(wave or Game.wave)
    local profile = {shield = 0, armor = 0, ranged = 0, fire = 0, charge = 0, elite = 0, boss = plan.boss and 1 or 0}
    for _, entry in ipairs(plan.enemies or {}) do
        local def = enemyDefs[entry[1]]
        local weight = entry[2] or 0
        if def then
            if def.defense == "shield" then profile.shield = profile.shield + weight end
            if def.defense == "armor" then profile.armor = profile.armor + weight end
            if def.behavior == "shooter" then profile.ranged = profile.ranged + weight end
            if def.behavior == "bomber" then profile.fire = profile.fire + weight end
            if def.behavior == "rammer" then profile.charge = profile.charge + weight end
            if def.elite then profile.elite = profile.elite + weight end
            if def.boss then profile.boss = profile.boss + weight end
        end
    end
    return profile
end

local function itemRecommendationReason(item)
    if not item then return nil end
    local profile = waveThreatProfile(Game.wave)
    local desc = item.desc or ""
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        if profile.shield >= 20 and def.element == "arc" then return "下一波护盾目标偏多，电弧武器更有效。" end
        if profile.armor >= 18 and def.element == "corrode" then return "下一波装甲目标偏多，腐蚀武器更有效。" end
        if profile.fire >= 3 and (def.range or 0) >= 760 then return "下一波有区域封锁，远射程更安全。" end
        if profile.boss > 0 and (def.damage or 0) * (def.count or 1) >= 20 then return "Boss/精英压力高，需要更强单轮输出。" end
    end
    if profile.shield >= 20 and (desc:find("护盾") or desc:find("电弧")) then return "下一波护盾敌人多，优先补电弧/护盾能力。" end
    if profile.armor >= 18 and desc:find("腐蚀") then return "下一波装甲敌人多，腐蚀武器更有效。" end
    if profile.fire >= 3 and (item.kind == "temp" or desc:find("移速") or desc:find("护盾")) then return "下一波有燃烧投手，临时生存/机动补强更稳。" end
    if profile.boss > 0 and (desc:find("伤害") or desc:find("暴击") or desc:find("射速")) then return "Boss 波需要更高持续输出。" end
    if desc:find("电弧") or desc:find("弹射") then return "可推进电弧/弹射组合效果。" end
    if desc:find("暴击") then return "可推进暴击流组合效果。" end
    return nil
end

waveThreatSummary = function(wave)
    local profile = waveThreatProfile(wave)
    local parts = {}
    if profile.boss > 0 then parts[#parts + 1] = "Boss" end
    if profile.elite > 0 then parts[#parts + 1] = "精英" end
    if profile.fire >= 3 then parts[#parts + 1] = "燃烧区" end
    if profile.charge >= 6 then parts[#parts + 1] = "冲锋威胁" end
    if profile.ranged >= 18 then parts[#parts + 1] = "远程压制" end
    if profile.shield >= 20 then parts[#parts + 1] = "护盾敌群" end
    if profile.armor >= 18 then parts[#parts + 1] = "装甲敌群" end
    return #parts > 0 and table.concat(parts, " / ") or "常规混合敌群"
end

local function itemTooltip(item)
    if not item then return nil end
    local kindText = kindLabel[item.kind] or item.kind or "模块"
    local kindDesc = ({
        weapon = "购买后装备为新武器；槽满时需先卖掉旧武器。",
        shield = "安装到护盾槽，替换当前护盾组件。",
        temp = "只影响下一波战斗。",
        item = "进入模块槽，本局永久生效。",
        mod = "改变核心战斗属性或武器表现。",
        relic = "偏构筑联动的永久效果。",
        legend = "带特殊协议的永久构筑件。"
    })[item.kind] or "决定购买后的生效位置。"
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local selected = Game.player.weapons[Game.selectedWeaponIndex or 1]
        local tip = weaponTooltip(def, "商品武器", selected)
        table.insert(tip.lines, 1, "价格：◆ " .. item.price .. " · " .. itemLevelText(item))
        table.insert(tip.lines, 2, {text = "类型：" .. kindText .. " · " .. kindDesc, color = C.muted})
        local rec = itemRecommendationReason(item)
        if rec then tip.lines[#tip.lines + 1] = {text = "推荐：" .. rec, color = C.gold, gap = 8} end
        if not selected then
            tip.lines[#tip.lines + 1] = {text = "提示：先点击右侧武器槽，选择要对比的武器。", color = C.muted, gap = 8}
        end
        return tip
    end
    local lines = {
        "价格：◆ " .. (item.price or 0) .. " · " .. itemLevelText(item),
        {text = "类型：" .. kindText .. " · " .. kindDesc, color = C.muted},
        {text = "效果：" .. modText(item.desc or "无说明"), color = C.white, gap = 6}
    }
    if item.flag then lines[#lines + 1] = "特殊协议：" .. item.flag end
    local rec = itemRecommendationReason(item)
    if rec then lines[#lines + 1] = {text = "推荐：" .. rec, color = C.gold, gap = 8} end
    return {title = "商品：" .. (item.name or "未知模块"), lines = lines}
end

local function drawShopCard(item, i, x, y, w, h)
    local mx, my = mousePosition()
    local hover = Game.state == "shop" and (Game.shopTab or "shop") == "shop" and hitRect(mx, my, x, y, w, h)
    if not item then
        drawMetalCard(x, y, w, h, C.white, false, false, false)
        love.graphics.setFont(Game.fonts.tiny)
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
        if hover then
            return {title = "商品已售罄", lines = {"这个位置已被购买。", "刷新商店后会重新补货。"}, anchor = {x = x, y = y, w = w, h = h}, width = 360}
        end
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
    local cardTags
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local brand = brands[def.brand]
        local elem = elements[def.element]
        cardTags = {
            {text = rarityText, color = rc},
            {text = kindText, color = accent},
            {text = brand and brand.name or "武器", color = brand and brand.color or C.white},
            {text = elem and elem.name or "动能", color = elem and elem.color or C.white}
        }
    else
        cardTags = {{text = kindText, color = accent}}
    end
    if item.kind ~= "weapon" then cardTags[#cardTags + 1] = {text = itemLevelText(item), color = C.gold} end
    if itemRecommendationReason(item) then cardTags[#cardTags + 1] = {text = "推荐", color = C.gold} end
    love.graphics.setFont(Game.fonts.tiny)
    drawTagRow(cardTags, x + 18, y + 13, w - 82)
    local topLockX, topLockY, topLockW, topLockH = x + w - 58, y + 10, 40, 30
    color(C.white, Game.locked[i] and 0.18 or 0.07)
    love.graphics.rectangle("fill", topLockX, topLockY, topLockW, topLockH, 9, 9)
    color(Game.locked[i] and C.white or C.muted, Game.locked[i] and 0.86 or 0.48)
    love.graphics.rectangle("line", topLockX + 0.5, topLockY + 0.5, topLockW - 1, topLockH - 1, 9, 9)
    if Game.locked[i] then
        textInBox("锁", topLockX, topLockY, topLockW, topLockH, Game.fonts.tiny, C.white, "center")
    else
        love.graphics.rectangle("line", topLockX + 13, topLockY + 13, 14, 11, 3, 3)
        love.graphics.arc("line", topLockX + 20, topLockY + 13, 6, math.pi, TAU)
    end

    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(compactDesc(item.name, 16), x + 18, y + 56, w - 36, "left")
    if item.kind ~= "weapon" then
        color(C.gold, 0.90)
        love.graphics.printf(itemLevelText(item), x + 18, y + 56, w - 36, "right")
    end
    love.graphics.setFont(Game.fonts.tiny)
    local desc = compactDesc(item.desc, 30)
    color(C.muted)
    love.graphics.printf(desc, x + 18, y + 88, w - 36, "left")

    local buyY = y + h - 36
    local displayY, displayH = y + 120, math.max(42, buyY - y - 130)
    color(C.white, 0.045)
    love.graphics.rectangle("fill", x + 18, displayY, w - 36, displayH, 12, 12)
    color(C.white, 0.18)
    love.graphics.rectangle("line", x + 18.5, displayY + 0.5, w - 37, displayH - 1, 12, 12)

    love.graphics.setFont(Game.fonts.tiny)
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local rows = {
            {"伤害", tostring(def.damage)},
            {"弹体", tostring(def.count or 1)},
            {"总伤", tostring((def.damage or 0) * (def.count or 1))},
            {"射程", tostring(math.floor(def.range or 0))},
            {"弹速", tostring(math.floor(def.speed or 0))},
            {"弹射", tostring(def.bounce or 0)}
        }
        for ri, row in ipairs(rows) do
            local ry = displayY + 10 + (ri - 1) * 18
            if ry + 16 < displayY + displayH then
                textInBox(row[1] .. "  " .. row[2], x + 34, ry, w - 68, 16, Game.fonts.tiny, ri == 1 and C.white or C.muted, "left")
            end
        end
    else
        local effectMode = item.kind == "temp" and "下一波生效" or "永久生效"
        textInBox(effectMode .. " · " .. kindText, x + 34, displayY + 10, w - 68, 18, Game.fonts.tiny, C.white, "left")
        love.graphics.setFont(Game.fonts.tiny)
        local descText = modText(item.desc or "无说明")
        local effectColor = descText:find("%-") and C.red or (descText:find("%+") and C.green or C.muted)
        color(effectColor)
        love.graphics.printf(descText, x + 34, displayY + 36, w - 68, "left")
    end
    local buyColor = affordable and C.gold or C.muted
    color(buyColor, hover and 0.28 or 0.12)
    love.graphics.rectangle("fill", x + 18, buyY - 4, w - 36, 34, 10, 10)
    color(buyColor, hover and 0.78 or 0.42)
    love.graphics.setLineWidth(hover and 2 or 1)
    love.graphics.rectangle("line", x + 18, buyY - 4, w - 36, 34, 10, 10)
    love.graphics.setLineWidth(1)
    local buyText = affordable and ("购买  " .. i .. "  · ◆ " .. item.price) or ("材料不足 · ◆ " .. item.price)
    centeredText(buyText, x + 18, buyY - 4, w - 36, 34, Game.fonts.tiny, buyColor, "center")

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
        if tip then tip.anchor = {x = x, y = y, w = w, h = h}; tip.width = 430 end
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
        {"暴伤", pct(p.stats.critDamage)}, {"射程", pct(p.stats.range)}, {"弹速", pct(p.stats.projectileSpeed)},
        {"元素", pct(p.stats.elementDamage or 1)}, {"吸血", pct(p.stats.lifesteal)}
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
        names[#names + 1] = weapon.name
        if i >= 4 then break end
    end
    love.graphics.printf(table.concat(names, " / "), x + 16, wy + 22, w - 32, "center")
end

local sellWeapon, sellShield, sellItem

local function drawCompactBuildPanel(x, y, w, h, opts)
    local p = Game.player
    opts = opts or {}
    local showSell = opts.showSell ~= false
    love.graphics.setColor(0, 0, 0, 0.86)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    color(C.white, 0.045)
    love.graphics.rectangle("fill", x + 6, y + 6, w - 12, h - 12, 16, 16)
    color(C.white, 0.18)
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
    local tabs = {{id = "stats", label = "基础属性"}, {id = "items", label = "模块槽"}}
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
        love.graphics.printf("模块槽 " .. #items .. "/" .. (p.itemSlots or ITEM_SLOT_BASE), x + 14, itemY - 28, w - 28, "left")
        color(C.muted)
        love.graphics.printf("3 个同名自动融合；商店可升级容量。", x + 118, itemY - 28, w - 132, "right")
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
            local lvW = 46
            textInBox(compactDesc(item.name, showSell and 7 or 10), sx + 10, sy, slotW - (showSell and 92 or 58), 30, Game.fonts.tiny, C.white, "left")
            color(C.gold, 0.13)
            love.graphics.rectangle("fill", sx + slotW - (showSell and 88 or 52), sy + 5, lvW, 20, 7, 7)
            color(C.gold, 0.58)
            love.graphics.rectangle("line", sx + slotW - (showSell and 88 or 52), sy + 5, lvW, 20, 7, 7)
            textInBox(itemLevelText(item), sx + slotW - (showSell and 88 or 52), sy + 5, lvW, 20, Game.fonts.tiny, C.gold, "center")
            if showSell then
                color(C.red, 0.14)
                love.graphics.rectangle("fill", sx + slotW - 40, sy + 5, 30, 20, 7, 7)
                color(C.red, 0.58)
                love.graphics.rectangle("line", sx + slotW - 40, sy + 5, 30, 20, 7, 7)
                textInBox("卖", sx + slotW - 40, sy + 5, 30, 20, Game.fonts.tiny, C.red, "center")
            end
            if hitRect(mx, my, sx, sy, slotW, 30) then
                local tip = itemTooltip(item)
                tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击右侧“卖”出售模块。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
                return tip
            end
        end
        if #items == 0 then
            color(C.white, 0.05)
            love.graphics.rectangle("fill", x + 14, itemY, w - 28, 34, 8, 8)
            color(C.muted)
            textInBox("暂无模块 · 容量 " .. (p.itemSlots or ITEM_SLOT_BASE), x + 26, itemY, w - 52, 34, Game.fonts.tiny, C.muted, "left")
        end
        return nil
    end

    local stats = {
        {"伤害", pct(p.stats.damage)}, {"射速", pct(p.stats.fireRate)},
        {"暴击", pct(p.stats.crit)}, {"暴伤", pct(p.stats.critDamage)},
        {"射程", pct(p.stats.range)}, {"弹速", pct(p.stats.projectileSpeed)},
        {"元素", pct(p.stats.elementDamage or 1)}, {"吸血", pct(p.stats.lifesteal)},
    }
    local statGap = 18
    local statW = (w - 28 - statGap) / 2
    for i, row in ipairs(stats) do
        local sx = x + 14 + ((i - 1) % 2) * (statW + statGap)
        local sy = y + 130 + math.floor((i - 1) / 2) * 22
        color(C.white, 0.06)
        love.graphics.rectangle("fill", sx, sy, statW, 18, 6, 6)
        textInBox(row[1] .. "  " .. row[2], sx + 8, sy, statW - 16, 18, Game.fonts.tiny, C.white, "center")
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
        local weaponText = weapon and compactDesc(weapon.name, showSell and 9 or 12) or "空武器"
        local priceW = weapon and 52 or 0
        local nameW = slotW - (showSell and 106 or 26) - priceW
        textInBox(weaponText, sx + 10, sy, nameW, 34, Game.fonts.tiny, weapon and C.white or C.muted, weapon and "left" or "center")
        if weapon then
            local priceX = sx + slotW - (showSell and 100 or 62)
            color(C.gold, 0.13)
            love.graphics.rectangle("fill", priceX, sy + 6, 52, 22, 7, 7)
            color(C.gold, 0.58)
            love.graphics.rectangle("line", priceX, sy + 6, 52, 22, 7, 7)
            textInBox("◆" .. tostring(weapon.price or 0), priceX, sy + 6, 52, 22, Game.fonts.tiny, C.gold, "center")
        end
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
    textInBox(shield and compactDesc(shield.name, showSell and 13 or 18) or "空护盾槽", x + 26, shieldY, w - (showSell and 178 or 146), 42, Game.fonts.tiny, shield and C.white or C.muted, shield and "left" or "center")
    if shield then
        local priceX = x + w - (showSell and 124 or 96)
        color(C.gold, 0.13)
        love.graphics.rectangle("fill", priceX, shieldY + 9, 56, 24, 7, 7)
        color(C.gold, 0.58)
        love.graphics.rectangle("line", priceX, shieldY + 9, 56, 24, 7, 7)
        textInBox("◆" .. tostring(shield.price or 0), priceX, shieldY + 9, 56, 24, Game.fonts.tiny, C.gold, "center")
    end
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
    local reward, penalty, protocol = affixesAt(Game.wave)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("下一波情报", x + 24, y + 18, w - 48, "left")
    color(C.gold)
    love.graphics.printf(chapterWaveLabel(Game.wave) .. " · " .. (plan.name or "生存波次"), x + 24, y + 54, w - 48, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("10 大关 30 小关 · 每 3 小关击败 Boss · 主要威胁：" .. waveThreatSummary(Game.wave), x + 24, y + 84, w - 48, "left")

    if penalty and not reward and not protocol then
        tip = drawAffixInfoPill(penalty, "大关词缀", x + 24, y + 122, w - 48, 66, mx, my) or tip
    else
        local pillW = (w - 62) / 2
        if protocol then tip = drawAffixInfoPill(protocol, "协议", x + 24, y + 122, pillW, 58, mx, my) or tip end
        if reward then tip = drawAffixInfoPill(reward, "奖励", x + 38 + pillW, y + 122, pillW, 58, mx, my) or tip end
        if penalty then tip = drawAffixInfoPill(penalty, "惩罚", x + 24, y + 188, w - 48, 52, mx, my) or tip end
    end

    love.graphics.setFont(Game.fonts.tiny)
    color(C.white)
    love.graphics.printf("敌人构成", x + 24, y + 258, w - 48, "left")
    local rowY = y + 286
    local total = 0
    for _, entry in ipairs(plan.enemies or {}) do total = total + (entry[2] or 0) end
    for i, entry in ipairs(plan.enemies or {}) do
        local key, weight = entry[1], entry[2]
        local def = enemyDefs[key]
        if def and i <= 6 then
            local chance = total > 0 and math.floor(weight / total * 100 + 0.5) or weight
            color(def.color, 0.16)
            love.graphics.rectangle("fill", x + 24, rowY, w - 48, 22, 7, 7)
            color(def.color)
            love.graphics.printf(def.name, x + 36, rowY + 5, 112, "left")
            color(C.muted)
            love.graphics.printf(chance .. "% · " .. defenseText(def) .. " · " .. (def.behavior or "追击") .. " · 伤害 " .. def.damage, x + 156, rowY + 5, w - 196, "left")
            rowY = rowY + 26
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
    local status = unlocked and ("第 " .. milestone .. " 关战后补给 · " .. (free and "本轮免费" or ("消耗 " .. slotSpinCost() .. " 材料"))) or "每关战后解锁"
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
    love.graphics.printf(Game.slotResult and Game.slotResult.text or "三符奖励 / 双符奖励 / 黑箱事件 / 基础补给", x + 142, y + 34, w - 246, "left")

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
    local status = unlocked and ("第 " .. milestone .. " 关战后补给 · " .. (free and "本轮免费 1 次" or ("本次消耗 " .. slotSpinCost() .. " 材料"))) or "每过 1 关补 1 次免费启动；用完后可花材料继续转"
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
    love.graphics.printf(Game.slotResult and Game.slotResult.text or "三符奖励，双符奖励，黑箱事件，基础补给返材料。奖励会直接给材料/治疗，或以 0 材料商品放入商店。", x + 28, y + 248, w - 56, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("符号：材料、武器、战术、护盾、修复、黑箱、稀有。补给转轮只影响商店阶段，不会替你自动进入下一波。", x + 28, y + 292, w - 56, "center")

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
        {"护盾回复", string.format("%.1f/s", p.shieldRegen)},
        {"移速", tostring(math.floor(p.speed))},
        {"暴击", pct(p.stats.crit)}, {"暴伤", pct(p.stats.critDamage)},
        {"元素伤", pct(p.stats.elementDamage or 1)}, {"吸血", pct(p.stats.lifesteal)}
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
        love.graphics.printf(weapon.name, wx + 14, wy + 10, cardW - 28, "left")
        love.graphics.setFont(Game.fonts.tiny)
        color(brand and brand.color or C.gold)
        love.graphics.printf((brand and brand.name or "武器") .. " · " .. elem.name, wx + 14, wy + 36, cardW - 28, "left")
        color(C.muted)
        local actualDamage = math.floor((weapon.damage or 0) * (p.stats.damage or 1) + 0.5)
        local detail = "伤害 " .. actualDamage .. "×" .. (weapon.count or 1) .. "  冷却 " .. string.format("%.2f", weapon.cooldown or 0) .. "s  范围 " .. math.floor(weapon.range or 0)
        local extra = "穿透 " .. (weapon.pierce or 0) .. "  弹射 " .. (weapon.bounce or 0) .. "  弹速 " .. math.floor(weapon.speed or 0)
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
    local actionY, actionH = 42, 42
    local refreshW, nextW, sellW, actionGap = 168, 230, 178, 10
    local actionX = Game.w - marginX - refreshW - nextW - sellW - actionGap * 2
    drawShopTabs(marginX, tabY)

    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    local infoX, infoW = 590, actionX - 610
    love.graphics.printf("商店 / " .. chapterWaveLabel(clearedWave) .. " 战后补给", infoX, 38, infoW, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    local shieldText = Game.player.shieldItem and "护盾槽 1/1" or "护盾槽 0/1"
    local incomeText = Game.lastWaveIncome and ("上波收入 +" .. Game.lastWaveIncome .. " · ") or ""
    love.graphics.printf(incomeText .. shopBudgetHint() .. " · 武器槽 " .. #Game.player.weapons .. "/4 · " .. shieldText .. " · 模块槽 " .. #(Game.player.items or {}) .. "/" .. (Game.player.itemSlots or ITEM_SLOT_BASE), infoX, 74, infoW, "center")

    local rerollCost = 3 + Game.shopRefresh * 2
    local refreshText = Game.freeRefresh > 0 and ("免费刷新 " .. Game.freeRefresh .. " 次") or ("刷新 " .. rerollCost .. " 材料")
    local slotCost = itemSlotUpgradeCost()
    local upgradeText = slotCost and ("模块槽 +1 · ◆" .. slotCost) or "模块槽满级"
    uiButton(refreshText, actionX, actionY + 4, refreshW, actionH - 8, C.cyan)
    uiButton("进入下一波", actionX + refreshW + actionGap, actionY, nextW, actionH, C.gold, C.white, Game.fonts.small)
    uiButton(upgradeText, actionX + refreshW + actionGap + nextW + actionGap, actionY + 4, sellW, actionH - 8, slotCost and C.green or C.muted)

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
        local shelfTitleH = 34
        local rowGap = 54
        local bottomPad = 0
        local cardH = math.floor((contentH - shelfTitleH * 2 - rowGap - bottomPad) / 2)
        local weaponY = contentY + shelfTitleH
        local supportY = contentY + contentH - bottomPad - cardH
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf("武器架 · 3 选 1", marginX, weaponY - 34, shelfW, "left")
        color(C.white, 0.08)
        love.graphics.rectangle("fill", marginX, weaponY - 8, shelfW, 10, 5, 5)
        color(C.white, 0.16)
        love.graphics.rectangle("fill", marginX, weaponY + cardH + 10, shelfW, 8, 4, 4)
        color(C.white)
        love.graphics.printf("装备箱 · 模块 / 护盾 / 战术", marginX, supportY - 34, shelfW, "left")
        color(C.white, 0.07)
        love.graphics.rectangle("fill", marginX, supportY - 8, shelfW, 10, 5, 5)
        color(C.white, 0.14)
        love.graphics.rectangle("fill", marginX, supportY + cardH - 8, shelfW, 8, 4, 4)
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
    love.graphics.printf(chapterWaveLabel(Game.wave) .. "   击杀 " .. Game.kills .. "   材料 " .. Game.coins, Game.w / 2 - 300, 355, 600, "center")
    color(C.cyan)
    love.graphics.printf("总伤害 " .. math.floor(Game.runStats.damage or 0) .. "   收入 " .. math.floor(Game.runStats.coinsEarned or 0) .. "   危险 " .. Game.danger, Game.w / 2 - 300, 388, 600, "center")
    color(C.muted)
    love.graphics.printf("回车回到选择界面 / Esc 退出", Game.w / 2 - 300, 425, 600, "center")
end

local function drawClearTransitionOverlay()
    if Game.state ~= "clearing" then return end
    local t = Game.clearTransition or {timer = 0}
    local alpha = clamp(0.22 + math.sin((t.timer or 0) * 18) * 0.08, 0.12, 0.34)
    love.graphics.setBlendMode("add")
    color(C.cyan, alpha)
    love.graphics.rectangle("fill", 0, 138, Game.w, Game.h - 204)
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(Game.fonts.big)
    color(C.white, 0.92)
    love.graphics.printf("目标达成 · 敌群毁灭", 0, 168, Game.w, "center")
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
    drawCombatWarningOverlay()
    drawClearTransitionOverlay()
    if Game.state == "clearing" then drawVersion(); love.graphics.pop(); return end
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

function buySlot(i)
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
    local value = math.max(8, sellValue(w, 20))
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
    if not item then toast("该模块槽为空") return false end
    table.remove(p.items, index)
    local value = sellValue(item, 14)
    Game.coins = Game.coins + value
    rebuildPlayerBuildStats()
    playCue("shop"); toast("卖出模块 " .. item.name .. "：+" .. value .. " 材料")
    return true
end

function recycleWeapon()
    return sellWeapon(Game.selectedWeaponIndex or #Game.player.weapons)
end

function refreshShop()
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

function handlePointer(x, y)
    if Game.state == "menu" then
        local deckX, deckY, deckW = 90, Game.h - 168, Game.w - 180
        if hitRect(x, y, deckX + deckW - 220, deckY + 88, 94, 30) then Game.danger = math.max(0, Game.danger - 1); return true end
        if hitRect(x, y, deckX + deckW - 112, deckY + 88, 94, 30) then Game.danger = math.min(6, Game.danger + 1); return true end
        if hitRect(x, y, Game.w / 2 - 140, deckY + 30, 280, 62) then resetRun(); return true end
    elseif Game.state == "levelup" then
        local w, h, gap = 330, 190, 34
        local sx = Game.w / 2 - (w * 3 + gap * 2) / 2
        for i = 1, 3 do
            local cx = sx + (i - 1) * (w + gap)
            if hitRect(x, y, cx, 500, w, h) then chooseLevelReward(i); return true end
        end
    elseif Game.state == "shop" then
        local marginX = 40
        local actionY, actionH = 42, 42
        local refreshW, nextW, sellW, actionGap = 168, 230, 178, 10
        local actionX = Game.w - marginX - refreshW - nextW - sellW - actionGap * 2
        if hitRect(x, y, actionX, actionY + 4, refreshW, actionH - 8) then refreshShop(); return true end
        if hitRect(x, y, actionX + refreshW + actionGap, actionY, nextW, actionH) then startWave(); return true end
        if hitRect(x, y, actionX + refreshW + actionGap + nextW + actionGap, actionY + 4, sellW, actionH - 8) then upgradeItemSlots(); return true end

        local tab = shopTabHit(x, y)
        if tab then Game.shopTab = tab; return true end

        if (Game.shopTab or "shop") == "shop" then
            local gap = 28
            local sideW = 430
            local sideGap = 32
            local sideX = Game.w - marginX - sideW
            local shelfW = sideX - marginX - sideGap
            local cardW = (shelfW - gap * 2) / 3
            local contentY, contentH = 154, Game.h - 200
            local shelfTitleH, rowGap, bottomPad = 34, 54, 0
            local cardH = math.floor((contentH - shelfTitleH * 2 - rowGap - bottomPad) / 2)
            local weaponY = contentY + shelfTitleH
            local supportY = contentY + contentH - bottomPad - cardH
            if handleBuildPanelClick(x, y, sideX, contentY, sideW, contentH) then return true end
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
        if key == "u" then upgradeItemSlots() end
        if key == "s" then spinSlotMachine(); return end
        if key == "r" then
            if not (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then toast("刷新需按 Shift+R，避免误触"); return end
            refreshShop()
        end
    end
end
