extends SceneTree
## Dumps bot games for the server's parity test (server/test/parity.ts): for each game, the
## seed, every move (some deliberately illegal), whether it was allowed, and the full state
## after it. OUT env var: the folder (default /tmp/wp_parity).
func _init() -> void:
	var out := OS.get_environment("OUT")
	if out == "":
		out = "/tmp/wp_parity"
	DirAccess.make_dir_recursive_absolute(out)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var games: Array = []
	var n := int(OS.get_environment("GAMES")) if OS.get_environment("GAMES") != "" else 300
	for gi in n:
		var seed := rng.randi()
		var g := WarState.new()
		g.setup(["Ana", "Ben"], seed)
		var steps: Array = []
		var safety := 0
		while g.phase() != "over" and safety < 4000:
			safety += 1
			var moves: Array = []
			if g.phase() == "war":
				moves.append({"t": "flip_all"} if rng.randf() < 0.15 else {"t": "flip"})
				if rng.randf() < 0.05:
					moves.append({"t": "done", "p": 0})   # illegal in War
			else:
				# Work out each side's moves on a copy, then play them in a mixed order.
				var first := rng.randi_range(0, 1)
				for p in [first, 1 - first]:
					var copy := WarState.from_dict(g.to_dict())
					var mine := WarBot.arrange(copy, p)
					if rng.randf() < 0.3 and not mine.is_empty():
						mine.resize(rng.randi_range(0, mine.size()))   # stop early sometimes
					moves.append_array(mine)
					if rng.randf() < 0.1:
						moves.append({"t": "lock", "p": p, "ids": [1, 2, 3]})   # usually not in hand / not a set
					if rng.randf() < 0.05:
						moves.append({"t": "add", "p": p, "set": 99, "ids": [5]})
					moves.append({"t": "done", "p": p})
				if rng.randf() < 0.05:
					moves.append({"t": "done", "p": 0})   # already done: illegal
			for m in moves:
				var ok := g.apply(m)
				steps.append({"move": m, "ok": ok, "after": g.to_dict()})
				if g.phase() == "over":
					break
		games.append({"seed": seed, "names": ["Ana", "Ben"], "steps": steps})
	var f := FileAccess.open(out + "/games.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(games))
	f.close()
	var total := 0
	for gm in games:
		total += gm["steps"].size()
	print("dumped %d games, %d steps to %s" % [games.size(), total, out])
	quit(0)
