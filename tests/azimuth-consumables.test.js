'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

function model(script) {
    return runAddon({ script: `
        local ns = {}
        assert(loadfile("addon/AzimuthConsumables/Model.lua"))("AzimuthConsumables", ns)
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
function integration(script) {
    return runAddon({ script: `
        local slots = { { itemID = 1, stackCount = 2 }, { itemID = 1, stackCount = 3 } }
        local buffs = {}
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
        }
        C_UnitAuras = { GetAuraDataByIndex = function(_, i) return buffs[i] end }
        local ns = {}
        assert(loadfile("addon/AzimuthConsumables/Model.lua"))("AzimuthConsumables", ns)
        assert(loadfile("addon/AzimuthConsumables/Core.lua"))("AzimuthConsumables", ns)
        stub.fire("PLAYER_LOGIN")
        ${script}
    ` }).emitted;
}

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
