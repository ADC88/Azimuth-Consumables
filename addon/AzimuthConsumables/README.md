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
- Right-click an icon to link it to one of your **currently active buffs or weapon enchants**. The picker stays open through bag and item-cache refreshes; it closes when you select an effect, press Escape, use its close button or enter combat. Choose **Automatic matching (reset)** to remove a manual override.
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
/azc map ITEM_ID main
/azc map ITEM_ID off
/azc map ITEM_ID either
```

Multiple IDs mean alternative effects; the longest matching remaining effect is shown. Buff mappings and hidden items are account-wide; position is per character.

## Sharpening stones and weapon enchants

Left-click a stone or weapon oil outside combat to use it and open the Character equipment tab. Click the weapon slot you want to coat. Repeated clicks keep the tab open.

Weapon enchant timers use Forever's `C_Item.GetWeaponEnchantInfo`, with a legacy global API fallback. Both hands are read; temporary enchants and imbues are distinguished by their exact enchant ID, and permanent enchants are excluded. Weapon enchant IDs are different from buff spell IDs.

- **Already applied a stone?** Right-click its consumable icon and choose **Main hand: weapon enchant ...** or **Off hand: weapon enchant ...**. This links that exact enchant and hand, and starts its real remaining-time countdown. Weapon oils and poisons can be linked this way too.
- **Apply the next stone through the bar:** recognized sharpening stones, weightstones and Item Enhancement consumables learn their enchant when the item's bag count falls and exactly one enchant changes or refreshes within 45 seconds. Cancelled uses and ambiguous changes do not create a link. This also supports custom Forever enchant IDs.
- Automatic learned matches can follow the same enchant on either hand. For a specific hand, use the picker or `/azc map ITEM_ID main` / `off` while that enchant is active. `either` links the exact currently active enchant to either hand.
- Links use exact enchant IDs: another sharpening-stone rank, a different oil, an unrelated buff, or a permanent weapon enchant does not incorrectly satisfy the reminder. Link each consumable you use once if it was applied before the addon could learn it.
- To clear manual and learned matching for an item completely, use `/azc map ITEM_ID auto`.

Weapon snapshots are refreshed while the bar is visible and on equipment/inventory events, so weapon swaps, replacements and expired coatings update the display. Restricted enchant data shows `?`, rather than a misleading missing-effect glow.

## Changes in 0.2.0

- Fixed the buff picker being dismissed by every bag or item-data refresh.
- Added exact-ID weapon enchant tracking and safe stone learning.
- Cached item metadata and avoided rewriting secure button attributes for unchanged layouts.
- Ignored unrelated item-cache notifications and coalesced bag updates.
- Fixed recursive zero-delay refreshes when the last consumable's effect expired in combat.
- Validated saved settings and positions before loading them.

## Validation

Version 0.2.0 passed Lua 5.1 syntax validation and 15 model/UI regression tests
using the project's simulated client under Fengari (a JavaScript-hosted Lua
5.3 VM, with the stub's `unpack` alias provided). Native Lua 5.1 execution is
still blocked in this Windows environment. These checks verify behavior in
the simulation, not the live client's protected-action enforcement. Live
WoW Forever testing remains necessary.

Forever API declarations used: `Gethe/wow-ui-source`, branch `forever`, `ItemDocumentation.lua`, `ItemConstantsDocumentation.lua`, `ContainerDocumentation.lua`, and `UnitAuraDocumentation.lua`. Weapon time units and enumeration were checked against `Blizzard_BuffFrame/BuffFrame.lua`. Secure item buttons follow the existing project's `QoL/Buttons.lua` pattern.

Run the Lua 5.1-backed model and simulated-client tests with `node --test tests/azimuth-consumables.test.js` from the repository root. The test runner requires Lua 5.1 or LuaJIT on PATH, or an explicit `LUA` executable path.

In-game checks: use an elixir and watch the timer; cancel its buff and check the glow; split/merge stacks; consume the last item; loot another consumable during combat and verify the layout updates after combat; link a food's Well Fed buff; reload and confirm saved position/mappings.

## License

GPL-3.0-only, consistent with the Azimuth repository. See the included LICENSE file.
