class_name WarState
extends RefCounted
## War: higher cards win; three down/one up on ties for every tie.
## Piece: four suits bank automatically. Three heists: trailing, leading, trailing.
## Pairs/triples may steal a missing suit; a private, single-use shield can block it.
## Banked sets are safe. Play alternates until all 13 ranks are banked.
## Exhausted ties return evenly to Piece hands so every set remains obtainable.

const NAMES := ["You", "Computer"]

var rules_version := 5
var shields := [0, 0]
var shield_pool := 2
var shields_spent := 0
var shield_draws := [[], []] # private insertion points, indexed by rank cards remaining
var heist_order: Array = []
var heist_step := 0
var pending_heist: Dictionary = {}
var _heist_options: Array = []
var heist_used := [false, false]
var _server_view := false
var _allowed_heists: Array = []
var players: Array = []      # {name, stock, won, hand, sets: [[cards]]}
var round_number := 1        # odd = War, even = Piece
var unclaimed: Array = []    # exhausted ties: neither player owns these cards
var pot: Array = []          # cards on the table in the current face-off
var last_faceoff: Dictionary = {}  # what the UI shows for the latest flip
var piece_done := [false, false]
var quiet_pieces := 0       # Piece rounds in a row where nobody locked anything
var _locked_before := 0
var winner := -1             # -1 playing, 0/1 a player, 2 a draw
var events: Array = []       # {p, text, kind}
var rng := 1


func setup(names: Array, seed: int) -> void:
	rng = seed if seed != 0 else 1
	players.clear()
	for n in names:
		players.append({"name": n, "stock": [], "won": [], "hand": [], "sets": []})
	var deck := WarCards.build_deck()
	_shuffle(deck)
	for i in deck.size():
		players[i % 2]["stock"].append(deck[i])
	round_number = 1
	winner = -1
	_place_shields()
	_event(-1, "Round 1: War! Each of you has 26 cards.", "round")


# ------------------------------------------------------------------ helpers

func phase() -> String:
	if winner >= 0:
		return "over"
	return "war" if round_number % 2 == 1 else "piece"


func opp(p: int) -> int:
	return 1 - p


func nm(p: int) -> String:
	return players[p]["name"]


func stock(p: int) -> Array:
	return players[p]["stock"]


func hand(p: int) -> Array:
	return players[p]["hand"]


func sets(p: int) -> Array:
	return players[p]["sets"]


func locked_count(p: int) -> int:
	var n := 0
	for s in sets(p):
		n += s.size()
	return n


## Every card a player still has in play (not locked).
func loose_count(p: int) -> int:
	return stock(p).size() + players[p]["won"].size() + hand(p).size()


## An event is worded for each player: "You take 2 cards" for one, "Ana takes 2 cards"
## for the other. text is for player 0, text1 for player 1.
## say is a String (the same for both) or a Callable(viewer) -> String.
func _event(p: int, say, kind := "") -> void:
	var t0: String = say.call(0) if say is Callable else str(say)
	var t1: String = say.call(1) if say is Callable else str(say)
	events.append({"p": p, "text": t0, "text1": t1, "kind": kind, "round": round_number})


## "You" or the player's name, to start a sentence.
func _who(p: int, v: int) -> String:
	return "You" if p == v else nm(p)


## "you" or the player's name, mid-sentence.
func _whom(p: int, v: int) -> String:
	return "you" if p == v else nm(p)


## Subject and verb: _sv(p, v, "take", "takes") -> "You take" / "Ana takes".
func _sv(p: int, v: int, you_form: String, other_form: String) -> String:
	return "You " + you_form if p == v else nm(p) + " " + other_form


## The same, mid-sentence: "you take" / "Ana takes".
func _svl(p: int, v: int, you_form: String, other_form: String) -> String:
	return "you " + you_form if p == v else nm(p) + " " + other_form


func _rand() -> float:
	# mulberry32, kept in the state so a game can be replayed exactly
	rng = (rng + 0x6D2B79F5) & 0xFFFFFFFF
	var t := rng
	t = _imul(t ^ (t >> 15), t | 1)
	t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := int(_rand() * (i + 1))
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ------------------------------------------------------------------ moves

