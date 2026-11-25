extends SceneTree
## Drives five real game screens through attacks, defenses, passes, and War.
var _game
var _frames := 0
var _games := 0

func _initialize() -> void:
	_new_game()

func _new_game() -> void:
	if _game:
		_game.queue_free()
	_game = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(_game)
	_game._reduced_motion = true

func _process(_d: float) -> bool:
	if is_instance_valid(_game) and _game.get("_animating") == true:
		if _game._main_btn.text in ["Go to war!", "Yet another war!"]:
			_game._on_flip()
		return false

	if _game._busy or _game._bot_running: return false
	var summary = _game.get_node_or_null("Summary")
	if summary:
		summary.queue_free()
		_game._build_mode()
		return false
	_frames += 1
	if _frames < 3:
		return false
	var g: WarState = _game.g
	if g.phase() == "war":
		if _frames % 2 == 0:
			_game._on_flip()
		else:
			_game._skip_war()
	elif g.phase() == "piece":
		if _game._lock_btn == null or not is_instance_valid(_game._lock_btn):
			_game._on_flip()  # "On to the Piece round"
		elif g.piece_actor() == 0:
			_game._auto_arrange()
		elif g.piece_actor() < 0:
			_game._done_piece()
	else:
		if g.total_cards() != 52 or g.total_shields() != 2:
			push_error("card count")
		_games += 1
		print("game %d over: winner %d round %d locked %d-%d" % [_games, g.winner, g.round_number, g.locked_count(0), g.locked_count(1)])
		if _games >= 5:
			print("UI PLAYTHROUGH OK")
			quit(0)
			return true
		_new_game()
	return false
