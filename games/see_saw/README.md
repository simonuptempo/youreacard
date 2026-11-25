# See Saw

The third **You're a Card** game: a memory game. It lives inside the You're a Card app
(open it from the See Saw tile on the home screen); all its code is in `games/see_saw/`.

- **Level N shows N cards for N seconds.** Then they flip face down and you answer 2–3 quick multiple-choice questions (2 on levels 1–2, 3 after that).
- **Answer them all right** to move up a level.
- **A wrong answer costs a life** (you have 3) and you try that level again with new cards. The cards flip back up so you can see what you missed.
- **Score** = highest level reached. Your best is saved on the device.

Jacks, Queens, Kings and Aces are characters (Pip, Juno, Lou, Amara), same names and art as the Profile cast (`res://art/role-*.png`).

## Questions
`nth_card` What was the 2nd card? · `nth_suit` What suit was it? · `nth_rank` What number was it? ·
`nth_color` What color? (easy levels) · `yes_no` Was there a Spade / an Ace / a character card? ·
`character` Who was on the character card? · `which_shown` Which of these did you see? ·
`not_shown` Which card was NOT shown? · `extreme` Highest / lowest card? ·
`where` Where was the 7 of Clubs? (3+ cards) · `count` How many Hearts were there? (3+ cards)

Wrong answers are near misses (same rank other suit, a rank or two off, or a card that *was* shown but in a different spot). A round never asks the same kind twice. Weights per level are in `KINDS` at the top of `scripts/ss_questions.gd`.

## Code (all paths under games/see_saw/)
- `scripts/ss_cards.gd` deck, names, characters
- `scripts/ss_questions.gd` question generator + `is_correct()` checker
- `scripts/see_saw.gd` the rules engine (levels, lives, phases; seeded RNG)
- `scripts/best.gd` best score (`user://see_saw.cfg`)
- `scripts/game.gd` the table (get ready → look → answer → next level / game over); `scripts/main.gd` menu and How to Play
- `scripts/ss_card_view.gd` card drawing (from War and Piece)
- Shared, not changed: `scripts/ui.gd`, `fonts/Nunito.ttf`, `Profile` (home navigation, your name), `Sfx` (sounds)
- Shared, small edit: `scripts/home.gd` (See Saw tile is Play and opens `games/see_saw/scenes/main.tscn`)

## Tests
```
godot --headless --path . -s games/see_saw/tests/sim.gd            # 18,000 questions: exactly one right answer each; full games
godot --headless --path . -s games/see_saw/tests/ui_playthrough.gd # real screens, 3 games end to end, best score saved
OUT=/tmp/shots godot --path . -s games/see_saw/tests/shots.gd      # screenshots of every screen (needs a display)
```
`SEESAW_SEED` and `SEESAW_LEVEL` env vars start the game on a fixed deal / level.

## Next
Gimmicks, your own face on the characters (via Profile), friends and leaderboards.
Online play will get its own Supabase edge function (not Gem Heist's).

## Age screen (shared)
Anything that sends data off the phone (online play, photo-to-cartoon) must go through `AgeGate.require(...)` in `scripts/age_gate.gd`. The birthday is asked once for the whole app and kept in Profile, so a player who answered in another game is never asked again. Under 13: nothing leaves the phone (Online._http also refuses as a backstop).
