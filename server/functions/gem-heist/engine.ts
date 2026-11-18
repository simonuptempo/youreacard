// Gem Heist rules engine: a direct port of scripts/game_state.gd + scripts/cards.gd.
// The server is the only place a real online game is played, so hidden cards stay hidden.
// Every event carries its text twice: t[0] worded for seat 0, t[1] for seat 1
// ("You paid 2 bills" vs "Juno paid 2 bills").

export type Card = { id: number; kind: string; face?: number };
export type Player = {
  name: string;
  hand: Card[];
  collection: Record<string, Card[]>;
  vault: (Card | null)[];
  bank: Card[];
};
export type Ev = { p: number; t: [string, string]; card: string; face: number; big: boolean; turn: number; kept?: string };
export type State = {
  deck: Card[];
  discard: Card[];
  players: Player[];
  current: number;
  plays_left: number;
  plays_per_turn: number;
  winner: number;
  turn_number: number;
  counter_owed: boolean[];
  owes: number[];
  events: Ev[];
  rng: number;
};
export type Move = Record<string, unknown>;

// ------------------------------------------------------------------ cards

export const COLORS = ["ruby", "emerald", "sapphire", "topaz", "diamond", "amethyst"];
export const TREASURES: Record<string, { name: string; one: string; size: number; count: number }> = {
  ruby: { name: "Rubies", one: "Ruby", size: 2, count: 4 },
  emerald: { name: "Emeralds", one: "Emerald", size: 3, count: 5 },
  sapphire: { name: "Sapphires", one: "Sapphire", size: 3, count: 5 },
  topaz: { name: "Topazes", one: "Topaz", size: 3, count: 5 },
  diamond: { name: "Diamonds", one: "Diamond", size: 3, count: 5 },
  amethyst: { name: "Amethysts", one: "Amethyst", size: 3, count: 5 },
};
// Same order as cards.gd ACTIONS, so card ids match the Godot build.
export const ACTIONS: [string, string, string, number][] = [
  ["wild", "Wild", "wild", 2],
  ["swipe", "Heist", "heist", 7],
  ["swap", "Trade", "heist", 4],
  ["shakedown", "Shakedown", "heist", 4],
  ["grand", "Grand Heist", "heist", 2],
  ["payup", "Pay Up!", "heist", 4],
  ["shield", "Shield", "trap", 5],
  ["mirror", "Mirror", "trap", 3],
  ["snare", "Snare", "trap", 2],
  ["lockpick", "Lockpick", "tool", 4],
  ["lucky", "Lucky Break", "tool", 4],
  ["loot1", "1 Bill", "money", 6],
  ["loot2", "2 Bills", "money", 5],
  ["loot3", "3 Bills", "money", 4],
  ["loot4", "4 Bills", "money", 3],
  ["loot5", "5 Bills", "money", 2],
];
const ACTION_NAME: Record<string, string> = Object.fromEntries(ACTIONS.map((a) => [a[0], a[1]]));
const COSTS: Record<string, number> = { swipe: 2, swap: 1, shakedown: 1, grand: 5, lockpick: 2 };
export const HEISTS = ["swipe", "swap", "shakedown", "grand", "payup"];
export const TRAPS = ["shield", "mirror", "snare"];
const PAWN: Record<string, number> = { ruby: 2, diamond: 2 };

export const HAND_LIMIT = 7;
export const SETS_TO_WIN = 4;
const DRAW_PER_TURN = 2;
const EXTRA_GEM_PAY = [2, 3];
const PAY_UP_AMOUNT = 2;
const START_HAND = 5;

