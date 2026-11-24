extends SceneTree
func _init() -> void:
	var hist := {}
	var stuck := 0
	for i in 1000:
		var g := WarState.new()
		g.setup(["You", "Computer"], i * 7919 + 13)
		var n := 0
		while g.phase() != "over" and g.round_number < 60:
			if g.phase() == "war": g.flip()
			else:
				WarBot.play_piece(g, 0); WarBot.play_piece(g, 1)
		if g.phase() != "over":
			stuck += 1
			if stuck <= 2:
				print("stuck seed ", i, " loose ", g.loose_count(0), "/", g.loose_count(1), " locked ", g.locked_count(0), "/", g.locked_count(1))
			continue
		var k := mini(g.round_number, 20)
		hist[k] = hist.get(k, 0) + 1
	var ks := hist.keys(); ks.sort()
	var s := ""
	for k in ks: s += "%d:%d " % [k, hist[k]]
	print(s, " stuck ", stuck)
	quit()
