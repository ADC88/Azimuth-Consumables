local _, ns = ...
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
    label(reminders, 12, "TOPLEFT", 16, -257):SetText("Consumable item ID or link")
    local itemID, seconds = input(reminders, 190), input(reminders, 70)
    itemID:SetPoint("TOPLEFT", 22, -282)
    seconds:SetPoint("LEFT", itemID, "RIGHT", 18, 0)
    label(reminders, 11, "TOPLEFT", 310, -288):SetText("seconds")
    local reminderContent = scrollContent(reminders, -330)
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
