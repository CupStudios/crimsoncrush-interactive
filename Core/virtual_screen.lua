-- Core/virtual_screen.lua
-- Gestiona una resolución lógica fija de 1600x1200 y calcula letterboxing/pillarboxing
-- para mantener SIEMPRE una proporción 12:9 sin importar el tamaño real de la ventana.
local VirtualScreen = {
    width = 1600,
    height = 1200,
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    windowWidth = 1600,
    windowHeight = 1200
}

function VirtualScreen:update(windowWidth, windowHeight)
    self.windowWidth = windowWidth
    self.windowHeight = windowHeight

    -- Escala uniforme: se elige el menor factor para que el lienzo virtual completo
    -- quepa dentro de la ventana real sin deformar el ratio 12:9.
    self.scale = math.min(windowWidth / self.width, windowHeight / self.height)

    -- Barras negras: el espacio sobrante se reparte a ambos lados para centrar
    -- matemáticamente la pantalla virtual dentro de la ventana física.
    self.offsetX = math.floor((windowWidth - self.width * self.scale) / 2)
    self.offsetY = math.floor((windowHeight - self.height * self.scale) / 2)
end

function VirtualScreen:apply()
    -- A partir de aquí, cualquier draw se expresa en coordenadas virtuales
    -- 1600x1200. La conversión a píxeles reales ocurre con translate + scale:
    -- pantalla_real = (coordenada_virtual * scale) + offset(letterbox/pillarbox).
    love.graphics.push()
    love.graphics.translate(self.offsetX, self.offsetY)
    love.graphics.scale(self.scale, self.scale)
end

function VirtualScreen:release()
    love.graphics.pop()
end

function VirtualScreen:drawBlackBars()
    -- La ventana física se limpia en negro antes de aplicar el sistema virtual.
    -- Las zonas no ocupadas por el área virtual escalada quedan como barras negras.
    love.graphics.clear(0, 0, 0, 1)
end

function VirtualScreen:getMousePosition()
    local mouseX, mouseY = love.mouse.getPosition()
    return (mouseX - self.offsetX) / self.scale, (mouseY - self.offsetY) / self.scale
end

return VirtualScreen
