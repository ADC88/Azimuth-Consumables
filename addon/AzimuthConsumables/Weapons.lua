-- Forever exposes weapon enchants separately from player auras. Its own
-- Blizzard_BuffFrame/BuffFrame.lua converts timeLeft from milliseconds.
local _, ns = ...
local W = {}
ns.Weapons = W

local function read(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function W.Read(now)
    local result = { effects = {}, readable = true }
    if C_Item and C_Item.GetWeaponEnchantInfo then
        for _, slot in ipairs({ { hand = "main", enum = 0 }, { hand = "off", enum = 1 } }) do
            local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot.enum)
            enchants = ok and read(enchants) or nil
            if type(enchants) ~= "table" then
                result.readable = false
            else
                for _, entry in pairs(enchants) do
                    entry = read(entry)
                    if type(entry) ~= "table" then result.readable = false
                    else
                        local present, kind = read(entry.hasEnchant), read(entry.enchantType)
                        if present == nil or kind == nil then result.readable = false end
                        -- Ignore permanent enchants. Imbues also occur on
                        -- Forever; exact enchant IDs keep those distinct.
                        if present and (kind == 2 or kind == 3) then
                            local id, ms = read(entry.enchantID), read(entry.timeLeft)
                            if type(id) ~= "number" then result.readable = false
                            else
                                result.effects[#result.effects + 1] = {
                                    enchantID = id, hand = slot.hand,
                                    expires = type(ms) == "number" and ms > 0 and now + ms / 1000 or nil,
                                    icon = read(entry.enchantIconID),
                                }
                            end
                        end
                    end
                end
            end
        end
    elseif GetWeaponEnchantInfo then
        local ok, mh, mt, _, mi, oh, ot, _, oi = pcall(GetWeaponEnchantInfo)
        if not ok then result.readable = false; return result end
        for _, slot in ipairs({ { hand = "main", present = mh, time = mt, id = mi },
            { hand = "off", present = oh, time = ot, id = oi } }) do
            local present, id, ms = read(slot.present), read(slot.id), read(slot.time)
            if present == nil then result.readable = false
            elseif present then
                if type(id) ~= "number" then result.readable = false
                else
                    result.effects[#result.effects + 1] = {
                        enchantID = id, hand = slot.hand,
                        expires = type(ms) == "number" and ms > 0 and now + ms / 1000 or nil,
                    }
                end
            end
        end
    else result.readable = false end
    return result
end

function W.IsCandidate(item)
    if item.subClassID == 6 then return true end -- Item Enhancement
    local name = string.lower(item.name or "")
    local spell = string.lower(item.spellName or "")
    return name:find("sharpening stone", 1, true) ~= nil
        or name:find("weightstone", 1, true) ~= nil
        or name:match(" oil$") ~= nil
        or spell:find("sharpen", 1, true) ~= nil
end

-- Learn only after the clicked consumable's bag count actually fell, and
-- exactly one weapon enchant changed/refreshed. A failed/cancelled use never
-- assigns an arbitrary existing enchant to a stone.
function W.Learn(before, after, oldCount, count, settings, itemID)
    if not before.readable or not after.readable or count >= oldCount then return false end
    local changed = {}
    for _, current in ipairs(after.effects) do
        local same = false
        for _, previous in ipairs(before.effects) do
            if current.hand == previous.hand and current.enchantID == previous.enchantID
                and (not current.expires or not previous.expires or current.expires <= previous.expires + 3) then
                same = true; break
            end
        end
        if not same then changed[#changed + 1] = current end
    end
    if #changed ~= 1 then return false end
    settings.weaponEnchants = settings.weaponEnchants or {}
    local ids = settings.weaponEnchants[itemID] or {}
    ids[changed[1].enchantID] = true
    settings.weaponEnchants[itemID] = ids
    return true
end
