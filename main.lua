-- main.lua
-- Minimal playable LÖVE starter: move, collect, avoid enemies, restart.

local Game = {
    state = "menu", -- menu, playing, gameover
    width = 1280,
    height = 720,
    score = 0,
    best = 0,
    time = 0,
    player = {x = 160, y = 360, r = 18, speed = 280, hp = 3},
    orb = {x = 900, y = 360, r = 14},
    enemies = {},
    spawnTimer = 0
}

local function clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

local function distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function resetGame()
    Game.state = "playing"
    Game.score = 0
    Game.time = 0
    Game.spawnTimer = 0
    Game.player.x = 160
    Game.player.y = Game.height / 2
    Game.player.hp = 3
    Game.orb.x = 860
    Game.orb.y = 360
    Game.enemies = {}
end

local function spawnEnemy()
    local fromTop = love.math.random() < 0.5
    local enemy = {
        x = Game.width + 40,
        y = fromTop and love.math.random(80, 280) or love.math.random(440, Game.height - 80),
        r = love.math.random(14, 24),
        speed = love.math.random(130, 220) + Game.time * 4
    }
    table.insert(Game.enemies, enemy)
end

function love.load()
    love.window.setTitle("My LÖVE Game")
    love.graphics.setDefaultFilter("nearest", "nearest")
    Game.width, Game.height = love.graphics.getDimensions()
    love.math.setRandomSeed(os.time())
end

function love.update(dt)
    if Game.state ~= "playing" then return end

    Game.time = Game.time + dt

    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end

    local p = Game.player
    p.x = clamp(p.x + dx * p.speed * dt, p.r, Game.width - p.r)
    p.y = clamp(p.y + dy * p.speed * dt, p.r, Game.height - p.r)

    Game.spawnTimer = Game.spawnTimer - dt
    if Game.spawnTimer <= 0 then
        spawnEnemy()
        Game.spawnTimer = math.max(0.35, 1.05 - Game.time * 0.018)
    end

    for i = #Game.enemies, 1, -1 do
        local e = Game.enemies[i]
        e.x = e.x - e.speed * dt
        if e.x < -60 then
            table.remove(Game.enemies, i)
        elseif distance(p, e) < p.r + e.r then
            table.remove(Game.enemies, i)
            p.hp = p.hp - 1
            if p.hp <= 0 then
                Game.state = "gameover"
                Game.best = math.max(Game.best, Game.score)
            end
        end
    end

    if distance(p, Game.orb) < p.r + Game.orb.r then
        Game.score = Game.score + 1
        Game.best = math.max(Game.best, Game.score)
        Game.orb.x = love.math.random(260, Game.width - 120)
        Game.orb.y = love.math.random(90, Game.height - 90)
    end
end

local function drawText(text, y, size)
    love.graphics.setFont(love.graphics.newFont(size or 24))
    love.graphics.printf(text, 0, y, Game.width, "center")
end

function love.draw()
    Game.width, Game.height = love.graphics.getDimensions()

    love.graphics.clear(0.06, 0.08, 0.12, 1)

    -- background grid
    love.graphics.setColor(0.12, 0.16, 0.23, 1)
    for x = 0, Game.width, 32 do love.graphics.line(x, 0, x, Game.height) end
    for y = 0, Game.height, 32 do love.graphics.line(0, y, Game.width, y) end

    if Game.state == "menu" then
        love.graphics.setColor(1, 0.86, 0.35, 1)
        drawText("MY LÖVE GAME", 220, 48)
        love.graphics.setColor(0.9, 0.95, 1, 1)
        drawText("Press ENTER to start", 310, 26)
        drawText("WASD / Arrow Keys to move", 350, 20)
        return
    end

    local p = Game.player
    love.graphics.setColor(0.24, 0.72, 1.0, 1)
    love.graphics.circle("fill", p.x, p.y, p.r)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("line", p.x, p.y, p.r + 3)

    love.graphics.setColor(1.0, 0.78, 0.22, 1)
    love.graphics.circle("fill", Game.orb.x, Game.orb.y, Game.orb.r)

    for _, e in ipairs(Game.enemies) do
        love.graphics.setColor(1.0, 0.22, 0.28, 1)
        love.graphics.circle("fill", e.x, e.y, e.r)
    end

    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: " .. Game.score, 24, 22)
    love.graphics.print("Best: " .. Game.best, 24, 52)
    love.graphics.print("HP: " .. string.rep("♥", p.hp), Game.width - 160, 22)

    if Game.state == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.62)
        love.graphics.rectangle("fill", 0, 0, Game.width, Game.height)
        love.graphics.setColor(1, 0.35, 0.35, 1)
        drawText("GAME OVER", 250, 48)
        love.graphics.setColor(1, 1, 1, 1)
        drawText("Score: " .. Game.score .. "   Best: " .. Game.best, 325, 24)
        drawText("Press ENTER to restart", 370, 22)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "return" or key == "kpenter" then
        if Game.state == "menu" or Game.state == "gameover" then
            resetGame()
        end
    end
end
