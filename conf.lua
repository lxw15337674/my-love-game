-- conf.lua
-- Stardrift Promise - LÖVE 11.x configuration

function love.conf(t)
    t.identity = "stardrift-promise"
    t.version = "11.4"
    t.console = false
    t.appendidentity = false

    t.window.title = "Stardrift Promise"
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 960
    t.window.minheight = 540
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 4
    t.window.highdpi = true
    t.window.usedpiscale = true

    t.modules.audio = false
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = false
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = true
    t.modules.video = false
    t.modules.window = true
end
