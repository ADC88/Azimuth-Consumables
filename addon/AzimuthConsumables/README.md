# Azimuth Consumables

A standalone consumable bar for **World of Warcraft: Forever** (Interface 16001). It does not require Polestar or Test Addon.

## Install

Extract `AzimuthConsumables.zip` directly into your game's `Interface/AddOns` directory. The result must be `Interface/AddOns/AzimuthConsumables/AzimuthConsumables.toc`. Restart the game completely and enable **Azimuth Consumables**.

## Use

- Left-click an icon to use that consumable. Duplicate bag stacks share one icon and combined count.
- A pulsing gold outline means the tracked effect is missing. A green countdown shows how long the active effect has left.
- `CD` means the item's reuse cooldown. The swipe also shows reuse cooldown; it is separate from the active-effect timer.
- An active effect without a readable expiration is labeled `ACTIVE`. `?` means the client restricts aura information; it does not trigger a false missing-buff glow.
- Drag the header to move the bar. `/azc lock` locks it; `/azc unlock` unlocks it.
- Right-click an icon to link it to one of your **currently active buffs**. Use this after consuming a food or custom item whose buff differs from its cast spell. Choose **Automatic matching (reset)** to remove that override.
- Shift-right-click hides an item. `/azc restore` restores hidden items.
- `/azc scale 1.2` changes size. `/azc hide`, `/azc show`, and `/azc reset` control the bar.

Bag additions, removals, position changes and secure click attributes are applied out of combat. Existing buttons remain clickable during combat and their visual timers continue updating where the client permits. After the last copy is consumed, its dimmed icon and zero count remain while its tracked buff is active.

## Effect matching

Items must be in the consumable item class and have a use spell, or be explicitly mapped. Quest items, reagents, equipment and passive consumables are excluded. Instant healing/mana consumables have no persistent buff to count down: they display READY or their cooldown and glow while no matching effect is present.

Automatic matching uses the item's spell ID or localized spell name against your helpful player auras. Some food and custom Forever items apply a different spell. Right-click to link the correct active buff, or use:

```
/azc buffs
/azc map ITEM_ID BUFF_SPELL_ID
/azc map ITEM_ID BUFF_SPELL_ID ANOTHER_BUFF_SPELL_ID
/azc map ITEM_ID auto
```

Multiple IDs mean alternative effects; the longest matching remaining effect is shown. Buff mappings and hidden items are account-wide; position is per character. Weapon oils/poisons that apply a temporary weapon enchant rather than a player aura do not yet have active-effect detection; hide those icons if you do not want reminders for them.

## Validation

This first build has passed Lua 5.1 syntax validation. The seven model/UI
regression tests are included but were not run successfully here: Lua 5.1 is
not installed, and the portable validation runtime could not start in this
Windows environment (Illegal System DLL Relocation). It has not yet been
tested in the game client.

Forever API declarations used: `Gethe/wow-ui-source`, branch `forever`, `ItemDocumentation.lua`, `ContainerDocumentation.lua`, and `UnitAuraDocumentation.lua`. Secure item buttons follow the existing project's `QoL/Buttons.lua` pattern.

Run the Lua 5.1-backed model and simulated-client tests with `node --test tests/azimuth-consumables.test.js` from the repository root. The test runner requires Lua 5.1 or LuaJIT on PATH, or an explicit `LUA` executable path.

In-game checks: use an elixir and watch the timer; cancel its buff and check the glow; split/merge stacks; consume the last item; loot another consumable during combat and verify the layout updates after combat; link a food's Well Fed buff; reload and confirm saved position/mappings.

## License

GPL-3.0-only, consistent with the Azimuth repository. See the included LICENSE file.
