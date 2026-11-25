// War and Piece server: every online action goes through here (modeled on gem-heist).
// Players never read the tables directly; this function hands each seat only what that
// seat may see (Game.view in engine.ts: face-down stocks and the other hand stay hidden).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { Game, type Move } from "./engine.ts";
import { validNickname } from "./kid.ts";

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

function cleanName(raw: unknown): string {
  const s = String(raw ?? "").replace(/[^\p{L}' -]/gu, "").replace(/\s+/g, " ").trim().slice(0, 16);
  if (!s) throw new Oops("Please enter a first name.");
  return s;
}

// Players under 13 (kid accounts) can only use a nickname from our list, never typed text.
async function nameFor(me: string, raw: unknown): Promise<string> {
  const p = await profile(me);
  if (!p.kid) return cleanName(raw);
  if (!validNickname(raw)) throw new Oops("Please pick a nickname from the list.");
  return String(raw);
}

async function profile(id: string) {
  const { data } = await db.from("profiles").select("id, display_name, avatar, is_guest, kid").eq("id", id).maybeSingle();
  return data ?? { id, display_name: "Player", avatar: {}, is_guest: false, kid: false };
}

// Who can move: 2 = either player (War, or both still arranging), 0/1 = that seat, -1 = over.
function turnSeat(g: Game): number {
  const ph = g.phase();
  if (ph === "over") return -1;
  if (ph === "war") return 2;
  if (g.pieceActor() >= 0) return g.pieceActor();
  const d = g.s.piece_done;
  return d[0] && !d[1] ? 1 : d[1] && !d[0] ? 0 : 2;
}
const myTurn = (status: string, current: number, seat: number) => status === "active" && (current === 2 || current === seat);

async function newGame(seat0: string, seat1: string, via: string) {
  const [p0, p1] = await Promise.all([profile(seat0), profile(seat1)]);
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  const g = Game.create([p0.display_name, p1.display_name], seed);
  const { data, error } = await db.from("wp_games")
    .insert({ seat0, seat1, state: g.s, current_seat: turnSeat(g), winner: g.s.winner, via })
    .select("id").single();
  if (error) throw new Oops(error.message, 500);
  return data.id as string;
}

async function loadGame(gameId: unknown, me: string) {
  const { data: row } = await db.from("wp_games").select("*").eq("id", String(gameId ?? "")).maybeSingle();
  if (!row) throw new Oops("Game not found.", 404);
  const seat = row.seat0 === me ? 0 : row.seat1 === me ? 1 : -1;
  if (seat < 0) throw new Oops("That's not your game.", 403);
  return { row, seat, game: new Game(row.state) };
}

async function gameView(row: Record<string, any>, seat: number, game: Game) {
  const oppId = seat === 0 ? row.seat1 : row.seat0;
  const opp = oppId ? await profile(oppId) : { display_name: "Former player", avatar: {} };
  return {
    game_id: row.id,
    status: row.status,
    move_count: row.move_count,
    my_turn: myTurn(row.status, turnSeat(game), seat),
    opponent: { name: opp.display_name },
    view: game.view(seat),
  };
}

type Ctx = { me: string; body: Record<string, any> };

const actions: Record<string, (c: Ctx) => Promise<unknown>> = {
  async me({ me }) {
    return { profile: await profile(me) };
  },

  async update_profile({ me, body }) {
    if (body.display_name !== undefined) await db.from("profiles").update({ display_name: await nameFor(me, body.display_name) }).eq("id", me);
    return { profile: await profile(me) };
  },

  // ---- invites: host makes a code, guest enters it with a first name, host confirms.
  async create_invite({ me }) {
    for (let i = 0; i < 5; i++) {
      const code = newCode();
      const { error } = await db.from("wp_invites").insert({ code, host: me });
      if (!error) return { code };
    }
    throw new Oops("Couldn't make a code. Try again.", 500);
  },

  async join_invite({ me, body }) {
    const code = String(body.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const name = await nameFor(me, body.name);
    const { data: inv } = await db.from("wp_invites").select("*").eq("code", code).maybeSingle();
    if (!inv || new Date(inv.expires_at) < new Date()) throw new Oops("That code doesn't work. Check it and try again.", 404);
    if (inv.host === me) throw new Oops("That's your own invite code.");
    if (inv.status !== "open" && !(inv.status === "pending" && inv.guest === me)) throw new Oops("Someone already used that code.");
    await db.from("wp_invites").update({ guest: me, guest_name: name, status: "pending" }).eq("code", code);
    const p = await profile(me);
    if (p.is_guest || p.display_name === "Player") await db.from("profiles").update({ display_name: name }).eq("id", me);
    const host = await profile(inv.host);
    return { status: "pending", host_name: host.display_name };
  },

  async invite_status({ me, body }) {
    const { data: inv } = await db.from("wp_invites").select("*").eq("code", String(body.code ?? "").toUpperCase()).maybeSingle();
    if (!inv || (inv.host !== me && inv.guest !== me)) throw new Oops("Invite not found.", 404);
    return { status: inv.status, guest_name: inv.guest_name, game_id: inv.game_id, i_am_host: inv.host === me };
  },

  async respond_invite({ me, body }) {
    const code = String(body.code ?? "").toUpperCase();
    const { data: inv } = await db.from("wp_invites").select("*").eq("code", code).maybeSingle();
    if (!inv || inv.host !== me) throw new Oops("Invite not found.", 404);
    if (inv.status !== "pending") throw new Oops("Nobody is waiting on that code yet.");
    if (!body.accept) {
      await db.from("wp_invites").update({ status: "open", guest: null, guest_name: null }).eq("code", code);
      return { status: "open" };
    }
    const gameId = await newGame(inv.host, inv.guest, "invite");
    await db.from("wp_invites").update({ status: "accepted", game_id: gameId }).eq("code", code);
    return { status: "accepted", game_id: gameId };
  },

  async cancel_invite({ me, body }) {
    await db.from("wp_invites").update({ status: "expired" }).eq("code", String(body.code ?? "").toUpperCase()).eq("host", me);
    return { ok: true };
  },

  // ---- strangers
  async find_match({ me }) {
    // Players under 13 only play friends they invite (or who invite them), never strangers.
    if ((await profile(me)).kid) throw new Oops("Finding a player isn't available on this account. Invite a friend instead.", 403);
    const { data: other, error } = await db.rpc("take_wp_match", { me });
    if (error) throw new Oops(error.message, 500);
    if (!other) return { waiting: true };
    return { game_id: await newGame(other as string, me, "match") };
  },

  async match_status({ me }) {
    const { data: q } = await db.from("wp_match_queue").select("user_id").eq("user_id", me).maybeSingle();
    if (q) return { waiting: true };
    const since = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { data } = await db.from("wp_games").select("id")
      .or(`seat0.eq.${me},seat1.eq.${me}`).eq("via", "match").eq("move_count", 0)
      .gt("created_at", since).order("created_at", { ascending: false }).limit(1);
    return data?.length ? { game_id: data[0].id } : { waiting: false };
  },

  async cancel_match({ me }) {
    await db.from("wp_match_queue").delete().eq("user_id", me);
    return { ok: true };
  },

  // ---- games
  async my_games({ me }) {
    const { data } = await db.from("wp_games").select("id, seat0, seat1, status, current_seat, winner, state, updated_at")
      .or(`seat0.eq.${me},seat1.eq.${me}`).order("updated_at", { ascending: false }).limit(30);
    const out = [];
    for (const r of data ?? []) {
      const seat = r.seat0 === me ? 0 : 1;
      const oppId = seat === 0 ? r.seat1 : r.seat0;
      const opp = oppId ? await profile(oppId) : { display_name: "Former player" };
      const g = new Game(r.state);
      out.push({
        game_id: r.id, opponent: opp.display_name, status: r.status,
        my_turn: myTurn(r.status, turnSeat(g), seat),
        round: g.s.round, phase: g.phase(),
        locked: [g.lockedCount(seat), g.lockedCount(1 - seat)],
        banked_sets: [g.sets(seat).length, g.sets(1 - seat).length],
        won: r.winner < 0 ? null : r.winner === 2 ? "draw" : r.winner === seat,
        updated_at: r.updated_at,
      });
    }
    return { games: out };
  },

  async state({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    return gameView(row, seat, game);
  },

  async act({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    if (row.status !== "active") throw new Oops("This game is over.");
    const raw = (body.move ?? {}) as Move;
    const t = String(raw.t ?? "");
    let move: Move;
    if (t === "flip" || t === "flip_all") move = { t };
    else if (t === "heist") move = { t, p: seat, rank: raw.rank, suit: raw.suit };
    else if (t === "defend") move = { t, p: seat, block: raw.block };
    else if (t === "pass") move = { t, p: seat };
    else if (t === "lock" || t === "add" || t === "done") move = { t, p: seat, ids: raw.ids, set: raw.set };   // you only ever move for yourself
    else throw new Oops("That move isn't allowed right now.", 409);
    if (t === "done" || t === "lock" || t === "add") { if (move.ids === undefined) delete move.ids; if (move.set === undefined) delete move.set; }
    if (!game.apply(move)) throw new Oops("That move isn't allowed right now.", 409);
    const seq = row.move_count + 1;
    const status = game.s.winner >= 0 ? "finished" : "active";
    const current = turnSeat(game);
    // Only save if nobody else changed the game since we loaded it.
    const { data: saved } = await db.from("wp_games")
      .update({ state: game.s, current_seat: current, winner: game.s.winner, move_count: seq, status, updated_at: new Date().toISOString() })
      .eq("id", row.id).eq("move_count", row.move_count).select("id");
    if (!saved?.length) throw new Oops("The game changed. Refreshing.", 409);
    await db.from("wp_moves").insert({ game_id: row.id, seq, seat, move });
    Object.assign(row, { move_count: seq, status, current_seat: current, winner: game.s.winner });
    return gameView(row, seat, game);
  },

  async resign({ me, body }) {
    const { row, seat, game } = await loadGame(body.game_id, me);
    if (row.status !== "active") return { ok: true };
    game.resign(seat);
    await db.from("wp_games").update({ state: game.s, winner: game.s.winner, current_seat: -1, status: "finished", updated_at: new Date().toISOString() }).eq("id", row.id);
    return { ok: true };
  },

  // ---- account deletion (App Store guideline 5.1.1(v)); the account is shared with Gem Heist.
  async delete_account({ me }) {
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
