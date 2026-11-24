extends SceneTree
## Screenshots of each screen (needs a display: run with xvfb-run or on your Mac).
## OUT env var is the folder.
var _step := 0
var _f := 0
var _scene
var _out := OS.get_environment("OUT")

func _initialize() -> void:
	SSBest.reset()
	OS.set_environment("SEESAW_SEED", "5")
	_scene = load("res://games/see_saw/scenes/main.tscn").instantiate()
	root.add_child(_scene)

func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("shot ", name)

func _game(level: int) -> void:
	_scene.queue_free()
	OS.set_environment("SEESAW_LEVEL", str(level))
	_scene = load("res://games/see_saw/scenes/game.tscn").instantiate()
	root.add_child(_scene)

## Swap in a question of a chosen kind (so every option style gets a picture).
func _ask(kind: String) -> void:
	var g: SeeSaw = _scene.g
	var q := SSQuestions.make(kind, g.cards, g.rng)
	if not q.is_empty():
		g.questions[g.q_index] = q
	_scene._build_question()

func _process(_d: float) -> bool:
	_f += 1
	if _f % 15 != 0:
		return false
	match _step:
		0: _shot("01-menu")
		1: _scene.show_rules()
		2: _shot("02-rules")
		3: _game(1)
		4: _shot("03-ready-L1")
		5: _scene._go()
		6: _shot("04-show-L1")
		7: _scene._time_up(); _ask("nth_card")
		8: _shot("05-q-card-L1")
		9: _game(3); _scene._go()
		10: _shot("06-show-L3")
		11: _scene._time_up(); _ask("nth_suit")
		12: _shot("07-q-suit")
		13: _ask("yes_no")
		14: _shot("08-q-yesno")
		15: _game(6); _scene._go()
		16: _shot("09-show-L6")
		17:
			_scene._time_up()
			var g: SeeSaw = _scene.g
			# put a character card in so we can ask who was on it
			if SSQuestions._face_positions(g.cards).is_empty():
				g.cards[2] = SSCards.make(12, "H")
				_scene._build_question()
			_ask("character")
		18: _shot("10-q-character")
		19: _ask("where")
		20: _shot("11-q-where")
		21: _scene._pick((_scene.g.question()["answer"] + 1) % _scene.g.question()["options"].size())
		22: _shot("12-wrong")
		23: _game(12); _scene._go()
		24: _shot("13-show-L12")
		25: _scene._time_up(); _ask("not_shown")
		26: _shot("14-q-not-shown")
		27: _scene._pick(_scene.g.question()["answer"])
		28: _shot("15-right")
		29:
			_game(20); _scene._go()
		30: _shot("16-show-L20")
		31:
			root.get_node("Profile").display_name = "Simon"
			var g: SeeSaw = _scene.g
			g.level = 9; g.lives = 0; g.phase = "over"
			_scene._advance()
		32: _shot("17-game-over")
		33:
			var profile = root.get_node("Profile")
			profile.onboarded = true
			profile.launch_checked = true
			_scene.queue_free()
			_scene = load("res://scenes/home.tscn").instantiate()
			root.add_child(_scene)
		34: _shot("00-home")
		35: quit(0)
	_step += 1
	return false
