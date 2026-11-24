// War and Piece rules: a line-for-line port of scripts/war_cards.gd + scripts/war_state.gd.
// Keep the two in step: any rule or wording change in Godot must be made here too, then run
// server/test/parity.ts (it replays Godot games move for move and compares every state).

export type Card = { id: number; rank: number; suit: string };
export type Player = { name: string; stock: Card[]; won: Card[]; hand: Card[]; sets: Card[][] };
export type Faceoff = { cards: Card[][]; ups: (Card | null)[]; winner: number; wars: number; reason: string; pot: number };
export type Ev = { p: number; text: string; text1: string; kind: string; round: number };
export type State = {
  players: Player[]; round: number; piece_done: boolean[]; winner: number; quiet: number;
  locked_before: number; events: Ev[]; rng: number; last_faceoff: Faceoff | Record<string, never>;
};
export type Move = { t: string; p?: number; ids?: number[]; set?: number };

// ------------------------------------------------------------------ war_cards.gd
export const SUITS = ["S", "H", "D", "C"];
const SUIT_NAMES: Record<string, string> = { S: "Spades", H: "Hearts", D: "Diamonds", C: "Clubs" };
export const DECK_SIZE = 52;
export const WIN_LOCKED = 30;
const MIN_SET = 3;
const WAR_DOWN = 3;

export function buildDeck(): Card[] {
  const deck: Card[] = [];
  let id = 1;
  for (const s of SUITS) for (let r = 2; r < 15; r++) deck.push({ id: id++, rank: r, suit: s });
  return deck;
}
const rankName = (r: number) => ({ 11: "Jack", 12: "Queen", 13: "King", 14: "Ace" } as Record<number, string>)[r] ?? String(r);
const rankShort = (r: number) => ({ 11: "J", 12: "Q", 13: "K", 14: "A" } as Record<number, string>)[r] ?? String(r);
const pluralRank = (r: number) => rankName(r) + "s";
export const cardName = (c: Card) => `${rankName(c.rank)} of ${SUIT_NAMES[c.suit]}`;
const countWord = (n: number) => n < 5 ? ["", "one", "two", "three", "four"][n] : String(n);

export function setType(cards: Card[]): string {
  if (cards.length < MIN_SET) return "";
  const r = cards[0].rank;
  if (cards.every((c) => c.rank === r)) return "kind";
  const s = cards[0].suit;
  const ranks: number[] = [];
  for (const c of cards) {
    if (c.suit !== s) return "";
    ranks.push(c.rank);
  }
  ranks.sort((a, b) => a - b);
  for (let i = 1; i < ranks.length; i++) if (ranks[i] !== ranks[i - 1] + 1) return "";
  return "run";
}

export function describeSet(cards: Card[]): string {
  const t = setType(cards);
  if (t === "kind") return `${countWord(cards.length)} ${pluralRank(cards[0].rank)}`;
  if (t === "run") {
    const ranks = cards.map((c) => c.rank).sort((a, b) => a - b);
    return `${rankShort(ranks[0])} to ${rankShort(ranks[ranks.length - 1])} of ${SUIT_NAMES[cards[0].suit]}`;
  }
  return "";
}

export function sortHand(cards: Card[]): Card[] {
  return [...cards].sort((a, b) => a.rank !== b.rank ? a.rank - b.rank : SUITS.indexOf(a.suit) - SUITS.indexOf(b.suit));
}

// ------------------------------------------------------------------ war_state.gd
export class Game {
  s: State;
  pot: Card[] = [];

  constructor(s: State) {
    this.s = s;
  }

  static create(names: string[], seed: number): Game {
    const g = new Game({ players: [], round: 1, piece_done: [false, false], winner: -1, quiet: 0, locked_before: 0, events: [], rng: seed !== 0 ? seed >>> 0 : 1, last_faceoff: {} });
    for (const n of names) g.s.players.push({ name: n, stock: [], won: [], hand: [], sets: [] });
    const deck = buildDeck();
    g.shuffle(deck);
    for (let i = 0; i < deck.length; i++) g.s.players[i % 2].stock.push(deck[i]);
    g.ev(-1, "Round 1: War! Each of you has 26 cards.", "round");
    return g;
  }

