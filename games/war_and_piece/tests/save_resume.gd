extends SceneTree
## Saving and resuming: a game stopped at any point, written to disk and read back,
## plays on exactly like the original. Pending-defense screen resume is in shield_ui.gd.
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
	quit(0)


## One move by the bots. Returns 1.
func _step_game(g: WarState) -> int:
	if g.phase() == "war":
		g.apply({"t": "flip"})
	else:
		WarBot.play_piece(g, 0)
		WarBot.play_piece(g, 1)
	return 1
