class_name Bot
extends RefCounted
## Simple heuristic opponent. Scores every legal move and plays the best one.


static func take_turn(g: GameState, p: int) -> void:
	var guard := 0
	while g.winner < 0 and g.current == p and guard < 40:
		guard += 1
		var move := choose_move(g, p)
		if move.is_empty():
			break
		g.apply(move)


static func choose_move(g: GameState, p: int) -> Dictionary:
	var moves := g.legal_moves(p)
	if moves.is_empty():
		return {}
	# Play first: pick the best useful play, if any.
	var best: Dictionary = {}
	var best_score := 0.0
	for m in moves:
		if m["type"] in ["end", "discard"]:
			continue
		var base := score(g, p, m)
		if base <= 0.0:
			continue  # never make a move the bot considers pointless
		var s := base + g.rng.randf() * 2.0
		if s > best_score:
			best_score = s
			best = m
	if not best.is_empty():
		return best
	# Nothing useful left: discard down to the hand limit, least useful card first.
	var discards := moves.filter(func(m): return m["type"] == "discard")
	if not discards.is_empty():
		var worst: Dictionary = discards[0]
		var worst_score := INF
		for m in discards:
			var ks := keep_value(g, p, g.find_hand_card(p, m["card"]))
			if ks < worst_score:
				worst_score = ks
				worst = m
		return worst
	return {"type": "end"}


static func keep_value(g: GameState, p: int, card: Dictionary) -> float:
	var kind: String = card["kind"]
	if CardDB.is_money(kind):
		return 4.0 + CardDB.value(kind)
	if CardDB.is_treasure(kind):
		if g.is_complete(p, kind):
			return 0.0
		return 5.0 + g.set_cards(p, kind).size() * 2.0
	match kind:
		"wild": return 30.0
		"grand": return 25.0
		"lucky": return 6.0
		"lockpick": return 7.0
	if kind in CardDB.TRAPS:
		return 9.0
	return 11.0


static func _progress(g: GameState, p: int, color: String) -> float:
	return float(g.set_cards(p, color).size()) / float(CardDB.set_size(color))


static func score(g: GameState, p: int, m: Dictionary) -> float:
	var o := g.opp(p)
	var risk := g.vault_count(o) * 7.0
	match m["type"]:
		"counter":
			var mine := g.find_collection_card(p, m["mine"])
			var theirs := g.find_collection_card(o, m["their"])
			var gain := 6.0 * g.set_cards(p, theirs[0]).size() - 6.0 * g.set_cards(p, mine[0]).size()
			if g.set_cards(p, theirs[0]).size() + 1 >= CardDB.set_size(theirs[0]) and mine[0] != theirs[0]:
				gain += 40.0
			if mine[1]["kind"] == "wild":
				gain -= 12.0
			return 2.0 + gain
		"counter_skip":
			return 1.0
		"bank":
			var bc := g.find_hand_card(p, m["card"])
			if CardDB.is_treasure(bc["kind"]):
				# Pawn a gem only when that set is out of reach (they already own it).
				var col: String = bc["kind"]
				if g.is_complete(o, col) and not g.is_complete(p, col):
					return 9.0 + CardDB.value(col)
				return 0.5
			var need := 0
			for c in g.hand(p):
				need = maxi(need, CardDB.cost(c["kind"]))
			var bt := g.bank_total(p)
			if bt < 3:
				return 19.0 + CardDB.value(bc["kind"])
			if bt < need + 2:
				return 15.0 + CardDB.value(bc["kind"])
			return 6.0 + CardDB.value(bc["kind"]) * 0.5
		"collect":
			var color: String = m["color"]
			var card := g.find_hand_card(p, m["card"])
			if g.is_complete(p, color):
				return 30.0  # an extra gem on a finished set: they pay us (or owe us)
			var completes := g.set_cards(p, color).size() + 1 >= CardDB.set_size(color)
			if card["kind"] == "wild":
				return 75.0 if completes else 3.0 + 6.0 * _progress(g, p, color)
			return (70.0 if completes else 20.0 + 12.0 * _progress(g, p, color))
		"heist":
			var card := g.find_hand_card(p, m["card"])
			var wild_penalty := 12.0 if card["kind"] == "wild" else 0.0
			match m["as"]:
				"grand":
					return 120.0 - risk * 0.5 - wild_penalty
				"swipe":
					var found := g.find_collection_card(o, m["their"])
					var color: String = found[0]
					var s := 22.0 + 12.0 * g.set_cards(p, color).size() + 10.0 * _progress(g, o, color)
					if g.set_cards(p, color).size() + 1 >= CardDB.set_size(color):
						s += 40.0
					if found[1]["kind"] == "wild":
						s += 6.0
					return s - risk - wild_penalty - 2.0 * CardDB.cost("swipe")
				"swap":
					var mine := g.find_collection_card(p, m["mine"])
					var theirs := g.find_collection_card(o, m["their"])
					var gain := 6.0 * g.set_cards(p, theirs[0]).size() - 6.0 * g.set_cards(p, mine[0]).size()
					if g.set_cards(p, theirs[0]).size() + 1 >= CardDB.set_size(theirs[0]) and mine[0] != theirs[0]:
						gain += 40.0
					return 10.0 + gain - risk - wild_penalty
				"shakedown":
					return 8.0 + 2.0 * g.hand(o).size() - risk - wild_penalty - 2.0 * CardDB.cost("shakedown")
				"payup":
					var worth := mini(GameState.PAY_UP_AMOUNT, g.bank_total(o)) * 3.0
					if g.bank_total(o) <= 0:
						worth = 5.0   # they'll pay with a gem
					return 10.0 + worth - risk - wild_penalty
		"tool":
			var card := g.find_hand_card(p, m["card"])
			if card["kind"] == "lucky":
				return 12.0
			var has_heist := false
			for c in g.hand(p):
				if c["kind"] in CardDB.HEISTS:
					has_heist = true
			return 30.0 if has_heist else 14.0  # it steals the card, so worth it even without a heist
		"vault":
			var card := g.find_hand_card(p, m["card"])
			var kind: String = card["kind"]
			if kind in CardDB.TRAPS:
				return 18.0
			if CardDB.is_treasure(kind) and g.is_complete(p, kind):
				return 8.0
			return -1.0
		"move_wild":
			var color: String = m["color"]
			var from := g.find_collection_card(p, m["card"])
			if not from.is_empty() and g.is_complete(p, from[0]):
				return -1.0  # don't break a finished set to finish another
			if g.set_cards(p, color).size() + 1 >= CardDB.set_size(color):
				return 50.0
			return -1.0
	return -1.0
