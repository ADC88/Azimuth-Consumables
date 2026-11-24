local _, ns = ...
local unpack = unpack or table.unpack
local editors = {}

local function button(parent, text, width, action)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetText(text)
    control:SetScript("OnClick", action)
    return control
end

local function input(parent, width)
    local control = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    control:SetSize(width, 24)
    control:SetAutoFocus(false)
    editors[#editors + 1] = control
    control:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return control
end

local function scrollContent(panel, top)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, top)
    scroll:SetPoint("BOTTOMRIGHT", -36, 20)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(500, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    return content
end

local function saveSeconds(control, settings, key, status)
    if ns.ProfileChanging then return false end
    local text = (control:GetText() or ""):match("^%s*(.-)%s*$")
    local number = tonumber(text)
    if text ~= "" and (not number or number ~= number or number < 0 or number > 3600) then
        status:SetText("Enter 0 to 3600 seconds, or leave blank to use the default.")
        return false
    end
    settings[key] = text ~= "" and ns.Model.RefreshSeconds(number) or nil
    status:SetText("")
    return true
end

function ns.RegisterAdvancedOptions(parentCategory, apply, label)
    ns.CancelOptionsEditing = function()
        ns.ProfileChanging = true
        for _, editor in ipairs(editors) do
            if editor:HasFocus() then editor:ClearFocus() end
        end
        ns.ProfileChanging = false
    end
    local panels, categories, refreshers = {}, {}, {}
    local function panel(name, globalName)
        local frame = CreateFrame("Frame", globalName)
        frame:Hide()
        label(frame, 20, "TOPLEFT", 16, -16):SetText(name)
        local category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, name)
        frame:SetScript("OnShow", function() refreshers[name]() end)
        panels[name], categories[name] = frame, category
        return frame
    end

    local layoutPanel = panel("Layout and status", "AzimuthConsumablesLayoutOptions")
    local layoutStatus = label(layoutPanel, 11, "TOPLEFT", 16, -50)
    local fields = {
        { key = "iconsPerLine", text = "Icons per row / column", min = 1, max = 20, default = 8 },
        { key = "iconSize", text = "Icon size", min = 24, max = 80, default = 40 },
        { key = "spacing", text = "Icon spacing", min = 0, max = 20, default = 7 },
        { key = "timerTextSize", text = "Timer text size", min = 8, max = 20, default = 10 },
        { key = "countTextSize", text = "Stack count text size", min = 8, max = 20, default = 11 },
    }
    for index, field in ipairs(fields) do
        local y = -86 - (index - 1) * 40
        label(layoutPanel, 12, "TOPLEFT", 16, y - 6):SetText(field.text)
        field.input = input(layoutPanel, 70)
        field.input:SetPoint("TOPLEFT", 210, y)
        local function save(self)
            if ns.ProfileChanging then return end
            local value = tonumber(self:GetText())
            if not value or value ~= value or value < field.min or value > field.max then
                layoutStatus:SetText(("Enter %d to %d for %s."):format(field.min, field.max, field.text:lower()))
                return
            end
            ns.GetSettings()[field.key] = ns.Model.Number(value, field.default, field.min, field.max)
            layoutStatus:SetText("")
            apply()
            refreshers["Layout and status"]()
        end
        field.input:SetScript("OnEnterPressed", function(self) save(self); self:ClearFocus() end)
        field.input:SetScript("OnEditFocusLost", save)
    end
    local vertical = CreateFrame("CheckButton", nil, layoutPanel, "UICheckButtonTemplate")
    vertical:SetPoint("TOPLEFT", 310, -79)
    label(vertical, 12, "LEFT", 32, 0):SetText("Vertical layout")
    vertical:SetScript("OnClick", function(self)
        ns.GetSettings().vertical = self:GetChecked()
        apply()
        refreshers["Layout and status"]()
    end)
    label(layoutPanel, 12, "TOPLEFT", 310, -125):SetText("Preview (scaled to fit)")
    local preview = CreateFrame("Frame", nil, layoutPanel)
    preview:SetPoint("TOPLEFT", 310, -154)
    local previewIcons = {}
    for index = 1, 6 do
        local sample = CreateFrame("Frame", nil, preview)
        local texture = sample:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexture(134400)
        sample.count = label(sample, 11, "TOPRIGHT", -2, -2)
        sample.count:SetText("5")
        sample.time = label(sample, 10, "BOTTOM", 0, 2)
        sample.time:SetText("1:30")
        previewIcons[index] = sample
    end
    button(layoutPanel, "Reset layout", 140, function()
        local settings = ns.GetSettings()
        for _, field in ipairs(fields) do settings[field.key] = field.default end
        settings.vertical = false
        apply()
        refreshers["Layout and status"]()
    end):SetPoint("TOPLEFT", 16, -300)
    button(layoutPanel, "Diagnostic report", 160, function() ns.ShowDebug() end):SetPoint("TOPLEFT", 16, -340)
    local statusOrder = { "ACTIVE", "EXPIRING", "MISSING", "COOLDOWN", "RESOURCE", "UNAVAILABLE", "EMPTY", "UNKNOWN" }
    for index, code in ipairs(statusOrder) do
        local status = ns.Model.Statuses[code]
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local text = label(layoutPanel, 11, "TOPLEFT", 16 + column * 280, -396 - row * 24)
        text:SetText((status.badge ~= "" and (status.badge .. " — ") or "") .. status.label)
        text:SetTextColor(unpack(status.color))
    end
    label(layoutPanel, 11, "TOPLEFT", 16, -510):SetText("Layout changes apply after combat. Preview icons demonstrate your saved layout.")
    refreshers["Layout and status"] = function()
        local settings = ns.GetSettings()
        for _, field in ipairs(fields) do
            if not field.input:HasFocus() then field.input:SetText(settings[field.key]) end
        end
        vertical:SetChecked(settings.vertical)
        local layout = ns.Model.Layout(6, settings)
        preview:SetSize(math.max(1, layout.width), math.max(1, layout.height))
        preview:SetScale(math.min(1, 240 / math.max(1, layout.width), 220 / math.max(1, layout.height)))
        for index, sample in ipairs(previewIcons) do
            local column, row = (index - 1) % layout.perLine, math.floor((index - 1) / layout.perLine)
            if settings.vertical then column, row = row, column end
            sample:SetSize(layout.size, layout.size)
            sample:ClearAllPoints()
            sample:SetPoint("TOPLEFT", layout.gap + column * (layout.size + layout.gap), -row * (layout.size + layout.gap))
            local path = sample.time:GetFont()
            sample.time:SetFont(path, settings.timerTextSize, "OUTLINE")
            sample.count:SetFont(path, settings.countTextSize, "OUTLINE")
        end
    end

    local profiles = panel("Profiles", "AzimuthConsumablesProfiles")
    local profileName = label(profiles, 13, "TOPLEFT", 16, -54)
    label(profiles, 12, "TOPLEFT", 16, -83):SetText("Choose where this character saves AZC settings.")
    for index, mode in ipairs({ { "shared", "Shared" }, { "character", "Character" }, { "spec", "Spec" } }) do
        local control = button(profiles, mode[2], 108, function() ns.SetProfileMode(mode[1]) end)
        control:SetPoint("TOPLEFT", 16 + (index - 1) * 116, -112)
    end
    local profileHelp = label(profiles, 12, "TOPLEFT", 16, -156)
    profileHelp:SetWidth(500)
    profileHelp:SetJustifyH("LEFT")
    profileHelp:SetText("Shared settings are available to every character. Character and spec profiles start from shared settings. Each profile saves its buff choices, reminders, appearance and blacklist. Character and spec profiles also save their own bar position.")
    local copyShared = button(profiles, "Copy shared settings into this profile", 300, ns.CopySharedProfile)
    copyShared:SetPoint("TOPLEFT", 16, -239)
    label(profiles, 11, "TOPLEFT", 16, -277):SetText("Profile switches apply after combat. Copying replaces this profile's settings.")
    refreshers.Profiles = function()
        local character = ns.GetCharacterSettings()
        local mode = character.profileMode or "shared"
        profileName:SetText("Active: " .. (ns.ProfileName or "Shared settings"))
        copyShared:SetEnabled(mode ~= "shared")
    end

    local buffs = panel("Class buffs", "AzimuthConsumablesClassBuffOptions")
    label(buffs, 11, "TOPLEFT", 16, -52):SetText("Choose buffs to track. Preferred choices are offered when their slot has no active buff.")
    label(buffs, 11, "TOPLEFT", 16, -74):SetText("Refresh seconds: blank uses the default; 0 reminds only when missing.")
    local buffStatus = label(buffs, 11, "TOPLEFT", 16, -99)
    local buffContent = scrollContent(buffs, -128)
    local buffRows = {}
    refreshers["Class buffs"] = function()
        local settings = ns.GetSettings()
        local choices = ns.ClassBuffs.Options()
        for index, choice in ipairs(choices) do
            local row = buffRows[index]
            if not row then
                row = CreateFrame("Frame", nil, buffContent)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 38)
                row:SetPoint("RIGHT")
                row:SetHeight(38)
                row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.enabled:SetPoint("LEFT", 0, 0)
                row.name = label(row, 12, "LEFT", 34, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -218, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWordWrap(false)
                row.enabled:SetScript("OnClick", function(self)
                    ns.GetSettings().disabledBuffs[row.choice.id] = not self:GetChecked() or nil
                    apply()
                end)
                row.prefer = button(row, "Prefer", 86, function()
                    local db = ns.GetSettings()
                    local key = row.choice.group
                    db.preferredBuffs[key] = db.preferredBuffs[key] ~= row.choice.id and row.choice.id or nil
                    apply()
                    refreshers["Class buffs"]()
                end)
                row.prefer:SetPoint("RIGHT", -112, 0)
                row.seconds = input(row, 56)
                row.seconds:SetPoint("RIGHT", -26, 0)
                label(row, 11, "RIGHT", -4, 0):SetText("s")
                row.seconds:SetScript("OnEnterPressed", function(self)
                    if saveSeconds(self, ns.GetSettings().refreshThresholds, row.choice.id, buffStatus) then
                        self:ClearFocus()
                        apply()
                    end
                end)
                row.seconds:SetScript("OnEditFocusLost", function(self)
                    if saveSeconds(self, ns.GetSettings().refreshThresholds, row.choice.id, buffStatus) then apply() end
                end)
                buffRows[index] = row
            end
            row.choice = choice
            row.enabled:SetChecked(not settings.disabledBuffs[choice.id])
            row.name:SetText(choice.name)
            row.prefer:SetShown(choice.group ~= nil)
            if choice.group then
                row.prefer:SetText(settings.preferredBuffs[choice.group] == choice.id and "Preferred" or "Prefer")
            end
            if not row.seconds:HasFocus() then row.seconds:SetText(settings.refreshThresholds[choice.id] or "") end
            row:Show()
        end
        for index = #choices + 1, #buffRows do buffRows[index]:Hide() end
        buffContent:SetHeight(math.max(1, #choices * 38))
    end

    local reminders = panel("Reminders", "AzimuthConsumablesReminderOptions")
    label(reminders, 11, "TOPLEFT", 16, -52):SetText("Glow when an active buff has less than this many seconds left. Maximum 3600.")
    label(reminders, 11, "TOPLEFT", 16, -74):SetText("Use 0 for missing-only reminders. Blank item or buff values inherit the default.")
    local reminderStatus = label(reminders, 11, "TOPLEFT", 16, -101)
    label(reminders, 12, "TOPLEFT", 16, -143):SetText("Default refresh seconds")
    local defaultSeconds = input(reminders, 80)
    defaultSeconds:SetPoint("TOPLEFT", 226, -137)
    defaultSeconds:SetScript("OnEnterPressed", function(self)
        if saveSeconds(self, ns.GetSettings(), "refreshDefault", reminderStatus) then self:ClearFocus(); apply() end
    end)
    defaultSeconds:SetScript("OnEditFocusLost", function(self)
        if saveSeconds(self, ns.GetSettings(), "refreshDefault", reminderStatus) then apply() end
    end)
    label(reminders, 12, "TOPLEFT", 16, -185):SetText("Sleeping bag refresh seconds")
    local bagSeconds = input(reminders, 80)
    bagSeconds:SetPoint("TOPLEFT", 226, -179)
    bagSeconds:SetScript("OnEnterPressed", function(self)
        if saveSeconds(self, ns.GetSettings().refreshThresholds, ns.Model.SleepingBag, reminderStatus) then
            self:ClearFocus()
            apply()
        end
    end)
    bagSeconds:SetScript("OnEditFocusLost", function(self)
        if saveSeconds(self, ns.GetSettings().refreshThresholds, ns.Model.SleepingBag, reminderStatus) then apply() end
    end)
    label(reminders, 11, "TOPLEFT", 16, -218):SetText("The sleeping bag defaults to 300 seconds. Class buffs have individual controls in Class buffs.")
    local needsRefresh = CreateFrame("CheckButton", nil, reminders, "UICheckButtonTemplate")
    needsRefresh:SetPoint("TOPLEFT", 14, -244)
    label(needsRefresh, 12, "LEFT", 32, 0):SetText("Only show missing or expiring consumables")
    needsRefresh:SetScript("OnClick", function(self)
        ns.GetSettings().onlyNeedsRefresh = self:GetChecked()
        apply()
    end)
    label(reminders, 12, "TOPLEFT", 16, -287):SetText("Reapplication threshold (seconds)")
    local needsSeconds = input(reminders, 80)
    needsSeconds:SetPoint("TOPLEFT", 280, -281)
    local function saveNeedsSeconds(self)
        if ns.ProfileChanging then return end
        if saveSeconds(self, ns.GetSettings(), "needsRefreshSeconds", reminderStatus) then
            ns.GetSettings().needsRefreshSeconds = ns.Model.Number(ns.GetSettings().needsRefreshSeconds, 300, 0, 3600)
            apply()
        end
    end
    needsSeconds:SetScript("OnEnterPressed", function(self) saveNeedsSeconds(self); self:ClearFocus() end)
    needsSeconds:SetScript("OnEditFocusLost", saveNeedsSeconds)
    label(reminders, 11, "TOPLEFT", 16, -322):SetText("Item overrides take priority. 0 shows only missing effects. Class buffs keep their own controls.")
    label(reminders, 12, "TOPLEFT", 16, -360):SetText("Consumable item ID or link")
    local itemID, seconds = input(reminders, 190), input(reminders, 70)
    itemID:SetPoint("TOPLEFT", 22, -385)
    seconds:SetPoint("LEFT", itemID, "RIGHT", 18, 0)
    label(reminders, 11, "TOPLEFT", 310, -391):SetText("seconds")
    local reminderContent = scrollContent(reminders, -433)
    local reminderRows = {}
    local function saveItem()
        local text = itemID:GetText() or ""
        local id = tonumber(text:match("^%s*(%d+)%s*$") or text:match("|Hitem:(%d+):"))
        if not id or id <= 0 or id > 2147483647 then reminderStatus:SetText("Enter a valid item ID or link."); return end
        if saveSeconds(seconds, ns.GetSettings().refreshThresholds, id, reminderStatus) then
            itemID:ClearFocus()
            seconds:ClearFocus()
            apply()
            refreshers.Reminders()
        end
    end
    button(reminders, "Save", 70, saveItem):SetPoint("LEFT", seconds, "RIGHT", 68, 0)
    seconds:SetScript("OnEnterPressed", saveItem)
    refreshers.Reminders = function()
        local db = ns.GetSettings()
        needsRefresh:SetChecked(db.onlyNeedsRefresh)
        if not needsSeconds:HasFocus() then needsSeconds:SetText(db.needsRefreshSeconds) end
        if not defaultSeconds:HasFocus() then defaultSeconds:SetText(db.refreshDefault) end
        if not bagSeconds:HasFocus() then bagSeconds:SetText(db.refreshThresholds[ns.Model.SleepingBag] or "") end
        local ids = {}
        for id in pairs(db.refreshThresholds) do
            if type(id) == "number" and id > 0 and id ~= ns.Model.SleepingBag then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for index, id in ipairs(ids) do
            local row = reminderRows[index]
            if not row then
                row = CreateFrame("Frame", nil, reminderContent)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
                row:SetPoint("RIGHT")
                row:SetHeight(30)
                row.name = label(row, 12, "LEFT", 0, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -105, 0)
                row.name:SetWordWrap(false)
                row.name:SetJustifyH("LEFT")
                local reset = button(row, "Use default", 95, function()
                    ns.GetSettings().refreshThresholds[row.itemID] = nil
                    apply()
                    refreshers.Reminders()
                end)
                reset:SetPoint("RIGHT")
                reminderRows[index] = row
            end
            row.itemID = id
            row.name:SetText(("%s (#%d): %ds"):format(C_Item.GetItemInfo(id) or "Item", id,
                ns.Model.RefreshSeconds(db.refreshThresholds[id])))
            row:Show()
        end
        for index = #ids + 1, #reminderRows do reminderRows[index]:Hide() end
        reminderContent:SetHeight(math.max(1, #ids * 30))
    end
    return function()
        for name, frame in pairs(panels) do
            if frame:IsVisible() then refreshers[name]() end
        end
    end, categories
end
