// Scripted player B for the end-to-end test: joins Godot's invite code, then plays to the end
// (flips now and then, heists missing cards, takes a moment before finishing Piece rounds).
import { readFileSync, existsSync } from "node:fs";
import { signup, call, kinds } from "./api.ts";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const tok = await signup("Ben");
let code = "";
for (let i = 0; i < 300 && !code; i++) {
  if (existsSync("/tmp/wp_code.txt")) code = readFileSync("/tmp/wp_code.txt", "utf8").trim();
  else await sleep(300);
}
console.log("B code", code, (await call(tok, "join_invite", { code, name: "Ben" })).status);
let gid = "";
for (let i = 0; i < 200 && !gid; i++) {
  const s = await call(tok, "invite_status", { code });
  gid = s.data.game_id ?? "";
  if (!gid) await sleep(300);
}
console.log("B game", gid);
let flips = 0, rounds = 0;
for (let i = 0; i < 3000; i++) {
  const s = (await call(tok, "state", { game_id: gid })).data;
  if (s.status !== "active") { console.log("B done:", s.view.events.at(-1).text, `(B flipped ${flips} times, arranged ${rounds} Piece rounds)`); break; }
  if (s.view.round % 2 === 1) {
    if (i % 9 === 0) { const r = await call(tok, "act", { game_id: gid, move: { t: "flip" } }); if (r.status === 200) flips++; }
  } else if (!s.view.piece_done[0]) {
    const v = s.view, pending = v.pending_heist;
    const actor = Object.keys(pending).length ? 1 - pending.attacker : (v.heist_order[v.heist_step] ?? -1);
    if (actor === 0) {
      const move = Object.keys(pending).length ? {t:"defend", block:v.shields[0]>0}
        : v.heist_options.length ? {t:"heist", ...v.heist_options[0]} : {t:"pass"};
      await call(tok, "act", {game_id:gid, move});
    } else if (actor < 0) {
      await call(tok, "act", {game_id:gid, move:{t:"done"}}); rounds++;
    }
  }
  await sleep(250);
}
