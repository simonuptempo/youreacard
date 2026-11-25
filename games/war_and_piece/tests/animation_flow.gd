extends SceneTree
var screen: Control
var out := OS.get_environment("OUT")

func _initialize() -> void:
	_run.call_deferred()

func shot(name: String) -> void:
	if out == "": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func show_scene(path: String) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
		await process_frame
	screen = load(path).instantiate()
	root.add_child(screen)
	await pause(0.2)

func fixture(a: Array, b: Array) -> WarState:
	var g := WarState.new()
	g.setup(["You", "Computer"], 5)
	var deck := WarCards.build_deck()
	for p in 2:
		g.stock(p).clear()
		var ranks: Array = a if p == 0 else b
		for rank in ranks:
			for c in deck:
				if c.rank == rank:
					g.stock(p).push_front(c)
					deck.erase(c)
					break
	g.players[1].won = deck
	return g

func _run() -> void:
	root.get_node("Profile").onboarded = true
	root.get_node("Profile").launch_checked = true
	await show_scene("res://scenes/home.tscn")
	await shot("home")
	await show_scene("res://games/war_and_piece/scenes/main.tscn")
	await shot("war-menu")
	await show_scene("res://games/see_saw/scenes/main.tscn")
	await shot("see-saw-menu")
	await show_scene("res://games/war_and_piece/scenes/game.tscn")
	screen.g = fixture([8,2,3,4,9,5,6,7,13,2], [8,2,3,4,9,5,6,7,12,3])
	screen._build_mode()
	await shot("war-ready")
	screen._on_flip()
	var after: Dictionary = screen.g.to_dict()
	screen._on_flip()
	assert(screen.g.to_dict() == after, "Repeated tap dealt extra cards")
	await pause(0.4)
	await shot("flip")
	var ties := 0
	var frames := 0
	while screen._animating:
		frames += 1
		assert(frames < 6000, "Animation stalled")
		if screen._main_btn.text in ["Go to war!", "Yet another war!"]:
			ties += 1
			assert(screen._main_btn.text == ("Go to war!" if ties == 1 else "Yet another war!"))
			await shot("tie-%d" % ties)
			screen._on_flip()
			await pause(1.3)
			await shot("war-stack-%d" % ties)
		await process_frame
	assert(ties == 2)
	assert(screen.g.last_faceoff.pot == 18 and screen.g.last_faceoff.winner == 0)
	assert(screen._battle.filter(func(v): return v.has_meta("owner")).is_empty())
	assert(not screen._main_btn.disabled)
	await shot("collected")
	screen._show_settings()
	await shot("settings")
	screen._settings.queue_free()
	await process_frame
	screen.g = fixture([8,11], [8,11,4,3])
	screen._build_mode()
	screen._reduced_motion = true
	screen._on_flip()
	while screen._animating:
		if screen._main_btn.text in ["Go to war!", "Yet another war!"]: screen._on_flip()
		await process_frame
	assert(screen.g.unclaimed.is_empty() and screen.g.total_cards() == 52)
	assert(screen._main_btn.text == "On to the Piece round")
	await shot("unclaimed")
	print("ANIMATION FLOW OK: double war, tap guard, collection, settings, reduced motion, unclaimed")
	quit()
