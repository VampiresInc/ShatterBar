# ShatterBar 0.1.14 acceptance testing

Automated tests validate Lua 5.1 loading, API adapters, scanning decisions, secure
button attributes, binding capture, and client archive contents against mocks.
They cannot establish game-client compatibility, protected-action permission, or
visual correctness. Confirmed results below are limited to the actions tested in game.

| Client | Interface | In-game result |
| --- | --- | --- |
| Retail (priority) | 120105 | PARTIAL PASS: disenchanting; carried-ore prospecting; Warband ore with bank open or Jewelcrafting open |
| Forever (priority) | 16001 | NOT TESTED |
| Classic Era | 11509 | NOT TESTED |
| Mists Classic | 50504 | NOT TESTED |
| Burning Crusade Anniversary | 20506 | NOT TESTED |

For each client, install its ZIP and enable Lua error reporting. Disable Breakables.

1. Log into a character with the relevant profession. Verify only bars for known skills/learned recipes appear.
2. Check the compact icon layout, tooltips, quality of font rendering, counts, and all growth directions.
3. Shift-drag each bar, relog, and verify positions persist. Test reset placement.
4. Test a single eligible item click for each available profession. Verify nothing is equipped or used
   when there is no valid target. Confirm known non-disenchantable equipment and unmet skill requirements are hidden.
   Verify client-specific exclusion data and loaded tooltip checks allow genuinely eligible items.
5. Bind a key in options and in the game's bindings screen. Verify one key press performs exactly one
   operation. Repeat until the stack is exhausted and confirm the next eligible stack/item is selected.
6. Move or replace the target bag slot before pressing the key; verify the current eligible target is used.
   Test rapid repeated presses while casting and while the item is locked.
7. Split ore/herbs into stacks smaller than five. Verify they cannot be targeted despite a sufficient total.
   Make a stack of five and verify it appears. Verify counts after processing.
8. Test ignored items, per-ID restore, restore all, bound/warbound toggles, equipment sets, and tabards.
9. Enter combat with a target prepared. Verify all bindings and clicks stop processing, the hide option
   behaves correctly, and there are no blocked-action/taint errors. Leave combat and verify refresh.
10. Start/end a pet battle where available. Test hide/show, automatic profession detection, and empty inventory.
11. Log out completely and verify settings/ignore list/positions and bindings survive a restart.
12. Capture screenshots of bars/options and any full error stack, plus `/shatterbar status` output.

Record the client build, character profession/rank, item IDs, action, expected result,
actual result, and screenshots before changing a row to PASS.

## Retail recipe prospecting (0.1.10)

- Confirm learned Midnight Prospecting and at least five eligible ore in one stack.
- Open Jewelcrafting once, then verify the bar appears even without the old Prospecting spell.
- Test each ore quality, multiple expansion recipes, unknown recipes, and short/locked stacks.
- Click an item and use both first-item keybinds. Verify exactly one batch, the intended
  stack/quality, and no concentration use. Confirm actual protected-action permission.
- Move/exhaust the stack and verify the next press refreshes its target. Test combat/casting guards.
- Click the profession icon and verify it opens Jewelcrafting.
- If anything fails, run `/sb prospectdebug` then `/reload` to preserve the relevant client data.

## Experimental Warband Bank ore (0.1.10)

- Option starts off; carried-only prospecting must behave as before.
- Enable the option. Test bank-only ore with the Warband Bank open and then closed.
- Check W marker, tooltip source counts, one-batch click/keybind behavior, and no concentration.
- Carry eligible ore too; verify carried stacks are consumed first and counts are not duplicated.
- Move/remove the bank stack between presses; verify no different item is processed.
- Test short stacks in both sources, ignored ore, unlearned recipe, and combat/casting.
- Disable the option and verify bank entries/keybind targets disappear immediately.
- Record whether remote bank targets are exposed and craftable. If not, collect
  `/sb prospectdebug` followed by `/reload`. Remove the feature if it is not useful.

## Confirmed by Arametheus - October 22, 2026

- Retail disenchanting works; the four reported non-disenchantable items were excluded.
- Retail carried-ore recipe prospecting works; individual expansion coverage is still being tested.
- Warband Bank ore works while the bank is open.
- ShatterBar 0.1.9: clicking a W item successfully prospects Warband Bank ore remotely
  with Jewelcrafting open and the bank closed. Screenshot 2026-10-22 205838.png
  shows crafting results and updated counts; user explicitly confirmed the ShatterBar click.
- Closing Jewelcrafting removes remote targets in the observed session. Keep Jewelcrafting
  open for remote use. Clicking was confirmed; the bank-source keybind path still needs its own test.
- Other clients, milling, lockpicking, and the remaining checklist are not yet confirmed in game.

## Retail recipe milling (0.1.10): in-game verification pending

- Test carried herbs with a learned old five-herb recipe and a modern ten-herb recipe.
- Verify insufficient stacks are omitted, correct batch counts, exact-stack targeting,
  one operation per click/key press, and count updates after each mill.
- Confirm the profession icon opens Inscription. Test unlearned recipes and ignore lists.
- Enable the separate Warband Bank herbs option. Test with the bank open and then
  the bank closed with Inscription open, as for prospecting. Carried herbs come first.
- Verify ore/herb bank options work independently and prospecting remains unchanged.
- Use `/sb milldebug` then `/reload` if eligible herbs are absent or cannot be milled.

Retail carried milling and Warband Bank herb milling with Inscription open were confirmed
in game by Arametheus on October 22, 2026 (0.1.10). Rogue bar visibility was confirmed;
actual lockbox unlocking is still untested. Newer ten-herb milling is still untested in game.

## Pick then open (0.1.12): new opening step needs in-game confirmation

Rogue bar detection and successful lockpicking were confirmed by Arametheus.
The old build kept the unlocked box targeting Pick Lock and required opening it from bags.

- Click a locked box and finish the cast. Verify its label changes to Open.
- Click it again and confirm the ordinary loot window/auto-loot behavior, then removal.
- Test two same-ID boxes with different lock states; open the unlocked box first.
- Test the lockpicking keybind, moving the box, full bags/partial loot, and combat.
- Right-click must remain Ignore. Restore any box ignored during earlier testing.

## Localization acceptance (0.1.13)

Automated checks cover all 11 locale catalogs, enGB English alias, unknown-locale
English fallback, format argument preservation, initialization, status output, and
localized binding names. Existing functional scenarios remain in the same suite.
All five packages must include Localization.lua before Core.lua.

In each localized game client, reload and open Settings > AddOns > ShatterBar.
Check wrapped labels, numeric Apply controls, direction changes, binding capture,
ignore restoration, scrolling, profession tooltips, and item action hints.
Confirm native item/spell details remain Blizzard-localized. Check decimal comma
input for scale. These visual and native-language checks are not yet performed.

## Language override (0.1.14)

Check the native AddOns Language selector, choose an override and click Reload UI.
Confirm the chosen language and binding names persist after logging into another
character. Choose Automatic to restore the client language after reload.
Automated coverage includes every override, invalid saved values and selector clicks.
Retail lockpicking and the second click to open/loot were both confirmed by the user.
