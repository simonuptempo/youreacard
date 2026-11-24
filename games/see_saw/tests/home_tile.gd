extends SceneTree
## From the You're a Card home screen: the See Saw tile says Play, opens See Saw's menu,
## Play opens the game, and the menu's back button returns home.
var _f := 0
var _step := 0
var _fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error(msg)

func _cur() -> Node:
	return current_scene

func _process(_d: float) -> bool:
	_f += 1
	if _f % 10 != 0:
		return false
	match _step:
		0:
			var profile = root.get_node("Profile")  # autoload (not a compile-time name in -s scripts)
			profile.onboarded = true
			profile.launch_checked = true
			change_scene_to_file("res://scenes/home.tscn")
		1:
			var tile: Button = null
			for c in _cur().get_children():
				if c is Button and c.accessibility_name == "See Saw":
					tile = c
			check(tile != null and not tile.disabled, "See Saw tile missing or disabled")
			var says_play := false
			for l in tile.get_children():
				if l is Label and l.text.begins_with("Play"):
					says_play = true
			check(says_play, "tile doesn't say Play")
			tile.pressed.emit()
		2:
			check(_cur().scene_file_path == "res://games/see_saw/scenes/main.tscn", "tile opened " + _cur().scene_file_path)
			for c in _cur().get_children():
				if c is Button and c.text == "Play":
					c.pressed.emit()
		3:
			check(_cur().scene_file_path == "res://games/see_saw/scenes/game.tscn", "Play opened " + _cur().scene_file_path)
			change_scene_to_file("res://games/see_saw/scenes/main.tscn")
		4:
			for c in _cur().get_children():
				if c is Button and c.tooltip_text == "Home":
					c.pressed.emit()
		5:
			check(_cur().scene_file_path == "res://scenes/home.tscn", "back went to " + _cur().scene_file_path)
			print("HOME TILE %s" % ("OK" if _fails == 0 else "FAILED"))
			quit(0 if _fails == 0 else 1)
	_step += 1
	return false
