'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon: runLua } = require('./helpers/lua');
function runAddon(options) {
    const luaRunner = process.env.AZIMUTH_LUA_RUNNER
        ? [process.execPath, process.env.AZIMUTH_LUA_RUNNER] : undefined;
    return runLua({ ...options, luaRunner });
}

function model(script) {
    return runAddon({ script: `
        local ns = {}
        assert(loadfile("addon/AzimuthConsumables/Model.lua"))("AzimuthConsumables", ns)
        assert(loadfile("addon/AzimuthConsumables/Weapons.lua"))("AzimuthConsumables", ns)
        local M = ns.Model
        local db = { hidden = {}, mappings = {} }
        ${script}
    ` }).emitted;
}

test('consumables: aggregates stacks, excludes quest items and reagents, and honors hidden items', () => {
    const [items] = model(`
        db.hidden[3] = true
        emit(M.Items({
            { id = 1, count = 5, classID = 0, spellID = 100 },
            { id = 1, count = 2, classID = 0, spellID = 100 },
            { id = 2, count = 10, classID = 7 },
            { id = 3, count = 1, classID = 0, spellID = 300 },
            { id = 4, count = 1, classID = 12, spellID = 400 },
            { id = 5, count = 0, classID = 0, spellID = 500 },
        }, db))
    `);
    assert.equal(items.length, 1);
    assert.equal(items[0].count, 7);
    assert.equal(items[0].id, 1);
});

test('consumables: effect countdown follows aura expiration, not item cooldown', () => {
    const [active, expired] = model(`
        local item = { id = 1, spellID = 100, cooldownEnd = 999 }
        local auras = { { spellID = 100, expires = 160 } }
        emit(M.State(item, auras, db, 100, true))
        emit(M.State(item, auras, db, 161, true))
    `);
    assert.equal(active.text, '1:00');
    assert.equal(active.glow, false);
    assert.equal(expired.active, undefined);
    assert.equal(expired.glow, true);
    assert.match(expired.text, /^CD /);
});

test('consumables: localized names and explicit multi-effect mappings handle different cast and buff IDs', () => {
    const [named, mapped, castOnly] = model(`
        local item = { id = 1, spellID = 100, spellName = "Localized Elixir" }
        emit(M.State(item, { { spellID = 200, name = "Localized Elixir", expires = 300 } }, db, 100, true))
        db.mappings[1] = { 201, 202 }
        emit(M.State(item, { { spellID = 202, expires = 400 } }, db, 100, true))
        emit(M.State(item, { { spellID = 100, expires = 400 } }, db, 100, true))
    `);
    assert.equal(named.active, true);
    assert.equal(mapped.text, '5:00');
    assert.equal(castOnly.glow, true);
});

test('consumables: unreadable auras suppress false missing-buff glow; permanent buffs have no fabricated timer', () => {
    const [unknown, permanent, ready] = model(`
        local item = { id = 1, spellID = 100 }
        emit(M.State(item, {}, db, 100, false))
        emit(M.State(item, { { spellID = 100, expires = 0 } }, db, 100, true))
        emit(M.State(item, {}, db, 100, true))
    `);
    assert.equal(unknown.text, '?');
    assert.equal(unknown.glow, false);
    assert.equal(permanent.text, 'ACTIVE');
    assert.equal(permanent.glow, false);
    assert.equal(ready.text, 'READY');
    assert.equal(ready.glow, true);
});

test('consumables: duration labels are rounded up and never negative', () => {
    const [result] = model('emit({ M.Time(3601), M.Time(61), M.Time(0.2), M.Time(-3) })');
    assert.deepEqual(result, ['1h 0m', '1:01', '1s', '0s']);
});

// Exercise the real UI and event handlers against the project's fake client.
function integration(script, before = '') {
    return runAddon({ script: `
        local slots = { { itemID = 1, stackCount = 2 }, { itemID = 1, stackCount = 3 } }
        local buffs, weaponData = {}, {}
        C_Container = {
            GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end,
            GetContainerItemInfo = function(_, slot) return slots[slot] end,
            GetItemCooldown = function() return 0, 0, 1 end,
        }
        C_Item = {
            GetItemInfoInstant = function(id) return id, "Consumable", "Elixir", "", 123, 0, 2 end,
            GetItemInfo = function() return "Example Elixir" end,
            GetItemSpell = function() return "Elixir Effect", 100 end,
            IsUsableItem = function() return true end,
            GetWeaponEnchantInfo = function(slot) return weaponData[slot] or {} end,
            GetItemCount = function(id)
                local count = 0
                for _, slot in ipairs(slots) do if slot.itemID == id then count = count + slot.stackCount end end
                return count
            end,
        }
        C_UnitAuras = { GetAuraDataByIndex = function(_, i) return buffs[i] end }
        ${before}
        local ns = {}
        assert(loadfile("addon/AzimuthConsumables/Model.lua"))("AzimuthConsumables", ns)
        assert(loadfile("addon/AzimuthConsumables/Weapons.lua"))("AzimuthConsumables", ns)
        assert(loadfile("addon/AzimuthConsumables/Options.lua"))("AzimuthConsumables", ns)
        assert(loadfile("addon/AzimuthConsumables/Core.lua"))("AzimuthConsumables", ns)
        stub.fire("PLAYER_LOGIN")
        ${script}
    ` }).emitted;
}

