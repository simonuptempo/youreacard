extends SceneTree

func card(rank: int, id: int) -> Dictionary:
	return {"id": id, "rank": rank, "suit": "S" if id % 2 == 0 else "H"}

func make_game(a: Array, b: Array) -> WarState:
	var g := WarState.new()
	g.setup(["You", "Computer"], 1)
	for p in 2:
		g.players[p]["stock"] = []
		var ranks: Array = a if p == 0 else b
		for i in ranks.size():
			g.stock(p).push_front(card(ranks[i], p * 100 + i))
	return g

func _init() -> void:
	# Initial tie, then limited war. Equal contributions; unused stock remains theirs.
	var g := make_game([8, 2, 13], [8, 3, 10, 9, 7, 6])
	var r := g.flip()
	assert(r.cards[0].size() == 3 and r.cards[1].size() == 3)
	assert(r.winner == 0 and r.pot == 6 and g.hand(1).size() == 3)
	assert(g.total_cards() == 9 and g.phase() == "piece")
	g = make_game([8, 11], [8, 11, 4, 3])
	r = g.flip()
	assert(r.winner == -1 and r.reason == "unclaimed" and g.unclaimed.is_empty())
	assert(g.hand(0).size() == 2 and g.hand(1).size() == 4)
	var restored := WarState.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert(restored.unclaimed.is_empty() and restored.total_cards() == 6)
	assert(restored.phase() == "piece")
	g = make_game([8], [8, 4, 3])
	g.flip()
	assert(g.unclaimed.is_empty() and g.total_cards() == 4)
	g = make_game([8, 2, 3, 4, 9, 2, 3, 4, 14], [8, 2, 3, 4, 9, 2, 3, 4, 10])
	r = g.flip()
	assert(r.wars == 2 and r.pot == 18 and r.winner == 0)
	assert(g.total_cards() == 18)
	var old := g.to_dict()
	old.erase("unclaimed")
	assert(WarState.from_dict(old).unclaimed.is_empty())
	# Banked sets must never award a tied face-off: both sevens start a war.
	g = make_game([7, 2, 3, 4, 14, 6], [7, 2, 3, 4, 10, 5])
	g.players[1]["sets"] = [WarCards.build_deck().filter(func(c): return c.rank == 12)]
	r = g.flip()
	assert(r.wars == 1 and r.pot == 10 and r.winner == 0 and r.reason != "sets")
	print("WAR EDGE CASES OK")
	quit()