  phase(): string {
    if (this.s.winner >= 0) return "over";
    return this.s.round % 2 === 1 ? "war" : "piece";
  }
  nm(p: number) { return this.s.players[p].name; }
  stock(p: number) { return this.s.players[p].stock; }
  hand(p: number) { return this.s.players[p].hand; }
  sets(p: number) { return this.s.players[p].sets; }
  lockedCount(p: number) { return this.sets(p).reduce((n, st) => n + st.length, 0); }
  looseCount(p: number) { const pl = this.s.players[p]; return pl.stock.length + pl.won.length + pl.hand.length; }
  totalCards() { return this.pot.length + [0, 1].reduce((n, p) => n + this.looseCount(p) + this.lockedCount(p), 0); }

  ev(p: number, say: string | ((v: number) => string), kind = "") {
    const t0 = typeof say === "function" ? say(0) : say;
    const t1 = typeof say === "function" ? say(1) : say;
    this.s.events.push({ p, text: t0, text1: t1, kind, round: this.s.round });
  }
  who(p: number, v: number) { return p === v ? "You" : this.nm(p); }
  whom(p: number, v: number) { return p === v ? "you" : this.nm(p); }
  sv(p: number, v: number, you: string, other: string) { return p === v ? "You " + you : this.nm(p) + " " + other; }
  svl(p: number, v: number, you: string, other: string) { return p === v ? "you " + you : this.nm(p) + " " + other; }

