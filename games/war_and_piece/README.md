# War and Piece

The second **You're a Card** game, inside the You're a Card app. Open it from the home screen's War and Piece tile.

- **Odd rounds — War.** Flip your top card; higher card takes both. A tie is a war (3 down, 1 up). More locked sets wins ties outright. Won cards go to your winnings pile.
- **Even rounds — Piece.** Lock your winnings into sets (3+ of a kind, or 3+ in a row of one suit, Aces high), or add to sets you already locked. Locked sets are safe for good. Everything else is shuffled into your stock for the next War.
- **Winning.** Lock away 30 of the 52 cards. If someone has no loose cards left for War (or two Piece rounds pass with no new sets) whoever locked more wins.

Jacks, Queens, Kings and Aces are characters (Pip, Juno, Lou, Amara).

## Code
Everything is in `games/war_and_piece/`. Shared pieces come from the app: `scripts/ui.gd`, `fonts/Nunito.ttf`, `art/role-*.png`, Profile, Icon.
- `war_cards.gd` deck, names, set rules
- `war_state.gd` the rules engine (deterministic mulberry32 RNG, events)
- `war_bot.gd` set arranging for the computer and the Auto button
- `war_card_view.gd` card drawing
- `wp_table.gd` the table; `wp_menu.gd` menu and How to Play
- `tests/sim.gd`, `tests/dist.gd`, `tests/ui_playthrough.gd`, `tests/shots.gd`

## Next
Put your face on the characters (from Gem Heist), then online play with friends.
