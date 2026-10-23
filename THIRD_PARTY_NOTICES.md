# Third-party notices

The files `Data/NoDisenchant_*.lua` are adapted from Molinari's generated
client-specific `data/*/nondisenchantable.lua` tables.

Source: https://github.com/p3lim-wow/Molinari
Pinned revision: dded160c5aed7cb5324b0536624a18bf2a27b72a
Generation rule: scripts/nondisenchantable.py selects ItemSparse records with
Flags_0 bit 0x8000 (No Disenchant), excluding deprecated/non-equipment/cosmetic
or out-of-range quality records that are separately filtered.

Copyright (c) 2006-2008 Trond A Ekseth
Copyright (c) 2009-2026 Adrian L Lange

Licensed under the MIT license. The complete copyright and permission notice is
included in licenses/Molinari-MIT.txt and ships in every client package.
Only the namespace and provenance comments were adapted. Data must be refreshed
from a reviewed pinned revision as client item databases evolve.

Retail uses Standard data. Forever uses Camelot. Classic Era uses Vanilla.
Mists and Burning Crusade Anniversary use their corresponding data files.
Each client ZIP contains only its corresponding exclusion table.

`Data/Prospecting_Retail.lua` is adapted from `data/Standard/prospectable.lua`
at the same revision, under the same MIT license. It maps ore item IDs to the
client's expansion-specific prospecting recipe and batch size. Only Retail loads
this recipe mapping; older clients retain the spell-based path.

`Data/Milling_Retail.lua` is adapted from `data/Standard/millable.lua` at the
same revision under the same MIT license, mapping herbs and other valid milling
inputs to expansion-specific recipes and per-recipe batch sizes (five or ten).

`Data/Lockboxes_*.lua` are adapted from the corresponding client `openable.lua`
tables at the same revision and under the same MIT license. They identify supported
lockbox/container item types so an unlocked box can remain as an explicit Open action.
