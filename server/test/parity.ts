import { readFileSync } from "node:fs";
import { Game, COLORS } from "../functions/gem-heist/engine.ts";

const games = JSON.parse(readFileSync("/tmp/parity/games.json", "utf8"));
// Capture third-person text (viewer -1) to compare with Godot's "Ana"/"Ben" wording.
const origEv = Game.prototype.ev;
Game.prototype.ev = function (p, text, card, face, big) {
  const e = origEv.call(this, p, text, card, face, big);
  (e as any).t3 = text(-1);
  return e;
};
const sortKeys = (v: any): any => Array.isArray(v) ? v.map(sortKeys) : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])])) : typeof v === "number" ? Math.round(v) : v;
const norm = (x: any) => JSON.stringify(sortKeys(x));
const strip = (st: any) => ({
  players: st.players.map((pl: any) => ({ hand: pl.hand, bank: pl.bank, vault: pl.vault, collection: COLORS.map((c) => pl.collection[c]) })),
  deck: st.deck, discard: st.discard, current: st.current, plays_left: st.plays_left, winner: st.winner,
  counter_owed: st.counter_owed, owes: st.owes,
});
let steps = 0, textMismatch = 0, fails = 0;
for (const [gi, gm] of games.entries()) {
  const s0 = gm.start;
  const g = new Game({ ...JSON.parse(JSON.stringify(s0)), plays_per_turn: gm.plays_per_turn, turn_number: gm.turn_number, events: [], rng: 1 });
  for (const [si, st] of gm.steps.entries()) {
    const evBefore = g.s.events.length;
    const ok = g.apply(st.move);
    steps++;
    if (!ok) { console.log(`game ${gi} step ${si}: TS says illegal`, JSON.stringify(st.move)); fails++; break; }
    const a = norm(strip(g.s)), b = norm(strip(st.after));
    const last = st.texts.some((t: string) => t.includes("random card") || t.includes("shuffled") || (t.startsWith("Reflected!") && !t.includes("Grand Heist")));
    if (last) break;
    if (a !== b) { console.log(`game ${gi} step ${si}: state differs after`, JSON.stringify(st.move)); fails++; break; }
    const tsTexts = g.s.events.slice(evBefore).map((e: any) => e.t3);
    if (JSON.stringify(tsTexts) !== JSON.stringify(st.texts)) {
      if (textMismatch < 8) console.log("TEXT\n  godot:", st.texts, "\n  ts:   ", tsTexts);
      textMismatch++;
    }
  }
}
console.log(`games ${games.length}, steps ${steps}, state failures ${fails}, text mismatches ${textMismatch}`);
