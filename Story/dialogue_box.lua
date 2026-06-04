-- Story/dialogue_box.lua
-- Visual Novel dialogue box with typewriter text, portraits, names, and choices.
local DialogueBox = {
    active = false,
    tree = nil,
    currentNodeId = nil,
    currentNode = nil,
    context = nil,
    visibleCharacters = 0,
    charactersPerSecond = 42,
    selectedChoice = 1,
    choiceRegions = {}
}

local portraitCache = {}

local BOX_X = 90
local BOX_Y = 820
local BOX_WIDTH = 1420
local BOX_HEIGHT = 310
local PORTRAIT_SIZE = 190
local TEXT_X = BOX_X + PORTRAIT_SIZE + 48
local TEXT_Y = BOX_Y + 82
local TEXT_WIDTH = BOX_WIDTH - PORTRAIT_SIZE - 90
local CHOICE_X = TEXT_X
local CHOICE_Y = BOX_Y + 202
local CHOICE_WIDTH = TEXT_WIDTH
local CHOICE_HEIGHT = 34
local CHOICE_GAP = 12

local function utf8Length(text)
    local count = 0
    for _ in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
    end
    return count
end

local function utf8Sub(text, maxCharacters)
    local result = {}
    local count = 0

    for character in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > maxCharacters then
            break
        end
        result[#result + 1] = character
    end

    return table.concat(result)
end

local function resolvePortrait(portrait)
    if type(portrait) == "userdata" then return portrait end
    if type(portrait) ~= "string" or portrait == "" then return nil end
    if portraitCache[portrait] ~= nil then return portraitCache[portrait] end

    if love.filesystem.getInfo(portrait) then
        portraitCache[portrait] = love.graphics.newImage(portrait)
    else
        portraitCache[portrait] = false
    end

    return portraitCache[portrait] or nil
end

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width
        and y >= rect.y and y <= rect.y + rect.height
end

function DialogueBox:isActive()
    return self.active
end

function DialogueBox:start(tree, startNodeId, context)
    self.active = true
    self.tree = tree or {}
    self.context = context or {}
    self:goTo(startNodeId or self.tree.start or "start")
end

function DialogueBox:close()
    self.active = false
    self.tree = nil
    self.currentNodeId = nil
    self.currentNode = nil
    self.context = nil
    self.visibleCharacters = 0
    self.selectedChoice = 1
    self.choiceRegions = {}
end

function DialogueBox:goTo(nodeId)
    local nextNode = self.tree and self.tree.nodes and self.tree.nodes[nodeId]
    if not nextNode then
        self:close()
        return
    end

    self.currentNodeId = nodeId
    self.currentNode = nextNode
    self.visibleCharacters = 0
    self.selectedChoice = 1
    self.choiceRegions = {}

    if nextNode.onEnter then
        nextNode.onEnter(self.context or {}, self)
    end
end

function DialogueBox:isTyping()
    if not self.currentNode then return false end
    return self.visibleCharacters < utf8Length(self.currentNode.text or "")
end

function DialogueBox:finishTyping()
    if self.currentNode then
        self.visibleCharacters = utf8Length(self.currentNode.text or "")
    end
end

function DialogueBox:advance()
    if not self.active or not self.currentNode then return end

    if self:isTyping() then
        self:finishTyping()
        return
    end

    local choices = self.currentNode.choices or {}
    if #choices > 0 then
        return
    end

    if self.currentNode.onComplete then
        self.currentNode.onComplete(self.context or {}, self)
    end

    if self.currentNode.next then
        self:goTo(self.currentNode.next)
    else
        self:close()
    end
end

function DialogueBox:selectChoice(index)
    if not self.active or not self.currentNode or self:isTyping() then return end

    local choices = self.currentNode.choices or {}
    local choice = choices[index]
    if not choice then return end

    if choice.callback then
        choice.callback(self.context or {}, self)
    end

    if choice.next then
        self:goTo(choice.next)
    else
        self:close()
    end
end

function DialogueBox:update(dt)
    if not self.active or not self.currentNode then return end

    if self:isTyping() then
        self.visibleCharacters = math.min(
            utf8Length(self.currentNode.text or ""),
            self.visibleCharacters + self.charactersPerSecond * dt
        )
    end
end

function DialogueBox:keypressed(key)
    if not self.active then return false end

    local choices = self.currentNode and self.currentNode.choices or {}
    if key == "up" or key == "w" then
        if #choices > 0 and not self:isTyping() then
            self.selectedChoice = ((self.selectedChoice - 2) % #choices) + 1
        end
        return true
    elseif key == "down" or key == "s" then
        if #choices > 0 and not self:isTyping() then
            self.selectedChoice = (self.selectedChoice % #choices) + 1
        end
        return true
    elseif key == "return" or key == "space" or key == "e" or key == "j" then
        if #choices > 0 and not self:isTyping() then
            self:selectChoice(self.selectedChoice)
        else
            self:advance()
        end
        return true
    elseif key == "escape" then
        self:close()
        return true
    end

    return true
end

function DialogueBox:mousepressed(x, y, button)
    if not self.active or button ~= 1 then return self.active end

    if self:isTyping() then
        self:finishTyping()
        return true
    end

    for index, region in ipairs(self.choiceRegions) do
        if pointInRect(x, y, region) then
            self:selectChoice(index)
            return true
        end
    end

    self:advance()
    return true
end

function DialogueBox:touchpressed(id, x, y)
    if not self.active then return false end
    return self:mousepressed(x, y, 1)
end

function DialogueBox:draw()
    if not self.active or not self.currentNode then return end

    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", BOX_X, BOX_Y, BOX_WIDTH, BOX_HEIGHT, 14, 14)
    love.graphics.setColor(0.85, 0.15, 0.18, 1)
    love.graphics.rectangle("line", BOX_X, BOX_Y, BOX_WIDTH, BOX_HEIGHT, 14, 14)

    local portrait = resolvePortrait(self.currentNode.portrait)
    if portrait then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(portrait, BOX_X + 28, BOX_Y + 58, 0, PORTRAIT_SIZE / portrait:getWidth(), PORTRAIT_SIZE / portrait:getHeight())
    else
        love.graphics.setColor(0.18, 0.18, 0.22, 1)
        love.graphics.rectangle("fill", BOX_X + 28, BOX_Y + 58, PORTRAIT_SIZE, PORTRAIT_SIZE, 8, 8)
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.rectangle("line", BOX_X + 28, BOX_Y + 58, PORTRAIT_SIZE, PORTRAIT_SIZE, 8, 8)
    end

    love.graphics.setColor(1, 0.82, 0.34, 1)
    love.graphics.print(self.currentNode.speaker or "", TEXT_X, BOX_Y + 36)

    love.graphics.setColor(1, 1, 1, 1)
    local visibleText = utf8Sub(self.currentNode.text or "", math.floor(self.visibleCharacters))
    love.graphics.printf(visibleText, TEXT_X, TEXT_Y, TEXT_WIDTH, "left")

    self.choiceRegions = {}
    if not self:isTyping() then
        local choices = self.currentNode.choices or {}
        for index = 1, math.min(#choices, 3) do
            local y = CHOICE_Y + (index - 1) * (CHOICE_HEIGHT + CHOICE_GAP)
            local isSelected = index == self.selectedChoice
            self.choiceRegions[index] = { x = CHOICE_X, y = y, width = CHOICE_WIDTH, height = CHOICE_HEIGHT }

            love.graphics.setColor(isSelected and 0.45 or 0.16, isSelected and 0.16 or 0.16, isSelected and 0.18 or 0.2, 0.92)
            love.graphics.rectangle("fill", CHOICE_X, y, CHOICE_WIDTH, CHOICE_HEIGHT, 6, 6)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(index .. ". " .. (choices[index].text or "..."), CHOICE_X + 14, y + 7)
        end

        if #choices == 0 then
            love.graphics.setColor(0.75, 0.75, 0.78, 1)
            love.graphics.print("Space/E: continuar", TEXT_X, BOX_Y + BOX_HEIGHT - 42)
        end
    end
end

return DialogueBox
