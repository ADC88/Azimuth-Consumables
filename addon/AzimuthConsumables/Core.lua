local ADDON, ns = ...
local M = ns.Model
local W = ns.Weapons
local db, char, bar, picker
local buttons, items, itemByID, auras = {}, {}, {}, {}
local auraReadable, initialized = true, false
local requested, metadata = {}, {}
local weapons = { effects = {}, readable = false }
local pendingWeapon, layoutSignature
local queueLayout
local SIZE, GAP, COLUMNS = 40, 7, 8
local EXPRESSWAY = [[Interface\AddOns\EllesmereUI\media\fonts\Expressway.TTF]]

local function secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function read(value)
    if secret(value) then return nil end
    return value
end

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function say(text)
    print("|cff61d9c4Azimuth Consumables:|r " .. text)
end

-- Forever's C_UnitAuras can return restricted data during combat. Unknown
-- data is displayed as '?' rather than falsely claiming a buff is missing.
local function scanAuras()
    auras, auraReadable = {}, true
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then auraReadable = false; return end
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or secret(aura) then auraReadable = false; break end
        if not aura then break end
        local id, name = read(aura.spellId), read(aura.name)
        if not id or not name then
            auraReadable = false
        else
            local expires = read(aura.expirationTime)
            auras[#auras + 1] = {
                spellID = id, name = name, expires = expires,
                duration = read(aura.duration), icon = read(aura.icon),
            }
        end
    end
end

local function scanBags()
    local slots = {}
    if not (C_Container and C_Item) then return end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and read(info.itemID)
            if id then
                local cached = metadata[id]
                if not cached then
                    local _, _, _, _, icon, classID, subClassID = C_Item.GetItemInfoInstant(id)
                    local name = C_Item.GetItemInfo(id)
                    local spellName, spellID = C_Item.GetItemSpell(id)
                    cached = { name = name or ("Item " .. id), icon = icon, classID = classID,
                        subClassID = subClassID, spellName = spellName, spellID = spellID }
                    if name then metadata[id] = cached end
                    if (not name or not classID) and not requested[id] and C_Item.RequestLoadItemDataByID then
                        requested[id] = true
                        C_Item.RequestLoadItemDataByID(id)
                    end
                end
                if cached.classID == 0 or db.mappings[id] then
                    slots[#slots + 1] = {
                        id = id, count = read(info.stackCount) or 0, name = cached.name,
                        icon = cached.icon, classID = cached.classID, subClassID = cached.subClassID,
                        spellName = cached.spellName, spellID = cached.spellID,
                        weapon = W.IsCandidate(cached),
                    }
                end
            end
        end
    end
    items, itemByID = M.Items(slots, db), {}
    for _, item in ipairs(items) do itemByID[item.id] = item end
end

local function setTextFont(text, size, flags, fallback)
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    local registered = media and media:Fetch("font", "Expressway", true)
    if registered then
        local ok, applied = pcall(text.SetFont, text, registered, size, flags)
        if ok and applied then return end
    end
    local ok, applied = pcall(text.SetFont, text, EXPRESSWAY, size, flags)
    if not (ok and applied) then text:SetFont(fallback, size, flags) end
end

