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


func _event(p: int, text: String, kind := "") -> void:
	events.append({"p": p, "text": text, "kind": kind, "round": round_number})


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
	var a := WarCards.card_name(ups[0])
	var b := WarCards.card_name(ups[1])
	var text := ""
	if w < 0:
		text = "%s vs %s: a tie, and nobody had cards left for a war. Everyone keeps their own." % [a, b]
	elif reason == "sets":
		text = "%s vs %s: a tie! %s more locked sets, so %s %d cards." % [a, b, "You have" if w == 0 else "%s has" % nm(w), "you take" if w == 0 else "%s takes" % nm(w), pot.size()]
	elif wars > 0:
		text = "War%s! %s vs %s. %s %d cards." % ["" if wars == 1 else " x%d" % wars, a, b, "You win" if nm(w) == "You" else "%s wins" % nm(w), pot.size()]
	elif reason == "out":
		text = "%s vs %s: a tie, and %s ran out of cards for the war. %s %d cards." % [a, b, "you" if nm(opp(w)) == "You" else nm(opp(w)), "You take" if nm(w) == "You" else "%s takes" % nm(w), pot.size()]
	else:
		text = "%s beats %s. %s %d cards." % [WarCards.card_name(ups[w]), WarCards.card_name(ups[opp(w)]), "You take" if nm(w) == "You" else "%s takes" % nm(w), pot.size()]
	_event(w, text, "war" if wars > 0 else "flip")
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
	_event(-1, "Round %d: Piece! You won %d cards and %s won %d. Lock them away in sets." % [round_number, hand(0).size(), nm(1), hand(1).size()], "round")


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
	_event(p, "%s locked away %s." % [nm(p), WarCards.describe_set(cards)], "lock")
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
	_event(p, "%s added %d to %s." % [nm(p), cards.size(), WarCards.describe_set(grown)], "lock")
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
			_end_game(best, "%s locked away %d cards!" % [nm(best), locked_count(best)])
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
		_end_game(w, "%s no loose cards left for a War round." % ("You have" if hand(0).is_empty() else "%s has" % nm(1)))
		return
	round_number += 1
	for p in 2:
		var s: Array = hand(p).duplicate()
		_shuffle(s)
		players[p]["stock"] = s
		players[p]["hand"] = []
	_event(-1, "Round %d: War! You have %d loose cards and %s has %d." % [round_number, stock(0).size(), nm(1), stock(1).size()], "round")


func _end_game(w: int, why: String) -> void:
	winner = w
	if w == 2:
		_event(-1, "%s It's a draw: %d locked cards each." % [why, locked_count(0)], "over")
	else:
		_event(w, "%s %s with %d locked cards to %d." % [why, "You win" if nm(w) == "You" else "%s wins" % nm(w), locked_count(w), locked_count(opp(w))], "over")


# ------------------------------------------------------------------ saving

func to_dict() -> Dictionary:
	return {"players": players.duplicate(true), "round": round_number, "piece_done": piece_done.duplicate(),
		"winner": winner, "quiet": quiet_pieces, "locked_before": _locked_before, "events": events.duplicate(true), "rng": rng}


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
	# JSON turns ints into floats; put ranks and ids back.
	for pl in g.players:
		for key in ["stock", "won", "hand"]:
			pl[key] = pl[key].map(func(c): return {"id": int(c["id"]), "rank": int(c["rank"]), "suit": str(c["suit"])})
		pl["sets"] = pl["sets"].map(func(st): return st.map(func(c): return {"id": int(c["id"]), "rank": int(c["rank"]), "suit": str(c["suit"])}))
	return g


func total_cards() -> int:
	var n := pot.size()
	for p in 2:
		n += loose_count(p) + locked_count(p)
	return n
