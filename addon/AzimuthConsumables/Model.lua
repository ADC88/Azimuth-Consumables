-- Pure selection/matching logic; no WoW UI or protected actions.
local _, ns = ...
local M = {}
ns.Model = M
M.Statuses = {
    ACTIVE = { label = "Active", badge = "", color = { 0.4, 1, 0.65 } },
    EXPIRING = { label = "Expiring soon", badge = "EXP", color = { 1, 0.55, 0.15 } },
    MISSING = { label = "Effect missing", badge = "MISS", color = { 1, 0.85, 0.4 } },
    COOLDOWN = { label = "On cooldown", badge = "CD", color = { 0.45, 0.7, 1 } },
    RESOURCE = { label = "Not enough mana or power", badge = "PWR", color = { 0.6, 0.5, 1 } },
    UNAVAILABLE = { label = "Unavailable to cast or use", badge = "N/A", color = { 0.7, 0.7, 0.7 } },
    EMPTY = { label = "No copies in bags", badge = "0", color = { 0.7, 0.7, 0.7 } },
    UNKNOWN = { label = "Effect data unavailable", badge = "?", color = { 0.7, 0.7, 0.7 } },
}

function M.Number(value, default, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number then number = default end
    return math.max(minimum, math.min(maximum, math.floor(number)))
end

function M.Layout(count, settings)
    local size = M.Number(settings.iconSize, 40, 24, 80)
    local gap = M.Number(settings.spacing, 7, 0, 20)
    local perLine = M.Number(settings.iconsPerLine, 8, 1, 20)
    local columns, rows = math.min(count, perLine), math.ceil(count / perLine)
    if settings.vertical then columns, rows = rows, columns end
    return { size = size, gap = gap, perLine = perLine, rows = rows, columns = columns,
        width = columns * (size + gap) + gap, height = rows * (size + gap) }
end

function M.Status(item, state, now, usable, noResource, enabled)
    if item.classBuff and not item.castSpell then return "UNAVAILABLE" end
    if not item.classBuff and item.count == 0 then return "EMPTY" end
    if state.status == "UNKNOWN" then return "UNKNOWN" end
    if item.cooldownEnd and item.cooldownEnd > now then return "COOLDOWN" end
    if noResource then return "RESOURCE" end
    if usable == false or enabled == 0 then return "UNAVAILABLE" end
    return state.status
end

function M.SelectionReason(item, settings)
    if settings.hidden[item.id] then return "Blacklisted" end
    if settings.excludeRecoveryFood and item.recoveryFood and not settings.mappings[item.id] then
        return "Recovery-only food filtered"
    end
    if (item.count or 0) <= 0 then return "No copies in bags" end
    if item.id == M.SleepingBag or settings.mappings[item.id] or (item.classID == 0 and item.spellID) then
        return "Included"
    end
    return "No usable consumable spell or explicit mapping"
end
M.SleepingBag = 211527
local WELL_RESTED, BAG_REFRESH = 429959, 300

-- Preserve timestamps already read by the client. Partial scans cannot prove
-- an unobserved effect was removed. A complete scan replaces the cache.
function M.PreserveEffects(previous, current, readable, inCombat)
    if readable or not inCombat then return current end
    local seen = {}
    local function key(effect)
        return effect.spellID or (tostring(effect.hand) .. ":" .. tostring(effect.enchantID))
    end
    for _, effect in ipairs(current) do seen[key(effect)] = true end
    for _, effect in ipairs(previous) do
        if not seen[key(effect)] then
            local cached = {}
            for name, value in pairs(effect) do cached[name] = value end
            cached.cached = true
            current[#current + 1] = cached
        end
    end
    return current
end

function M.Scale(value)
    return math.max(0.6, math.min(2, tonumber(value) or 1))
end

function M.RefreshSeconds(value)
    local seconds = tonumber(value)
    if not seconds or seconds ~= seconds then return 0 end
    return math.max(0, math.min(3600, math.floor(seconds)))
end

function M.RefreshThreshold(item, settings)
    local override = settings.refreshThresholds and settings.refreshThresholds[item.id]
    if override ~= nil then return M.RefreshSeconds(override) end
    if item.id == M.SleepingBag then return BAG_REFRESH end
    return M.RefreshSeconds(settings.refreshDefault)
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
        if item.id and M.SelectionReason(item, settings) == "Included" then
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
    local sleepingBag = item.id == M.SleepingBag
    local mapping = not sleepingBag and settings.mappings[item.id]
    local learned = not sleepingBag and settings.weaponEnchants and settings.weaponEnchants[item.id]
    local best
    local function consider(effect)
        local expires = effect.expires
        if effect.cached or not expires or expires == 0 or expires > now then
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
        if sleepingBag then
            match = aura.spellID == WELL_RESTED
        elseif item.classBuff then
            match = item.buffIDs and item.buffIDs[aura.spellID]
                or item.spellID == aura.spellID or item.spellName == aura.name
        elseif mapping then
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
    local ready = not item.cooldownEnd or item.cooldownEnd <= now
    local sleepingBag = item.id == M.SleepingBag
    if effect then
        local remaining = effect.expires and effect.expires > 0 and effect.expires - now or nil
        local refresh = remaining and remaining < M.RefreshThreshold(item, settings)
            and (not sleepingBag or ready)
        return { text = M.Time(remaining), glow = not effect.cached and not not refresh,
            active = true, effect = effect, cached = effect.cached,
            status = refresh and "EXPIRING" or "ACTIVE" }
    end
    local mapping = settings.mappings[item.id]
    local isWeapon = not sleepingBag and (mapping and mapping.weapon or (not mapping and (item.weapon
        or (settings.weaponEnchants and settings.weaponEnchants[item.id]))))
    if (isWeapon and (not weapons or not weapons.readable)) or (not isWeapon and not readable) then
        return { text = "?", glow = false, status = "UNKNOWN" }
    end
    return { text = ready and "READY" or ("CD " .. M.Time(item.cooldownEnd - now)),
        glow = not sleepingBag or ready, status = ready and "MISSING" or "COOLDOWN" }
end