test('consumables UI: settings apply scale, lock, title visibility, colors and blacklist entries', () => {
    const [category, saved, hidden, shown, title] = integration(`
        SlashCmdList.AZIMUTHCONSUMABLES("")
        emit(stub.openedCategory)
        local panel = AzimuthConsumablesOptions
        local input, hideTitle
        for _, control in ipairs(panel.children) do
            if control:GetObjectType() == "EditBox" then input = control end
            if control:GetObjectType() == "CheckButton" then
                local name = control.regions[1]:GetText()
                if name == "Lock bar position" then
                    control:SetChecked(true)
                    control:Click()
                elseif name == "Hide bar title" then
                    hideTitle = control
                end
            end
            if control:GetText() == "+" then control:Click() end
            if control:GetText() == "Missing-effect glow" then control:Click() end
        end
        ColorPickerFrame.GetColorRGB = function() return 0.1, 0.2, 0.3 end
        ColorPickerFrame.info.swatchFunc()
        emit({ AzimuthConsumablesDB.scale, AzimuthConsumablesBar:GetScale(),
            AzimuthConsumablesDB.locked, AzimuthConsumablesDB.glowColor })
        input:SetText("|Hitem:1:0|h[Example Elixir]|h")
        stub.RunScript(input, "OnEnterPressed")
        emit({ AzimuthConsumablesDB.hidden[1], ns.Buttons[1]:IsShown() })
        for _, frame in ipairs(stub.frames) do
            if frame:GetText() == "Remove" then frame:Click(); break end
        end
        emit({ AzimuthConsumablesDB.hidden[1] == nil, ns.Buttons[1]:IsShown() })
        local bar = AzimuthConsumablesBar
        local originallyShown = bar.title:IsShown()
        hideTitle:SetChecked(true)
        hideTitle:Click()
        local hiddenTitle = AzimuthConsumablesDB.hideTitle and not bar.title:IsShown()
        stub.openedCategory = nil
        bar.title:GetParent():Click("RightButton")
        hideTitle:SetChecked(false)
        hideTitle:Click()
        emit({ originallyShown, hiddenTitle, stub.openedCategory, bar.title:IsShown() })
    `);
    assert.equal(category, 'Azimuth Consumables');
    assert.deepEqual(saved, [1.05, 1.05, true, [0.1, 0.2, 0.3]]);
    assert.deepEqual(hidden, [true, false]);
    assert.deepEqual(shown, [true, true]);
    assert.deepEqual(title, [true, true, 'Azimuth Consumables', true]);
});

test('consumables UI: filters plain food while retaining buff food, uncertain food and manual mappings', () => {
    const [filtered, all, mapped, blacklisted] = integration(`
        local function shownIDs()
            local ids = {}
            for _, b in ipairs(ns.Buttons) do
                if b:IsShown() then ids[#ids + 1] = b.item.id end
            end
            emit(ids)
        end
        shownIDs()
        AzimuthConsumablesDB.excludeRecoveryFood = false
        ns.Refresh()
        shownIDs()
        AzimuthConsumablesDB.excludeRecoveryFood = true
        SlashCmdList.AZIMUTHCONSUMABLES("map 1 100")
        shownIDs()
        AzimuthConsumablesDB.hidden[1] = true
        ns.Refresh()
        shownIDs()
    `, `
        slots = {
            { itemID = 1, stackCount = 1 }, { itemID = 2, stackCount = 1 },
            { itemID = 3, stackCount = 1 }, { itemID = 4, stackCount = 1 },
        }
        C_Item.GetItemInfoInstant = function(id)
            return id, "Consumable", "Food & Drink", "", 123, 0, id == 4 and 1 or 5
        end
        local plain = "|cffffffffUse:|r Restores 1,392 health over 30 sec. Must remain seated while eating."
        C_TooltipInfo = { GetItemByID = function(id)
            if id == 3 then return nil end
            local lines = { { leftText = plain } }
            if id == 2 then lines[2] = { leftText = "If you spend at least 10 seconds eating you will become Well Fed." } end
            return { lines = lines }
        end }
    `);
    assert.deepEqual(filtered, [4, 2, 3]);
    assert.deepEqual(all, [4, 1, 2, 3]);
    assert.deepEqual(mapped, [4, 1, 2, 3]);
    assert.deepEqual(blacklisted, [4, 2, 3]);
});

