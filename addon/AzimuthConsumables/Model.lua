-- Pure selection/matching logic; no WoW UI or protected actions.
local _, ns = ...
local M = {}
ns.Model = M

function M.Scale(value)
    return math.max(0.6, math.min(2, tonumber(value) or 1))
end

-- Only hide food whose use text is entirely ordinary health/mana recovery.
-- Keep unfamiliar wording and extra effects visible.
function M.IsRecoveryFood(lines)
    local recovery
    for _, line in ipairs(lines) do
        local text = line:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            :gsub("%s+", " "):match("^%s*(.-)%s*$")
        if text:find("well fed", 1, true) or text:find("^if you spend")
            or text:find("^increases ") or text:find("^grants ") then return false end
        local effect = text:match("^use:%s*(.+)$")
        if effect then
            if recovery then return false end
            effect = effect:gsub(" must remain seated while eating and drinking%.$", "")
                :gsub(" must remain seated while eating%.$", "")
                :gsub(" must remain seated while drinking%.$", "")
            local resources = effect:match("^restores (.+) over [%d.]+ sec%.$")
                or effect:match("^restores (.+) over [%d.]+ seconds?%.$")
            if not resources then return false end
            local amount = "[%d,.]+%%?"
            recovery = resources:match("^" .. amount .. " health$")
                or resources:match("^" .. amount .. " mana$")
                or resources:match("^" .. amount .. " health and " .. amount .. " mana$")
            if not recovery then return false end
        end
    end
    if recovery then return true end
end

function M.IsExcluded(item, settings)
    return settings.hidden[item.id] or (settings.excludeRecoveryFood and item.recoveryFood
        and not settings.mappings[item.id])
end

function M.Items(slots, settings)
    local byID, items = {}, {}
    for _, item in ipairs(slots) do
        if item.id and (item.count or 0) > 0 and not M.IsExcluded(item, settings)
            and (settings.mappings[item.id] or (item.classID == 0 and item.spellID)) then
            if byID[item.id] then
                byID[item.id].count = byID[item.id].count + item.count
            else
                local copy = {}
                for k, v in pairs(item) do copy[k] = v end
                byID[item.id] = copy
                items[#items + 1] = copy
            end
        end
    end
    table.sort(items, function(a, b)
        if (a.subClassID or 99) ~= (b.subClassID or 99) then
            return (a.subClassID or 99) < (b.subClassID or 99)
        end
        return a.id < b.id
    end)
    return items
end

-- An explicit mapping overrides the cast spell: many foods and custom
-- consumables apply a different aura. Match by ID first, localized name second.
function M.Effect(item, auras, settings, now, weapons)
    local mapping = settings.mappings[item.id]
    local learned = settings.weaponEnchants and settings.weaponEnchants[item.id]
    local best
    local function consider(effect)
        local expires = effect.expires
        if not expires or expires == 0 or expires > now then
            local rank = expires and expires > 0 and expires or math.huge
            local prior = best and best.expires
            if not best or rank > (prior and prior > 0 and prior or math.huge) then best = effect end
        end
    end
    if weapons and ((mapping and mapping.weapon) or (not mapping and learned)) then
        for _, effect in ipairs(weapons.effects) do
            if mapping and mapping.weapon then
                if (mapping.hand == "either" or mapping.hand == effect.hand)
                    and mapping.enchantID == effect.enchantID then consider(effect) end
            elseif learned[effect.enchantID] then consider(effect) end
        end
        return best
    end
    if mapping and mapping.weapon then return nil end
    for _, aura in ipairs(auras) do
        local match = false
        if mapping then
            for _, id in ipairs(mapping) do
                if id == aura.spellID then match = true; break end
            end
        else
            match = item.spellID == aura.spellID
                or (item.spellName and item.spellName == aura.name)
        end
        if match then consider(aura) end
    end
    return best
end

function M.Time(seconds)
    if seconds == nil then return "ACTIVE" end
    seconds = math.max(0, math.ceil(seconds))
    if seconds >= 3600 then return string.format("%dh %dm", math.floor(seconds / 3600), math.floor(seconds / 60) % 60) end
    if seconds >= 60 then return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end
    return tostring(seconds) .. "s"
end

-- Countdown is the active effect, never the item's reuse cooldown.
function M.State(item, auras, settings, now, readable, weapons)
    local effect = M.Effect(item, auras, settings, now, weapons)
    if effect then
        local remaining = effect.expires and effect.expires > 0 and effect.expires - now or nil
        return { text = M.Time(remaining), glow = false, active = true, effect = effect }
    end
    local mapping = settings.mappings[item.id]
    local isWeapon = mapping and mapping.weapon or (not mapping and (item.weapon
        or (settings.weaponEnchants and settings.weaponEnchants[item.id])))
    if (isWeapon and (not weapons or not weapons.readable)) or (not isWeapon and not readable) then
        return { text = "?", glow = false }
    end
    local ready = not item.cooldownEnd or item.cooldownEnd <= now
    return { text = ready and "READY" or ("CD " .. M.Time(item.cooldownEnd - now)), glow = true }
end
