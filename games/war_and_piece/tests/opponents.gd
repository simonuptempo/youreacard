extends SceneTree
const Opponents = preload("res://games/war_and_piece/scripts/war_opponents.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var path := "user://opponent_rotation_test.cfg"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Opponents.record_win("Mei", path)
	for expected in ["Milo", "Rascal", "Felix", "Olive", "Maggie", "Mei", "Kodi", "Rosa", "Nana Bea", "Milo"]:
		assert(Opponents.peek_next(path) == expected)
		assert(Opponents.peek_next(path) == expected)
		assert(Opponents.take_next(path) == expected)
		assert(Opponents.beaten("Mei", path))
	assert(not Opponents.beaten("Fox", path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var scene = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(scene)
	var opponent: String = scene.g.nm(1)
	assert(opponent in Opponents.NAMES)
	assert(scene.has_node("AnimalOpponent"))
	var next := Opponents.peek_next()
	scene.queue_free(); await process_frame
	WarSave.resume_next = true
	scene = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(scene)
	assert(scene.g.nm(1) == opponent and Opponents.peek_next() == next)
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "": root.get_texture().get_image().save_png(out.path_join("animal-opponent.png"))
	print("OPPONENTS OK: nine characters, tenth wraps, progress preserved, preview does not advance, saved opponent persists")
	quit()
