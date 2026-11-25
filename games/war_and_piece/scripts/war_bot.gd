class_name WarBot

static func plan(hand: Array, _locked: Array) -> Dictionary:
	var result := {"new": [], "add": [], "count": 0}
	for rank in range(2, 15):
		var group := hand.filter(func(c): return int(c["rank"]) == rank)
		if WarCards.set_type(group) != "":
			result["new"].append(group.map(func(c): return int(c["id"])))
			result["count"] += 4
	return result

static func next_move(g: WarState, p: int) -> Dictionary:
	if g.phase() != "piece": return {}
	if g.piece_actor() < 0:
		return {"t": "done", "p": p} if not g.piece_done[p] else {}
	if g.piece_actor() != p: return {}
	var options := g.heist_options(p)
	options.sort_custom(func(a, b):
		var ca := g.hand(p).filter(func(c): return c.rank == a.rank).size()
		var cb := g.hand(p).filter(func(c): return c.rank == b.rank).size()
		return ca > cb if ca != cb else a.rank > b.rank)
	if options.is_empty(): return {"t": "pass", "p": p}
	return {"t": "heist", "p": p, "rank": options[0].rank, "suit": options[0].suit}

static func arrange(g: WarState, p: int) -> Array:
	var move := next_move(g, p)
	return [move] if not move.is_empty() and g.apply(move) else []

static func play_piece(g: WarState, p: int) -> Array:
	return arrange(g, p)
