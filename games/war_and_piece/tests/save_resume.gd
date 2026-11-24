extends SceneTree
## Saving and resuming: a game stopped at any point, written to disk and read back,
## plays on exactly like the original. Then the real screens: play a bit, leave,
## Continue from the menu, and check the table picked up the same game.
var _step := 0
var _f := 0
var _scene
var _before := {}

func _initialize() -> void:
	var bad := 0
	var checked := 0
	for i in 200:
		var a := WarState.new()
		a.setup(["You", "Computer"], i * 104729 + 7)
		var stop := 3 + (i * 37) % 60   # stop after this many moves
		var n := 0
		while a.phase() != "over" and n < stop:
			n += _step_game(a)
		if a.phase() == "over":
			continue
		var text := JSON.stringify({"v": 1, "state": a.to_dict()})
		var b := WarState.from_dict(JSON.parse_string(text)["state"])
		checked += 1
		if JSON.stringify(b.to_dict()) != JSON.stringify(a.to_dict()):
			bad += 1
			push_error("game %d: restored state differs" % i)
			continue
		# Play both to the end, move for move.
		var safety := 0
		while a.phase() != "over" and safety < 3000:
			safety += 1
			_step_game(a)
			_step_game(b)
		if JSON.stringify(b.to_dict()) != JSON.stringify(a.to_dict()):
			bad += 1
			push_error("game %d: restored game played out differently" % i)
	print("save/resume engine: %d games checked, %d problems" % [checked, bad])
	if bad > 0:
		quit(1)
		return
	WarSave.clear()
	OS.set_environment("WAP_SEED", "5")
	_scene = load("res://games/war_and_piece/scenes/main.tscn").instantiate()
	root.add_child(_scene)


## One move by the bots. Returns 1.
func _step_game(g: WarState) -> int:
	if g.phase() == "war":
		g.apply({"t": "flip"})
	else:
		WarBot.play_piece(g, 0)
		WarBot.play_piece(g, 1)
	return 1


func _fail(msg: String) -> bool:
	push_error(msg)
	print("SAVE/RESUME FAILED: ", msg)
	quit(1)
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _f % 5 != 0:
		return false
	match _step:
		0:
			if _scene.get_node_or_null("Continue") != null:
				return _fail("menu offered Continue with no saved game")
			_scene._start_new()
		1:
			_scene = current_scene
			for k in 7:
				_scene._on_flip()
		2:
			_scene._skip_war()
			_scene._on_flip()   # on to the Piece round
		3:
			_scene._auto_arrange()   # some sets locked, not done yet
			_before = _scene.g.to_dict()
			if _scene.g.locked_count(0) == 0:
				print("(no sets this time)")
			change_scene_to_file("res://games/war_and_piece/scenes/main.tscn")
		4:
			_scene = current_scene
			if _scene.get_node_or_null("Continue") == null:
				return _fail("no Continue button on the menu")
			_scene.continue_game()
		5:
			_scene = current_scene
			if JSON.stringify(_scene.g.to_dict()) != JSON.stringify(_before):
				return _fail("Continue picked up a different game")
			if _scene.g.phase() != "piece" or _scene._lock_btn == null:
				return _fail("didn't reopen on the Piece round")
			_scene._done_piece()
			var s = _scene.get_node_or_null("Summary"); if s: s.queue_free()
			_scene._build_mode()
			_scene._on_flip()
			_before = _scene.g.to_dict()
			change_scene_to_file("res://games/war_and_piece/scenes/main.tscn")
		6:
			_scene = current_scene
			_scene.new_game()   # asks first
			if _scene.get_node_or_null("ConfirmNew") == null:
				return _fail("New Game didn't ask before replacing the saved game")
			_scene.continue_game()   # "Keep playing"
		7:
			_scene = current_scene
			if JSON.stringify(_scene.g.to_dict()) != JSON.stringify(_before):
				return _fail("Keep playing lost the game")
			if _scene._battle.is_empty():
				return _fail("the last face-off wasn't back on the table")
			# Finish the game: the save goes away.
			var g: WarState = _scene.g
			while g.phase() != "over":
				if g.phase() == "war":
					_scene._do({"t": "flip_all"})
				else:
					WarBot.arrange(g, 1)
					g.apply({"t": "done", "p": 1})
					WarBot.arrange(g, 0)
					_scene._do({"t": "done", "p": 0})
			if WarSave.has_game():
				return _fail("finished game is still saved")
			print("SAVE/RESUME UI OK")
			quit(0)
			return true
	_step += 1
	return false