## Every change to a game goes through here, as a small dictionary, so a game can be
## saved, replayed, checked against the server's copy, or sent over the internet:
##   {"t": "flip"}                      one face-off (War)
##   {"t": "flip_all"}                  flip to the end of the War round
##   {"t": "heist", "p": 0, "rank": 9, "suit": "H"} attempt a missing-card steal
##   {"t": "pass", "p": 0}             pass this heist
##   {"t": "lock", "p": 0, "ids": [..]} lock a new set (Piece)
##   {"t": "add", "p": 0, "set": 2, "ids": [..]} add to a locked set (Piece)
##   {"t": "done", "p": 0}              finished arranging (Piece)
## Returns false (and changes nothing) if the move isn't allowed right now.
func apply(m: Dictionary) -> bool:
	var t := str(m.get("t", ""))
	var p := int(m.get("p", -1))
	match t:
		"flip":
			if phase() != "war":
				return false
			flip()
			return true
		"flip_all":
			if phase() != "war":
				return false
			while phase() == "war":
				flip()
			return true
		"heist":
			return p in [0, 1] and heist(p, int(m.get("rank", -1)), str(m.get("suit", "")))
		"defend":
			return false # Shields resolve automatically with the attack.
		"pass":
			return p in [0, 1] and pass_heist(p)
		"lock":
			return p in [0, 1] and typeof(m.get("ids")) == TYPE_ARRAY and lock_set(p, _ints(m["ids"]))
		"add":
			return p in [0, 1] and typeof(m.get("ids")) == TYPE_ARRAY and add_to_set(p, int(m.get("set", -1)), _ints(m["ids"]))
		"done":
			if p not in [0, 1] or phase() != "piece" or piece_done[p] or piece_actor() >= 0:
				return false
			finish_piece(p)
			return true
	return false


static func _ints(a: Array) -> Array:
	var out: Array = []
	for x in a:
		var n := int(x)
		if n in out:
			return []   # the same card twice isn't a set
		out.append(n)
	return out


## One player leaves: the other wins.
func resign(p: int) -> void:
	if winner >= 0:
		return
	winner = opp(p)
	_event(p, func(v): return "%s the game." % _sv(p, v, "left", "left"), "over")


# ------------------------------------------------------------------ War

## Flip once (one face-off, including any wars it turns into). Returns what happened,
## for the table to animate: {cards: [[p0 cards...],[p1 cards...]], ups: [card0, card1],
## winner: p, wars: n, reason}.
func flip() -> Dictionary:
	if phase() != "war":
		return {}
	var shown := [[], []]
	var ups := [null, null]
	var wars := 0
	pot.clear()
	for p in 2:
		var c: Dictionary = _draw_war_card(p)
		pot.append(c)
		shown[p].append(c)
		ups[p] = c
	var w := -1
	var reason := ""
	while true:
		var r0: int = ups[0]["rank"]
		var r1: int = ups[1]["rank"]
		if r0 != r1:
			w = 0 if r0 > r1 else 1
			break
		# Both contribute equally; the last available card is face-up.
		if stock(0).is_empty() or stock(1).is_empty():
			w = -1
			reason = "unclaimed"
			break
		wars += 1
		var n := mini(WarCards.WAR_DOWN + 1, mini(stock(0).size(), stock(1).size()))
		for p in 2:
			for k in n:
				var c: Dictionary = _draw_war_card(p)
				pot.append(c)
				shown[p].append(c)
				ups[p] = c
	var r := {"cards": shown, "ups": ups, "winner": w, "wars": wars, "reason": reason, "pot": pot.size()}
	if w >= 0:
		players[w]["won"].append_array(pot)
	else:
		# Keep the cards accounted for, but out of both players' winnings.
		unclaimed.append_array(pot)
	var n := pot.size()
	var say := func(v: int) -> String:
		var mine := WarCards.card_name(ups[v])
		var theirs := WarCards.card_name(ups[1 - v])
		if w < 0:
			return "Still tied! %d cards set aside to split in Piece. On to the Piece round." % n
		if wars > 0:
			return "War%s! %s vs %s. %s %d cards." % ["" if wars == 1 else " x%d" % wars, mine, theirs, _sv(w, v, "win", "wins"), n]
		if reason == "out":
			return "%s vs %s: a tie, and %s ran out of cards for the war. %s %d cards." % [mine, theirs, _whom(1 - w, v), _sv(w, v, "take", "takes"), n]
		return "%s beats %s. %s %d cards." % [WarCards.card_name(ups[w]), WarCards.card_name(ups[1 - w]), _sv(w, v, "take", "takes"), n]
	_event(w, say, "war" if wars > 0 else "flip")
	pot = []
	last_faceoff = r
	if stock(0).is_empty() or stock(1).is_empty():
		_end_war_round()
	return r


