// Sacrifice in the server engine: same rule and same wording as the app (tests/sacrifice.gd).
import assert from "node:assert";
import { Game, cost } from "../functions/gem-heist/engine.ts";

const g = Game.create(["You", "Juno"], 4242, 0, 3);
const p = g.s.current;
g.s.players[p].bank = [];
g.s.players[p].credit = 0;
g.hand(p).push({ id: 9001, kind: "swipe" } as any, { id: 9002, kind: "grand" } as any);
const moves = g.legalMoves(p);
assert(moves.some((m: any) => m.type === "sacrifice" && m.card === 9001));
for (const m of moves as any[]) if (m.type === "sacrifice") assert(cost(g.findHandCard(p, m.card)!.kind) > 0);
const plays = g.s.plays_left, discards = g.s.discard.length;
assert(g.apply({ type: "sacrifice", card: 9001 } as any));
assert.equal(g.bankTotal(p), 2);
assert.equal(g.s.plays_left, plays - 1);
assert.equal(g.s.discard.length, discards + 1);
assert(g.apply({ type: "sacrifice", card: 9002 } as any));
assert.equal(g.bankTotal(p), 7);
const ev = g.s.events;
const text = `${ev[ev.length - 2].t[p]} | ${ev[ev.length - 1].t[p]}`;
assert.equal(text, "You sacrificed Heist for 2 bills. | You sacrificed Grand Heist for 5 bills.");
console.log("SERVER SACRIFICE OK: " + text);
