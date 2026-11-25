extends SceneTree
## Sacrifice: an action card goes to the discard pile for the bills it would have cost.
## Prints a line the server test (server/test/sacrifice.ts) must match exactly.
func _initialize() -> void:
	var g := GameState.new()
	g.setup(["You", "Juno"], 4242, 0, 3)
	var p := g.current
	g.players[p]["bank"] = []
	g.players[p]["credit"] = 0
	var heist := {"id": 9001, "kind": "swipe"}
	var grand := {"id": 9002, "kind": "grand"}
	g.hand(p).append(heist)
	g.hand(p).append(grand)
	var moves := g.legal_moves(p)
	assert(moves.any(func(m): return m["type"] == "sacrifice" and m["card"] == 9001))
	# Free cards (Lucky Break, defenses, Pay Up, wilds, money, gems) can't be sacrificed.
	for m in moves:
		if m["type"] == "sacrifice":
			assert(CardDB.cost(g.find_hand_card(p, m["card"])["kind"]) > 0)
	var plays: int = g.plays_left
	var discards: int = g.discard.size()
	assert(g.apply({"type": "sacrifice", "card": 9001}))
	assert(g.bank_total(p) == 2 and g.plays_left == plays - 1 and g.discard.size() == discards + 1)
	assert(g.find_hand_card(p, 9001).is_empty())
	assert(g.apply({"type": "sacrifice", "card": 9002}))
	assert(g.bank_total(p) == 7)
	print("SACRIFICE OK: ", g.events[-2]["text"], " | ", g.events[-1]["text"])
	quit()