func _end_war_round() -> void:
	# Undrawn shields stay in the deck; held/spent shields never return to it.
	for p in 2:
		shield_pool += shield_draws[p].size()
		shield_draws[p] = []
	for p in 2:
		players[p]["hand"] = players[p]["won"] + players[p]["stock"]
		players[p]["won"] = []
		players[p]["stock"] = []
	round_number += 1
	_return_unclaimed()
	piece_done = [false, false]
	heist_used = [false, false]
	_locked_before = locked_count(0) + locked_count(1)
	_event(-1, "Round %d: Piece! Bank complete ranks, then take turns heisting." % round_number, "round")
	for p in 2:
		auto_bank(p)
	_plan_heists()


# ------------------------------------------------------------------ Piece

## Complete ranks are banked as soon as the Piece round begins, or after a heist.
func auto_bank(p: int) -> void:
	if phase() != "piece":
		return
	for rank in range(2, 15):
		var group: Array = hand(p).filter(func(c): return int(c["rank"]) == rank)
		if WarCards.set_type(group) != "":
			lock_set(p, group.map(func(c): return int(c["id"])))


## Shields are secretly interleaved among rank-card draws, never exposed in public counts.
func _return_unclaimed() -> void:
	if unclaimed.is_empty(): return
	var count := unclaimed.size()
	_shuffle(unclaimed)
	var first := 0 if hand(0).size() <= hand(1).size() else 1
	for i in unclaimed.size(): hand((first + i) % 2).append(unclaimed[i])
	unclaimed = []
	_event(-1, "%d tied cards split evenly into Piece hands. Every set stays in play." % count, "reclaim")


func _place_shields() -> void:
	var total := stock(0).size() + stock(1).size()
	if total == 0: return
	while shield_pool > 0:
		var slot := int(_rand() * total)
		var p := 0 if slot < stock(0).size() else 1
		var position := slot + 1 if p == 0 else slot - stock(0).size() + 1
		shield_draws[p].append(position)
		shield_pool -= 1


func _draw_war_card(p: int) -> Dictionary:
	var remaining := stock(p).size()
	while remaining in shield_draws[p]:
		shield_draws[p].erase(remaining)
		shields[p] += 1
	return stock(p).pop_back()


func total_shields() -> int:
	return shields[0] + shields[1] + shield_pool + shields_spent + shield_draws[0].size() + shield_draws[1].size()


func _plan_heists() -> void:
	if check_complete(): return
	var first := (int(round_number / 2) - 1) % 2
	if sets(0).size() != sets(1).size():
		first = 0 if sets(0).size() < sets(1).size() else 1
	heist_order = [first, 1 - first, first]
	heist_step = 0
	pending_heist = {}


func piece_actor() -> int:
	if phase() != "piece": return -1
	if not pending_heist.is_empty(): return 1 - int(pending_heist["attacker"])
	return int(heist_order[heist_step]) if heist_step < heist_order.size() else -1


func heist_options(p: int, rank := -1) -> Array:
	if p not in [0, 1] or piece_actor() != p or not pending_heist.is_empty(): return []
	if _server_view:
		return _heist_options.filter(func(o): return rank < 0 or int(o["rank"]) == rank) if p == 0 else []
	var options: Array = []
	for r in range(2, 15):
		if rank >= 0 and rank != r: continue
		var group := hand(p).filter(func(c): return int(c["rank"]) == r)
		if group.size() not in [1, 2, 3]: continue
		for suit in WarCards.SUITS:
			if hand(opp(p)).any(func(c): return int(c["rank"]) == r and c["suit"] == suit):
				options.append({"rank": r, "suit": suit})
	return options


func can_heist(p: int, rank: int) -> bool:
	return not heist_options(p, rank).is_empty()