local function label(parent, size, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY")
    setTextFont(text, size, "OUTLINE", STANDARD_TEXT_FONT)
    text:SetPoint(point, parent, point, x, y)
    return text
end

local function closePicker()
    if picker then picker:Hide() end
end

local function pollWeapons()
    weapons = W.Read(GetTime())
    if pendingWeapon then
        if GetTime() > pendingWeapon.deadline then pendingWeapon = nil
        elseif C_Item and C_Item.GetItemCount then
            local count = read(C_Item.GetItemCount(pendingWeapon.id, false, false))
            if type(count) == "number" and W.Learn(pendingWeapon.before, weapons,
                pendingWeapon.count, count, db, pendingWeapon.id) then pendingWeapon = nil end
        end
    end
end

local rebuild
local function openPicker(item)
    if combat() then say("Link buffs after leaving combat."); return end
    scanAuras()
    pollWeapons()
    if not picker then
        picker = CreateFrame("Frame", "AzimuthConsumablesBuffPicker", UIParent, "BackdropTemplate")
        picker:SetSize(330, 380)
        picker:SetPoint("CENTER")
        picker:SetFrameStrata("DIALOG")
        picker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        picker:SetBackdropColor(0.04, 0.06, 0.09, 0.98)
        picker:SetBackdropBorderColor(0.25, 0.7, 0.6, 1)
        picker.title = label(picker, 12, "TOPLEFT", 12, -15)
        local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        close:SetScript("OnClick", closePicker)
        local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -65)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(280, 1)
        scroll:SetScrollChild(content)
        picker.content, picker.rows = content, {}
        label(picker, 10, "TOPLEFT", 12, -40):SetText("Choose the buff this item provides. Scroll for more.")
        table.insert(UISpecialFrames, "AzimuthConsumablesBuffPicker")
    end
    picker.title:SetText(item.name .. " - link effect")
    picker.itemID = item.id
    local choices = { { name = "Automatic matching (reset)", reset = true } }
    for _, effect in ipairs(weapons.effects) do
        choices[#choices + 1] = {
            name = (effect.hand == "main" and "Main hand" or "Off hand") .. ": weapon enchant " .. effect.enchantID,
            weapon = true, hand = effect.hand, enchantID = effect.enchantID,
        }
    end
    local seen = {}
    for _, aura in ipairs(auras) do
        if not seen[aura.spellID] then
            seen[aura.spellID] = true
            choices[#choices + 1] = aura
        end
    end
    for i, choice in ipairs(choices) do
        local row = picker.rows[i]
        if not row then
            row = CreateFrame("Button", nil, picker.content, "UIPanelButtonTemplate")
            row:SetSize(275, 25)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 29)
            local text = row:GetFontString()
            local font, size, flags = text:GetFont()
            setTextFont(text, size, flags, font)
            row:SetScript("OnClick", function(self)
                if combat() then say("Link buffs after leaving combat."); return end
                if self.choice.reset then db.mappings[picker.itemID] = nil
                elseif self.choice.weapon then db.mappings[picker.itemID] = {
                    weapon = true, hand = self.choice.hand, enchantID = self.choice.enchantID,
                }
                else db.mappings[picker.itemID] = { self.choice.spellID } end
                say("Updated effect link. Use /azc map for multiple buff IDs.")
                closePicker()
                rebuild()
            end)
            picker.rows[i] = row
        end
        row.choice = choice
        row:SetText(choice.name .. (choice.spellID and (" (" .. choice.spellID .. ")") or ""))
        row:Show()
    end
    for i = #choices + 1, #picker.rows do picker.rows[i]:Hide() end
    picker.content:SetHeight(math.max(1, #choices * 29))
    picker:Show()
end

local function isWeaponConsumable(item)
    if not item then return false end
    local mapping = db.mappings[item.id]
    return item.weapon or db.weaponEnchants[item.id] or (mapping and mapping.weapon)
end

local function newButton()
    local b = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type1", "item")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
    -- Plain textures can animate during lockdown; no secure visibility or
    -- attributes are changed when a timer updates.
    b.glow = CreateFrame("Frame", nil, b)
    b.glow:SetPoint("TOPLEFT", -3, 3)
    b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local tex = b.glow:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(1, 0.72, 0.16, 1)
        if edge == "TOP" or edge == "BOTTOM" then
            tex:SetHeight(3); tex:SetPoint(edge .. "LEFT"); tex:SetPoint(edge .. "RIGHT")
        else
            tex:SetWidth(3); tex:SetPoint("TOP" .. edge); tex:SetPoint("BOTTOM" .. edge)
        end
    end
    b.count = label(b, 11, "TOPRIGHT", -2, -2)
    b.time = label(b, 10, "BOTTOM", 0, 2)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item.id)
        GameTooltip:AddLine("Left-click: use. Right-click: link active buff.", 0.4, 1, 0.8, true)
        GameTooltip:AddLine("Shift-right-click: hide this item. /azc restore to restore.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:HookScript("PreClick", function(self, mouse, down)
        if mouse ~= "LeftButton" or down or not isWeaponConsumable(self.item) then return end
        pollWeapons()
        local count = C_Item.GetItemCount and read(C_Item.GetItemCount(self.item.id, false, false))
        if type(count) == "number" then
            pendingWeapon = { id = self.item.id, count = count, before = weapons, deadline = GetTime() + 45 }
        end
    end)
    b:HookScript("PostClick", function(self, mouse, down)
        if down or not self.item then return end
        if mouse == "LeftButton" then
            local item = itemByID[self.item.id]
            if item and item.count > 0 and isWeaponConsumable(item) and not combat() and ToggleCharacter then
                -- onlyShow keeps the equipment tab open on repeated clicks.
                ToggleCharacter("PaperDollFrame", true)
            end
            return
        end
        if mouse ~= "RightButton" then return end
        if IsShiftKeyDown() then
            db.hidden[self.item.id] = true
            rebuild()
        else
            openPicker(self.item)
        end
    end)
    return b
end

local function paint()
    local now = GetTime()
    for _, b in ipairs(buttons) do
        if b:IsShown() and b.item then
            local current = itemByID[b.item.id]
            local item = current or b.item
            local start, duration, enabled = 0, 0, 1
            if C_Container.GetItemCooldown then start, duration, enabled = C_Container.GetItemCooldown(item.id) end
            start, duration, enabled = read(start) or 0, read(duration) or 0, read(enabled)
            item.cooldownEnd = duration > 1.5 and start + duration or nil
            local state = M.State(item, auras, db, now, auraReadable, weapons)
            b.count:SetText(current and current.count or 0)
            b.time:SetText(state.text)
            b.time:SetTextColor(state.active and 0.4 or 1, state.active and 1 or 0.85, state.active and 0.65 or 0.4)
            b.glow:SetAlpha(state.glow and (0.55 + 0.45 * math.sin(now * 4) ^ 2) or 0)
            local usable = C_Item.IsUsableItem(item.id)
            b.icon:SetDesaturated(not current or item.count == 0 or enabled == 0 or not read(usable))
            if duration > 1.5 then b.cooldown:SetCooldown(start, duration) else b.cooldown:Clear() end
            if item.count == 0 and not state.active and queueLayout and not combat() then queueLayout() end
        end
    end
end

rebuild = function()
    if not initialized then return end
    pollWeapons()
    scanBags()
    -- Keep an active timer after consuming the last copy; show a dim icon and
    -- zero count until the effect expires. It then leaves the bar out of combat.
    for _, button in ipairs(buttons) do
        local previous = button.item
        if previous and not db.hidden[previous.id] and not itemByID[previous.id]
            and M.Effect(previous, auras, db, GetTime(), weapons) then
            local tracked = {}
            for k, v in pairs(previous) do tracked[k] = v end
            tracked.count = 0
            items[#items + 1] = tracked
            itemByID[tracked.id] = tracked
        end
    end
    if combat() then paint(); return end
    -- Keep picker contents stable while bag/item-data events arrive. Rebuilding
    -- the bar must not close or repurpose a row the player is about to click.
    local p = char.position or { "CENTER", "CENTER", 0, -200 }
    local signatureParts = { tostring(db.scale), tostring(db.disabled), table.concat(p, ":") }
    for _, item in ipairs(items) do signatureParts[#signatureParts + 1] = tostring(item.id) end
    local signature = table.concat(signatureParts, "|")
    if signature == layoutSignature then
        for _, b in ipairs(buttons) do if b.item and itemByID[b.item.id] then b.item = itemByID[b.item.id] end end
        paint()
        return
    end
    layoutSignature = signature
    local width = math.max(240, math.min(#items, COLUMNS) * (SIZE + GAP) + GAP)
    bar:SetSize(width, 28 + math.max(1, math.ceil(#items / COLUMNS)) * (SIZE + GAP))
    bar:ClearAllPoints()
    bar:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    bar:SetScale(db.scale)
    for i, item in ipairs(items) do
        local b = buttons[i]
        if not b then b = newButton(); buttons[i] = b end
        b.item = item
        b:SetAttribute("item1", "item:" .. item.id)
        b.icon:SetTexture(item.icon or 134400)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", GAP + ((i - 1) % COLUMNS) * (SIZE + GAP), -27 - math.floor((i - 1) / COLUMNS) * (SIZE + GAP))
        b:Show()
    end
    for i = #items + 1, #buttons do
        buttons[i]:SetAttribute("item1", nil)
        buttons[i].item = nil
        buttons[i]:Hide()
    end
    bar.empty:SetShown(#items == 0)
    bar:SetShown(not db.disabled)
    paint()
end

local function initialize()
    if initialized or combat() then return end
    AzimuthConsumablesDB = type(AzimuthConsumablesDB) == "table" and AzimuthConsumablesDB or {}
    AzimuthConsumablesCharDB = type(AzimuthConsumablesCharDB) == "table" and AzimuthConsumablesCharDB or {}
    db, char = AzimuthConsumablesDB, AzimuthConsumablesCharDB
    db.hidden = type(db.hidden) == "table" and db.hidden or {}
    db.mappings = type(db.mappings) == "table" and db.mappings or {}
    db.weaponEnchants = type(db.weaponEnchants) == "table" and db.weaponEnchants or {}
    for id, mapping in pairs(db.mappings) do
        if type(mapping) ~= "table" then db.mappings[id] = nil end
    end
    for id, ids in pairs(db.weaponEnchants) do
        if type(ids) ~= "table" then db.weaponEnchants[id] = nil end
    end
    local p = char.position
    local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    if type(p) ~= "table" or not anchors[p[1]] or not anchors[p[2]]
        or type(p[3]) ~= "number" or type(p[4]) ~= "number" then char.position = nil end
    db.scale = math.max(0.6, math.min(2, tonumber(db.scale) or 1))
    bar = CreateFrame("Frame", "AzimuthConsumablesBar", UIParent, "BackdropTemplate")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bar:SetBackdropColor(0.025, 0.04, 0.06, 0.88)
    local header = CreateFrame("Button", nil, bar)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(24)
    header:RegisterForDrag("LeftButton")
    label(header, 11, "LEFT", 8, 0):SetText("|cff61d9c4AZIMUTH|r  Consumables")
    header:SetScript("OnDragStart", function() if not combat() and not db.locked then bar:StartMoving() end end)
    local function stopDrag()
        if combat() then return end
        bar:StopMovingOrSizing()
        local point, _, relPoint, x, y = bar:GetPoint()
        char.position = { point, relPoint, x, y }
    end
    header:SetScript("OnDragStop", stopDrag)
    ns.StopDrag = stopDrag
    bar.empty = label(bar, 10, "BOTTOMLEFT", 8, 12)
    bar.empty:SetText("No usable consumables in bags. /azc help")
    local elapsed = 0
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.2 then elapsed = 0; pollWeapons(); paint() end
    end)
    initialized = true
    scanAuras()
    rebuild()
    say("Loaded. Drag the header to move; /azc help for options.")
end

SLASH_AZIMUTHCONSUMABLES1 = "/azc"
SlashCmdList.AZIMUTHCONSUMABLES = function(message)
    if not initialized then say("Ready after combat ends."); return end
    local command, args = message:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "lock" then db.locked = true; say("Position locked.")
    elseif command == "unlock" then db.locked = false; say("Drag the header to move.")
    elseif command == "hide" then db.disabled = true; closePicker(); rebuild()
    elseif command == "show" then db.disabled = false; rebuild()
    elseif command == "restore" then db.hidden = {}; rebuild()
    elseif command == "scale" and tonumber(args) then db.scale = math.max(0.6, math.min(2, tonumber(args))); rebuild()
    elseif command == "reset" then char.position = nil; db.scale = 1; rebuild()
    elseif command == "map" then
        local idText, spells = args:match("^(%d+)%s+(.+)$")
        if not idText then say("/azc map ITEM_ID BUFF_ID [BUFF_ID ...], auto, main, off, or either"); return end
        local id, ids = tonumber(idText), {}
        if spells == "auto" then db.mappings[id] = nil; db.weaponEnchants[id] = nil
        elseif spells == "main" or spells == "off" or spells == "either" then
            pollWeapons()
            local found
            for _, effect in ipairs(weapons.effects) do
                if spells == "either" or spells == effect.hand then found = effect; break end
            end
            if not found then say("Apply the stone first, then link its active weapon enchant."); return end
            db.mappings[id] = { weapon = true, hand = spells, enchantID = found.enchantID }
        else
            for n in spells:gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
            if #ids == 0 then say("Specify at least one buff spell ID."); return end
            db.mappings[id] = ids
        end
        rebuild()
    elseif command == "buffs" then
        scanAuras()
        for _, aura in ipairs(auras) do say(aura.spellID .. " - " .. aura.name) end
    else
        say("Left-click uses an item; right-click links its active buff; Shift-right-click hides it.")
        say("/azc lock | unlock | hide | show | restore | scale 1.2 | reset | buffs")
        say("/azc map ITEM_ID BUFF_ID [BUFF_ID ...] - link custom effects. Glow = missing; countdown = active effect; CD = reuse cooldown.")
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
    events:RegisterEvent(event)
end
local scheduled = false
local function rebuildSoon()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0, function() scheduled = false; rebuild() end)
end
queueLayout = rebuildSoon
events:SetScript("OnEvent", function(_, event, unit, success)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        initialize()
        if initialized then scanAuras(); rebuildSoon() end
    elseif not initialized then return
    elseif event == "PLAYER_REGEN_DISABLED" then
        closePicker()
        -- Starting combat automatically stops protected layout changes.
    elseif event == "UNIT_AURA" then
        if secret(unit) then return end
        if unit == "player" then scanAuras(); paint() end
    elseif event == "BAG_UPDATE_COOLDOWN" then paint()
    elseif event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
        -- Ignore unrelated item-cache activity. A completed request is removed
        -- before refreshing so cached reads cannot trigger a rebuild storm.
        if not secret(unit) and requested[unit] then
            requested[unit] = nil
            if success then metadata[unit] = nil; rebuildSoon() end
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if not secret(unit) and unit == "player" then pollWeapons(); rebuildSoon() end
    else
        if event == "PLAYER_ENTERING_WORLD" then scanAuras() end
        rebuildSoon()
    end
end)

ns.Refresh, ns.Buttons = rebuild, buttons
