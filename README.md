# You're a Card: Gem Heist

**You're a Card** is a family of quick, async card games where you put your own face (or your
cat's or dog's) on the cards. **Gem Heist** is the first game: collect gem sets, bank bills, and
outsmart your opponent with heists and twists. Play friends online, or take on 8 characters.

- **Engine:** Godot 4.7.1 (GDScript), portrait phone layout.
- **Online:** Supabase project `youreacard` (accounts, games, invites, matchmaking). See `server/`.
- **Website:** https://youreacard.lovable.app (Lovable, shares the same accounts).
- **On your iPhone:** see [TESTFLIGHT.md](TESTFLIGHT.md).

## Run it on your Mac
1. Open Godot 4.7.1 → Import → choose this folder's `project.godot`.
2. Press F5 (Play).

## Project map
- `scripts/game_state.gd` - the rules (the server's copy is `server/functions/gem-heist/engine.ts`; keep them in step)
- `scripts/game.gd` - the table screen (local, practice and online games)
- `scripts/online.gd`, `online_menu.gd` - accounts and the Play Online screen
- `scripts/sfx.gd`, `voice_recorder.gd`, `audio/` - sound effects, character voices, your own voice
- `scripts/avatar_*.gd`, `selfie_capture.gd`, `my_cards.gd` - putting faces on cards
- `tools/make_audio.py` - regenerates every sound and voice (`python3 tools/make_audio.py audio`)
- `tests/` - `sim.gd` (bot games), `ui_playthrough.gd`, `online_e2e.gd`; server tests in `server/test/`

---

## Earlier prototype notes

Local prototype: you vs. a bot, full 90-card deck, traps and decoys, wilds, avatar creator
with role costumes. Online async play (Supabase + push) is milestone M3.

## Run it
1. Open Godot 4.7 → Import → choose this folder's `project.godot`.
2. Press F5 (Play). The window is phone-shaped (portrait).

## New in v0.4
- **Loot** (the Critter Crew: Mouse 1, Raccoon 2, Fox 3, Owl 4, Magpie 5). Bank it with a play;
  Heists cost Loot (Swipe 2, Swap 1, Shakedown 1, Lockpick 1, Grand Heist 5). New card: **Pay Up!**
- **Rules:** draw 2, play up to 3, first to **4 sets**. Rubies need 2 cards, all other sets 3. Deck: 90 cards.
- Simulated pacing: ~13.7 turns per player for bots; expect ~15–20 with people.
- New playful logo + masked-card app icon.

## New in v0.3
- **Painted art** from `art/`: card frames per type, card back, treasure icons, logo, felt table,
  app icon. `scripts/art.gd` loads them; any missing file falls back to the code-drawn version.
- Avatar shading, extra skin tones, face size and new shirts (from the ChatGPT pass) kept as-is.

## New in v0.2
- **First-time setup:** welcome → your name → make your card → "Meet your cards" reveal.
  Replay it anytime from Settings → "Replay first-time setup".
- **Settings** (gear, top right of the menu): edit your card, change your name, switch back
  to the default cast, open the step-by-step tutorial, and toggle 2 or 3 plays per turn.
- **Learn to Play:** a player-paced, 13-step animated walkthrough with Next, Back, Replay Animation, and Close. Every example holds until Next. Loot values appear directly on the coins throughout the game.

## What to try
- **Make My Avatar** first, then play: your face appears on every character card you hold.
- Hide a trap in your vault, then watch the bot's Swipe bounce off it.
- Use a Lockpick on the bot's vault before a big heist.
- Settings: switch between 2 and 3 plays per turn for playtesting.

## Files
- `scripts/game_state.gd` — the rules engine (no UI; will move to the server later)
- `scripts/bot.gd` — heuristic opponent
- `scripts/avatar_view.gd` — procedural paper-doll avatar + role costumes
- `scripts/card_view.gd` — card drawing
- `scripts/game.gd`, `main.gd`, `avatar_creator.gd` — screens
- `tests/sim.gd` — 600 bot-vs-bot games: `godot --headless --path . -s res://tests/sim.gd`
- `scripts/onboarding.gd`, `settings.gd`, `explainer.gd` — first-run flow, settings, how-to-play animation

## Interactive tutorial
Open **Learn to Play** from the main menu, Settings, or onboarding. Short animations stop at their final state; the player advances manually. The turn lesson follows the selected 2/3-play setting.

The existing `marketing/YoureACard_HowToPlay.mp4` is a legacy export and is not used by the tutorial. The explainer no longer runs a timed movie sequence or supports the old `--movie` auto-exit workflow.

Loot values (Mouse 1, Raccoon 2, Fox 3, Owl 4, Magpie 5) are drawn as native badges on the coins by `Art.draw_coin`, so full cards, bank displays, and the tutorial share the same labels. The source PNGs remain unnumbered.
