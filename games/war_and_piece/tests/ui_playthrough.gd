extends SceneTree
## Drives the real game screen from start to finish (Auto-arrange, Done, Flip / Skip).
var _game
var _frames := 0
var _games := 0

func _initialize() -> void:
	_new_game()

func _new_game() -> void:
	if _game:
		_game.queue_free()
	_game = load("res://games/war_and_piece/wp_table.tscn").instantiate()
	root.add_child(_game)

func _process(_d: float) -> bool:
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
		else:
			_game._auto_arrange()
			_game._done_piece()
			var s = _game.get_node_or_null("Summary")
			if s: s.queue_free()
			_game._build_mode()
	else:
		if g.total_cards() != 52:
			push_error("card count")
		_games += 1
		print("game %d over: winner %d round %d locked %d-%d" % [_games, g.winner, g.round_number, g.locked_count(0), g.locked_count(1)])
		if _games >= 5:
			print("UI PLAYTHROUGH OK")
			quit(0)
			return true
		_new_game()
	return false
