local _, ns = ...
local unpack = unpack or table.unpack

local function button(parent, text, width, onClick)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetText(text)
    control:SetScript("OnClick", onClick)
    return control
end

function ns.RegisterOptions(db, apply, label)
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame", "AzimuthConsumablesOptions")
    label(panel, 20, "TOPLEFT", 16, -16):SetText("Azimuth Consumables")

    local function checkbox(text, key, y)
        local control = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        control:SetPoint("TOPLEFT", 14, y)
        label(control, 12, "LEFT", 32, 0):SetText(text)
        control:SetScript("OnClick", function(self)
            db[key] = self:GetChecked()
            apply()
        end)
        return control
    end

    local locked = checkbox("Lock bar position", "locked", -49)
    local exclude = checkbox("Hide food and drink that only restore health or mana", "excludeRecoveryFood", -85)

    local size = label(panel, 12, "TOPLEFT", 16, -128)
    local function resize(delta)
        db.scale = ns.Model.Scale(math.floor((db.scale + delta) * 100 + 0.5) / 100)
        size:SetText(("Bar size: %d%%"):format(math.floor(db.scale * 100 + 0.5)))
        apply()
    end
    button(panel, "-", 28, function() resize(-0.05) end):SetPoint("TOPLEFT", 132, -122)
    button(panel, "+", 28, function() resize(0.05) end):SetPoint("TOPLEFT", 164, -122)

    local function colorControl(text, key, x)
        local control = button(panel, text, 138, function()
            local original = db[key]
            local function update(color)
                db[key] = color
                apply()
                ns.RefreshOptions()
            end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = original[1], g = original[2], b = original[3],
                swatchFunc = function() update({ ColorPickerFrame:GetColorRGB() }) end,
                cancelFunc = function() update(original) end,
            })
        end)
        control:SetPoint("TOPLEFT", x, -159)
        local swatch = panel:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", control, "RIGHT", 5, 0)
        return swatch
    end
    local background = colorControl("Bar background", "backgroundColor", 16)
    local glow = colorControl("Missing-effect glow", "glowColor", 202)

    label(panel, 15, "TOPLEFT", 16, -206):SetText("Blacklist")
    label(panel, 11, "TOPLEFT", 16, -231):SetText("Enter an item ID or link. Shift-right-click a bar icon to hide it.")
    local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 22, -253)
    input:SetSize(200, 24)
    input:SetAutoFocus(false)
    local status = label(panel, 11, "TOPLEFT", 16, -288)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -314)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local empty = label(content, 11, "TOPLEFT", 0, 0)
    empty:SetText("Blacklist is empty.")
    local rows = {}

    local function refresh()
        locked:SetChecked(db.locked)
        exclude:SetChecked(db.excludeRecoveryFood)
        size:SetText(("Bar size: %d%%"):format(math.floor(db.scale * 100 + 0.5)))
        background:SetColorTexture(unpack(db.backgroundColor))
        glow:SetColorTexture(unpack(db.glowColor))
        local ids = {}
        for id, hidden in pairs(db.hidden) do
            if hidden and type(id) == "number" then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for index, id in ipairs(ids) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 27)
                row:SetPoint("RIGHT")
                row:SetHeight(27)
                local remove = button(row, "Remove", 76, function()
                    db.hidden[row.itemID] = nil
                    status:SetText("")
                    apply()
                    refresh()
                end)
                remove:SetPoint("RIGHT")
                row.name = label(row, 12, "LEFT", 0, 0)
                row.name:SetPoint("RIGHT", remove, "LEFT", -8, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWordWrap(false)
                rows[index] = row
            end
            row.itemID = id
            local name = C_Item.GetItemInfo(id)
            row.name:SetText(name and ("%s (#%d)"):format(name, id) or ("Item #%d"):format(id))
            row:Show()
        end
        for index = #ids + 1, #rows do rows[index]:Hide() end
        content:SetHeight(math.max(20, #ids * 27))
        empty:SetShown(#ids == 0)
    end
    local function add()
        local text = input:GetText() or ""
        local id = tonumber(text:match("^%s*(%d+)%s*$") or text:match("|Hitem:(%d+):"))
        if not id or id < 1 or id > 2147483647 then
            status:SetText("Enter a valid item ID or item link.")
            return
        end
        db.hidden[id] = true
        input:SetText("")
        input:ClearFocus()
        status:SetText("")
        apply()
        refresh()
    end
    input:SetScript("OnEnterPressed", add)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    button(panel, "Add to blacklist", 126, add):SetPoint("LEFT", input, "RIGHT", 8, 0)
    panel:SetScript("OnShow", function()
        status:SetText("")
        refresh()
    end)
    ns.RefreshOptions = function()
        if panel:IsVisible() then refresh() end
    end
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Azimuth Consumables")
    Settings.RegisterAddOnCategory(category)
    ns.OpenOptions = function() Settings.OpenToCategory(category:GetID()) end
end
