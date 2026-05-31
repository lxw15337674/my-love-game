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
    local cfg = {moduleStats = {}, moduleBlueprints = {}, moduleCombos = {}, affixDefs = {}, waveAffixes = {}, weaponDefs = {}, enemyDefs = {}, slotSymbols = {}, wavePlans = {}}
    local text = cfgReadText("balance.cfg") or ""
    for raw in text:gmatch("[^\r\n]+") do
        local line = raw:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
            if key and value then
                if key == "chapter_names" then
                    cfg.chapterNames = cfgSplit(value, ",")
                elseif key == "weapon" then
                    local parts = cfgSplit(value, "|")
                    local extra = {}
                    for _, pair in ipairs(cfgSplit(parts[12] or "", ",")) do
                        local k, v = pair:match("^([%w_]+)%s*=%s*([%d%.%-]+)$")
                        if k then extra[k] = tonumber(v) or 0 end
                    end
                    cfg.weaponDefs[parts[1]] = {id = parts[1], name = parts[2], brand = parts[3], element = parts[4], price = tonumber(parts[5]), damage = tonumber(parts[6]), cooldown = tonumber(parts[7]), speed = tonumber(parts[8]), count = tonumber(parts[9]), spread = tonumber(parts[10]), range = tonumber(parts[11]), extra = extra}
                elseif key == "enemy" then
                    local parts = cfgSplit(value, "|")
                    local flags = {}
                    for _, flag in ipairs(cfgSplit(parts[16] or "", ",")) do
                        local fk, fv = flag:match("^([%w_]+)%s*=%s*([%d%.%-]+)$")
                        if fk then flags[fk] = tonumber(fv) or fv elseif flag ~= "" then flags[flag] = true end
                    end
                    cfg.enemyDefs[parts[1]] = {id = parts[1], name = parts[2], sprite = parts[3], defense = parts[4], hp = tonumber(parts[5]), shield = tonumber(parts[6]), shieldRegen = tonumber(parts[7]), speed = tonumber(parts[8]), damage = tonumber(parts[9]), r = tonumber(parts[10]), color = parts[11], armor = tonumber(parts[12]), xp = tonumber(parts[13]), coin = tonumber(parts[14]), behavior = parts[15], flags = flags}
                elseif key == "slot_symbol" then
                    local parts = cfgSplit(value, "|")
                    cfg.slotSymbols[#cfg.slotSymbols + 1] = {id = parts[1], name = parts[2], mark = parts[3], color = parts[4], weight = tonumber(parts[5]) or 1}
                elseif key == "wave_plan" then
                    local parts = cfgSplit(value, "|")
                    local sides, enemies, events = {}, {}, {}
                    for _, side in ipairs(cfgSplit(parts[5] or "", ",")) do if side ~= "" then sides[#sides + 1] = side end end
                    for _, pair in ipairs(cfgSplit(parts[6] or "", ",")) do
                        local id, wt = pair:match("^([%w_]+)%s*:%s*([%d%.%-]+)$")
                        if id then enemies[#enemies + 1] = {id, tonumber(wt) or 1} end
                    end
                    for _, ev in ipairs(cfgSplit(parts[7] or "", ";")) do
                        local t, enemy, side, toast = ev:match("^([%d%.]+)%s*,%s*([%w_]+)%s*,%s*([%w_]+)%s*,?(.*)$")
                        if t and enemy then events[#events + 1] = {time = tonumber(t) or 0, enemy = enemy, side = side ~= "" and side or nil, toast = toast ~= "" and toast or nil} end
                    end
                    cfg.wavePlans[#cfg.wavePlans + 1] = {name = parts[2], interval = tonumber(parts[3]) or 1, pack = tonumber(parts[4]) or 1, sides = sides, enemies = enemies, events = events, boss = parts[8] == "boss"}
                elseif key == "module_stat" then
                    local parts = cfgSplit(value, "|")
                    cfg.moduleStats[parts[1]] = {id = parts[1], label = parts[2], min = tonumber(parts[3]) or 0, max = tonumber(parts[4]) or 0, format = parts[5] or "percent"}
                elseif key == "module" then
                    local parts = cfgSplit(value, "|")
                    cfg.moduleBlueprints[#cfg.moduleBlueprints + 1] = {key = parts[1], name = parts[2], kind = parts[3], stats = cfgSplit(parts[4] or "", ",")}
                elseif key == "module_combo" then
                    local parts = cfgSplit(value, "|")
                    local combo = {id = parts[1], name = parts[2], requires = cfgSplit(parts[3] or "", ","), bonuses = {}}
                    for _, pair in ipairs(cfgSplit(parts[4] or "", ",")) do
                        local k, v = pair:match("^([%w_]+)%s*=%s*([%d%.%-]+)$")
                        if k then combo.bonuses[k] = tonumber(v) or 0 end
                    end
                    cfg.moduleCombos[#cfg.moduleCombos + 1] = combo
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

local VERSION = "v2026.05.31.88"
local VIRTUAL_W, VIRTUAL_H = 1920, 1080
local ACTIVE_SKILL_CD = 3.0
local ACTIVE_SKILL_DURATION = 0.5
local ACTIVE_SKILL_SPEED_MULT = 2.1
local CHAPTER_SIZE = Balance.chapter_size or 3
local CHAPTER_NAMES = Balance.chapterNames or {"铁幕", "赤炉", "断链", "黑箱", "天灾", "归零", "深井", "白噪", "终焉", "重启"}
local SMALL_WAVE_DURATION = Balance.small_wave_duration or 30
local SMALL_WAVE_DURATION_MIN = Balance.small_wave_duration_min or 25
local SMALL_WAVE_DURATION_MAX = Balance.small_wave_duration_max or 70
local SMALL_WAVE_DURATION_STEP = Balance.small_wave_duration_step or 5
local CAMPAIGN_WAVES = CHAPTER_SIZE * #CHAPTER_NAMES
local AVERAGE_RUN_TARGET_WAVE = Balance.average_run_target_wave or 30
ITEM_SLOT_BASE = Balance.item_slot_base or 6
ITEM_SLOT_MAX = Balance.item_slot_max or 12
WEAPON_SLOT_MAX = 4

local Game = {
    w = VIRTUAL_W,
    h = VIRTUAL_H,
    state = "menu", -- menu, playing, event_choice, route_choice, clearing, paused, levelup, shop, gameover, victory
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
    hitFlash = 0,
    lastHitSource = nil,
    lastHitAngle = nil,
    lastHitColor = nil,
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
    routeChoices = {},
    eventChoices = {},
    eventChoiceMode = nil,
    preBattleEventArmed = false,
    preBattleEventChoice = nil,
    routeMods = {},
    nextRouteMods = nil,
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
        itemSlotLevel = 1,
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
    white = {0.90, 0.92, 0.96},
    muted = {0.68, 0.72, 0.80},
    pink = {0.88, 0.48, 0.60},
    cyan = {0.48, 0.72, 0.80},
    blue = {0.30, 0.56, 1.00},
    shield = {0.30, 0.56, 1.00},
    gold = {0.88, 0.70, 0.42},
    red = {0.90, 0.34, 0.36},
    green = {0.48, 0.72, 0.54},
    purple = {0.62, 0.54, 0.76},
    orange = {0.86, 0.54, 0.36},
    ice = {0.66, 0.78, 0.86}
}

local weaponDefs
local enemyDefs
local bossDefs
local bossPool

function cfgColor(name, fallback)
    return (C and C[name]) or fallback or C.white
end

function applyConfiguredWeapons()
    if not (Balance.weaponDefs and next(Balance.weaponDefs)) then return end
    for id, cfg in pairs(Balance.weaponDefs) do
        local def = weaponDefs[id]
        if def then
            for _, key in ipairs({"name", "brand", "element", "price", "damage", "cooldown", "speed", "count", "spread", "range", "statusChance", "statusDamage"}) do
                if cfg[key] ~= nil then def[key] = cfg[key] end
            end
            if cfg.extra then for k, v in pairs(cfg.extra) do def[k] = v end end
        end
    end
end

function applyConfiguredEnemies()
    if not (Balance.enemyDefs and next(Balance.enemyDefs)) then return end
    for id, cfg in pairs(Balance.enemyDefs) do
        local def = enemyDefs[id]
        if def then
            for _, key in ipairs({"name", "sprite", "defense", "hp", "shield", "shieldRegen", "speed", "damage", "r", "armor", "xp", "coin", "behavior"}) do
                if cfg[key] ~= nil then def[key] = cfg[key] end
            end
            def.color = cfgColor(cfg.color, def.color)
            if cfg.flags then for k, v in pairs(cfg.flags) do def[k] = v end end
        end
    end
end

function configuredSlotSymbols(defaults)
    if not (Balance.slotSymbols and #Balance.slotSymbols > 0) then return defaults end
    local out = {}
    for _, s in ipairs(Balance.slotSymbols) do
        out[#out + 1] = {id = s.id, name = s.name, mark = s.mark, color = cfgColor(s.color, C.white), weight = s.weight or 1}
    end
    return out
end

function configuredWavePlans(defaults)
    if not (Balance.wavePlans and #Balance.wavePlans > 0) then return defaults end
    local out = {}
    for _, plan in ipairs(Balance.wavePlans) do
        out[#out + 1] = {
            name = plan.name,
            interval = plan.interval,
            pack = plan.pack,
            sides = (#plan.sides > 0) and plan.sides or {"left", "right", "top", "bottom"},
            enemies = (#plan.enemies > 0) and plan.enemies or {{"drifter", 1}},
            events = plan.events or {},
            boss = plan.boss
        }
    end
    return out
end

local elements = {
    kinetic = {name = "动能", color = C.white, desc = "直接伤害", status = "无异常", weakness = "通用"},
    burn = {name = "灼烧", color = C.orange, desc = "点燃持续伤害，对轻甲更狠", status = "点燃", weakness = "轻甲"},
    arc = {name = "电击", color = C.cyan, desc = "对护盾增伤，破盾触发电爆", status = "触电", weakness = "护盾"},
    corrode = {name = "腐蚀", color = C.green, desc = "叠层持续伤害，并让目标受到后续伤害提高", status = "衰变", weakness = "厚血敌群"},
    ice = {name = "霜冻", color = C.ice, desc = "减速并累积冻结，冻结目标更易暴击", status = "冻结", weakness = "高速敌"},
    void = {name = "虚空", color = C.purple, desc = "牵引并累积坍缩", status = "坍缩", weakness = "密集敌群"}
}

local brands = {
    starforge = {name = "星铸", color = C.gold, tag = "精准暴击"},
    swarm = {name = "蜂群", color = C.green, tag = "多弹清场"},
    molten = {name = "熔火", color = C.orange, tag = "爆燃轰击"},
    echo = {name = "回声", color = C.cyan, tag = "弹射连锁"},
    caustic = {name = "蚀刻", color = C.green, tag = "腐蚀易伤"},
    cryo = {name = "冷井", color = C.ice, tag = "霜冻控场"},
    drone = {name = "母巢", color = C.green, tag = "无人机军团"},
    blackbox = {name = "黑箱", color = C.purple, tag = "异常代价"}
}

weaponDefs = {
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
    },
    splitter = {
        id = "splitter", projectileSprite = "projectile_star_needle",
        name = "裂星机炮", brand = "starforge", element = "kinetic", price = 30,
        damage = 6, cooldown = 0.42, speed = 680, count = 3, spread = 0.24, range = 720, critBonus = 0.06,
        desc = "多弹精准射击，适合暴击弹幕"
    },
    acid = {
        id = "acid", projectileSprite = "projectile_void_orb",
        name = "腐蚀喷针", brand = "caustic", element = "corrode", price = 34,
        damage = 12, cooldown = 0.72, speed = 520, count = 2, spread = 0.16, range = 660, statusChance = 0.32, statusDamage = 6,
        desc = "腐蚀附着，叠层持续伤害并施加易伤"
    },
    frost = {
        id = "frost", projectileSprite = "projectile_arc_bolt",
        name = "冷井脉冲", brand = "cryo", element = "ice", price = 32,
        damage = 10, cooldown = 0.78, speed = 500, count = 2, spread = 0.12, range = 640, statusChance = 0.34, statusDamage = 4,
        desc = "霜冻减速，累积后冻结"
    },
    drone = {
        id = "drone", projectileSprite = "projectile_swarm_missile",
        name = "蜂巢无人机", brand = "drone", element = "arc", price = 40,
        damage = 5, cooldown = 0.95, speed = 540, count = 4, spread = 0.72, range = 720, statusChance = 0.24, statusDamage = 5, hiveSplit = true,
        desc = "无人机齐射，击杀后分裂追咬"
    }
}

applyConfiguredWeapons()

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
    {name = "过载电容", kind = "legend", rarity = "legend", price = 70, desc = "射速 +18%，移速 +8%，护盾回复 -1", apply = function(p) p.stats.fireRate = p.stats.fireRate + 0.18; p.speed = p.speed + 20; p.shieldRegen = p.shieldRegen - 1 end},
    {name = "弱点扫描阵列", kind = "relic", rarity = "epic", price = 48, desc = "暴击 +7%，暴击击杀追加弹射", apply = function(p) p.stats.crit = p.stats.crit + 0.07; p.gear.critRicochet = true end},
    {name = "元素催化舱", kind = "relic", rarity = "epic", price = 50, desc = "元素概率 +10%，元素伤害 +16%", apply = function(p) p.stats.elementChance = p.stats.elementChance + 0.10; p.stats.elementDamage = p.stats.elementDamage + 0.16 end},
    {name = "反冲护盾线圈", kind = "relic", rarity = "epic", price = 46, desc = "击杀回盾，破盾脉冲，满盾增伤", apply = function(p) p.gear.killShield = true; p.gear.shieldBurst = true; p.gear.fullShieldDamage = true end},
    {name = "无人机母巢", kind = "legend", rarity = "legend", price = 72, desc = "周期发射支援无人机弹，射速 -5%", apply = function(p) p.gear.droneSwarm = true; p.stats.fireRate = p.stats.fireRate - 0.05 end}
}

local tempItemPool = {
    {name = "兴奋剂针剂", kind = "temp", rarity = "common", price = 12, desc = "下一波伤害 +18%", buff = {damage = 0.18}},
    {name = "战术电池", kind = "temp", rarity = "common", price = 12, desc = "下一波护盾上限 +25，开局满盾", buff = {shield = 25}},
    {name = "赏金合约", kind = "temp", rarity = "rare", price = 18, desc = "下一波结算材料 +30%", buff = {economy = 0.30}},
    {name = "低温弹匣", kind = "temp", rarity = "rare", price = 20, desc = "下一波子弹附带霜冻概率", buff = {elementChance = 0.18, element = "ice"}},
    {name = "腐蚀涂层", kind = "temp", rarity = "rare", price = 20, desc = "下一波元素伤害 +18%", buff = {elementDamage = 0.18}},
    {name = "过载保险", kind = "temp", rarity = "epic", price = 30, desc = "下一波射速 +22%，护盾回复 -20%", buff = {fireRate = 0.22, shieldRegenMult = -0.20}}
}

enemyDefs = {
    drifter = {name = "漂移噪声", sprite = "enemy_drifter", defense = "flesh", hp = 18, speed = 78, damage = 9, r = 14, color = C.red, xp = 3, coin = 2, behavior = "chase"},
    splinter = {name = "裂片", sprite = "enemy_splinter", defense = "flesh", hp = 12, speed = 130, damage = 7, r = 10, color = C.orange, xp = 2, coin = 1, behavior = "charger"},
    shell = {name = "壳层记忆", sprite = "enemy_shell", defense = "armor", hp = 44, speed = 50, damage = 13, r = 20, color = C.red, armor = 3, xp = 5, coin = 4, behavior = "guard"},
    wisp = {name = "电弧游魂", sprite = "enemy_wisp", defense = "shield", hp = 18, shield = 26, shieldRegen = 2.2, speed = 105, damage = 8, r = 13, color = C.blue, xp = 4, coin = 3, behavior = "shooter"},
    bulwark = {name = "护盾卫士", sprite = "enemy_shell", defense = "shield", hp = 34, shield = 54, shieldRegen = 2.6, speed = 58, damage = 12, r = 20, color = C.blue, armor = 0, xp = 6, coin = 5, behavior = "guard"},
    elite = {name = "坏蛋精英", sprite = "enemy_elite", defense = "shield", hp = 150, shield = 90, shieldRegen = 3.0, speed = 64, damage = 18, r = 28, color = C.blue, armor = 2, xp = 16, coin = 12, elite = true, behavior = "aura"},
    treasure = {name = "宝藏信标", sprite = "pickup_coin", defense = "flesh", hp = 16, speed = 112, damage = 0, r = 16, color = C.gold, xp = 1, coin = 5, treasureCoin = 18, treasure = true, behavior = "treasure"},
    bomber = {name = "燃烧投手", sprite = "enemy_splinter", defense = "flesh", hp = 38, speed = 72, damage = 10, r = 15, color = C.orange, xp = 4, coin = 4, behavior = "bomber"},
    rammer = {name = "突击钻头", sprite = "enemy_splinter", defense = "armor", hp = 52, speed = 96, damage = 16, r = 18, color = C.red, armor = 1, xp = 6, coin = 5, behavior = "rammer"},
    zoner = {name = "封锁织网者", sprite = "enemy_wisp", defense = "shield", hp = 42, shield = 24, shieldRegen = 1.4, speed = 68, damage = 11, r = 17, color = C.blue, armor = 0, xp = 7, coin = 6, behavior = "zoner", zoneRadius = 96, zoneDuration = 4.8, zoneCooldown = 3.5, zoneDamage = 6},
    flame_pusher = {name = "火线推进者", sprite = "enemy_splinter", defense = "flesh", hp = 40, speed = 82, damage = 11, r = 16, color = C.orange, armor = 0, xp = 5, coin = 4, behavior = "fireline", zoneRadius = 64, zoneDuration = 2.7, zoneCooldown = 2.2, zoneDamage = 5},
    rail_charger = {name = "磁轨冲锋兵", sprite = "enemy_splinter", defense = "armor", hp = 58, speed = 92, damage = 17, r = 18, color = C.cyan, armor = 1, xp = 7, coin = 5, behavior = "rail_charger"},
    rift_zoner = {name = "裂隙封锁者", sprite = "enemy_wisp", defense = "shield", hp = 46, shield = 28, shieldRegen = 1.2, speed = 72, damage = 10, r = 17, color = C.purple, armor = 0, xp = 7, coin = 6, behavior = "rift_zoner", zoneRadius = 68, zoneDuration = 3.2, zoneCooldown = 3.1, zoneDamage = 5},
    shield_amp = {name = "护盾放大器", sprite = "enemy_wisp", defense = "shield", hp = 32, shield = 42, shieldRegen = 2.8, speed = 64, damage = 8, r = 18, color = C.blue, armor = 0, xp = 8, coin = 6, behavior = "shield_amp"},
    armor_hauler = {name = "装甲搬运机", sprite = "enemy_shell", defense = "armor", hp = 72, speed = 42, damage = 14, r = 22, color = C.green, armor = 5, xp = 7, coin = 6, behavior = "armor_hauler"},
    cryo_jammer = {name = "冰霜干扰机", sprite = "enemy_wisp", defense = "shield", hp = 36, shield = 24, shieldRegen = 1.0, speed = 70, damage = 7, r = 17, color = C.ice, armor = 0, xp = 7, coin = 6, behavior = "cryo_jammer"},
    repair_drone = {name = "维修无人机", sprite = "enemy_wisp", defense = "flesh", hp = 30, speed = 118, damage = 6, r = 14, color = C.gold, armor = 0, xp = 8, coin = 7, behavior = "repair_drone"},
    beacon_summoner = {name = "信标召唤师", sprite = "enemy_wisp", defense = "shield", hp = 44, shield = 20, shieldRegen = 0.8, speed = 60, damage = 8, r = 18, color = C.purple, armor = 0, xp = 9, coin = 7, behavior = "beacon_summoner"},
    element_elite = {name = "元素精英", sprite = "enemy_elite", defense = "shield", hp = 120, shield = 70, shieldRegen = 2.0, speed = 68, damage = 16, r = 25, color = C.cyan, armor = 1, xp = 14, coin = 10, elite = true, behavior = "element_elite"},
    dual_guard = {name = "双抗精英", sprite = "enemy_shell", defense = "shield", hp = 118, shield = 96, shieldRegen = 1.8, speed = 48, damage = 17, r = 25, color = C.white, armor = 4, xp = 15, coin = 11, elite = true, behavior = "dual_guard"},
    berserker = {name = "狂暴残血怪", sprite = "enemy_splinter", defense = "flesh", hp = 46, speed = 96, damage = 13, r = 16, color = C.red, armor = 0, xp = 6, coin = 5, behavior = "berserker"}
}

bossDefs = {
    boss_heartbreak = {name = "裂心机核", sprite = "boss_heartbreak", defense = "armor", hp = 1900, shield = 260, shieldRegen = 1.2, speed = 48, damage = 24, r = 46, color = C.pink, armor = 2, xp = 80, coin = 60, boss = true, behavior = "boss", bossPattern = "heartbreak", phaseLabels = {"校准射击", "裂隙封锁", "核心暴露"}, bossRole = "弹幕 / 封锁教学"},
    boss_forge = {name = "赤炉执刑者", sprite = "boss_heartbreak", defense = "flesh", hp = 1720, shield = 120, shieldRegen = 0.8, speed = 55, damage = 27, r = 48, color = C.orange, armor = 1, xp = 82, coin = 62, boss = true, behavior = "boss", bossPattern = "forge", phaseLabels = {"热炉点火", "熔线横扫", "过热审判"}, bossRole = "燃烧区域 / 近身压迫"},
    boss_bulwark = {name = "铁幕壁垒", sprite = "boss_heartbreak", defense = "shield", hp = 1550, shield = 520, shieldRegen = 3.0, speed = 38, damage = 22, r = 52, color = C.blue, armor = 3, xp = 84, coin = 64, boss = true, behavior = "boss", bossPattern = "bulwark", phaseLabels = {"护盾校准", "壁垒增殖", "破盾反扑"}, bossRole = "高护盾 / 召唤卫士"},
    boss_hive = {name = "蜂巢母机", sprite = "boss_heartbreak", defense = "flesh", hp = 1650, shield = 190, shieldRegen = 1.0, speed = 62, damage = 21, r = 44, color = C.green, armor = 1, xp = 80, coin = 62, boss = true, behavior = "boss", bossPattern = "hive", phaseLabels = {"蜂群试探", "母巢分裂", "集群暴走"}, bossRole = "召唤 / 弹幕密度"},
    boss_glacier = {name = "冷井裁决体", sprite = "boss_heartbreak", defense = "armor", hp = 1780, shield = 240, shieldRegen = 1.4, speed = 42, damage = 23, r = 47, color = C.ice, armor = 2, xp = 82, coin = 63, boss = true, behavior = "boss", bossPattern = "glacier", phaseLabels = {"低温锁定", "霜环切割", "冻结裁决"}, bossRole = "减速区 / 节奏冻结"},
    boss_venom = {name = "蚀刻孢群", sprite = "boss_heartbreak", defense = "flesh", hp = 1880, shield = 90, shieldRegen = 0.6, speed = 50, damage = 24, r = 45, color = C.green, armor = 1, xp = 82, coin = 64, boss = true, behavior = "boss", bossPattern = "venom", phaseLabels = {"腐蚀孢子", "毒圈扩散", "衰变爆发"}, bossRole = "腐蚀易伤 / 区域逼位"},
    boss_void = {name = "黑箱坍缩核", sprite = "boss_heartbreak", defense = "shield", hp = 1680, shield = 360, shieldRegen = 1.8, speed = 45, damage = 25, r = 49, color = C.purple, armor = 2, xp = 86, coin = 66, boss = true, behavior = "boss", bossPattern = "void", phaseLabels = {"引力锁定", "黑箱牵引", "坍缩奇点"}, bossRole = "牵引 / 密集惩罚"},
    boss_rail = {name = "白噪狙击塔", sprite = "boss_heartbreak", defense = "armor", hp = 1580, shield = 260, shieldRegen = 1.1, speed = 36, damage = 31, r = 43, color = C.white, armor = 2, xp = 84, coin = 65, boss = true, behavior = "boss", bossPattern = "rail", phaseLabels = {"测距锁线", "交叉狙击", "白噪齐射"}, bossRole = "高伤狙击 / 走位校验"},
    boss_reactor = {name = "天灾反应堆", sprite = "boss_heartbreak", defense = "armor", hp = 2050, shield = 180, shieldRegen = 0.9, speed = 40, damage = 28, r = 54, color = C.red, armor = 3, xp = 88, coin = 68, boss = true, behavior = "boss", bossPattern = "reactor", phaseLabels = {"反应堆升温", "灾变泄压", "核心熔毁"}, bossRole = "爆炸环 / 高压终盘"},
    boss_reboot = {name = "重启终端", sprite = "boss_heartbreak", defense = "shield", hp = 1760, shield = 300, shieldRegen = 1.6, speed = 52, damage = 26, r = 48, color = C.gold, armor = 2, xp = 90, coin = 70, boss = true, behavior = "boss", bossPattern = "reboot", phaseLabels = {"协议重放", "多态切换", "重启归零"}, bossRole = "混合机制 / 最终综合考"},
    boss_storm = {name = "电磁审判庭", sprite = "boss_heartbreak", defense = "shield", hp = 1660, shield = 430, shieldRegen = 2.2, speed = 58, damage = 25, r = 47, color = C.cyan, armor = 1, xp = 86, coin = 66, boss = true, behavior = "boss", bossPattern = "storm", phaseLabels = {"雷场充能", "链式裁决", "电磁过载"}, bossRole = "电弧链 / 破盾压力"},
    boss_mirror = {name = "量子镜像体", sprite = "boss_heartbreak", defense = "flesh", hp = 1500, shield = 260, shieldRegen = 1.2, speed = 66, damage = 22, r = 43, color = C.purple, armor = 1, xp = 84, coin = 65, boss = true, behavior = "boss", bossPattern = "mirror", phaseLabels = {"残像校准", "镜像分裂", "多相折返"}, bossRole = "残像 / 目标切换"},
    boss_reclaimer = {name = "回收圣棺", sprite = "boss_heartbreak", defense = "armor", hp = 1850, shield = 330, shieldRegen = 2.4, speed = 34, damage = 21, r = 52, color = C.gold, armor = 4, xp = 88, coin = 68, boss = true, behavior = "boss", bossPattern = "reclaimer", phaseLabels = {"回收协议", "护盾再生", "废料圣棺"}, bossRole = "恢复 / 持久战"},
    boss_minefield = {name = "地雷织网机", sprite = "boss_heartbreak", defense = "armor", hp = 1700, shield = 210, shieldRegen = 1.0, speed = 44, damage = 27, r = 46, color = C.orange, armor = 2, xp = 84, coin = 65, boss = true, behavior = "boss", bossPattern = "minefield", phaseLabels = {"布雷启动", "网格封锁", "连锁爆破"}, bossRole = "地雷区 / 路线规划"},
    boss_duelist = {name = "碎星决斗者", sprite = "boss_heartbreak", defense = "flesh", hp = 1600, shield = 180, shieldRegen = 0.9, speed = 76, damage = 30, r = 42, color = C.red, armor = 1, xp = 86, coin = 66, boss = true, behavior = "boss", bossPattern = "duelist", phaseLabels = {"锁定挑战", "突刺连段", "处刑星轨"}, bossRole = "冲刺 / 单点高压"},
    boss_prism = {name = "棱镜分光仪", sprite = "boss_heartbreak", defense = "shield", hp = 1620, shield = 320, shieldRegen = 1.7, speed = 46, damage = 24, r = 46, color = C.white, armor = 1, xp = 86, coin = 66, boss = true, behavior = "boss", bossPattern = "prism", phaseLabels = {"分光校准", "元素折射", "全谱压制"}, bossRole = "多元素 / 读色反应"},
    boss_gravity = {name = "深井压缩者", sprite = "boss_heartbreak", defense = "armor", hp = 1920, shield = 250, shieldRegen = 1.1, speed = 39, damage = 26, r = 53, color = C.purple, armor = 3, xp = 88, coin = 68, boss = true, behavior = "boss", bossPattern = "gravity", phaseLabels = {"井口开启", "压力折叠", "深井塌缩"}, bossRole = "重力井 / 站位破坏"},
    boss_stitcher = {name = "血肉缝合塔", sprite = "boss_heartbreak", defense = "flesh", hp = 2150, shield = 80, shieldRegen = 0.4, speed = 32, damage = 24, r = 55, color = C.pink, armor = 1, xp = 88, coin = 68, boss = true, behavior = "boss", bossPattern = "stitcher", phaseLabels = {"血肉增殖", "缝合护卫", "畸变狂潮"}, bossRole = "厚血 / 小怪献祭"},
    boss_train = {name = "零度列车", sprite = "boss_heartbreak", defense = "armor", hp = 1740, shield = 220, shieldRegen = 1.0, speed = 70, damage = 28, r = 50, color = C.ice, armor = 2, xp = 86, coin = 66, boss = true, behavior = "boss", bossPattern = "train", phaseLabels = {"轨道预冷", "寒潮冲撞", "终点急冻"}, bossRole = "横冲 / 轨道预警"},
    boss_broadcast = {name = "终焉播报机", sprite = "boss_heartbreak", defense = "shield", hp = 1820, shield = 280, shieldRegen = 1.5, speed = 48, damage = 27, r = 48, color = C.gold, armor = 2, xp = 90, coin = 70, boss = true, behavior = "boss", bossPattern = "broadcast", phaseLabels = {"死亡播报", "协议串扰", "终焉倒放"}, bossRole = "混合广播 / 节奏干扰"}
}

bossPool = {"boss_heartbreak", "boss_forge", "boss_bulwark", "boss_hive", "boss_glacier", "boss_venom", "boss_void", "boss_rail", "boss_reactor", "boss_reboot", "boss_storm", "boss_mirror", "boss_reclaimer", "boss_minefield", "boss_duelist", "boss_prism", "boss_gravity", "boss_stitcher", "boss_train", "boss_broadcast"}
enemyDefs.boss = bossDefs.boss_heartbreak

applyConfiguredEnemies()

local function smallWaveDurationAt(wave)
    local safeWave = math.max(1, wave or 1)
    local chapterIndex = math.floor((safeWave - 1) / CHAPTER_SIZE) + 1
    return math.min(SMALL_WAVE_DURATION_MAX, SMALL_WAVE_DURATION_MIN + (chapterIndex - 1) * SMALL_WAVE_DURATION_STEP)
end

local wavePlans = configuredWavePlans({
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
})

local function wavePlanAt(wave)
    local safeWave = math.max(1, wave or 1)
    local chapterIndex = math.floor((safeWave - 1) / CHAPTER_SIZE) + 1
    local chapterWave = ((safeWave - 1) % CHAPTER_SIZE) + 1
    local nonBossPlanCount = math.max(1, #wavePlans - 1)
    local base = wavePlans[((safeWave - 1) % nonBossPlanCount) + 1] or wavePlans[1]
    if chapterWave == CHAPTER_SIZE then base = wavePlans[#wavePlans] end
    local plan = {}
    for k, v in pairs(base) do plan[k] = v end
    plan.events = {}
    for _, event in ipairs(base.events or {}) do
        local copy = {}
        for k, v in pairs(event) do copy[k] = v end
        plan.events[#plan.events + 1] = copy
    end
    plan.enemies = {}
    local hasBomber = false
    local hasZoner = false
    for i, entry in ipairs(base.enemies or {}) do
        local id, weight = entry[1], entry[2]
        if id == "bomber" and chapterIndex >= 2 then
            hasBomber = true
            weight = math.max(2, weight + math.floor(chapterIndex * 0.75) + (chapterWave == CHAPTER_SIZE and -1 or 1))
            if chapterIndex <= 3 and chapterWave ~= CHAPTER_SIZE then weight = math.min(weight, 1) end
        elseif id == "bomber" then
            hasBomber = true
        elseif id == "zoner" and chapterIndex >= 2 then
            hasZoner = true
            weight = math.max(2, weight + math.floor(chapterIndex * 0.80) + (chapterWave == CHAPTER_SIZE and 1 or 0))
        elseif id == "zoner" then
            hasZoner = true
        end
        plan.enemies[i] = {id, weight}
    end
    if chapterIndex >= 2 and not hasBomber then
        local bomberWeight = 3 + math.floor(chapterIndex * 0.75)
        if chapterIndex <= 3 and chapterWave ~= CHAPTER_SIZE then bomberWeight = 1 end
        plan.enemies[#plan.enemies + 1] = {"bomber", bomberWeight}
    end
    if chapterIndex >= 2 and not hasZoner then plan.enemies[#plan.enemies + 1] = {"zoner", 2 + math.floor(chapterIndex * 0.85) + (chapterWave == CHAPTER_SIZE and 1 or 0)} end
    local function addEnemyWeight(id, weight)
        plan.enemies[#plan.enemies + 1] = {id, math.max(1, math.floor(weight or 1))}
    end
    if chapterWave ~= CHAPTER_SIZE then
        if chapterIndex >= 1 and chapterWave >= 2 then addEnemyWeight("flame_pusher", 1 + chapterIndex * 0.45) end
        if chapterIndex >= 2 then addEnemyWeight("shield_amp", 2); addEnemyWeight("armor_hauler", 2); addEnemyWeight("rail_charger", 2 + chapterIndex * 0.35) end
        if chapterIndex >= 3 then addEnemyWeight("cryo_jammer", 2); addEnemyWeight("repair_drone", 1 + chapterIndex * 0.25); addEnemyWeight("beacon_summoner", 1 + chapterIndex * 0.25) end
        if chapterIndex >= 4 then addEnemyWeight("rift_zoner", 2 + chapterIndex * 0.30); addEnemyWeight("element_elite", 1 + chapterIndex * 0.18); addEnemyWeight("berserker", 2 + chapterIndex * 0.25) end
        if chapterIndex >= 5 then addEnemyWeight("dual_guard", 1 + chapterIndex * 0.16) end
        if routeAppliesToCurrentChapter and routeAppliesToCurrentChapter() and Game.routeMods and Game.routeMods.event == "element" then addEnemyWeight("element_elite", 3); addEnemyWeight("cryo_jammer", 2) end
    end
    plan.duration = chapterWave == CHAPTER_SIZE and nil or smallWaveDurationAt(safeWave)
    plan.interval = math.max(0.46, (base.interval or 1.0) - (chapterIndex - 1) * 0.020 - (chapterWave == CHAPTER_SIZE and 0.04 or 0))
    plan.pack = (base.pack or 1) + math.floor((chapterIndex - 1) / 2) + (chapterWave == CHAPTER_SIZE and 0 or 0)
    plan.name = chapterWave == CHAPTER_SIZE and ((CHAPTER_NAMES[chapterIndex] or "终局") .. "关底 Boss") or (base.name or "清理敌群")
    if chapterWave ~= CHAPTER_SIZE and chapterIndex >= 4 then
        plan.events[#plan.events + 1] = {time = 9, enemy = "zoner", side = "top", toast = "封锁织网者：战场切割"}
    end
    if (chapterIndex == 2 or chapterIndex == 3) and chapterWave == 1 then
        plan.interval = math.max(plan.interval or 1.0, chapterIndex == 2 and 1.02 or 0.92)
        plan.pack = math.max(1, (plan.pack or 1) - 1)
        for _, entry in ipairs(plan.enemies or {}) do
            if entry[1] == "bomber" then entry[2] = math.min(entry[2], chapterIndex == 2 and 1 or 2) end
            if entry[1] == "shell" then entry[2] = math.max(6, math.floor(entry[2] * (chapterIndex == 2 and 0.58 or 0.68))) end
            if entry[1] == "rammer" then entry[2] = math.max(4, math.floor(entry[2] * (chapterIndex == 2 and 0.65 or 0.72))) end
        end
    end
    if chapterWave == CHAPTER_SIZE then
        plan.boss = true
        plan.events = {
            {time = 0.2, enemy = "boss", side = "right", toast = "目标：打爆 Boss"}
        }
        if chapterIndex >= 3 then plan.events[#plan.events + 1] = {time = 12, enemy = "zoner", side = "top", toast = "封锁织网者：压缩战场"} end
        if chapterIndex >= 3 then plan.events[#plan.events + 1] = {time = 16, enemy = "bomber", side = "top", toast = "燃烧投手支援入场"} end
        if chapterIndex >= 2 then plan.events[#plan.events + 1] = {time = 24, enemy = "elite", side = "left", toast = "Boss护卫：左侧精英"} end
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
local function rollBossIdForWave(wave)
    local forced = os.getenv("LOVE_AUTOPLAY_BOSS_ID")
    if forced and bossDefs and bossDefs[forced] then return forced end
    if not bossPool or #bossPool == 0 then return "boss_heartbreak" end
    local picked = bossPool[rnd(1, #bossPool)]
    if #bossPool > 1 then
        for _ = 1, 8 do
            if picked ~= Game.lastBossId then break end
            picked = bossPool[rnd(1, #bossPool)]
        end
    end
    return picked
end

local function selectedBossDef()
    local id = Game.waveBossId or "boss_heartbreak"
    return (bossDefs and bossDefs[id]) or (bossDefs and bossDefs.boss_heartbreak) or enemyDefs.boss
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
    if routeAppliesToCurrentChapter and routeAppliesToCurrentChapter() then
        local route = Game.routeMods or {}
        bonus.coinMult = bonus.coinMult * (route.coin or 1)
        bonus.enemyHp = bonus.enemyHp * (route.enemyHp or 1)
        bonus.extraPack = bonus.extraPack + (route.extraPack or 0)
        bonus.intervalMult = bonus.intervalMult * (route.interval or 1)
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
    coins = 100,
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
    {name = "战役模式", desc = "普通关撑住 30 秒，关底打爆 Boss", mode = "survive"}
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
    {name = "腐蚀针剂", kind = "item", rarity = "rare", family = "元素", desc = "腐蚀叠层上限提高并强化易伤，元素伤害 +10%", apply = function(p) p.stats.elementDamage = p.stats.elementDamage + 0.10; p.gear.deepCorrode = true end},
    {name = "冰裂准星", kind = "mod", rarity = "epic", family = "元素", desc = "冻结/减速目标更容易被暴击", apply = function(p) p.gear.freezeCrit = true; p.stats.crit = p.stats.crit + 0.03 end},
    {name = "爆炸协议", kind = "mod", rarity = "epic", family = "爆炸", desc = "爆炸伤害 +22%，击杀小范围爆裂", apply = function(p) p.stats.explosiveDamage = p.stats.explosiveDamage + 0.22; p.gear.killBurst = true end},
    {name = "追踪电弧", kind = "relic", rarity = "epic", family = "元素", desc = "电弧命中后周期追踪", apply = function(p) p.gear.autoArc = true; p.stats.elementDamage = p.stats.elementDamage + 0.10 end},
    {name = "护盾回流", kind = "relic", rarity = "epic", family = "护盾", desc = "击杀回复护盾，满盾时伤害 +8%", apply = function(p) p.gear.killShield = true; p.gear.fullShieldDamage = true end},
    {name = "血线狂热", kind = "relic", rarity = "epic", family = "低血", desc = "生命越低伤害越高，吸血 +2%", apply = function(p) p.stats.lowHpDamage = p.stats.lowHpDamage + 0.45; p.stats.lifesteal = p.stats.lifesteal + 0.02 end},
    {name = "回收协议", kind = "relic", rarity = "rare", family = "经济", desc = "关卡结算材料 +18%", apply = function(p) p.stats.economy = p.stats.economy + 0.18 end},
    {name = "赏金猎犬", kind = "legend", rarity = "legend", family = "经济", desc = "商店免费刷新 +1，结算材料 +12%", apply = function(p) p.stats.economy = p.stats.economy + 0.12; Game.freeRefresh = Game.freeRefresh + 1 end},
    {name = "回声无尽", kind = "legend", rarity = "legend", family = "武器", desc = "电弧周期追踪，伤害 -5%", flag = "endlessEcho", apply = function(p) p.gear.echoOverdrive = true; p.stats.damage = p.stats.damage - 0.05 end},
    {name = "腐蚀瘟疫", kind = "legend", rarity = "legend", family = "元素", desc = "腐蚀击杀会扩散层数和易伤", apply = function(p) p.gear.corrosionSpread = true; p.stats.elementDamage = p.stats.elementDamage + 0.12 end},
    {name = "坏心眼弹匣", kind = "legend", rarity = "legend", family = "暴击", desc = "暴击击杀触发弹射爆裂", apply = function(p) p.gear.critRicochet = true; p.stats.critDamage = p.stats.critDamage + 0.18 end},
    {name = "弹幕校准", kind = "mod", rarity = "rare", family = "弹幕暴击", desc = "弹体数量 +1，暴击率 +3%", apply = function(p) p.gear.extraProjectile = (p.gear.extraProjectile or 0) + 1; p.stats.crit = p.stats.crit + 0.03 end},
    {name = "弱点连锁", kind = "relic", rarity = "epic", family = "弹幕暴击", desc = "暴击击杀后下一击必暴，暴伤 +14%", apply = function(p) p.gear.blink = true; p.stats.critDamage = p.stats.critDamage + 0.14 end},
    {name = "元素过量", kind = "mod", rarity = "rare", family = "元素异常", desc = "元素概率 +8%，元素伤害 +12%", apply = function(p) p.stats.elementChance = p.stats.elementChance + 0.08; p.stats.elementDamage = p.stats.elementDamage + 0.12 end},
    {name = "异常扩散", kind = "relic", rarity = "epic", family = "元素异常", desc = "腐蚀/点燃击杀扩散，腐蚀目标承受更多伤害", apply = function(p) p.gear.corrosionSpread = true; p.gear.burnSpread = true; p.gear.freezeCrit = true end},
    {name = "盾反协议", kind = "relic", rarity = "epic", family = "护盾反击", desc = "破盾释放电爆，击杀回复护盾", apply = function(p) p.gear.shieldBurst = true; p.gear.killShield = true end},
    {name = "满盾压制", kind = "mod", rarity = "rare", family = "护盾反击", desc = "满盾时伤害提高，护盾回复 +1", apply = function(p) p.gear.fullShieldDamage = true; p.shieldRegen = p.shieldRegen + 1 end},
    {name = "无人机同步", kind = "relic", rarity = "epic", family = "召唤无人机", desc = "周期支援无人机弹，召唤物继承元素", apply = function(p) p.gear.droneSwarm = true; p.stats.elementChance = p.stats.elementChance + 0.04 end},
    {name = "蜂群备份", kind = "legend", rarity = "legend", family = "召唤无人机", desc = "无人机击杀分裂，射速 +8%", apply = function(p) p.gear.droneSwarm = true; p.gear.droneSplit = true; p.stats.fireRate = p.stats.fireRate + 0.08 end}
}

local function selectedCharacter() return basePlayerDef end
local function selectedObjective() return objectiveDefs[Game.selectedObjective] or objectiveDefs[1] end

local rarityColor = {
    common = {0.70, 0.74, 0.82},
    rare = {0.48, 0.72, 0.80},
    epic = {0.62, 0.54, 0.76},
    legend = {0.88, 0.70, 0.42}
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

local function shopPriceMultiplier(wave)
    local safeWave = math.max(1, wave or (Game and Game.wave) or 1)
    local baseStep = Balance.shop_price_wave_step or 0.012
    local lateStart = Balance.shop_price_late_start or 8
    local lateStep = Balance.shop_price_late_step or 0.028
    local wavePart = 1 + math.max(0, safeWave - 1) * baseStep
    local latePart = 1 + math.max(0, safeWave - lateStart) * lateStep
    return wavePart * latePart
end

local function priced(base, rarity, wave)
    return math.max(8, math.floor(base * (rarityPower[rarity] or 1) * shopPriceMultiplier(wave) + 0.5))
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


function drawElementProjectileLayer(b, pulse)
    local elemId = b.element or "kinetic"
    local elem = elements[elemId] or elements.kinetic
    local c = elem.color or b.color or C.white
    love.graphics.setBlendMode("add")
    if elemId == "burn" then
        color(c, 0.36 + pulse * 0.18)
        love.graphics.circle("fill", -18, 0, 8 + pulse * 4)
        color(C.orange, 0.30)
        love.graphics.circle("fill", -30, 0, 12 + pulse * 6)
        love.graphics.setLineWidth(2)
        color(c, 0.70)
        love.graphics.arc("line", "open", 0, 0, 17 + pulse * 6, -0.75, 0.75)
    elseif elemId == "arc" then
        love.graphics.setLineWidth(3)
        color(c, 0.82)
        love.graphics.line(-24, -7, -13, 6, -3, -5, 9, 5, 22, -3)
        color(C.white, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(-20, -4, -12, 4, -2, -4, 8, 3, 18, -2)
        love.graphics.setLineWidth(2)
        color(c, 0.38)
        love.graphics.circle("line", 0, 0, 17 + pulse * 5)
    elseif elemId == "corrode" then
        color(c, 0.42)
        love.graphics.circle("fill", -7, -4, 5 + pulse * 3)
        love.graphics.circle("fill", -18, 5, 4 + pulse * 2)
        love.graphics.circle("fill", 8, 4, 3 + pulse * 2)
        color(c, 0.62)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, 15 + pulse * 4)
        love.graphics.setLineWidth(1)
    elseif elemId == "ice" then
        color(c, 0.42)
        love.graphics.polygon("line", 0, -18 - pulse * 4, 15 + pulse * 3, 0, 0, 18 + pulse * 4, -15 - pulse * 3, 0)
        color(C.white, 0.42)
        love.graphics.line(-18, 0, 18, 0)
        love.graphics.line(0, -18, 0, 18)
    elseif elemId == "void" then
        color(c, 0.28 + pulse * 0.16)
        love.graphics.circle("line", 0, 0, 24 + pulse * 8)
        love.graphics.circle("line", 0, 0, 11 + pulse * 5)
        color(c, 0.18)
        love.graphics.circle("fill", 0, 0, 22 + pulse * 5)
    else
        color(C.gold, 0.24 + pulse * 0.10)
        love.graphics.rectangle("fill", -30, -2, 42, 4, 2, 2)
        color(C.white, 0.35)
        love.graphics.line(-20, 0, 20, 0)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
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
    drawElementProjectileLayer(b, pulse)

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
        local tint = elements[b.element or "kinetic"] or elements.kinetic
        love.graphics.setColor(tint.color[1], tint.color[2], tint.color[3], 0.78)
        local size = b.aura and 34 or (b.splash and 30 or 24)
        local scale = size / math.max(img:getWidth(), img:getHeight())
        love.graphics.draw(img, 0, 0, 0, scale, scale, img:getWidth() / 2, img:getHeight() / 2)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

local function addText(x, y, text, c, opts)
    opts = opts or {}
    Game.damageTexts[#Game.damageTexts + 1] = {x = x, y = y, text = text, color = c or C.white, life = opts.life or 0.72, maxLife = opts.life or 0.72, scale = opts.scale or 1, font = opts.font}
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
    if e and e.boss then return r * 3.25 + 16 end
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

function currentSurvivalDuration()
    local plan = currentWavePlan and currentWavePlan()
    return (plan and plan.duration) or smallWaveDurationAt(Game.wave or 1) or SURVIVAL_DURATION
end

function survivalProgress()
    return clamp((Game.waveElapsed or 0) / math.max(1, currentSurvivalDuration()), 0, 1)
end

function runProgress()
    return clamp(((Game.wave or 1) - 1 + survivalProgress()) / math.max(1, Game.maxWave or CAMPAIGN_WAVES), 0, 1)
end

function difficultyProgress()
    -- 第一大关是养成段；第二大关开始按小关线性加压。
    -- 压力目标服务完整 30 小关通关，而不是在第 20 小关提前封顶。
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
    if chapterWave == CHAPTER_SIZE then return "关底 Boss" end
    if t < 0.20 then return "热身清场" end
    if t < 0.45 then return "敌群增压" end
    if t < 0.70 then return "火线压迫" end
    if t < 0.90 then return "濒临失控" end
    return "终局清场"
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
    local speed = (def.speed + Game.wave * 0.85) * bonus.enemySpeed * curve.speed * (1 + Game.danger * 0.025)
    local damage = def.damage * wavePowerScale(Game.wave) * bonus.enemyDamage * curve.damage * (1 + Game.danger * 0.06)
    local armor = (def.armor or 0) + bonus.enemyArmor + curve.armor
    local shieldRegen = def.shieldRegen or 0
    if def.boss and (Game.wave or 1) <= CHAPTER_SIZE then
        -- 第一 Boss 是教学标杆：保留机制语言，但随机池扩到 20 后不能让冲刺/区域/恢复型模板在入门关形成数值墙。
        hp = hp * 0.60
        shield = shield * 0.56
        speed = speed * 0.86
        damage = damage * 0.32
        armor = math.max(0, armor - 1)
    elseif def.boss then
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        local bossDamageRamp = clamp(0.18 + chapterIndex * 0.085, 0.35, 1.00)
        damage = damage * bossDamageRamp
        speed = speed * clamp(0.86 + chapterIndex * 0.035, 0.92, 1.00)
        if chapterIndex <= 3 then
            -- 第二/第三章是自然构筑成型窗口：保留机制，但别让护盾/恢复/狙击模板把尚未成型的构筑拖死。
            local midHpEase = chapterIndex == 2 and 0.78 or 0.88
            local midShieldEase = chapterIndex == 2 and 0.66 or 0.80
            local midRegenEase = chapterIndex == 2 and 0.50 or 0.68
            hp = hp * midHpEase
            shield = shield * midShieldEase
            shieldRegen = shieldRegen * midRegenEase
            damage = damage * (chapterIndex == 2 and 0.86 or 0.93)
            local pattern = def.bossPattern or ""
            if pattern == "rail" then
                damage = damage * 0.72
                hp = hp * 0.92
            elseif pattern == "bulwark" then
                shield = shield * 0.72
                shieldRegen = shieldRegen * 0.55
                armor = math.max(0, armor - 1)
            elseif pattern == "reboot" then
                hp = hp * 0.88
                shield = shield * 0.76
                shieldRegen = shieldRegen * 0.65
            elseif pattern == "glacier" then
                hp = hp * 0.88
                speed = speed * 0.92
            elseif pattern == "train" then
                hp = hp * 0.86
                speed = speed * 0.90
                damage = damage * 0.88
            end
        end
    end
    Game.enemies[#Game.enemies + 1] = {
        name = def.name, x = x, y = y, r = def.r,
        hp = hp, maxHp = hp, shield = shield, maxShield = shield, defense = def.defense or (shield > 0 and "shield" or ((def.armor or 0) > 0 and "armor" or "flesh")), shieldRegen = shieldRegen,
        speed = speed,
        damage = damage, baseDamage = damage, armor = armor,
        color = def.color, xp = def.xp, coin = def.coin, treasureCoin = def.treasureCoin, sprite = def.sprite, behavior = def.behavior or "chase",
        zoneRadius = def.zoneRadius, zoneDuration = def.zoneDuration, zoneCooldown = def.zoneCooldown, zoneDamage = def.zoneDamage,
        elite = def.elite, boss = def.boss, bossPattern = def.bossPattern, phaseLabels = def.phaseLabels, bossRole = def.bossRole, treasure = def.treasure,
        shootTimer = rnd() * 1.2, dashTimer = rnd() * 1.6, wanderTimer = rnd() * 1.4, wanderAngle = rnd() * TAU,
        burn = 0, slow = 0, corrosion = 0, lastHit = 0
    }
    local spawned = Game.enemies[#Game.enemies]
    if def.behavior == "element_elite" then
        local elems = {"burn", "arc", "corrode", "ice", "void"}
        local elem = elems[rnd(1, #elems)]
        spawned.elementKind = elem
        spawned.color = (elements[elem] and elements[elem].color) or spawned.color
        spawned.lastElement = elem
    end
    if def.behavior == "dual_guard" then spawned.damageTakenMult = 0.92 end
    if def.boss then
        local left, top, right, bottom = enemyArenaBounds(spawned)
        spawned.x = clamp(spawned.x, left, right)
        spawned.y = clamp(spawned.y, top, bottom)
        spawned.enteredArena = true
        spawned.bossPhase = 1
        spawned.bossPhaseName = (spawned.phaseLabels and spawned.phaseLabels[1]) or "校准射击"
        spawned.bossAttackTimer = 0.75
        spawned.bossSpecialTimer = 2.4
        spawned.bossWeakTimer = 0
        spawned.damageTakenMult = 1
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        if (Game.wave or 1) <= CHAPTER_SIZE then
            spawned.shieldRegen = (spawned.shieldRegen or 0) * 0.45
            spawned.bossAttackTimer = math.max(spawned.bossAttackTimer or 0, 1.60)
            spawned.bossSpecialTimer = math.max(spawned.bossSpecialTimer or 0, 4.8)
            spawned.bossSummonTimer = math.max(spawned.bossSummonTimer or 0, 5.8)
        elseif chapterIndex <= 3 then
            spawned.bossAttackTimer = math.max(spawned.bossAttackTimer or 0, chapterIndex == 2 and 1.35 or 1.10)
            spawned.bossSpecialTimer = math.max(spawned.bossSpecialTimer or 0, chapterIndex == 2 and 3.8 or 3.1)
            spawned.bossSummonTimer = math.max(spawned.bossSummonTimer or 0, chapterIndex == 2 and 4.8 or 4.0)
        end
        toast("Boss 接入：" .. def.name)
        addText(Game.w / 2 - 46, 154, "Boss", C.red)
    else
        local specialLabels = {
            bomber = {"燃烧投手", C.orange}, zoner = {"封锁", C.purple}, rift_zoner = {"裂隙", C.purple}, fireline = {"火线", C.orange},
            shield_amp = {"护盾放大", C.blue}, repair_drone = {"维修", C.gold}, beacon_summoner = {"召唤", C.purple},
            cryo_jammer = {"冰霜干扰", C.ice}, rail_charger = {"磁轨", C.cyan}, armor_hauler = {"装甲", C.green}, berserker = {"狂暴", C.red}, dual_guard = {"双抗", C.white}
        }
        local labelInfo = def.elite and {"精英", C.purple} or specialLabels[def.behavior]
        if labelInfo then addText(clamp(x, 80, Game.w - 80), clamp(y, 170, Game.h - 90), labelInfo[1], labelInfo[2]) end
    end
end

local function spawnPack(plan)
    plan = plan or currentWavePlan()
    if plan.boss then
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        if chapterIndex <= 3 then return end
    end
    local side = pickSpawnSide(plan)
    local bonus = currentAffixBonuses()
    local curve = survivalEnemyCurve()
    if #Game.enemies >= curve.cap then return end
    local pack = math.min((plan.pack or 1) + bonus.extraPack + curve.pack, math.max(1, curve.cap - #Game.enemies))
    if plan.boss then
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        pack = math.max(1, math.floor(pack * clamp(0.24 + chapterIndex * 0.13, 0.36, 0.78)))
    end
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

function itemSlotLevel()
    return (Game.player and Game.player.itemSlotLevel) or 1
end

function itemSlotEffectMultiplier()
    return 1 + math.max(0, itemSlotLevel() - 1) * (Balance.module_slot_effect_step or 0.06)
end

function itemSlotUpgradeCost()
    local p = Game.player or {}
    local level = p.itemSlotLevel or 1
    local slots = p.itemSlots or ITEM_SLOT_BASE
    if slots >= ITEM_SLOT_MAX then return nil end
    return (Balance.item_slot_upgrade_base or 22) + (level - 1) * (Balance.item_slot_upgrade_step or 14)
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
    p.itemSlotLevel = (p.itemSlotLevel or 1) + 1
    p.itemSlots = math.min(ITEM_SLOT_MAX, ITEM_SLOT_BASE + p.itemSlotLevel - 1)
    rebuildPlayerBuildStats()
    playCue("shop"); toast("模块槽 Lv." .. p.itemSlotLevel .. "：容量 " .. #p.items .. "/" .. p.itemSlots .. "，模块效能 ×" .. string.format("%.2f", itemSlotEffectMultiplier()))
    return true
end

local function applyItem(item)
    if item.apply and not item.effects then item.apply(Game.player) end
    return addPermanentModule(item)
end

local function addWeapon(def)
    stampItemLevel(def)
    local p = Game.player
    if #p.weapons >= WEAPON_SLOT_MAX then
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
    playCue("shop"); toast("战术模块已备好：" .. item.name)
    return true
end

synergyTagDefs = {
    {id = "barrage", name = "弹幕", color = C.cyan},
    {id = "element", name = "元素", color = C.orange},
    {id = "shield", name = "护盾", color = C.blue},
    {id = "drone", name = "召唤", color = C.green},
    {id = "crit", name = "暴击", color = C.gold},
    {id = "explosive", name = "爆炸", color = C.red},
    {id = "void", name = "黑箱", color = C.purple}
}

local synergyTagById = {}
for _, tag in ipairs(synergyTagDefs) do synergyTagById[tag.id] = tag end

local function addSynergyTag(tags, id)
    if id then tags[id] = true end
end

function tagsForBuildObject(obj)
    local tags = {}
    if not obj then return tags end
    for _, tag in ipairs(obj.tags or {}) do addSynergyTag(tags, tag) end
    local text = ((obj.name or "") .. " " .. (obj.desc or "") .. " " .. (obj.family or "") .. " " .. (obj.kind or ""))
    if obj.effects then
        for _, effect in ipairs(obj.effects or {}) do
            local label = effect.roll and effect.roll.label or ""
            if label == "伤害" or label == "射速" or label == "弹速" then addSynergyTag(tags, "barrage") end
            if label == "元素" or label == "附着" then addSynergyTag(tags, "element") end
            if label == "暴击" or label == "暴伤" then addSynergyTag(tags, "crit") end
            if label == "生命" or label == "吸血" then addSynergyTag(tags, "shield") end
            if label == "回收" or label == "拾取" then addSynergyTag(tags, "void") end
        end
    end
    if obj.brand == "swarm" or (obj.count or 1) >= 3 or text:find("弹幕") or text:find("多弹") or text:find("弹体") or text:find("射速") or text:find("弹速") then addSynergyTag(tags, "barrage") end
    if (obj.element and obj.element ~= "kinetic") or text:find("元素") or text:find("附着") or text:find("灼烧") or text:find("腐蚀") or text:find("霜冻") or text:find("电弧") or text:find("电击") then addSynergyTag(tags, "element") end
    if obj.kind == "shield" or text:find("护盾") or text:find("生命") or obj.shieldCap or obj.shieldRegen then addSynergyTag(tags, "shield") end
    if obj.brand == "drone" or obj.hiveSplit or text:find("无人机") or text:find("蜂群") or text:find("召唤") then addSynergyTag(tags, "drone") end
    if obj.brand == "starforge" or (obj.critBonus or 0) > 0 or text:find("暴击") or text:find("暴伤") or text:find("弱点") or text:find("瞄准") then addSynergyTag(tags, "crit") end
    if obj.splash or obj.fireSplash or text:find("爆") or text:find("燃烧") or text:find("熔火") then addSynergyTag(tags, "explosive") end
    if obj.brand == "blackbox" or obj.element == "void" or obj.voidSlow or obj.aura or text:find("黑箱") or text:find("虚空") or text:find("代价") or text:find("回收") then addSynergyTag(tags, "void") end
    return tags
end

function synergyTagTextFor(item)
    local tags = tagsForBuildObject(item)
    local out = {}
    for _, def in ipairs(synergyTagDefs) do if tags[def.id] then out[#out + 1] = def.name end end
    return #out > 0 and table.concat(out, "/") or "无"
end

applyBuildSynergies = function()
    local p = Game.player
    if not p or not p.stats then return end
    p.synergies = {}
    p.synergyTags = {barrage = 0, element = 0, shield = p.shieldItem and 1 or 0, drone = 0, crit = 0, explosive = 0, void = 0}
    local moduleKeys = {}
    for _, w in ipairs(p.weapons or {}) do
        for tag in pairs(tagsForBuildObject(w)) do p.synergyTags[tag] = (p.synergyTags[tag] or 0) + 1 end
    end
    if p.shieldItem then
        for tag in pairs(tagsForBuildObject(p.shieldItem)) do p.synergyTags[tag] = (p.synergyTags[tag] or 0) + 1 end
    end
    for _, item in ipairs(p.items or {}) do
        moduleKeys[mergeKeyForItem(item)] = true
        for tag in pairs(tagsForBuildObject(item)) do p.synergyTags[tag] = (p.synergyTags[tag] or 0) + 1 end
    end
    for _, combo in ipairs(moduleCombos or {}) do
        local ok = true
        for _, req in ipairs(combo.requires or {}) do
            if not moduleKeys[req] then ok = false; break end
        end
        if ok then
            for stat, value in pairs(combo.bonuses or {}) do applyModuleBonus(p, stat, value) end
            p.synergies[#p.synergies + 1] = "模块组合·" .. (combo.name or combo.id or "组合") .. "：" .. comboBonusText(combo)
        end
    end
    local function add(tag, tier, text)
        local def = synergyTagById[tag]
        p.synergies[#p.synergies + 1] = (def and def.name or tag) .. tostring(tier) .. "：" .. text
    end
    local barrage = p.synergyTags.barrage or 0
    if barrage >= 2 then p.stats.fireRate = p.stats.fireRate + 0.06; add("barrage", 2, "射速+6%") end
    if barrage >= 4 then p.gear.extraProjectile = (p.gear.extraProjectile or 0) + 1; add("barrage", 4, "弹体+1") end
    if barrage >= 6 then p.stats.projectileSpeed = p.stats.projectileSpeed + 0.16; add("barrage", 6, "弹速+16%") end

    local element = p.synergyTags.element or 0
    if element >= 2 then p.stats.elementChance = (p.stats.elementChance or 0) + 0.07; add("element", 2, "附着+7%") end
    if element >= 4 then p.stats.elementDamage = (p.stats.elementDamage or 1) + 0.15; add("element", 4, "元素伤害+15%") end
    if element >= 6 then p.gear.elementSpread = true; add("element", 6, "异常击杀扩散") end

    local shield = p.synergyTags.shield or 0
    if shield >= 2 then p.shieldRegen = p.shieldRegen + 1.0; add("shield", 2, "护盾回复+1") end
    if shield >= 4 then p.maxShield = p.maxShield + 22; p.shield = math.min(p.maxShield, p.shield + 22); add("shield", 4, "护盾上限+22") end
    if shield >= 6 then p.gear.shieldBurst = true; p.gear.killShield = true; add("shield", 6, "破盾脉冲+击杀回盾") end

    local drone = p.synergyTags.drone or 0
    if drone >= 2 then p.gear.droneSwarm = true; add("drone", 2, "周期支援齐射") end
    if drone >= 4 then p.gear.droneSplit = true; add("drone", 4, "无人机分裂") end
    if drone >= 6 then p.stats.fireRate = p.stats.fireRate + 0.10; add("drone", 6, "母巢过载") end

    local crit = p.synergyTags.crit or 0
    if crit >= 2 then p.stats.crit = p.stats.crit + 0.05; add("crit", 2, "暴击+5%") end
    if crit >= 4 then p.gear.critRicochet = true; add("crit", 4, "暴击击杀弹射") end
    if crit >= 6 then p.gear.blink = true; add("crit", 6, "暴击击杀蓄必暴") end

    local explosive = p.synergyTags.explosive or 0
    if explosive >= 2 then p.stats.explosiveDamage = (p.stats.explosiveDamage or 1) + 0.12; add("explosive", 2, "爆炸伤害+12%") end
    if explosive >= 4 then p.gear.fireSplash = true; add("explosive", 4, "爆炸追加燃烧") end
    if explosive >= 6 then p.gear.killBurst = true; add("explosive", 6, "击杀爆裂") end

    local void = p.synergyTags.void or 0
    if void >= 2 then p.stats.range = p.stats.range + 0.08; add("void", 2, "射程+8%") end
    if void >= 4 then p.stats.economy = p.stats.economy + 0.10; add("void", 4, "材料回收+10%") end
    if void >= 6 then p.gear.autoArc = true; p.gear.echoOverdrive = true; add("void", 6, "黑箱追踪电弧") end

    if shield >= 1 and element >= 1 then p.gear.shieldArcAura = true end
    local summary = {}
    for _, def in ipairs(synergyTagDefs) do
        local count = p.synergyTags[def.id] or 0
        if count >= 2 then summary[#summary + 1] = def.name .. count end
    end
    p.synergySummary = #summary > 0 and table.concat(summary, " / ") or "未成型"
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
            local mult = itemSlotEffectMultiplier()
            for _, e in ipairs(item.effects) do e.roll.apply(p, e.value * mult) end
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
        {name = "分裂枪管", tag = "多弹", cost = 0.55, brands = {swarm = 4, drone = 4}, apply = function(w, p) if (w.count or 1) < 8 then w.count = (w.count or 1) + 1; w.damage = math.max(1, math.floor(w.damage * 0.90 + 0.5)); w.spread = (w.spread or 0) + 0.08 end end},
        {name = "重炮管", tag = "重击", cost = 0.60, brands = {molten = 4, blackbox = 2, caustic = 3, cryo = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.16 + p * 0.04) + 0.5); if w.speed > 0 then w.speed = w.speed * 0.86 end; w.cooldown = w.cooldown * 1.08 end},
        {name = "棱镜枪管", tag = "折射", cost = 0.65, brands = {echo = 4, starforge = 2, cryo = 3}, apply = function(w, p) w.bounce = (w.bounce or 0) + 1; w.damage = math.max(1, math.floor(w.damage * 0.94 + 0.5)) end}
    },
    core = {
        {name = "暴击核心", tag = "暴击", cost = 0.55, brands = {starforge = 4}, apply = function(w, p) w.critBonus = (w.critBonus or 0) + 0.06 + p * 0.015; w.critDamageBonus = (w.critDamageBonus or 0) + 0.14 + p * 0.025 end},
        {name = "过载核心", tag = "过载", cost = 0.58, brands = {blackbox = 3, molten = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.12 + p * 0.035) + 0.5); w.overloadTax = true end},
        {name = "元素核心", tag = "元素", cost = 0.52, brands = {molten = 3, echo = 2, blackbox = 2, caustic = 3, cryo = 3}, apply = function(w, p) w.elementPower = (w.elementPower or 1) + 0.14 + p * 0.035; w.damage = math.max(1, math.floor(w.damage * 0.96 + 0.5)) end},
        {name = "稳定核心", tag = "稳定", cost = 0.42, brands = {starforge = 2, swarm = 2}, apply = function(w, p) w.spread = math.max(0, (w.spread or 0) * 0.82); w.cooldown = w.cooldown / (1.04 + p * 0.015) end}
    },
    power = {
        {name = "速射供能", tag = "速射", cost = 0.50, brands = {swarm = 3, starforge = 2, drone = 3}, apply = function(w, p) w.cooldown = w.cooldown / (1.09 + p * 0.025); w.damage = math.max(1, math.floor(w.damage * 0.95 + 0.5)) end},
        {name = "高压供能", tag = "高压", cost = 0.54, brands = {molten = 3, blackbox = 2}, apply = function(w, p) w.damage = math.floor(w.damage * (1.14 + p * 0.035) + 0.5); w.cooldown = w.cooldown * 1.06 end},
        {name = "回收供能", tag = "回收", cost = 0.48, brands = {swarm = 2, echo = 2, drone = 3}, apply = function(w, p) w.killHaste = true; w.cooldown = w.cooldown / 1.03 end},
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
    rapid = {text = "速射", cost = 0.48, brands = {swarm = 3, starforge = 2, drone = 3}, apply = function(w, p) w.cooldown = w.cooldown / (1.08 + p * 0.04) end},
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
    void = {title = "黑箱坍缩", desc = "牵引光环周期爆裂", apply = function(w) w.voidCollapse = true; w.aura = (w.aura or 48) + 38; w.voidSlow = true; w.damage = math.floor(w.damage * 1.20 + 0.5) end},
    splitter = {title = "星雨处刑", desc = "暴击击杀追加弹幕", apply = function(w) w.sparkSplit = true; w.critBonus = (w.critBonus or 0) + 0.08; w.count = (w.count or 1) + 1 end},
    acid = {title = "绿潮剥皮", desc = "腐蚀叠层更高，击杀扩散易伤", apply = function(w) w.statusChance = (w.statusChance or 0.25) + 0.18; w.elementPower = (w.elementPower or 1) + 0.18; w.deepCorrodeWeapon = true end},
    frost = {title = "绝对零度", desc = "霜冻更快冻结并碎裂", apply = function(w) w.statusChance = (w.statusChance or 0.25) + 0.20; w.freezeShatter = true; w.damage = math.floor(w.damage * 1.10 + 0.5) end},
    drone = {title = "蜂群女王", desc = "无人机击杀分裂并电击护盾", apply = function(w) w.hiveSplit = true; w.statusChance = (w.statusChance or 0.20) + 0.16; w.count = (w.count or 1) + 2 end}
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
    if def.element ~= "kinetic" then
        def.statusChance = clamp((def.statusChance or 0.22) + (power - 1) * 0.035, 0.12, 0.62)
        def.statusDamage = math.max(2, math.floor((def.statusDamage or math.max(3, def.damage * 0.36)) * (0.85 + power * 0.25) + 0.5))
    else
        def.statusChance = def.statusChance or 0
        def.statusDamage = def.statusDamage or 0
    end
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
    def.price = math.max(18, math.floor((base.price or 24) * (rarityPrice[rarity] or 1) * (1 + budgetSpend * 0.08) * shopPriceMultiplier(def.level or Game.wave or 1) + 0.5))
    local descParts = {brand.name, elem.name, elementProcText(def)}
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
moduleCombos = Balance.moduleCombos or {}

function applyModuleBonus(p, stat, value)
    if stat == "hp" then
        p.maxHp = p.maxHp + math.floor(value + 0.5)
        p.hp = math.min(p.maxHp, p.hp + math.floor(value * 0.5 + 0.5))
    elseif stat == "pickup" then
        p.pickup = p.pickup + math.floor(value + 0.5)
    elseif p.stats and p.stats[stat] ~= nil then
        p.stats[stat] = p.stats[stat] + value
    end
end

function comboBonusText(combo)
    local parts = {}
    for stat, value in pairs(combo.bonuses or {}) do
        local def = moduleStatDefs[stat]
        if def and def.desc then parts[#parts + 1] = def.desc(value) end
    end
    return table.concat(parts, " / ")
end

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
    local keys = {"needle", "swarm", "molten", "echo", "coil", "void", "splitter", "acid", "frost", "drone"}
    return makeWeaponItem(keys[rnd(1, #keys)])
end

local function randomSupportShopItem()
    local roll = rnd()
    if roll < (Balance.shop_support_shield_chance or 0.34) then return makeShieldItem() end
    if roll < (Balance.shop_support_temp_chance or 0.58) then return makeTempItem() end
    return makeStatItem()
end

local function randomShopItem()
    return rnd() < 0.36 and randomWeaponShopItem() or randomSupportShopItem()
end

local function randomShopItemForSlot(i)
    return i <= (Balance.shop_weapon_slots or 3) and randomWeaponShopItem() or randomSupportShopItem()
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

local slotSymbols = configuredSlotSymbols({
    {id = "coin", name = "材料", mark = "◆", color = C.gold, weight = 28},
    {id = "weapon", name = "武器", mark = "⚙", color = C.cyan, weight = 18},
    {id = "temp", name = "战术", mark = "战", color = C.purple, weight = 18},
    {id = "shield", name = "护盾", mark = "盾", color = C.blue, weight = 14},
    {id = "heal", name = "修复", mark = "❤", color = C.pink, weight = 14},
    {id = "blackbox", name = "黑箱", mark = "箱", color = C.purple, weight = 8},
    {id = "rare", name = "稀有", mark = "稀", color = C.orange, weight = 6}
})

local function clearedWaveCount()
    if Game.state == "shop" or Game.state == "levelup" then return math.max(0, Game.wave - 1) end
    return math.max(0, Game.wave)
end

local function clearRewardForWave(wave)
    local safeWave = math.max(1, wave or 1)
    local reward = (Balance.clear_reward_base or 12) + math.floor(safeWave * (Balance.clear_reward_wave_step or 1.5)) + Game.danger * (Balance.clear_reward_danger_step or 2)
    if routeAppliesToCurrentChapter and routeAppliesToCurrentChapter() then reward = reward * ((Game.routeMods and Game.routeMods.coin) or 1) end
    return math.max(1, math.floor(reward + 0.5))
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
    return (Balance.slot_spin_base or 8) + slotMilestone() * (Balance.slot_spin_wave_step or 1) + (Game.slotPaidSpins or 0) * (Balance.slot_spin_paid_step or 2)
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
        local keys = {"needle", "swarm", "molten", "echo", "coil", "void", "splitter", "acid", "frost", "drone"}
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
    {id = "kill", name = "清掉 22 个", short = "清敌", desc = "击杀 22 个敌人", target = 22, reward = function() Game.freeRefresh = (Game.freeRefresh or 0) + 1; return "免费刷新 +1" end},
    {id = "treasure", name = "打掉信标", short = "信标", desc = "击毁 1 个宝藏信标", target = 1, reward = function() addCoins(24, "objective"); return "材料 +24" end},
    {id = "elite", name = "干掉精英", short = "精英", desc = "击杀 1 个精英", target = 1, reward = function() addCoins(32, "objective"); return "材料 +32" end},
    {id = "nohit", name = "别挨打 10 秒", short = "无伤", desc = "连续 10 秒不受击", target = 10, reward = function() Game.player.maxShield = Game.player.maxShield + 16; Game.player.shield = math.min(Game.player.maxShield, Game.player.shield + 16); return "护盾上限 +16" end}
}

function rollSideObjective()
    local def = sideObjectiveDefs[rnd(1, #sideObjectiveDefs)]
    return {id = def.id, name = def.name, short = def.short or def.name, desc = def.desc, target = def.target, progress = 0, done = false, paid = false, reward = def.reward, timer = 0}
end

function objectiveTick(dt)
    local obj = Game.sideObjective
    if not obj or obj.done then return end
    if obj.id == "nohit" then
        obj.timer = (obj.timer or 0) + dt
        obj.progress = math.min(obj.target, obj.timer)
        if obj.timer >= obj.target then obj.done = true; toast("可选目标完成：" .. obj.name) end
    elseif (obj.progress or 0) >= (obj.target or 1) then
        obj.done = true
        toast("可选目标完成：" .. obj.name)
    end
end

function awardSideObjective()
    local obj = Game.sideObjective
    if obj and obj.done and not obj.paid and obj.reward then
        obj.paid = true
        local rewardText = obj.reward() or "奖励已发放"
        if Game.waveRewards then Game.waveRewards.objective = rewardText end
        toast("可选奖励：" .. rewardText)
    end
end

function addObjectiveProgress(kind, amount)
    local obj = Game.sideObjective
    if not obj or obj.done or obj.id ~= kind then return end
    obj.progress = (obj.progress or 0) + (amount or 1)
    if obj.progress >= obj.target then obj.done = true; toast("可选目标完成：" .. obj.name) end
end

dynamicEventPool = {
    {id = "ambush", name = "侧翼伏击"},
    {id = "treasure", name = "宝藏空投"},
    {id = "shield_convoy", name = "护盾车队"},
    {id = "repair_team", name = "维修小队"},
    {id = "rift_cut", name = "裂隙切场"},
    {id = "beacon_drop", name = "召唤信标"},
    {id = "element_surge", name = "元素涌动"},
    {id = "cryo_front", name = "寒潮前线"},
    {id = "rage_pack", name = "狂暴残群"}
}

function rollDynamicEvents(duration)
    if not dynamicEventPool or #dynamicEventPool == 0 then return {} end
    local ev = dynamicEventPool[rnd(1, #dynamicEventPool)]
    local event = {}
    for k, v in pairs(ev) do event[k] = v end
    local d = duration or currentSurvivalDuration()
    event.time = math.max(6, d * randf(0.46, 0.56))
    return {event}
end

startWave = function()
    local plan = currentWavePlan()
    if not plan.boss and not Game.preBattleEventArmed then
        beginEventChoice("战前随机事件", "prebattle")
        return
    end
    local preBattleEvent = Game.preBattleEventChoice
    Game.preBattleEventArmed = false
    Game.preBattleEventChoice = nil
    if plan.boss then
        Game.waveBossId = rollBossIdForWave(Game.wave)
        local boss = selectedBossDef()
        Game.waveBossName = boss and boss.name or "关底 Boss"
    else
        Game.waveBossId = nil
        Game.waveBossName = nil
    end
    Game.player.x, Game.player.y = Game.w / 2, Game.h / 2
    Game.player.lastMoveX, Game.player.lastMoveY = 0, -1
    Game.state = "playing"
    local waveDuration = plan.duration or smallWaveDurationAt(Game.wave)
    Game.waveTime = plan.boss and 0 or waveDuration
    Game.waveElapsed = 0
    Game.waveEventIndex = 1
    Game.bossDefeated = false
    Game.dynamicEvents = {}
    Game.dynamicEventIndex = 1
    Game.sideObjective = rollSideObjective()
    Game.waveStartKills = Game.kills
    Game.objectiveProgress = 0
    Game.objectiveText = plan.boss and "打爆 Boss" or ("撑住 " .. waveDuration .. " 秒")
    Game.enemies, Game.bullets, Game.pickups = {}, {}, {}
    Game.enemyShots, Game.fireZones, Game.beams = {}, {}, {}
    Game.pendingRewardNextState = nil
    Game.waveRewards = {wave = Game.wave, reason = "", kills = 0, coins = 0, clear = 0}
    local p = Game.player
    if plan.boss then
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        local earlyBoss = chapterIndex <= 3
        local intelPrep = routeAppliesToCurrentChapter and routeAppliesToCurrentChapter() and Game.routeMods and Game.routeMods.bossPrep
        local minHp = (p.maxHp or p.hp or 1) * (intelPrep and 0.82 or (earlyBoss and 0.85 or 0.62))
        local minShield = (p.maxShield or p.shield or 0) * (intelPrep and 1.00 or (earlyBoss and 1.00 or 0.75))
        if (p.hp or 0) < minHp then p.hp = minHp end
        if (p.shield or 0) < minShield then p.shield = minShield end
        toast(intelPrep and "Boss 情报整备：补给到位" or (earlyBoss and "Boss 前整备：教学保护" or "Boss 前整备：护盾补给"))
    end
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
    if preBattleEvent and preBattleEvent.apply then
        preBattleEvent.apply()
        Game.waveRewards.event = preBattleEvent.name
        toast("战前事件：" .. preBattleEvent.name)
    end
    Game.spawnTimer = 0.25
    Game.player.shieldDelay = 0
    local durationText = plan.boss and "Boss战" or (tostring(waveDuration) .. "秒")
    toast(chapterWaveLabel(Game.wave) .. "：" .. (plan.name or "战斗") .. " / " .. durationText .. " / " .. affixLabel() .. " / 可选 " .. (Game.sideObjective and Game.sideObjective.name or "无"))
end

local function enterShop()
    Game.state = "shop"
    Game.shopTab = "shop"
    Game.shopRefresh = 0
    rollShop(true)
    toast("商店开启：认真构筑")
end

local routeChoiceDefs = {
    {id = "safe", name = "稳定航线", desc = "下一章敌群压力降低，通关奖励略少。", risk = "奖励 -10%", mods = {enemyHp = 0.94, interval = 1.06, coin = 0.90}},
    {id = "danger", name = "高危航线", desc = "下一章敌群更密，通关奖励提高。", risk = "敌群 +1，奖励 +25%", mods = {extraPack = 1, interval = 0.94, coin = 1.25}},
    {id = "element", name = "元素航线", desc = "下一章元素敌与元素奖励更常见。", risk = "元素精英更容易出现", mods = {event = "element", elementReward = 0.18}},
    {id = "merchant", name = "商队航线", desc = "立刻获得材料和免费刷新，但下一章敌人稍硬。", risk = "敌人生命 +8%", mods = {coinNow = 45, freeRefresh = 1, enemyHp = 1.08}},
    {id = "bossIntel", name = "Boss 情报航线", desc = "下一章 Boss 前整备更好，普通关奖励略低。", risk = "普通清场奖励 -8%", mods = {bossPrep = 1, coin = 0.92}}
}

local function pickDistinct(defs, count)
    local pool, picked = {}, {}
    for _, def in ipairs(defs or {}) do pool[#pool + 1] = def end
    while #picked < math.min(count or 3, #pool) do
        local idx = rnd(1, #pool)
        picked[#picked + 1] = table.remove(pool, idx)
    end
    return picked
end

function routeAppliesToCurrentChapter()
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    return Game.routeMods and Game.routeMods.chapter == chapterIndex
end

local function chooseRoute(index)
    local choice = Game.routeChoices and Game.routeChoices[index]
    if not choice then return false end
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    local mods = {}
    for k, v in pairs(choice.mods or {}) do mods[k] = v end
    mods.id, mods.name, mods.chapter = choice.id, choice.name, chapterIndex
    Game.routeMods = mods
    Game.routeChoices = {}
    if mods.coinNow then addCoins(mods.coinNow, "route") end
    if mods.freeRefresh then Game.freeRefresh = (Game.freeRefresh or 0) + mods.freeRefresh end
    toast("路线选择：" .. choice.name)
    enterShop()
    return true
end

function beginRouteChoice()
    Game.routeChoices = pickDistinct(routeChoiceDefs, 3)
    Game.state = "route_choice"
    toast("Boss 已击破：选择下一章路线")
end

local eventChoiceDefs = {
    {id = "blackbox", name = "黑箱交易", desc = "立刻获得材料。", risk = "本章危险 +1", apply = function() addCoins(36 + Game.wave * 2, "event"); Game.danger = math.min(9, (Game.danger or 0) + 1) end},
    {id = "supply", name = "破损补给仓", desc = "获得免费刷新和护盾修复。", risk = "同时引来伏击", apply = function() Game.freeRefresh = (Game.freeRefresh or 0) + 1; Game.player.shield = math.min(Game.player.maxShield, Game.player.shield + 35); for _ = 1, 3 do spawnEnemy(enemyDefs.splinter, {side = pickSpawnSide(currentWavePlan()), scale = 0.86}) end end},
    {id = "rare", name = "异常商人", desc = "获得一笔材料并刷新商店。", risk = "本章敌人稍硬", apply = function() addCoins(28 + Game.wave, "event"); Game.routeMods = Game.routeMods or {}; Game.routeMods.chapter = select(4, chapterInfoAt(Game.wave)); Game.routeMods.enemyHp = math.max(Game.routeMods.enemyHp or 1, 1.06) end},
    {id = "beacon", name = "失控信标", desc = "摧毁信标可拿高奖励。", risk = "它会持续召唤护卫", apply = function() spawnEnemy(enemyDefs.beacon_summoner, {side = "top", scale = 1.05}); spawnEnemy(enemyDefs.treasure, {side = "top", scale = 1.0}) end},
    {id = "element", name = "元素风暴", desc = "本波元素伤害提高。", risk = "元素精英入场", apply = function() Game.player.waveElementChance = (Game.player.waveElementChance or 0) + 0.22; Game.player.waveElementDamageBonus = (Game.player.waveElementDamageBonus or 0) + 0.18; spawnEnemy(enemyDefs.element_elite, {side = pickSpawnSide(currentWavePlan()), scale = 0.86}) end},
    {id = "overclock", name = "临时超频", desc = "本波射速提高。", risk = "护盾回复暂时下降", apply = function() Game.player.waveFireRateBonus = (Game.player.waveFireRateBonus or 0) + 0.22; Game.player.waveShieldRegenMult = (Game.player.waveShieldRegenMult or 0) - 0.25 end}
}

function beginEventChoice(eventName, mode)
    Game.eventChoices = pickDistinct(eventChoiceDefs, 3)
    Game.eventChoiceTitle = eventName or "战前随机事件"
    Game.eventChoiceMode = mode or "prebattle"
    Game.state = "event_choice"
    toast("战前事件：先选择本波风险与回报")
end

local function chooseEvent(index)
    local choice = Game.eventChoices and Game.eventChoices[index]
    if not choice then return false end
    Game.eventChoices = {}
    if (Game.eventChoiceMode or "prebattle") == "prebattle" then
        Game.eventChoiceMode = nil
        Game.preBattleEventChoice = choice
        Game.preBattleEventArmed = true
        startWave()
        return true
    end
    if choice.apply then choice.apply() end
    Game.eventChoiceMode = nil
    Game.state = "playing"
    toast("事件选择：" .. choice.name)
    return true
end

local function choiceIndexAt(x, y, count)
    local n = count or 3
    local w, h, gap = 430, 250, 34
    local sx = Game.w / 2 - (w * n + gap * (n - 1)) / 2
    local sy = Game.h / 2 - h / 2 + 86
    for i = 1, n do
        if hitRect(x, y, sx + (i - 1) * (w + gap), sy, w, h) then return i end
    end
    return nil
end

local function resetRun()
    local ch = selectedCharacter()
    Game.time = 0
    Game.wave = 1
    Game.coins = ch.coins or 100
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
    Game.routeChoices = {}
    Game.eventChoices = {}
    Game.routeMods = {}
    Game.nextRouteMods = nil
    Game.runStats = {damage = 0, damageByWeapon = {}, coinsEarned = 0, highestWave = 1, rerolls = 0}
    if os.getenv("LOVE_AUTOPLAY_START_WAVE") then
        Game.wave = clamp(tonumber(os.getenv("LOVE_AUTOPLAY_START_WAVE")) or Game.wave, 1, Game.maxWave)
        Game.runStats.highestWave = Game.wave
    end
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
    Game.player.itemSlotLevel = 1
    Game.player.shieldItem = nil
    Game.player.gear = {}
    Game.tempBuffs = {}
    Game.shop, Game.locked = {}, {}
    addWeapon(weaponDefs[ch.weapon or "needle"])
    if rebuildPlayerBuildStats then rebuildPlayerBuildStats() end
    if autoplayApplyTestBuild then autoplayApplyTestBuild() end
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
    elseif nextState == "route" then
        beginRouteChoice()
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
    if e.boss then
        Game.bossDefeated = true
        Game.lastBossId = Game.waveBossId
        if Game.waveRewards then
            Game.waveRewards.bossTime = Game.waveElapsed or 0
            Game.waveRewards.bossRemaining = "0%"
        end
        toast("Boss 已打爆：" .. (e.name or "关底目标"))
    end
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
    if p.gear.elementSpread and e.lastElement and e.lastElement ~= "kinetic" then
        local dot = math.max(4, (e.burnDamage or e.shockDamage or e.corrosionDot or e.voidDamage or 4) * 0.55)
        for _, other in ipairs(Game.enemies) do
            if other ~= e and distance(e.x, e.y, other.x, other.y) < 135 then applyElementStatus(other, e.lastElement, dot, "元素羁绊扩散", 1.0) end
        end
        burst(e.x, e.y, (elements[e.lastElement] and elements[e.lastElement].color) or C.purple, 16, 160)
    end
    if p.gear.critRicochet and e.lastCrit then
        local other = nearestEnemy(e.x, e.y, 180)
        if other and other ~= e then damageEnemy(other, 24 * p.stats.damage, "kinetic", true, "暴击弹射") end
    end
    playCue(e.elite and "elite" or "pickup"); burst(e.x, e.y, e.color, e.boss and 44 or 12, e.boss and 260 or 150)
end

function elementStatusChance(weapon)
    if not weapon then return 0 end
    if weapon.element == "kinetic" and (weapon.statusChance or 0) <= 0 then return 0 end
    return clamp((weapon.statusChance or (weapon.element ~= "kinetic" and 0.22 or 0)) + ((Game.player and Game.player.stats and Game.player.stats.elementChance) or 0), 0, 0.85)
end

function elementStatusDamage(weapon)
    if not weapon then return 0 end
    if weapon.element == "kinetic" and (weapon.statusDamage or 0) <= 0 then return 0 end
    return math.max(0, math.floor((weapon.statusDamage or math.max(1, (weapon.damage or 0) * 0.35)) * ((Game.player and Game.player.stats and Game.player.stats.elementDamage) or 1) + 0.5))
end

function elementProcText(weapon)
    if not weapon then return "无元素附着" end
    local elem = elements[weapon.element] or elements.kinetic
    if weapon.element == "kinetic" and (weapon.statusChance or 0) <= 0 then return "动能直伤 · 无元素概率" end
    return elem.name .. "触发 " .. math.floor(elementStatusChance(weapon) * 100 + 0.5) .. "% · 异常伤害 " .. elementStatusDamage(weapon) .. "/s"
end

function applyElementStatus(e, elem, statusDamage, source, chance)
    if elem == "kinetic" then return false end
    local p = Game.player
    local procChance = chance
    if procChance ~= nil and procChance <= 0 then return false end
    if procChance == nil then procChance = 1 end
    procChance = clamp(procChance + ((p and p.stats and p.stats.elementChance) or 0), 0, 0.90)
    if rnd() > procChance then return false end
    local dot = math.max(1, statusDamage or 4)
    if elem == "burn" then
        e.burn = math.max(e.burn or 0, 3.2)
        e.burnDamage = math.max(e.burnDamage or 0, dot)
        addText(e.x, e.y - e.r - 12, "点燃", C.orange)
    elseif elem == "arc" then
        e.shock = math.max(e.shock or 0, 2.4)
        e.shockDamage = math.max(e.shockDamage or 0, dot)
        addText(e.x, e.y - e.r - 12, "触电", C.cyan)
        if (e.maxShield or 0) > 0 or (e.shield or 0) > 0 then
            for _, other in ipairs(Game.enemies or {}) do
                if other ~= e and distance(e.x, e.y, other.x, other.y) < 118 then damageEnemy(other, dot * 0.55, "arc", false, (source or "电击") .. "跳电", 0, 0) end
            end
        end
    elseif elem == "corrode" then
        e.corrosion = math.min((p and p.gear and p.gear.deepCorrode) and 9 or 6, (e.corrosion or 0) + 1)
        e.corrosionDot = math.max(e.corrosionDot or 0, dot * 0.62)
        addText(e.x, e.y - e.r - 12, "腐蚀易伤", C.green)
    elseif elem == "ice" then
        e.slow = math.max(e.slow or 0, 2.4)
        e.freeze = (e.freeze or 0) + 1
        if e.freeze >= 3 then
            e.frozen = math.max(e.frozen or 0, 1.05)
            e.freeze = 0
            addText(e.x, e.y - e.r - 12, "冻结", C.ice)
        else
            addText(e.x, e.y - e.r - 12, "霜冻", C.ice)
        end
    elseif elem == "void" then
        e.voidMark = math.max(e.voidMark or 0, 2.6)
        e.voidDamage = math.max(e.voidDamage or 0, dot)
        addText(e.x, e.y - e.r - 12, "坍缩", C.purple)
    end
    return true
end

function damageEnemy(e, amount, element, crit, source, statusChance, statusDamage)
    local p = Game.player
    local elem = element or "kinetic"
    local bonus = currentAffixBonuses()
    local elemMult = elem ~= "kinetic" and ((p.stats.elementDamage or 1) * (bonus.elementDamage or 1)) or 1
    local defenseMult = 1
    if e.shield and e.shield > 0 then
        defenseMult = elem == "arc" and 1.65 or 1
    elseif e.defense == "flesh" then
        defenseMult = elem == "burn" and 1.45 or 1
    end
    if elem == "corrode" then defenseMult = defenseMult * 1.08 end
    if (e.corrosion or 0) > 0 then defenseMult = defenseMult * (1 + math.min(8, e.corrosion or 0) * 0.055) end
    if elem ~= "kinetic" then defenseMult = defenseMult * (1 + (p.waveElementDamageBonus or 0)) end
    if e.damageTakenMult and e.damageTakenMult > 1 then defenseMult = defenseMult * e.damageTakenMult end
    if ((e.slow and e.slow > 0) or (e.frozen and e.frozen > 0)) and p.gear.freezeCrit then defenseMult = defenseMult * 1.18 end
    if e.frozen and e.frozen > 0 and crit then defenseMult = defenseMult * 1.18 end
    local armor = math.max(0, e.armor or 0)
    local dmg = math.max(1, amount * elemMult * defenseMult - armor)
    e.lastHit = 1.4
    e.lastCrit = crit
    e.lastElement = elem
    local hadShield = e.shield and e.shield > 0
    if e.shield and e.shield > 0 then
        local used = math.min(e.shield, dmg)
        e.shield = e.shield - used
        dmg = dmg - used
        if hadShield and e.shield <= 0 then
            e.shield = 0
            addText(e.x - 16, e.y - e.r - 24, "破盾", C.blue)
            burst(e.x, e.y, C.blue, 24, 220)
            if elem == "arc" then
                for _, other in ipairs(Game.enemies or {}) do
                    if other ~= e and distance(e.x, e.y, other.x, other.y) < 130 then damageEnemy(other, math.max(4, amount * 0.22), "arc", false, "破盾电爆", 0, 0) end
                end
            end
        end
    end
    if dmg > 0 then e.hp = e.hp - dmg end
    Game.runStats.damage = (Game.runStats.damage or 0) + dmg
    local src = source or "未知"
    Game.runStats.damageByWeapon[src] = (Game.runStats.damageByWeapon[src] or 0) + dmg
    if Game.player.stats.lifesteal > 0 and rnd() < Game.player.stats.lifesteal then Game.player.hp = math.min(Game.player.maxHp, Game.player.hp + 1) end
    addText(e.x, e.y - e.r, tostring(math.floor(dmg)) .. (crit and "!" or ""), crit and C.gold or elements[elem].color)
    applyElementStatus(e, elem, statusDamage, src, statusChance)
    if elem == "void" then
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
        statusChance = w.statusChance, statusDamage = w.statusDamage,
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
        local dead = damageEnemy(hit, hitDamage, elem, crit, w.name, w.statusChance, w.statusDamage)
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
                    local count = (w.count or 1) + (p.gear.extraProjectile or 0)
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
                local dead = damageEnemy(e, hitDamage, b.element, b.crit, b.source, b.statusChance, b.statusDamage)
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
                    if b.fireSplash and b.element == "burn" then igniteFireZone(e.x, e.y, math.min(110, (b.splash or 58) + 18), 2.8, math.max(4, hitDamage * 0.10), nil, nil, "燃烧残焰", false) end
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

local function damagePlayer(amount, source, sourceX, sourceY, sourceColor)
    local p = Game.player
    local skill = p.activeSkill
    if p.invuln > 0 or (skill and (skill.duration or 0) > 0) then return end
    if Game.sideObjective and Game.sideObjective.id == "nohit" and not Game.sideObjective.done then
        Game.sideObjective.timer = 0
        Game.sideObjective.progress = 0
    end
    p.invuln = 0.55
    p.shieldDelay = 2.4
    playCue("hit"); Game.shake = math.max(Game.shake or 0, 0.30)
    if p.gear and p.gear.highRiskCore then amount = amount * 1.12 end
    amount = math.max(1, amount)
    local rawAmount = amount
    local hitSource = source or "受击"
    Game.hitFlash = 0.42
    Game.lastHitSource = hitSource
    Game.lastHitColor = sourceColor or C.red
    if sourceX and sourceY then Game.lastHitAngle = angleTo(p.x, p.y, sourceX, sourceY) end
    local hadShield = p.shield > 0
    if p.shield > 0 then
        local used = math.min(p.shield, amount)
        p.shield = p.shield - used
        amount = amount - used
    end
    if amount > 0 then p.hp = p.hp - amount end
    local hitColor = amount > 0 and C.red or C.blue
    Game.lastHitDamage = math.ceil(rawAmount)
    addText(p.x - 44, p.y - p.r - 48, "-" .. tostring(math.ceil(rawAmount)) .. "  " .. hitSource, hitColor, {life = 1.05, scale = 1.28, font = Game.fonts.small})
    burst(p.x, p.y, hitColor, amount > 0 and 18 or 12, amount > 0 and 170 or 130)
    if hadShield and p.shield <= 0 then
        addText(p.x - 34, p.y - 42, "护盾破裂", C.blue)
        burst(p.x, p.y, C.blue, 24, 190)
        if p.gear.shieldBurst then
            for _, e in ipairs(Game.enemies) do
                if distance(p.x, p.y, e.x, e.y) < 165 then damageEnemy(e, 32 * p.stats.damage, "arc", false, "护盾脉冲") end
            end
            burst(p.x, p.y, C.blue, 38, 240)
        end
    end
    if p.hp <= 0 then Game.state = "gameover" end
end

local function fireEnemyShot(e, a, speed, radius, damageMult, colorOverride, sourceLabel)
    local spd = speed or 250
    Game.enemyShots[#Game.enemyShots + 1] = {x = e.x, y = e.y, vx = math.cos(a) * spd, vy = math.sin(a) * spd, r = radius or 6, damage = e.damage * (damageMult or 0.75), color = colorOverride or e.color, life = 3.0, source = sourceLabel or (e.boss and "Boss弹幕" or "敌弹")}
end

function igniteFireZone(x, y, radius, duration, damage, zoneColor, coreColor, label, hurtsPlayer)
    Game.fireZones = Game.fireZones or {}
    local outer = zoneColor or C.orange
    Game.fireZones[#Game.fireZones + 1] = {x = x, y = y, r = radius or 82, life = duration or 4.6, maxLife = duration or 4.6, damage = damage or 8, tick = 0, color = outer, coreColor = coreColor or C.red, label = label or (outer == C.purple and "封锁区" or "燃烧区"), hurtsPlayer = hurtsPlayer ~= false}
    burst(x, y, outer, 22, 220)
end

local function throwFireBomb(e, targetX, targetY)
    local travel = 0.85
    Game.enemyShots[#Game.enemyShots + 1] = {
        kind = "firebomb", x = e.x, y = e.y,
        targetX = targetX, targetY = targetY,
        vx = (targetX - e.x) / travel, vy = (targetY - e.y) / travel,
        r = 8, damage = e.damage * 0.65, color = C.orange, life = travel, source = "燃烧弹",
        zoneRadius = 86, zoneDuration = 4.8
    }
    addText(e.x, e.y - e.r - 10, "燃烧弹", C.orange)
end

local function bossPhaseLabel(e, phase)
    if e.phaseLabels and e.phaseLabels[phase] then return e.phaseLabels[phase] end
    return ({"校准射击", "裂隙封锁", "核心暴露"})[phase] or "失控"
end

local function setBossPhase(e, phase)
    if (e.bossPhase or 1) >= phase then return end
    e.bossPhase = phase
    e.bossPhaseName = bossPhaseLabel(e, phase)
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    local earlyBoss = currentWavePlan().boss and chapterIndex <= 3
    if phase == 2 then
        e.bossAttackTimer = earlyBoss and 1.35 or 0.55
        e.bossSpecialTimer = earlyBoss and 2.35 or 0.35
        e.shieldRegen = (e.shieldRegen or 0) * 0.50
        addText(e.x - 54, e.y - e.r - 30, "二阶段：" .. e.bossPhaseName, e.color or C.purple)
        toast((e.name or "Boss") .. " 二阶段：" .. e.bossPhaseName)
        burst(e.x, e.y, e.color or C.purple, 42, 280)
    elseif phase == 3 then
        e.bossAttackTimer = earlyBoss and 1.15 or 0.35
        e.bossSpecialTimer = earlyBoss and 2.10 or 0.25
        e.bossWeakTimer = earlyBoss and 4.6 or 3.8
        e.damageTakenMult = 1.42
        addText(e.x - 58, e.y - e.r - 34, "三阶段：" .. e.bossPhaseName, C.gold)
        toast((e.name or "Boss") .. " 三阶段：" .. e.bossPhaseName)
        burst(e.x, e.y, C.gold, 56, 320)
    end
end

local function spawnBossMinion(id, side, scale)
    if currentWavePlan().boss then
        local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
        if chapterIndex <= 3 then return end
    end
    local def = enemyDefs[id]
    if def then spawnEnemy(def, {side = side or pickSpawnSide(currentWavePlan()), scale = scale or 0.85}) end
end

local function bossTargetZone(e, radius, duration, damageMult, zoneColor, coreColor, label, lead, sideOffset)
    local p = Game.player
    local a = angleTo(e.x, e.y, p.x, p.y)
    local vx, vy = p.lastMoveX or math.cos(a), p.lastMoveY or math.sin(a)
    if math.abs(vx) + math.abs(vy) < 0.05 then vx, vy = math.cos(a), math.sin(a) end
    local px, py = -vy, vx
    e.bossZoneFlip = not e.bossZoneFlip
    local side = e.bossZoneFlip and 1 or -1
    local plan = currentWavePlan()
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    local introBoss = plan.boss and (Game.wave or 1) <= CHAPTER_SIZE
    local teachingBoss = plan.boss and chapterIndex <= 3
    local bossZoneRamp = plan.boss and clamp(0.28 + chapterIndex * 0.08, 0.38, 1.00) or 1
    local zoneRadius = (radius or 96) * (introBoss and 0.78 or 1)
    local zoneDuration = (duration or 4.2) * (introBoss and 0.55 or 1)
    local zoneDamage = (e.damage or 12) * (damageMult or 0.45) * bossZoneRamp * (teachingBoss and 0.16 or 1)
    local zx = clamp(p.x + vx * (lead or 112) + px * side * (sideOffset or 86), 96, Game.w - 96)
    local zy = clamp(p.y + vy * (lead or 112) + py * side * (sideOffset or 86), 178, Game.h - 90)
    igniteFireZone(zx, zy, zoneRadius, zoneDuration, math.max(teachingBoss and 0.5 or 5, zoneDamage), zoneColor or C.purple, coreColor or C.red, label or "压制区", not teachingBoss)
    addText(zx - 38, zy - zoneRadius - 14, label or "压制区", zoneColor or C.purple)
end

local function bossFanShot(e, a, count, spread, speed, radius, damageMult, c)
    local n = math.max(1, count or 3)
    local step = n > 1 and (spread or 0.36) / (n - 1) or 0
    local start = a - (step * (n - 1) / 2)
    for k = 0, n - 1 do
        fireEnemyShot(e, start + step * k, speed, radius, damageMult, c, e.boss and "Boss弹幕" or "敌弹")
    end
end

local function updateBossBehavior(e, dt, a, distToPlayer)
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    local earlyMidBoss = currentWavePlan().boss and chapterIndex <= 3
    local patternEase = earlyMidBoss and (chapterIndex == 2 and 1.26 or 1.12) or 1
    local patternDamageEase = earlyMidBoss and (chapterIndex == 2 and 0.76 or 0.88) or 1
    local hpPct = (e.hp or 0) / math.max(1, e.maxHp or e.hp or 1)
    if hpPct <= 0.35 then
        setBossPhase(e, 3)
    elseif hpPct <= 0.68 then
        setBossPhase(e, 2)
    end

    local phase = e.bossPhase or 1
    local pattern = e.bossPattern or "heartbreak"
    e.bossAttackTimer = (e.bossAttackTimer or 0) - dt
    e.bossSpecialTimer = (e.bossSpecialTimer or 2.4) - dt
    e.bossSummonTimer = (e.bossSummonTimer or 3.4) - dt
    e.bossWeakTimer = math.max(0, (e.bossWeakTimer or 0) - dt)
    e.damageTakenMult = e.bossWeakTimer > 0 and 1.42 or 1

    e.bossWanderTimer = (e.bossWanderTimer or 0) - dt
    if e.bossWanderTimer <= 0 then
        local centerAngle = angleTo(e.x, e.y, Game.w / 2, Game.h / 2)
        e.bossWanderAngle = centerAngle + randf(-0.85, 0.85)
        e.bossWanderTimer = randf(0.85, 1.45)
    end
    local moveAngle = e.bossWanderAngle or a
    local speedMult = 0.42 + phase * 0.06
    e.bossPhaseName = bossPhaseLabel(e, phase)

    if pattern == "forge" then
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 7 or 5, phase >= 2 and 0.86 or 0.58, 250 + phase * 18, 8, 0.58, C.orange)
            e.bossAttackTimer = phase >= 3 and 0.82 or 1.05
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 88 + phase * 10, 4.4, 0.56, C.orange, C.red, "熔炉线")
            e.bossSpecialTimer = randf(2.4, 3.1)
        end
    elseif pattern == "bulwark" then
        speedMult = speedMult * 0.72
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 5 or 3, 0.52, 230, 8, 0.50 * patternDamageEase, C.blue)
            e.bossAttackTimer = 1.18 * patternEase
        end
        if e.enteredArena and e.bossSummonTimer <= 0 then
            spawnBossMinion(phase >= 2 and "bulwark" or "wisp", pickSpawnSide(currentWavePlan()), (0.62 + phase * 0.08) * (earlyMidBoss and 0.82 or 1))
            e.bossSummonTimer = (phase >= 3 and 3.8 or 5.0) * patternEase
            addText(e.x - 38, e.y - e.r - 28, "护卫接入", C.blue)
        end
    elseif pattern == "hive" then
        speedMult = speedMult * 1.08
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 9 or 6, 1.18, 245 + phase * 12, 6, 0.44, C.green)
            e.bossAttackTimer = phase >= 3 and 0.78 or 1.02
        end
        if e.enteredArena and e.bossSummonTimer <= 0 then
            for _ = 1, phase + 1 do spawnBossMinion((rnd() < 0.55) and "splinter" or "drifter", pickSpawnSide(currentWavePlan()), 0.55 + phase * 0.06) end
            e.bossSummonTimer = phase >= 3 and 3.2 or 4.4
        end
    elseif pattern == "glacier" then
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 2 and 5 or 3, 0.70, 222, 8, 0.46 * patternDamageEase, C.ice)
            e.bossAttackTimer = (phase >= 3 and 0.92 or 1.20) * patternEase
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 94 + phase * 8, 4.8 * (earlyMidBoss and 0.82 or 1), 0.40 * patternDamageEase, C.ice, C.blue, "霜环")
            e.bossSpecialTimer = randf(2.8, 3.6) * patternEase
        end
    elseif pattern == "venom" then
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 6 or 4, 0.82, 238, 7, 0.48, C.green)
            e.bossAttackTimer = phase >= 3 and 0.88 or 1.10
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 104 + phase * 6, 5.2, 0.42, C.green, C.purple, "腐蚀云")
            e.bossSpecialTimer = randf(2.6, 3.4)
        end
    elseif pattern == "void" then
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 7 or 5, 0.96, 214 + phase * 16, 8, 0.52, C.purple)
            e.bossAttackTimer = phase >= 3 and 0.95 or 1.16
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            local pull = 0.045 + phase * 0.010
            Game.player.x = Game.player.x + (e.x - Game.player.x) * pull
            Game.player.y = Game.player.y + (e.y - Game.player.y) * pull
            bossTargetZone(e, 92 + phase * 12, 4.0, 0.46, C.purple, C.blue, "坍缩点", 80, 64)
            e.bossSpecialTimer = randf(3.0, 3.8)
        end
    elseif pattern == "rail" then
        speedMult = speedMult * 0.66
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 3 or 1, phase >= 3 and 0.32 or 0, 360 + phase * 40, 6, 0.86 * patternDamageEase, C.white)
            addText(e.x - 30, e.y - e.r - 24, "锁线", C.white)
            e.bossAttackTimer = (phase >= 3 and 0.74 or 1.12) * patternEase
        end
    elseif pattern == "reactor" then
        speedMult = speedMult * 0.78
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 10 or 6, 1.35, 230 + phase * 18, 8, 0.50, C.red)
            e.bossAttackTimer = phase >= 3 and 0.82 or 1.12
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            for k = 0, 7 do fireEnemyShot(e, k * TAU / 8, 210 + phase * 24, 8, 0.46, C.orange, "灾变泄压") end
            bossTargetZone(e, 116, 3.8, 0.52, C.red, C.orange, "泄压区", 68, 44)
            e.bossSpecialTimer = randf(3.1, 4.0)
        end
    elseif pattern == "reboot" then
        local mode = ({"heartbreak", "forge", "void"})[phase] or "heartbreak"
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 8 or 5, phase >= 3 and 1.04 or 0.72, 250 + phase * 22, 7, 0.54 * patternDamageEase, phase == 2 and C.orange or (phase == 3 and C.purple or C.gold))
            e.bossAttackTimer = (phase >= 3 and 0.82 or 1.05) * patternEase
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 96 + phase * 8, 4.2, 0.48 * patternDamageEase, mode == "forge" and C.orange or C.purple, C.red, phase == 2 and "协议过热" or "归零点")
            e.bossSpecialTimer = randf(2.8, 3.6) * patternEase
        end
    elseif pattern == "storm" then
        speedMult = speedMult * 1.08
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 8 or 5, phase >= 2 and 1.10 or 0.72, 278 + phase * 20, 6, 0.50, C.cyan)
            e.bossAttackTimer = phase >= 3 and 0.72 or 0.98
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            for _, other in ipairs(Game.enemies or {}) do
                if other ~= e and not other.boss and distance(e.x, e.y, other.x, other.y) < 280 then damageEnemy(other, math.max(6, (e.damage or 20) * 0.22), "arc", false, "电磁裁决", 0, 0) end
            end
            bossTargetZone(e, 88 + phase * 6, 3.6, 0.36, C.cyan, C.blue, "雷场")
            e.bossSpecialTimer = randf(2.6, 3.4)
        end
    elseif pattern == "mirror" then
        speedMult = speedMult * 1.18
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a + randf(-0.25, 0.25), phase >= 3 and 6 or 4, 0.82, 245 + phase * 22, 6, 0.44, C.purple)
            e.bossAttackTimer = phase >= 3 and 0.78 or 1.02
        end
        if e.enteredArena and e.bossSummonTimer <= 0 then
            for _ = 1, phase do spawnBossMinion(rnd() < 0.5 and "wisp" or "splinter", pickSpawnSide(currentWavePlan()), 0.50 + phase * 0.05) end
            addText(e.x - 32, e.y - e.r - 24, "残像", C.purple)
            e.bossSummonTimer = phase >= 3 and 3.2 or 4.5
        end
    elseif pattern == "reclaimer" then
        speedMult = speedMult * 0.62
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 5 or 3, 0.58, 218, 8, 0.42, C.gold)
            e.bossAttackTimer = 1.18
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            local heal = math.min((e.maxHp or e.hp) * 0.055, 95 + Game.wave * 4)
            e.hp = math.min(e.maxHp or e.hp, (e.hp or 0) + heal)
            e.shield = math.min(e.maxShield or 0, (e.shield or 0) + heal * 0.65)
            addText(e.x - 34, e.y - e.r - 28, "回收修复", C.gold)
            spawnBossMinion("treasure", pickSpawnSide(currentWavePlan()), 0.80)
            e.bossSpecialTimer = phase >= 3 and 5.4 or 6.8
        end
    elseif pattern == "minefield" then
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 6 or 4, 0.92, 232, 7, 0.46, C.orange)
            e.bossAttackTimer = phase >= 3 and 0.88 or 1.12
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            for n = 1, phase + 1 do bossTargetZone(e, 58 + phase * 8, 5.0, 0.42, C.orange, C.red, "地雷", randf(52, 140), randf(42, 118)) end
            e.bossSpecialTimer = randf(3.0, 4.0)
        end
    elseif pattern == "duelist" then
        speedMult = speedMult * 1.24
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 3 or 1, phase >= 3 and 0.22 or 0, 390 + phase * 48, 6, 0.76, C.red)
            addText(e.x - 28, e.y - e.r - 24, "决斗锁定", C.red)
            e.bossAttackTimer = phase >= 3 and 0.70 or 1.05
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            moveAngle = a
            speedMult = speedMult * (2.4 + phase * 0.28)
            e.bossSpecialTimer = randf(2.4, 3.2)
        end
    elseif pattern == "prism" then
        local colors = {C.red, C.cyan, C.green, C.ice, C.purple, C.gold}
        local c = colors[((Game.wave + phase + math.floor((Game.time or 0) * 0.6)) % #colors) + 1]
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 9 or 6, 1.22, 245 + phase * 18, 6, 0.44, c)
            e.bossAttackTimer = phase >= 3 and 0.82 or 1.04
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 82 + phase * 8, 3.8, 0.40, c, C.white, "分光区")
            e.bossSpecialTimer = randf(2.7, 3.5)
        end
    elseif pattern == "gravity" then
        speedMult = speedMult * 0.74
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 7 or 5, 0.96, 220 + phase * 14, 8, 0.50, C.purple)
            e.bossAttackTimer = phase >= 3 and 0.90 or 1.14
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            local pull = 0.060 + phase * 0.014
            Game.player.x = Game.player.x + (e.x - Game.player.x) * pull
            Game.player.y = Game.player.y + (e.y - Game.player.y) * pull
            bossTargetZone(e, 118 + phase * 8, 4.4, 0.44, C.purple, C.blue, "重力井", 60, 42)
            e.bossSpecialTimer = randf(3.0, 3.9)
        end
    elseif pattern == "stitcher" then
        speedMult = speedMult * 0.58
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 6 or 4, 0.82, 224, 8, 0.46, C.pink)
            e.bossAttackTimer = phase >= 3 and 0.96 or 1.20
        end
        if e.enteredArena and e.bossSummonTimer <= 0 then
            for _ = 1, phase + 1 do spawnBossMinion(rnd() < 0.5 and "drifter" or "rammer", pickSpawnSide(currentWavePlan()), 0.58 + phase * 0.06) end
            e.hp = math.min(e.maxHp or e.hp, (e.hp or 0) + math.min(60 + Game.wave * 3, (e.maxHp or e.hp) * 0.035))
            addText(e.x - 38, e.y - e.r - 28, "血肉缝合", C.pink)
            e.bossSummonTimer = phase >= 3 and 3.6 or 4.8
        end
    elseif pattern == "train" then
        speedMult = speedMult * (earlyMidBoss and 1.12 or 1.35)
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 5 or 3, 0.44, 300 + phase * 20, 7, 0.54 * patternDamageEase, C.ice)
            e.bossAttackTimer = (phase >= 3 and 0.78 or 1.06) * patternEase
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 72 + phase * 7, 3.2, 0.48 * patternDamageEase, C.ice, C.blue, "寒潮轨道", 150, 18)
            moveAngle = a
            speedMult = speedMult * (earlyMidBoss and 1.32 or 1.75)
            e.bossSpecialTimer = randf(2.8, 3.6) * patternEase
        end
    elseif pattern == "broadcast" then
        local c = phase == 1 and C.gold or (phase == 2 and C.cyan or C.red)
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 8 or 5, phase >= 3 and 1.08 or 0.76, 252 + phase * 20, 7, 0.50 * patternDamageEase, c)
            e.bossAttackTimer = (phase >= 3 and 0.78 or 1.00) * patternEase
        end
        if e.enteredArena and e.bossSpecialTimer <= 0 then
            if phase >= 2 then spawnBossMinion(rnd() < 0.5 and "bomber" or "wisp", pickSpawnSide(currentWavePlan()), (0.62 + phase * 0.05) * (earlyMidBoss and 0.82 or 1)) end
            bossTargetZone(e, 90 + phase * 8, 3.9 * (earlyMidBoss and 0.84 or 1), 0.44 * patternDamageEase, c, C.purple, phase >= 3 and "终焉倒放" or "串扰区")
            e.bossSpecialTimer = randf(2.8, 3.7) * patternEase
        end
    else
        if e.bossAttackTimer <= 0 then
            bossFanShot(e, a, phase >= 3 and 7 or (phase == 2 and 5 or 3), phase >= 3 and 1.02 or (phase == 2 and 0.74 or 0.44), 245 + phase * 18, 7, phase >= 3 and 0.58 or 0.64, phase == 2 and C.purple or C.red)
            e.bossAttackTimer = phase >= 3 and 0.92 or (phase == 2 and 1.05 or 1.25)
        end
        if phase >= 2 and e.enteredArena and e.bossSpecialTimer <= 0 then
            bossTargetZone(e, 104, 4.2, 0.45, C.purple, C.red, phase >= 3 and "弱点窗口" or "裂隙封锁")
            if phase >= 3 then e.bossWeakTimer = 2.4; e.damageTakenMult = 1.42 end
            e.bossSpecialTimer = phase >= 3 and 6.0 or randf(2.9, 3.5)
        end
    end

    if phase >= 3 and e.bossWeakTimer <= 0 and (pattern == "heartbreak" or pattern == "reboot") then
        e.bossPhaseName = bossPhaseLabel(e, phase) .. " / 失控齐射"
    end
    if distToPlayer < 190 then
        moveAngle = angleTo(Game.player.x, Game.player.y, e.x, e.y)
        speedMult = speedMult * 1.18
    end
    return moveAngle, speedMult
end
local function fireZoneDamageForChapter(baseDamage)
    local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
    local fireRamp = clamp(0.12 + chapterIndex * 0.05, 0.24, 1.00)
    return (baseDamage or 0) * fireRamp
end

function updateEnemyShots(dt)
    local p = Game.player
    for i = #Game.enemyShots, 1, -1 do
        local b = Game.enemyShots[i]
        b.life = b.life - dt
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        if b.kind == "firebomb" and b.life <= 0 then
            igniteFireZone(b.targetX or b.x, b.targetY or b.y, b.zoneRadius, b.zoneDuration, fireZoneDamageForChapter(b.damage), C.orange, C.red, "燃烧区")
            table.remove(Game.enemyShots, i)
        elseif distance(b.x, b.y, p.x, p.y) < b.r + p.r then
            damagePlayer(b.damage, b.source or (b.kind == "firebomb" and "燃烧弹" or "敌弹"), b.x, b.y, b.color)
            burst(b.x, b.y, b.color, 5, 80)
            if b.kind == "firebomb" then
                igniteFireZone(b.x, b.y, b.zoneRadius, b.zoneDuration, fireZoneDamageForChapter(b.damage), C.orange, C.red, "燃烧区")
            end
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
        if z.hurtsPlayer ~= false and distance(z.x, z.y, p.x, p.y) < z.r + p.r * 0.35 and z.tick <= 0 then
            damagePlayer(z.damage or 6, z.label or "危险区域", z.x, z.y, z.color)
            z.tick = 0.45
        end
        if z.life <= 0 then table.remove(Game.fireZones, i) end
    end
end

function updateDroneSwarm(dt)
    local p = Game.player
    if not (p.gear and p.gear.droneSwarm) then return end
    p.droneTimer = (p.droneTimer or 0) - dt
    if p.droneTimer > 0 then return end
    p.droneTimer = p.gear.droneSplit and 0.82 or 1.08
    local target = nearestEnemy(p.x, p.y, 680)
    if not target then return end
    for i = -1, 1 do
        local a = angleTo(p.x, p.y, target.x, target.y) + i * 0.18
        Game.bullets[#Game.bullets + 1] = {
            x = p.x + i * 12, y = p.y - 18, vx = math.cos(a) * 560, vy = math.sin(a) * 560,
            r = 4, damage = 6 * p.stats.damage, element = p.waveElement or "arc", range = 720,
            traveled = 0, life = 2.4, pierce = 0, bounce = 0, color = elements[p.waveElement or "arc"].color, sprite = "projectile_swarm_missile", crit = false, target = target, source = "支援无人机", brand = "drone",
            hiveSplit = p.gear.droneSplit, statusChance = 0.22, statusDamage = 4
        }
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
            e.hp = e.hp - (e.burnDamage or 5) * dt
        end
        if e.shock and e.shock > 0 then
            e.shock = e.shock - dt
            e.hp = e.hp - (e.shockDamage or 4) * dt
        end
        if e.corrosionDot and e.corrosionDot > 0 then e.hp = e.hp - e.corrosionDot * dt end
        if e.slow and e.slow > 0 then e.slow = e.slow - dt end
        if e.frozen and e.frozen > 0 then e.frozen = e.frozen - dt end
        if e.voidMark and e.voidMark > 0 then
            e.voidMark = e.voidMark - dt
            if e.voidMark <= 0 then
                damageEnemy(e, e.voidDamage or 8, "void", false, "虚空坍缩", 0, 0)
                burst(e.x, e.y, C.purple, 18, 170)
            end
        end
        local spd = e.speed * ((e.frozen and e.frozen > 0) and 0.08 or (((e.slow and e.slow > 0) and 0.58 or 1)))
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
        elseif behavior == "fireline" then
            e.zoneTimer = (e.zoneTimer or randf(0.8, 1.4)) - dt
            if e.enteredArena and e.zoneTimer <= 0 then
                igniteFireZone(e.x, e.y, e.zoneRadius or 64, e.zoneDuration or 2.7, fireZoneDamageForChapter(e.zoneDamage or math.max(3, (e.damage or 8) * 0.42)), C.orange, C.red, "火线")
                e.zoneTimer = randf((e.zoneCooldown or 2.2) * 0.85, (e.zoneCooldown or 2.2) * 1.15)
            end
            moveAngle = randomWanderAngle(e, dt, 0.45, 0.95, a, 0.64)
            spd = spd * (e.enteredArena and 0.86 or 1.12)
        elseif behavior == "zoner" or behavior == "rift_zoner" then
            e.zoneTimer = (e.zoneTimer or randf(0.8, 1.6)) - dt
            if e.enteredArena and distToPlayer < 720 and e.zoneTimer <= 0 then
                local mx, my = p.lastMoveX or 0, p.lastMoveY or -1
                if math.abs(mx) + math.abs(my) < 0.05 then mx, my = math.cos(a), math.sin(a) end
                local px, py = -my, mx
                e.zoneFlip = not e.zoneFlip
                local side = e.zoneFlip and 1 or -1
                local isRift = behavior == "rift_zoner"
                local lead = isRift and randf(42, 86) or randf(72, 132)
                local offset = side * (isRift and randf(28, 68) or randf(56, 104))
                local zx = clamp(p.x + mx * lead + px * offset, 88, Game.w - 88)
                local zy = clamp(p.y + my * lead + py * offset, 172, Game.h - 88)
                local label = isRift and "裂隙" or "封锁区"
                igniteFireZone(zx, zy, e.zoneRadius or (isRift and 68 or 96), e.zoneDuration or (isRift and 3.2 or 4.8), e.zoneDamage or math.max(4, (e.damage or 8) * 0.55), C.purple, isRift and C.blue or C.red, label)
                addText(zx - 34, zy - (e.zoneRadius or 96) - 14, label, C.purple)
                e.zoneTimer = randf((e.zoneCooldown or 3.5) * 0.85, (e.zoneCooldown or 3.5) * 1.18)
            end
            moveAngle = randomWanderAngle(e, dt, 0.70, 1.45, a, behavior == "rift_zoner" and 0.50 or 0.58)
            spd = spd * (e.enteredArena and (behavior == "rift_zoner" and 0.56 or 0.50) or 0.96)
        elseif behavior == "shield_amp" then
            e.ampTimer = (e.ampTimer or 0.6) - dt
            if e.enteredArena and e.ampTimer <= 0 then
                for _, other in ipairs(Game.enemies or {}) do
                    if other ~= e and not other.boss and distance(e.x, e.y, other.x, other.y) < 190 then
                        other.maxShield = math.max(other.maxShield or 0, 18 + Game.wave * 1.6)
                        other.shield = math.min(other.maxShield, (other.shield or 0) + 12 + Game.wave * 0.5)
                    end
                end
                addText(e.x - 30, e.y - e.r - 14, "护盾放大", C.blue)
                e.ampTimer = 1.25
            end
            moveAngle = randomWanderAngle(e, dt, 0.65, 1.35, a, 0.62)
            spd = spd * (e.enteredArena and 0.50 or 1.00)
        elseif behavior == "cryo_jammer" then
            if e.enteredArena and distToPlayer < 230 then
                p.waveVoidSlowTimer = math.max(p.waveVoidSlowTimer or 0, 0.32)
                e.jammerTextTimer = (e.jammerTextTimer or 0) - dt
                if e.jammerTextTimer <= 0 then addText(e.x - 28, e.y - e.r - 12, "冰霜干扰", C.ice); e.jammerTextTimer = 1.1 end
            end
            moveAngle = randomWanderAngle(e, dt, 0.60, 1.25, a, 0.55)
            spd = spd * (e.enteredArena and 0.58 or 1.02)
        elseif behavior == "repair_drone" then
            e.repairTimer = (e.repairTimer or 0.8) - dt
            if e.enteredArena and e.repairTimer <= 0 then
                local target, missing = nil, 0
                for _, other in ipairs(Game.enemies or {}) do
                    local miss = (other.maxHp or other.hp or 0) - (other.hp or 0)
                    if other ~= e and miss > missing and distance(e.x, e.y, other.x, other.y) < 260 then target, missing = other, miss end
                end
                if target then
                    local heal = math.min(missing, 18 + Game.wave * 1.4)
                    target.hp = math.min(target.maxHp or target.hp, (target.hp or 0) + heal)
                    addText(target.x - 18, target.y - target.r - 18, "+" .. math.floor(heal) .. " 修复", C.gold)
                    burst(target.x, target.y, C.gold, 8, 110)
                end
                e.repairTimer = 1.25
            end
            moveAngle = randomWanderAngle(e, dt, 0.42, 1.00, a, 0.48)
            spd = spd * (e.enteredArena and 0.72 or 1.15)
        elseif behavior == "beacon_summoner" then
            e.summonTimer = (e.summonTimer or randf(1.2, 2.0)) - dt
            if e.enteredArena and e.summonTimer <= 0 then
                addText(e.x - 32, e.y - e.r - 16, "召唤读条", C.purple)
                local count = Game.wave >= 12 and 3 or 2
                for _ = 1, count do spawnEnemy(rnd() < 0.55 and enemyDefs.splinter or enemyDefs.drifter, {side = pickSpawnSide(currentWavePlan()), scale = 0.58}) end
                e.summonTimer = randf(4.2, 5.4)
            end
            moveAngle = randomWanderAngle(e, dt, 0.80, 1.60, a, 0.46)
            spd = spd * (e.enteredArena and 0.42 or 0.96)
        elseif behavior == "element_elite" then
            e.shootTimer = (e.shootTimer or 0) - dt
            local elem = e.elementKind or "arc"
            if distToPlayer < 600 and e.shootTimer <= 0 then
                fireEnemyShot(e, a, 245, 7, 0.64, (elements[elem] and elements[elem].color) or e.color, "元素弹幕")
                e.shootTimer = randf(1.25, 1.75)
            end
            moveAngle = randomWanderAngle(e, dt, 0.55, 1.25, a, 0.50)
            spd = spd * (e.enteredArena and 0.70 or 1.06)
        elseif behavior == "dual_guard" then
            spd = spd * 0.58
            e.armor = math.max(e.armor or 0, 4 + math.floor(Game.wave / 4))
        elseif behavior == "berserker" then
            local pct = (e.hp or 0) / math.max(1, e.maxHp or e.hp or 1)
            if pct < 0.40 then
                if not e.enraged then e.enraged = true; addText(e.x - 24, e.y - e.r - 16, "狂暴", C.red); burst(e.x, e.y, C.red, 14, 150) end
                spd = spd * 1.72
                e.damage = math.max(e.damage or 0, (e.baseDamage or e.damage or 0) * 1.22)
            end
        elseif behavior == "charger" then
            e.dashTimer = (e.dashTimer or 0) - dt
            if e.dashTimer <= 0 and distToPlayer < 360 then
                spd = spd * 2.4
                e.dashTimer = 2.2
                addText(e.x, e.y - e.r - 8, "突进", C.orange)
            end
        elseif behavior == "rammer" or behavior == "rail_charger" then
            local rail = behavior == "rail_charger"
            e.chargeCooldown = math.max(0, (e.chargeCooldown or randf(0.4, 1.2)) - dt)
            if e.chargeState == "windup" then
                e.chargeTimer = (e.chargeTimer or 0) - dt
                moveAngle = e.chargeAngle or a
                spd = spd * 0.10
                if e.chargeTimer <= 0 then
                    e.chargeState = "dash"
                    e.chargeTimer = e.chargeDashTime or (rail and 0.52 or 0.44)
                    addText(e.x, e.y - e.r - 10, rail and "磁轨冲锋" or "冲锋", rail and C.cyan or C.red)
                end
            elseif e.chargeState == "dash" then
                e.chargeTimer = (e.chargeTimer or 0) - dt
                moveAngle = e.chargeAngle or a
                spd = spd * (e.chargeSpeedMult or (rail and 4.9 or 4.4))
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
                e.chargeTimer = rail and 0.92 or 0.74
                e.chargeAngle = a
                e.chargeWarnLength = clamp(distToPlayer + (rail and 220 or 160), 260, rail and 620 or 520)
                spd = 0
                addText(e.x, e.y - e.r - 10, rail and "磁轨锁线" or "蓄力", rail and C.cyan or C.red)
            else
                moveAngle = randomWanderAngle(e, dt, 0.60, 1.20, a, 0.42)
                spd = spd * (e.enteredArena and 0.82 or 1.12)
            end
        elseif behavior == "guard" then
            spd = spd * 0.78
            e.armor = math.max(e.armor or 0, 3 + math.floor(Game.wave / 3))
        elseif behavior == "aura" and distToPlayer < 135 then
            damagePlayer(e.damage * 0.22, "燃烧光环", e.x, e.y, e.color)
        elseif behavior == "boss" then
            moveAngle, spd = updateBossBehavior(e, dt, a, distToPlayer)
        end
        if not e.enteredArena then spd = spd * (e.boss and 3.4 or (e.elite and 2.5 or 1.7)) end
        e.x = e.x + math.cos(moveAngle) * spd * dt
        e.y = e.y + math.sin(moveAngle) * spd * dt
        markAndClampEnemyArena(e)
        if distance(e.x, e.y, p.x, p.y) < e.r + p.r then
            local chargingHit = (e.behavior == "rammer" or e.behavior == "rail_charger") and e.chargeState == "dash"
            if (e.damage or 0) > 0 then damagePlayer(e.damage * (chargingHit and 1.45 or 1), chargingHit and (e.behavior == "rail_charger" and "磁轨冲锋" or "冲锋撞击") or "敌人碰撞", e.x, e.y, e.color) end
            if chargingHit then e.chargeState = "recover"; e.chargeTimer = 0.72; e.chargeCooldown = 1.4 end
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
    if os.getenv("LOVE_AUTOPLAY_RECORD") == "1" and Game.autoplayMove then
        dx, dy = Game.autoplayMove.x or 0, Game.autoplayMove.y or 0
    end
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
        p.shield = math.min(p.maxShield, p.shield + p.shieldRegen * bonus.shieldRegenMult * math.max(0.20, 1 + (p.waveShieldRegenMult or 0)) * dt)
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
    if finishedWave % CHAPTER_SIZE == 0 and finishedWave < (Game.maxWave or CAMPAIGN_WAVES) then
        p.hp = math.max(p.hp or 0, (p.maxHp or p.hp or 1) * 0.72)
        p.shield = math.max(p.shield or 0, (p.maxShield or p.shield or 0) * 0.85)
        if Game.waveRewards then Game.waveRewards.chapterRepair = "章节整备" end
    end
    if autoplayCaptureWave then autoplayCaptureWave(summary) end
    Game.lastWaveIncome = (Game.waveRewards and Game.waveRewards.coins) or base
    generateLevelChoices()
    if Game.wave >= Game.maxWave then
        Game.pendingRewardNextState = "victory"
        Game.state = "levelup"
        return
    end
    local routeAfterReward = finishedWave % CHAPTER_SIZE == 0
    Game.wave = Game.wave + 1
    Game.runStats.highestWave = math.max(Game.runStats.highestWave or 1, Game.wave)
    Game.pendingRewardNextState = routeAfterReward and "route" or "shop"
    Game.state = "levelup"
end

local function completeWave(reason)
    if Game.state == "clearing" then return end
    Game.clearTransition = {reason = reason or "波次完成", timer = 0, pulse = 0.06}
    Game.state = "clearing"
    Game.objectiveText = "目标完成 · 清场中"
    Game.enemyShots, Game.bullets, Game.fireZones = {}, {}, {}
    Game.spawnTimer = 999
    Game.shake = math.max(Game.shake or 0, 0.36)
    playCue("elite")
    burst(Game.player.x, Game.player.y, C.cyan, 22, 210)
    toast("目标完成：清场")
end

local function updateWaveClear(dt)
    local t = Game.clearTransition
    if not t then finalizeWaveReward("波次完成"); return end
    t.timer = (t.timer or 0) + dt
    t.pulse = (t.pulse or 0) - dt
    Game.objectiveText = "目标完成 · 清场中"
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
        local eventDef = event.enemy == "boss" and selectedBossDef() or (enemyDefs[event.enemy] or weightedEnemy(plan))
        spawnEnemy(eventDef, {side = event.side, scale = event.enemy == "boss" and 1 or 1.08})
        if event.toast then toast(event.enemy == "boss" and ("目标：打爆 " .. (Game.waveBossName or "Boss")) or event.toast) end
        Game.waveEventIndex = Game.waveEventIndex + 1
    end
    objectiveTick(dt)

    Game.spawnTimer = (Game.spawnTimer or 0) - dt
    if Game.spawnTimer <= 0 and not (plan.boss and Game.waveElapsed < 4) then
        spawnPack(plan)
        local pressure = math.max(0, Game.waveElapsed / math.max(1, plan.duration or currentSurvivalDuration()))
        local bonus = currentAffixBonuses()
        local curve = survivalEnemyCurve()
        local interval = ((plan.interval or 1.0) * bonus.intervalMult * curve.interval) - pressure * 0.10
        if plan.boss then
            local _, _, _, chapterIndex = chapterInfoAt(Game.wave)
            interval = interval * clamp(2.10 - chapterIndex * 0.12, 1.22, 1.90)
        end
        Game.spawnTimer = math.max(0.38, interval)
    end
    updatePlayer(dt)
    updateWeapons(dt)
    updateAutoArc(dt)
    updateDroneSwarm(dt)
    updateBullets(dt)
    updateEnemyShots(dt)
    updateFireZones(dt)
    updateEnemies(dt)

    local obj = Game.sideObjective
    local extra = obj and (" · 可选 " .. obj.name .. " " .. math.floor(obj.progress or 0) .. "/" .. obj.target) or ""
    if plan.boss then
        local boss
        for _, e in ipairs(Game.enemies or {}) do if e.boss then boss = e; break end end
        if boss then
            local pct = math.max(0, math.ceil((boss.hp / math.max(1, boss.maxHp or boss.hp)) * 100))
            local phase = boss.bossPhaseName and (" · " .. boss.bossPhaseName) or ""
            Game.objectiveText = "打爆 Boss" .. phase .. " · " .. pct .. "%" .. extra
        else
            Game.objectiveText = (Game.bossDefeated and "Boss 已打爆" or "打爆 Boss") .. extra
        end
        if Game.bossDefeated and Game.state == "playing" then completeWave("Boss击破") end
    else
        local remain = math.max(0, math.ceil(Game.waveTime))
        Game.objectiveText = "撑住 " .. math.floor(remain / 60) .. ":" .. string.format("%02d", remain % 60) .. extra
        if Game.waveTime <= 0 and Game.state == "playing" then
            Game.waveTime = 0
            completeWave(Game.wave >= Game.maxWave and "通关完成" or "敌群清完")
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
    Game.fonts = {tiny = uiFont(19), subtitle = uiFont(22), small = uiFont(24), normal = uiFont(31), timer = uiFont(44), big = uiFont(50), title = uiFont(84)}
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

function autoplayRecordEnabled()
    return os.getenv("LOVE_AUTOPLAY_RECORD") == "1"
end

function autoplayRecordPath()
    return os.getenv("LOVE_AUTOPLAY_RECORD_PATH") or "autoplay-playtest.md"
end

function love.errorhandler(msg)
    if autoplayRecordEnabled and autoplayRecordEnabled() then
        local trace = debug and debug.traceback and debug.traceback(tostring(msg), 2) or tostring(msg)
        local path = autoplayRecordPath and autoplayRecordPath() or "autoplay-playtest.md"
        local f = io.open(path, "a")
        if f then
            f:write("\n## 自动跑局错误\n\n```\n" .. trace .. "\n```\n")
            f:close()
        end
        io.stderr:write(trace .. "\n")
        return function() love.event.quit(1) end
    end
    return msg
end

function autoplayLine(text)
    if not autoplayRecordEnabled() then return end
    local path = autoplayRecordPath()
    local mode = Game.autoplayLogStarted and "a" or "w"
    local f = io.open(path, mode)
    if not f then return end
    if not Game.autoplayLogStarted then
        f:write("# Robot War 自动跑局记录\n\n")
        f:write("> 自动记录模式：LOVE_AUTOPLAY_RECORD=1。该结果来自简单自动驾驶策略，不等同于人工完整通关。\n\n")
        f:write("- 版本：" .. VERSION .. "\n")
        f:write("- 目标波次：" .. tostring(tonumber(os.getenv("LOVE_AUTOPLAY_TARGET_WAVE")) or 12) .. "\n")
        f:write("- 难度：" .. tostring(Game.danger or 0) .. "\n\n")
        f:write("## 波次结果\n\n")
        f:write("| Wave | 结果 | Boss | Boss耗时 | Boss剩余 | 击杀 | 收入 | 结束生命 | 结束护盾 | 结算后材料 | 构筑 |\n")
        f:write("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n")
        Game.autoplayLogStarted = true
    end
    f:write(text .. "\n")
    f:close()
end

function autoplayBuildText()
    local p = Game.player or {}
    local weapons = {}
    for _, w in ipairs(p.weapons or {}) do weapons[#weapons + 1] = w.name or "武器" end
    local synergies = p.synergies and #p.synergies or 0
    return table.concat(weapons, "/") .. "; 模块 " .. tostring(#(p.items or {})) .. "/" .. tostring(p.itemSlots or ITEM_SLOT_BASE) .. "; 联动 " .. tostring(synergies)
end

function autoplayTestModule(name, key, desc, apply)
    return {kind = "mod", rarity = "test", level = Game.wave or 1, mergeKey = key, name = name, price = 0, desc = desc, apply = apply}
end

function autoplayApplyTestBuild()
    local build = os.getenv("LOVE_AUTOPLAY_TEST_BUILD") or ""
    if build == "" or Game.autoplayTestBuildApplied then return end
    local p = Game.player
    Game.autoplayTestBuildApplied = true
    if build ~= "balanced" then
        toast("未知测试构筑：" .. build)
        return
    end
    p.weapons = {}
    addWeapon(weaponDefs.needle)
    addWeapon(weaponDefs.swarm)
    addWeapon(weaponDefs.echo)
    addWeapon(weaponDefs.coil)
    p.itemSlotLevel = 4
    p.itemSlots = math.min(ITEM_SLOT_MAX, ITEM_SLOT_BASE + p.itemSlotLevel - 1)
    p.speed = p.speed + 90
    p.invuln = math.max(p.invuln or 0, tonumber(os.getenv("LOVE_AUTOPLAY_TEST_INVULN")) or 999)
    for _, weapon in ipairs(p.weapons or {}) do
        weapon.damage = math.floor((weapon.damage or 1) * 1.85 + 0.5)
        weapon.cooldown = math.max(0.12, (weapon.cooldown or 1) * 0.72)
        weapon.range = (weapon.range or 500) * 1.10
    end
    p.shieldItem = {kind = "shield", rarity = "test", level = Game.wave or 1, name = "测试护盾阵列", price = 0, desc = "自动跑局测试：护盾 +240 / 回复 +15.0 / 满盾增伤", shieldCap = 240, shieldRegen = 15.0, hp = 120, flag = "fullShieldDamage"}
    p.items = {
        autoplayTestModule("测试火控模块", "fire_control", "伤害 +180% / 暴击 +25%", function(player) player.stats.damage = player.stats.damage + 1.80; player.stats.crit = player.stats.crit + 0.25 end),
        autoplayTestModule("测试脉冲模块", "pulse_drive", "射速 +130% / 弹速 +36%", function(player) player.stats.fireRate = player.stats.fireRate + 1.30; player.stats.projectileSpeed = player.stats.projectileSpeed + 0.36 end),
        autoplayTestModule("测试元素模块", "element_core", "元素 +75% / 附着 +14%", function(player) player.stats.elementDamage = player.stats.elementDamage + 0.75; player.stats.elementChance = player.stats.elementChance + 0.14 end),
        autoplayTestModule("测试回收模块", "recycle_core", "结算材料 +30% / 拾取 +32", function(player) player.stats.economy = player.stats.economy + 0.30; player.pickup = player.pickup + 32 end),
        autoplayTestModule("测试维生模块", "survival_core", "生命 +180 / 吸血 +8%", function(player) player.maxHp = player.maxHp + 180; player.hp = player.hp + 180; player.stats.lifesteal = player.stats.lifesteal + 0.08 end)
    }
    rebuildPlayerBuildStats()
    p.hp = p.maxHp
    p.shield = p.maxShield
    Game.coins = math.max(Game.coins or 0, tonumber(os.getenv("LOVE_AUTOPLAY_TEST_COINS")) or 160)
    autoplayLine("\n## 测试构筑\n\n- 构筑：balanced\n- 起始波次：" .. tostring(Game.wave or 1) .. "\n- 初始材料：" .. tostring(Game.coins or 0) .. "\n- 内容：星针 / 蜂群发射器 / 回声刃 / 电弧线圈，测试护盾阵列，5 个测试模块。\n")
    toast("自动跑局测试构筑：balanced")
end

function autoplayCaptureWave(summary)
    if not autoplayRecordEnabled() then return end
    local p = Game.player or {}
    local bossName = Game.waveBossName or "-"
    local bossTime = summary.bossTime and (string.format("%.1fs", summary.bossTime)) or "-"
    local bossRemaining = summary.bossRemaining or (bossName ~= "-" and "0%" or "-")
    autoplayLine("| " .. tostring(summary.wave or Game.wave) .. " | " .. tostring(summary.reason or "完成") .. " | " .. bossName .. " | " .. bossTime .. " | " .. bossRemaining .. " | " .. tostring(summary.kills or 0) .. " | " .. tostring(summary.coins or 0) .. " | " .. tostring(math.ceil(p.hp or 0)) .. "/" .. tostring(p.maxHp or 0) .. " | " .. tostring(math.ceil(p.shield or 0)) .. "/" .. tostring(p.maxShield or 0) .. " | " .. tostring(Game.coins or 0) .. " | " .. autoplayBuildText() .. " |")
end

function autoplayBossProgress(e)
    if not e then return "-" end
    local hpPct = math.max(0, math.ceil(((e.hp or 0) / math.max(1, e.maxHp or e.hp or 1)) * 100))
    local shieldPct = (e.maxShield or 0) > 0 and (" / 护盾" .. tostring(math.max(0, math.ceil(((e.shield or 0) / math.max(1, e.maxShield or 1)) * 100))) .. "%") or ""
    return tostring(hpPct) .. "%" .. shieldPct
end

function autoplayNearestEnemy()
    local p = Game.player
    local best, bestD = nil, 999999
    for _, e in ipairs(Game.enemies or {}) do
        local d = distance(p.x, p.y, e.x, e.y)
        if d < bestD then best, bestD = e, d end
    end
    return best, bestD
end

function autoplaySetMove()
    local p = Game.player
    local e, d = autoplayNearestEnemy()
    local dx, dy = 0, 0
    if e and d < 360 then
        dx, dy = p.x - e.x, p.y - e.y
    else
        local t = love.timer.getTime() or 0
        local radius = 250
        local tx = Game.w / 2 + math.cos(t * 0.70) * radius
        local ty = Game.h / 2 + math.sin(t * 0.70) * radius
        dx, dy = tx - p.x, ty - p.y
    end
    if math.abs(dx) + math.abs(dy) > 0.01 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end
    Game.autoplayMove = {x = dx, y = dy}
    local skill = p.activeSkill
    if e and d < 130 and skill and (skill.cd or 0) <= 0 then useActiveSkill() end
end

function autoplayShopSummary(cleared)
    local affordable, names = 0, {}
    for i, item in ipairs(Game.shop or {}) do
        if item and Game.coins >= (item.price or 0) then
            affordable = affordable + 1
            names[#names + 1] = (item.name or "商品") .. "@" .. tostring(item.price or 0)
        end
    end
    local slotCost = itemSlotUpgradeCost()
    local slotText = slotCost and ((Game.coins >= slotCost and "可升级槽位@" or "缺材料槽位@") .. slotCost) or "槽位满级"
    autoplayLine("\n### Wave " .. tostring(cleared) .. " 后商店\n\n- 材料：" .. tostring(Game.coins or 0) .. "\n- 可购买商品：" .. tostring(affordable) .. "（" .. (#names > 0 and table.concat(names, " / ") or "无") .. "）\n- 转轮成本：" .. tostring(slotSpinCost()) .. "；" .. slotText .. "\n")
end

function autoplayShouldBuy(item)
    if not item then return false end
    if (os.getenv("LOVE_AUTOPLAY_TEST_BUILD") or "") ~= "" then
        -- 专用测试构筑固定武器/护盾；购物只补模块/战术，避免替换掉测试基线。
        return isPermanentModule(item) or item.kind == "temp"
    end
    return true
end

function autoplayWeaponPower(def, profile)
    if not def then return 0 end
    profile = profile or waveThreatProfile((Game.wave or 1) + 1)
    local total = (def.damage or 0) * math.max(1, def.count or 1)
    local score = 120 + total * 4 + (def.range or 0) * 0.05
    if profile.boss > 0 then score = score + total * 5 end
    if (profile.shield or 0) >= 18 and def.element == "arc" then score = score + 210 end
    if (profile.armor or 0) >= 16 and (def.element == "acid" or def.element == "burn") then score = score + 160 end
    if (profile.fire or 0) >= 3 and (def.range or 0) >= 720 then score = score + 95 end
    if def.brand == "drone" or def.hiveSplit then score = score + 70 end
    if def.pierce and def.pierce > 0 then score = score + def.pierce * 35 end
    if def.bounce and def.bounce > 0 then score = score + def.bounce * 30 end
    score = score + ((rarityPower and rarityPower[def.rarity]) or 1) * 18 + (def.level or 1) * 9
    return score
end

function autoplayWeakestWeapon(profile)
    local p = Game.player or {}
    local weakestIndex, weakestWeapon, weakestScore = nil, nil, 999999
    for i, weapon in ipairs(p.weapons or {}) do
        local score = autoplayWeaponPower(weapon, profile)
        if score < weakestScore then weakestIndex, weakestWeapon, weakestScore = i, weapon, score end
    end
    return weakestIndex, weakestWeapon, weakestScore
end

function autoplayWeaponScore(item, profile)
    local def = item and (item.weaponDef or (item.id and weaponDefs[item.id]))
    if not def then return 0 end
    local score = autoplayWeaponPower(def, profile)
    local weaponCount = #(Game.player.weapons or {})
    if weaponCount < 3 then
        -- 自然构筑的前两章先补齐火力骨架；否则自动购买会把材料花到模块槽/消耗品上，Boss 只剩拖时。
        score = score + 820
    elseif weaponCount < 4 then
        score = score + 340
    else
        local _, _, weakestScore = autoplayWeakestWeapon(profile)
        local upgradeDelta = score - (weakestScore or score)
        if upgradeDelta < 95 then return 0 end
        score = 240 + upgradeDelta * 2.4
    end
    return score
end

function autoplayModuleScore(item, profile)
    local desc = (item and item.desc or "") .. " " .. (item and item.name or "")
    local score = 110
    if desc:find("伤害") then score = score + 190 end
    if desc:find("射速") then score = score + 175 end
    if desc:find("暴击") or desc:find("暴伤") then score = score + 145 end
    if desc:find("元素") or desc:find("附着") then score = score + 130 end
    if desc:find("射程") or desc:find("弹速") then score = score + 95 end
    if desc:find("腐蚀") or desc:find("易伤") then score = score + 105 end
    if profile.boss > 0 and (desc:find("伤害") or desc:find("射速") or desc:find("暴击") or desc:find("元素")) then score = score + 130 end
    if (profile.shield or 0) >= 18 and (desc:find("电弧") or desc:find("护盾")) then score = score + 95 end
    if (Game.wave or 1) <= 5 and (desc:find("回收") or desc:find("材料")) then score = score + 70 end
    if (Game.player.hp or 1) < (Game.player.maxHp or 1) * 0.55 and (desc:find("生命") or desc:find("吸血") or desc:find("护盾")) then score = score + 110 end
    return score
end

function autoplayShieldScore(item)
    local p = Game.player
    local current = p.shieldItem or {}
    local currentValue = (current.shieldCap or 0) + (current.shieldRegen or 0) * 16 + (current.hp or 0) * 0.45
    local value = (item.shieldCap or 0) + (item.shieldRegen or 0) * 16 + (item.hp or 0) * 0.45
    local score = 80 + value * 2.2 - currentValue * 1.5
    if not p.shieldItem then score = score + 220 end
    if (p.shield or 0) < (p.maxShield or 1) * 0.45 then score = score + 80 end
    if item.flag == "fullShieldDamage" then score = score + 95 end
    if item.flag == "killShield" then score = score + 65 end
    return score
end

function autoplayItemScore(item)
    if not item or not autoplayShouldBuy(item) then return -99999 end
    local profile = waveThreatProfile((Game.wave or 1) + 1)
    local score = 0
    if item.kind == "weapon" then
        score = autoplayWeaponScore(item, profile)
    elseif item.kind == "shield" then
        score = autoplayShieldScore(item)
    elseif isPermanentModule(item) then
        score = autoplayModuleScore(item, profile)
    elseif item.kind == "temp" then
        score = profile.boss > 0 and 165 or 75
        local desc = item.desc or ""
        if desc:find("伤害") or desc:find("射速") or desc:find("元素") then score = score + 80 end
        if desc:find("护盾") or desc:find("回复") then score = score + 45 end
    end
    score = score + ((rarityPower and rarityPower[item.rarity]) or 1) * 22
    score = score - (item.price or 0) * 0.35
    local reason = itemRecommendationReason(item)
    if reason then score = score + 90 end
    return score
end

function autoplayPrepareWeaponReplacement(item, score)
    local p = Game.player or {}
    if not item or item.kind ~= "weapon" or #(p.weapons or {}) < WEAPON_SLOT_MAX then return true end
    local profile = waveThreatProfile((Game.wave or 1) + 1)
    local def = item.weaponDef or (item.id and weaponDefs[item.id])
    local candidateScore = autoplayWeaponPower(def, profile)
    local weakestIndex, weakestWeapon, weakestScore = autoplayWeakestWeapon(profile)
    if weakestIndex and candidateScore - (weakestScore or 0) >= 95 then
        local soldName = weakestWeapon and weakestWeapon.name or "旧武器"
        if sellWeapon(weakestIndex) then
            Game.autoplayPurchases = Game.autoplayPurchases or {}
            Game.autoplayPurchases[#Game.autoplayPurchases + 1] = "替换武器：" .. soldName .. "→" .. tostring(item.name or "新武器")
            return true
        end
    end
    return false
end

function autoplayUpgradeSlotsIfUseful()
    local p = Game.player
    local cost = itemSlotUpgradeCost()
    if not cost or Game.coins < cost then return false end
    local weaponCount = #(p.weapons or {})
    local slotsFull = #(p.items or {}) >= (p.itemSlots or ITEM_SLOT_BASE)
    local earlyInvestment = weaponCount >= 3 and (Game.wave or 1) <= 6 and Game.coins >= cost + 90
    local rich = weaponCount >= 3 and Game.coins >= cost + 180
    if slotsFull or earlyInvestment or rich then
        local beforeLevel = p.itemSlotLevel or 1
        if upgradeItemSlots() then
            Game.autoplayPurchases = Game.autoplayPurchases or {}
            Game.autoplayPurchases[#Game.autoplayPurchases + 1] = "模块槽Lv." .. tostring(beforeLevel + 1) .. "@" .. tostring(cost)
            return true
        end
    end
    return false
end

function autoplayShopPurchaseSummary()
    if not autoplayRecordEnabled() then return end
    local purchases = Game.autoplayPurchases or {}
    local text = #purchases > 0 and table.concat(purchases, " / ") or "无购买"
    autoplayLine("- 自动购买/投资：" .. text)
end

function autoplayBuyPolicy()
    Game.autoplayPurchases = Game.autoplayPurchases or {}
    local bought = 0
    while bought < 4 do
        local bestIndex, bestItem, bestScore = nil, nil, -99999
        for i, item in ipairs(Game.shop or {}) do
            if item and Game.coins >= (item.price or 0) then
                local score = autoplayItemScore(item)
                if score > bestScore then bestIndex, bestItem, bestScore = i, item, score end
            end
        end
        if not bestIndex or bestScore < 40 then break end
        local name, price = bestItem.name or "商品", bestItem.price or 0
        if autoplayPrepareWeaponReplacement(bestItem, bestScore) and buySlot(bestIndex) then
            bought = bought + 1
            Game.autoplayPurchases[#Game.autoplayPurchases + 1] = name .. "@" .. tostring(price) .. "#" .. tostring(math.floor(bestScore + 0.5))
            autoplayUpgradeSlotsIfUseful()
        else
            break
        end
    end
end

function autoplayUpdate(dt)
    if not autoplayRecordEnabled() then return end
    local target = tonumber(os.getenv("LOVE_AUTOPLAY_TARGET_WAVE")) or 12
    if Game.state == "menu" then
        resetRun()
        autoplayLine("<!-- start -->")
        return
    end
    if Game.state == "route_choice" then chooseRoute(1); return end
    if Game.state == "event_choice" then chooseEvent(1); return end
    if Game.state == "playing" then
        autoplaySetMove()
        Game.autoplayWallClock = (Game.autoplayWallClock or 0) + dt
        local maxSimSeconds = tonumber(os.getenv("LOVE_AUTOPLAY_MAX_SIM_SECONDS")) or 180
        local waveSimSeconds = Game.waveElapsed or Game.autoplayWallClock or 0
        if waveSimSeconds > maxSimSeconds then
            local bossInfo = ""
            for _, e in ipairs(Game.enemies or {}) do
                if e.boss then
                    bossInfo = "；当前 Boss：" .. tostring(e.name or Game.waveBossName or "?") .. " " .. autoplayBossProgress(e) .. "；Boss耗时 " .. string.format("%.1fs", Game.waveElapsed or 0)
                    break
                end
            end
            autoplayLine("\n## 中止\n\n自动跑局当前波超过 " .. tostring(maxSimSeconds) .. " 秒模拟时间，停止记录；当前 wave " .. tostring(Game.wave or "?") .. bossInfo .. "。\n")
            love.event.quit()
        end
        return
    end
    if Game.state == "levelup" then
        local best = 1
        for i, reward in ipairs(Game.levelChoices or {}) do
            local desc = reward.desc or ""
            if desc:find("伤害") or desc:find("射速") or desc:find("暴击") then best = i; break end
        end
        chooseLevelReward(best)
        return
    end
    if Game.state == "shop" then
        local cleared = clearedWaveCount()
        if Game.autoplayShopRecorded ~= cleared then
            Game.autoplayShopRecorded = cleared
            Game.autoplayPurchases = {}
            autoplayShopSummary(cleared)
            autoplayBuyPolicy()
            if slotUnlocked() then
                local before = Game.coins or 0
                spinSlotMachine()
                if Game.slotResult then
                    Game.autoplayPurchases[#Game.autoplayPurchases + 1] = "补给转轮" .. (Game.slotResult.free and "@free" or ("@" .. tostring(math.max(0, before - (Game.coins or 0))))) .. "=" .. tostring(Game.slotResult.text or "")
                end
            end
            autoplayBuyPolicy()
            autoplayShopPurchaseSummary()
        end
        if cleared >= target then
            autoplayLine("\n## 结论\n\n自动跑局抵达目标 wave " .. tostring(target) .. " 后商店。请结合人工跑局验证真实手感。\n")
            love.event.quit()
        else
            startWave()
        end
        return
    end
    if Game.state == "gameover" then
        local p = Game.player or {}
        local liveBossName, liveBossProgress = nil, nil
        for _, e in ipairs(Game.enemies or {}) do if e.boss then liveBossName = e.name; liveBossProgress = autoplayBossProgress(e); break end end
        local bossText = liveBossName and ("；本波 Boss：" .. tostring(liveBossName) .. " " .. tostring(liveBossProgress or "")) or ""
        local hitText = Game.lastHitSource and ("；最后受击：" .. tostring(Game.lastHitSource) .. (Game.lastHitDamage and (" -" .. tostring(Game.lastHitDamage)) or "")) or ""
        autoplayLine("\n## 结论\n\n自动跑局死亡于 wave " .. tostring(Game.wave or "?") .. bossText .. hitText .. "；生命/护盾 " .. tostring(math.ceil(p.hp or 0)) .. "/" .. tostring(p.maxHp or 0) .. " / " .. tostring(math.ceil(p.shield or 0)) .. "/" .. tostring(p.maxShield or 0) .. "。\n")
        love.event.quit()
    elseif Game.state == "victory" then
        autoplayLine("\n## 结论\n\n自动跑局通关。\n")
        love.event.quit()
    end
end

function love.update(dt)
    Game.w, Game.h = VIRTUAL_W, VIRTUAL_H
    if autoplayRecordEnabled() then dt = math.min(dt * (tonumber(os.getenv("LOVE_AUTOPLAY_SPEED")) or 8), 0.08) end
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
    Game.hitFlash = math.max(0, (Game.hitFlash or 0) - dt)
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
    if autoplayRecordEnabled() then autoplayUpdate(dt) end
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
    elseif os.getenv("LOVE_AUTOELEMENTSHOT") == "1" and not Game.autoElementDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoElementStarted then
            Game.autoElementStarted = true
            Game.enemies = {}
            Game.bullets = {}
            local samples = {
                {id = "kinetic", x = Game.player.x - 420, y = Game.player.y - 180, vx = 620, vy = 0, sprite = "projectile_star_needle", brand = "starforge"},
                {id = "burn", x = Game.player.x - 420, y = Game.player.y - 110, vx = 540, vy = 0, sprite = "projectile_molten_orb", brand = "molten", splash = 58},
                {id = "arc", x = Game.player.x - 420, y = Game.player.y - 40, vx = 580, vy = 0, sprite = "projectile_arc_bolt", brand = "echo"},
                {id = "corrode", x = Game.player.x - 420, y = Game.player.y + 30, vx = 530, vy = 0, sprite = "projectile_void_orb", brand = "caustic"},
                {id = "ice", x = Game.player.x - 420, y = Game.player.y + 100, vx = 520, vy = 0, sprite = "projectile_arc_bolt", brand = "cryo"},
                {id = "void", x = Game.player.x - 420, y = Game.player.y + 170, vx = 420, vy = 0, sprite = "projectile_void_orb", brand = "blackbox", aura = 44}
            }
            for _, sample in ipairs(samples) do
                local elem = elements[sample.id] or elements.kinetic
                Game.bullets[#Game.bullets + 1] = {
                    x = sample.x, y = sample.y, vx = sample.vx, vy = sample.vy,
                    r = sample.aura and 6 or 4, damage = 10, element = sample.id, range = 1000,
                    traveled = 0, life = 3.0, pierce = 9, bounce = 0, splash = sample.splash, aura = sample.aura,
                    color = elem.color, sprite = sample.sprite, crit = sample.id == "kinetic", source = elem.name .. "测试弹", brand = sample.brand,
                    statusChance = sample.id ~= "kinetic" and 0.35 or 0, statusDamage = sample.id ~= "kinetic" and 6 or 0
                }
                addText(sample.x + 18, sample.y - 28, elem.name, elem.color)
            end
        end
        Game.autoElementClock = (Game.autoElementClock or 0) + dt
        if Game.autoElementClock > 0.55 then
            Game.autoElementDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-elements.png")
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
    elseif os.getenv("LOVE_AUTOFACTIONSHOT") == "1" and not Game.autoFactionDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoFactionStarted then
            Game.autoFactionStarted = true
            Game.enemies = {}
            local samples = {
                {def = enemyDefs.drifter, x = Game.player.x - 320, y = Game.player.y - 110},
                {def = enemyDefs.splinter, x = Game.player.x - 210, y = Game.player.y + 92},
                {def = enemyDefs.shell, x = Game.player.x + 210, y = Game.player.y + 96},
                {def = enemyDefs.wisp, x = Game.player.x + 310, y = Game.player.y - 105},
                {def = enemyDefs.bulwark, x = Game.player.x + 90, y = Game.player.y - 155},
                {def = enemyDefs.treasure, x = Game.player.x - 80, y = Game.player.y + 165},
            }
            for _, sample in ipairs(samples) do
                local def = sample.def
                local hp, shield = def.hp, def.shield or 0
                Game.enemies[#Game.enemies + 1] = {name = def.name, x = sample.x, y = sample.y, r = def.r, hp = hp, maxHp = hp, shield = shield, maxShield = shield, defense = def.defense, shieldRegen = 0, speed = 0, damage = def.damage or 0, armor = def.armor or 0, color = def.color, xp = def.xp, coin = def.coin, treasureCoin = def.treasureCoin, sprite = def.sprite, behavior = def.behavior, elite = def.elite, treasure = def.treasure, enteredArena = true}
                addText(sample.x - 28, sample.y - def.r - 36, def.treasure and "掉落/中立" or "敌方", def.treasure and C.gold or def.color, {life = 2.0, scale = 1.05})
            end
        end
        Game.autoFactionClock = (Game.autoFactionClock or 0) + dt
        if Game.autoFactionClock > 0.45 then
            Game.autoFactionDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-factions.png")
            love.event.quit()
        end
    elseif os.getenv("LOVE_AUTOHITSHOT") == "1" and not Game.autoHitDone then
        if Game.state == "menu" then resetRun() end
        if Game.state == "playing" and not Game.autoHitApplied then
            Game.autoHitApplied = true
            Game.enemies = {}
            local p = Game.player
            p.invuln = 0
            local def = enemyDefs.rammer
            Game.enemies[#Game.enemies + 1] = {name = def.name, x = p.x + 270, y = p.y - 50, r = def.r, hp = def.hp, maxHp = def.hp, shield = 0, maxShield = 0, defense = def.defense, shieldRegen = 0, speed = def.speed, damage = def.damage, armor = def.armor or 0, color = def.color, xp = def.xp, coin = def.coin, sprite = def.sprite, behavior = def.behavior, enteredArena = true, chargeState = "dash", chargeTimer = 0.42, chargeAngle = angleTo(p.x + 270, p.y - 50, p.x, p.y), chargeWarnLength = 440}
            damagePlayer(18, "冲锋撞击", p.x + 270, p.y - 50, C.red)
        end
        Game.autoHitClock = (Game.autoHitClock or 0) + dt
        if Game.autoHitClock > 0.18 then
            Game.autoHitDone = true
            love.graphics.captureScreenshot(os.getenv("LOVE_AUTOSHOT_PATH") or "heartcore-hit.png")
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
        local shotDelay = tonumber(os.getenv("LOVE_AUTOSHOT_DELAY")) or 2.0
        if Game.time > shotDelay then
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
        love.graphics.setColor(0.010, 0.012, 0.030, 0.42)
        love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
        love.graphics.setColor(0.02, 0.04, 0.08, 0.12)
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

local function drawBarCapsule(label, value, x, y, w, h, pct, accent, opts)
    opts = opts or {}
    color(C.panel, opts.bgAlpha or 0.66)
    love.graphics.rectangle("fill", x, y, w, h, opts.radius or 12, opts.radius or 12)
    color(accent, opts.borderAlpha or 0.46)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, opts.radius or 12, opts.radius or 12)
    local labelFont = opts.labelFont or Game.fonts.tiny
    local valueFont = opts.valueFont or Game.fonts.tiny
    local labelW = opts.labelW or 58
    local valueW = opts.valueW or 84
    local barH = opts.barH or 11
    if opts.centerValue then
        local barX, barY = x + 72, y + h - barH - 8
        local barW = w - 92
        bar(barX, barY, barW, barH, pct, accent, {0.02, 0.024, 0.05})
        love.graphics.setFont(labelFont)
        color(opts.labelColor or C.muted, opts.labelAlpha or 0.78)
        love.graphics.printf(label, x + 14, y + 8, labelW, "left")
        love.graphics.setFont(valueFont)
        color(opts.valueColor or C.white)
        love.graphics.printf(value, x + 10, y + math.floor((h - valueFont:getHeight()) / 2) - 1, w - 20, "center")
        return
    end
    love.graphics.setFont(labelFont)
    color(opts.labelColor or C.muted)
    love.graphics.printf(label, x + 12, y + math.floor((h - labelFont:getHeight()) / 2), labelW, "left")
    local barX, barY = x + labelW + 24, y + math.floor((h - barH) / 2)
    local barW = w - (barX - x) - valueW - 14
    bar(barX, barY, barW, barH, pct, accent, {0.02, 0.024, 0.05})
    love.graphics.setFont(valueFont)
    color(opts.valueColor or C.white)
    love.graphics.printf(value, x + w - valueW - 12, y + math.floor((h - valueFont:getHeight()) / 2), valueW, "right")
end

local waveThreatSummary

local function drawHud()
    local p = Game.player
    local hpPct = clamp(p.hp / math.max(1, p.maxHp), 0, 1)
    local shieldPct = clamp(p.shield / math.max(1, p.maxShield), 0, 1)
    local dangerPulse = 0.5 + 0.5 * math.sin((love.timer.getTime() or 0) * 8.0)
    local hudY, hudH = 14, 138
    panel(18, hudY, Game.w - 36, hudH)
    color(C.bgA, 0.42)
    love.graphics.rectangle("fill", 26, hudY + 8, Game.w - 52, hudH - 16, 16, 16)
    color(C.white, 0.045)
    love.graphics.rectangle("fill", 32, hudY + 14, Game.w - 64, hudH - 28, 14, 14)

    -- 左：生存状态必须比材料/击杀更抢眼。原型可以乱，战斗 HUD 不能乱。
    local lx = 36
    local hpColor = hpPct < 0.35 and C.red or C.pink
    drawBarCapsule("生命", math.ceil(p.hp) .. "/" .. p.maxHp, lx, hudY + 10, 370, 58, hpPct, hpColor, {centerValue = true, valueFont = Game.fonts.big, labelW = 54, barH = 8, bgAlpha = 0.72, borderAlpha = 0.58})
    drawBarCapsule("护盾", math.ceil(p.shield) .. "/" .. p.maxShield, lx, hudY + 76, 370, 42, shieldPct, C.blue, {centerValue = true, valueFont = Game.fonts.normal, labelW = 54, barH = 6, bgAlpha = 0.50, borderAlpha = 0.30, labelAlpha = 0.62})
    if hpPct < 0.35 then
        color(C.red, 0.16 + dangerPulse * 0.18)
        love.graphics.rectangle("line", lx - 4, hudY + 6, 378, 62, 12, 12)
        love.graphics.setFont(Game.fonts.tiny)
        color(C.red, 0.90)
        love.graphics.printf("核心受损", lx + 258, hudY + 30, 96, "right")
    end
    drawCapsule("◆ " .. tostring(Game.coins), lx + 392, hudY + 22, 104, 28, {font = Game.fonts.tiny, fg = C.gold, border = C.gold, align = "center", padX = 8, bgAlpha = 0.18, borderAlpha = 0.14})
    drawCapsule("☠ " .. tostring(Game.kills), lx + 392, hudY + 62, 104, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.white, align = "center", padX = 8, bgAlpha = 0.10, borderAlpha = 0.06})

    -- 中：主任务。只保留一个主读数；章节、敌情和可选目标退到辅助胶囊，别和倒计时抢戏。
    local plan = currentWavePlan()
    local bossMode = plan.boss == true
    local midX = Game.w / 2
    local timerFont = Game.fonts.timer or Game.fonts.normal
    local mainTargetText = bossMode and "打爆" or ("撑住 " .. string.format("%02d", math.max(0, math.ceil(Game.waveTime))))
    love.graphics.setFont(timerFont)
    local textW, textH = timerFont:getWidth(mainTargetText), timerFont:getHeight()
    local timerW = math.max(bossMode and 118 or 190, textW + 38)
    local timerH = math.max(54, textH + 8)
    local timerX, timerY = midX - timerW / 2, hudY + 56
    local timerCx, timerCy = timerX + timerW / 2, timerY + timerH / 2
    local now = love.timer.getTime() or 0
    if Game.hudTimerText ~= mainTargetText then
        Game.hudTimerText = mainTargetText
        Game.hudTimerPulseAt = now
    end
    local pulse = clamp(1 - (now - (Game.hudTimerPulseAt or now)) / 0.26, 0, 1)
    local scale = 1 + pulse * (bossMode and 0.025 or 0.055)
    local framePulse = 0.50 + 0.50 * math.sin(now * 7.0)

    love.graphics.setBlendMode("add")
    color(C.cyan, 0.07 + pulse * 0.06)
    love.graphics.rectangle("fill", timerX - 7, timerY - 6, timerW + 14, timerH + 12, 14, 14)
    love.graphics.setBlendMode("alpha")
    color(C.white, 0.18 + pulse * 0.08)
    love.graphics.rectangle("fill", timerX, timerY, timerW, timerH, 12, 12)
    color(C.cyan, 0.78 + pulse * 0.18 + framePulse * 0.04)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", timerX + 0.5, timerY + 0.5, timerW - 1, timerH - 1, 12, 12)
    love.graphics.setLineWidth(1)
    drawCapsule("目标", timerX + 24, timerY - 20, timerW - 48, 18, {font = Game.fonts.tiny, fg = C.muted, border = C.cyan, bgAlpha = 0.22, borderAlpha = 0.08, align = "center", radius = 7, padX = 8})

    color(C.white, 0.88 + pulse * 0.12)
    love.graphics.push()
    love.graphics.translate(timerCx, timerCy)
    love.graphics.scale(scale, scale)
    love.graphics.print(mainTargetText, -textW / 2, -textH / 2)
    love.graphics.pop()

    local leftInfoX, sideW = midX - 304, 154
    drawCapsule(chapterWaveLabel(Game.wave), leftInfoX, hudY + 22, sideW, 26, {font = Game.fonts.tiny, fg = C.gold, border = C.gold, borderAlpha = 0.12, bgAlpha = 0.20})
    drawCapsule(plan.name or "清理敌群", leftInfoX, hudY + 58, sideW, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.gold, bgAlpha = 0.14, borderAlpha = 0.08})
    local rightInfoX = midX + 150
    local obj = Game.sideObjective
    local sideObjective = obj and ("可选 " .. (obj.short or obj.name) .. " " .. math.floor(obj.progress or 0) .. "/" .. obj.target) or "可选 无"
    drawCapsule(bossMode and (Game.bossDefeated and "Boss 已打爆" or "打爆 Boss") or sideObjective, rightInfoX, hudY + 22, sideW, 26, {font = Game.fonts.tiny, fg = C.cyan, border = C.cyan, borderAlpha = 0.12, bgAlpha = 0.18})
    drawCapsule("危 " .. Game.danger .. " · " .. survivalPhaseName(), rightInfoX, hudY + 58, sideW, 24, {font = Game.fonts.tiny, fg = C.muted, border = C.cyan, bgAlpha = 0.14, borderAlpha = 0.08})

    -- 右：即时操作/威胁。长说明留给商店情报，战斗中别念小作文。
    local rx, rw = Game.w - 430, 392
    local skill = p.activeSkill or {}
    local skillText = "空格 冲刺"
    local skillFg = C.muted
    if (skill.duration or 0) > 0 then
        skillText = "空格 冲刺 " .. string.format("%.1f", skill.duration) .. "s"
        skillFg = C.gold
    elseif (skill.cd or 0) > 0 then
        skillText = "空格 CD " .. string.format("%.1f", skill.cd) .. "s"
        skillFg = C.muted
    end
    drawCapsule(skillText, rx, hudY + 18, rw, 28, {font = Game.fonts.tiny, fg = skillFg, border = skillFg, bgAlpha = 0.08, borderAlpha = 0.04, align = "left", padX = 14})
    drawCapsule("敌 " .. waveThreatSummary(Game.wave), rx, hudY + 58, rw, 30, {font = Game.fonts.tiny, fg = C.gold, border = C.gold, bgAlpha = 0.22, borderAlpha = 0.18, align = "left", padX = 14})

    local boss = nil
    for _, e in ipairs(Game.enemies or {}) do if e.boss then boss = e; break end end
    if boss then
        local bossW = 640
        local bossX = Game.w / 2 - bossW / 2
        local bossY = hudY + hudH + 82
        local phaseLabel = boss.bossPhaseName and (" · " .. boss.bossPhaseName) or ""
        drawCapsule("Boss状态 · " .. (boss.name or "关底目标") .. phaseLabel, bossX, bossY - 26, bossW, 22, {font = Game.fonts.tiny, fg = (boss.bossWeakTimer or 0) > 0 and C.gold or C.gold, border = (boss.bossWeakTimer or 0) > 0 and C.gold or C.gold, bgAlpha = 0.18, borderAlpha = 0.12, align = "center"})
        if (boss.maxShield or 0) > 0 then
            drawBarCapsule("Boss护盾", math.ceil(math.max(0, boss.shield or 0)) .. "/" .. math.ceil(boss.maxShield or 0), bossX, bossY, bossW, 30, math.max(0, boss.shield or 0) / math.max(1, boss.maxShield or 1), C.blue, {labelW = 98, valueW = 150, valueFont = Game.fonts.tiny, barH = 8, bgAlpha = 0.50, borderAlpha = 0.26})
            drawBarCapsule("Boss生命", math.ceil(boss.hp) .. "/" .. math.ceil(boss.maxHp or boss.hp), bossX, bossY + 36, bossW, 32, boss.hp / math.max(1, boss.maxHp or boss.hp), C.red, {labelW = 98, valueW = 170, valueFont = Game.fonts.tiny, barH = 9, bgAlpha = 0.58, borderAlpha = 0.36})
        else
            drawBarCapsule("Boss生命", math.ceil(boss.hp) .. "/" .. math.ceil(boss.maxHp or boss.hp), bossX, bossY, bossW, 34, boss.hp / math.max(1, boss.maxHp or boss.hp), C.red, {labelW = 98, valueW = 170, valueFont = Game.fonts.tiny, barH = 9, bgAlpha = 0.58, borderAlpha = 0.36})
        end
    else
        drawCapsule("敌群 " .. #Game.enemies, rx, hudY + 96, rw, 22, {font = Game.fonts.tiny, fg = C.muted, border = C.white, bgAlpha = 0.18, borderAlpha = 0.12, align = "left", padX = 14})
    end
end

local function drawCombatWarningOverlay()
    if Game.state ~= "playing" then return end
    local p = Game.player
    local hpPct = clamp(p.hp / math.max(1, p.maxHp), 0, 1)
    local t = love.timer.getTime() or 0
    local pulse = 0.45 + 0.55 * math.sin(t * 8.0)
    local hitFlash = clamp((Game.hitFlash or 0) / 0.42, 0, 1)
    if hitFlash > 0 then
        local hitColor = Game.lastHitColor or C.red
        love.graphics.setBlendMode("add")
        color(hitColor, 0.10 + hitFlash * 0.18)
        love.graphics.rectangle("fill", 0, 0, Game.w, 46)
        love.graphics.rectangle("fill", 0, Game.h - 46, Game.w, 46)
        love.graphics.rectangle("fill", 0, 0, 46, Game.h)
        love.graphics.rectangle("fill", Game.w - 46, 0, 46, Game.h)
        if Game.lastHitAngle then
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(Game.lastHitAngle)
            color(hitColor, 0.28 + hitFlash * 0.34)
            love.graphics.polygon("fill", 48, 0, 8, -24, 8, 24)
            color(hitColor, 0.74 + hitFlash * 0.22)
            love.graphics.setLineWidth(7)
            love.graphics.line(52, 0, 128, 0)
            love.graphics.setLineWidth(1)
            love.graphics.pop()
        end
        love.graphics.setBlendMode("alpha")
        if Game.lastHitSource then
            local cardW, cardH = 360, 44
            local cardX, cardY = Game.w / 2 - cardW / 2, 146
            color(C.bgA, 0.78)
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)
            color(hitColor, 0.72 + hitFlash * 0.18)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX + 0.5, cardY + 0.5, cardW - 1, cardH - 1, 12, 12)
            love.graphics.setLineWidth(1)
            love.graphics.setFont(Game.fonts.small)
            color(C.white, 0.94)
            local dmg = Game.lastHitDamage and (" -" .. tostring(Game.lastHitDamage)) or ""
            love.graphics.printf("受击：" .. Game.lastHitSource .. dmg, cardX + 12, cardY + 12, cardW - 24, "center")
        end
    end
    if hpPct < 0.35 then
        love.graphics.setBlendMode("add")
        color(C.red, 0.08 + pulse * 0.08)
        love.graphics.rectangle("fill", 0, 0, Game.w, 38)
        love.graphics.rectangle("fill", 0, Game.h - 38, Game.w, 38)
        love.graphics.rectangle("fill", 0, 0, 38, Game.h)
        love.graphics.rectangle("fill", Game.w - 38, 0, 38, Game.h)
        love.graphics.setBlendMode("alpha")
        love.graphics.setFont(Game.fonts.small)
        color(C.red, 0.72 + pulse * 0.18)
        love.graphics.printf("警告：核心生命过低", 0, hitFlash > 0 and 168 or 142, Game.w, "center")
    end
end

local function drawWorld()
    for _, z in ipairs(Game.fireZones or {}) do
        local pct = clamp(z.life / math.max(0.1, z.maxLife or z.life), 0, 1)
        love.graphics.setBlendMode("add")
        local outer, core = z.color or C.orange, z.coreColor or C.red
        color(outer, 0.10 + pct * 0.18)
        love.graphics.circle("fill", z.x, z.y, z.r)
        color(core, 0.12 + pct * 0.12)
        love.graphics.circle("fill", z.x, z.y, z.r * 0.68)
        love.graphics.setBlendMode("alpha")
        color(outer, 0.48)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", z.x, z.y, z.r)
        color(core, 0.34)
        love.graphics.circle("line", z.x, z.y, z.r * 0.68)
        love.graphics.setLineWidth(1)
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
        local hostile = b.kind == "firebomb" and C.orange or C.red
        local pulse = 0.50 + 0.50 * math.sin((love.timer.getTime() or 0) * 12 + b.x * 0.02)
        love.graphics.setBlendMode("add")
        color(hostile, b.kind == "firebomb" and (0.32 + pulse * 0.18) or (0.26 + pulse * 0.16))
        love.graphics.circle("fill", b.x, b.y, b.r * (b.kind == "firebomb" and 3.8 or 3.0))
        color(hostile, 0.58 + pulse * 0.24)
        love.graphics.circle("line", b.x, b.y, b.r * (b.kind == "firebomb" and 2.4 or 2.0))
        love.graphics.setBlendMode("alpha")
        color(hostile, 0.96)
        love.graphics.circle("fill", b.x, b.y, b.r * 1.08)
        love.graphics.setColor(1, 0.96, 0.82, 0.82)
        love.graphics.circle("fill", b.x, b.y, math.max(2.0, b.r * 0.42))
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
        if (e.behavior == "rammer" or e.behavior == "rail_charger") and e.chargeState == "windup" then
            local a = e.chargeAngle or angleTo(e.x, e.y, p.x, p.y)
            local len = e.chargeWarnLength or 420
            local x2, y2 = e.x + math.cos(a) * len, e.y + math.sin(a) * len
            local pulse = 0.48 + 0.52 * math.sin((love.timer.getTime() or 0) * 16)
            love.graphics.setBlendMode("add")
            love.graphics.setLineWidth(14)
            local warnColor = e.behavior == "rail_charger" and C.cyan or C.red
            color(warnColor, 0.10 + pulse * 0.10)
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
        local hostile = e.treasure and C.gold or (e.boss and C.red or (e.elite and C.orange or C.red))
        local enemyPulse = 0.50 + 0.50 * math.sin((love.timer.getTime() or 0) * (e.boss and 5.0 or 6.5) + e.x * 0.01)
        love.graphics.setColor(0, 0, 0, 0.42)
        love.graphics.ellipse("fill", e.x, e.y + e.r * 1.42, e.r * 2.55, e.r * 0.62)
        if e.treasure then
            local pulse = 0.55 + 0.45 * math.sin((love.timer.getTime() or 0) * 5)
            love.graphics.setBlendMode("add")
            color(C.gold, 0.24 + pulse * 0.18)
            love.graphics.circle("fill", e.x, e.y, e.r * 3.1)
            color(C.white, 0.78)
            love.graphics.circle("line", e.x, e.y, e.r * 2.05)
            love.graphics.setBlendMode("alpha")
            love.graphics.setFont(Game.fonts.tiny)
            color(C.gold)
            love.graphics.printf("宝", e.x - 16, e.y - e.r - 26, 32, "center")
        end
        love.graphics.setBlendMode("add")
        color(hostile, e.boss and (0.34 + enemyPulse * 0.12) or (0.20 + enemyPulse * 0.08))
        love.graphics.circle("fill", e.x, e.y, e.r * (e.boss and 3.0 or 2.55))
        color(hostile, e.boss and 0.82 or (e.elite and 0.72 or 0.58))
        love.graphics.setLineWidth(e.boss and 5 or (e.elite and 4 or 3))
        love.graphics.circle("line", e.x, e.y, e.r * (e.boss and 2.38 or 2.14))
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0.02, 0.012, 0.018, 0.92)
        love.graphics.setLineWidth(e.boss and 3 or 2)
        love.graphics.circle("line", e.x, e.y, e.r * 1.86)
        color(hostile, e.boss and 0.98 or 0.86)
        love.graphics.circle("line", e.x, e.y, e.r * 1.58)
        color(C.white, e.boss and 0.76 or (e.elite and 0.54 or 0.34))
        love.graphics.setLineWidth(e.boss and 3 or 2)
        love.graphics.circle("line", e.x, e.y, e.r * (e.boss and 2.66 or 2.34))
        love.graphics.setLineWidth(1)
        if e.boss or e.elite or e.behavior == "shooter" or e.behavior == "bomber" or e.behavior == "rammer" or e.behavior == "zoner" then
            local tag = e.boss and "BOSS" or (e.elite and "精英" or (e.behavior == "zoner" and "封锁" or (e.behavior == "bomber" and "火力" or (e.behavior == "rammer" and "冲锋" or "远程"))))
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
        if not e.treasure then
            love.graphics.setBlendMode("add")
            color(hostile, 0.16 + enemyPulse * 0.10)
            love.graphics.circle("fill", e.x, e.y + e.r * 0.08, e.r * (e.boss and 2.95 or 2.42))
            color(e.color or hostile, 0.30 + enemyPulse * 0.14)
            love.graphics.setLineWidth(e.boss and 5 or 3)
            love.graphics.circle("line", e.x, e.y, e.r * (e.boss and 3.12 or 2.78))
            color(hostile, 0.48)
            love.graphics.circle("fill", e.x - e.r * 0.72, e.y - e.r * 0.78, math.max(6, e.r * 0.28))
            love.graphics.setLineWidth(1)
            love.graphics.setBlendMode("alpha")
        end
        if (e.shield or 0) > 0 and (e.maxShield or 0) > 0 then
            local shieldPulse = 0.45 + 0.55 * math.sin((love.timer.getTime() or 0) * 7 + e.x * 0.01)
            love.graphics.setBlendMode("add")
            color(C.blue, 0.18 + shieldPulse * 0.14)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", e.x, e.y, e.r * 2.82)
            love.graphics.setLineWidth(1)
            love.graphics.setBlendMode("alpha")
        end
        if e.boss and (e.bossWeakTimer or 0) > 0 then
            local weakPulse = 0.50 + 0.50 * math.sin((love.timer.getTime() or 0) * 11)
            love.graphics.setBlendMode("add")
            color(C.gold, 0.24 + weakPulse * 0.20)
            love.graphics.circle("fill", e.x, e.y, e.r * 2.15)
            color(C.white, 0.46 + weakPulse * 0.22)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", e.x, e.y, e.r * 1.34)
            love.graphics.setLineWidth(1)
            love.graphics.setBlendMode("alpha")
        end
        if (e.burn and e.burn > 0) or (e.shock and e.shock > 0) or (e.corrosion and e.corrosion > 0) or (e.slow and e.slow > 0) or (e.voidMark and e.voidMark > 0) then
            local statusColor = (e.burn and e.burn > 0 and C.orange) or (e.shock and e.shock > 0 and C.cyan) or (e.corrosion and e.corrosion > 0 and C.green) or (e.slow and e.slow > 0 and C.ice) or C.purple
            love.graphics.setBlendMode("add")
            color(statusColor, 0.18)
            love.graphics.circle("fill", e.x, e.y, e.r * 2.25)
            love.graphics.setBlendMode("alpha")
        end
        if e.hp < e.maxHp or ((e.shield or 0) < (e.maxShield or 0) and (e.maxShield or 0) > 0) then
            local bw = e.boss and e.r * 3.0 or e.r * 2.55
            local bh = e.boss and 8 or 6
            local barX = clamp(e.x - bw / 2, 46, Game.w - bw - 46)
            local barY = clamp(e.y - e.r - 16, 178, Game.h - 82)
            if (e.maxShield or 0) > 0 then
                bar(barX, barY - bh - 2, bw, math.max(4, bh - 1), (e.shield or 0) / math.max(1, e.maxShield), C.blue)
            end
            bar(barX, barY, bw, bh, e.hp / e.maxHp, C.red)
        end
    end

    -- 无敌状态保持机体稳定可见；主动技能只用固定光环提示，不再用闪烁隐藏。
    do
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
        local playerPulse = 0.50 + 0.50 * math.sin((love.timer.getTime() or 0) * 4.6)
        love.graphics.setBlendMode("add")
        color(C.cyan, 0.18 + playerPulse * 0.08)
        love.graphics.circle("fill", p.x, p.y, p.r + 34)
        color(C.cyan, 0.68 + playerPulse * 0.18)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", p.x, p.y, p.r + 22)
        color(C.cyan, 0.58)
        love.graphics.setLineWidth(2)
        love.graphics.line(p.x - p.r - 26, p.y, p.x - p.r - 10, p.y)
        love.graphics.line(p.x + p.r + 10, p.y, p.x + p.r + 26, p.y)
        love.graphics.line(p.x, p.y - p.r - 26, p.x, p.y - p.r - 10)
        love.graphics.line(p.x, p.y + p.r + 10, p.x, p.y + p.r + 26)
        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0, 0, 0, 0.34)
        love.graphics.ellipse("fill", p.x, p.y + p.r + 14, p.r * 2.25, p.r * 0.58)
        if not drawSprite("player_heartcore", p.x, p.y, 100, 0, 1) then
            color(C.pink)
            drawHeart(p.x, p.y + 2, 0.78)
        end
        color(C.cyan, 0.86)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", p.x, p.y, p.r + 14)
        love.graphics.setLineWidth(1)
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
    for _, t in ipairs(Game.damageTexts) do
        local alpha = clamp(t.life / math.max(0.01, t.maxLife or 0.72), 0, 1)
        local font = t.font or Game.fonts.tiny
        love.graphics.setFont(font)
        love.graphics.push()
        love.graphics.translate(t.x, t.y)
        love.graphics.scale(t.scale or 1, t.scale or 1)
        color(C.bgA, 0.58 * alpha)
        love.graphics.print(t.text, 1, 1)
        color(t.color, alpha)
        love.graphics.print(t.text, 0, 0)
        love.graphics.pop()
    end
end

function hitRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function uiButton(text, x, y, w, h, bg, fg, font)
    local c = bg or C.cyan
    local strong = font == Game.fonts.normal
    local pulse = strong and (0.5 + 0.5 * math.sin((love.timer.getTime() or 0) * 3.4)) or 0
    color(c, strong and (0.48 + pulse * 0.16) or 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    if strong then
        color(C.gold, 0.22 + pulse * 0.16)
        love.graphics.rectangle("fill", x - 16, y - 16, w + 32, h + 32, 22, 22)
        color(C.gold, 0.34 + pulse * 0.18)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 18, y - 18, w + 36, h + 36, 24, 24)
        love.graphics.setLineWidth(1)
    end
    color(strong and C.gold or c, strong and (0.96 + pulse * 0.04) or 0.74)
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

function drawMenu()
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
    color(C.white, 0.92)
    love.graphics.printf("10大关30小关 · 首关养成 · 二关升压", 0, 124, w, "center")
    local introW, introH = 760, 38
    local introX, introY = w / 2 - introW / 2, 154
    color(C.panel, 0.56)
    love.graphics.rectangle("fill", introX, introY, introW, introH, 12, 12)
    color(C.cyan, 0.22)
    love.graphics.rectangle("line", introX + 0.5, introY + 0.5, introW - 1, introH - 1, 12, 12)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.white, 0.94)
    love.graphics.printf("撑住倒计时，收材料，把白板机体养成怪物。", introX + 20, introY + 9, introW - 40, "center")

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
    love.graphics.printf("开局白板进场，靠局内随机滚出流派", cx - 300, cy + 160, 600, "center")

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
    local diffX, diffY, diffW = deckX + deckW - 406, deckY + 18, 378
    color(C.panel, 0.52)
    love.graphics.rectangle("fill", diffX, diffY, diffW, 100, 14, 14)
    color(C.gold, 0.30)
    love.graphics.rectangle("line", diffX + 0.5, diffY + 0.5, diffW - 1, 99, 14, 14)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.gold)
    love.graphics.printf("难度选择", diffX + 18, diffY + 10, diffW - 36, "left")
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(dangerText, diffX + 18, diffY + 30, diffW - 36, "center")
    uiButton("‹ Q 降低", diffX + 18, diffY + 60, 154, 34, C.cyan, C.white, Game.fonts.tiny)
    uiButton("E 提高 ›", diffX + diffW - 172, diffY + 60, 154, 34, C.cyan, C.white, Game.fonts.tiny)

    uiButton("开始实验", w / 2 - 140, deckY + 24, 280, 54, C.gold, C.white, Game.fonts.normal)
    uiButton("图鉴", w / 2 - 90, deckY + 84, 180, 30, C.cyan, C.white, Game.fonts.tiny)
    -- 首页不再提供模式切换，只保留战役模式；难度仍可调整。
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("目标：普通关撑住，关底打爆 Boss；越往后越凶。", deckX + 28, deckY + 96, 500, "left")
end

function drawSettlementCard(title, value, x, y, w, h, accent, detail)
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

function drawLevelUp()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    panel(Game.w / 2 - 660, 110, 1320, 640)

    love.graphics.setFont(Game.fonts.big)
    color(C.gold)
    love.graphics.printf("关卡完成", Game.w / 2 - 620, 134, 1240, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf("选择一个成长奖励，然后进入补给商店。", Game.w / 2 - 620, 206, 1240, "center")

    local wr = Game.waveRewards or {}
    local cardY, cardH = 252, 104
    local cardW, gap = 278, 22
    local sx = Game.w / 2 - (cardW * 4 + gap * 3) / 2
    drawSettlementCard("本关", chapterWaveLabel(wr.wave or Game.wave), sx, cardY, cardW, cardH, C.gold, wr.reason or "波次完成")
    drawSettlementCard("收益", "+" .. tostring(wr.coins or 0) .. " 材料", sx + (cardW + gap), cardY, cardW, cardH, C.cyan, "通关奖励 +" .. tostring(wr.clear or 0))
    drawSettlementCard("击杀", tostring(wr.kills or 0), sx + (cardW + gap) * 2, cardY, cardW, cardH, C.red, "当前危险 " .. tostring(Game.danger or 0))
    drawSettlementCard("可选目标", wr.objective and ("+" .. wr.objective) or "未完成", sx + (cardW + gap) * 3, cardY, cardW, cardH, wr.objective and C.gold or C.muted, Game.sideObjective and Game.sideObjective.name or "本关可选")

    local damageRows = {}
    for name, dmg in pairs(Game.runStats.damageByWeapon or {}) do damageRows[#damageRows + 1] = {name = name, damage = dmg} end
    table.sort(damageRows, function(a, b) return a.damage > b.damage end)
    local dmgText = {}
    for i = 1, math.min(4, #damageRows) do dmgText[#dmgText + 1] = damageRows[i].name .. " " .. math.floor(damageRows[i].damage) end
    panel(Game.w / 2 - 570, 374, 1140, 50)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.cyan)
    love.graphics.printf("武器伤害", Game.w / 2 - 548, 386, 120, "left")
    color(C.white)
    love.graphics.printf(#dmgText > 0 and table.concat(dmgText, "   /   ") or "暂无", Game.w / 2 - 420, 386, 950, "left")

    love.graphics.setFont(Game.fonts.normal)
    color(C.gold)
    love.graphics.printf("选择奖励", Game.w / 2 - 560, 444, 1120, "center")
    local w, h, rewardGap = 330, 206, 34
    local rewardX = Game.w / 2 - (w * 3 + rewardGap * 2) / 2
    local mx, my = mousePosition()
    for i, r in ipairs(Game.levelChoices) do
        local x, y = rewardX + (i - 1) * (w + rewardGap), 484
        local hover = hitRect(mx, my, x, y, w, h)
        local lift = hover and -6 or 0
        local yy = y + lift
        local rc = rarityColor[r.rarity or "rare"] or C.cyan
        panel(x, yy, w, h)
        color(rc, hover and 0.18 or 0.08)
        love.graphics.rectangle("fill", x + 8, yy + 10, w - 16, h - 20, 14, 14)
        color(rc, 0.95)
        love.graphics.rectangle("fill", x, yy, w, 6, 6, 6)
        color(rc, hover and 0.78 or 0.30)
        love.graphics.setLineWidth(hover and 3 or 1)
        love.graphics.rectangle("line", x + 0.5, yy + 0.5, w - 1, h - 1, 14, 14)
        love.graphics.setLineWidth(1)
        drawCapsule("快捷键 " .. i, x + 18, yy + 18, 88, 24, {font = Game.fonts.tiny, fg = hover and C.gold or C.muted, border = hover and C.gold or C.white, bgAlpha = hover and 0.20 or 0.12, borderAlpha = hover and 0.28 or 0.10})
        love.graphics.setFont(Game.fonts.normal)
        color(C.white)
        love.graphics.printf(r.name, x + 16, yy + 56, w - 32, "center")
        love.graphics.setFont(Game.fonts.tiny)
        color(hover and C.white or C.muted)
        local rewardDesc = compactDesc(tostring(r.desc or ""), 34)
        love.graphics.printf(rewardDesc, x + 30, yy + 108, w - 60, "center")
        local chooseText = hover and "点击后立即选择" or "点击选择"
        drawCapsule(chooseText, x + 50, yy + h - 44, w - 100, 34, {font = Game.fonts.tiny, fg = C.bgA, border = hover and C.gold or C.cyan, bg = hover and C.gold or C.cyan, bgAlpha = hover and 0.94 or 0.92, borderAlpha = hover and 1.00 or 0.98})
    end
end

function statText(label, value)
    return label .. " " .. value
end

function pct(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

function modText(text)
    return text
end

function textInBox(text, x, y, w, h, font, c, align)
    font = font or Game.fonts.tiny
    love.graphics.setFont(font)
    color(c or C.white)
    love.graphics.printf(tostring(text or ""), x, y + math.floor((h - font:getHeight()) / 2), w, align or "center")
end

function centeredText(text, x, y, w, h, font, c, align)
    textInBox(text, x, y, w, h, font, c, align or "center")
end

function tagPill(text, x, y, bg, fg, maxW, primary)
    local font = Game.fonts.tiny
    local tw = math.max(primary and 54 or 46, font:getWidth(text) + (primary and 24 or 18))
    if maxW then tw = math.min(tw, maxW) end
    local th = 24
    color(bg, primary and 0.88 or 0.12)
    love.graphics.rectangle("fill", x, y, tw, th, 8, 8)
    color(bg, primary and 0.74 or 0.34)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, tw - 1, th - 1, 8, 8)
    centeredText(text, x, y, tw, th, font, fg or (primary and C.bgA or C.muted), "center")
    return tw
end

function drawTagRow(tags, x, y, maxW)
    local cursor = x
    for i, tag in ipairs(tags) do
        if i > 3 then break end
        local remain = maxW - (cursor - x)
        if remain < 42 then break end
        local primary = tag.primary == true or i == 1
        local bg = primary and (tag.color or C.gold) or C.white
        local fg = primary and (tag.fg or C.bgA) or (tag.fg or C.muted)
        cursor = cursor + tagPill(tag.text, cursor, y, bg, fg, remain, primary) + 6
    end
    return cursor - x
end

function shopItemAccent(item)
    if item.kind == "weapon" then return C.orange end
    if item.kind == "shield" then return C.blue end
    if item.kind == "temp" then return C.purple end
    if item.kind == "legend" then return C.gold end
    return rarityColor[item.rarity or "common"] or C.white
end

function drawKindIcon(kind, x, y, accent)
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

function compactDesc(text, maxLen)
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

function drawMetalCard(x, y, w, h, accent, hover, locked, rare)
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

Tooltip = {}

function wrappedLineCount(font, text, width)
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
        local text = type(entry) == "table" and (entry.text or entry.plainText) or entry
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
        local text = type(entry) == "table" and (entry.text or entry.plainText) or entry
        local lineColor = type(entry) == "table" and entry.color or (i == 1 and C.white or C.muted)
        local gap = type(entry) == "table" and entry.gap or 0
        cy = cy + gap
        if type(entry) == "table" and entry.segments then
            love.graphics.printf(entry.segments, innerX, cy, innerW, "left")
        else
            color(lineColor)
            love.graphics.printf(tostring(text or ""), innerX, cy, innerW, "left")
        end
        cy = cy + wrappedLineCount(fontBody, text, innerW) * 19
    end
end

function drawTooltip(tip)
    if not tip then return end
    local mx, my = mousePosition()
    Tooltip.draw(tip, mx, my)
end

local weaponCompareValue
local compareColor

function diffText(delta, suffix)
    if math.abs(delta) < 0.001 then return "（±0" .. (suffix or "") .. "）" end
    local sign = delta > 0 and "+" or ""
    return "（" .. sign .. delta .. (suffix or "") .. "）"
end

function weaponHasProjectile(weapon)
    return (weapon.speed or 0) > 0 and not ((weapon.chain or 0) > 0 and (weapon.speed or 0) == 0)
end

function weaponDeliveryText(weapon)
    if weaponHasProjectile(weapon) then return "飞行弹体" end
    if (weapon.chain or 0) > 0 then return "连锁光束 · 无弹体" end
    return "即时命中 · 无弹体"
end

function elementRichLine(prefix, weapon, suffix)
    local elem = elements[(weapon and weapon.element) or "kinetic"] or elements.kinetic
    local text = prefix .. elem.name .. (suffix or "")
    return {plainText = text, segments = {C.muted, prefix, elem.color, elem.name, C.muted, suffix or ""}, color = elem.color}
end

function elementProcRichLine(prefix, weapon)
    local elem = elements[(weapon and weapon.element) or "kinetic"] or elements.kinetic
    local proc = elementProcText(weapon)
    local name = elem.name
    local rest = proc
    local startAt, endAt = proc:find(name, 1, true)
    if startAt == 1 then rest = proc:sub(endAt + 1) end
    local text = prefix .. proc
    return {plainText = text, segments = {C.muted, prefix, elem.color, name, elem.color, rest}, color = elem.color}
end

function weaponTooltip(weapon, titlePrefix, compareWeapon)
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
        elementRichLine("元素：", weapon, " · " .. elem.desc),
        elementProcRichLine("元素效果：", weapon),
        {text = "命中方式：" .. weaponDeliveryText(weapon), color = C.white},
        attr("单发伤害", v.damage, "damage", true, nil, 6),
        attr("弹体数量", v.count, "count", true),
        attr("总伤害", v.totalDamage, "totalDamage", true),
        attr("射程", v.range, "range", true),
        attr("穿透", v.pierce, "pierce", true),
        attr("弹射", v.bounce, "bounce", true)
    }
    if weaponHasProjectile(weapon) then lines[#lines + 1] = attr("弹速", v.speed, "speed", true) end
    local affixNames = {}
    for _, part in ipairs(weapon.parts or {}) do affixNames[#affixNames + 1] = part.tag or part.name end
    for _, tag in ipairs(weapon.affixTags or {}) do affixNames[#affixNames + 1] = tag end
    if weapon.legendaryDesc then affixNames[#affixNames + 1] = weapon.legendaryTitle or "传说协议" end
    local tagText = synergyTagTextFor and synergyTagTextFor(weapon) or "无"
    lines[#lines + 1] = {text = "羁绊标签：" .. tagText, color = C.gold, gap = 6}
    if #affixNames > 0 then lines[#lines + 1] = {text = "词缀：" .. table.concat(affixNames, " / "), color = C.gold, gap = 6} end
    local affixDetails = {}
    if weapon.legendaryDesc then affixDetails[#affixDetails + 1] = weapon.legendaryDesc end
    if weapon.splash then affixDetails[#affixDetails + 1] = "爆炸半径 " .. weapon.splash end
    if weapon.chain then affixDetails[#affixDetails + 1] = "连锁 " .. (weapon.chain + (p.gear.echoOverdrive and 1 or 0)) .. " 次" end
    if weapon.aura then affixDetails[#affixDetails + 1] = "牵引光环 " .. weapon.aura end
    if weapon.sixthPierce then affixDetails[#affixDetails + 1] = "每第 6 发 +1 穿透" end
    if weapon.sparkSplit then affixDetails[#affixDetails + 1] = "击杀分裂火花" end
    if weapon.echoRamp then affixDetails[#affixDetails + 1] = "弹射后伤害递增" end
    if weapon.voidSlow or weapon.heavy or weapon.overloadTax then affixDetails[#affixDetails + 1] = "高收益代价：开火短暂拖慢机体" end
    if weapon.killHaste then affixDetails[#affixDetails + 1] = "击杀后短暂提高射击节奏" end
    if weapon.executeLowHp then affixDetails[#affixDetails + 1] = "低血处刑增伤" end
    if weapon.hiveSplit then affixDetails[#affixDetails + 1] = "击杀后虫群分裂" end
    if weapon.arcMark then affixDetails[#affixDetails + 1] = "连锁叠电痕并爆电" end
    if weapon.voidCollapse then affixDetails[#affixDetails + 1] = "虚空光环周期坍缩" end
    if #affixDetails > 0 then lines[#lines + 1] = {text = "词缀说明：" .. table.concat(affixDetails, " / "), color = C.white, gap = 6} end
    if compareWeapon then lines[#lines + 1] = {text = "对比对象：当前装备的「" .. (compareWeapon.name or "武器") .. "」", color = C.gold, gap = 6} end
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

function weaponComparisonLines(current, candidate)
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

function waveThreatProfile(wave)
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

function itemRecommendationReason(item)
    if not item then return nil end
    local profile = waveThreatProfile(Game.wave)
    local desc = item.desc or ""
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        if profile.shield >= 20 and def.element == "arc" then return "下一波护盾目标偏多，电弧武器更有效。" end
        if profile.fire >= 3 and (def.range or 0) >= 760 then return "下一波有区域封锁，远射程更安全。" end
        if profile.boss > 0 and (def.damage or 0) * (def.count or 1) >= 20 then return "Boss/精英压力高，需要更强单轮输出。" end
    end
    if profile.shield >= 20 and (desc:find("护盾") or desc:find("电弧")) then return "下一波护盾敌人多，优先补电弧/护盾能力。" end
    if (profile.boss > 0 or profile.elite > 0) and desc:find("腐蚀") then return "下一波厚血目标多，腐蚀易伤更适合滚雪球。" end
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
    if profile.fire >= 3 then parts[#parts + 1] = "火" end
    if profile.charge >= 6 then parts[#parts + 1] = "冲" end
    if profile.ranged >= 18 then parts[#parts + 1] = "远" end
    if profile.shield >= 20 then parts[#parts + 1] = "盾" end
    if profile.armor >= 18 then parts[#parts + 1] = "厚" end
    return #parts > 0 and table.concat(parts, " / ") or "常规"
end

function moduleComboHintForItem(item)
    if not item or not isPermanentModule(item) then return nil end
    local key = mergeKeyForItem(item)
    local present = {}
    for _, owned in ipairs((Game.player and Game.player.items) or {}) do
        present[mergeKeyForItem(owned)] = true
    end
    present[key] = true
    local partial = nil
    for _, combo in ipairs(moduleCombos or {}) do
        local hasKey, missing = false, {}
        for _, req in ipairs(combo.requires or {}) do
            if req == key then hasKey = true end
            if not present[req] then missing[#missing + 1] = req end
        end
        if hasKey then
            local text = (combo.name or combo.id or "组合") .. "：" .. comboBonusText(combo)
            if #missing == 0 then return "已联动 " .. text end
            if #missing == 1 then partial = partial or ("可凑 " .. text) end
        end
    end
    return partial
end

function moduleSlotTooltip(item)
    if not item then return nil end
    local lines = {
        "价格：◆ " .. (item.price or 0),
        {text = "羁绊标签：" .. ((synergyTagTextFor and synergyTagTextFor(item)) or "无"), color = C.gold, gap = 6},
        {text = "效果：" .. modText(item.desc or "无效果"), color = C.white, gap = 6}
    }
    local combo = moduleComboHintForItem(item)
    if combo then lines[#lines + 1] = {text = "联动：" .. combo, color = C.gold, gap = 6} end
    return {title = item.name or "未知模块", lines = lines}
end

function itemTooltip(item)
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
        if not selected then
            tip.lines[#tip.lines + 1] = {text = "提示：先点击右侧武器槽，选择要对比的武器。", color = C.muted, gap = 8}
        end
        return tip
    end
    local lines = {
        "价格：◆ " .. (item.price or 0) .. " · " .. itemLevelText(item),
        {text = "类型：" .. kindText .. " · " .. kindDesc, color = C.muted},
        {text = "羁绊标签：" .. ((synergyTagTextFor and synergyTagTextFor(item)) or "无"), color = C.gold, gap = 6},
        {text = "效果：" .. modText(item.desc or "无说明"), color = C.white, gap = 6}
    }
    if item.flag then lines[#lines + 1] = {text = "词缀说明：" .. item.flag, color = C.gold, gap = 6} end
    return {title = "商品：" .. (item.name or "未知模块"), lines = lines}
end

function drawShopCard(item, i, x, y, w, h)
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
        local elem = elements[def.element] or elements.kinetic
        cardTags = {
            {text = rarityText, color = rc, primary = true},
            {text = kindText, color = C.white},
            {text = brand and brand.name or "武器", color = C.white},
            {text = elem.name, color = elem.color}
        }
    else
        local focus = item.mergeKey and ((item.mergeKey:gsub("_core", "")):gsub("_", " ")) or itemLevelText(item)
        cardTags = {
            {text = rarityText, color = rc, primary = true},
            {text = kindText, color = C.white},
            {text = itemLevelText(item), color = C.white}
        }
    end
    love.graphics.setFont(Game.fonts.tiny)
    drawTagRow(cardTags, x + 18, y + 13, w - 82)
    local topLockX, topLockY, topLockW, topLockH = x + w - 74, y + 10, 56, 30
    color(C.white, Game.locked[i] and 0.18 or 0.07)
    love.graphics.rectangle("fill", topLockX, topLockY, topLockW, topLockH, 9, 9)
    color(Game.locked[i] and C.white or C.muted, Game.locked[i] and 0.86 or 0.48)
    love.graphics.rectangle("line", topLockX + 0.5, topLockY + 0.5, topLockW - 1, topLockH - 1, 9, 9)
    textInBox(Game.locked[i] and "锁定" or "锁货", topLockX, topLockY, topLockW, topLockH, Game.fonts.tiny, Game.locked[i] and C.white or C.muted, "center")

    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf(compactDesc(item.name, 16), x + 18, y + 56, w - 36, "left")
    if item.kind ~= "weapon" then
        color(C.gold, 0.90)
        love.graphics.printf(itemLevelText(item), x + 18, y + 56, w - 36, "right")
    end
    love.graphics.setFont(Game.fonts.tiny)
    local missing = math.max(0, (item.price or 0) - Game.coins)
    local reason = itemRecommendationReason(item)
    if reason then
        drawCapsule("推荐", x + w - 74, y + 84, 56, 24, {font = Game.fonts.tiny, fg = C.bgA, border = C.gold, bg = C.gold, bgAlpha = affordable and 0.88 or 0.42, borderAlpha = 0.88, padX = 6})
    end

    local buyY = y + h - 36
    local displayY, displayH = y + 120, math.max(42, buyY - y - 130)
    color(C.white, 0.045)
    love.graphics.rectangle("fill", x + 18, displayY, w - 36, displayH, 12, 12)
    color(C.white, 0.18)
    love.graphics.rectangle("line", x + 18.5, displayY + 0.5, w - 37, displayH - 1, 12, 12)

    love.graphics.setFont(Game.fonts.tiny)
    if item.kind == "weapon" and item.id and weaponDefs[item.id] then
        local def = item.weaponDef or weaponDefs[item.id]
        local elem = elements[def.element] or elements.kinetic
        local rows = {
            {"伤害", tostring(def.damage)},
            {"弹体", tostring(def.count or 1)},
            {"射程", tostring(math.floor(def.range or 0))},
            {"元素", elem.name}
        }
        for ri, row in ipairs(rows) do
            local ry = displayY + 10 + (ri - 1) * 20
            if ry + 16 < displayY + displayH then
                textInBox(row[1], x + 34, ry, 54, 16, Game.fonts.tiny, C.muted, "left")
                textInBox(row[2], x + 92, ry, w - 126, 16, Game.fonts.tiny, row[1] == "元素" and elem.color or C.white, "left")
            end
        end
    else
        love.graphics.setFont(Game.fonts.tiny)
        local descText = modText(item.desc or "无说明")
        local effectColor = descText:find("%-") and C.red or (descText:find("%+") and C.green or C.muted)
        color(effectColor)
        love.graphics.printf(compactDesc(descText, 34), x + 34, displayY + 10, w - 68, "left")
    end
    local buyColor = affordable and C.green or C.red
    local buyBgAlpha = affordable and (hover and 0.34 or 0.18) or 0.10
    color(buyColor, buyBgAlpha)
    love.graphics.rectangle("fill", x + 18, buyY - 4, w - 36, 34, 10, 10)
    color(buyColor, affordable and (hover and 0.82 or 0.48) or 0.42)
    love.graphics.setLineWidth(hover and 2 or 1)
    love.graphics.rectangle("line", x + 18, buyY - 4, w - 36, 34, 10, 10)
    love.graphics.setLineWidth(1)
    local buyText = affordable and ("可购买  " .. i .. "  · 花费 ◆" .. item.price) or ("缺材料 " .. missing .. " · 需 ◆" .. item.price)
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

function drawBuildPanel(x, y, w, h)
    local p = Game.player
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("当前构筑", x, y + 14, w, "center")

    love.graphics.setFont(Game.fonts.tiny)
    local groups = buildAttributeGroups(p)
    local groupW, groupH, gap = (w - 42) / 2, 66, 10
    for i, group in ipairs(groups) do
        local gx = x + 14 + ((i - 1) % 2) * (groupW + gap)
        local gy = y + 54 + math.floor((i - 1) / 2) * (groupH + gap)
        drawAttributeGroupBox(group, gx, gy, groupW, groupH, false)
    end
    local resourceY = y + 54 + 2 * (groupH + gap) + 8
    color(C.white, 0.08)
    love.graphics.rectangle("fill", x + 14, resourceY, w - 28, 34, 8, 8)
    textInBox("吸血 " .. pct(p.stats.lifesteal or 0) .. " · 经济 " .. pct(p.stats.economy or 1) .. " · 拾取 " .. tostring(math.floor(p.pickup or 0)) .. " · 模块 " .. tostring(#(p.items or {})) .. "/" .. tostring(p.itemSlots or ITEM_SLOT_BASE), x + 24, resourceY, w - 48, 34, Game.fonts.tiny, C.white, "center")

    local wy = y + h - 84
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, wy - 12, w - 28, 1)
    color(C.gold)
    love.graphics.printf("武器", x, wy, w, "center")
    color(C.muted)
    local names = {}
    for i, weapon in ipairs(p.weapons) do
        names[#names + 1] = weapon.name
        if i >= WEAPON_SLOT_MAX then break end
    end
    love.graphics.printf(table.concat(names, " / "), x + 16, wy + 22, w - 32, "center")
end

local sellWeapon, sellShield, sellItem

function buildAttributeGroups(p)
    local stats = p.stats or {}
    return {
        {title = "生存", color = C.pink, rows = {
            "生命 " .. math.ceil(p.hp or 0) .. "/" .. tostring(p.maxHp or 0) .. " · 护盾 " .. math.ceil(p.shield or 0) .. "/" .. tostring(p.maxShield or 0),
            "回复 " .. string.format("%.1f", p.shieldRegen or 0) .. "/s · 移速 " .. tostring(math.floor(p.speed or 0))
        }},
        {title = "攻击", color = C.gold, rows = {
            "伤害 " .. pct(stats.damage or 1) .. " · 射速 " .. pct(stats.fireRate or 1),
            "暴击 " .. pct(stats.crit or 0) .. " · 暴伤 " .. pct(stats.critDamage or 1)
        }}
    }
end

function drawAttributeGroupBox(group, x, y, w, h, compact)
    local c = group.color or C.white
    color(c, 0.13)
    love.graphics.rectangle("fill", x, y, w, h, compact and 8 or 10, compact and 8 or 10)
    color(c, 0.42)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, compact and 8 or 10, compact and 8 or 10)
    love.graphics.setFont(Game.fonts.tiny)
    color(c)
    love.graphics.printf(group.title or "属性", x + 8, y + 5, w - 16, "left")
    color(C.white)
    love.graphics.printf(compactDesc(group.rows[1] or "", compact and 21 or 32), x + 8, y + (compact and 20 or 24), w - 16, "left")
    color(C.muted)
    love.graphics.printf(compactDesc(group.rows[2] or "", compact and 21 or 32), x + 8, y + (compact and 35 or 42), w - 16, "left")
end

function drawAttributeSummaryRow(group, x, y, w, h)
    local c = group.color or C.white
    color(c, 0.10)
    love.graphics.rectangle("fill", x, y, w, h, 7, 7)
    color(c, 0.34)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 7, 7)
    love.graphics.setFont(Game.fonts.tiny)
    color(c)
    love.graphics.printf(group.title or "属性", x + 8, y + 5, 42, "left")
    color(C.white)
    local text = compactDesc((group.rows[1] or "") .. " · " .. (group.rows[2] or ""), 38)
    love.graphics.printf(text, x + 54, y + 5, w - 64, "left")
end

function compactAttributeCards(p)
    local stats = p.stats or {}
    return {
        {label = "生命", value = math.ceil(p.hp or 0) .. "/" .. tostring(p.maxHp or 0), color = C.pink},
        {label = "护盾", value = math.ceil(p.shield or 0) .. "/" .. tostring(p.maxShield or 0), color = C.cyan},
        {label = "回复", value = string.format("%.1f/s", p.shieldRegen or 0), color = C.blue},
        {label = "移速", value = tostring(math.floor(p.speed or 0)), color = C.green},
        {label = "伤害", value = pct(stats.damage or 1), color = C.gold},
        {label = "射速", value = pct(stats.fireRate or 1), color = C.orange},
        {label = "暴击", value = pct(stats.crit or 0), color = C.gold},
        {label = "暴伤", value = pct(stats.critDamage or 1), color = C.red}
    }
end

function drawCompactStatTile(stat, x, y, w, h)
    local c = stat.color or C.white
    color(c, 0.12)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    color(c, 0.38)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 8, 8)
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf(stat.label or "属性", x + 8, y + 6, 42, "left")
    color(C.white)
    love.graphics.printf(stat.value or "-", x + 54, y + 6, w - 64, "right")
end

function drawCompactBuildPanel(x, y, w, h, opts)
    local p = Game.player
    opts = opts or {}
    local showSell = opts.showSell ~= false
    local mx, my = mousePosition()
    love.graphics.setColor(0, 0, 0, 0.86)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    color(C.white, 0.045)
    love.graphics.rectangle("fill", x + 6, y + 6, w - 12, h - 12, 16, 16)
    color(C.white, 0.18)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 18, 18)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("当前构筑", x + 14, y + 8, w - 28, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("槽位总览 · 模块在下方滚动", x + 108, y + 13, w - 122, "right")

    color(C.gold)
    love.graphics.printf("基础属性", x + 14, y + 38, w - 28, "left")
    color(C.muted)
    love.graphics.printf("生存 / 攻击", x + 14, y + 38, w - 28, "right")
    local stats = compactAttributeCards(p)
    local tileW, tileH, tileGap = (w - 40 - 10) / 2, 30, 7
    for i, stat in ipairs(stats) do
        local sx = x + 14 + ((i - 1) % 2) * (tileW + 10)
        local sy = y + 66 + math.floor((i - 1) / 2) * (tileH + tileGap)
        drawCompactStatTile(stat, sx, sy, tileW, tileH)
    end

    local slotW = (w - 44) / 2
    local slotGap = 12
    local weaponLabelY = y + 224
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, weaponLabelY - 12, w - 28, 1)
    color(C.orange)
    love.graphics.printf("武器槽 " .. #p.weapons .. "/" .. tostring(WEAPON_SLOT_MAX), x + 14, weaponLabelY, w - 28, "left")
    local weaponY = weaponLabelY + 28
    for i = 1, WEAPON_SLOT_MAX do
        local weapon = p.weapons[i]
        local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
        local sy = weaponY + math.floor((i - 1) / 2) * 52
        local accent = weapon and (elements[weapon.element] or elements.kinetic).color or C.white
        local selected = weapon and i == (Game.selectedWeaponIndex or 1)
        color(accent, weapon and 0.13 or 0.05)
        love.graphics.rectangle("fill", sx, sy, slotW, 44, 9, 9)
        color(selected and C.gold or accent, selected and 0.78 or (weapon and 0.44 or 0.18))
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", sx + 0.5, sy + 0.5, slotW - 1, 43, 9, 9)
        love.graphics.setLineWidth(1)
        if weapon then
            local nameW = slotW - (showSell and 78 or 20)
            love.graphics.setFont(Game.fonts.tiny)
            color(C.white)
            love.graphics.printf(compactDesc(weapon.name, showSell and 11 or 15), sx + 10, sy + 5, nameW, "left")
            color(C.gold)
            love.graphics.printf("◆" .. tostring(weapon.price or 0), sx + 10, sy + 24, nameW, "left")
        else
            textInBox("空武器槽", sx + 10, sy, slotW - 20, 44, Game.fonts.tiny, C.muted, "center")
        end
        if weapon and showSell then
            color(C.red, 0.14); love.graphics.rectangle("fill", sx + slotW - 54, sy + 8, 44, 28, 7, 7)
            color(C.red, 0.58); love.graphics.rectangle("line", sx + slotW - 54, sy + 8, 44, 28, 7, 7)
            textInBox("出售", sx + slotW - 54, sy + 8, 44, 28, Game.fonts.tiny, C.red, "center")
        end
        if weapon and hitRect(mx, my, sx, sy, slotW, 44) then
            local tip = weaponTooltip(weapon, selected and "当前武器 · 对比中" or "当前武器")
            tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击槽位选中；点击右侧“卖”出售。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
            return tip
        end
    end

    local shieldLabelY = weaponY + 2 * 52 + 22
    color(C.white, 0.12)
    love.graphics.rectangle("fill", x + 14, shieldLabelY - 12, w - 28, 1)
    color(C.cyan)
    love.graphics.printf("护盾槽", x + 14, shieldLabelY, w - 28, "left")
    local shieldY = shieldLabelY + 28
    local shield = p.shieldItem
    color(C.cyan, shield and 0.16 or 0.07)
    love.graphics.rectangle("fill", x + 14, shieldY, w - 28, 48, 10, 10)
    color(C.cyan, shield and 0.52 or 0.22)
    love.graphics.rectangle("line", x + 14.5, shieldY + 0.5, w - 29, 47, 10, 10)
    if shield then
        love.graphics.setFont(Game.fonts.tiny)
        color(C.white)
        love.graphics.printf(compactDesc(shield.name, showSell and 18 or 24), x + 26, shieldY + 6, w - (showSell and 160 or 100), "left")
        color(C.muted)
        love.graphics.printf("◆" .. tostring(shield.price or 0) .. " · " .. compactDesc(shield.desc or "护盾组件", 24), x + 26, shieldY + 27, w - (showSell and 160 or 100), "left")
    else
        textInBox("空护盾槽", x + 26, shieldY, w - 52, 48, Game.fonts.tiny, C.muted, "center")
    end
    if shield and showSell then
        color(C.red, 0.14); love.graphics.rectangle("fill", x + w - 78, shieldY + 10, 50, 28, 7, 7)
        color(C.red, 0.58); love.graphics.rectangle("line", x + w - 78, shieldY + 10, 50, 28, 7, 7)
        textInBox("出售", x + w - 78, shieldY + 10, 50, 28, Game.fonts.tiny, C.red, "center")
    else
        textInBox(shield and "1/1" or "0/1", x + w - 72, shieldY, 44, 48, Game.fonts.tiny, C.cyan, "right")
    end
    if shield and hitRect(mx, my, x + 14, shieldY, w - 28, 48) then
        local tip = itemTooltip(shield)
        tip.lines[#tip.lines + 1] = {text = showSell and "操作：点击右侧“卖”出售护盾。" or "当前暂停中：构筑信息只读展示。", color = C.gold, gap = 8}
        return tip
    end

    local items = p.items or {}
    local moduleY = shieldY + 84
    local moduleBottom = y + h - 16
    local moduleH = math.max(80, moduleBottom - moduleY)
    local slotCost = itemSlotUpgradeCost()
    local upX, upY, upW, upH = x + w - 146, moduleY - 34, 132, 28
    color(C.gold)
    love.graphics.printf("模块槽 Lv." .. (p.itemSlotLevel or 1) .. "  " .. #items .. "/" .. (p.itemSlots or ITEM_SLOT_BASE), x + 14, moduleY - 36, upX - x - 22, "left")
    color(C.muted)
    love.graphics.printf("效能 ×" .. string.format("%.2f", itemSlotEffectMultiplier()) .. " · 羁绊 " .. (p.synergySummary or "未成型") .. " · " .. #(p.synergies or {}) .. "项", x + 14, moduleY - 16, upX - x - 22, "left")
    local canUpgradeSlot = slotCost and Game.coins >= slotCost
    local upgradeText = slotCost and (canUpgradeSlot and ("升级 ◆" .. slotCost) or ("缺 " .. (slotCost - Game.coins))) or "满级"
    uiButton(upgradeText, upX, upY, upW, upH, canUpgradeSlot and C.green or (slotCost and C.red or C.muted), C.white, Game.fonts.tiny)

    local cardH, cardGap = 46, 8
    local visible = math.max(1, math.floor((moduleH + cardGap) / (cardH + cardGap)))
    local maxScroll = math.max(0, #items - visible)
    Game.buildModuleScroll = clamp(math.floor(Game.buildModuleScroll or 0), 0, maxScroll)
    local startIndex = Game.buildModuleScroll + 1
    if #items == 0 then
        color(C.white, 0.05)
        love.graphics.rectangle("fill", x + 14, moduleY, w - 28, 34, 8, 8)
        textInBox("暂无模块 · 购买模块后自动装备", x + 26, moduleY, w - 52, 34, Game.fonts.tiny, C.muted, "center")
    else
        for row = 0, visible - 1 do
            local idx = startIndex + row
            local item = items[idx]
            if not item then break end
            local sy = moduleY + row * (cardH + cardGap)
            local accent = shopItemAccent(item)
            color(accent, 0.12)
            love.graphics.rectangle("fill", x + 14, sy, w - 28, cardH, 8, 8)
            color(accent, 0.40)
            love.graphics.rectangle("line", x + 14.5, sy + 0.5, w - 29, cardH - 1, 8, 8)
            local comboHint = moduleComboHintForItem(item)
            local effectText = compactDesc(item.desc or itemLevelText(item), comboHint and 16 or 24)
            if comboHint then effectText = effectText .. " · " .. compactDesc(comboHint, 14) end
            color(C.white)
            love.graphics.printf(compactDesc(item.name, showSell and 12 or 16), x + 26, sy + 6, w - (showSell and 176 or 138), "left")
            textInBox("◆" .. tostring(item.price or 0), x + w - (showSell and 112 or 76), sy + 5, 52, 22, Game.fonts.tiny, C.gold, "center")
            color(C.muted)
            love.graphics.printf(effectText, x + 26, sy + 25, w - (showSell and 152 or 116), "left")
            if showSell then
                color(C.red, 0.14); love.graphics.rectangle("fill", x + w - 40, sy + 9, 26, 28, 7, 7)
                color(C.red, 0.58); love.graphics.rectangle("line", x + w - 40, sy + 9, 26, 28, 7, 7)
                textInBox("售", x + w - 40, sy + 9, 26, 28, Game.fonts.tiny, C.red, "center")
            end
            if hitRect(mx, my, x + 14, sy, w - 28, cardH) then
                return moduleSlotTooltip(item)
            end
        end
        if maxScroll > 0 then
            local barX = x + w - 8
            color(C.white, 0.10)
            love.graphics.rectangle("fill", barX, moduleY, 3, moduleH, 2, 2)
            local thumbH = math.max(26, moduleH * visible / math.max(visible, #items))
            local thumbY = moduleY + (moduleH - thumbH) * (Game.buildModuleScroll / math.max(1, maxScroll))
            color(C.gold, 0.48)
            love.graphics.rectangle("fill", barX, thumbY, 3, thumbH, 2, 2)
            color(C.muted)
            love.graphics.printf("滚轮查看更多", x + 14, moduleBottom - 18, w - 28, "center")
        end
    end
    return nil
end

function handleBuildPanelClick(px, py, x, y, w, h)
    local p = Game.player
    local slotW = (w - 44) / 2
    local slotGap = 12
    local weaponY = y + 164
    for i = 1, WEAPON_SLOT_MAX do
        local weapon = p.weapons[i]
        local sx = x + 14 + ((i - 1) % 2) * (slotW + slotGap)
        local sy = weaponY + math.floor((i - 1) / 2) * 52
        if weapon and hitRect(px, py, sx, sy, slotW, 44) then
            if hitRect(px, py, sx + slotW - 54, sy + 8, 44, 28) then return sellWeapon(i) end
            Game.selectedWeaponIndex = i
            playCue("shop"); toast("已选中武器槽 " .. i .. "：" .. weapon.name)
            return true
        end
    end

    local shieldY = y + 304
    if p.shieldItem and hitRect(px, py, x + w - 78, shieldY + 10, 50, 28) then return sellShield() end

    local items = p.items or {}
    local moduleY = shieldY + 84
    local moduleBottom = y + h - 16
    local moduleH = math.max(80, moduleBottom - moduleY)
    if hitRect(px, py, x + w - 146, moduleY - 34, 132, 28) then return upgradeItemSlots() end
    local cardH, cardGap = 46, 8
    local visible = math.max(1, math.floor((moduleH + cardGap) / (cardH + cardGap)))
    local maxScroll = math.max(0, #items - visible)
    Game.buildModuleScroll = clamp(math.floor(Game.buildModuleScroll or 0), 0, maxScroll)
    local startIndex = Game.buildModuleScroll + 1
    for row = 0, visible - 1 do
        local idx = startIndex + row
        if not items[idx] then break end
        local sy = moduleY + row * (cardH + cardGap)
        if hitRect(px, py, x + w - 40, sy + 9, 26, 28) then return sellItem(idx) end
    end
    return false
end

function defenseText(def)
    if def.defense == "armor" then return "护甲" end
    if def.defense == "shield" then return "护盾" end
    if def.defense == "flesh" then return "轻甲" end
    return "普通"
end


function affixDecisionHints(wave)
    local reward, penalty, protocol = affixesAt(wave or Game.wave)
    local profile = waveThreatProfile(wave or Game.wave)
    local buy, counter, avoid = {}, {}, {}
    local function add(list, text)
        if text and text ~= "" then list[#list + 1] = text end
    end
    for _, affix in ipairs({reward, penalty, protocol}) do
        if affix then
            if affix.coinMult and affix.coinMult > 1 then add(buy, "经济/回收：趁材料加成滚雪球") end
            if affix.playerDamage and affix.playerDamage > 1 then add(buy, "高射速/多弹：吃伤害加成") end
            if affix.critBonus and affix.critBonus > 0 then add(buy, "暴击流：直接吃暴击词缀") end
            if affix.elementDamage and affix.elementDamage > 1 then add(buy, "元素武器：电/火/腐蚀/冰优先") end
            if affix.shieldRegenMult and affix.shieldRegenMult > 1 then add(buy, "护盾反击：回盾更快") end
            if affix.shieldRegenMult and affix.shieldRegenMult < 1 then add(avoid, "少押回盾：补生命/机动") end
            if affix.enemyHp and affix.enemyHp > 1 then add(counter, "厚血：腐蚀/暴击/爆发") end
            if affix.enemyArmor and affix.enemyArmor > 0 then add(counter, "护甲：高伤/腐蚀，别刮痧") end
            if affix.enemySpeed and affix.enemySpeed > 1 then add(counter, "高速：冰冻/位移/护盾") end
            if affix.enemyDamage and affix.enemyDamage > 1 then add(counter, "高伤：生命/护盾优先") end
            if affix.extraPack and affix.extraPack > 0 then add(counter, "敌群：AOE/弹射/无人机") end
            if affix.intervalMult and affix.intervalMult < 1 then add(counter, "密集刷怪：清场效率优先") end
        end
    end
    if profile.shield >= 20 then add(counter, "护盾多：电弧/持续输出") end
    if profile.fire >= 3 then add(counter, "封锁：远射程/机动/临时盾") end
    if profile.charge >= 6 then add(counter, "冲锋：减速/冰冻/容错") end
    if profile.ranged >= 18 then add(counter, "远程：射程/弹速/护盾") end
    if profile.boss > 0 or profile.elite > 0 then add(counter, "Boss：爆发/腐蚀/暴击") end
    if #buy == 0 then add(buy, "补当前流派核心，少乱买") end
    if #counter == 0 then add(counter, "常规：伤害/射速/生存") end
    if #avoid == 0 then add(avoid, "别逆词缀买；缺清场别贪单体") end
    return buy, counter, avoid
end

function drawDecisionLine(label, text, x, y, w, accent)
    love.graphics.setFont(Game.fonts.tiny)
    color(accent, 0.14)
    love.graphics.rectangle("fill", x, y, w, 30, 9, 9)
    color(accent, 0.66)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, 29, 9, 9)
    color(accent)
    love.graphics.printf(label, x + 10, y + 8, 52, "left")
    color(C.white, 0.90)
    love.graphics.printf(text, x + 66, y + 8, w - 78, "left")
end

function drawAffixInfoPill(affix, label, x, y, w, h, mx, my)
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

function drawNextWavePanel(x, y, w, h)
    local mx, my = mousePosition()
    local tip = nil
    local plan = wavePlanAt(Game.wave)
    local reward, penalty, protocol = affixesAt(Game.wave)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.small)
    color(C.white)
    love.graphics.printf("下一波情报", x + 24, y + 18, w - 48, "left")
    color(C.gold)
    love.graphics.printf(chapterWaveLabel(Game.wave) .. " · " .. (plan.name or "清理敌群"), x + 24, y + 54, w - 48, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("10 大关 30 小关 · 每 3 小关打爆 Boss · 主要敌情：" .. waveThreatSummary(Game.wave), x + 24, y + 84, w - 48, "left")

    local buyHints, counterHints, avoidHints = affixDecisionHints(Game.wave)
    drawDecisionLine("买", buyHints[1], x + 24, y + 112, w - 48, C.green)
    drawDecisionLine("克制", counterHints[1], x + 24, y + 148, w - 48, C.gold)
    drawDecisionLine("避坑", avoidHints[1], x + 24, y + 184, w - 48, C.red)

    local affixY = 222
    if penalty and not reward and not protocol then
        tip = drawAffixInfoPill(penalty, "大关词缀", x + 24, y + affixY, w - 48, 54, mx, my) or tip
    else
        local pillW = (w - 62) / 2
        if protocol then tip = drawAffixInfoPill(protocol, "协议", x + 24, y + affixY, pillW, 50, mx, my) or tip end
        if reward then tip = drawAffixInfoPill(reward, "奖励", x + 38 + pillW, y + affixY, pillW, 50, mx, my) or tip end
        if penalty then tip = drawAffixInfoPill(penalty, "惩罚", x + 24, y + affixY + 56, w - 48, 46, mx, my) or tip end
    end

    love.graphics.setFont(Game.fonts.tiny)
    color(C.white)
    local enemyTitleY = y + 330
    love.graphics.printf("敌人构成", x + 24, enemyTitleY, w - 48, "left")
    local rowY = enemyTitleY + 28
    local total = 0
    for _, entry in ipairs(plan.enemies or {}) do total = total + (entry[2] or 0) end
    for i, entry in ipairs(plan.enemies or {}) do
        local key, weight = entry[1], entry[2]
        local def = enemyDefs[key]
        if def and i <= 5 then
            local chance = total > 0 and math.floor(weight / total * 100 + 0.5) or weight
            color(def.color, 0.07)
            love.graphics.rectangle("fill", x + 24, rowY, w - 48, 22, 7, 7)
            color(def.color, 0.78)
            love.graphics.printf(def.name, x + 36, rowY + 5, 112, "left")
            color(C.white, 0.82)
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

function drawSlotMachinePanel(x, y, w, h)
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

function drawSlotTabContent(x, y, w, h)
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

function drawVersion()
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted, 0.72)
    love.graphics.printf(VERSION, 0, Game.h - 28, Game.w - 30, "right")
end

shopTabs = {
    {id = "shop", label = "商店"},
    {id = "intel", label = "下一波情报"},
    {id = "slot", label = "补给转轮"}
}

function drawShopTabs(x, y)
    local active = Game.shopTab or "shop"
    local tabW, tabH, gap = 148, 44, 12
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

function shopTabHit(x, y)
    local startX, startY = 40, 38
    local tabW, tabH, gap = 148, 44, 12
    for i, tab in ipairs(shopTabs) do
        local tx = startX + (i - 1) * (tabW + gap)
        if hitRect(x, y, tx, startY, tabW, tabH) then return tab.id end
    end
end

function drawBuildTabContent(x, y, w, h)
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
        local brandText = (brand and brand.name or "武器") .. " · "
        love.graphics.printf(brandText, wx + 14, wy + 36, cardW - 28, "left")
        color(elem.color)
        love.graphics.printf(elem.name, wx + 14 + Game.fonts.tiny:getWidth(brandText), wy + 36, cardW - 28, "left")
        color(C.muted)
        local actualDamage = math.floor((weapon.damage or 0) * (p.stats.damage or 1) + 0.5)
        local detail = "伤害 " .. actualDamage .. "×" .. (weapon.count or 1) .. "  冷却 " .. string.format("%.2f", weapon.cooldown or 0) .. "s  范围 " .. math.floor(weapon.range or 0)
        local extra = "触发 " .. math.floor(elementStatusChance(weapon) * 100 + 0.5) .. "%  异常伤害 " .. elementStatusDamage(weapon) .. "/s"
        love.graphics.printf(detail, wx + 14, wy + 56, cardW - 28, "left")
        color(elem.color)
        love.graphics.printf(extra, wx + 14, wy + 72, cardW - 28, "left")
    end
end


archetypeCodex = {
    {name = "弹幕暴击", color = C.gold, desc = "多弹体、高暴击、击杀后追加弹射。弱点是前期单发偏低，吃暴击和站位。", keys = {"裂星机炮", "星针", "弱点扫描阵列", "弹幕校准"}},
    {name = "元素异常", color = C.orange, desc = "靠灼烧、电击、腐蚀易伤、霜冻和虚空异常处理不同目标。弱点是需要概率和元素伤害支撑。", keys = {"熔火炮", "腐蚀喷针", "冷井脉冲", "元素催化舱"}},
    {name = "护盾反击", color = C.cyan, desc = "把护盾当输出资源：满盾增伤、破盾电爆、击杀回盾。弱点是破盾窗口危险。", keys = {"电弧线圈", "反冲护盾线圈", "护盾回流", "满盾压制"}},
    {name = "召唤无人机", color = C.green, desc = "周期支援无人机弹、蜂群分裂、远距离自动压制。弱点是成型慢，占模块槽。", keys = {"蜂巢无人机", "无人机母巢", "无人机同步", "蜂群备份"}}
}

function drawCodexPanel(x, y, w, h)
    panel(x, y, w, h)
    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    love.graphics.printf("图鉴 / 流派与元素", x + 24, y + 20, w - 48, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("参考土豆兄弟：先看流派方向，再看武器、模块、元素和敌人克制。图鉴不消费材料。", x + 24, y + 54, w - 48, "left")

    local colW, gap = (w - 72) / 2, 24
    local cardH = 118
    for i, a in ipairs(archetypeCodex) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cx, cy = x + 24 + col * (colW + gap), y + 92 + row * (cardH + 18)
        color(a.color, 0.11)
        love.graphics.rectangle("fill", cx, cy, colW, cardH, 14, 14)
        color(a.color, 0.52)
        love.graphics.rectangle("line", cx + 0.5, cy + 0.5, colW - 1, cardH - 1, 14, 14)
        love.graphics.setFont(Game.fonts.small)
        color(a.color)
        love.graphics.printf(a.name, cx + 16, cy + 12, colW - 32, "left")
        love.graphics.setFont(Game.fonts.tiny)
        color(C.white)
        love.graphics.printf(a.desc, cx + 16, cy + 42, colW - 32, "left")
        color(C.muted)
        love.graphics.printf("关键：" .. table.concat(a.keys, " / "), cx + 16, cy + 88, colW - 32, "left")
    end

    local sectionY = y + 92 + 2 * (cardH + 18) + 18
    color(C.gold)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.printf("元素效果", x + 24, sectionY, w - 48, "left")
    local ex, ey = x + 24, sectionY + 34
    local ew = (w - 72) / 3
    local idx = 0
    for _, id in ipairs({"burn", "arc", "corrode", "ice", "void", "kinetic"}) do
        local elem = elements[id]
        idx = idx + 1
        local cx = ex + ((idx - 1) % 3) * (ew + 12)
        local cy = ey + math.floor((idx - 1) / 3) * 66
        color(elem.color, 0.12)
        love.graphics.rectangle("fill", cx, cy, ew, 52, 12, 12)
        color(elem.color, 0.44)
        love.graphics.rectangle("line", cx + 0.5, cy + 0.5, ew - 1, 51, 12, 12)
        love.graphics.setFont(Game.fonts.tiny)
        color(elem.color)
        love.graphics.printf(elem.name .. " · " .. (elem.status or "效果"), cx + 12, cy + 8, ew - 24, "left")
        color(C.muted)
        love.graphics.printf(elem.desc, cx + 12, cy + 28, ew - 24, "left")
    end

    local enemyY = ey + 142
    color(C.red)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.printf("敌人防御", x + 24, enemyY, w - 48, "left")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    love.graphics.printf("护盾敌人显示蓝色护盾条和外圈；电击对护盾增伤并可破盾电爆。腐蚀改为叠层易伤/持续伤害，轻甲敌更怕灼烧。", x + 24, enemyY + 34, w - 48, "left")
end

function drawShop()
    panel(18, 18, Game.w - 36, Game.h - 36)
    local clearedWave = math.max(1, Game.wave - 1)
    local marginX = 40
    local tabY = 38
    local contentY, contentH = 154, Game.h - 200
    local actionY, actionH = 42, 42
    local nextW = 230
    local actionX = Game.w - marginX - nextW
    drawShopTabs(marginX, tabY)

    love.graphics.setFont(Game.fonts.normal)
    color(C.white)
    local infoX, infoW = 590, actionX - 610
    love.graphics.printf("商店 · " .. chapterWaveLabel(clearedWave), infoX, 38, infoW, "center")
    love.graphics.setFont(Game.fonts.tiny)
    color(C.muted)
    local shieldText = Game.player.shieldItem and "护盾槽 1/1" or "护盾槽 0/1"
    local incomeText = Game.lastWaveIncome and ("上波收入 +" .. Game.lastWaveIncome .. " · ") or ""
    love.graphics.printf("当前材料 ◆" .. Game.coins .. " · " .. incomeText .. shopBudgetHint() .. " · 武器槽 " .. #Game.player.weapons .. "/" .. tostring(WEAPON_SLOT_MAX) .. " · " .. shieldText .. " · 模块槽 Lv." .. (Game.player.itemSlotLevel or 1) .. " " .. #(Game.player.items or {}) .. "/" .. (Game.player.itemSlots or ITEM_SLOT_BASE), infoX, 74, infoW, "center")

    local rerollCost = 3 + Game.shopRefresh * 2
    uiButton("进入下一波", actionX, actionY, nextW, actionH, C.gold, C.white, Game.fonts.small)

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
        local tabRefreshW, tabRefreshH = 210, 34
        local tabRefreshX, tabRefreshY = marginX + shelfW - tabRefreshW, weaponY - 40
        local refreshText = Game.freeRefresh > 0 and ("刷新商店 · 免费 x" .. Game.freeRefresh) or ("刷新商店 · ◆" .. rerollCost)
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf("武器架 · 3 选 1", marginX, weaponY - 34, shelfW - tabRefreshW - 16, "left")
        uiButton(refreshText, tabRefreshX, tabRefreshY, tabRefreshW, tabRefreshH, C.cyan, C.white, Game.fonts.tiny)
        color(C.white, 0.08)
        love.graphics.rectangle("fill", marginX, weaponY - 8, shelfW, 10, 5, 5)
        color(C.white, 0.16)
        love.graphics.rectangle("fill", marginX, weaponY + cardH + 10, shelfW, 8, 4, 4)
        color(C.white)
        love.graphics.printf("装备箱", marginX, supportY - 34, shelfW, "left")
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

function drawPauseOverlay()
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
    local tip = drawCompactBuildPanel(rightX, y + 28, rightW, h - 56, {showSell = false})
    drawTooltip(tip)
end

function drawEnd(title, subtitle, c)
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

function drawClearTransitionOverlay()
    if Game.state ~= "clearing" then return end
    local t = Game.clearTransition or {timer = 0}
    local alpha = clamp(0.22 + math.sin((t.timer or 0) * 18) * 0.08, 0.12, 0.34)
    love.graphics.setBlendMode("add")
    color(C.cyan, alpha)
    love.graphics.rectangle("fill", 0, 138, Game.w, Game.h - 204)
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(Game.fonts.big)
    color(C.white, 0.92)
    love.graphics.printf("目标完成 · 敌群清空", 0, 168, Game.w, "center")
end

local function drawChoiceOverlay(kind, title, subtitle, choices)
    choices = choices or {}
    local n = math.max(1, #choices)
    local overlay = kind == "event" and 0.58 or 0.38
    color(C.bgA, overlay)
    love.graphics.rectangle("fill", 0, 0, Game.w, Game.h)
    local panelW, panelH = 1480, 500
    local panelX, panelY = Game.w / 2 - panelW / 2, Game.h / 2 - panelH / 2
    panel(panelX, panelY, panelW, panelH)
    love.graphics.setFont(Game.fonts.big)
    color(C.white)
    love.graphics.printf(title, panelX + 32, panelY + 26, panelW - 64, "center")
    love.graphics.setFont(Game.fonts.small)
    color(C.muted)
    love.graphics.printf(subtitle, panelX + 120, panelY + 92, panelW - 240, "center")
    color(C.white, 0.10)
    love.graphics.rectangle("fill", panelX + 70, panelY + 136, panelW - 140, 1)
    local mx, my = mousePosition()
    local cardW, cardH, gap = 430, 250, 34
    local sx, sy = Game.w / 2 - (cardW * n + gap * (n - 1)) / 2, Game.h / 2 - cardH / 2 + 86
    for i, choice in ipairs(choices) do
        local x, y = sx + (i - 1) * (cardW + gap), sy
        local hover = hitRect(mx, my, x, y, cardW, cardH)
        local accent = i == 1 and C.cyan or (i == 2 and C.gold or C.purple)
        color(accent, hover and 0.20 or 0.10)
        love.graphics.rectangle("fill", x, y, cardW, cardH, 18, 18)
        color(accent, hover and 0.82 or 0.42)
        love.graphics.setLineWidth(hover and 3 or 2)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, cardW - 1, cardH - 1, 18, 18)
        love.graphics.setLineWidth(1)
        drawCapsule(tostring(i), x + 18, y + 16, 42, 30, {font = Game.fonts.tiny, fg = C.bgA, border = accent, bg = accent, bgAlpha = 0.88, align = "center"})
        love.graphics.setFont(Game.fonts.small)
        color(C.white)
        love.graphics.printf(choice.name or "未知选择", x + 70, y + 18, cardW - 92, "left")
        love.graphics.setFont(Game.fonts.tiny)
        color(C.cyan, 0.92)
        love.graphics.printf("收益", x + 24, y + 66, cardW - 48, "left")
        color(C.white)
        love.graphics.printf(choice.desc or "", x + 24, y + 88, cardW - 48, "left")
        color(C.red, 0.12)
        love.graphics.rectangle("fill", x + 20, y + 140, cardW - 40, 48, 10, 10)
        color(C.red, 0.48)
        love.graphics.rectangle("line", x + 20.5, y + 140.5, cardW - 41, 47, 10, 10)
        color(C.red, 0.92)
        love.graphics.printf("代价", x + 34, y + 150, 48, "left")
        color(C.white)
        love.graphics.printf(choice.risk or "无", x + 92, y + 150, cardW - 126, "left")
        color(C.gold, 0.92)
        love.graphics.printf("点击或按 " .. tostring(i) .. " 选择", x + 24, y + cardH - 38, cardW - 48, "center")
    end
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
    if Game.state == "codex" then drawCodexPanel(90, 92, Game.w - 180, Game.h - 170); uiButton("返回主菜单", Game.w / 2 - 130, Game.h - 70, 260, 44, C.cyan, C.white, Game.fonts.small); drawVersion(); love.graphics.pop(); return end
    if Game.state == "route_choice" then drawChoiceOverlay("route", "选择下一章路线", "Boss 后路线选择：风险与回报一起拿，下一章内生效。", Game.routeChoices); drawVersion(); love.graphics.pop(); return end
    if Game.state == "shop" then drawShop(); drawVersion(); love.graphics.pop(); return end
    if Game.state == "levelup" then drawWorld(); drawHud(); drawLevelUp(); drawVersion(); love.graphics.pop(); return end
    drawWorld()
    drawHud()
    drawCombatWarningOverlay()
    drawClearTransitionOverlay()
    if Game.state == "event_choice" then drawChoiceOverlay("event", Game.eventChoiceTitle or "战前随机事件", "战斗前先选本波风险/回报；选完立即开打，不再中途打断。", Game.eventChoices); drawVersion(); love.graphics.pop(); return end
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
    return true
end

function sellValue(item, fallback)
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
    if Game.state == "route_choice" then
        local idx = choiceIndexAt(x, y, #(Game.routeChoices or {}))
        if idx then chooseRoute(idx); return true end
    elseif Game.state == "event_choice" then
        local idx = choiceIndexAt(x, y, #(Game.eventChoices or {}))
        if idx then chooseEvent(idx); return true end
    elseif Game.state == "menu" then
        local deckX, deckY, deckW = 90, Game.h - 168, Game.w - 180
        local diffX, diffY, diffW = deckX + deckW - 406, deckY + 18, 378
        if hitRect(x, y, diffX + 18, diffY + 60, 154, 34) then Game.danger = math.max(0, Game.danger - 1); return true end
        if hitRect(x, y, diffX + diffW - 172, diffY + 60, 154, 34) then Game.danger = math.min(6, Game.danger + 1); return true end
        if hitRect(x, y, Game.w / 2 - 140, deckY + 24, 280, 54) then resetRun(); return true end
        if hitRect(x, y, Game.w / 2 - 90, deckY + 84, 180, 30) then Game.state = "codex"; return true end
    elseif Game.state == "codex" then
        if hitRect(x, y, Game.w / 2 - 130, Game.h - 70, 260, 44) then Game.state = "menu"; return true end
    elseif Game.state == "levelup" then
        local w, h, gap = 330, 206, 34
        local sx = Game.w / 2 - (w * 3 + gap * 2) / 2
        for i = 1, 3 do
            local cx = sx + (i - 1) * (w + gap)
            if hitRect(x, y, cx, 484, w, h) then chooseLevelReward(i); return true end
        end
    elseif Game.state == "shop" then
        local marginX = 40
        local actionY, actionH = 42, 42
        local nextW = 230
        local actionX = Game.w - marginX - nextW
        if hitRect(x, y, actionX, actionY, nextW, actionH) then startWave(); return true end

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
            local tabRefreshW, tabRefreshH = 210, 34
            local tabRefreshX, tabRefreshY = marginX + shelfW - tabRefreshW, weaponY - 40
            if hitRect(x, y, tabRefreshX, tabRefreshY, tabRefreshW, tabRefreshH) then refreshShop(); return true end
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

function love.wheelmoved(_, y)
    if Game.state ~= "shop" then return end
    local marginX, contentY, contentH = 40, 154, Game.h - 200
    local sideW = 430
    local sideX = Game.w - marginX - sideW
    local mx, my = mousePosition()
    if not hitRect(mx, my, sideX, contentY, sideW, contentH) then return end
    local items = Game.player.items or {}
    local moduleY = contentY + 304 + 84
    local moduleH = math.max(80, contentY + contentH - 16 - moduleY)
    local visible = math.max(1, math.floor((moduleH + 8) / (46 + 8)))
    local maxScroll = math.max(0, #items - visible)
    Game.buildModuleScroll = clamp((Game.buildModuleScroll or 0) - y, 0, maxScroll)
end

function love.keypressed(key)
    if key == "escape" then
        if Game.state == "playing" then Game.state = "paused"; toast("已暂停"); return end
        if Game.state == "paused" then Game.state = "playing"; toast("继续战斗"); return end
        if Game.state == "codex" then Game.state = "menu"; return end
        if Game.state == "gameover" or Game.state == "victory" then Game.state = "menu"; return end
        love.event.quit()
    end

    if key == "space" and Game.state == "playing" then useActiveSkill(); return end

    if Game.state == "paused" then return end

    if Game.state == "route_choice" then
        if key == "1" then chooseRoute(1) end
        if key == "2" then chooseRoute(2) end
        if key == "3" then chooseRoute(3) end
        return
    end
    if Game.state == "event_choice" then
        if key == "1" then chooseEvent(1) end
        if key == "2" then chooseEvent(2) end
        if key == "3" then chooseEvent(3) end
        return
    end

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
        elseif Game.state == "codex" then Game.state = "menu"
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
        if key == "tab" then Game.shopTab = (Game.shopTab == "shop") and "intel" or ((Game.shopTab == "intel") and "slot" or "shop"); return end
        if key == "e" then recycleWeapon() end
        if key == "u" then upgradeItemSlots() end
        if key == "s" then spinSlotMachine(); return end
        if key == "r" then
            if not (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then toast("刷新需按 Shift+R，避免误触"); return end
            refreshShop()
        end
    end
end
