local _, ns = ...
local B = {}
ns.ClassBuffs = B

-- Ranks are ordered from strongest to weakest. Related alternatives share a
-- slot and follow the active choice. The live spellbook also supplies ranks
-- introduced by Forever.
local families = {
    { class = "WARRIOR", ranks = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 } },
    { class = "WARRIOR", ranks = { 469 } },
    { class = "PRIEST", ranks = { 10938, 10937, 2791, 1245, 1244, 1243 }, aliases = { 21562, 21564 } },
    { class = "PRIEST", ranks = { 27841, 14819, 14818, 14752 }, aliases = { 27681 } },
    { class = "PRIEST", ranks = { 10958, 10957, 976 }, aliases = { 27683 } },
    { class = "PRIEST", ranks = { 10952, 10951, 1006, 7128, 588 } },
    { class = "PRIEST", ranks = { 6346 } },
    { class = "PRIEST", ranks = { 15473 } },
    { class = "PRIEST", ranks = { 15286 } },
    { class = "PRIEST", ranks = { 19266, 19265, 19264, 19262, 19261, 2652 } },
    { class = "PRIEST", ranks = { 19312, 19311, 19310, 19309, 19308, 18137 } },
    { class = "MAGE", ranks = { 10157, 10156, 1461, 1460, 1459 }, aliases = { 23028 } },
    { class = "MAGE", group = "armor", ranks = { 22783, 22782, 6117 } },
    { class = "MAGE", group = "armor", ranks = { 30482 } },
    { class = "MAGE", group = "armor", ranks = { 10220, 10219, 7320, 7302, 7301, 168 } },
    { class = "MAGE", group = "magic", ranks = { 10174, 10173, 8451, 8450, 604 } },
    { class = "MAGE", group = "magic", ranks = { 10170, 10169, 8455, 1008 } },
    { class = "DRUID", ranks = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, aliases = { 21849, 21850 } },
    { class = "DRUID", ranks = { 9910, 9756, 8914, 1075, 782, 467 } },
    { class = "DRUID", ranks = { 16864 } },
    { class = "HUNTER", group = "aspect", ranks = { 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
    { class = "HUNTER", group = "aspect", ranks = { 13163 } },
    { class = "HUNTER", group = "aspect", ranks = { 5118 } },
    { class = "HUNTER", group = "aspect", ranks = { 13159 } },
    { class = "HUNTER", group = "aspect", ranks = { 20190, 20043 } },
    { class = "HUNTER", group = "aspect", ranks = { 13161 } },
    { class = "HUNTER", ranks = { 20906, 20905, 19506 } },
    { class = "WARLOCK", group = "armor", ranks = { 11735, 11734, 11733, 1086, 706, 696, 687 } },
    { class = "WARLOCK", group = "armor", ranks = { 28189, 28176 } },
    { class = "WARLOCK", ranks = { 19028 }, aliases = { 25228 } },
    { class = "WARLOCK", ranks = { 5697 } },
    { class = "WARLOCK", ranks = { 11743, 2970, 132 } },
    { class = "SHAMAN", group = "shield", ranks = { 10432, 10431, 8134, 905, 945, 325, 324 } },
    { class = "SHAMAN", group = "shield", ranks = { 408510 } },
    { class = "SHAMAN", group = "shield", ranks = { 408514 } },
    { class = "SHAMAN", ranks = { 546 } },
    { class = "SHAMAN", ranks = { 131 } },
    { class = "SHAMAN", group = "imbue", weapon = true, ranks = { 16362, 10486, 8235, 8232 } },
    { class = "SHAMAN", group = "imbue", weapon = true, ranks = { 16342, 16341, 10456, 8038, 8033 } },
    { class = "SHAMAN", group = "imbue", weapon = true, ranks = { 16339, 16316, 10445, 10400, 8029, 8027, 8024 } },
    { class = "SHAMAN", group = "imbue", weapon = true, ranks = { 16314, 16313, 10408, 10399, 8019, 8018, 8017 } },
    { class = "PALADIN", group = "blessing", ranks = { 20217 }, aliases = { 25898 } },
    { class = "PALADIN", group = "blessing", ranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, aliases = { 25782, 25916 } },
    { class = "PALADIN", group = "blessing", ranks = { 25290, 19854, 19853, 19852, 19850, 19742 }, aliases = { 25894, 25918 } },
    { class = "PALADIN", group = "blessing", ranks = { 20914, 20913, 20912, 20911 }, aliases = { 25899 } },
    { class = "PALADIN", group = "blessing", ranks = { 1038 }, aliases = { 25895 } },
    { class = "PALADIN", group = "blessing", ranks = { 19979, 19978, 19977 } },
    { class = "PALADIN", ranks = { 25780 } },
    { class = "PALADIN", group = "aura", ranks = { 10293, 10292, 10291, 10290, 643, 465 } },
    { class = "PALADIN", group = "aura", ranks = { 10301, 10300, 10299, 7294 } },
    { class = "PALADIN", group = "aura", ranks = { 19746 } },
    { class = "PALADIN", group = "aura", ranks = { 19896, 19895, 19891 } },
    { class = "PALADIN", group = "aura", ranks = { 19898, 19897, 19888 } },
    { class = "PALADIN", group = "aura", ranks = { 19900, 19899, 19876 } },
    { class = "PALADIN", group = "aura", ranks = { 20218 } },
    { class = "PALADIN", group = "seal", ranks = { 20165 } },
    { class = "PALADIN", group = "seal", ranks = { 20166 } },
    { class = "PALADIN", group = "seal", ranks = { 20375 } },
    { class = "PALADIN", group = "seal", ranks = { 20164 } },
    { class = "PALADIN", group = "seal", ranks = { 20293, 20292, 20291, 20290, 20289, 20288, 21084 } },
    { class = "PALADIN", group = "seal", ranks = { 20308, 20307, 20306, 20305, 20304, 20162, 21082 } },
}

local function spellbookRanks()
    local byName = {}
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookItemInfo) then return byName end
    for index = 1, book.GetNumSpellBookSkillLines() do
        local line = book.GetSpellBookSkillLineInfo(index)
        if line then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local entry = book.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if entry and entry.spellID and not entry.isPassive and not entry.isOffSpec then
                    local list = byName[entry.name] or {}
                    list[#list + 1] = entry.spellID
                    byName[entry.name] = list
                end
            end
        end
    end
    return byName
end

function B.Items(settings, auras, effect, now, weapons)
    if settings.hideClassBuffs or not C_Spell then return {} end
    local _, class = UnitClass("player")
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    local bookRanks = spellbookRanks()
    local items, groups = {}, {}
    for _, family in ipairs(families) do
        local base = family.ranks[#family.ranks]
        local info = C_Spell.GetSpellInfo(base)
        if info then
            local cast, ids = nil, {}
            for _, id in ipairs(family.ranks) do
                ids[id] = true
                if not cast and known and known(id) then cast = id end
            end
            for _, id in ipairs(family.aliases or {}) do ids[id] = true end
            for _, id in ipairs(bookRanks[info.name] or {}) do
                ids[id] = true
                if known and known(id) then cast = id end
            end
            if family.class ~= class then cast = nil end
            local item = { id = -base, count = 1, classBuff = true, castSpell = cast,
                spellID = cast or base, spellName = info.name, icon = info.iconID, buffIDs = ids,
                weapon = family.weapon }
            local active = effect(item, auras, settings, now, weapons)
            local disabled = settings.disabledBuffs and settings.disabledBuffs[-base]
            if not disabled and (cast or (not settings.hideUnavailableClassBuffs and (family.class == class or active))) then
                local key = family.class .. ":" .. (family.group or base)
                local preferred = settings.preferredBuffs and settings.preferredBuffs[key] == -base
                local previous = groups[key]
                if not previous then
                    items[#items + 1] = item
                    groups[key] = { index = #items, active = active ~= nil, known = cast ~= nil, preferred = preferred }
                elseif (active and not previous.active)
                    or (not previous.active and cast and (not previous.known or (preferred and not previous.preferred))) then
                    items[previous.index] = item
                    previous.active, previous.known, previous.preferred = active ~= nil, cast ~= nil, preferred
                end
            end
        end
    end
    return items
end

function B.Options()
    local _, class = UnitClass("player")
    local result = {}
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    local book = spellbookRanks()
    for _, family in ipairs(families) do
        if family.class == class then
            local base = family.ranks[#family.ranks]
            local info = C_Spell and C_Spell.GetSpellInfo(base)
            if info then
                local available = false
                for _, id in ipairs(family.ranks) do
                    if known and known(id) then available = true; break end
                end
                for _, id in ipairs(book[info.name] or {}) do
                    if known and known(id) then available = true; break end
                end
                result[#result + 1] = { id = -base, name = info.name,
                    group = family.group and (family.class .. ":" .. family.group), available = available }
            end
        end
    end
    return result
end
