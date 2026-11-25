extends SceneTree
## End-to-end: this Godot client hosts an invite game against a scripted player,
## through the real gem-heist server code (run locally by tests/run_online_e2e.sh).
var phase := "start"
var steps := 0
var replays := 0
var my_moves := 0

func _process(_d: float) -> bool:
	steps += 1
	if root.get_node("Profile").birth_year != 1990:
		root.get_node("Profile").birth_year = 1990  # always an adult player here (AgeGate)
		root.get_node("Profile").birth_month = 1
	if steps > 200000:
		print("E2E TIMEOUT in phase ", phase); quit(1); return true
	if phase == "start":
		phase = "signing"
		_host()
		return false
	if phase != "playing":
		return false
	var s = current_scene
	if s == null or not ("g" in s) or s.g == null:
		return false
	if s.mode == "over":
		print("E2E game over. winner (my view)=", s.g.winner, " my moves=", my_moves, " replays seen=", replays, " events=", s.g.events.size())
		print("E2E OK")
		quit(0)
		return true
	if s._replaying and is_instance_valid(s._replay_panel):
		replays += 1
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
	var m: Dictionary = Bot.choose_move(s.g, 0)
	if m.is_empty():
		return false
	my_moves += 1
	if m["type"] == "end":
		s._on_end_pressed()
	elif m["type"] == "discard":
		s.mode = "discard"
		s._on_hand_tapped(null, m["card"])
	else:
		s._apply_and_clear(m)
	return false

func _host() -> void:
	var O = root.get_node("Online")
	var err = await O.sign_in_guest("Ana")
	print("A signed in: ", err == "", " name=", O.name_or("?"))
	var r = await O.call_fn("create_invite")
	var code: String = r["data"]["code"]
	print("A invite code: ", code)
	var f = FileAccess.open("/tmp/yac_code.txt", FileAccess.WRITE)
	f.store_string(code)
	f.close()
	while true:
		await create_timer(0.3).timeout
		var st = await O.call_fn("invite_status", {"code": code})
		if st["ok"] and st["data"]["status"] == "pending":
			print("A sees guest: ", st["data"]["guest_name"])
			break
	var acc = await O.call_fn("respond_invite", {"code": code, "accept": true})
	print("A accepted, game ", acc["data"]["game_id"])
	O.game_id = str(acc["data"]["game_id"])
	change_scene_to_file("res://scenes/game.tscn")
	phase = "playing"