test('consumables UI: uses Expressway for bar and picker text and falls back when unavailable', () => {
    const fonts = String.raw`
        local b = ns.Buttons[1]
        stub.RunScript(b, "PostClick", "RightButton", false)
        local picker = AzimuthConsumablesBuffPicker
        local row = picker.rows[1]:GetFontString()
        emit({ { b.count:GetFont() }, { b.time:GetFont() },
            { picker.title:GetFont() }, { row:GetFont() } })
    `;
    const shared = 'SharedExpressway.ttf';
    const ellesmere = String.raw`Interface\AddOns\EllesmereUI\media\fonts\Expressway.TTF`;
    const standard = String.raw`Fonts\FRIZQT__.TTF`;
    const [registered] = integration(fonts, `
        LibStub = function(name, silent)
            assert(name == "LibSharedMedia-3.0" and silent)
            return { Fetch = function(_, kind, face, noDefault)
                assert(kind == "font" and face == "Expressway" and noDefault)
                return "${shared}"
            end }
        end
    `);
    const [installed] = integration(fonts);
    const [fallback] = integration(fonts, `
        local methods = stub.Methods
        local setFont = methods.SetFont
        methods.SetFont = function(self, path, size, flags)
            if path ~= STANDARD_TEXT_FONT then error("Font unavailable") end
            return setFont(self, path, size, flags)
        end
    `);
    for (const [actual, expected] of [[registered, shared], [installed, ellesmere], [fallback, standard]]) {
        assert.deepEqual(actual, [
            [expected, 11, 'OUTLINE'], [expected, 10, 'OUTLINE'],
            [expected, 12, 'OUTLINE'], [expected, 12, ''],
        ]);
    }
});

test('consumables UI: secure item clicks, combined count, aura gained/expired, and last-copy timer', () => {
    const [initial, active, empty, expired] = integration(`
        local b = ns.Buttons[1]
        emit({ #ns.Buttons, b:GetAttribute("type1"), b:GetAttribute("item1"), b.count:GetText(), b.time:GetText() })
        buffs = { { spellId = 100, name = "Elixir Effect", duration = 60, expirationTime = 60 } }
        stub.fire("UNIT_AURA", "player")
        emit({ b.time:GetText(), b.glow:GetAlpha() })
        slots = {}
        ns.Refresh()
        emit({ b:IsShown(), b.count:GetText(), b.time:GetText() })
        buffs = {}
        stub.fire("UNIT_AURA", "player")
        stub.runTimers()
        emit(b:IsShown())
    `);
    assert.deepEqual(initial, [1, 'item', 'item:1', '5', 'READY']);
    assert.deepEqual(active, ['1:00', 0]);
    assert.deepEqual(empty, [true, '0', '1:00']);
    assert.equal(expired, false);
});

test('consumables UI: bar fits tracked items, wraps, and shrinks after the last effect expires', () => {
    const [titled, compact, wrapped, combat, active, empty] = integration(`
        local bar = AzimuthConsumablesBar
        emit({ bar:GetWidth() >= bar.title:GetStringWidth() + 16, bar:GetHeight() })
        AzimuthConsumablesDB.hideTitle = true
        ns.Refresh()
        emit({ bar:GetWidth(), bar:GetHeight() })
        for id = 2, 9 do slots[#slots + 1] = { itemID = id, stackCount = 1 } end
        ns.Refresh()
        emit({ bar:GetWidth(), bar:GetHeight() })
        stub.inCombat = true
        slots = { { itemID = 1, stackCount = 1 } }
        ns.Refresh()
        emit({ bar:GetWidth(), bar:GetHeight() })
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        stub.runTimers()
        buffs = { { spellId = 100, name = "Elixir Effect", duration = 60, expirationTime = 60 } }
        stub.fire("UNIT_AURA", "player")
        slots = {}
        ns.Refresh()
        emit({ bar:GetWidth(), bar:GetHeight(), ns.Buttons[1].count:GetText() })
        buffs = {}
        stub.fire("UNIT_AURA", "player")
        stub.runTimers()
        emit({ bar:GetWidth() == math.ceil(bar.empty:GetStringWidth()) + 14, bar:GetHeight(), bar.empty:IsShown() })
    `);
    assert.deepEqual(titled, [true, 74]);
    assert.deepEqual(compact, [54, 62]);
    assert.deepEqual(wrapped, [383, 109]);
    assert.deepEqual(combat, wrapped);
    assert.deepEqual(active, [54, 62, '0']);
    assert.deepEqual(empty, [true, 36, true]);
});

