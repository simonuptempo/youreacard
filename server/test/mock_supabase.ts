// A tiny in-memory stand-in for Supabase (database + auth), so the real gem-heist function
// and the real Godot client can be tested together without network access.
import http from "node:http";

type Row = Record<string, any>;
export const tables: Record<string, Row[]> = { profiles: [], games: [], game_moves: [], invites: [], match_queue: [], users: [] };

function getPath(row: Row, col: string) {
  const m = col.match(/^(\w+)->>(\w+)$/);
  if (m) return row[m[1]]?.[m[2]] !== undefined ? String(row[m[1]][m[2]]) : undefined;
  return row[col];
}

class Query {
  filters: ((r: Row) => boolean)[] = [];
  op: "select" | "insert" | "update" | "delete" = "select";
  payload: any = null;
  orderCol = ""; asc = true; lim = 0; wantSingle = 0; returning = false;
  table: string;
  constructor(table: string) { this.table = table; }
  select(_cols?: string) { if (this.op !== "select") this.returning = true; return this; }
  insert(p: any) { this.op = "insert"; this.payload = p; return this; }
  update(p: any) { this.op = "update"; this.payload = p; return this; }
  delete() { this.op = "delete"; return this; }
  eq(c: string, v: any) { this.filters.push((r) => getPath(r, c) == v); return this; }
  gt(c: string, v: any) { this.filters.push((r) => getPath(r, c) > v); return this; }
  in(c: string, vs: any[]) { this.filters.push((r) => vs.includes(r[c])); return this; }
  or(expr: string) {
    const parts = expr.split(",").map((p) => p.split(".eq."));
    this.filters.push((r) => parts.some(([c, v]) => String(r[c]) === v));
    return this;
  }
  order(c: string, o?: { ascending: boolean }) { this.orderCol = c; this.asc = o?.ascending ?? true; return this; }
  limit(n: number) { this.lim = n; return this; }
  maybeSingle() { this.wantSingle = 1; return this; }
  single() { this.wantSingle = 2; return this; }
  then(res: (v: any) => void, rej?: (e: any) => void) {
    try { res(this.run()); } catch (e) { rej?.(e); }
  }
  run() {
    const t = tables[this.table];
    const clone = (x: any) => JSON.parse(JSON.stringify(x));
    if (this.op === "insert") {
      const rows = (Array.isArray(this.payload) ? this.payload : [this.payload]).map((p: Row) => ({ ...defaults(this.table), ...clone(p) }));
      for (const r of rows) {
        const pk = this.table === "invites" ? "code" : this.table === "match_queue" ? "user_id" : "id";
        if (this.table !== "game_moves" && t.some((x) => x[pk] === r[pk])) return { data: null, error: { message: "duplicate key" } };
        t.push(r);
      }
      const data = this.returning ? clone(rows) : null;
      return { data: this.wantSingle ? data?.[0] ?? null : data, error: null };
    }
    let rows = t.filter((r) => this.filters.every((f) => f(r)));
    if (this.op === "update") { for (const r of rows) Object.assign(r, clone(this.payload)); }
    if (this.op === "delete") { tables[this.table] = t.filter((r) => !rows.includes(r)); }
    if (this.orderCol) rows = [...rows].sort((a, b) => (a[this.orderCol] > b[this.orderCol] ? 1 : -1) * (this.asc ? 1 : -1));
    if (this.lim) rows = rows.slice(0, this.lim);
    const data = clone(rows);
    if (this.op !== "select" && !this.returning) return { data: null, error: null };
    if (this.wantSingle) return { data: data[0] ?? null, error: this.wantSingle === 2 && !data[0] ? { message: "no rows" } : null };
    return { data, error: null };
  }
}

let seq = 0;
function defaults(table: string): Row {
  const now = new Date(Date.now() + seq++).toISOString();
  if (table === "games") return { id: crypto.randomUUID(), game_type: "gem_heist", status: "active", current_seat: 0, winner: -1, move_count: 0, created_at: now, updated_at: now };
  if (table === "invites") return { status: "open", guest: null, guest_name: null, game_id: null, created_at: now, expires_at: new Date(Date.now() + 7 * 864e5).toISOString() };
  if (table === "match_queue") return { joined_at: now };
  return { created_at: now };
}

