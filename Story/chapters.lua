-- Story/chapters.lua
-- Sample chapter data. Dialogue callbacks receive a context table from StoryManager.
local ReputationManager = require("Story.reputation_manager")
local TrainingDummy = require("Entities.training_dummy")

local Chapters = {}

local function saveStoryState(context)
    if context.saveManager and context.player then
        context.saveManager.savePlayer(context.player)
    end
end

local function spawnAggressiveCombat(context)
    if not context.entityManager or not context.player then return end

    for index = 1, 3 do
        local angle = (math.pi * 2 / 3) * index
        local spawnX = context.player.x + math.cos(angle) * 260
        local spawnY = context.player.y + math.sin(angle) * 260
        local dummy = TrainingDummy.new(spawnX, spawnY)
        dummy.type = "enemy"
        dummy.isAggressive = true
        context.entityManager:add(dummy)
    end
end

Chapters.chapter1 = {
    id = "chapter1",
    title = "Chapter 1: Ashes at Red Village",
    triggers = {
        village_elder = {
            id = "village_elder",
            label = "Red Village Elder",
            x = 180,
            y = -80,
            width = 48,
            height = 64,
            radius = 120,
            dialogue = "elder_intro"
        }
    },
    dialogues = {
        elder_intro = {
            start = "start",
            nodes = {
                start = {
                    speaker = "Elder Mara",
                    text = "Traveler, our food stores are burning. Help us defend the village, or take what remains and leave us to the ashes.",
                    choices = {
                        {
                            text = "Defend the village stores.",
                            next = "help_village",
                            callback = function(context)
                                ReputationManager:change("red_village", 30)
                                context.lastMoralChoice = "helped_village"
                                saveStoryState(context)
                            end
                        },
                        {
                            text = "Take supplies and walk away.",
                            next = "betray_village",
                            callback = function(context)
                                ReputationManager:change("red_village", -60)
                                context.lastMoralChoice = "betrayed_village"
                                spawnAggressiveCombat(context)
                                saveStoryState(context)
                            end
                        },
                        {
                            text = "Ask what happened first.",
                            next = "ask_context"
                        }
                    }
                },
                ask_context = {
                    speaker = "Elder Mara",
                    text = "Bandits followed the crimson storm. If we lose the granary, children will starve before the next moon.",
                    next = "start"
                },
                help_village = {
                    speaker = "Elder Mara",
                    text = "Then Red Village remembers you as a shield, not a blade. Our scouts will guide you through the canyon.",
                    next = "end"
                },
                betray_village = {
                    speaker = "Elder Mara",
                    text = "So be it. Red Village names you enemy. The guards will answer your greed with steel.",
                    next = "end"
                },
                ["end"] = {
                    speaker = "Narrator",
                    text = "The choice settles over the village like ash. Reputation has changed."
                }
            }
        }
    }
}

return Chapters
