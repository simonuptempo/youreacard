extends SceneTree
## Plays several full games through the game screen's own handlers (headless).
var games := 0
var started := false
var steps := 0
func _process(_d: float) -> bool:
	if not started:
		started = true
		change_scene_to_file("res://scenes/game.tscn")
		return false
	var s = current_scene
	if s == null or not ("g" in s) or s.g == null:
		return false
	steps += 1
	if steps > 20000:
		print("TOO MANY STEPS"); quit(1); return true
	if s.mode == "over":
		games += 1
		print("game %d over: winner=%d turns=%d" % [games, s.g.winner, s.g.turn_number])
		if games >= 4:
			print("UI PLAYTHROUGH OK"); quit(0); return true
		s.get_tree().reload_current_scene()
		return false
	if s._replaying and is_instance_valid(s._replay_panel):
		s._end_replay_now()
		return false
	if s._flip != null:
		s._end_coin_flip(s.g.current)
		return false
	if s.overlay != null:
		s._replay_token += 1
		s._play_next_replay()
		return false
	if s.g.current != 0 or s.mode == "busy":
		return false
	# Exercise the tap paths sometimes.
	var m: Dictionary = Bot.choose_move(s.g, 0)
	if m.is_empty():
		return false
	match m["type"]:
		"end":
			s._on_end_pressed()
		"discard":
			if s.mode != "discard":
				s._on_end_pressed()
			s._on_hand_tapped(null, m["card"])
		"heist":
			s._on_hand_tapped(null, m["card"])
			if m["as"] in ["shakedown", "payup"]:
				s._apply_and_clear(m)
			else:
				s._start_target(m["as"])
				match m["as"]:
					"swipe": s._on_chip_tapped(null, 1, m["their"], "")
					"grand": s._on_chip_tapped(null, 1, -1, m["color"])
					"swap":
						s._on_chip_tapped(null, 0, m["mine"], "")
						s._on_chip_tapped(null, 1, m["their"], "")
		"tool":
			s._on_hand_tapped(null, m["card"])
			if m.has("slot"):
				s._lockpick_random()
			else:
				s._apply_and_clear(m)
		_:
			if m.has("card") and not s.g.find_hand_card(0, m["card"]).is_empty():
				s._on_hand_tapped(null, m["card"])
			s._apply_and_clear(m)
	return false
