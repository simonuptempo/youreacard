extends SceneTree
## Holding Deal! for 3 seconds fills the button and fast-forwards the War round.
var screen
var t0 := 0
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	WarSave.clear()
	screen = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
	root.add_child(screen)
	await create_timer(0.5).timeout
	assert(screen.g.phase() == "war")
	var btn: Button = screen._main_btn
	# A short press is still a normal deal.
	btn.button_down.emit()
	await create_timer(0.5).timeout
	assert(screen._hold_fill.size.x > 0 and screen._hold_fill.size.x < btn.size.x * 0.3)
	btn.button_up.emit()
	assert(screen._hold_fill.size.x == 0)
	# Hold for 3 seconds.
	btn.button_down.emit()
	await create_timer(1.5).timeout
	assert(screen._hold_fill.size.x > btn.size.x * 0.4 and not screen._fast)
	await create_timer(1.7).timeout
	assert(screen._fast, "fast-forward should start after 3 seconds")
	btn.button_up.emit()
	btn.pressed.emit()          # the release that ended the hold must not deal again
	t0 = Time.get_ticks_msec()
	var flips_left: int = mini(screen.g.stock(0).size(), screen.g.stock(1).size())
	while screen._fast:
		await process_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	assert(screen.g.phase() != "war", "the round should be over")
	assert(not screen._skip_release and not btn.disabled)
	assert(screen._main_btn.text != "Fast-forwarding…")
	if OS.get_environment("OUT") != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/hold-done.png")
	print("HOLD FAST-FORWARD OK: round of up to %d face-offs in %.1f s" % [flips_left, secs])
	quit()
