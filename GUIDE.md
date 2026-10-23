# ShatterBar usage guide

## Using the bars

Left-click an item to process it. Shift-drag a profession icon to move its bar.
Right-click a profession icon to open options. Right-click an item to ignore its
type; restore it in the Ignored items section of options.

For lockboxes, left-click once to pick the lock and again to open and loot.
Each click or key press performs one action or one batch. Processing pauses in
combat and while casting. Short material stacks are not moved or combined.

## Keybindings

Assign keys in ShatterBar options or the game's Key Bindings > ShatterBar category.
The general binding uses the first nonempty available bar in this order:
Disenchant, Prospect, Mill, Pick Lock. Each profession also has its own binding.
Escape cancels key capture; Backspace or Delete clears a binding. Assigning a key
replaces its previous action.

## Retail recipes and Warband Bank

Retail prospecting and milling use learned expansion-specific recipes. If a bar
is missing, open Jewelcrafting or Inscription once to populate recipe data. The
profession icon opens the relevant profession.

Warband ore and herb support are separate experimental settings, both off by
default. Bank-only entries have a **W** marker. Open the bank or keep the relevant
profession open so the game exposes live bank targets; opening its material picker
may also be necessary. Closing the profession can remove remote access. Personal
bank items and cached inventory without a live target are excluded.

Recipe batches use their mapped size: usually five materials, with some newer
milling recipes requiring ten. Each stack must contain a complete batch.

## Languages

English is the default fallback. German, French, Spanish (Spain and Latin America),
Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese, and Traditional
Chinese translations are included. Choose **Automatic (client language)** or an
override under **Language**, then click **Reload UI**. The choice saves account-wide.
Blizzard's item and spell text continues to use the client language. Translations
and their layouts still need native-speaker and in-game review.

## Troubleshooting

`/sb status` reports the version and listed items. `/sb debug`, `/sb prospectdebug`,
and `/sb milldebug` record diagnostics; `/reload` writes them to SavedVariables.
Reports can contain item links and item instance identifiers; review before sharing.

For a bug report, include client/build, ShatterBar version, profession, item name/ID,
steps to reproduce, and any Lua error. Do not upload your entire WTF folder.
