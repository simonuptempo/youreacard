// War and Piece rules: a line-for-line port of scripts/war_cards.gd + scripts/war_state.gd.
// Keep the two in step: any rule or wording change in Godot must be made here too, then run
// server/test/parity.ts (it replays Godot games move for move and compares every state).

export type Card = { id: number; rank: number; suit: string };
export type Player = { name: string; stock: Card[]; won: Card[]; hand: Card[]; sets: Card[][] };
export type Faceoff = { cards: Card[][]; ups: (Card | null)[]; winner: number; wars: number; reason: string; pot: number };
export type Ev = { p: number; text: string; text1: string; kind: string; round: number };
export type State = {
  shields?: number[]; shield_pool?: number; shields_spent?: number; shield_draws?: number[][]; heist_order?: number[]; heist_step?: number; pending_heist?: {attacker: number; rank: number; suit: string} | Record<string, never>; rules_version?: number; heist_used?: boolean[]; unclaimed?: Card[]; players: Player[]; round: number; piece_done: boolean[]; winner: number; quiet: number;
  locked_before: number; events: Ev[]; rng: number; last_faceoff: Faceoff | Record<string, never>;
};
export type Move = { t: string; p?: number; ids?: number[]; set?: number; rank?: number; suit?: string; block?: boolean };

