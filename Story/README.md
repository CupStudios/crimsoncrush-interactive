# Story/VN Integration

## Runtime modules

- `Story/reputation_manager.lua` stores persistent faction scores and statuses.
- `Story/dialogue_box.lua` owns the active Visual Novel state, typewriter text, portraits, choices, and input interception.
- `Story/story_manager.lua` owns world-space story triggers and starts dialogue trees from `Story/chapters.lua`.

## Main loop integration

In `Game.load`, initialize reputation from the save data before creating story triggers:

```lua
local saveData = SaveManager.loadPlayer()
ReputationManager:init(saveData and saveData.reputation)
StoryManager:init({
    entityManager = entityManager,
    player = player,
    saveManager = SaveManager,
    reputationManager = ReputationManager
})
```

In `Game.update`, update the updater first, then freeze world simulation while the dialogue box is active:

```lua
Updater:update(dt)
if DialogueBox:isActive() then
    DialogueBox:update(dt)
    return
end
StoryManager:update(dt, player)
entityManager:update(dt)
```

In `Game.draw`, draw world triggers inside the camera transform and draw dialogue UI after the normal HUD:

```lua
camera:apply()
StoryManager:drawWorld()
entityManager:draw()
camera:release()
StoryManager:drawUi()
```

Forward input to `StoryManager` before combat controls. When dialogue is active, it consumes keyboard, mouse, and touch input for advancing text or selecting choices.
