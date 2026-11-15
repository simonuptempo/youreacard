extends SceneTree
## Headless check: bot-vs-bot games. Run with:
## godot --headless --path . -s res://tests/sim.gd

func _init() -> void:
	for plays in [3, 2]:
		var turns_total := 0
		var finished := 0
		var max_turns := 0
		var traps := 0
		var events_total := 0
		var games := 300
		for i in games:
			var g := GameState.new()
			g.setup(["You", "Juno"], i * 7919 + plays, i % 2, plays)
			var safety := 0
			while g.winner < 0 and g.turn_number < 200:
				Bot.take_turn(g, g.current)
				safety += 1
				assert(g.total_cards() == CardDB.build_deck().size(), "card count drifted")
				if g.total_cards() != CardDB.build_deck().size():
					print("CARD COUNT DRIFT game ", i, " -> ", g.total_cards())
					quit(1)
					return
				if safety > 500:
					break
			if g.winner >= 0:
				finished += 1
				turns_total += g.turn_number
				max_turns = max(max_turns, g.turn_number)
			for e in g.events:
				events_total += 1
				if e["card"] in ["shield", "mirror", "snare"]:
					traps += 1
		print("plays/turn=%d finished %d/%d, avg turns per player %.1f, max %d, trap triggers/game %.2f" % [plays, finished, games, float(turns_total) / max(1, finished) / 2.0, max_turns, float(traps) / games])
	quit(0)