func heist(p: int, rank: int, suit := "") -> bool:
	if _server_view: return false
	var options := heist_options(p, rank)
	if suit != "": options = options.filter(func(o): return o["suit"] == suit)
	if options.is_empty(): return false
	pending_heist = {"attacker": p, "rank": rank, "suit": options[0]["suit"]}
	var card := WarCards.card_name(pending_heist)
	_event(p, func(v): return "%s to steal the %s." % [_sv(p, v, "try", "tries"), card], "heist_start")
	return _resolve_heist()


func _resolve_heist() -> bool:
	if _server_view or pending_heist.is_empty(): return false
	var p := 1 - int(pending_heist["attacker"])
	var block: bool = shields[p] > 0
	var attacker := int(pending_heist["attacker"])
	var rank := int(pending_heist["rank"])
	var suit := str(pending_heist["suit"])
	var card_name := WarCards.card_name(pending_heist)
	if block:
		shields[p] -= 1
		shields_spent += 1
		_event(p, func(v): return "%s the heist with a shield!" % _sv(p, v, "block", "blocks"), "shield")
	else:
		for card in hand(p).duplicate():
			if int(card["rank"]) == rank and card["suit"] == suit:
				hand(p).erase(card)
				hand(attacker).append(card)
				break
		_event(attacker, func(v): return "%s the %s." % [_sv(attacker, v, "stole", "stole"), card_name], "heist")
		auto_bank(attacker)
	heist_used[attacker] = true
	pending_heist = {}
	heist_step += 1
	return true


func pass_heist(p: int) -> bool:
	if piece_actor() != p or not pending_heist.is_empty(): return false
	heist_used[p] = true
	heist_step += 1
	_event(p, func(v): return "%s this heist." % _sv(p, v, "pass", "passes"), "pass")
	return true


## Keep existing saves playable: incomplete legacy sets return to their owner's cards.
func _upgrade_four_suits() -> void:
	if rules_version >= 2:
		return
	rules_version = 2
	heist_used = [false, false]
	if winner >= 0:
		return
	for p in 2:
		var kept: Array = []
		for st in sets(p):
			if WarCards.set_type(st) != "":
				kept.append(st)
			else:
				players[p]["hand" if phase() == "piece" else "stock"].append_array(st)
		players[p]["sets"] = kept
	_locked_before = locked_count(0) + locked_count(1)
	quiet_pieces = 0
	_event(-1, "New Piece rules: four suits make a set. Incomplete banked groups return to their owner's cards.", "rules")
	if phase() == "piece":
		piece_done = [false, false]
		for p in 2:
			auto_bank(p)


func upgrade_rules() -> void:
	if rules_version >= 5: return
	var previous := rules_version
	_upgrade_shields()
	rules_version = 5
	if winner < 0:
		if previous < 4: _event(-1, "Keep playing War and Piece until all 13 sets are complete.", "rules")
		if not pending_heist.is_empty(): _resolve_heist()
		_event(-1, "Shields now block heists automatically.", "rules")


func _upgrade_shields() -> void:
	if rules_version >= 3: return
	_upgrade_four_suits()
	rules_version = 3
	shields = [0, 0]
	shield_pool = 2
	shields_spent = 0
	shield_draws = [[], []]
	if winner >= 0: return
	if phase() == "war":
		_place_shields()
	else:
		_plan_heists()
		for p in 2:
			if heist_used[p]: heist_order.erase(p)
		piece_done = [false, false]
	_event(-1, "Piece now uses three heist turns. Two secret shields can be found during War.", "rules")


## Lock a new set from your hand. Returns false if those cards aren't a set.
func lock_set(p: int, ids: Array) -> bool:
	if phase() != "piece" or piece_done[p]:
		return false
	var cards := _take_from_hand(p, ids, false)
	if cards.size() != ids.size() or WarCards.set_type(cards) == "":
		return false
	_take_from_hand(p, ids, true)
	sets(p).append(WarCards.sort_hand(cards))
	var what := WarCards.describe_set(cards)
	_event(p, func(v): return "%s banked %s." % [_who(p, v), what], "lock")
	check_complete()
	return true


## Add cards from your hand to one of your locked sets (it must still be a set).
func add_to_set(p: int, set_index: int, ids: Array) -> bool:
	if phase() != "piece" or piece_done[p] or set_index < 0 or set_index >= sets(p).size():
		return false
	var cards := _take_from_hand(p, ids, false)
	if cards.size() != ids.size() or cards.is_empty():
		return false
	var grown: Array = sets(p)[set_index] + cards
	if WarCards.set_type(grown) == "":
		return false
	_take_from_hand(p, ids, true)
	sets(p)[set_index] = WarCards.sort_hand(grown)
	var what := WarCards.describe_set(grown)
	var k := cards.size()
	_event(p, func(v): return "%s added %d to %s." % [_who(p, v), k, what], "lock")
	return true


