import { register } from "node:module";
register("./loader.mjs", import.meta.url);
(globalThis as any).Deno = { env: { get: () => "mock" }, serve: (h: any) => { (globalThis as any).__handler = h; } };
const { tables } = await import("./mock_supabase.ts");
await import("../functions/gem-heist/index.ts");
const handler = (globalThis as any).__handler;
let n = 0;
function user(name: string) {
  const id = crypto.randomUUID();
  tables.users.push({ id, token: "t" + id });
  tables.profiles.push({ id, display_name: name, avatar: {}, is_guest: false, beaten: [] });
  return async (action: string, extra: any = {}) => {
    const r = await handler(new Request("http://x/", { method: "POST", headers: { Authorization: "Bearer t" + id }, body: JSON.stringify({ action, ...extra }) }));
    return { status: r.status, data: await r.json() };
  };
}
const check = (ok: boolean, what: string) => { n++; console.log((ok ? "PASS " : "FAIL ") + what); if (!ok) process.exitCode = 1; };

const host = user("Simon"), guest = user("Maya"), other = user("Leo");
const { data: { code } } = await host("create_invite");
check((await guest("join_invite", { code, name: "Maya" })).data.status === "pending", "guest joins -> pending");
check((await other("join_invite", { code, name: "Leo" })).status === 400, "a second person can't grab a pending code");
check((await guest("respond_invite", { code, accept: true })).status === 404, "only the host can accept");
await host("respond_invite", { code, accept: false });
check((await guest("invite_status", { code })).status === 404, "declined guest is told it didn't go through");
check((await other("join_invite", { code, name: "Leo<script>" })).data.status === "pending", "after a no, the code opens for the right person");
check(tables.invites[0].guest_name === "Leoscript", "names are cleaned to letters only");
const acc = await host("respond_invite", { code, accept: true });
const gid = acc.data.game_id;
check(!!gid, "host accepts -> game created");
check((await guest("state", { game_id: gid })).status === 403, "outsiders can't see the game");
const sv = (await other("state", { game_id: gid })).data.view;
check(sv.players[1].hand.every((c: any) => c.kind === "hidden" && c.id < 0), "opponent's hand is hidden (no kinds, no real ids)");
check(sv.players[0].hand.every((c: any) => c.kind !== "hidden"), "your own hand is visible");
check(!("deck" in sv) && typeof sv.deck_count === "number", "deck order never sent");
const cur = sv.current === 0 ? other : host;
const notCur = sv.current === 0 ? host : other;
check((await notCur("act", { game_id: gid, move: { type: "end" } })).status === 409, "can't move out of turn");
check((await cur("act", { game_id: gid, move: { type: "heist", card: 999, as: "grand", color: "ruby" } })).status === 409, "illegal moves are rejected");
check((await cur("act", { game_id: gid, move: { type: "end" } })).status === 200, "legal move accepted");
// matchmaking
const a = user("Ana"), b = user("Ben");
check((await a("find_match")).data.waiting === true, "first player waits in the queue");
check((await a("match_status")).data.waiting === true, "still waiting");
const mb = await b("find_match");
check(!!mb.data.game_id, "second player gets matched immediately");
check((await a("match_status")).data.game_id === mb.data.game_id, "first player finds the same game");
check((await a("my_games")).data.games.length === 1, "game shows in Your games");
// avatars: photos never stored
await a("update_profile", { avatar: { skin: 3, portrait_path: "user://portraits/me.png", photo_data: "xyz" } });
const prof = tables.profiles.find((p: any) => p.display_name === "Ana");
check(!("portrait_path" in prof.avatar) && !("photo_data" in prof.avatar) && prof.avatar.skin === 3, "photos are stripped from avatars");
console.log(`${n} checks done`);