  rand(): number {
    // mulberry32, the same as WarState._rand
    this.s.rng = (this.s.rng + 0x6D2B79F5) >>> 0;
    let t = this.s.rng;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ ((t + Math.imul(t ^ (t >>> 7), t | 61)) >>> 0)) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  shuffle<T>(a: T[]) {
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(this.rand() * (i + 1));
      const t = a[i]; a[i] = a[j]; a[j] = t;
    }
  }

  // ---- moves
  apply(m: Move): boolean {
    if (!m || typeof m !== "object") return false;
    const t = String(m.t ?? "");
    const p = Number.isInteger(m.p) ? m.p as number : -1;
    switch (t) {
      case "flip":
        if (this.phase() !== "war") return false;
        this.flip();
        return true;
      case "flip_all":
        if (this.phase() !== "war") return false;
        while (this.phase() === "war") this.flip();
        return true;
      case "lock": {
        const ids = Game.ints(m.ids);
        return (p === 0 || p === 1) && ids !== null && this.lockSet(p, ids);
      }
      case "add": {
        const ids = Game.ints(m.ids);
        return (p === 0 || p === 1) && ids !== null && this.addToSet(p, Number.isInteger(m.set) ? m.set as number : -1, ids);
      }
      case "done":
        if ((p !== 0 && p !== 1) || this.phase() !== "piece" || this.s.piece_done[p]) return false;
        this.finishPiece(p);
        return true;
    }
    return false;
  }

  static ints(a: unknown): number[] | null {
    if (!Array.isArray(a)) return null;
    const out: number[] = [];
    for (const x of a) {
      const n = Math.trunc(Number(x));
      if (!Number.isFinite(n)) return [];
      if (out.includes(n)) return [];
      out.push(n);
    }
    return out;
  }

  resign(p: number) {
    if (this.s.winner >= 0) return;
    this.s.winner = 1 - p;
    this.ev(p, (v) => `${this.sv(p, v, "left", "left")} the game.`, "over");
  }

  // ---- War
  flip(): Faceoff | null {
    if (this.phase() !== "war") return null;
    const shown: Card[][] = [[], []];
    const ups: (Card | null)[] = [null, null];
    let wars = 0;
    this.pot = [];
    for (const p of [0, 1]) {
      const c = this.stock(p).pop()!;
      this.pot.push(c);
      shown[p].push(c);
      ups[p] = c;
    }
    let w = -1;
    let reason = "";
    while (true) {
      const r0 = ups[0]!.rank, r1 = ups[1]!.rank;
      if (r0 !== r1) { w = r0 > r1 ? 0 : 1; break; }
      if (this.sets(0).length !== this.sets(1).length) {
        w = this.sets(0).length > this.sets(1).length ? 0 : 1;
        reason = "sets";
        break;
      }
      if (this.stock(0).length === 0 || this.stock(1).length === 0) {
        if (this.stock(0).length === 0 && this.stock(1).length === 0) { w = -1; reason = "split"; }
        else { w = this.stock(1).length === 0 ? 0 : 1; reason = "out"; }
        break;
      }
      wars++;
      for (const p of [0, 1]) {
        const n = Math.min(WAR_DOWN + 1, this.stock(p).length);
        for (let k = 0; k < n; k++) {
          const c = this.stock(p).pop()!;
          this.pot.push(c);
          shown[p].push(c);
          ups[p] = c;
        }
      }
    }
    const r: Faceoff = { cards: shown, ups, winner: w, wars, reason, pot: this.pot.length };
    if (w >= 0) this.s.players[w].won.push(...this.pot);
    else for (const p of [0, 1]) this.s.players[p].won.push(...shown[p]);
    const n = this.pot.length;
    this.ev(w, (v) => {
      const mine = cardName(ups[v]!);
      const theirs = cardName(ups[1 - v]!);
      if (w < 0) return `${mine} vs ${theirs}: a tie, and nobody had cards left for a war. Everyone keeps their own.`;
      if (reason === "sets") return `${mine} vs ${theirs}: a tie! ${this.sv(w, v, "have", "has")} more locked sets, so ${this.svl(w, v, "take", "takes")} ${n} cards.`;
      if (wars > 0) return `War${wars === 1 ? "" : " x" + wars}! ${mine} vs ${theirs}. ${this.sv(w, v, "win", "wins")} ${n} cards.`;
      if (reason === "out") return `${mine} vs ${theirs}: a tie, and ${this.whom(1 - w, v)} ran out of cards for the war. ${this.sv(w, v, "take", "takes")} ${n} cards.`;
      return `${cardName(ups[w]!)} beats ${cardName(ups[1 - w]!)}. ${this.sv(w, v, "take", "takes")} ${n} cards.`;
    }, wars > 0 ? "war" : "flip");
    this.pot = [];
    this.s.last_faceoff = r;
    if (this.stock(0).length === 0 || this.stock(1).length === 0) this.endWarRound();
    return r;
  }

  endWarRound() {
    for (const p of [0, 1]) {
      const pl = this.s.players[p];
      pl.hand = [...pl.won, ...pl.stock];
      pl.won = [];
      pl.stock = [];
    }
    this.s.round++;
    this.s.piece_done = [false, false];
    this.s.locked_before = this.lockedCount(0) + this.lockedCount(1);
    const round = this.s.round;
    this.ev(-1, (v) => `Round ${round}: Piece! You won ${this.hand(v).length} cards and ${this.nm(1 - v)} won ${this.hand(1 - v).length}. Lock them away in sets.`, "round");
  }

  // ---- Piece
  lockSet(p: number, ids: number[]): boolean {
    if (this.phase() !== "piece" || this.s.piece_done[p]) return false;
    const cards = this.takeFromHand(p, ids, false);
    if (cards.length !== ids.length || setType(cards) === "") return false;
    this.takeFromHand(p, ids, true);
    this.sets(p).push(sortHand(cards));
    const what = describeSet(cards);
    this.ev(p, (v) => `${this.who(p, v)} locked away ${what}.`, "lock");
    return true;
  }

  addToSet(p: number, i: number, ids: number[]): boolean {
    if (this.phase() !== "piece" || this.s.piece_done[p] || i < 0 || i >= this.sets(p).length) return false;
    const cards = this.takeFromHand(p, ids, false);
    if (cards.length !== ids.length || cards.length === 0) return false;
    const grown = [...this.sets(p)[i], ...cards];
    if (setType(grown) === "") return false;
    this.takeFromHand(p, ids, true);
    this.sets(p)[i] = sortHand(grown);
    const what = describeSet(grown);
    const k = cards.length;
    this.ev(p, (v) => `${this.who(p, v)} added ${k} to ${what}.`, "lock");
    return true;
  }

  takeFromHand(p: number, ids: number[], remove: boolean): Card[] {
    const out: Card[] = [];
    for (const id of ids) {
      const c = this.hand(p).find((x) => x.id === id);
      if (c) out.push(c);
    }
    if (remove) {
      for (const c of out) {
        const h = this.hand(p);
        const at = h.indexOf(c);
        if (at >= 0) h.splice(at, 1);
      }
    }
    return out;
  }

  finishPiece(p: number) {
    if (this.phase() !== "piece") return;
    this.s.piece_done[p] = true;
    if (this.s.piece_done[0] && this.s.piece_done[1]) this.startWarRound();
  }

  startWarRound() {
    const best = this.lockedCount(0) >= this.lockedCount(1) ? 0 : 1;
    if (this.lockedCount(best) >= WIN_LOCKED) {
      if (this.lockedCount(0) === this.lockedCount(1)) this.endGame(2, `You both locked away ${this.lockedCount(0)} cards!`);
      else {
        const lc = this.lockedCount(best);
        this.endGame(best, (v) => `${this.who(best, v)} locked away ${lc} cards!`);
      }
      return;
    }
    this.s.quiet = this.lockedCount(0) + this.lockedCount(1) === this.s.locked_before ? this.s.quiet + 1 : 0;
    if (this.s.quiet >= 2) {
      const a0 = this.lockedCount(0), b0 = this.lockedCount(1);
      this.endGame(a0 > b0 ? 0 : b0 > a0 ? 1 : 2, "No new sets for two Piece rounds in a row, so the game ends.");
      return;
    }
    if (this.hand(0).length === 0 || this.hand(1).length === 0) {
      const a = this.lockedCount(0), b = this.lockedCount(1);
      const w = a > b ? 0 : b > a ? 1 : 2;
      const empty = this.hand(0).length === 0 ? 0 : 1;
      this.endGame(w, (v) => `${this.sv(empty, v, "have", "has")} no loose cards left for a War round.`);
      return;
    }
    this.s.round++;
    for (const p of [0, 1]) {
      const s = [...this.hand(p)];
      this.shuffle(s);
      this.s.players[p].stock = s;
      this.s.players[p].hand = [];
    }
    const round = this.s.round;
    this.ev(-1, (v) => `Round ${round}: War! You have ${this.stock(v).length} loose cards and ${this.nm(1 - v)} has ${this.stock(1 - v).length}.`, "round");
  }

  endGame(w: number, why: string | ((v: number) => string)) {
    this.s.winner = w;
    const a = this.lockedCount(0), b = this.lockedCount(1);
    const reason = (v: number) => typeof why === "function" ? why(v) : why;
    if (w === 2) this.ev(-1, (v) => `${reason(v)} It's a draw: ${a} locked cards each.`, "over");
    else {
      const mine = w === 0 ? a : b, theirs = w === 0 ? b : a;
      this.ev(w, (v) => `${reason(v)} ${this.sv(w, v, "win", "wins")} with ${mine} locked cards to ${theirs}.`, "over");
    }
  }

  // ---- what each player may see
  // The table as one seat sees it, turned around so that seat is always player 0:
  // stocks are face down (placeholder cards, counts only), the opponent's Piece hand is
  // hidden, and the shuffle seed stays on the server. Godot loads it with WarState.from_dict.
  view(seat: number, fromEvent = 0): Record<string, unknown> {
    const o = 1 - seat;
    const hide = (cards: Card[]) => cards.map(() => ({ id: 0, rank: 0, suit: "" }));
    const rot = (p: number) => p < 0 || p > 1 ? p : p === seat ? 0 : 1;
    const pl = (p: number, mine: boolean) => {
      const x = this.s.players[p];
      return { name: x.name, stock: hide(x.stock), won: x.won, hand: mine ? x.hand : hide(x.hand), sets: x.sets };
    };
    const lf = this.s.last_faceoff as Faceoff;
    const faceoff = lf && "ups" in lf
      ? { cards: [lf.cards[seat], lf.cards[o]], ups: [lf.ups[seat], lf.ups[o]], winner: rot(lf.winner), wars: lf.wars, reason: lf.reason, pot: lf.pot }
      : {};
    return {
      players: [pl(seat, true), pl(o, false)],
      round: this.s.round,
      piece_done: [this.s.piece_done[seat], this.s.piece_done[o]],
      winner: rot(this.s.winner),
      quiet: this.s.quiet,
      locked_before: this.s.locked_before,
      events: this.s.events.slice(fromEvent).map((e) => ({ p: rot(e.p), text: seat === 0 ? e.text : e.text1, text1: seat === 0 ? e.text1 : e.text, kind: e.kind, round: e.round })),
      rng: 0,
      last_faceoff: faceoff,
    };
  }
}
