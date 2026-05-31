-- Utils/mobile_controls.lua
local VirtualScreen = require("Core.virtual_screen")

local MobileControls = {
    joystick = { x = 250, y = 900, radius = 150, active = false, touchId = nil, dx = 0, dy = 0 },
    buttons = {
        m1 = { x = 1450, y = 900, r = 80, pressed = false },
        dash = { x = 1300, y = 1050, r = 60, pressed = false },
        will = { x = 1300, y = 750, r = 60, pressed = false },
        block = { x = 1150, y = 900, r = 60, pressed = false },
        charge = { x = 1450, y = 750, r = 60, pressed = false }
    }
}

function MobileControls:touchpressed(id, x, y)
    -- Convertir coordenadas físicas a virtuales
    local vx, vy = (x - VirtualScreen.offsetX) / VirtualScreen.scale, (y - VirtualScreen.offsetY) / VirtualScreen.scale
    
    -- Joystick
    local dist = math.sqrt((vx - self.joystick.x)^2 + (vy - self.joystick.y)^2)
    if dist < self.joystick.radius then
        self.joystick.active = true
        self.joystick.touchId = id
    end

    -- Botones
    for name, btn in pairs(self.buttons) do
        local d = math.sqrt((vx - btn.x)^2 + (vy - btn.y)^2)
        if d < btn.r then btn.pressed = true end
    end
end

function MobileControls:touchmoved(id, x, y)
    local vx, vy = (x - VirtualScreen.offsetX) / VirtualScreen.scale, (y - VirtualScreen.offsetY) / VirtualScreen.scale
    
    if id == self.joystick.touchId then
        local dx = vx - self.joystick.x
        local dy = vy - self.joystick.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local maxDist = self.joystick.radius
        
        if dist > maxDist then
            dx, dy = (dx/dist) * maxDist, (dy/dist) * maxDist
        end
        self.joystick.dx, self.joystick.dy = dx/maxDist, dy/maxDist
    end
end

function MobileControls:touchreleased(id)
    if id == self.joystick.touchId then
        self.joystick.active = false
        self.joystick.dx, self.joystick.dy = 0, 0
    end
    for _, btn in pairs(self.buttons) do btn.pressed = false end
end

function MobileControls:isActionPressed(action)
    return self.buttons[action] and self.buttons[action].pressed
end

function MobileControls:getJoystickVector()
    return self.joystick.dx, self.joystick.dy
end

function MobileControls:draw()
    love.graphics.setColor(1, 1, 1, 0.3)
    -- Dibujar Joystick
    love.graphics.circle("line", self.joystick.x, self.joystick.y, self.joystick.radius)
    love.graphics.circle("fill", self.joystick.x + self.joystick.dx * self.joystick.radius, self.joystick.y + self.joystick.dy * self.joystick.radius, 40)
    -- Dibujar Botones
    for _, btn in pairs(self.buttons) do
        love.graphics.circle(btn.pressed and "fill" or "line", btn.x, btn.y, btn.r)
    end
end

return MobileControls
