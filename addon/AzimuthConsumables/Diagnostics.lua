local _, ns = ...
local D = {}
ns.Diagnostics = D

function D.Build(context)
    local db = context.settings
    local lines = {
        "Azimuth Consumables " .. context.version,
        "Class: " .. context.class .. " | Profile: " .. context.profile .. " | Spec: " .. context.spec,
        "Combat: " .. tostring(context.combat) .. " | Aura data readable: " .. tostring(context.auraReadable)
            .. " | Weapon data readable: " .. tostring(context.weapons.readable),
        ("Layout: %s, %d per line, %dpx icons, %dpx spacing, timer %dpx, count %dpx"):format(
            db.vertical and "vertical" or "horizontal", db.iconsPerLine, db.iconSize,
            db.spacing, db.timerTextSize, db.countTextSize),
        "Class buffs hidden: " .. tostring(not not db.hideClassBuffs)
            .. " | Unavailable buffs hidden: " .. tostring(db.hideUnavailableClassBuffs),
        "",
        "Tracked entries",
    }
    local function wanted(id, cast)
        return not context.query or context.query == math.abs(id) or context.query == cast
    end
    for _, item in ipairs(context.items) do
        if wanted(item.id, item.castSpell) then
            local state = ns.Model.State(item, context.auras, db, context.now, context.auraReadable, context.weapons)
            local effect = state.effect
            local match = effect and (effect.spellID or effect.enchantID or effect.name) or "none"
            local status = context.statuses[item.id] or state.status
            lines[#lines + 1] = ("%s #%d | status=%s | timer=%s | estimated=%s | match=%s | hand=%s | cast=%s | count=%d | refresh=%ds"):format(
                item.name or item.spellName or "Item", item.id, status, state.text,
                tostring(not not state.cached), tostring(match), tostring(effect and effect.hand or "none"),
                tostring(item.castSpell or item.spellID), item.count or 0,
                ns.Model.RefreshThreshold(item, db))
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Bag selection"
    local ids = {}
    for id, item in pairs(context.bags) do
        if wanted(id) and (context.query or item.classID == 0 or id == ns.Model.SleepingBag or db.hidden[id] or db.mappings[id]) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local item = context.bags[id]
        lines[#lines + 1] = ("%s #%d | %s | spell=%s | count=%d"):format(
            item.name or "Item", id, ns.Model.SelectionReason(item, db), tostring(item.spellID), item.count)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Class buff selection"
    local tracked = {}
    for _, item in ipairs(context.items) do tracked[item.id] = true end
    for _, choice in ipairs(context.choices) do
        if wanted(choice.id) then
            local reason = "Enabled; slot follows learned spells, active alternatives and preferred choice"
            if db.hideClassBuffs then reason = "All class buffs hidden"
            elseif db.disabledBuffs[choice.id] then reason = "Disabled individually"
            elseif db.hideUnavailableClassBuffs and not choice.available then reason = "Unavailable in this loadout"
            elseif not tracked[choice.id] and choice.group then reason = "Another choice occupies this buff slot" end
            local preferred = choice.group and db.preferredBuffs[choice.group]
            lines[#lines + 1] = ("%s #%d | %s | preferred=%s"):format(
                choice.name, choice.id, reason, tostring(preferred or "automatic"))
        end
    end
    if context.query and not context.bags[context.query] then
        lines[#lines + 1] = "Requested item is not in the current bag snapshot. Class spell IDs are listed above when matched."
    end
    return table.concat(lines, "\n")
end

function D.Show(report)
    if not D.frame then
        local frame = CreateFrame("Frame", "AzimuthConsumablesDiagnostics", UIParent, "BackdropTemplate")
        frame:SetSize(650, 480)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        frame:SetBackdropColor(0.025, 0.04, 0.06, 0.98)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("AZC diagnostics — Ctrl+A, Ctrl+C to copy")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -45)
        scroll:SetPoint("BOTTOMRIGHT", -34, 16)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(590)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnTextChanged", function(self)
            self:SetHeight(math.max(400, self:GetStringHeight() + 20))
        end)
        scroll:SetScrollChild(edit)
        scroll:SetScript("OnSizeChanged", function(_, width) edit:SetWidth(math.max(1, width)) end)
        frame:SetScript("OnHide", function() edit:ClearFocus() end)
        D.frame, D.edit = frame, edit
        table.insert(UISpecialFrames, "AzimuthConsumablesDiagnostics")
    end
    D.edit:SetText(report)
    D.frame:Show()
    D.edit:SetFocus()
    D.edit:HighlightText()
end