export const mockClient = {
  from: (t: string) => new Query(t),
  async rpc(name: string, args: any) {
    if (name !== "take_match") return { data: null, error: { message: "no rpc" } };
    const q = tables.match_queue.filter((r) => r.user_id !== args.me).sort((a, b) => (a.joined_at > b.joined_at ? 1 : -1));
    if (!q.length) {
      if (!tables.match_queue.some((r) => r.user_id === args.me)) tables.match_queue.push({ user_id: args.me, joined_at: new Date().toISOString() });
      return { data: null, error: null };
    }
    const other = q[0].user_id;
    tables.match_queue = tables.match_queue.filter((r) => r.user_id !== args.me && r.user_id !== other);
    return { data: other, error: null };
  },
  auth: {
    async getUser(token: string) {
      const u = tables.users.find((x) => x.token === token);
      return u ? { data: { user: { id: u.id } }, error: null } : { data: { user: null }, error: { message: "bad token" } };
    },
    admin: {
      async deleteUser(id: string) {
        tables.users = tables.users.filter((u) => u.id !== id);
        tables.profiles = tables.profiles.filter((p) => p.id !== id);
        tables.invites = tables.invites.filter((i) => i.host !== id && i.guest !== id);
        tables.match_queue = tables.match_queue.filter((q) => q.user_id !== id);
        for (const g of tables.games) { if (g.seat0 === id) g.seat0 = null; if (g.seat1 === id) g.seat1 = null; }
        return { error: null };
      },
    },
  },
};

// ---- the HTTP side: Supabase Auth endpoints + the function, as the Godot client calls them
function makeUser(meta: any, email?: string, password?: string) {
  const id = crypto.randomUUID();
  const u = { id, token: "tok-" + id, refresh: "ref-" + id, email: email ?? null, password, is_anonymous: !email };
  tables.users.push(u);
  const name = String(meta?.display_name || "Player").slice(0, 24);
  tables.profiles.push({ id, display_name: name, avatar: {}, is_guest: !email, beaten: [] });
  return u;
}
const session = (u: any) => ({ access_token: u.token, refresh_token: u.refresh, expires_in: 3600, user: { id: u.id, email: u.email, is_anonymous: u.is_anonymous } });

export function serve(handler: (req: Request) => Promise<Response>, port: number) {
  const server = http.createServer(async (req, res) => {
    const chunks: Buffer[] = [];
    for await (const c of req) chunks.push(c as Buffer);
    const bodyText = Buffer.concat(chunks).toString();
    const url = new URL(req.url!, `http://127.0.0.1:${port}`);
    const send = (status: number, obj: any) => { res.writeHead(status, { "Content-Type": "application/json" }); res.end(JSON.stringify(obj)); };
    try {
      if (url.pathname === "/auth/v1/signup") {
        const b = bodyText ? JSON.parse(bodyText) : {};
        if (b.email && tables.users.some((u) => u.email === b.email)) return send(422, { msg: "User already registered" });
        return send(200, session(makeUser(b.data, b.email, b.password)));
      }
      if (url.pathname === "/auth/v1/token") {
        const b = JSON.parse(bodyText || "{}");
        const gt = url.searchParams.get("grant_type");
        const u = gt === "password" ? tables.users.find((x) => x.email === b.email && x.password === b.password)
          : tables.users.find((x) => x.refresh === b.refresh_token);
        return u ? send(200, session(u)) : send(400, { error_description: "Invalid login credentials" });
      }
      if (url.pathname === "/auth/v1/logout") return send(204, {});
      if (url.pathname === "/functions/v1/gem-heist") {
        const r = await handler(new Request(url, { method: "POST", headers: req.headers as any, body: bodyText }));
        res.writeHead(r.status, { "Content-Type": "application/json" });
        return res.end(await r.text());
      }
      send(404, { error: "not found" });
    } catch (e) {
      console.error(e);
      send(500, { error: String(e) });
    }
  });
  server.listen(port, "127.0.0.1");
  return server;
}
