-- Utils/effects.lua
-- Sistema ligero de efectos visuales/sonoros definidos por JSON.
-- Uso típico desde cualquier script:
--   local Effects = require("Utils.effects")
--   Effects:emit("player_dash", x, y, { directionX = 1, directionY = 0 })
local JSON = require("json")

local Effects = {
    definitions = {},
    particles = {},
    images = {},
    sounds = {},
    configPath = "Data/effects.json",
    assetRoots = {
        images = "Assets/images/",
        audio = "Assets/audio/"
    }
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function readFile(path)
    if love and love.filesystem and love.filesystem.getInfo(path) then
        return love.filesystem.read(path)
    end

    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local contents = file:read("*a")
    file:close()
    return contents
end

local function fileExists(path)
    if love and love.filesystem then
        return love.filesystem.getInfo(path) ~= nil
    end

    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end

    return false
end

local function resolveAsset(root, relativePath)
    if not relativePath or relativePath == "" then
        return nil
    end

    if relativePath:match("^/") or relativePath:match("^%a:[/\\]") then
        return relativePath
    end

    return root .. relativePath
end

local function loadImage(path)
    if not path or not love or not love.graphics or not fileExists(path) then
        return nil
    end

    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function loadSound(path)
    if not path or not love or not love.audio or not fileExists(path) then
        return nil
    end

    return love.audio.newSource(path, "static")
end

function Effects:load(configPath)
    self.configPath = configPath or self.configPath
    self.definitions = {}
    self.particles = {}
    self.images = {}
    self.sounds = {}

    local rawJson = readFile(self.configPath)
    if not rawJson then
        self.lastError = "No se encontró " .. self.configPath
        return false, self.lastError
    end

    local ok, decoded = pcall(function()
        return JSON:decode(rawJson)
    end)

    if not ok or type(decoded) ~= "table" then
        self.lastError = "JSON de efectos inválido: " .. tostring(decoded)
        return false, self.lastError
    end

    self.assetRoots.images = decoded.imageRoot or self.assetRoots.images
    self.assetRoots.audio = decoded.audioRoot or self.assetRoots.audio
    self.definitions = decoded.effects or {}

    for effectName, definition in pairs(self.definitions) do
        local visual = definition.visual or {}
        local sound = definition.sound or {}
        local imagePath = resolveAsset(self.assetRoots.images, visual.image)
        local soundPath = resolveAsset(self.assetRoots.audio, sound.file)

        self.images[effectName] = loadImage(imagePath)
        self.sounds[effectName] = loadSound(soundPath)
    end

    self.lastError = nil
    return true
end

function Effects:emit(effectName, x, y, overrides)
    local definition = self.definitions[effectName]
    if not definition then
        return false, "Efecto desconocido: " .. tostring(effectName)
    end

    overrides = overrides or {}
    local visual = definition.visual or {}
    local sound = definition.sound or {}
    local particle = {
        name = effectName,
        x = x or 0,
        y = y or 0,
        directionX = overrides.directionX or 0,
        directionY = overrides.directionY or 0,
        age = 0,
        duration = overrides.duration or visual.duration or 0.25,
        radius = overrides.radius or visual.radius or 24,
        endRadius = overrides.endRadius or visual.endRadius or visual.radius or 24,
        color = overrides.color or visual.color or {1, 1, 1, 1},
        shape = overrides.shape or visual.shape or "circle",
        image = self.images[effectName]
    }

    table.insert(self.particles, particle)

    local source = self.sounds[effectName]
    if source then
        source:stop()
        source:setVolume(clamp(overrides.volume or sound.volume or 1, 0, 1))
        source:setPitch(overrides.pitch or sound.pitch or 1)
        source:play()
    end

    return true
end

function Effects:update(dt)
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.age = particle.age + dt

        if particle.age >= particle.duration then
            table.remove(self.particles, index)
        end
    end
end

function Effects:draw()
    for _, particle in ipairs(self.particles) do
        local progress = particle.duration > 0 and clamp(particle.age / particle.duration, 0, 1) or 1
        local alpha = (particle.color[4] or 1) * (1 - progress)
        local radius = particle.radius + (particle.endRadius - particle.radius) * progress
        local x = particle.x + particle.directionX * progress * radius * 0.35
        local y = particle.y + particle.directionY * progress * radius * 0.35

        love.graphics.setColor(particle.color[1] or 1, particle.color[2] or 1, particle.color[3] or 1, alpha)

        if particle.image then
            local width = particle.image:getWidth()
            local height = particle.image:getHeight()
            local scale = (radius * 2) / math.max(width, height)
            love.graphics.draw(particle.image, x, y, 0, scale, scale, width / 2, height / 2)
        elseif particle.shape == "ring" then
            love.graphics.circle("line", x, y, radius)
        elseif particle.shape == "rect" then
            love.graphics.rectangle("line", x - radius, y - radius, radius * 2, radius * 2, 6, 6)
        else
            love.graphics.circle("fill", x, y, radius)
        end
    end
end

return Effects
