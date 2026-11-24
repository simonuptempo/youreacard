class_name WarState
extends RefCounted
## War and Piece rules. Odd rounds are War, even rounds are Piece.
##
## WAR: each player flips the top card of their stock; the higher card wins both, and
## won cards go to that player's winnings (not back into play). A tie is a war: each
## side puts down 3 face-down cards and 1 face-up, and the face-up cards decide who
## takes everything. A player with more locked sets wins ties outright. The round ends
## when either stock runs out; any cards still in a stock are kept by their owner.
##
## PIECE: each player sorts their winnings into sets: 3+ of a kind, or 3+ in a row of
## one suit (Aces high). Sets are locked away for good: they can't be lost, they count
## toward winning, and they win ties in War. A card can also be added to a locked set.
## Whatever isn't locked is shuffled into a new stock for the next War round.
##
## WINNING: lock away 30 of the 52 cards. If a War round can't start because a
## player has no loose cards left, the game ends and whoever locked more cards wins.

const NAMES := ["You", "Computer"]

var players: Array = []      # {name, stock, won, hand, sets: [[cards]]}
var round_number := 1        # odd = War, even = Piece
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
		"lock":
			return p in [0, 1] and typeof(m.get("ids")) == TYPE_ARRAY and lock_set(p, _ints(m["ids"]))
		"add":
			return p in [0, 1] and typeof(m.get("ids")) == TYPE_ARRAY and add_to_set(p, int(m.get("set", -1)), _ints(m["ids"]))
		"done":
			if p not in [0, 1] or phase() != "piece" or piece_done[p]:
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
		var c: Dictionary = stock(p).pop_back()
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
		# A tie. More locked sets wins it outright.
		if sets(0).size() != sets(1).size():
			w = 0 if sets(0).size() > sets(1).size() else 1
			reason = "sets"
			break
		# War: three down, one up. Short of cards? Put down what you have, last one up.
		if stock(0).is_empty() or stock(1).is_empty():
			if stock(0).is_empty() and stock(1).is_empty():
				w = -1
				reason = "split"
			else:
				w = 0 if stock(1).is_empty() else 1
				reason = "out"
			break
		wars += 1
		for p in 2:
			var n := mini(WarCards.WAR_DOWN + 1, stock(p).size())
			for k in n:
				var c: Dictionary = stock(p).pop_back()
				pot.append(c)
				shown[p].append(c)
				ups[p] = c
	var r := {"cards": shown, "ups": ups, "winner": w, "wars": wars, "reason": reason, "pot": pot.size()}
	if w >= 0:
		players[w]["won"].append_array(pot)
	else:
		# Nobody can fight on: everyone keeps their own cards.
		for p in 2:
			players[p]["won"].append_array(shown[p])
	var n := pot.size()
	var say := func(v: int) -> String:
		var mine := WarCards.card_name(ups[v])
		var theirs := WarCards.card_name(ups[1 - v])
		if w < 0:
			return "%s vs %s: a tie, and nobody had cards left for a war. Everyone keeps their own." % [mine, theirs]
		if reason == "sets":
			return "%s vs %s: a tie! %s more locked sets, so %s %d cards." % [mine, theirs, _sv(w, v, "have", "has"), _svl(w, v, "take", "takes"), n]
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
	for p in 2:
		players[p]["hand"] = players[p]["won"] + players[p]["stock"]
		players[p]["won"] = []
		players[p]["stock"] = []
	round_number += 1
	piece_done = [false, false]
	_locked_before = locked_count(0) + locked_count(1)
	_event(-1, func(v): return "Round %d: Piece! You won %d cards and %s won %d. Lock them away in sets." % [round_number, hand(v).size(), nm(1 - v), hand(1 - v).size()], "round")


# ------------------------------------------------------------------ Piece

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
	_event(p, func(v): return "%s locked away %s." % [_who(p, v), what], "lock")
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
	if phase() != "piece":
		return
	piece_done[p] = true
	if piece_done[0] and piece_done[1]:
		_start_war_round()


func _start_war_round() -> void:
	var best := 0 if locked_count(0) >= locked_count(1) else 1
	if locked_count(best) >= WarCards.WIN_LOCKED:
		if locked_count(0) == locked_count(1):
			_end_game(2, "You both locked away %d cards!" % locked_count(0))
		else:
			var lc := locked_count(best)
			_end_game(best, func(v): return "%s locked away %d cards!" % [_who(best, v), lc])
		return
	quiet_pieces = quiet_pieces + 1 if locked_count(0) + locked_count(1) == _locked_before else 0
	if quiet_pieces >= 2:
		var a0 := locked_count(0)
		var b0 := locked_count(1)
		_end_game(0 if a0 > b0 else (1 if b0 > a0 else 2), "No new sets for two Piece rounds in a row, so the game ends.")
		return
	if hand(0).is_empty() or hand(1).is_empty():
		var a := locked_count(0)
		var b := locked_count(1)
		var w := 0 if a > b else (1 if b > a else 2)
		var empty := 0 if hand(0).is_empty() else 1
		_end_game(w, func(v): return "%s no loose cards left for a War round." % _sv(empty, v, "have", "has"))
		return
	round_number += 1
	for p in 2:
		var s: Array = hand(p).duplicate()
		_shuffle(s)
		players[p]["stock"] = s
		players[p]["hand"] = []
	_event(-1, func(v): return "Round %d: War! You have %d loose cards and %s has %d." % [round_number, stock(v).size(), nm(1 - v), stock(1 - v).size()], "round")


func _end_game(w: int, why) -> void:
	winner = w
	var a := locked_count(0)
	var b := locked_count(1)
	var reason := func(v: int) -> String: return why.call(v) if why is Callable else str(why)
	if w == 2:
		_event(-1, func(v): return "%s It's a draw: %d locked cards each." % [reason.call(v), a], "over")
	else:
		var mine := a if w == 0 else b
		var theirs := b if w == 0 else a
		_event(w, func(v): return "%s %s with %d locked cards to %d." % [reason.call(v), _sv(w, v, "win", "wins"), mine, theirs], "over")


# ------------------------------------------------------------------ saving

func to_dict() -> Dictionary:
	return {"players": players.duplicate(true), "round": round_number, "piece_done": piece_done.duplicate(),
		"winner": winner, "quiet": quiet_pieces, "locked_before": _locked_before, "events": events.duplicate(true), "rng": rng,
		"last_faceoff": last_faceoff.duplicate(true)}


static func from_dict(d: Dictionary) -> WarState:
	var g := WarState.new()
	g.players = d["players"].duplicate(true)
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
	return g


static func _card(c) -> Dictionary:
	return {"id": int(c["id"]), "rank": int(c["rank"]), "suit": str(c["suit"])}


func total_cards() -> int:
	var n := pot.size()
	for p in 2:
		n += loose_count(p) + locked_count(p)
	return n
