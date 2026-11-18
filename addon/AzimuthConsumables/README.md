# Azimuth Consumables

A standalone consumable bar for **World of Warcraft: Forever** (Interface 16001). It does not require Polestar or Test Addon.

## Install

Extract `AzimuthConsumables.zip` directly into your game's `Interface/AddOns` directory. The result must be `Interface/AddOns/AzimuthConsumables/AzimuthConsumables.toc`. Restart the game completely and enable **Azimuth Consumables**.

## Use

The bar and effect picker use Expressway Regular when it is registered through LibSharedMedia or available from EllesmereUI. WoW's default fonts are used if Expressway cannot be loaded.

- Type `/azc` or right-click the bar header to open Settings. Adjust bar size, lock its position, hide the title, and choose separate colors for the background and missing-effect glow. The header still accepts clicks and drags when the title is hidden.
- The bar fits its tracked icons and wraps after eight per row. A visible title sets the minimum width. Hiding the title leaves a small drag and settings handle. Layout changes apply after combat.
- Add an item ID or item link to the blacklist, or Shift-right-click an icon. Use **Remove** beside an entry to restore that item. The blacklist follows your active profile.
- **Hide food and drink that only restore health or mana** is enabled by default. It recognizes standard English recovery tooltips and keeps buff food, manually mapped items and items with unclear or localized tooltips visible. Uncheck it to show recovery food.

- Left-click an icon to use that consumable. Duplicate bag stacks share one icon and combined count.
- A pulsing gold outline means the tracked effect is missing. A green countdown shows how long the active effect has left.
- `CD` means the item's reuse cooldown. The swipe also shows reuse cooldown; it is separate from the active-effect timer.
- Carrying a Cozy Sleeping Bag adds its Well-Rested timer to the bar. Left-click to place it when the game allows, then rest in it to refresh the buff. The icon glows when the bag is ready and the buff is missing or has less than five minutes left.
- Ongoing class buffs appear for your class and learned spells. Click a spell icon to cast it on yourself. Rank families use the highest learned rank, including matching ranks found in the current spellbook.
- Warriors track shouts. Priests track Fortitude, Spirit, Shadow Protection, Inner Fire, Fear Ward, Shadowform, Vampiric Embrace and racial maintenance buffs. Mages track Intellect, armor and magic protection. Druids track Mark, Thorns and Omen of Clarity. Hunters track aspects and Trueshot Aura. Warlocks track armor, Soul Link, Unending Breath and Detect Invisibility. Shamans track shields, weapon imbues, Water Walking and Water Breathing. Paladins track blessings, auras, seals and Righteous Fury. Rogue poisons use the existing bag consumable and weapon-enchant tracking.
- Mutually exclusive armors, aspects, shields, blessings, auras, seals and imbues share a slot that follows the active choice. If none is active, the first learned choice in the class list is offered.
- Shaman weapon-imbue matching learns the exact enchant after a successful cast through the bar. Reapply once through the bar to link an existing imbue. If multiple enchants change together, it waits for an unambiguous application.
- **Hide unavailable class buffs** is enabled by default. Turn it off to see unlearned maintenance buffs for your class or tracked buffs applied by other players.
- Enable **Hide class buffs** in Settings to hide the class spell icons. Both visibility settings follow your active profile. Changes to protected buttons apply after combat.

## Buff choices, reminders and profiles

Open `/azc` and choose **Class buffs**, **Reminders** or **Profiles**.

- **Class buffs** lets you enable each buff family individually. Select **Prefer** beside an armor, aspect, aura or other exclusive choice to offer it when the slot has no active buff. An active enabled alternative continues to occupy that slot. Use the seconds box for a buff-specific refresh reminder.
- **Reminders** sets the default refresh threshold and overrides for individual consumable item IDs or links. Values are seconds, from 0 to 3600. Zero means remind when missing; a blank override inherits the default. The sleeping bag keeps its 300-second default unless you override it. Buffs with an unreadable duration suppress early-refresh reminders.
- **Profiles** chooses shared, character or spec settings. Existing settings become the shared profile. New character and spec profiles copy shared settings once, then save buff choices, reminders, colors, size and blacklists independently. Character and spec profiles also save their own position. Shared profiles retain each character's existing position.
- **Copy shared settings into this profile** replaces the current character or spec settings with a fresh copy of shared settings. Profile and layout switches wait until combat ends.

## Layout and status

Open `/azc` and choose **Layout / status**. Set horizontal or vertical wrapping, icons per row or column, icon size, spacing, timer text size and stack count text size. The preview scales down to fit the Settings panel. Layout settings are saved in your active profile and apply to the bar after combat.

The effect countdown keeps showing the remaining buff duration. A separate badge explains attention or availability:

- **EXP** marks a buff within its refresh threshold.
- **MISS** marks a missing tracked effect.
- **CD** marks an item or spell on cooldown.
- **PWR** means the client reports insufficient mana or power.
- **N/A** marks an unavailable action.
- **0** marks an empty stack while an effect remains active.
- **?** marks unreadable effect data.

Timer colors follow these statuses. Active effects use green. Hover an icon for its full status description. Missing and expiring reminders pulse when their actions are ready.

## Diagnostics

Use `/azc debug` to open a report you can copy with Ctrl+A and Ctrl+C. Use `/azc debug ITEM_ID` to focus on a consumable, or a class buff's base spell ID to focus on that family. The report includes the loaded addon version, class, spec, active profile, layout, tracked effects and matches, refresh thresholds, bag selection reasons and class buff controls.
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

Multiple IDs mean alternative effects; the longest matching remaining effect is shown. Buff mappings and hidden items follow your active profile.

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