test('consumables UI: picker survives bag refreshes and item-cache events until a selection is made', () => {
    const [open, refreshed, mapped] = integration(`
        local b = ns.Buttons[1]
        buffs = { { spellId = 200, name = "Example Buff", expirationTime = 600, duration = 600 } }
        stub.RunScript(b, "PostClick", "RightButton", false)
        local picker = AzimuthConsumablesBuffPicker
        emit(picker:IsShown())
        -- A layout change while the menu is open must not dismiss its rows.
        slots[#slots + 1] = { itemID = 2, stackCount = 1 }
        stub.fire("BAG_UPDATE_DELAYED")
        stub.fire("GET_ITEM_INFO_RECEIVED", 999, true)
        stub.runTimers()
        emit({ picker:IsShown(), picker.itemID, picker.rows[2].choice.spellID })
        local row = picker.rows[2]
        row.scripts.OnClick(row)
        emit({ picker:IsShown(), AzimuthConsumablesDB.mappings[1][1] })
    `);
    assert.equal(open, true);
    assert.deepEqual(refreshed, [true, 1, 200]);
    assert.deepEqual(mapped, [false, 200]);
});

test('consumables UI: right-click links a weapon enchant already active before login', () => {
    const [chosen, active] = integration(`
        local b = ns.Buttons[1]
        stub.RunScript(b, "PostClick", "RightButton", false)
        local row = AzimuthConsumablesBuffPicker.rows[2]
        emit({ row.choice.weapon, row.choice.hand, row.choice.enchantID })
        row.scripts.OnClick(row)
        emit({ b.time:GetText(), b.glow:GetAlpha(), AzimuthConsumablesDB.mappings[1].enchantID })
    `, `
        weaponData[0] = { { hasEnchant = true, enchantType = 2, enchantID = 1643, timeLeft = 1800000 } }
    `);
    assert.deepEqual(chosen, [true, 'main', 1643]);
    assert.deepEqual(active, ['30:00', 0, 1643]);
});

test('consumables: Forever weapon API converts milliseconds and excludes permanent enchants', () => {
    const [snapshot] = model(`
        C_Item = { GetWeaponEnchantInfo = function(slot)
            if slot == 0 then return {
                { hasEnchant = true, enchantType = 1, enchantID = 999, timeLeft = 0 },
                { hasEnchant = true, enchantType = 2, enchantID = 13, timeLeft = 60000 },
            } end
            return { { hasEnchant = true, enchantType = 2, enchantID = 14, timeLeft = 120000 } }
        end }
        emit(ns.Weapons.Read(100))
    `);
    assert.equal(snapshot.readable, true);
    assert.equal(snapshot.effects.length, 2);
    assert.deepEqual(snapshot.effects.map(e => [e.hand, e.enchantID, e.expires]), [
        ['main', 13, 160], ['off', 14, 220],
    ]);
});

test('consumables: exact weapon IDs and hands prevent other stones/imbues suppressing the reminder', () => {
    const [wrong, right, unknown, removed] = model(`
        db.mappings[1] = { weapon = true, hand = "main", enchantID = 13 }
        local item = { id = 1 }
        local weapons = { readable = true, effects = {
            { hand = "main", enchantID = 999, expires = 200 },
            { hand = "off", enchantID = 13, expires = 200 },
        } }
        emit(M.State(item, {}, db, 100, true, weapons))
        weapons.effects[1].enchantID = 13
        emit(M.State(item, {}, db, 100, false, weapons))
        emit(M.State(item, {}, db, 100, true, { readable = false, effects = {} }))
        emit(M.State(item, {}, db, 100, false, { readable = true, effects = {} }))
    `);
    assert.equal(wrong.glow, true);
    assert.equal(right.text, '1:40');
    assert.equal(right.glow, false);
    assert.equal(unknown.text, '?');
    assert.equal(unknown.glow, false);
    assert.equal(removed.glow, true);
});

