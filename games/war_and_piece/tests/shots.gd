extends SceneTree
## Screenshots of each screen: OUT env var is the folder.
var _step := 0
var _pre := 0
var _f := 0
var _scene
var _out := OS.get_environment("OUT")

func _initialize() -> void:
	OS.set_environment("WAP_SEED", "2")
	# A game in progress, so the menu shows Continue.
	var g := WarState.new()
	g.setup(["You", "Computer"], 99)
	g.apply({"t": "flip_all"})
	WarBot.play_piece(g, 0)
	WarBot.play_piece(g, 1)
	g.apply({"t": "flip"})
	WarSave.save(g)
	# First the You're a Card home screen, with War and Piece's tile.
	_scene = null

func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("shot ", name)

func _process(_d: float) -> bool:
	_f += 1
	if _f % 20 != 0:
		return false
	if _pre < 2:
		if _pre == 0:
			root.get_node("/root/Profile").onboarded = true
			root.get_node("/root/Profile").launch_checked = true
			_scene = load("res://scenes/home.tscn").instantiate()
			root.add_child(_scene)
		else:
			_shot("0-home")
			_scene.queue_free()
			_scene = load("res://games/war_and_piece/scenes/main.tscn").instantiate()
			root.add_child(_scene)
		_pre += 1
		return false
	match _step:
		0: _shot("1-menu")
		1:
			_scene.show_rules()
		2:
			_shot("2-rules")
			WarSave.clear()
			_scene.queue_free()
			_scene = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
			root.add_child(_scene)
		3: _shot("3-war-start")
		4:
			# flip until a war happens (or 40 flips)
			for i in 40:
				_scene._on_flip()
				if _scene.g.last_faceoff.get("wars", 0) > 0 or _scene.g.stock(0).size() < 3:
					break
		5: _shot("4-war")
		6: _scene._skip_war()
		7: _shot("5-war-end")
		8: _scene._on_flip()
		9: _shot("6-piece")
		10:
			var g: WarState = _scene.g
			var pl := WarBot.plan(g.hand(0), g.sets(0))
			if pl["new"].size() > 0:
				g.lock_set(0, pl["new"][0])
			if pl["new"].size() > 1:
				_scene._sel = pl["new"][1].duplicate()
			_scene._sync_piece()
		11: _shot("7-piece-selected")
		12: _scene._done_piece()
		13: _shot("8-summary")
		14:
			var s = _scene.get_node_or_null("Summary"); if s: s.queue_free()
			var g: WarState = _scene.g
			while g.phase() != "over":
				if g.phase() == "war": g.flip()
				else:
					WarBot.play_piece(g, 0); WarBot.play_piece(g, 1)
			_scene._build_mode()
		15: _shot("9-over")
		16: quit(0)
	_step += 1
	return false