// ------------------------------------------------------------------ war_cards.gd
export const SUITS = ["S", "H", "D", "C"];
const SUIT_NAMES: Record<string, string> = { S: "Spades", H: "Hearts", D: "Diamonds", C: "Clubs" };
export const DECK_SIZE = 52;
export const TOTAL_SETS = 13;
const MIN_SET = 4;
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
  if (cards.length !== 4) return "";
  const rank = cards[0].rank;
  const suits = new Set<string>();
  for (const c of cards) {
    if (c.rank !== rank || !SUITS.includes(c.suit) || suits.has(c.suit)) return "";
    suits.add(c.suit);
  }
  return "kind";
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
    this.s.unclaimed ??= [];
    this.s.heist_used ??= [false, false];
    this.s.shields ??= [0, 0]; this.s.shield_pool ??= 2; this.s.shields_spent ??= 0;
    this.s.shield_draws ??= [[], []]; this.s.heist_order ??= []; this.s.heist_step ??= 0;
    this.s.pending_heist ??= {};
    this.upgradeRules();
  }

  static create(names: string[], seed: number): Game {
    const g = new Game({ rules_version: 5, heist_used: [false, false], players: [], round: 1, piece_done: [false, false], winner: -1, quiet: 0, locked_before: 0, events: [], rng: seed !== 0 ? seed >>> 0 : 1, last_faceoff: {} });
    for (const n of names) g.s.players.push({ name: n, stock: [], won: [], hand: [], sets: [] });
    const deck = buildDeck();
    g.shuffle(deck);
    for (let i = 0; i < deck.length; i++) g.s.players[i % 2].stock.push(deck[i]);
    g.placeShields();
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
  totalCards() { return this.pot.length + (this.s.unclaimed?.length ?? 0) + [0, 1].reduce((n, p) => n + this.looseCount(p) + this.lockedCount(p), 0); }

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
      case "heist":
        return (p === 0 || p === 1) && Number.isInteger(m.rank) && this.heist(p, m.rank!, m.suit ?? "");
      case "defend":
        return false; // Shields resolve with the heist.
      case "pass":
        return (p === 0 || p === 1) && this.passHeist(p);
      case "lock": {
        const ids = Game.ints(m.ids);
        return (p === 0 || p === 1) && ids !== null && this.lockSet(p, ids);
      }
      case "add": {
        const ids = Game.ints(m.ids);
        return (p === 0 || p === 1) && ids !== null && this.addToSet(p, Number.isInteger(m.set) ? m.set as number : -1, ids);
      }
      case "done":
        if ((p !== 0 && p !== 1) || this.phase() !== "piece" || this.s.piece_done[p] || this.pieceActor() >= 0) return false;
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
      const c = this.drawWarCard(p);
      this.pot.push(c);
      shown[p].push(c);
      ups[p] = c;
    }
    let w = -1;
    let reason = "";
    while (true) {
      const r0 = ups[0]!.rank, r1 = ups[1]!.rank;
      if (r0 !== r1) { w = r0 > r1 ? 0 : 1; break; }
      if (this.stock(0).length === 0 || this.stock(1).length === 0) {
        w = -1; reason = "unclaimed";
        break;
      }
      wars++;
      const n = Math.min(WAR_DOWN + 1, this.stock(0).length, this.stock(1).length);
      for (const p of [0, 1]) {
        for (let k = 0; k < n; k++) {
          const c = this.drawWarCard(p);
          this.pot.push(c);
          shown[p].push(c);
          ups[p] = c;
        }
      }
    }
    const r: Faceoff = { cards: shown, ups, winner: w, wars, reason, pot: this.pot.length };
    if (w >= 0) this.s.players[w].won.push(...this.pot);
    else this.s.unclaimed!.push(...this.pot);
    const n = this.pot.length;
    this.ev(w, (v) => {
      const mine = cardName(ups[v]!);
      const theirs = cardName(ups[1 - v]!);
      if (w < 0) return `Still tied! ${n} cards set aside to split in Piece. On to the Piece round.`;
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
    for (const p of [0, 1]) { this.s.shield_pool! += this.s.shield_draws![p].length; this.s.shield_draws![p] = []; }
    for (const p of [0, 1]) {
      const pl = this.s.players[p];
      pl.hand = [...pl.won, ...pl.stock];
      pl.won = [];
      pl.stock = [];
    }
    this.s.round++;
    this.returnUnclaimed();
    this.s.piece_done = [false, false];
    this.s.heist_used = [false, false];
    this.s.locked_before = this.lockedCount(0) + this.lockedCount(1);
    const round = this.s.round;
    this.ev(-1, `Round ${round}: Piece! Bank complete ranks, then take turns heisting.`, "round");
    for (const p of [0, 1]) this.autoBank(p);
    this.planHeists();
  }

  // ---- Piece
  autoBank(p: number) {
    if (this.phase() !== "piece") return;
    for (let rank = 2; rank < 15; rank++) {
      const group = this.hand(p).filter(c => c.rank === rank);
      if (setType(group) !== "") this.lockSet(p, group.map(c => c.id));
    }
  }

  returnUnclaimed() {
    if (!this.s.unclaimed!.length) return;
    const count=this.s.unclaimed!.length; this.shuffle(this.s.unclaimed!);
    const first=this.hand(0).length<=this.hand(1).length?0:1;
    this.s.unclaimed!.forEach((c,i)=>this.hand((first+i)%2).push(c));
    this.s.unclaimed=[];
    this.ev(-1,`${count} tied cards split evenly into Piece hands. Every set stays in play.`,"reclaim");
  }

  placeShields() {
    const total = this.stock(0).length + this.stock(1).length;
    if (!total) return;
    while (this.s.shield_pool! > 0) {
      const slot = Math.floor(this.rand() * total);
      const p = slot < this.stock(0).length ? 0 : 1;
      const position = p === 0 ? slot + 1 : slot - this.stock(0).length + 1;
      this.s.shield_draws![p].push(position); this.s.shield_pool!--;
    }
  }
  drawWarCard(p: number): Card {
    const remaining = this.stock(p).length;
    let i;
    while ((i = this.s.shield_draws![p].indexOf(remaining)) >= 0) {
      this.s.shield_draws![p].splice(i, 1); this.s.shields![p]++;
    }
    return this.stock(p).pop()!;
  }
  totalShields(): number {
    return this.s.shields![0] + this.s.shields![1] + this.s.shield_pool! + this.s.shields_spent! + this.s.shield_draws![0].length + this.s.shield_draws![1].length;
  }
  planHeists() {
    if(this.checkComplete()) return;
    let first = (Math.floor(this.s.round / 2) - 1) % 2;
    if (this.sets(0).length !== this.sets(1).length) first = this.sets(0).length < this.sets(1).length ? 0 : 1;
    this.s.heist_order = [first, 1 - first, first]; this.s.heist_step = 0; this.s.pending_heist = {};
  }
  pieceActor(): number {
    if (this.phase() !== "piece") return -1;
    if (Object.keys(this.s.pending_heist!).length) return 1 - this.s.pending_heist!.attacker;
    return this.s.heist_step! < this.s.heist_order!.length ? this.s.heist_order![this.s.heist_step!] : -1;
  }
  heistOptions(p: number, rank = -1): {rank: number; suit: string}[] {
    if (![0, 1].includes(p) || this.pieceActor() !== p || Object.keys(this.s.pending_heist!).length) return [];
    const options: {rank: number; suit: string}[] = [];
    for (let r = 2; r < 15; r++) {
      if (rank >= 0 && rank !== r) continue;
      const group = this.hand(p).filter(c => c.rank === r);
      if (![1, 2, 3].includes(group.length)) continue;
      for (const suit of SUITS) if (this.hand(1-p).some(c => c.rank === r && c.suit === suit)) options.push({rank:r, suit});
    }
    return options;
  }
  canHeist(p: number, rank: number): boolean { return this.heistOptions(p, rank).length > 0; }
  heist(p: number, rank: number, suit = ""): boolean {
    let options = this.heistOptions(p, rank);
    if (suit !== "") options = options.filter(o => o.suit === suit);
    if (!options.length) return false;
    this.s.pending_heist = {attacker:p, rank, suit:options[0].suit};
    const card = cardName(this.s.pending_heist as Card);
    this.ev(p, v => `${this.sv(p, v, "try", "tries")} to steal the ${card}.`, "heist_start");
    return this.resolveHeist();
  }
  resolveHeist(): boolean {
    if (!Object.keys(this.s.pending_heist!).length) return false;
    const p=1-this.s.pending_heist!.attacker;
    const block=this.s.shields![p]>0;
    const {attacker, rank, suit} = this.s.pending_heist!;
    const name = cardName({rank, suit} as Card);
    if (block) {
      this.s.shields![p]--; this.s.shields_spent!++;
      this.ev(p, v => `${this.sv(p, v, "block", "blocks")} the heist with a shield!`, "shield");
    } else {
      const i = this.hand(p).findIndex(c => c.rank === rank && c.suit === suit);
      this.hand(attacker).push(this.hand(p).splice(i, 1)[0]);
      this.ev(attacker, v => `${this.sv(attacker, v, "stole", "stole")} the ${name}.`, "heist");
      this.autoBank(attacker);
    }
    this.s.heist_used![attacker] = true; this.s.pending_heist = {}; this.s.heist_step!++;
    return true;
  }
  passHeist(p: number): boolean {
    if (this.pieceActor() !== p || Object.keys(this.s.pending_heist!).length) return false;
    this.s.heist_used![p] = true; this.s.heist_step!++;
    this.ev(p, v => `${this.sv(p, v, "pass", "passes")} this heist.`, "pass");
    return true;
  }

  upgradeFourSuits() {
    if ((this.s.rules_version ?? 1) >= 2) return;
    this.s.rules_version = 2;
    this.s.heist_used = [false, false];
    if (this.s.winner >= 0) return;
    for (const p of [0, 1]) {
      const kept: Card[][] = [];
      for (const st of this.sets(p)) {
        if (setType(st) !== "") kept.push(st);
        else this.s.players[p][this.phase() === "piece" ? "hand" : "stock"].push(...st);
      }
      this.s.players[p].sets = kept;
    }
    this.s.locked_before = this.lockedCount(0) + this.lockedCount(1);
    this.s.quiet = 0;
    this.ev(-1, "New Piece rules: four suits make a set. Incomplete banked groups return to their owner's cards.", "rules");
    if (this.phase() === "piece") {
      this.s.piece_done = [false, false];
      for (const p of [0, 1]) this.autoBank(p);
    }
  }

  upgradeRules() {
    if ((this.s.rules_version??1)>=5) return;
    const previous=this.s.rules_version??1;
    this.upgradeShields(); this.s.rules_version=5;
    if (this.s.winner<0) {
      if(previous<4) this.ev(-1,"Keep playing War and Piece until all 13 sets are complete.","rules");
      if(Object.keys(this.s.pending_heist!).length) this.resolveHeist();
      this.ev(-1,"Shields now block heists automatically.","rules");
    }
  }

  upgradeShields() {
    if ((this.s.rules_version ?? 1) >= 3) return;
    this.upgradeFourSuits(); this.s.rules_version = 3;
    this.s.shields = [0,0]; this.s.shield_pool = 2; this.s.shields_spent = 0; this.s.shield_draws = [[],[]];
    if (this.s.winner >= 0) return;
    if (this.phase() === "war") this.placeShields();
    else {
      this.planHeists();
      for (const p of [0,1]) if (this.s.heist_used![p]) {const i=this.s.heist_order!.indexOf(p); if (i>=0) this.s.heist_order!.splice(i,1);}
      this.s.piece_done = [false,false];
    }
    this.ev(-1, "Piece now uses three heist turns. Two secret shields can be found during War.", "rules");
  }

  lockSet(p: number, ids: number[]): boolean {
    if (this.phase() !== "piece" || this.s.piece_done[p]) return false;
    const cards = this.takeFromHand(p, ids, false);
    if (cards.length !== ids.length || setType(cards) === "") return false;
    this.takeFromHand(p, ids, true);
    this.sets(p).push(sortHand(cards));
    const what = describeSet(cards);
    this.ev(p, (v) => `${this.who(p, v)} banked ${what}.`, "lock");
    this.checkComplete();
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
    if (this.phase() !== "piece" || this.pieceActor() >= 0) return;
    this.s.piece_done[p] = true;
    if (this.s.piece_done[0] && this.s.piece_done[1]) this.startWarRound();
  }

  checkComplete(): boolean {
    if(this.s.winner>=0) return true;
    if(this.sets(0).length+this.sets(1).length!==13) return false;
    this.s.heist_order=[];this.s.pending_heist={};
    this.endGame(this.sets(0).length>this.sets(1).length?0:1,"All 13 sets are complete!");
    return true;
  }

  finalShowdown() {
    let deck=buildDeck(); this.shuffle(deck);
    const draws: Card[][]=[[],[]], totals=[0,0]; let w=-1;
    while(w<0) {
      for(let i=0;i<5;i++) {
        if(deck.length<2) { deck=buildDeck(); this.shuffle(deck); }
        for(const p of [0,1]) { const card=deck.pop()!; draws[p].push(card); totals[p]+=card.rank; }
      }
      if(totals[0]!==totals[1]) w=totals[0]>totals[1]?0:1;
    }
    const finalSet=[...this.hand(0),...this.hand(1)];
    this.s.players[0].hand=[]; this.s.players[1].hand=[];
    this.sets(w).push(sortHand(finalSet));
    this.s.last_faceoff={cards:draws,ups:[draws[0].at(-1)!,draws[1].at(-1)!],winner:w,wars:draws[0].length/5-1,reason:"final_showdown",pot:4};
    this.ev(w,v=>`${this.sv(w,v,"win","wins")} the final showdown and completed the last set!`,"showdown");
    this.endGame(this.sets(0).length>this.sets(1).length?0:1,"All 13 sets are complete!");
  }

  startWarRound() {
    this.returnUnclaimed();
    for (const p of [0,1]) this.autoBank(p);
    if (this.sets(0).length + this.sets(1).length === 13) {
      const a=this.sets(0).length, b=this.sets(1).length;
      this.endGame(a>b?0:b>a?1:2, "All 13 sets are complete!"); return;
    }
    if (this.sets(0).length + this.sets(1).length === 12) {
      // One set left. A showdown only breaks a 6-6 tie; otherwise the leader wins now.
      if (this.sets(0).length === this.sets(1).length) this.finalShowdown();
      else this.endGame(this.sets(0).length > this.sets(1).length ? 0 : 1, "Only one set is left, and it can't change the result!");
      return;
    }
    this.s.quiet=0;
    if (!this.hand(0).length || !this.hand(1).length) {
      const loose=[...this.hand(0),...this.hand(1)]; this.shuffle(loose);
      this.s.players[0].hand=[]; this.s.players[1].hand=[];
      loose.forEach((c,i)=>this.hand(i%2).push(c));
      this.ev(-1,"The remaining loose cards are dealt evenly for the next War.","redeal");
    }
    this.s.round++;
    for (const p of [0, 1]) {
      const s = [...this.hand(p)];
      this.shuffle(s);
      this.s.players[p].stock = s;
      this.s.players[p].hand = [];
    }
    this.placeShields();
    const round = this.s.round;
    this.ev(-1, (v) => `Round ${round}: War! You have ${this.stock(v).length} loose cards and ${this.nm(1 - v)} has ${this.stock(1 - v).length}.`, "round");
  }

  endGame(w: number, why: string | ((v: number) => string)) {
    this.s.winner = w;
    const a = this.sets(0).length, b = this.sets(1).length;
    const reason = (v: number) => typeof why === "function" ? why(v) : why;
    if (w === 2) this.ev(-1, (v) => `${reason(v)} It's a draw: ${a} banked sets each.`, "over");
    else {
      const mine = w === 0 ? a : b, theirs = w === 0 ? b : a;
      this.ev(w, (v) => `${reason(v)} ${this.sv(w, v, "win", "wins")} with ${mine} banked sets to ${theirs}.`, "over");
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
      rules_version: this.s.rules_version,
      shields: [this.s.shields![seat], -1],
      heist_order: this.s.heist_order!.map(rot), heist_step: this.s.heist_step,
      pending_heist: Object.keys(this.s.pending_heist!).length ? {...this.s.pending_heist, attacker:rot(this.s.pending_heist!.attacker)} : {},
      heist_options: this.heistOptions(seat),
      heist_used: [this.s.heist_used![seat], this.s.heist_used![o]],
      allowed_heists: Array.from({length: 13}, (_, i) => i + 2).filter(rank => this.canHeist(seat, rank)),
      unclaimed: this.s.unclaimed,
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
