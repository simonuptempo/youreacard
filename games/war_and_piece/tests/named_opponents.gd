extends SceneTree
const Opponents = preload("res://games/war_and_piece/scripts/war_opponents.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var path := "user://named_opponents_test.cfg"
	var config := ConfigFile.new()
	config.set_value("beaten", "Mouse", true)
	config.set_value("rotation", "next", 4)
	config.save(path)
	assert(Opponents.beaten("Milo", path))
	assert(Opponents.take_next(path) == "Maggie")
	assert(Opponents.peek_next(path) == "Mei")
	assert(Opponents.beaten("Milo", path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var g := WarState.new()
	g.setup(["You", "Mouse"], 6)
	WarSave.save(g)
	var restored := WarSave.load_game()
	assert(restored.nm(1) == "Milo" and restored.total_cards() == 52)
	WarSave.clear()
	var menu = load("res://games/war_and_piece/scenes/main.tscn").instantiate()
	root.add_child(menu)
	assert(menu.get_node("NewGame").get_child_count() == 2)
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "": root.get_texture().get_image().save_png(out.path_join("named-opponent-menu.png"))
	menu.queue_free();await process_frame
	var screen = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(screen)
	assert(screen._main_btn.text == "Deal!")
	var sound: AudioStream = load("res://audio/sfx/wp_card_deal.wav")
	assert(sound.get_length() > 0.1 and sound.get_length() < 0.2)
	root.get_node("Sfx").enabled = true
	root.get_node("Sfx").play("wp_card_deal", -4.0)
	assert(root.get_node("Sfx")._players.any(func(p):return p.playing and p.stream == sound))
	await RenderingServer.frame_post_draw
	if out != "": root.get_texture().get_image().save_png(out.path_join("deal-button.png"))
	print("NAMES AND DEAL OK: legacy wins and saved names, portrait play button, Deal label, short sound playback")
	quit()
