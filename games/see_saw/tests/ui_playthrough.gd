extends SceneTree
## Drives the real screens end to end: menu -> Play -> Go -> time's up -> answer
## (right for a few levels, then wrong until out of lives) -> game over -> best saved
## -> Play again, three games in a row.
var _scene
var _f := 0
var _games := 0
var _target := 0          # answer right until this level, then go wrong
var _fails := 0


func _initialize() -> void:
	SSBest.reset()
	OS.set_environment("SEESAW_SEED", "11")
	_scene = load("res://games/see_saw/scenes/main.tscn").instantiate()
	root.add_child(_scene)


func check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error(msg)


func _process(_d: float) -> bool:
	_f += 1
	if _f % 2 != 0:
		return false
	var cur = root.get_child(root.get_child_count() - 1)
	if cur.scene_file_path.ends_with("main.tscn"):
		if _games >= 3:
			print("UI PLAYTHROUGH %s" % ("OK" if _fails == 0 else "FAILED"))
			quit(0 if _fails == 0 else 1)
			return true
		var lbl: Label = cur.get_node("Best")
		if _games > 0:
			check(lbl.text == "Best: Level %d" % SSBest.get_best(), "menu best label: " + lbl.text)
		change_scene_to_file("res://games/see_saw/scenes/game.tscn")
		return false
	var game = cur
	var g: SeeSaw = game.g
	match g.phase:
		"ready":
			_target = [4, 7, 2][_games]
			game._go()
			check(game._views.size() == g.level, "shown %d cards at level %d" % [game._views.size(), g.level])
			for v in game._views:
				check(not v.face_down, "card face down while showing")
				check(v.position.x >= 0 and v.position.x + v.size.x <= 720 and v.position.y + v.size.y <= 1140, "card off screen at level %d" % g.level)
		"show":
			game._time_up()
			check(game._opts.size() == g.question()["options"].size(), "options on screen")
			for v in game._views:
				check(v.face_down, "card face up while asking")
		"ask":
			var q: Dictionary = g.question()
			var right: int = q["answer"]
			var pick: int = right if g.level < _target else (right + 1) % q["options"].size()
			var lives := g.lives
			game._pick(pick)
			if pick != right:
				check(g.lives == lives - 1, "life not lost")
				check(game._hearts.lives == g.lives, "hearts not updated")
			else:
				# skip the little "Right!" pause
				if g.phase == "ask":
					game._build_question()
		"between":
			game._advance()
		"over":
			if game._over == null:
				game._advance()
				check(game._over != null, "no game over screen")
				check(g.score() == _target, "score %d, expected %d" % [g.score(), _target])
				print("game %d: reached level %d, best %d, new best %s" % [_games + 1, g.score(), SSBest.get_best(), game.new_best])
				check(SSBest.get_best() == [4, 7, 7][_games], "best not saved")
				_games += 1
				if _games < 3 and _games % 2 == 1:
					reload_current_scene.call_deferred()  # Play again
				else:
					change_scene_to_file("res://games/see_saw/scenes/main.tscn")
	return false
