-- Story/reputation_manager.lua
-- Persistent faction/village reputation state for story consequences.
local ReputationManager = {
    defaultScore = 0,
    factions = {}
}

local function cloneFactions(savedFactions)
    local result = {}

    if type(savedFactions) ~= "table" then
        return result
    end

    for faction, data in pairs(savedFactions) do
        if type(data) == "table" then
            result[faction] = {
                score = math.floor(tonumber(data.score) or 0),
                status = data.status or "neutral"
            }
        else
            result[faction] = {
                score = math.floor(tonumber(data) or 0),
                status = "neutral"
            }
        end
    end

    return result
end

local function statusForScore(score)
    if score >= 25 then
        return "friendly"
    elseif score <= -25 then
        return "hostile"
    end

    return "neutral"
end

function ReputationManager:init(savedData)
    self.factions = cloneFactions(savedData)
    self.factions.red_village = self.factions.red_village or {
        score = self.defaultScore,
        status = "neutral"
    }

    for _, data in pairs(self.factions) do
        data.status = statusForScore(data.score or 0)
    end
end

function ReputationManager:change(faction, amount)
    if not faction or faction == "" then
        return 0, "neutral"
    end

    local entry = self.factions[faction] or {
        score = self.defaultScore,
        status = "neutral"
    }

    entry.score = math.floor((entry.score or 0) + (tonumber(amount) or 0))
    entry.status = statusForScore(entry.score)
    self.factions[faction] = entry

    return entry.score, entry.status
end

function ReputationManager:getStatus(faction)
    local entry = self.factions[faction]
    if not entry then
        return "neutral", self.defaultScore
    end

    entry.status = statusForScore(entry.score or 0)
    return entry.status, entry.score or self.defaultScore
end

function ReputationManager:serialize()
    local data = {}
    for faction, entry in pairs(self.factions) do
        data[faction] = {
            score = math.floor(tonumber(entry.score) or 0),
            status = statusForScore(entry.score or 0)
        }
    end

    return data
end

_G.ReputationManager = ReputationManager

return ReputationManager