export const isTreasure = (k: string) => k in TREASURES;
export const isMoney = (k: string) => /^loot[1-5]$/.test(k);
export const displayName = (k: string) => (isTreasure(k) ? TREASURES[k].name : ACTION_NAME[k] ?? k);
const oneName = (c: string) => TREASURES[c].one;
export const bills = (n: number) => `${n} bill${n === 1 ? "" : "s"}`;
export const pawnValue = (k: string) => (isTreasure(k) ? PAWN[k] ?? 1 : 0);
export const value = (k: string) => (isMoney(k) ? Number(k.substring(4)) : pawnValue(k));
export const cost = (k: string) => COSTS[k] ?? 0;
export const setSize = (c: string) => TREASURES[c].size;
const aAn = (w: string) => ("aeiou".includes(w[0].toLowerCase()) ? "an " : "a ") + w;
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
function ordinal(n: number): string {
  return n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`;
}
const extraGemPay = (i: number) => EXTRA_GEM_PAY[Math.max(0, Math.min(i - 1, EXTRA_GEM_PAY.length - 1))];

export function buildDeck(): Card[] {
  const deck: Card[] = [];
  let id = 1;
  for (const c of COLORS) for (let i = 0; i < TREASURES[c].count; i++) deck.push({ id: id++, kind: c });
  for (const [k, , , n] of ACTIONS) for (let i = 0; i < n; i++) deck.push({ id: id++, kind: k });
  return deck;
}

// ------------------------------------------------------------------ engine

export class Game {
  s: State;
  constructor(s: State) {
    this.s = s;
  }

  static create(names: [string, string], seed: number, first: number, plays = 3): Game {
    const coll = () => Object.fromEntries(COLORS.map((c) => [c, [] as Card[]]));
    const g = new Game({
      deck: buildDeck(), discard: [], current: first, plays_left: 0, plays_per_turn: plays, winner: -1,
      turn_number: 0, counter_owed: [false, false], owes: [0, 0], events: [], rng: seed >>> 0 || 1,
      players: names.map((n) => ({ name: n, hand: [], collection: coll(), vault: [null, null], bank: [] })),
    });
    g.shuffle(g.s.deck);
    for (let i = 0; i < START_HAND; i++) for (let p = 0; p < 2; p++) g.drawOne(p);
    g.startTurn(true);
    return g;
  }

  // ---- random (mulberry32, state kept in the saved game)
  rand(): number {
    let t = (this.s.rng = (this.s.rng + 0x6d2b79f5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  randInt(lo: number, hi: number) {
    return lo + Math.floor(this.rand() * (hi - lo + 1));
  }
  shuffle(a: Card[]) {
    for (let i = a.length - 1; i > 0; i--) {
      const j = this.randInt(0, i);
      [a[i], a[j]] = [a[j], a[i]];
    }
  }

  // ---- helpers
  opp = (p: number) => 1 - p;
  hand = (p: number) => this.s.players[p].hand;
  bank = (p: number) => this.s.players[p].bank;
  vault = (p: number) => this.s.players[p].vault;
  setCards = (p: number, c: string) => this.s.players[p].collection[c];
  bankTotal = (p: number) => this.bank(p).reduce((t, c) => t + value(c.kind), 0);
  lootSum = (cards: Card[]) => cards.reduce((t, c) => t + value(c.kind), 0);

  isComplete(p: number, color: string): boolean {
    const cards = this.setCards(p, color);
    if (cards.length < setSize(color)) return false;
    return cards.some((c) => c.kind !== "wild");
  }
  completeCount = (p: number) => COLORS.filter((c) => this.isComplete(p, c)).length;
  vaultCount = (p: number) => this.vault(p).filter((c) => c !== null).length;
  totalCards(): number {
    let n = this.s.deck.length + this.s.discard.length;
    for (let p = 0; p < 2; p++) {
      n += this.hand(p).length + this.vaultCount(p) + this.bank(p).length;
      for (const c of COLORS) n += this.setCards(p, c).length;
    }
    return n;
  }
  findHandCard = (p: number, id: number) => this.hand(p).find((c) => c.id === id);
  removeFromHand(p: number, id: number): Card {
    const h = this.hand(p);
    const i = h.findIndex((c) => c.id === id);
    return h.splice(i, 1)[0];
  }
  removeFromCollection(p: number, id: number): [string, Card] | null {
    for (const color of COLORS) {
      const cards = this.setCards(p, color);
      const i = cards.findIndex((c) => c.id === id);
      if (i >= 0) return [color, cards.splice(i, 1)[0]];
    }
    return null;
  }
  findCollectionCard(p: number, id: number): [string, Card] | null {
    for (const color of COLORS) {
      const c = this.setCards(p, color).find((x) => x.id === id);
      if (c) return [color, c];
    }
    return null;
  }

  drawOne(p: number): boolean {
    if (this.s.deck.length === 0) {
      if (this.s.discard.length === 0) return false;
      this.s.deck = this.s.discard;
      this.s.discard = [];
      this.shuffle(this.s.deck);
      this.ev(p, () => "The discard pile was shuffled into a new deck.", "", -1, false);
    }
    this.hand(p).push(this.s.deck.pop()!);
    return true;
  }
  draw(p: number, n: number) {
    let got = 0;
    for (let i = 0; i < n; i++) if (this.drawOne(p)) got++;
    return got;
  }

  // ---- text: every sentence is built once per viewer
  nm = (p: number, v: number) => (p === v ? "You" : this.s.players[p].name);
  poss = (p: number, v: number) => (p === v ? "your" : this.s.players[p].name + "'s");
  // verb agreement: "You owe" / "Juno owes"
  vb = (p: number, v: number, you: string, they: string) => (p === v ? you : they);
  ev(p: number, text: (v: number) => string, card: string, face: number, big: boolean) {
    this.s.events.push({ p, t: [text(0), text(1)], card, face, big, turn: this.s.turn_number });
    return this.s.events[this.s.events.length - 1];
  }

  // ---- payments
  pay(p: number, amount: number): Card[] {
    const b = this.bank(p);
    if (amount <= 0 || b.length === 0) return [];
    if (this.bankTotal(p) <= amount) return b.splice(0, b.length);
    const n = Math.min(b.length, 12);
    let bestMask = -1, bestSum = 1 << 30, bestCount = 99;
    for (let m = 1; m < 1 << n; m++) {
      let sm = 0, cnt = 0;
      for (let i = 0; i < n; i++) if (m & (1 << i)) { sm += value(b[i].kind); cnt++; }
      if (sm >= amount && (sm < bestSum || (sm === bestSum && cnt < bestCount))) {
        bestSum = sm; bestMask = m; bestCount = cnt;
      }
    }
    const paid: Card[] = [];
    if (bestMask < 0) return paid;
    for (let i = n - 1; i >= 0; i--) if (bestMask & (1 << i)) paid.push(b.splice(i, 1)[0]);
    return paid;
  }

  exactSubset(pool: Card[], target: number): Card[] {
    if (target <= 0) return [];
    const n = Math.min(pool.length, 12);
    let best = -1, bestCount = 99;
    for (let m = 1; m < 1 << n; m++) {
      let sm = 0, cnt = 0;
      for (let i = 0; i < n; i++) if (m & (1 << i)) { sm += value(pool[i].kind); cnt++; }
      if (sm === target && cnt < bestCount) { best = m; bestCount = cnt; }
    }
    const out: Card[] = [];
    if (best >= 0) for (let i = 0; i < n; i++) if (best & (1 << i)) out.push(pool[i]);
    return out;
  }

  private moveChange(payer: number, payee: number, over: number): Card[] {
    const change = this.exactSubset(this.bank(payee), over);
    for (const c of change) this.bank(payee).splice(this.bank(payee).indexOf(c), 1);
    this.bank(payer).push(...change);
    return change;
  }

  // Returns the sentence (per viewer) describing the payment.
  transfer(payer: number, payee: number, amount: number): (v: number) => string {
    const got = this.pay(payer, amount);
    let sum = this.lootSum(got);
    let change: Card[] = [];
    if (sum > amount) change = this.moveChange(payer, payee, sum - amount);
    this.bank(payee).push(...got);
    const gems: string[] = [];
    let gemSum = 0;
    while (sum + gemSum < amount) {
      const pick = this.gemForPayment(payer, payee);
      if (!pick) break;
      const removed = this.removeFromCollection(payer, pick.id)!;
      this.receive(payee, removed[1], removed[0]);
      gems.push(removed[0]);
      gemSum += pawnValue(removed[0]);
    }
    let change2: Card[] = [];
    if (gemSum > 0 && sum + gemSum > amount && change.length === 0) {
      change2 = this.moveChange(payer, payee, sum + gemSum - amount);
    }
    const paidSum = sum;
    sum += gemSum;
    let short = amount - sum;
    let owedNow = 0;
    if (short > 0) {
      const cancel = Math.min(short, this.s.owes[payee]);
      this.s.owes[payee] -= cancel;
      short -= cancel;
      this.s.owes[payer] += short;
      owedNow = short;
    }
    const counts: Record<string, number> = {};
    for (const k of gems) counts[k] = (counts[k] ?? 0) + 1;
    const names = Object.keys(counts).map((k) => (counts[k] === 1 ? aAn(oneName(k)) : `${counts[k]} ${displayName(k)}`));
    const changeSum = this.lootSum(change) + this.lootSum(change2);
    const text = (v: number) => {
      const parts: string[] = [];
      parts.push(got.length === 0 ? `${this.nm(payer, v)} had no bills` : `${this.nm(payer, v)} paid ${bills(paidSum)}`);
      if (change.length) parts.push(`got ${bills(this.lootSum(change))} back in change`);
      if (names.length) {
        if (got.length === 0) parts[0] = `${this.nm(payer, v)} paid with ${names.join(" and ")}`;
        else parts.push(`handed over ${names.join(" and ")}`);
      }
      if (change2.length) parts.push(`got ${bills(this.lootSum(change2))} back in change`);
      let t = parts.join(" and ") + ".";
      if (owedNow > 0) {
        t += ` ${this.nm(payer, v)} ${this.vb(payer, v, "owe", "owes")} ${bills(owedNow)}${got.length === 0 ? "" : " more"}, taken from the next bills ${payer === v ? "you" : "they"} get.`;
      }
      return t;
    };
    void changeSum;
    if (got.length && this.s.owes[payee] > 0) this.collectDebt(payee);
    return text;
  }

  gemForPayment(p: number, payee: number): Card | null {
    let best: Card | null = null;
    let bestScore = 1e9;
    const wanted = new Set<string>();
    for (const c of COLORS) if (this.setCards(payee, c).length) wanted.add(c);
    for (const c of this.hand(payee)) if (isTreasure(c.kind)) wanted.add(c.kind);
    for (const color of COLORS) {
      if (this.isComplete(p, color)) continue;
      const cards = this.setCards(p, color);
      const progress = cards.length / setSize(color);
      for (const c of cards) {
        if (c.kind === "wild") continue;
        const score = (wanted.has(color) ? 0 : 100) + progress * 10 + pawnValue(color);
        if (score < bestScore) { bestScore = score; best = c; }
      }
    }
    return best;
  }

  collectDebt(p: number) {
    if (this.s.owes[p] <= 0 || this.bank(p).length === 0) return;
    const amount = this.s.owes[p];
    this.s.owes[p] = 0;
    const how = this.transfer(p, this.opp(p), amount);
    this.ev(p, (v) => "Paying what's owed: " + how(v), "", -1, false);
  }

  // ---- turn flow
  startTurn(first = false) {
    const s = this.s;
    s.turn_number++;
    s.plays_left = s.plays_per_turn;
    let n = DRAW_PER_TURN;
    if (this.hand(s.current).length === 0) n = 5;
    if (first) n = 1;
    const cur = s.current;
    const got = this.draw(cur, n);
    this.ev(cur, (v) => `${this.nm(cur, v)} drew ${got} card${got === 1 ? "" : "s"}.`, "", -1, false);
    if (s.counter_owed[cur] && this.counterMoves(cur).length === 0) {
      s.counter_owed[cur] = false;
      this.ev(cur, () => "No gems could be traded, so the counter-trade is lost.", "", -1, false);
    }
  }

  counterMoves(p: number): Move[] {
    const o = this.opp(p);
    const out: Move[] = [];
    for (const color of COLORS) {
      if (this.isComplete(p, color)) continue;
      for (const m of this.setCards(p, color))
        for (const c2 of COLORS) {
          if (this.isComplete(o, c2)) continue;
          for (const t of this.setCards(o, c2)) out.push({ type: "counter", as: "swap", mine: m.id, their: t.id });
        }
    }
    return out;
  }

  // A collected gem can be pawned unless it's a wild or a finished set needs it.
  canPawnCollected(p: number, color: string, card: Card): boolean {
    if (card.kind === "wild") return false;
    if (!this.isComplete(p, color)) return true;
    const rest = this.setCards(p, color).filter((c) => c.id !== card.id);
    return rest.length >= setSize(color) && rest.some((c) => c.kind !== "wild");
  }

  canCollect(p: number, card: Card, color: string): boolean {
    if (this.isComplete(p, color)) return card.kind === color;
    return card.kind === "wild" || card.kind === color;
  }

  legalMoves(p: number): Move[] {
    const s = this.s;
    let moves: Move[] = [];
    if (s.winner >= 0 || p !== s.current) return moves;
    const o = this.opp(p);
    if (s.counter_owed[p]) {
      moves = this.counterMoves(p);
      moves.push({ type: "counter_skip" });
      return moves;
    }
    if (s.plays_left > 0) {
      const empty = this.vault(p).indexOf(null);
      for (const card of this.hand(p)) {
        const kind = card.kind, id = card.id;
        if (isMoney(kind)) moves.push({ type: "bank", card: id });
        else if (isTreasure(kind)) {
          moves.push({ type: "bank", card: id });
          if (this.canCollect(p, card, kind)) moves.push({ type: "collect", card: id, color: kind });
        } else if (kind === "wild") {
          for (const color of COLORS) if (this.canCollect(p, card, color)) moves.push({ type: "collect", card: id, color });
        } else if (HEISTS.includes(kind)) moves.push(...this.heistMoves(p, id, kind));
        else if (kind === "lockpick" && this.bankTotal(p) >= cost("lockpick")) {
          for (let sl = 0; sl < 2; sl++) if (this.vault(o)[sl] !== null) moves.push({ type: "tool", card: id, slot: sl });
        } else if (kind === "lucky") moves.push({ type: "tool", card: id });
        if (empty >= 0) moves.push({ type: "vault", card: id, slot: empty });
      }
      // Pawn a gem straight out of a collection (never a wild, never one a finished set needs).
      for (const color of COLORS)
        for (const c of this.setCards(p, color)) if (this.canPawnCollected(p, color, c)) moves.push({ type: "pawn", card: c.id });
    }
    for (let sl = 0; sl < 2; sl++) if (this.vault(p)[sl] !== null) moves.push({ type: "reclaim", slot: sl });
    for (const from of COLORS)
      for (const c of this.setCards(p, from))
        if (c.kind === "wild")
          for (const color of COLORS)
            if (color !== from && !this.isComplete(p, color)) moves.push({ type: "move_wild", card: c.id, color });
    if (this.hand(p).length > HAND_LIMIT) for (const c of this.hand(p)) moves.push({ type: "discard", card: c.id });
    else moves.push({ type: "end" });
    return moves;
  }

  heistMoves(p: number, id: number, kind: string): Move[] {
    const o = this.opp(p);
    const out: Move[] = [];
    if (this.bankTotal(p) < cost(kind)) return out;
    if (kind === "swipe") {
      for (const color of COLORS)
        if (!this.isComplete(o, color)) for (const c of this.setCards(o, color)) out.push({ type: "heist", card: id, as: "swipe", their: c.id });
    } else if (kind === "swap") {
      const mine: Card[] = [], theirs: Card[] = [];
      for (const color of COLORS) {
        if (!this.isComplete(p, color)) mine.push(...this.setCards(p, color));
        if (!this.isComplete(o, color)) theirs.push(...this.setCards(o, color));
      }
      for (const m of mine) for (const t of theirs) out.push({ type: "heist", card: id, as: "swap", mine: m.id, their: t.id });
    } else if (kind === "shakedown") {
      if (this.hand(o).length) out.push({ type: "heist", card: id, as: "shakedown" });
    } else if (kind === "grand") {
      for (const color of COLORS) if (this.isComplete(o, color)) out.push({ type: "heist", card: id, as: "grand", color });
    } else if (kind === "payup") {
      // No bills? They pay with a gem at its pawn value instead (never from a finished set).
      if (this.bank(o).length || this.gemForPayment(o, p)) out.push({ type: "heist", card: id, as: "payup" });
    }
    return out;
  }

  static key(m: Move): string {
    return JSON.stringify(Object.keys(m).sort().map((k) => [k, m[k]]));
  }

  isLegal(p: number, move: Move): boolean {
    const k = Game.key(move);
    return this.legalMoves(p).some((m) => Game.key(m) === k);
  }

  apply(move: Move): boolean {
    const s = this.s;
    const p = s.current;
    if (!this.isLegal(p, move)) return false;
    const n = (k: string) => move[k] as number;
    switch (move.type) {
      case "collect": this.doCollect(p, move); break;
      case "vault": {
        const c = this.removeFromHand(p, n("card"));
        this.vault(p)[n("slot")] = c;
        s.plays_left--;
        this.ev(p, (v) => `${this.nm(p, v)} moved a card to the vault.`, "", -1, false);
        break;
      }
      case "tool": this.doTool(p, move); break;
      case "bank": {
        const c = this.removeFromHand(p, n("card"));
        this.bank(p).push(c);
        s.plays_left--;
        if (isTreasure(c.kind)) this.ev(p, (v) => `${this.nm(p, v)} pawned ${aAn(oneName(c.kind))} for ${bills(value(c.kind))}.`, c.kind, -1, false);
        else this.ev(p, (v) => `${this.nm(p, v)} banked ${bills(value(c.kind))}.`, c.kind, -1, false);
        this.collectDebt(p);
        break;
      }
      case "pawn": {
        const found = this.removeFromCollection(p, n("card"))!;
        this.bank(p).push(found[1]);
        s.plays_left--;
        this.ev(p, (v) => `${this.nm(p, v)} pawned ${aAn(oneName(found[0]))} from ${p === v ? "your" : "their"} collection for ${bills(pawnValue(found[0]))}.`, found[0], -1, false);
        this.collectDebt(p);
        break;
      }
      case "heist": this.doHeistPlay(p, move); break;
      case "reclaim": {
        const c = this.vault(p)[n("slot")]!;
        this.vault(p)[n("slot")] = null;
        this.hand(p).push(c);
        this.ev(p, (v) => `${this.nm(p, v)} took a card back from the vault.`, "", -1, false);
        break;
      }
      case "move_wild": {
        const found = this.removeFromCollection(p, n("card"))!;
        this.setCards(p, move.color as string).push(found[1]);
        this.ev(p, (v) => `${this.nm(p, v)} moved a wild to ${displayName(move.color as string)}.`, "wild", found[1].face ?? p, false);
        break;
      }
      case "discard": {
        const c = this.removeFromHand(p, n("card"));
        s.discard.push(c);
        this.ev(p, (v) => `${this.nm(p, v)} discarded ${p === v ? displayName(c.kind) : "a card"}.`, "", -1, false);
        break;
      }
      case "counter": {
        s.counter_owed[p] = false;
        const o = this.opp(p);
        const mine = this.removeFromCollection(p, n("mine"))!;
        const theirs = this.removeFromCollection(o, n("their"))!;
        this.receive(o, mine[1], mine[0]);
        this.receive(p, theirs[1], theirs[0]);
        this.ev(p, (v) => `Counter-trade! ${this.nm(p, v)} traded a ${this.cardLabel(mine[1], mine[0])} for ${this.poss(o, v)} ${this.cardLabel(theirs[1], theirs[0])}.`, "mirror", p, true);
        break;
      }
      case "counter_skip":
        s.counter_owed[p] = false;
        this.ev(p, (v) => `${this.nm(p, v)} skipped the counter-trade.`, "", -1, false);
        break;
      case "end":
        s.current = this.opp(p);
        this.startTurn();
        break;
    }
    this.checkWinner(p);
    return true;
  }

  checkWinner(p: number) {
    if (this.s.winner >= 0) return;
    for (const q of [p, this.opp(p)]) {
      if (this.completeCount(q) >= SETS_TO_WIN) {
        this.s.winner = q;
        this.ev(q, (v) => `${this.nm(q, v)} completed ${SETS_TO_WIN} sets and won!`, "wild", q, true);
        return;
      }
    }
  }

  doCollect(p: number, move: Move) {
    const s = this.s;
    const c = this.removeFromHand(p, move.card as number);
    const color = move.color as string;
    if (c.kind === "wild" && c.face === undefined) c.face = p;
    const extra = this.isComplete(p, color);
    this.setCards(p, color).push(c);
    s.plays_left--;
    if (extra) {
      const n = this.setCards(p, color).length;
      const how = this.transfer(this.opp(p), p, extraGemPay(n - setSize(color)));
      this.ev(p, (v) => `${this.nm(p, v)} added ${n !== 8 ? "a" : "an"} ${ordinal(n)} ${oneName(color)}. ${how(v)}`, color, -1, true);
      return;
    }
    const done = this.isComplete(p, color) ? " Set complete!" : "";
    if (c.kind === "wild") this.ev(p, (v) => `${this.nm(p, v)} played a Wild as ${aAn(oneName(color))}.${done}`, "wild", c.face!, done !== "");
    else this.ev(p, (v) => `${this.nm(p, v)} collected ${aAn(oneName(color))}.${done}`, color, -1, done !== "");
  }

  doTool(p: number, move: Move) {
    const s = this.s;
    const c = this.removeFromHand(p, move.card as number);
    s.discard.push(c);
    s.plays_left--;
    s.discard.push(...this.pay(p, cost(c.kind)));
    if (c.kind === "lucky") {
      const got = this.draw(p, 2);
      this.ev(p, (v) => `${this.nm(p, v)} played Lucky Break and drew ${got}.`, "lucky", p, false);
    } else {
      const o = this.opp(p);
      const slot = move.slot as number;
      const target = this.vault(o)[slot]!;
      this.vault(o)[slot] = null;
      this.hand(p).push(target);
      const what = displayName(target.kind);
      const label = TRAPS.includes(target.kind) ? `a ${what} (Defense)` : `a decoy (${what})`;
      this.ev(p, (v) => `${this.nm(p, v)} picked ${this.poss(o, v)} vault, found ${label}, and stole it!`, "lockpick", p, true);
    }
  }

  doHeistPlay(p: number, move: Move) {
    const s = this.s;
    const o = this.opp(p);
    const card = this.removeFromHand(p, move.card as number);
    const kind = move.as as string;
    if (card.kind === "wild" && card.face === undefined) card.face = p;
    s.plays_left--;
    const paid = this.pay(p, cost(kind));
    s.discard.push(...paid);
    const paidTxt = paid.length ? ` (paid ${bills(this.lootSum(paid))})` : "";
    this.ev(p, (v) => `${this.nm(p, v)} played ${displayName(kind)} on ${o === v ? "you" : this.s.players[o].name}${paidTxt}.`, kind, card.face ?? p, true);
    for (let sl = 0; sl < 2; sl++) {
      const t = this.vault(o)[sl];
      if (t !== null && TRAPS.includes(t.kind)) {
        this.vault(o)[sl] = null;
        s.discard.push(t);
        if (t.kind === "shield") {
          s.discard.push(card);
          this.ev(o, (v) => `Blocked! ${cap(this.poss(o, v))} Shield stopped ${this.poss(p, v)} ${displayName(kind)}.`, "shield", o, true);
        } else if (t.kind === "snare") {
          this.hand(o).push(card);
          const e = this.ev(o, (v) => `Snared! ${cap(this.poss(o, v))} Snare stopped ${this.poss(p, v)} ${displayName(kind)}, and ${o === v ? "you" : this.s.players[o].name} kept the card.`, "snare", o, true);
          e.kept = card.kind;
        } else {
          s.discard.push(card);
          if (kind === "swap") {
            s.counter_owed[o] = true;
            this.ev(o, (v) => `Bounced! ${cap(this.poss(o, v))} Mirror blocked the Trade and earns ${o === v ? "you" : this.s.players[o].name} a counter-trade on ${o === v ? "your" : "their"} next turn.`, "mirror", o, true);
          } else {
            this.ev(o, (v) => `Reflected! ${cap(this.poss(o, v))} Mirror bounced ${this.poss(p, v)} ${displayName(kind)} back.`, "mirror", o, true);
            this.resolveHeist(kind, o, p, true, move);
          }
        }
        return;
      }
    }
    s.discard.push(card);
    this.resolveHeist(kind, p, o, false, move);
  }

  resolveHeist(kind: string, a: number, vic: number, reflected: boolean, move: Move) {
    if (kind === "swipe") {
      let found: [string, Card] | null = null;
      if (reflected) {
        const best = this.bestStealTarget(a, vic);
        if (best >= 0) found = this.removeFromCollection(vic, best);
      } else found = this.removeFromCollection(vic, move.their as number);
      if (!found) {
        this.ev(a, (v) => (reflected ? `The Mirror bounced it back, but ${this.nm(vic, v)} had no gem to steal.` : "There was nothing to steal."), "", -1, false);
        return;
      }
      this.receive(a, found[1], found[0]);
      const f = found;
      this.ev(a, (v) => `${this.nm(a, v)} stole ${this.poss(vic, v)} ${this.cardLabel(f[1], f[0])}.`, "swipe", a, true);
    } else if (kind === "swap") {
      // Reflected trades become counter-trades before they get here; kept for parity.
      const mine = this.removeFromCollection(a, move.mine as number)!;
      const theirs = this.removeFromCollection(vic, move.their as number)!;
      this.receive(vic, mine[1], mine[0]);
      this.receive(a, theirs[1], theirs[0]);
      this.ev(a, (v) => `${this.nm(a, v)} traded a ${this.cardLabel(mine[1], mine[0])} for ${this.poss(vic, v)} ${this.cardLabel(theirs[1], theirs[0])}.`, "swap", a, true);
    } else if (kind === "shakedown") {
      if (this.hand(vic).length === 0) {
        this.ev(a, (v) => (reflected ? `The Mirror bounced it back, but ${this.poss(vic, v)} hand was empty.` : `${cap(this.poss(vic, v))} hand was empty.`), "", -1, false);
        return;
      }
      const i = this.randInt(0, this.hand(vic).length - 1);
      const c = this.hand(vic).splice(i, 1)[0];
      this.hand(a).push(c);
      // Only the two players involved ever see this text, and both know the card.
      this.ev(a, (v) => `${this.nm(a, v)} took a random card from ${this.poss(vic, v)} hand: ${displayName(c.kind)}.`, "shakedown", a, true);
    } else if (kind === "payup") {
      const how = this.transfer(vic, a, PAY_UP_AMOUNT);
      this.ev(a, (v) => (reflected ? "Bounced back! " : "Pay Up! ") + how(v), "payup", a, true);
    } else if (kind === "grand") {
      let color = "";
      if (reflected) {
        let best = 0;
        for (const col of COLORS)
          if (this.isComplete(vic, col) && this.setCards(vic, col).length > best) { best = this.setCards(vic, col).length; color = col; }
      } else color = move.color as string;
      if (!color && reflected) {
        // No finished set to take: the Mirror takes their best set in progress instead.
        const pick = this.bestUnfinishedSet(a, vic);
        if (!pick) {
          this.ev(a, (v) => `The Mirror bounced it back, but ${this.nm(vic, v)} had no gems to take.`, "", -1, false);
          return;
        }
        const taken = this.setCards(vic, pick).splice(0);
        for (const c of taken) this.receive(a, c, pick);
        const what = taken.length === 1 ? oneName(pick) : `${taken.length} ${displayName(pick)}`;
        this.ev(a, (v) => `${this.nm(vic, v)} had no finished set, so ${a === v ? "you" : this.s.players[a].name} took ${vic === v ? "your" : "their"} ${what} instead!`, "grand", a, true);
        return;
      }
      if (!color) {
        this.ev(a, () => "There was no complete set to take.", "", -1, false);
        return;
      }
      const cards = this.setCards(vic, color).splice(0);
      this.setCards(a, color).push(...cards);
      this.ev(a, (v) => `${this.nm(a, v)} pulled off a Grand Heist and took ${this.poss(vic, v)} ${displayName(color)}!`, "grand", a, true);
    }
  }

  // For a reflected Grand Heist when the victim has no finished set.
  bestUnfinishedSet(a: number, vic: number): string {
    let best = "";
    let bestScore = 0;
    for (const color of COLORS) {
      const n = this.setCards(vic, color).length;
      if (n === 0 || this.isComplete(vic, color)) continue;
      let score = n;
      if (!this.isComplete(a, color)) {
        score += this.setCards(a, color).length;
        if (score >= setSize(color)) score += 100;
      }
      if (score > bestScore) { bestScore = score; best = color; }
    }
    return best;
  }

  cardLabel = (card: Card, color: string) => (card.kind === "wild" ? `wild (${oneName(color)})` : oneName(color));

  receive(p: number, card: Card, color: string) {
    if (this.isComplete(p, color)) this.hand(p).push(card);
    else this.setCards(p, color).push(card);
  }

  bestStealTarget(a: number, vic: number): number {
    let bestId = -1, bestScore = -1;
    for (const color of COLORS) {
      if (this.isComplete(vic, color)) continue;
      for (const c of this.setCards(vic, color)) {
        const score = this.setCards(a, color).length + this.rand() * 0.1;
        if (score > bestScore) { bestScore = score; bestId = c.id; }
      }
    }
    return bestId;
  }

  // ---- what one seat is allowed to see
  view(seat: number, sinceEvent = 0) {
    const s = this.s;
    const o = this.opp(seat);
    let hid = 0;
    const hidden = () => ({ id: -(++hid), kind: "hidden" });
    // Seat order is rotated so the viewer is always player 0, as in the offline game.
    const pv = (p: number) => ({
      name: p === seat ? "You" : s.players[p].name,
      hand: p === seat ? s.players[p].hand : s.players[p].hand.map(hidden),
      collection: s.players[p].collection,
      vault: p === seat ? s.players[p].vault : s.players[p].vault.map((c) => (c ? hidden() : null)),
      bank: s.players[p].bank,
    });
    const rot = (p: number) => (p < 0 ? p : p === seat ? 0 : 1);
    return {
      players: [pv(seat), pv(o)],
      deck_count: s.deck.length,
      discard_count: s.discard.length,
      current: rot(s.current),
      plays_left: s.plays_left,
      plays_per_turn: s.plays_per_turn,
      winner: rot(s.winner),
      turn_number: s.turn_number,
      counter_owed: [s.counter_owed[seat], s.counter_owed[o]],
      owes: [s.owes[seat], s.owes[o]],
      events: s.events.slice(sinceEvent).map((e) => ({
        p: rot(e.p), text: e.t[seat], card: e.card, face: e.face < 0 ? e.face : rot(e.face), big: e.big, turn: e.turn,
        ...(e.kept ? { kept: e.kept } : {}),
      })),
      event_count: s.events.length,
    };
  }
}
