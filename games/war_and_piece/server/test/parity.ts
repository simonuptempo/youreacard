// Godot engine vs. server engine, move for move. First run (from the project folder):
//   godot --headless --path . -s res://games/war_and_piece/tests/parity_dump.gd        (writes /tmp/wp_parity/games.json)
// then: node --experimental-strip-types games/war_and_piece/server/test/parity.ts
import { readFileSync } from "node:fs";
import { Game } from "../functions/war-and-piece/engine.ts";

const file = process.argv[2] ?? "/tmp/wp_parity/games.json";
const games = JSON.parse(readFileSync(file, "utf8"));
const sortKeys = (v: any): any => Array.isArray(v) ? v.map(sortKeys)
  : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]))
  : typeof v === "number" ? Number(v) : v;
const norm = (x: any) => JSON.stringify(sortKeys(x));
let steps = 0, fails = 0, illegal = 0, events = 0;
for (const [gi, gm] of games.entries()) {
  const g = Game.create(gm.names, gm.seed);
  for (const [si, st] of gm.steps.entries()) {
    steps++;
    const ok = g.apply(JSON.parse(JSON.stringify(st.move)));
    if (!st.ok) illegal++;
    if (ok !== st.ok) { console.log(`game ${gi} step ${si}: godot says ${st.ok}, ts says ${ok}`, JSON.stringify(st.move)); fails++; break; }
    const a = norm(g.s), b = norm(st.after);
    if (a !== b) {
      console.log(`game ${gi} step ${si}: state differs after`, JSON.stringify(st.move));
      for (const k of Object.keys(st.after)) if (norm((g.s as any)[k]) !== norm(st.after[k])) console.log("  differs:", k, "\n   ts:   ", norm((g.s as any)[k]).slice(0, 400), "\n   godot:", norm(st.after[k]).slice(0, 400));
      fails++;
      break;
    }
  }
  events += g.s.events.length;
}
console.log(`games ${games.length}, moves ${steps} (${illegal} illegal), events ${events}, failures ${fails}`);
process.exit(fails ? 1 : 0);