test('consumables: weapon learning rejects failed uses and ambiguous weapon changes', () => {
    const [failed, ambiguous, learned, id] = model(`
        local before = { readable = true, effects = {} }
        local after = { readable = true, effects = { { hand = "main", enchantID = 13, expires = 1900 } } }
        emit(ns.Weapons.Learn(before, after, 5, 5, db, 1))
        after.effects[2] = { hand = "off", enchantID = 14, expires = 1900 }
        emit(ns.Weapons.Learn(before, after, 5, 4, db, 1))
        after.effects[2] = nil
        emit(ns.Weapons.Learn(before, after, 5, 4, db, 1))
        emit(db.weaponEnchants[1][13])
    `);
    assert.equal(failed, false);
    assert.equal(ambiguous, false);
    assert.equal(learned, true);
    assert.equal(id, true);
});

test('consumables UI: weapon oil opens the equipment tab on release outside combat', () => {
    const [calls] = integration(`
        local calls = {}
        ToggleCharacter = function(tab, onlyShow) calls[#calls + 1] = { tab, onlyShow } end
        local oil = ns.Buttons[1]
        stub.RunScript(oil, "PostClick", "LeftButton", true)
        stub.RunScript(oil, "PostClick", "LeftButton", false)
        stub.RunScript(oil, "PostClick", "LeftButton", false)
        stub.inCombat = true
        stub.RunScript(oil, "PostClick", "LeftButton", false)
        stub.inCombat = false
        slots = { { itemID = 2, stackCount = 1 } }
        ns.Refresh()
        stub.RunScript(ns.Buttons[1], "PostClick", "LeftButton", false)
        emit(calls)
    `, `
        C_Item.GetItemInfo = function(id) return id == 1 and "Wizard Oil" or "Example Elixir" end
    `);
    assert.deepEqual(calls, [['PaperDollFrame', true], ['PaperDollFrame', true]]);
});

test('consumables UI: using a sharpening stone learns its enchant and tracks last-copy expiry', () => {
    const [learned, expired] = integration(`
        local b = ns.Buttons[1]
        stub.RunScript(b, "PreClick", "LeftButton", false)
        slots = {}
        weaponData[0] = { { hasEnchant = true, enchantType = 2, enchantID = 13, timeLeft = 1800000 } }
        stub.fire("UNIT_INVENTORY_CHANGED", "player")
        stub.runTimers()
        emit({ AzimuthConsumablesDB.weaponEnchants[1][13], b.time:GetText(), b.count:GetText(), b.glow:GetAlpha() })
        weaponData[0] = {}
        stub.fire("UNIT_INVENTORY_CHANGED", "player")
        stub.runTimers()
        emit(b:IsShown())
    `, `
        C_Item.GetItemInfo = function() return "Rough Sharpening Stone" end
        C_Item.GetItemInfoInstant = function(id) return id, "Consumable", "Item Enhancement", "", 123, 0, 6 end
    `);
    assert.deepEqual(learned, [true, '30:00', '0', 0]);
    assert.equal(expired, false);
});

test('consumables UI: no recursive timer refresh when the last effect expires during combat', () => {
    const [locked, finished] = integration(`
        local b = ns.Buttons[1]
        buffs = { { spellId = 100, name = "Elixir Effect", expirationTime = 60 } }
        stub.fire("UNIT_AURA", "player")
        slots = {}
        ns.Refresh()
        stub.inCombat = true
        buffs = {}
        stub.fire("UNIT_AURA", "player")
        local after = C_Timer.After
        local queued = 0
        C_Timer.After = function(delay, fn)
            queued = queued + 1
            assert(queued < 20, "recursive refresh loop")
            return after(delay, fn)
        end
        stub.advance(0.4)
        emit({ b:IsShown(), queued })
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        stub.runTimers()
        emit(b:IsShown())
    `);
    assert.deepEqual(locked, [true, 0]);
    assert.equal(finished, false);
});

test('consumables UI: unchanged bag layout does not rewrite protected click attributes', () => {
    const [writes] = integration(`
        local b = ns.Buttons[1]
        local original, writes = b.SetAttribute, 0
        b.SetAttribute = function(self, ...) writes = writes + 1; return original(self, ...) end
        for i = 1, 5 do
            stub.fire("BAG_UPDATE_DELAYED")
            stub.fire("GET_ITEM_INFO_RECEIVED", 1, true)
            stub.runTimers()
        end
        emit(writes)
    `);
    assert.equal(writes, 0);
});

test('consumables UI: combat keeps click attributes stable until leaving combat', () => {
    const [locked, unlocked] = integration(`
        local b = ns.Buttons[1]
        stub.inCombat = true
        slots = { { itemID = 2, stackCount = 1 } }
        ns.Refresh()
        emit(b:GetAttribute("item1"))
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        stub.runTimers()
        emit(b:GetAttribute("item1"))
    `);
    assert.equal(locked, 'item:1');
    assert.equal(unlocked, 'item:2');
});
