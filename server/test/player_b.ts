// Scripted second player: joins by invite code, then plays simple legal moves each turn.
import { existsSync, readFileSync } from "node:fs";
const BASE = "http://127.0.0.1:54321";
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
async function post(path: string, body: any, token?: string) {
  const r = await fetch(BASE + path, { method: "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) }, body: JSON.stringify(body) });
  return { status: r.status, data: await r.json().catch(() => null) };
}
while (!existsSync("/tmp/yac_code.txt")) await sleep(200);
const code = readFileSync("/tmp/yac_code.txt", "utf8").trim();
const s = await post("/auth/v1/signup", { data: { display_name: "Maya" } });
const tok = s.data.access_token;
const fn = (action: string, extra: any = {}) => post("/functions/v1/gem-heist", { action, ...extra }, tok);
console.log("B join:", JSON.stringify((await fn("join_invite", { code, name: "Maya" })).data));
let gameId = "";
for (let i = 0; i < 300 && !gameId; i++) {
  const st = await fn("invite_status", { code });
  if (st.data?.game_id) gameId = st.data.game_id;
  await sleep(300);
}
console.log("B game:", gameId);
let moves = 0;
for (let i = 0; i < 5000; i++) {
  const r = await fn("state", { game_id: gameId, since_seq: 1000000 });
  const v = r.data.view;
  if (v.winner >= 0) { console.log("B sees game over, winner (B's view):", v.winner, "B moves:", moves); break; }
  if (v.current !== 0) { await sleep(150); continue; }
  const me = v.players[0];
  let move: any = null;
  if (v.counter_owed[0]) move = { type: "counter_skip" };
  else if (me.hand.length > 7) move = { type: "discard", card: me.hand[0].id };
  else if (v.plays_left > 0) {
    for (const c of me.hand) {
      if (/^loot/.test(c.kind)) { move = { type: "bank", card: c.id }; break; }
      const gems = ["ruby", "emerald", "sapphire", "topaz", "diamond", "amethyst"];
      if (gems.includes(c.kind)) { move = { type: "collect", card: c.id, color: c.kind }; break; }
      if (c.kind === "payup" && v.players[1].bank.length) { move = { type: "heist", card: c.id, as: "payup" }; break; }
    }
  }
  if (!move) move = { type: "end" };
  const a = await fn("act", { game_id: gameId, move });
  if (a.status !== 200) { console.log("B move rejected", JSON.stringify(move), a.data); await fn("act", { game_id: gameId, move: { type: "end" } }); }
  moves++;
}
// Finally, prove account deletion works.
const d = await fn("delete_account");
console.log("B delete:", JSON.stringify(d.data), "then me():", (await fn("me")).status);
