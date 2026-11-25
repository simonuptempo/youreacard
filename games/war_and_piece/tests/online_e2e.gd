extends SceneTree
## Online end to end: this Godot client is player A (Ana) against a scripted player B, with
## the real war-and-piece function on a local stand-in for Supabase (server/test/run_e2e.sh).
## Ana signs up, makes an invite, lets Ben in, then plays the game to the end on the real table.
var Online: Node
var _f := 0
var _stage := "start"
var _code_written := false
var _flips := 0
var _waits := 0
var _summaries := 0
var _started := 0
var _shots := {}

## Screenshots (OUT env var) the first time each moment comes up.
func _shot(name: String) -> void:
	var out := OS.get_environment("OUT")
	if out == "" or _shots.has(name):
		return
	_shots[name] = true
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func _process(_d: float) -> bool:
	_f += 1
	if root.get_node("Profile").birth_year == 0:
		root.get_node("Profile").birth_year = 1990  # an adult player (AgeGate)
		root.get_node("Profile").birth_month = 1
	if _f == 2:
		Online = root.get_node("/root/Online")
		_start()
		return false
	if _f < 5 or _stage == "signing up":
		return false
	if Time.get_ticks_msec() - _started > 240000:
		print("E2E FAILED: timed out in stage ", _stage)
		quit(1)
		return true
	var sc = current_scene
	match _stage:
		"invite":
			if sc != null and sc.has_method("_show_invite") and not _code_written and sc._invite_code != "":
				var f := FileAccess.open("/tmp/wp_code.txt", FileAccess.WRITE)
				f.store_string(sc._invite_code)
				f.close()
				_code_written = true
				print("A invite code ", sc._invite_code)
			if _code_written:
				_shot("o1-invite")
			if sc != null and sc.has_method("_show_invite") and is_instance_valid(sc._overlay):
				_shot("o2-confirm")
				print("A lets Ben in")
				sc._set_answer(1)
			if sc != null and sc.has_method("_online_move"):
				_stage = "play"
		"play":
			if sc == null or not sc.has_method("_online_move") or sc.g == null or sc._layer == null:
				return false
			for n in ["CatchUp"]:
				var o = sc.get_node_or_null(n)
				if o: o.queue_free()
			var s = sc.get_node_or_null("Summary")
			if s:
				_shot("o5-summary")
				_summaries += 1
				s.queue_free()
				sc._build_mode()
				return false
			if sc.get_node_or_null("Waiting"):
				if _waits == 5:
					_shot("o4-waiting")
				_waits += 1
				return false
			if sc._busy or sc._pumping:
				return false
			var g = sc.g
			match g.phase():
				"war":
					if _flips == 3:
						_shot("o3-war")
					if _f % 3 == 0:
						if _flips % 5 == 4:
							sc._skip_war()
						else:
							sc._on_flip()
						_flips += 1
				"piece":
					if sc._lock_btn == null or not is_instance_valid(sc._lock_btn):
						sc._on_flip()   # "On to the Piece round"
					elif not sc._main_btn.disabled:
						sc._auto_arrange()
						sc._done_piece()
				"over":
					print("A sees: ", g.events[-1]["text"])
					if g.total_cards() != 52:
						print("E2E FAILED: card count ", g.total_cards())
						quit(1)
						return true
					if sc._over == null:
						return false
					_shot("o6-over")
					print("E2E OK: %d flips/skips by A, waited for Ben in %d frames, %d Piece summaries, final %d-%d" % [_flips, _waits, _summaries, g.locked_count(0), g.locked_count(1)])
					quit(0)
					return true
	return false


func _start() -> void:
	_started = Time.get_ticks_msec()
	_stage = "signing up"
	var err: String = await Online.sign_up_email("ana@example.com", "secret1", "Ana")
	if err != "":
		print("E2E FAILED: sign up: ", err)
		quit(1)
		return
	print("A signed up as ", Online.name_or("?"))
	change_scene_to_file("res://games/war_and_piece/scenes/online.tscn")
	await process_frame
	await process_frame
	current_scene._show_invite()
	_stage = "invite"
