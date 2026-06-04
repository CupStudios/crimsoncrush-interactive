-- Story/story_manager.lua
-- World triggers + chapter orchestration for Visual Novel conversations.
local Collision = require("Utils.collision")
local DialogueBox = require("Story.dialogue_box")
local Chapters = require("Story.chapters")

local StoryManager = {
    currentChapterId = "chapter1",
    state = "world",
    triggers = {},
    context = nil,
    prompt = nil
}

local StoryTrigger = {}
StoryTrigger.__index = StoryTrigger

function StoryTrigger.new(config)
    return setmetatable({
        id = config.id,
        type = "story_trigger",
        label = config.label or config.id or "Story Trigger",
        x = config.x or 0,
        y = config.y or 0,
        width = config.width or 48,
        height = config.height or 48,
        radius = config.radius or 96,
        dialogue = config.dialogue,
        chapterId = config.chapterId,
        used = false
    }, StoryTrigger)
end

function StoryTrigger:getInteractionCircle()
    local centerX, centerY = Collision.entityCenter(self)
    return {
        x = centerX,
        y = centerY,
        radius = self.radius
    }
end

function StoryTrigger:isPlayerInRange(player)
    if not player then return false end
    return Collision.circleCircle(self:getInteractionCircle(), Collision.entityCircle(player))
end

function StoryTrigger:draw()
    love.graphics.setColor(0.12, 0.16, 0.24, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 6, 6)
    love.graphics.setColor(0.95, 0.75, 0.28, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 6, 6)
    love.graphics.print("!", self.x + self.width / 2 - 4, self.y - 20)
end

function StoryManager:init(context)
    self.context = context or {}
    self.triggers = {}
    self:loadChapter(self.currentChapterId)
end

function StoryManager:loadChapter(chapterId)
    self.currentChapterId = chapterId or self.currentChapterId
    self.triggers = {}

    local chapter = Chapters[self.currentChapterId]
    if not chapter or not chapter.triggers then return end

    for _, triggerConfig in pairs(chapter.triggers) do
        triggerConfig.chapterId = self.currentChapterId
        table.insert(self.triggers, StoryTrigger.new(triggerConfig))
    end
end

function StoryManager:getDialogueTree(trigger)
    local chapter = Chapters[trigger.chapterId or self.currentChapterId]
    if not chapter or not chapter.dialogues then return nil end
    return chapter.dialogues[trigger.dialogue]
end

function StoryManager:startDialogue(trigger)
    local tree = self:getDialogueTree(trigger)
    if not tree then return false end

    local context = self.context or {}
    context.storyManager = self
    context.trigger = trigger
    DialogueBox:start(tree, tree.start, context)
    self.state = "dialogue"
    return true
end

function StoryManager:update(dt, player)
    self.prompt = nil
    if DialogueBox:isActive() then
        self.state = "dialogue"
        return
    end

    self.state = "world"

    for _, trigger in ipairs(self.triggers) do
        if trigger:isPlayerInRange(player) then
            self.prompt = trigger
            if love.keyboard.isDown("e") then
                self:startDialogue(trigger)
            end
            break
        end
    end
end

function StoryManager:getState()
    return DialogueBox:isActive() and "dialogue" or self.state
end

function StoryManager:keypressed(key)
    if DialogueBox:isActive() then
        return DialogueBox:keypressed(key)
    end

    if key == "e" and self.prompt then
        return self:startDialogue(self.prompt)
    end

    return false
end

function StoryManager:mousepressed(x, y, button)
    if DialogueBox:isActive() then
        return DialogueBox:mousepressed(x, y, button)
    end

    return false
end

function StoryManager:touchpressed(id, x, y)
    if DialogueBox:isActive() then
        return DialogueBox:touchpressed(id, x, y)
    end

    return false
end

function StoryManager:drawWorld()
    for _, trigger in ipairs(self.triggers) do
        trigger:draw()
    end
end

function StoryManager:drawUi()
    if self.prompt and not DialogueBox:isActive() then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("E: hablar con " .. self.prompt.label, 650, 1030)
    end

    DialogueBox:draw()
end

return StoryManager
