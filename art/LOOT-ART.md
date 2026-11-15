# Critter Crew — Loot artwork

Six new PNGs for res://art/. Generated with the built-in image_gen tool; exact final prompts are in loot-manifest.json. Existing game scripts and rules were not changed.

| Value | Creature | Texture | Size |
|---|---|---|---|
| 1 | Mouse | loot-mouse.png | 512×512 |
| 2 | Raccoon | loot-raccoon.png | 512×512 |
| 3 | Fox | loot-fox.png | 512×512 |
| 4 | Owl | loot-owl.png | 512×512 |
| 5 | Magpie | loot-magpie.png | 512×512 |
| — | Copper Loot/money frame | frame-money.png | 600×840 |

The five coins share a copper rim and ivory interior, with transparent backgrounds outside the coin. Render values and card names as native Godot text; values are deliberately not baked into the images. Preserve texture aspect ratio. Use the same creature-to-value mapping in bank chips and full cards.

The frame is a transparent perimeter overlay, like the other frames. Draw a native card base beneath it, and art and text in its central opening. Keep content within x=12–88% and y=12–88% where practical. Retain native selection, highlight and dimmed states. See loot-validation.json for measured alpha in the central region; sparse 1/255 residual alpha may remain from generation/export.

No extra Pay Up! illustration is included: the requested set is five critter coins and one copper frame. The Boss avatar can continue to illustrate Pay Up! using the heist frame.

Integration note: the stated copy counts add 20 Loot + 4 Pay Up! cards. Starting from 68 gives 92 unless the revised set sizes remove two other cards; reconcile that with the intended 90-card deck during rules integration.

Validation: visually inspected all generated designs; checked exported PNG dimensions, alpha channels and transparent pixels. Actual game-layout verification belongs to texture integration.
