# Gem Heist server (Supabase project "youreacard")

- `functions/gem-heist/engine.ts` - the rules, ported from `scripts/game_state.gd`. Keep the two in step:
  any rule change in Godot must be made here too, then run `test/parity.ts`.
- `functions/gem-heist/index.ts` - every online action (moves, invites, matchmaking, account deletion).
- `functions/auth-relay/index.ts` - hands Apple/Google/Facebook sign-ins from the browser back to the app.
- `migrations/` - database tables, in order.

Tests (Node 22):
- `node --experimental-strip-types test/parity.ts` - Godot engine vs. server engine, move for move
  (needs /tmp/parity/games.json from the Godot dump script).
- `node --experimental-strip-types test/edge_cases.ts` - invites, hidden cards, matchmaking, photo stripping.
- `test/run_online_e2e.sh` - the real Godot client plays a full invite game against a scripted player,
  using a local stand-in for Supabase.
