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

local function toVirtualCoordinates(x, y)
    local scale = VirtualScreen.scale ~= 0 and VirtualScreen.scale or 1
    return (x - VirtualScreen.offsetX) / scale, (y - VirtualScreen.offsetY) / scale
end

local function isInsideCircle(x, y, circleX, circleY, radius)
    local dx = x - circleX
    local dy = y - circleY
    return dx * dx + dy * dy <= radius * radius
end

function MobileControls:touchpressed(id, x, y)
    -- Convertir coordenadas físicas a virtuales
    local vx, vy = toVirtualCoordinates(x, y)

    -- Joystick
    if not self.joystick.active and isInsideCircle(vx, vy, self.joystick.x, self.joystick.y, self.joystick.radius) then
        self.joystick.active = true
        self.joystick.touchId = id
    end

    -- Botones. Cada botón guarda su touchId para no soltar todos al liberar un dedo.
    for _, btn in pairs(self.buttons) do
        if not btn.touchId and isInsideCircle(vx, vy, btn.x, btn.y, btn.r) then
            btn.pressed = true
            btn.touchId = id
        end
    end
end

function MobileControls:touchmoved(id, x, y)
    local vx, vy = toVirtualCoordinates(x, y)

    if id == self.joystick.touchId then
        local dx = vx - self.joystick.x
        local dy = vy - self.joystick.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local maxDist = self.joystick.radius

        if dist > maxDist and dist > 0 then
            dx, dy = (dx / dist) * maxDist, (dy / dist) * maxDist
        end
        self.joystick.dx, self.joystick.dy = dx / maxDist, dy / maxDist
    end
end

function MobileControls:touchreleased(id)
    if id == self.joystick.touchId then
        self.joystick.active = false
        self.joystick.touchId = nil
        self.joystick.dx, self.joystick.dy = 0, 0
    end

    for _, btn in pairs(self.buttons) do
        if btn.touchId == id then
            btn.pressed = false
            btn.touchId = nil
        end
    end
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
    for name, btn in pairs(self.buttons) do
        love.graphics.circle(btn.pressed and "fill" or "line", btn.x, btn.y, btn.r)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.printf(name:upper(), btn.x - btn.r, btn.y - 8, btn.r * 2, "center")
        love.graphics.setColor(1, 1, 1, 0.3)
    end
end

return MobileControls
