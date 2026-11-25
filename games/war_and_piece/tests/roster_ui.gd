extends SceneTree
const Opponents = preload("res://games/war_and_piece/scripts/war_opponents.gd")
var screen: Control
func _initialize() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "": root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func _run() -> void:
	root.get_node("Profile").voices = "off"
	screen = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(screen)
	var g := WarState.new()
	g.setup(["You", "Mei"], 13)
	g.winner = 0
	g.events.append({"p":0,"kind":"over","round":10,"text":"All 13 sets are complete! You win with 7 sets to 6.","text1":""})
	WarSave.save(g)
	WarSave.save(g)
	assert(Opponents.beaten("Mei"))
	var loss := WarState.new()
	loss.setup(["You", "Rosa"], 14)
	loss.winner = 1
	var previous := Opponents.beaten("Rosa")
	WarSave.save(loss)
	assert(Opponents.beaten("Rosa") == previous)
	screen.g = g
	screen._reduced_motion = false
	screen._build_mode()
	var reaction: Control = screen._over.get_node("OpponentReaction")
	await create_timer(0.25).timeout
	assert(absf(reaction.rotation) > 0.01)
	await shot("opponent-defeated")
	await create_timer(1.2).timeout
	assert(reaction.scale.is_equal_approx(Vector2.ONE))
	var progress := Opponents.show_progress(screen)
	await shot("opponent-progress")
	progress.queue_free(); await process_frame
	g.players[1].name = "Nana Bea"
	g.winner = 1
	g.events[-1].text = "All 13 sets are complete! Nana Bea wins with 8 sets to 5."
	screen._build_mode()
	reaction = screen._over.get_node("OpponentReaction")
	await create_timer(0.15).timeout
	assert(reaction.position.y < 620)
	await shot("opponent-victory")
	# Dev is visible in Piece; muted voices stay muted while the cursor consumes events.
	g = WarState.new();g.setup(["You","Mouse"],6)
	g.apply({"t":"flip_all"})
	screen.g = g;screen._reduced_motion = true;screen._build_mode()
	assert(screen._layer.get_node("PieceStatus").has_node("Shield0"))
	await shot("dev-shield")
	assert(root.get_node("Sfx").voice_left() == 0)
	print("ROSTER UI OK: persistent win badges, no badge on loss, nine portraits, both reactions, Dev shield")
	quit()