func can_add(p: int, set_index: int, ids: Array) -> bool:
	if set_index < 0 or set_index >= sets(p).size():
		return false
	var cards := _take_from_hand(p, ids, false)
	return cards.size() == ids.size() and not cards.is_empty() and WarCards.set_type(sets(p)[set_index] + cards) != ""


func _take_from_hand(p: int, ids: Array, remove: bool) -> Array:
	var out: Array = []
	for id in ids:
		for c in hand(p):
			if c["id"] == id:
				out.append(c)
				break
	if remove:
		for c in out:
			hand(p).erase(c)
	return out


## Finish your Piece round. When both are done, the game checks for a winner and
## starts the next War round with everyone's loose cards.
func finish_piece(p: int) -> void:
	if phase() != "piece" or piece_actor() >= 0:
		return
	piece_done[p] = true
	if piece_done[0] and piece_done[1]:
		_start_war_round()


func _start_war_round() -> void:
	# Also reclaim reserves carried by older saved games.
	_return_unclaimed()
	for p in 2: auto_bank(p)
	if sets(0).size() + sets(1).size() == 13:
		var a := sets(0).size()
		var b := sets(1).size()
		_end_game(0 if a > b else (1 if b > a else 2), "All 13 sets are complete!")
		return
	if sets(0).size() + sets(1).size() == 12:
		# One set left. A showdown only breaks a 6-6 tie; otherwise the last set can't
		# change the result, so the leader wins now.
		if sets(0).size() == sets(1).size():
			_final_showdown()
		else:
			_end_game(0 if sets(0).size() > sets(1).size() else 1, "Only one set is left, and it can't change the result!")
		return
	quiet_pieces = 0
	# A fresh deal of loose cards keeps both players in War if one deck is empty.
	if hand(0).is_empty() or hand(1).is_empty():
		var loose: Array = hand(0) + hand(1)
		_shuffle(loose)
		players[0]["hand"] = []
		players[1]["hand"] = []
		for i in loose.size(): hand(i % 2).append(loose[i])
		_event(-1, "The remaining loose cards are dealt evenly for the next War.", "redeal")
	round_number += 1
	for p in 2:
		var s: Array = hand(p).duplicate()
		_shuffle(s)
		players[p]["stock"] = s
		players[p]["hand"] = []
	_place_shields()
	_event(-1, func(v): return "Round %d: War! You have %d loose cards and %s has %d." % [round_number, stock(v).size(), nm(1 - v), stock(1 - v).size()], "round")


func _final_showdown() -> void:
	var deck := WarCards.build_deck()
	_shuffle(deck)
	var draws: Array = [[], []]
	var w := -1
	var totals := [0, 0]
	while w < 0:
		for i in 5:
			if deck.size() < 2:
				deck = WarCards.build_deck()
				_shuffle(deck)
			for p in 2:
				var card: Dictionary = deck.pop_back()
				draws[p].append(card)
				totals[p] += int(card.rank)
		if totals[0] != totals[1]: w = 0 if totals[0] > totals[1] else 1
	var final_set: Array = hand(0) + hand(1)
	players[0]["hand"] = []
	players[1]["hand"] = []
	sets(w).append(WarCards.sort_hand(final_set))
	last_faceoff = {"cards": draws, "ups": [draws[0][-1], draws[1][-1]], "winner": w, "wars": int(draws[0].size() / 5) - 1, "reason": "final_showdown", "pot": 4}
	_event(w, func(v): return "%s the final showdown and completed the last set!" % _sv(w, v, "win", "wins"), "showdown")
	_end_game(0 if sets(0).size() > sets(1).size() else 1, "All 13 sets are complete!")


func check_complete() -> bool:
	if winner >= 0: return true
	if sets(0).size() + sets(1).size() != 13: return false
	heist_order = []
	pending_heist = {}
	_end_game(0 if sets(0).size() > sets(1).size() else 1, "All 13 sets are complete!")
	return true


