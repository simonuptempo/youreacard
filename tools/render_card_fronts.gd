extends SceneTree
## Renders one 750x1050 PNG per card kind (the print size inside the bleed) to /tmp/print/raw.
## Run: xvfb-run godot --rendering-driver opengl3 --path . -s res://tools/render_card_fronts.gd
## Then python3 tools/make_print_fronts.py adds the bleed and writes one file per card.
const W := 750
const H := 1050
func _initialize() -> void:
	_go()
func _go() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/print/raw")
	var CV = load("res://scripts/card_view.gd")
	var kinds: Array = []
	var counts := {}
	for c in CardDB.build_deck():
		if not kinds.has(c["kind"]):
			kinds.append(c["kind"])
		counts[c["kind"]] = counts.get(c["kind"], 0) + 1
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	for k in kinds:
		var v = CV.new()
		v.size = Vector2(W, H)
		vp.add_child(v)
		v.setup({"id": 1, "kind": k})
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("/tmp/print/raw/%s.png" % k)
		v.queue_free()
		await process_frame
	var f := FileAccess.open("/tmp/print/raw/counts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"order": kinds, "counts": counts}))
	f.close()
	quit(0)
