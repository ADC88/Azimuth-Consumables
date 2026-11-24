local _, ns = ...
local P = {}
ns.Profiles = P

local keys = {
    "hidden", "mappings", "weaponEnchants", "scale", "locked", "disabled",
    "hideTitle", "backgroundColor", "glowColor", "excludeRecoveryFood",
    "hideUnavailableClassBuffs", "hideClassBuffs", "disabledBuffs",
    "preferredBuffs", "refreshDefault", "refreshThresholds",
    "iconSize", "spacing", "iconsPerLine", "vertical", "timerTextSize", "countTextSize",
    "onlyNeedsRefresh", "needsRefreshSeconds",
    "handMappings",
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

function P.Copy(settings)
    local result = {}
    for _, key in ipairs(keys) do result[key] = copy(settings[key]) end
    return result
end

function P.SpecKey()
    local api = C_SpecializationInfo
    local index = api and api.GetSpecialization and api.GetSpecialization()
        or (GetSpecialization and GetSpecialization())
    if index then
        local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
        local id, name
        if getInfo then id, name = getInfo(index) end
        return "spec:" .. tostring(id or index), name or ("Spec " .. index)
    end
    local group = GetActiveTalentGroup and GetActiveTalentGroup()
    if group then return "talents:" .. group, "Talent group " .. group end
    return "default", "Default spec"
end

function P.Resolve(account, character)
    local mode = character.profileMode
    if mode ~= "character" and mode ~= "spec" then return account, character, "Shared settings" end
    character.profiles = type(character.profiles) == "table" and character.profiles or {}
    local key, name = "character", "This character"
    if mode == "spec" then key, name = P.SpecKey() end
    if type(character.profiles[key]) ~= "table" then
        character.profiles[key] = P.Copy(account)
        character.profiles[key].position = copy(character.position)
    end
    return character.profiles[key], character.profiles[key], name
end
