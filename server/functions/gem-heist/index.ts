// Gem Heist server: every online action goes through here.
// Players never read the games table directly; this function hands each seat only
// what that seat may see (see Game.view in engine.ts).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { Game, type Move } from "./engine.ts";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
class Oops extends Error {
  status: number;
  constructor(msg: string, status = 400) { super(msg); this.status = status; }
}

// Codes avoid look-alike characters (0/O, 1/I/L) so they're easy to read aloud.
const CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const newCode = () => Array.from(crypto.getRandomValues(new Uint8Array(6)), (b) => CODE_CHARS[b % CODE_CHARS.length]).join("");

// First names only: letters, spaces, apostrophes and hyphens, 1-16 characters.
function cleanName(raw: unknown): string {
  const s = String(raw ?? "").replace(/[^\p{L}' -]/gu, "").replace(/\s+/g, " ").trim().slice(0, 16);
  if (!s) throw new Oops("Please enter a first name.");
  return s;
}
// Avatars are cartoon settings only. Real photos never leave the player's phone.
function cleanAvatar(a: unknown): Record<string, unknown> {
  if (!a || typeof a !== "object") return {};
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a as Record<string, unknown>)) {
    if (k === "portrait_path" || k.includes("photo")) continue;
    if (["string", "number", "boolean"].includes(typeof v)) out[k] = v;
  }
  return out;
}

async function profile(id: string) {
  const { data } = await db.from("profiles").select("id, display_name, avatar, is_guest").eq("id", id).maybeSingle();
  return data ?? { id, display_name: "Player", avatar: {}, is_guest: false };
}

async function newGame(seat0: string, seat1: string, via: string) {
  const [p0, p1] = await Promise.all([profile(seat0), profile(seat1)]);
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  const first = seed % 2; // the coin flip
  const g = Game.create([p0.display_name, p1.display_name], seed, first, 3);
  const state = { ...g.s, via, first };
  const { data, error } = await db.from("games")
    .insert({ seat0, seat1, state, current_seat: g.s.current, winner: g.s.winner })
    .select("id").single();
  if (error) throw new Oops(error.message, 500);
  return data.id as string;
}

async function loadGame(gameId: string, me: string) {
  const { data: row } = await db.from("games").select("*").eq("id", gameId).maybeSingle();
  if (!row) throw new Oops("Game not found.", 404);
  const seat = row.seat0 === me ? 0 : row.seat1 === me ? 1 : -1;
  if (seat < 0) throw new Oops("That's not your game.", 403);
  return { row, seat, game: new Game(row.state) };
}

async function gameView(row: Record<string, any>, seat: number, game: Game, sinceSeq: number) {
  const oppId = seat === 0 ? row.seat1 : row.seat0;
  const opp = oppId ? await profile(oppId) : { display_name: "Former player", avatar: {} };
  const { data: moves } = await db.from("game_moves")
    .select("seq, seat, move, view0, view1").eq("game_id", row.id).gt("seq", sinceSeq).order("seq");
  return {
    game_id: row.id,
    status: row.status,
    move_count: row.move_count,
    first: row.state.first === seat ? 0 : 1,
    opponent: { name: opp.display_name, avatar: opp.avatar },
    view: game.view(seat),
    // Each later move, as this seat saw the table right after it (powers the turn replay).
    moves: (moves ?? []).map((m) => ({ seq: m.seq, mine: m.seat === seat, view: seat === 0 ? m.view0 : m.view1 })),
  };
}

// ------------------------------------------------------------------ actions

type Ctx = { me: string; body: Record<string, any> };

