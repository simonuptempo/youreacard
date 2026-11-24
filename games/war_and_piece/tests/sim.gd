extends SceneTree
## Plays many bot-vs-bot games and checks the rules hold together.
func _init() -> void:
	var games := 500
	var rounds_total := 0
	var flips_total := 0
	var wins := [0, 0, 0]
	var by_lock := 0
	var longest := 0
	var bad := 0
	for i in games:
		var g := WarState.new()
		g.setup(["You", "Computer"], i * 7919 + 13)
		var flips := 0
		var safety := 0
		while g.phase() != "over" and safety < 5000:
			safety += 1
			if g.phase() == "war":
				g.flip()
				flips += 1
			else:
				WarBot.play_piece(g, 0)
				WarBot.play_piece(g, 1)
			if g.total_cards() != 52:
				bad += 1
				push_error("card count %d in game %d" % [g.total_cards(), i])
				break
		if g.phase() != "over":
			push_error("game %d never ended" % i)
			bad += 1
			continue
		wins[g.winner] += 1
		rounds_total += g.round_number
		flips_total += flips
		longest = maxi(longest, g.round_number)
		if g.events[-1]["text"].contains("locked away") and g.events[-1]["text"].contains("!"):
			by_lock += 1
	print("games %d  wins %s  avg rounds %.1f (max %d)  avg flips %.1f  ended by 26 locked: %d  problems: %d" % [games, wins, float(rounds_total) / games, longest, float(flips_total) / games, by_lock, bad])
	quit(0)
