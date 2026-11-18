class_name GameState
extends RefCounted
## Pure rules engine. No UI code here, so the same rules can later run on the server.
## Player 0 is the local human (named "You"), player 1 is the opponent.

const HAND_LIMIT := 7
const SETS_TO_WIN := 4
const DRAW_PER_TURN := 2
const EXTRA_GEM_PAY := [2, 3]  # bills your opponent pays for the 1st and 2nd extra gem added to a finished set
const PAY_UP_AMOUNT := 2
const START_HAND := 5

var rng := RandomNumberGenerator.new()
var deck: Array = []
var discard: Array = []
var players: Array = []      # {name, hand:[], collection:{color:[cards]}, vault:[card|null, card|null]}
var current := 0
var plays_left := 0
var plays_per_turn := 2
var free_used := false
var winner := -1
var turn_number := 0
var events: Array = []       # every event, in order. UI reads new ones by index.
var counter_owed := [false, false]
var owes := [0, 0]           # bills a player still owes their opponent; taken from the next bills they get  # a Mirror bounced a Trade: this player picks a free trade at the start of their turn


func setup(names: Array, seed_value: int, first: int, plays: int = 3) -> void:
	rng.seed = seed_value
	plays_per_turn = plays
	deck = CardDB.build_deck()
	_shuffle(deck)
	discard = []
	players = []
	events = []
	winner = -1
	turn_number = 0
	counter_owed = [false, false]
	owes = [0, 0]
	for n in names:
		var coll := {}
		for c in CardDB.COLORS:
			coll[c] = []
		players.append({"name": n, "hand": [], "collection": coll, "vault": [null, null], "bank": []})
	for i in START_HAND:
		for p in players.size():
			_draw_one(p)
	current = first
	_start_turn(true)


## Online games: rebuild the table from what the server lets this player see.
## The viewer is always player 0; the opponent's hand and vault arrive as "hidden" cards.
static func from_view(v: Dictionary) -> GameState:
	var g := GameState.new()
	g.players = []
	for pv in v.get("players", []):
		var coll := {}
		for c in CardDB.COLORS:
			coll[c] = _cards(pv.get("collection", {}).get(c, []))
		var vault: Array = []
		for c in pv.get("vault", [null, null]):
			vault.append(null if c == null else _card(c))
		g.players.append({"name": str(pv.get("name", "")), "hand": _cards(pv.get("hand", [])),
			"collection": coll, "vault": vault, "bank": _cards(pv.get("bank", []))})
	g.current = int(v.get("current", 0))
	g.plays_left = int(v.get("plays_left", 0))
	g.plays_per_turn = int(v.get("plays_per_turn", 3))
	g.winner = int(v.get("winner", -1))
	g.turn_number = int(v.get("turn_number", 0))
	g.counter_owed = [bool(v.get("counter_owed", [false, false])[0]), bool(v.get("counter_owed", [false, false])[1])]
	g.owes = [int(v.get("owes", [0, 0])[0]), int(v.get("owes", [0, 0])[1])]
	g.events = []
	for e in v.get("events", []):
		var ev := {"p": int(e.get("p", 0)), "text": str(e.get("text", "")), "card": str(e.get("card", "")),
			"face": int(e.get("face", -1)), "big": bool(e.get("big", false)), "turn": int(e.get("turn", 0))}
		if e.has("kept"):
			ev["kept"] = str(e["kept"])
		g.events.append(ev)
	return g


## The whole table as plain data, to save a game in progress (see Profile.save_game).
func to_dict(with_events := true) -> Dictionary:
	return {"players": players.duplicate(true), "deck": deck.duplicate(true), "discard": discard.duplicate(true),
		"current": current, "plays_left": plays_left, "plays_per_turn": plays_per_turn, "winner": winner,
		"turn_number": turn_number, "counter_owed": counter_owed.duplicate(), "owes": owes.duplicate(),
		"free_used": free_used, "events": events.duplicate(true) if with_events else [],
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}


