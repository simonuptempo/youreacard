// The war-and-piece function against the in-memory stand-in: invites, hidden cards,
// who may move, ordered attacks and defenses, a whole game to the end, matchmaking, resign.
// Run: node --experimental-strip-types run_server.ts & then node --experimental-strip-types edge_cases.ts
import { signup, call, kinds } from "./api.ts";

let fails = 0;
let heists = 0;
const check = (ok: boolean, what: string) => { console.log((ok ? "ok   " : "FAIL ") + what); if (!ok) fails++; };

const ana = await signup("Ana", "ana@example.com");
const ben = await signup("Ben");

// ---- invite: Ana makes a code, Ben joins, Ana confirms
const { data: inv } = await call(ana, "create_invite");
check(/^[A-Z2-9]{6}$/.test(inv.code), "invite code looks right: " + inv.code);
check((await call(ana, "join_invite", { code: inv.code, name: "Ana" })).status === 400, "can't join your own code");
const j = await call(ben, "join_invite", { code: inv.code.toLowerCase(), name: "Benny" });
check(j.status === 200 && j.data.host_name === "Ana", "guest joins (code is case-insensitive)");
check((await call(ana, "invite_status", { code: inv.code })).data.guest_name === "Benny", "host sees the guest's name");
const acc = await call(ana, "respond_invite", { code: inv.code, accept: true });
check(acc.data.status === "accepted" && !!acc.data.game_id, "host accepts: game made");
const gid = acc.data.game_id;
check((await call(ben, "invite_status", { code: inv.code })).data.game_id === gid, "guest finds the game");

// ---- what each seat sees
let a = (await call(ana, "state", { game_id: gid })).data;
let b = (await call(ben, "state", { game_id: gid })).data;
check(a.view.players[0].name === "Ana" && b.view.players[0].name === "Benny", "each player is player 0 in their own view");
check(a.opponent.name === "Benny" && b.opponent.name === "Ana", "opponent names");
check(a.view.players[0].stock.length === 26 && a.view.players[0].stock.every((c: any) => c.id === 0), "stocks are face down (no card ids)");
check(a.view.rng === 0, "the shuffle seed stays on the server");
check(a.my_turn && b.my_turn, "War: either player can flip");
const stranger = await signup("Cy");
check((await call(stranger, "state", { game_id: gid })).status === 403, "someone else can't open the game");

// ---- War: both flip; texts say "You" to the right person
let r = await call(ana, "act", { game_id: gid, move: { t: "flip" } });
check(r.status === 200 && r.data.view.last_faceoff.ups.length === 2, "Ana flips");
const evA = r.data.view.events.at(-1), evB = (await call(ben, "state", { game_id: gid })).data.view.events.at(-1);
check((evA.text.includes("You") || evA.text.includes("Benny")) && (evB.text.includes("You") || evB.text.includes("Ana")), "event worded for each player: " + evA.text + " | " + evB.text);
check(evA.p === -1 || evB.p === -1 || evA.p !== evB.p, "event owner turned around for each player");
r = await call(ben, "act", { game_id: gid, move: { t: "flip" } });
check(r.status === 200, "Ben flips too");
check((await call(ana, "act", { game_id: gid, move: { t: "done" } })).status === 409, "can't finish a Piece round during War");
r = await call(ben, "act", { game_id: gid, move: { t: "flip_all" } });
check(r.data.view.round === 2, "flip to the end of the War round");

// ---- Piece: only the authenticated attacker/defender may act.
a = (await call(ana, "state", { game_id: gid })).data;
b = (await call(ben, "state", { game_id: gid })).data;
check(a.my_turn !== b.my_turn, "Piece has exactly one active player");
check(a.view.players[1].hand.every((c: any) => c.id === 0), "opponent hand is hidden");
check(a.view.shields[1] === -1 && b.view.shields[1] === -1, "opponent shields are hidden");
check(!("shield_draws" in a.view) && !("shield_pool" in a.view), "private shield metadata is absent");
check((await call(ana, "act", {game_id:gid, move:{t:"done"}})).status === 409, "cannot skip unfinished heist turns");
let safety = 0, defenses = 0;
while (safety++ < 500) {
  const state = (await call(ana, "state", {game_id:gid})).data;
  if (state.status !== "active") break;
  if (state.view.round % 2) {
    await call(ana, "act", {game_id:gid, move:{t:"flip_all"}}); continue;
  }
  for (const [tok, other] of [[ana,ben],[ben,ana]]) {
    const me = (await call(tok,"state",{game_id:gid})).data;
    if (me.status !== "active" || me.view.round % 2 || me.view.piece_done[0]) continue;
    const v = me.view, pending = v.pending_heist;
    const actor = Object.keys(pending).length ? 1-pending.attacker : (v.heist_order[v.heist_step] ?? -1);
    if (actor > 0) continue;
    let move: any;
    if (Object.keys(pending).length) {
      check((await call(other,"act",{game_id:gid,move:{t:"defend",p:1,block:false}})).status === 409, "attacker cannot impersonate defender");
      if (!v.shields[0]) check((await call(tok,"act",{game_id:gid,move:{t:"defend",block:true}})).status === 409, "cannot block without a shield");
      move={t:"defend",block:v.shields[0]>0}; defenses++;
    } else if (actor < 0) move={t:"done"};
    else {
      check((await call(other,"act",{game_id:gid,move:{t:"pass",p:1}})).status === 409, "cannot impersonate attacker");
      move=v.heist_options.length ? {t:"heist",...v.heist_options[0]} : {t:"pass"};
      if(move.t === "heist") heists++;
    }
    const result=await call(tok,"act",{game_id:gid,move:{...move,p:1}});
    check(result.status === 200, "authenticated " + move.t + " (spoofed seat ignored)");
    if(move.t==="heist") check(Object.keys(result.data.view.pending_heist).length===0,"heist resolves atomically");
  }
}
check(defenses === 0, "shields resolve without a defense turn");
a = (await call(ana, "state", { game_id: gid })).data;
b = (await call(ben, "state", { game_id: gid })).data;
check(a.status === "finished" && [0, 1, 2].includes(a.view.winner), "game finished: " + a.view.events.at(-1).text);
check(a.view.winner === 2 ? b.view.winner === 2 : a.view.winner === 1 - b.view.winner, "winner turned around for each player");
check((await call(ana, "act", { game_id: gid, move: { t: "flip" } })).status === 400, "no moves after the end");
const list = (await call(ben, "my_games")).data.games;
check(list.length === 1 && list[0].opponent === "Ana" && list[0].won !== null, "Ben's games list");

// ---- matchmaking and resign
const cy = stranger, dee = await signup("Dee");
check((await call(cy, "find_match")).data.waiting === true, "first in the queue waits");
const m = await call(dee, "find_match");
check(!!m.data.game_id, "second player gets a game");
check((await call(cy, "match_status")).data.game_id === m.data.game_id, "first player finds it");
await call(cy, "resign", { game_id: m.data.game_id });
const after = (await call(dee, "state", { game_id: m.data.game_id })).data;
check(after.status === "finished" && after.view.winner === 0 && after.view.events.at(-1).text === "Cy left the game.", "resign: the other player wins");

check(heists > 0, "played authenticated heist moves");
console.log(fails ? `${fails} FAILED` : "ALL OK");
process.exit(fails ? 1 : 0);