const actions: Record<string, (c: Ctx) => Promise<unknown>> = {
  async me({ me }) {
    return { profile: await profile(me) };
  },

  async update_profile({ me, body }) {
    const patch: Record<string, unknown> = {};
    if (body.display_name !== undefined) patch.display_name = cleanName(body.display_name);
    if (body.avatar !== undefined) patch.avatar = cleanAvatar(body.avatar);
    await db.from("profiles").update(patch).eq("id", me);
    return { profile: await profile(me) };
  },

  // ---- invites: host makes a code, guest enters it with a first name, host confirms.
  async create_invite({ me }) {
    for (let i = 0; i < 5; i++) {
      const code = newCode();
      const { error } = await db.from("invites").insert({ code, host: me });
      if (!error) return { code };
    }
    throw new Oops("Couldn't make a code. Try again.", 500);
  },

  async join_invite({ me, body }) {
    const code = String(body.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const name = cleanName(body.name);
    const { data: inv } = await db.from("invites").select("*").eq("code", code).maybeSingle();
    if (!inv || new Date(inv.expires_at) < new Date()) throw new Oops("That code doesn't work. Check it and try again.", 404);
    if (inv.host === me) throw new Oops("That's your own invite code.");
    if (inv.status !== "open" && !(inv.status === "pending" && inv.guest === me)) throw new Oops("Someone already used that code.");
    await db.from("invites").update({ guest: me, guest_name: name, status: "pending" }).eq("code", code);
    const p = await profile(me);
    if (p.is_guest || p.display_name === "Player") await db.from("profiles").update({ display_name: name }).eq("id", me);
    const host = await profile(inv.host);
    return { status: "pending", host_name: host.display_name };
  },

  async invite_status({ me, body }) {
    const { data: inv } = await db.from("invites").select("*").eq("code", String(body.code ?? "").toUpperCase()).maybeSingle();
    if (!inv || (inv.host !== me && inv.guest !== me)) throw new Oops("Invite not found.", 404);
    return { status: inv.status, guest_name: inv.guest_name, game_id: inv.game_id, i_am_host: inv.host === me };
  },

  async respond_invite({ me, body }) {
    const code = String(body.code ?? "").toUpperCase();
    const { data: inv } = await db.from("invites").select("*").eq("code", code).maybeSingle();
    if (!inv || inv.host !== me) throw new Oops("Invite not found.", 404);
    if (inv.status !== "pending") throw new Oops("Nobody is waiting on that code yet.");
    if (!body.accept) {
      // Turned down: the code opens up again for someone else.
      await db.from("invites").update({ status: "open", guest: null, guest_name: null }).eq("code", code);
      return { status: "open" };
    }
    const gameId = await newGame(inv.host, inv.guest, "invite");
    await db.from("invites").update({ status: "accepted", game_id: gameId }).eq("code", code);
    return { status: "accepted", game_id: gameId };
  },

  async cancel_invite({ me, body }) {
    await db.from("invites").update({ status: "expired" }).eq("code", String(body.code ?? "").toUpperCase()).eq("host", me);
    return { ok: true };
  },

  // ---- strangers
  async find_match({ me }) {
    const { data: other, error } = await db.rpc("take_match", { me });
    if (error) throw new Oops(error.message, 500);
    if (!other) return { waiting: true };
    return { game_id: await newGame(other as string, me, "match") };
  },

  async match_status({ me }) {
    const { data: q } = await db.from("match_queue").select("user_id").eq("user_id", me).maybeSingle();
    if (q) return { waiting: true };
    const since = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { data } = await db.from("games").select("id")
      .or(`seat0.eq.${me},seat1.eq.${me}`).eq("state->>via", "match").eq("move_count", 0)
      .gt("created_at", since).order("created_at", { ascending: false }).limit(1);
    return data?.length ? { game_id: data[0].id } : { waiting: false };
  },

  async cancel_match({ me }) {
    await db.from("match_queue").delete().eq("user_id", me);
    return { ok: true };
  },

  // ---- games
  async my_games({ me }) {
    const { data } = await db.from("games").select("id, seat0, seat1, status, current_seat, winner, updated_at")
      .or(`seat0.eq.${me},seat1.eq.${me}`).order("updated_at", { ascending: false }).limit(30);
    const out = [];
    for (const r of data ?? []) {
      const seat = r.seat0 === me ? 0 : 1;
      const oppId = seat === 0 ? r.seat1 : r.seat0;
      const opp = oppId ? await profile(oppId) : { display_name: "Former player" };
      out.push({
        game_id: r.id, opponent: opp.display_name, status: r.status,
        my_turn: r.status === "active" && r.current_seat === seat,
        won: r.winner < 0 ? null : r.winner === seat, updated_at: r.updated_at,
      });
    }
    return { games: out };
  },

  async state({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    return gameView(row, seat, game, Number(body.since_seq ?? 0));
  },

  async act({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    if (row.status !== "active") throw new Oops("This game is over.");
    if (game.s.current !== seat) throw new Oops("It's not your turn.", 409);
    const move = body.move as Move;
    const evBefore = game.s.events.length;
    if (!move || !game.apply(move)) throw new Oops("That move isn't allowed right now.", 409);
    const seq = row.move_count + 1;
    const status = game.s.winner >= 0 ? "finished" : "active";
    // Only save if nobody else changed the game since we loaded it.
    const { data: saved } = await db.from("games")
      .update({ state: { ...game.s, via: row.state.via, first: row.state.first }, current_seat: game.s.current, winner: game.s.winner, move_count: seq, status, updated_at: new Date().toISOString() })
      .eq("id", row.id).eq("move_count", row.move_count).select("id");
    if (!saved?.length) throw new Oops("The game changed. Refreshing.", 409);
    await db.from("game_moves").insert({ game_id: row.id, seq, seat, move, view0: game.view(0, evBefore), view1: game.view(1, evBefore) });
    row.move_count = seq;
    row.status = status;
    return gameView(row, seat, game, seq);
  },

  async resign({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    if (row.status !== "active") return { ok: true };
    game.s.winner = 1 - seat;
    game.ev(seat, (v) => `${game.nm(seat, v)} ${seat === v ? "leave" : "left"} the game.`, "", -1, true);
    await db.from("games").update({ state: { ...game.s, via: row.state.via, first: row.state.first }, winner: 1 - seat, status: "finished", updated_at: new Date().toISOString() }).eq("id", row.id);
    return { ok: true };
  },

  // ---- account deletion (App Store guideline 5.1.1(v))
  async delete_account({ me }) {
    // Games stay for the other player; this seat just becomes "Former player".
    const { error } = await db.auth.admin.deleteUser(me);
    if (error) throw new Oops("Couldn't delete the account: " + error.message, 500);
    return { deleted: true };
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: auth, error } = await db.auth.getUser(token);
    if (error || !auth?.user) throw new Oops("Please sign in again.", 401);
    const body = await req.json().catch(() => ({}));
    const fn = actions[body.action];
    if (!fn) throw new Oops("Unknown action.");
    return json(await fn({ me: auth.user.id, body }));
  } catch (e) {
    if (e instanceof Oops) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong on the server." }, 500);
  }
});