## Rebuild a saved table (JSON turns every number into a float, so ids are made ints again).
static func from_dict(d: Dictionary) -> GameState:
	var g := from_view(d)
	g.deck = _cards(d.get("deck", []))
	g.discard = _cards(d.get("discard", []))
	g.free_used = bool(d.get("free_used", false))
	g.rng.seed = int(str(d.get("rng_seed", "0")))
	g.rng.state = int(str(d.get("rng_state", "0")))
	return g


static func _card(c: Dictionary) -> Dictionary:
	var out := {"id": int(c.get("id", 0)), "kind": str(c.get("kind", "hidden"))}
	if c.has("face"):
		out["face"] = int(c["face"])
	return out


static func _cards(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(_card(c))
	return out


## A detached copy of the whole table, used to replay a turn step by step.
func clone() -> GameState:
	var c := GameState.new()
	c.deck = deck.duplicate(true)
	c.discard = discard.duplicate(true)
	c.players = players.duplicate(true)
	c.current = current
	c.plays_left = plays_left
	c.plays_per_turn = plays_per_turn
	c.winner = winner
	c.turn_number = turn_number
	c.counter_owed = counter_owed.duplicate()
	c.owes = owes.duplicate()
	c.events = []
	return c


# ---------------------------------------------------------------- helpers

func opp(p: int) -> int:
	return 1 - p


func hand(p: int) -> Array:
	return players[p]["hand"]


func bank(p: int) -> Array:
	return players[p]["bank"]


func bank_total(p: int) -> int:
	var t := 0
	for c in bank(p):
		t += CardDB.value(c["kind"])
	return t


## Pay `amount` from p's bank automatically: the combination that overpays least
## (then uses fewest cards). No change is given. Returns the cards paid.
func _pay(p: int, amount: int) -> Array:
	var b := bank(p)
	if amount <= 0 or b.is_empty():
		return []
	if bank_total(p) <= amount:
		var everything := b.duplicate()
		b.clear()
		return everything
	var n := mini(b.size(), 12)
	var best_mask := -1
	var best_sum := 1 << 30
	var best_count := 99
	for m in range(1, 1 << n):
		var sm := 0
		var cnt := 0
		for i in n:
			if m & (1 << i):
				sm += CardDB.value(b[i]["kind"])
				cnt += 1
		if sm >= amount and (sm < best_sum or (sm == best_sum and cnt < best_count)):
			best_sum = sm
			best_mask = m
			best_count = cnt
	var paid: Array = []
	if best_mask < 0:
		return paid
	for i in range(n - 1, -1, -1):
		if best_mask & (1 << i):
			paid.append(b[i])
			b.remove_at(i)
	return paid


## Bills for an extra gem on a finished set: 2 for the first extra, 3 after that.
static func extra_gem_pay(extra_index: int) -> int:
	return EXTRA_GEM_PAY[clampi(extra_index - 1, 0, EXTRA_GEM_PAY.size() - 1)]


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


## The bills in `pool` that add up to exactly `target` (fewest cards), or [] if none do.
func _exact_subset(pool: Array, target: int) -> Array:
	if target <= 0:
		return []
	var n := mini(pool.size(), 12)
	var best := -1
	var best_count := 99
	for m in range(1, 1 << n):
		var sm := 0
		var cnt := 0
		for i in n:
			if m & (1 << i):
				sm += CardDB.value(pool[i]["kind"])
				cnt += 1
		if sm == target and cnt < best_count:
			best = m
			best_count = cnt
	var out: Array = []
	if best >= 0:
		for i in n:
			if best & (1 << i):
				out.append(pool[i])
	return out


## One player pays another. Overpayment comes back as change when the payee's bank has
## the right bills; anything the payer can't cover is owed and taken from the next bills
## they get. Returns a sentence describing what happened.
func transfer(payer: int, payee: int, amount: int) -> String:
	var got := _pay(payer, amount)
	var sum := _loot_sum(got)
	var change: Array = []
	if sum > amount:
		change = _exact_subset(bank(payee), sum - amount)
		for c in change:
			bank(payee).erase(c)
		bank(payer).append_array(change)
	bank(payee).append_array(got)
	var parts: Array = []
	if got.is_empty():
		parts.append("%s had no bills" % nm(payer))
	else:
		parts.append("%s paid %s" % [nm(payer), CardDB.bills(sum)])
	if not change.is_empty():
		parts.append("got %s back in change" % CardDB.bills(_loot_sum(change)))
	# Out of bills? Pay the rest with gems at their pawn value, taken from the payer's
	# least-built unfinished sets (finished sets are never broken up).
	var gems: Array = []
	var gem_sum := 0
	while sum + gem_sum < amount:
		var pick := _gem_for_payment(payer, payee)
		if pick.is_empty():
			break
		var removed := _remove_from_collection(payer, pick["id"])
		_receive(payee, removed[1], removed[0])
		gems.append(removed[1]["kind"] if removed[1]["kind"] != "wild" else removed[0])
		gem_sum += CardDB.pawn_value(removed[0])
	if not gems.is_empty():
		var counts := {}
		for k in gems:
			counts[k] = counts.get(k, 0) + 1
		var names: Array = []
		for k in counts:
			names.append(a_an(CardDB.one_name(k)) if counts[k] == 1 else "%d %s" % [counts[k], CardDB.display_name(k)])
		if got.is_empty():
			parts[0] = "%s paid with %s" % [nm(payer), " and ".join(names)]
		else:
			parts.append("handed over %s" % " and ".join(names))
	if gem_sum > 0 and sum + gem_sum > amount and change.is_empty():
		change = _exact_subset(bank(payee), sum + gem_sum - amount)
		for c in change:
			bank(payee).erase(c)
		bank(payer).append_array(change)
		if not change.is_empty():
			parts.append("got %s back in change" % CardDB.bills(_loot_sum(change)))
	sum += gem_sum
	var text := " and ".join(parts) + "."
	var short := amount - sum
	if short > 0:
		# Net against anything the payee already owes, then record the rest.
		var cancel := mini(short, owes[payee])
		owes[payee] -= cancel
		short -= cancel
		owes[payer] += short
		if short > 0:
			text += " %s %s %s%s, taken from the next bills %s get." % [nm(payer), "owe" if nm(payer) == "You" else "owes", CardDB.bills(short), "" if got.is_empty() else " more", "you" if nm(payer) == "You" else "they"]
	if not got.is_empty() and owes[payee] > 0:
		_collect_debt(payee)
	return text


## Which gem a payer hands over: first a gem the payee is already collecting (in their
## collection or hand), then from the payer's least-built set. Never from a finished set,
## never a wild.
func _gem_for_payment(p: int, payee: int) -> Dictionary:
	var best := {}
	var best_score := 1e9
	var wanted := {}
	for color in CardDB.COLORS:
		if not set_cards(payee, color).is_empty():
			wanted[color] = true
	for c in hand(payee):
		if CardDB.is_treasure(c["kind"]):
			wanted[c["kind"]] = true
	for color in CardDB.COLORS:
		if is_complete(p, color):
			continue
		var cards := set_cards(p, color)
		var progress := float(cards.size()) / CardDB.set_size(color)
		for c in cards:
			if c["kind"] == "wild":
				continue
			var score := (0.0 if wanted.has(color) else 100.0) + progress * 10.0 + CardDB.pawn_value(color)
			if score < best_score:
				best_score = score
				best = c
	return best


## A player who owes bills hands them over as soon as they bank some.
func _collect_debt(p: int) -> void:
	if owes[p] <= 0 or bank(p).is_empty():
		return
	var amount: int = owes[p]
	owes[p] = 0
	var how := transfer(p, opp(p), amount)
	_event(p, "Paying what's owed: " + how, "", -1, false)


func _loot_sum(cards: Array) -> int:
	var t := 0
	for c in cards:
		t += CardDB.value(c["kind"])
	return t


func vault(p: int) -> Array:
	return players[p]["vault"]


func set_cards(p: int, color: String) -> Array:
	return players[p]["collection"][color]


func is_complete(p: int, color: String) -> bool:
	var cards := set_cards(p, color)
	if cards.size() < CardDB.set_size(color):
		return false
	for c in cards:
		if c["kind"] != "wild":
			return true
	return false


func complete_count(p: int) -> int:
	var n := 0
	for color in CardDB.COLORS:
		if is_complete(p, color):
			n += 1
	return n


func vault_count(p: int) -> int:
	var n := 0
	for c in vault(p):
		if c != null:
			n += 1
	return n


func total_cards() -> int:
	var n := deck.size() + discard.size()
	for p in players.size():
		n += hand(p).size() + vault_count(p) + bank(p).size()
		for color in CardDB.COLORS:
			n += set_cards(p, color).size()
	return n


func find_hand_card(p: int, id: int) -> Dictionary:
	for c in hand(p):
		if c["id"] == id:
			return c
	return {}


## Returns [color, card] for a card in a player's collection, or [] if missing.
func find_collection_card(p: int, id: int) -> Array:
	for color in CardDB.COLORS:
		for c in set_cards(p, color):
			if c["id"] == id:
				return [color, c]
	return []


func _remove_from_hand(p: int, id: int) -> Dictionary:
	var h := hand(p)
	for i in h.size():
		if h[i]["id"] == id:
			var c = h[i]
			h.remove_at(i)
			return c
	return {}


func _remove_from_collection(p: int, id: int) -> Array:
	for color in CardDB.COLORS:
		var cards := set_cards(p, color)
		for i in cards.size():
			if cards[i]["id"] == id:
				var c = cards[i]
				cards.remove_at(i)
				return [color, c]
	return []


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _draw_one(p: int) -> bool:
	if deck.is_empty():
		if discard.is_empty():
			return false
		deck = discard
		discard = []
		_shuffle(deck)
		_event(p, "The discard pile was shuffled into a new deck.", "", -1, false)
	hand(p).append(deck.pop_back())
	return true


func _draw(p: int, n: int) -> int:
	var got := 0
	for i in n:
		if _draw_one(p):
			got += 1
	return got


# ---------------------------------------------------------------- text

func nm(p: int) -> String:
	return players[p]["name"]


static func a_an(word: String) -> String:
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


func poss(p: int) -> String:
	return "your" if nm(p) == "You" else nm(p) + "'s"


func _event(p: int, text: String, card_kind: String, face: int, big: bool) -> void:
	events.append({"p": p, "text": text, "card": card_kind, "face": face, "big": big, "turn": turn_number})


# ---------------------------------------------------------------- turn flow

func _start_turn(first_turn := false) -> void:
	turn_number += 1
	plays_left = plays_per_turn
	free_used = false
	var n := DRAW_PER_TURN
	if hand(current).is_empty():
		n = 5
	if first_turn:
		n = 1
	var got := _draw(current, n)
	_event(current, "%s drew %d card%s." % [nm(current), got, "" if got == 1 else "s"], "", -1, false)
	if counter_owed[current] and _counter_moves(current).is_empty():
		counter_owed[current] = false
		_event(current, "No gems could be traded, so the counter-trade is lost.", "", -1, false)


## The trades a player may make with a counter-trade (same rule as a Trade card).
func _counter_moves(p: int) -> Array:
	var o := opp(p)
	var out: Array = []
	for color in CardDB.COLORS:
		if is_complete(p, color):
			continue
		for m in set_cards(p, color):
			for color2 in CardDB.COLORS:
				if is_complete(o, color2):
					continue
				for t in set_cards(o, color2):
					out.append({"type": "counter", "as": "swap", "mine": m["id"], "their": t["id"]})
	return out


## A collected gem can be pawned unless it's a wild or a finished set needs it.
func can_pawn_collected(p: int, color: String, card: Dictionary) -> bool:
	if card["kind"] == "wild":
		return false
	if not is_complete(p, color):
		return true
	var rest: Array = set_cards(p, color).filter(func(c): return c["id"] != card["id"])
	if rest.size() < CardDB.set_size(color):
		return false
	for c in rest:
		if c["kind"] != "wild":
			return true
	return false


func can_collect(p: int, card: Dictionary, color: String) -> bool:
	if is_complete(p, color):
		# An extra real gem (not a wild) can go on a finished set; the opponent pays for it.
		return card["kind"] == color
	return _can_collect_open(card, color)


func _can_collect_open(card: Dictionary, color: String) -> bool:
	if card["kind"] == "wild":
		return true
	return card["kind"] == color


## Every legal move for player p right now. Moves are small dictionaries.
func legal_moves(p: int) -> Array:
	var moves: Array = []
	if winner >= 0 or p != current:
		return moves
	var o := opp(p)
	if counter_owed[p]:
		# A counter-trade must be settled (made or skipped) before anything else.
		moves = _counter_moves(p)
		moves.append({"type": "counter_skip"})
		return moves
	if plays_left > 0:
		var empty_slot := vault(p).find(null)
		for card in hand(p):
			var kind: String = card["kind"]
			var id: int = card["id"]
			if CardDB.is_money(kind):
				moves.append({"type": "bank", "card": id})
			elif CardDB.is_treasure(kind):
				moves.append({"type": "bank", "card": id})  # pawn it for bills
				if can_collect(p, card, kind):
					moves.append({"type": "collect", "card": id, "color": kind})
			elif kind == "wild":
				for color in CardDB.COLORS:
					if can_collect(p, card, color):
						moves.append({"type": "collect", "card": id, "color": color})
			elif kind in CardDB.HEISTS:
				moves.append_array(_heist_moves(p, id, kind))
			elif kind == "lockpick" and bank_total(p) >= CardDB.cost("lockpick"):
				for s in 2:
					if vault(o)[s] != null:
						moves.append({"type": "tool", "card": id, "slot": s})
			elif kind == "lucky":
				moves.append({"type": "tool", "card": id})
			if empty_slot >= 0:
				moves.append({"type": "vault", "card": id, "slot": empty_slot})
		# Pawn a gem straight out of a collection (never a wild, never one a finished set needs).
		for color in CardDB.COLORS:
			for c in set_cards(p, color):
				if can_pawn_collected(p, color, c):
					moves.append({"type": "pawn", "card": c["id"]})
	# Free actions (no play used, no limit): take a vault card back, move a wild.
	if true:
		for s in 2:
			if vault(p)[s] != null:
				moves.append({"type": "reclaim", "slot": s})
		for from_color in CardDB.COLORS:
			for c in set_cards(p, from_color):
				if c["kind"] == "wild":
					for color in CardDB.COLORS:
						if color != from_color and not is_complete(p, color):
							moves.append({"type": "move_wild", "card": c["id"], "color": color})
	if hand(p).size() > HAND_LIMIT:
		for c in hand(p):
			moves.append({"type": "discard", "card": c["id"]})
	else:
		moves.append({"type": "end"})
	return moves


func _heist_moves(p: int, id: int, kind: String) -> Array:
	var o := opp(p)
	var out: Array = []
	if bank_total(p) < CardDB.cost(kind):
		return out
	match kind:
		"swipe":
			for color in CardDB.COLORS:
				if not is_complete(o, color):
					for c in set_cards(o, color):
						out.append({"type": "heist", "card": id, "as": "swipe", "their": c["id"]})
		"swap":
			var mine: Array = []
			var theirs: Array = []
			for color in CardDB.COLORS:
				if not is_complete(p, color):
					mine.append_array(set_cards(p, color))
				if not is_complete(o, color):
					theirs.append_array(set_cards(o, color))
			for m in mine:
				for t in theirs:
					out.append({"type": "heist", "card": id, "as": "swap", "mine": m["id"], "their": t["id"]})
		"shakedown":
			if not hand(o).is_empty():
				out.append({"type": "heist", "card": id, "as": "shakedown"})
		"grand":
			for color in CardDB.COLORS:
				if is_complete(o, color):
					out.append({"type": "heist", "card": id, "as": "grand", "color": color})
		"payup":
			# No bills? They pay with a gem at its pawn value instead (never from a finished set).
			if not bank(o).is_empty() or not _gem_for_payment(o, p).is_empty():
				out.append({"type": "heist", "card": id, "as": "payup"})
	return out


static func move_key(m: Dictionary) -> String:
	return JSON.stringify(m, "", true)


func is_legal(p: int, move: Dictionary) -> bool:
	var key := move_key(move)
	for m in legal_moves(p):
		if move_key(m) == key:
			return true
	return false


## Apply a move for the current player. Returns false (and changes nothing) if illegal.
func apply(move: Dictionary) -> bool:
	var p := current
	if not is_legal(p, move):
		return false
	match move["type"]:
		"collect":
			_do_collect(p, move)
		"vault":
			var c := _remove_from_hand(p, move["card"])
			vault(p)[move["slot"]] = c
			plays_left -= 1
			_event(p, "%s moved a card to the vault." % nm(p), "", -1, false)
		"tool":
			_do_tool(p, move)
		"bank":
			var c := _remove_from_hand(p, move["card"])
			bank(p).append(c)
			plays_left -= 1
			if CardDB.is_treasure(c["kind"]):
				_event(p, "%s pawned %s for %s." % [nm(p), a_an(CardDB.one_name(c["kind"])), CardDB.bills(CardDB.value(c["kind"]))], c["kind"], -1, false)
			else:
				_event(p, "%s banked %s." % [nm(p), CardDB.bills(CardDB.value(c["kind"]))], c["kind"], -1, false)
			_collect_debt(p)
		"pawn":
			var found := _remove_from_collection(p, move["card"])
			bank(p).append(found[1])
			plays_left -= 1
			_event(p, "%s pawned %s from %s collection for %s." % [nm(p), a_an(CardDB.one_name(found[0])), "your" if nm(p) == "You" else "their", CardDB.bills(CardDB.pawn_value(found[0]))], found[0], -1, false)
			_collect_debt(p)
		"heist":
			_do_heist_play(p, move)
		"reclaim":
			var c = vault(p)[move["slot"]]
			vault(p)[move["slot"]] = null
			hand(p).append(c)
			free_used = true
			_event(p, "%s took a card back from the vault." % nm(p), "", -1, false)
		"move_wild":
			var found := _remove_from_collection(p, move["card"])
			set_cards(p, move["color"]).append(found[1])
			free_used = true
			_event(p, "%s moved a wild to %s." % [nm(p), CardDB.display_name(move["color"])], "wild", found[1].get("face", p), false)
		"discard":
			var c := _remove_from_hand(p, move["card"])
			discard.append(c)
			_event(p, "%s discarded %s." % [nm(p), CardDB.display_name(c["kind"]) if nm(p) == "You" else "a card"], "", -1, false)
		"counter":
			counter_owed[p] = false
			var mine := _remove_from_collection(p, move["mine"])
			var theirs := _remove_from_collection(opp(p), move["their"])
			_receive(opp(p), mine[1], mine[0])
			_receive(p, theirs[1], theirs[0])
			_event(p, "Counter-trade! %s traded a %s for %s %s." % [nm(p), _card_label(mine[1], mine[0]), poss(opp(p)), _card_label(theirs[1], theirs[0])], "mirror", p, true)
		"counter_skip":
			counter_owed[p] = false
			_event(p, "%s skipped the counter-trade." % nm(p), "", -1, false)
		"end":
			current = opp(p)
			_start_turn()
	_check_winner(p)
	return true


func _check_winner(p: int) -> void:
	if winner >= 0:
		return
	for q in [p, opp(p)]:
		if complete_count(q) >= SETS_TO_WIN:
			winner = q
			_event(q, "%s completed %d sets and won!" % [nm(q), SETS_TO_WIN], "wild", q, true)
			return


func _do_collect(p: int, move: Dictionary) -> void:
	var c := _remove_from_hand(p, move["card"])
	var color: String = move["color"]
	if c["kind"] == "wild" and not c.has("face"):
		c["face"] = p
	var extra := is_complete(p, color)
	set_cards(p, color).append(c)
	plays_left -= 1
	if extra:
		var n := set_cards(p, color).size()
		var amount := extra_gem_pay(n - CardDB.set_size(color))
		var how := transfer(opp(p), p, amount)
		_event(p, "%s added %s %s %s. %s" % [nm(p), "a" if n != 8 else "an", ordinal(n), CardDB.one_name(color), how], color, -1, true)
		return
	var done := " Set complete!" if is_complete(p, color) else ""
	if c["kind"] == "wild":
		_event(p, "%s played a Wild as %s.%s" % [nm(p), a_an(CardDB.one_name(color)), done], "wild", c["face"], done != "")
	else:
		_event(p, "%s collected %s.%s" % [nm(p), a_an(CardDB.one_name(color)), done], color, -1, done != "")


func _do_tool(p: int, move: Dictionary) -> void:
	var c := _remove_from_hand(p, move["card"])
	discard.append(c)
	plays_left -= 1
	discard.append_array(_pay(p, CardDB.cost(c["kind"])))
	if c["kind"] == "lucky":
		var got := _draw(p, 2)
		_event(p, "%s played Lucky Break and drew %d." % [nm(p), got], "lucky", p, false)
	else:
		var o := opp(p)
		var target = vault(o)[move["slot"]]
		vault(o)[move["slot"]] = null
		hand(p).append(target)
		var what: String = CardDB.display_name(target["kind"])
		var label := "a %s (Defense)" % what if target["kind"] in CardDB.TRAPS else "a decoy (%s)" % what
		_event(p, "%s picked %s vault, found %s, and stole it!" % [nm(p), poss(o), label], "lockpick", p, true)


func _do_heist_play(p: int, move: Dictionary) -> void:
	var o := opp(p)
	var card := _remove_from_hand(p, move["card"])
	var kind: String = move["as"]
	if card["kind"] == "wild" and not card.has("face"):
		card["face"] = p
	plays_left -= 1
	var paid := _pay(p, CardDB.cost(kind))
	discard.append_array(paid)
	var as_text := CardDB.display_name(kind)
	if card["kind"] == "wild":
		as_text = "You're a Card! (as %s)" % as_text
	var paid_txt := " (paid %s)" % CardDB.bills(_loot_sum(paid)) if not paid.is_empty() else ""
	_event(p, "%s played %s on %s%s." % [nm(p), as_text, nm(o) if nm(o) != "You" else "you", paid_txt], kind, card.get("face", p), true)
	# Traps fire automatically, first real trap in slot order.
	for s in 2:
		var t = vault(o)[s]
		if t != null and t["kind"] in CardDB.TRAPS:
			vault(o)[s] = null
			discard.append(t)
			match t["kind"]:
				"shield":
					discard.append(card)
					_event(o, "Blocked! %s Shield stopped %s %s." % [poss(o).capitalize(), poss(p), CardDB.display_name(kind)], "shield", o, true)
				"snare":
					hand(o).append(card)
					_event(o, "Snared! %s Snare stopped %s %s, and %s kept the card." % [poss(o).capitalize(), poss(p), CardDB.display_name(kind), "you" if nm(o) == "You" else nm(o)], "snare", o, true)
					events[-1]["kept"] = card["kind"]
				"mirror":
					discard.append(card)
					if kind == "swap":
						counter_owed[o] = true
						_event(o, "Bounced! %s Mirror blocked the Trade and earns %s a counter-trade on %s next turn." % [poss(o).capitalize(), "you" if nm(o) == "You" else nm(o), "your" if nm(o) == "You" else "their"], "mirror", o, true)
					else:
						_event(o, "Reflected! %s Mirror bounced %s %s back." % [poss(o).capitalize(), poss(p), CardDB.display_name(kind)], "mirror", o, true)
						_resolve_heist(kind, o, p, true, move)
			return
	discard.append(card)
	_resolve_heist(kind, p, o, false, move)


## a = the player who benefits, v = the victim.
func _resolve_heist(kind: String, a: int, v: int, reflected: bool, move: Dictionary) -> void:
	match kind:
		"swipe":
			var found: Array = []
			if reflected:
				var best_id := _best_steal_target(a, v)
				if best_id >= 0:
					found = _remove_from_collection(v, best_id)
			else:
				found = _remove_from_collection(v, move["their"])
			if found.is_empty():
				_event(a, ("The Mirror bounced it back, but %s had no gem to steal." % nm(v)) if reflected else "There was nothing to steal.", "", -1, false)
				return
			_receive(a, found[1], found[0])
			_event(a, "%s stole %s %s." % [nm(a), poss(v), _card_label(found[1], found[0])], "swipe", a, true)
		"swap":
			if reflected:
				# The defender takes the attacker's offered card for free.
				var found := _remove_from_collection(v, move["mine"])
				if found.is_empty():
					return
				_receive(a, found[1], found[0])
				_event(a, "%s took %s %s for free." % [nm(a), poss(v), _card_label(found[1], found[0])], "swap", a, true)
			else:
				var mine := _remove_from_collection(a, move["mine"])
				var theirs := _remove_from_collection(v, move["their"])
				_receive(v, mine[1], mine[0])
				_receive(a, theirs[1], theirs[0])
				_event(a, "%s traded a %s for %s %s." % [nm(a), _card_label(mine[1], mine[0]), poss(v), _card_label(theirs[1], theirs[0])], "swap", a, true)
		"shakedown":
			if hand(v).is_empty():
				_event(a, ("The Mirror bounced it back, but %s hand was empty." % poss(v)) if reflected else "%s hand was empty." % poss(v).capitalize(), "", -1, false)
				return
			var i := rng.randi_range(0, hand(v).size() - 1)
			var c = hand(v)[i]
			hand(v).remove_at(i)
			hand(a).append(c)
			_event(a, "%s took a random card from %s hand: %s." % [nm(a), poss(v), CardDB.display_name(c["kind"])], "shakedown", a, true)
		"payup":
			var how := transfer(v, a, PAY_UP_AMOUNT)
			_event(a, ("Bounced back! " if reflected else "Pay Up! ") + how, "payup", a, true)
		"grand":
			var color := ""
			if reflected:
				var best := 0
				for col in CardDB.COLORS:
					if is_complete(v, col) and set_cards(v, col).size() > best:
						best = set_cards(v, col).size()
						color = col
			else:
				color = move["color"]
			if color == "" and reflected:
				# No finished set to take: the Mirror takes their best set in progress instead.
				var pick := _best_unfinished_set(a, v)
				if pick == "":
					_event(a, "The Mirror bounced it back, but %s had no gems to take." % nm(v), "", -1, false)
					return
				var taken: Array = set_cards(v, pick).duplicate()
				set_cards(v, pick).clear()
				for c in taken:
					_receive(a, c, pick)
				var what := CardDB.one_name(pick) if taken.size() == 1 else "%d %s" % [taken.size(), CardDB.display_name(pick)]
				_event(a, "%s had no finished set, so %s took %s %s instead!" % [nm(v), "you" if nm(a) == "You" else nm(a), "your" if nm(v) == "You" else "their", what], "grand", a, true)
				return
			if color == "":
				_event(a, "There was no complete set to take.", "", -1, false)
				return
			var cards: Array = set_cards(v, color).duplicate()
			set_cards(v, color).clear()
			set_cards(a, color).append_array(cards)
			_event(a, "%s pulled off a Grand Heist and took %s %s!" % [nm(a), poss(v), CardDB.display_name(color)], "grand", a, true)


func _card_label(card: Dictionary, color: String) -> String:
	if card["kind"] == "wild":
		return "wild (%s)" % CardDB.one_name(color)
	return CardDB.one_name(color)


func _receive(p: int, card: Dictionary, color: String) -> void:
	if is_complete(p, color):
		hand(p).append(card)
	else:
		set_cards(p, color).append(card)


## For a reflected Grand Heist when the victim has no finished set: the unfinished set
## that helps the beneficiary most (finishing one of their sets counts most).
func _best_unfinished_set(a: int, v: int) -> String:
	var best := ""
	var best_score := 0
	for color in CardDB.COLORS:
		var n := set_cards(v, color).size()
		if n == 0 or is_complete(v, color):
			continue
		var score := n
		if not is_complete(a, color):
			score += set_cards(a, color).size()
			if score >= CardDB.set_size(color):
				score += 100
		if score > best_score:
			best_score = score
			best = color
	return best


## For a reflected Heist (swipe): pick the victim's card the beneficiary most wants.
func _best_steal_target(a: int, v: int) -> int:
	var best_id := -1
	var best_score := -1.0
	for color in CardDB.COLORS:
		if is_complete(v, color):
			continue
		for c in set_cards(v, color):
			var score := float(set_cards(a, color).size()) + rng.randf() * 0.1
			if score > best_score:
				best_score = score
				best_id = c["id"]
	return best_id
