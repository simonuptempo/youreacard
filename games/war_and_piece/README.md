# War and Piece

The second **You're a Card** game. Everything for it lives in this folder; it uses the app's
shared `scripts/ui.gd`, `fonts/Nunito.ttf`, `Profile`, `Online`, `Sfx`, card maker (My Cards) and
voice recorder, and the painted character art in `art/role-*.png`.
Opened from the home screen's War and Piece tile (`scenes/main.tscn` here).

## The game
- **Odd rounds: War.** Flip your top card; the higher card wins both. A tie is a war (3 down, 1 up).
  More locked sets wins ties outright. Won cards go to your winnings. The round ends when someone's
  stock runs out, and you keep what's left in yours.
- **Even rounds: Piece.** Lock your winnings into sets (3+ of a kind, or 3+ in a row of one suit, Aces
  high), or add to sets you locked earlier. Locked sets are safe forever, count toward winning, and win
  ties in War. Unlocked cards are shuffled into your stock for the next War.
- **Winning:** lock away 30 of the 52 cards. The game also ends if someone has no loose cards for War,
  or two Piece rounds in a row go by with no new sets. Whoever locked more wins.
- Jacks, Queens, Kings and Aces are Pip, Juno, Lou and Amara. Put your own face (and voice) on them in
  My Cards: it shows on every one of those cards here, and a winning face card sometimes speaks.

## Code (`scripts/`)
- `war_cards.gd` deck, names, set rules (`WIN_LOCKED = 30`)
- `war_state.gd` the rules engine: seeded mulberry32 RNG, every change is a move through `apply()`,
  events worded for each player (`text` / `text1`)
- `war_bot.gd` arranges sets for the Computer and the Auto button
- `war_card_view.gd` draws the cards (faces from the shared Profile)
- `war_save.gd` the game against the Computer, saved after every move (`user://war_game.json`)
- `war_online.gd` calls this game's server function with the shared sign-in
- `menu.gd`, `game.gd` (the table: Computer or online), `online_menu.gd` (Play Online)

## Online (`server/`)
Its own Supabase edge function, **war-and-piece**, on the shared `youreacard` project, with its own
tables (`wp_games`, `wp_moves`, `wp_invites`, `wp_match_queue`; `migrations/001_war_and_piece.sql`).
Accounts and profiles are shared with Gem Heist. Each player gets the table turned so they are
player 0; stocks and the other player's Piece hand stay hidden. War: either player flips.
Piece: both arrange at the same time; when both tap Done, the next War starts.
- `functions/war-and-piece/engine.ts` is a copy of `war_cards.gd` + `war_state.gd`. **Keep them in step.**

## Tests
From the project folder (`godot` = Godot 4.7.1):
- `godot --headless --path . -s res://games/war_and_piece/tests/sim.gd` 500 bot games
- `.../tests/dist.gd` how long games run; `.../tests/save_resume.gd`; `.../tests/ui_playthrough.gd`
- `.../tests/shots.gd` screenshots (OUT=folder, needs a display)
- Parity: `.../tests/parity_dump.gd`, then `node --experimental-strip-types games/war_and_piece/server/test/parity.ts`
- Server: `node --experimental-strip-types run_server.ts &` then `edge_cases.ts` (in `server/test`)
- Online end to end: `games/war_and_piece/server/test/run_e2e.sh` (Godot client vs. a scripted player)

## Age screen (shared)
Anything that sends data off the phone (online play, photo-to-cartoon) must go through `AgeGate.require(...)` in `scripts/age_gate.gd`. The birthday is asked once for the whole app and kept in Profile, so a player who answered in another game is never asked again. Under 13: nothing leaves the phone (Online._http also refuses as a backstop).