func _end_game(w: int, why) -> void:
	winner = w
	var a := sets(0).size()
	var b := sets(1).size()
	var reason := func(v: int) -> String: return why.call(v) if why is Callable else str(why)
	if w == 2:
		_event(-1, func(v): return "%s It's a draw: %d banked sets each." % [reason.call(v), a], "over")
	else:
		var mine := a if w == 0 else b
		var theirs := b if w == 0 else a
		_event(w, func(v): return "%s %s with %d banked sets to %d." % [reason.call(v), _sv(w, v, "win", "wins"), mine, theirs], "over")


# ------------------------------------------------------------------ saving

func to_dict() -> Dictionary:
	return {"shields": shields.duplicate(), "shield_pool": shield_pool, "shields_spent": shields_spent,
		"shield_draws": shield_draws.duplicate(true), "heist_order": heist_order.duplicate(), "heist_step": heist_step,
		"pending_heist": pending_heist.duplicate(true), "rules_version": rules_version, "heist_used": heist_used.duplicate(), "players": players.duplicate(true), "round": round_number, "piece_done": piece_done.duplicate(),
		"winner": winner, "quiet": quiet_pieces, "locked_before": _locked_before, "events": events.duplicate(true), "rng": rng,
		"last_faceoff": last_faceoff.duplicate(true), "unclaimed": unclaimed.duplicate(true)}


static func from_dict(d: Dictionary) -> WarState:
	var g := WarState.new()
	g.players = d["players"].duplicate(true)
	g.rules_version = int(d.get("rules_version", 1))
	g.shields = d.get("shields", [0, 0]).map(func(x): return int(x))
	g.shield_pool = int(d.get("shield_pool", 0))
	g.shields_spent = int(d.get("shields_spent", 0))
	g.shield_draws = d.get("shield_draws", [[], []]).map(func(a): return a.map(func(x): return int(x)))
	g.heist_order = d.get("heist_order", []).map(func(x): return int(x))
	g.heist_step = int(d.get("heist_step", 0))
	g.pending_heist = d.get("pending_heist", {}).duplicate(true)
	if not g.pending_heist.is_empty():
		g.pending_heist["attacker"] = int(g.pending_heist["attacker"])
		g.pending_heist["rank"] = int(g.pending_heist["rank"])
	g._heist_options = d.get("heist_options", []).duplicate(true)
	g.heist_used = d.get("heist_used", [false, false]).map(func(x): return bool(x))
	g._server_view = d.has("allowed_heists")
	g._allowed_heists = d.get("allowed_heists", []).map(func(x): return int(x))
	g.unclaimed = d.get("unclaimed", []).map(_card)
	g.round_number = int(d["round"])
	g.piece_done = d["piece_done"].duplicate()
	g.winner = int(d["winner"])
	g.events = d["events"].duplicate(true)
	g.rng = int(d["rng"])
	g.quiet_pieces = int(d.get("quiet", 0))
	g._locked_before = int(d.get("locked_before", 0))
	g.piece_done = [bool(g.piece_done[0]), bool(g.piece_done[1])]
	# JSON turns ints into floats; put ranks, ids and players back.
	for pl in g.players:
		pl["name"] = str(pl["name"])
		for key in ["stock", "won", "hand"]:
			pl[key] = pl[key].map(_card)
		pl["sets"] = pl["sets"].map(func(st): return st.map(_card))
	for e in g.events:
		e["p"] = int(e["p"])
		e["round"] = int(e.get("round", 0))
		if not e.has("text1"):
			e["text1"] = e["text"]
	var lf = d.get("last_faceoff", {})
	if typeof(lf) == TYPE_DICTIONARY and lf.has("ups"):
		g.last_faceoff = {"cards": lf["cards"].map(func(a): return a.map(_card)), "ups": lf["ups"].map(func(c): return null if c == null else _card(c)),
			"winner": int(lf["winner"]), "wars": int(lf["wars"]), "reason": str(lf["reason"]), "pot": int(lf["pot"])}
	g.upgrade_rules()
	return g


static func _card(c) -> Dictionary:
	return {"id": int(c["id"]), "rank": int(c["rank"]), "suit": str(c["suit"])}


func total_cards() -> int:
	var n := pot.size() + unclaimed.size()
	for p in 2:
		n += loose_count(p) + locked_count(p)
	return n
