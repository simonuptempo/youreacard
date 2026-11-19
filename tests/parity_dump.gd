extends SceneTree
## Dumps bot-vs-bot games for server/test/parity.ts: /tmp/parity/games.json
func _st(g: GameState) -> Dictionary:
	var ps: Array = []
	for p in g.players:
		ps.append({"name": p["name"], "hand": p["hand"].duplicate(true), "bank": p["bank"].duplicate(true), "credit": int(p.get("credit", 0)), "vault": p["vault"].duplicate(true), "collection": p["collection"].duplicate(true)})
	return {"players": ps, "deck": g.deck.duplicate(true), "discard": g.discard.duplicate(true), "current": g.current, "plays_left": g.plays_left, "winner": g.winner, "counter_owed": g.counter_owed.duplicate(), "owes": g.owes.duplicate()}

func _init() -> void:
	var games: Array = []
	var grand_reflect := 0
	var pawned := 0
	var pick := RandomNumberGenerator.new()
	pick.seed = 7
	for i in 250:
		var g := GameState.new()
		g.setup(["Ana", "Ben"], 1000 + i, i % 2, 3)
		var gm := {"plays_per_turn": 3, "turn_number": g.turn_number, "start": _st(g), "steps": []}
		var n := 0
		while g.winner < 0 and n < 400:
			var m: Dictionary = Bot.choose_move(g, g.current)
			# Bots never pawn from a collection, so sometimes force it to test that rule.
			var pawns: Array = g.legal_moves(g.current).filter(func(x): return x["type"] == "pawn")
			if not pawns.is_empty() and pick.randf() < 0.05:
				m = pawns[pick.randi() % pawns.size()]
				pawned += 1
			var before := g.events.size()
			if not g.apply(m): break
			var texts: Array = []
			for e in g.events.slice(before): texts.append(e["text"])
			for t in texts:
				if "had no finished set, so" in t: grand_reflect += 1
			gm["steps"].append({"move": m, "after": _st(g), "texts": texts})
			n += 1
		games.append(gm)
	DirAccess.make_dir_recursive_absolute("/tmp/parity")
	var f := FileAccess.open("/tmp/parity/games.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(games))
	print("dumped ", games.size(), " games; reflected grand heists taking an unfinished set: ", grand_reflect, "; collection pawns: ", pawned)
	quit(0)
