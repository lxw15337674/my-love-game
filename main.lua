-- main.lua
-- 星河告白 / Stardrift Promise
-- A complete tiny LÖVE 11.x arcade game written without external assets.

local Game = {
    width = 1280,
    height = 720,
    state = "menu", -- menu, playing, paused, victory, gameover
    time = 0,
    score = 0,
    best = 0,
    combo = 0,
    comboTimer = 0,
    targetLetters = {"L", "O", "V", "E"},
    collectedLetters = {},
    message = "",
    messageTimer = 0,
    shake = 0,
    mouseWasDown = false,
    particles = {},
    stars = {},
    hazards = {},
    shards = {},
    player = {
        x = 180,
        y = 360,
        r = 18,
        speed = 300,
        hp = 5,
        invincible = 0,
        trailTimer = 0
    },
    goal = {
        x = 1090,
        y = 360,
        r = 42,
        pulse = 0
    },
    spawn = {
        shard = 0,
        hazard = 0
    },
    fonts = {}
}

local TAU = math.pi * 2

local palette = {
    bg1 = {0.035, 0.040, 0.090},
    bg2 = {0.120, 0.055, 0.160},
    pink = {1.000, 0.270, 0.510},
    rose = {1.000, 0.470, 0.650},
    gold = {1.000, 0.760, 0.300},
    cyan = {0.230, 0.820, 1.000},
    blue = {0.190, 0.310, 0.800},
    white = {0.950, 0.970, 1.000},
    muted = {0.610, 0.660, 0.800},
    danger = {1.000, 0.170, 0.250},
    panel = {0.040, 0.045, 0.100, 0.760}
}

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function setColor(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function newFont(size)
    return love.graphics.newFont(size)
end

local function font(name)
    return Game.fonts[name]
end

local function drawHeart(x, y, s, mode)
    local vertices = {}
    for i = 0, 54 do
        local t = (i / 54) * TAU
        local hx = 16 * math.sin(t) ^ 3
        local hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        table.insert(vertices, x + hx * s)
        table.insert(vertices, y + hy * s)
    end
    love.graphics.polygon(mode or "fill", vertices)
end

local function addParticle(x, y, color, count, speed)
    for _ = 1, count or 10 do
        local a = love.math.random() * TAU
        local v = love.math.random(30, speed or 160)
        table.insert(Game.particles, {
            x = x,
            y = y,
            vx = math.cos(a) * v,
            vy = math.sin(a) * v,
            life = love.math.random(35, 85) / 100,
            maxLife = love.math.random(35, 85) / 100,
            size = love.math.random(2, 6),
            color = color
        })
    end
end

local function toast(text)
    Game.message = text
    Game.messageTimer = 1.5
end

local function hasLetter(letter)
    for _, got in ipairs(Game.collectedLetters) do
        if got == letter then return true end
    end
    return false
end

local function nextLetter()
    return Game.targetLetters[#Game.collectedLetters + 1]
end

local function resetStars()
    Game.stars = {}
    for _ = 1, 140 do
        table.insert(Game.stars, {
            x = love.math.random() * Game.width,
            y = love.math.random() * Game.height,
            r = love.math.random(8, 24) / 10,
            speed = love.math.random(10, 48),
            twinkle = love.math.random() * TAU
        })
    end
end

local function spawnShard(forceLetter)
    local letter = forceLetter
    if not letter then
        if love.math.random() < 0.38 and nextLetter() then
            letter = nextLetter()
        elseif love.math.random() < 0.5 then
            letter = ({"L", "O", "V", "E"})[love.math.random(1, 4)]
        end
    end

    table.insert(Game.shards, {
        x = love.math.random(260, Game.width - 160),
        y = love.math.random(90, Game.height - 110),
        r = letter and 19 or 13,
        letter = letter,
        phase = love.math.random() * TAU,
        drift = love.math.random(16, 36),
        life = 9.5
    })
end

local function spawnHazard()
    local side = love.math.random(1, 4)
    local x, y, vx, vy
    local speed = love.math.random(95, 180) + Game.time * 2.5
    if side == 1 then
        x, y = -40, love.math.random(80, Game.height - 80)
        vx, vy = speed, love.math.random(-40, 40)
    elseif side == 2 then
        x, y = Game.width + 40, love.math.random(80, Game.height - 80)
        vx, vy = -speed, love.math.random(-40, 40)
    elseif side == 3 then
        x, y = love.math.random(80, Game.width - 80), -40
        vx, vy = love.math.random(-45, 45), speed
    else
        x, y = love.math.random(80, Game.width - 80), Game.height + 40
        vx, vy = love.math.random(-45, 45), -speed
    end

    table.insert(Game.hazards, {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        r = love.math.random(15, 27),
        spin = love.math.random() * TAU,
        spinSpeed = love.math.random(-4, 4),
        glow = love.math.random() * TAU
    })
end

local function resetGame()
    Game.state = "playing"
    Game.time = 0
    Game.score = 0
    Game.combo = 0
    Game.comboTimer = 0
    Game.message = ""
    Game.messageTimer = 0
    Game.shake = 0
    Game.player.x = 170
    Game.player.y = Game.height / 2
    Game.player.hp = 5
    Game.player.invincible = 0
    Game.hazards = {}
    Game.shards = {}
    Game.particles = {}
    Game.collectedLetters = {}
    Game.spawn.shard = 0.25
    Game.spawn.hazard = 1.0
    for _, letter in ipairs(Game.targetLetters) do
        spawnShard(letter)
    end
    toast("Collect L O V E, then reach the heart gate")
end

local function completeGame()
    Game.state = "victory"
    Game.best = math.max(Game.best, Game.score)
    addParticle(Game.goal.x, Game.goal.y, palette.gold, 80, 260)
    addParticle(Game.player.x, Game.player.y, palette.rose, 60, 240)
end

function love.load()
    love.window.setTitle("Stardrift Promise")
    love.graphics.setDefaultFilter("linear", "linear")
    love.math.setRandomSeed(os.time())
    Game.width, Game.height = love.graphics.getDimensions()
    Game.fonts = {
        tiny = newFont(14),
        small = newFont(18),
        normal = newFont(24),
        title = newFont(58),
        huge = newFont(78)
    }
    resetStars()
end

local function updatePlaying(dt)
    Game.time = Game.time + dt
    Game.goal.pulse = Game.goal.pulse + dt * 2.2

    local p = Game.player
    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end

    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        dx, dy = mx - p.x, my - p.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 12 then dx, dy = dx / len, dy / len else dx, dy = 0, 0 end
    elseif dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end

    p.x = clamp(p.x + dx * p.speed * dt, 32, Game.width - 32)
    p.y = clamp(p.y + dy * p.speed * dt, 48, Game.height - 42)
    p.invincible = math.max(0, p.invincible - dt)
    p.trailTimer = p.trailTimer - dt
    if p.trailTimer <= 0 and (dx ~= 0 or dy ~= 0) then
        p.trailTimer = 0.035
        table.insert(Game.particles, {
            x = p.x,
            y = p.y,
            vx = love.math.random(-18, 18),
            vy = love.math.random(-18, 18),
            life = 0.38,
            maxLife = 0.38,
            size = love.math.random(4, 8),
            color = palette.cyan
        })
    end

    Game.spawn.shard = Game.spawn.shard - dt
    if Game.spawn.shard <= 0 then
        spawnShard()
        Game.spawn.shard = love.math.random(115, 175) / 100
    end

    Game.spawn.hazard = Game.spawn.hazard - dt
    if Game.spawn.hazard <= 0 then
        spawnHazard()
        Game.spawn.hazard = math.max(0.38, 1.2 - Game.time * 0.012)
    end

    if Game.comboTimer > 0 then
        Game.comboTimer = Game.comboTimer - dt
    else
        Game.combo = 0
    end

    for i = #Game.shards, 1, -1 do
        local s = Game.shards[i]
        s.phase = s.phase + dt * 2.5
        s.life = s.life - dt
        s.y = s.y + math.sin(s.phase) * s.drift * dt
        if s.life <= 0 then
            table.remove(Game.shards, i)
        elseif dist(p.x, p.y, s.x, s.y) < p.r + s.r then
            table.remove(Game.shards, i)
            Game.combo = Game.combo + 1
            Game.comboTimer = 2.2
            local gain = s.letter and 90 or 25
            Game.score = Game.score + gain + Game.combo * 8
            if s.letter and s.letter == nextLetter() then
                table.insert(Game.collectedLetters, s.letter)
                toast("Letter " .. s.letter .. " captured")
                addParticle(s.x, s.y, palette.gold, 26, 190)
            elseif s.letter and hasLetter(s.letter) then
                toast("Extra spark +" .. tostring(gain))
                addParticle(s.x, s.y, palette.rose, 16, 140)
            elseif s.letter then
                toast("Wrong order. Spell L O V E")
                Game.score = math.max(0, Game.score - 25)
                addParticle(s.x, s.y, palette.muted, 12, 110)
            else
                addParticle(s.x, s.y, palette.cyan, 14, 130)
            end
        end
    end

    for i = #Game.hazards, 1, -1 do
        local h = Game.hazards[i]
        h.x = h.x + h.vx * dt
        h.y = h.y + h.vy * dt
        h.spin = h.spin + h.spinSpeed * dt
        h.glow = h.glow + dt * 4
        if h.x < -100 or h.x > Game.width + 100 or h.y < -100 or h.y > Game.height + 100 then
            table.remove(Game.hazards, i)
        elseif p.invincible <= 0 and dist(p.x, p.y, h.x, h.y) < p.r + h.r then
            p.hp = p.hp - 1
            p.invincible = 1.1
            Game.combo = 0
            Game.shake = 0.32
            table.remove(Game.hazards, i)
            addParticle(p.x, p.y, palette.danger, 34, 230)
            if p.hp <= 0 then
                Game.state = "gameover"
                Game.best = math.max(Game.best, Game.score)
            else
                toast("Careful. The void bites.")
            end
        end
    end

    if #Game.collectedLetters == #Game.targetLetters and dist(p.x, p.y, Game.goal.x, Game.goal.y) < p.r + Game.goal.r then
        Game.score = Game.score + 500 + p.hp * 80
        completeGame()
    end
end

function love.update(dt)
    Game.width, Game.height = love.graphics.getDimensions()

    for _, star in ipairs(Game.stars) do
        star.x = star.x - star.speed * dt
        star.twinkle = star.twinkle + dt * 2
        if star.x < -5 then
            star.x = Game.width + 5
            star.y = love.math.random() * Game.height
        end
    end

    for i = #Game.particles, 1, -1 do
        local p = Game.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(Game.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * (1 - dt * 1.6)
            p.vy = p.vy * (1 - dt * 1.6)
        end
    end

    Game.messageTimer = math.max(0, Game.messageTimer - dt)
    Game.shake = math.max(0, Game.shake - dt)

    if Game.state == "playing" then
        updatePlaying(dt)
    end
end

local function drawBackground()
    love.graphics.clear(palette.bg1)
    for i = 0, 18 do
        local t = i / 18
        love.graphics.setColor(lerp(palette.bg1[1], palette.bg2[1], t), lerp(palette.bg1[2], palette.bg2[2], t), lerp(palette.bg1[3], palette.bg2[3], t), 1)
        love.graphics.rectangle("fill", 0, Game.height * t, Game.width, Game.height / 18 + 1)
    end

    for _, star in ipairs(Game.stars) do
        local alpha = 0.35 + math.sin(star.twinkle) * 0.25
        love.graphics.setColor(0.70, 0.82, 1, alpha)
        love.graphics.circle("fill", star.x, star.y, star.r)
    end

    love.graphics.setColor(0.35, 0.12, 0.42, 0.18)
    love.graphics.circle("fill", Game.width * 0.78, Game.height * 0.22, 180)
    love.graphics.setColor(0.13, 0.55, 0.82, 0.11)
    love.graphics.circle("fill", Game.width * 0.18, Game.height * 0.72, 230)
end

local function drawPanel(x, y, w, h)
    setColor(palette.panel)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 18, 18)
end

local function drawHud()
    drawPanel(22, 18, 360, 76)
    love.graphics.setFont(font("normal"))
    setColor(palette.white)
    love.graphics.print("Score " .. Game.score, 42, 30)
    love.graphics.setFont(font("small"))
    setColor(palette.muted)
    love.graphics.print("Best " .. Game.best, 44, 62)
    if Game.combo > 1 then
        setColor(palette.gold)
        love.graphics.print("Combo x" .. Game.combo, 170, 62)
    end

    drawPanel(Game.width - 260, 18, 232, 76)
    love.graphics.setFont(font("small"))
    setColor(palette.muted)
    love.graphics.print("HEART", Game.width - 238, 32)
    for i = 1, 5 do
        if i <= Game.player.hp then setColor(palette.pink) else love.graphics.setColor(1, 1, 1, 0.14) end
        drawHeart(Game.width - 172 + i * 26, 58, 0.55)
    end

    drawPanel(Game.width / 2 - 154, 18, 308, 76)
    love.graphics.setFont(font("small"))
    setColor(palette.muted)
    love.graphics.printf("PROMISE", Game.width / 2 - 154, 29, 308, "center")
    love.graphics.setFont(font("normal"))
    for i, letter in ipairs(Game.targetLetters) do
        local x = Game.width / 2 - 88 + (i - 1) * 58
        if Game.collectedLetters[i] == letter then setColor(palette.gold) else love.graphics.setColor(1, 1, 1, 0.18) end
        love.graphics.printf(letter, x, 53, 36, "center")
    end
end

local function drawGoal()
    local ready = #Game.collectedLetters == #Game.targetLetters
    local pulse = 1 + math.sin(Game.goal.pulse) * 0.08
    love.graphics.setColor(ready and palette.gold[1] or 0.35, ready and palette.gold[2] or 0.18, ready and palette.gold[3] or 0.42, ready and 0.26 or 0.16)
    love.graphics.circle("fill", Game.goal.x, Game.goal.y, Game.goal.r * 1.85 * pulse)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(ready and palette.gold[1] or 0.65, ready and palette.gold[2] or 0.35, ready and palette.gold[3] or 0.75, 0.82)
    love.graphics.circle("line", Game.goal.x, Game.goal.y, Game.goal.r * pulse)
    setColor(ready and palette.pink or palette.muted, ready and 1 or 0.45)
    drawHeart(Game.goal.x, Game.goal.y + 2, 1.15 * pulse, "fill")
    love.graphics.setLineWidth(1)
end

local function drawPlayer()
    local p = Game.player
    local blink = p.invincible > 0 and math.floor(p.invincible * 18) % 2 == 0
    if blink then return end
    love.graphics.setColor(palette.cyan[1], palette.cyan[2], palette.cyan[3], 0.20)
    love.graphics.circle("fill", p.x, p.y, p.r * 2.2)
    setColor(palette.cyan)
    drawHeart(p.x, p.y + 2, 0.72)
    love.graphics.setColor(1, 1, 1, 0.86)
    love.graphics.circle("line", p.x, p.y, p.r + 4)
end

local function drawShard(s)
    local wobble = math.sin(s.phase) * 3
    if s.letter then
        love.graphics.setColor(palette.gold[1], palette.gold[2], palette.gold[3], 0.18)
        love.graphics.circle("fill", s.x, s.y + wobble, 30)
        setColor(palette.gold)
        love.graphics.circle("fill", s.x, s.y + wobble, s.r)
        love.graphics.setColor(0.13, 0.08, 0.08, 0.82)
        love.graphics.setFont(font("normal"))
        love.graphics.printf(s.letter, s.x - 18, s.y - 13 + wobble, 36, "center")
    else
        setColor(palette.rose)
        drawHeart(s.x, s.y + wobble, 0.42)
    end
end

local function drawHazard(h)
    love.graphics.push()
    love.graphics.translate(h.x, h.y)
    love.graphics.rotate(h.spin)
    love.graphics.setColor(palette.danger[1], palette.danger[2], palette.danger[3], 0.20 + math.sin(h.glow) * 0.05)
    love.graphics.circle("fill", 0, 0, h.r * 1.7)
    setColor(palette.danger)
    love.graphics.polygon("fill", 0, -h.r, h.r * 0.86, h.r * 0.5, -h.r * 0.86, h.r * 0.5)
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.polygon("line", 0, -h.r, h.r * 0.86, h.r * 0.5, -h.r * 0.86, h.r * 0.5)
    love.graphics.pop()
end

local function drawParticles()
    for _, p in ipairs(Game.particles) do
        local a = clamp(p.life / p.maxLife, 0, 1)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a * 0.72)
        love.graphics.circle("fill", p.x, p.y, p.size * a)
    end
end

local function drawCentered(text, y, f, color)
    love.graphics.setFont(f)
    setColor(color or palette.white)
    love.graphics.printf(text, 0, y, Game.width, "center")
end

local function drawMenu()
    drawCentered("STARDRIFT", 178, font("title"), palette.white)
    drawCentered("PROMISE", 238, font("huge"), palette.pink)
    love.graphics.setFont(font("normal"))
    setColor(palette.muted)
    love.graphics.printf("收集 L O V E 四枚星字，躲开虚空碎片，最后抵达心门。", 0, 338, Game.width, "center")

    drawPanel(Game.width / 2 - 210, 410, 420, 126)
    love.graphics.setFont(font("small"))
    setColor(palette.white)
    love.graphics.printf("Enter 开始 / P 暂停 / R 重开", Game.width / 2 - 210, 434, 420, "center")
    setColor(palette.muted)
    love.graphics.printf("WASD / 方向键移动，也可以按住鼠标左键牵引角色", Game.width / 2 - 180, 474, 360, "center")
end

local function drawEndScreen(title, subtitle, color)
    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", 0, 0, Game.width, Game.height)
    drawPanel(Game.width / 2 - 280, 190, 560, 290)
    drawCentered(title, 230, font("title"), color)
    drawCentered(subtitle, 318, font("normal"), palette.white)
    drawCentered("Score " .. Game.score .. "   Best " .. Game.best, 360, font("small"), palette.gold)
    drawCentered("Enter 再来一次    Esc 退出", 410, font("small"), palette.muted)
end

function love.draw()
    local ox, oy = 0, 0
    if Game.shake > 0 then
        ox = love.math.random(-6, 6) * Game.shake * 3
        oy = love.math.random(-6, 6) * Game.shake * 3
    end

    love.graphics.push()
    love.graphics.translate(ox, oy)
    drawBackground()

    if Game.state == "menu" then
        drawParticles()
        drawMenu()
        love.graphics.pop()
        return
    end

    drawGoal()
    for _, shard in ipairs(Game.shards) do drawShard(shard) end
    for _, hazard in ipairs(Game.hazards) do drawHazard(hazard) end
    drawParticles()
    drawPlayer()
    drawHud()

    if Game.messageTimer > 0 and Game.message ~= "" then
        local a = clamp(Game.messageTimer, 0, 1)
        drawPanel(Game.width / 2 - 220, Game.height - 86, 440, 48)
        love.graphics.setFont(font("small"))
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.printf(Game.message, Game.width / 2 - 210, Game.height - 72, 420, "center")
    end

    if Game.state == "paused" then
        drawEndScreen("PAUSED", "00000号准许你喘口气。只有一点点。", palette.gold)
    elseif Game.state == "victory" then
        drawEndScreen("PROMISE KEPT", "心门已开。恭喜，笨拙但有效。", palette.pink)
    elseif Game.state == "gameover" then
        drawEndScreen("HEART BROKEN", "虚空赢了一局。再试一次，把它撕回去。", palette.danger)
    end

    love.graphics.pop()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "return" or key == "kpenter" then
        if Game.state == "menu" or Game.state == "gameover" or Game.state == "victory" then
            resetGame()
        end
    elseif key == "r" then
        resetGame()
    elseif key == "p" or key == "space" then
        if Game.state == "playing" then
            Game.state = "paused"
        elseif Game.state == "paused" then
            Game.state = "playing"
        end
    end
end
