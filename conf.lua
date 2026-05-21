-- conf.lua
-- My LÖVE Game - project configuration

function love.conf(t)
    t.title = "My LÖVE Game"
    t.identity = "my-love-game"
    t.appendidentity = false

    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 960
    t.window.minheight = 540
    t.window.resizable = true
    t.window.vsync = true
    t.window.msaa = 0
    t.window.highdpi = true
    t.window.usedpiscale = true

    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.timer = true
    t.modules.window = true
end
