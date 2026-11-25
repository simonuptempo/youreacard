extends SceneTree
## Cutout: a cartoon's plain background turns transparent; a photo is left alone.
func _initialize() -> void:
	var src := OS.get_environment("CARTOON")
	var t0 := Time.get_ticks_msec()
	var img: Image = Image.load_from_file(src) if src != "" else _sample()
	var out: Image = Cutout.cut(img)
	var ms := Time.get_ticks_msec() - t0
	var w := out.get_width()
	var h := out.get_height()
	assert(out.get_pixel(2, 2).a < 0.05 and out.get_pixel(w - 3, 3).a < 0.05, "corners should be transparent")
	assert(out.get_pixel(w / 2, h / 2).a > 0.95, "the face stays")
	var clear := 0
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			if out.get_pixel(x, y).a < 0.1: clear += 1
	var share := float(clear) / ((w / 8) * (h / 8))
	assert(share > 0.15 and share < 0.75, "background share %.2f" % share)
	if OS.get_environment("OUT") != "": out.save_png(OS.get_environment("OUT"))
	# A photo (no plain border) comes back untouched.
	var photo := Image.load_from_file(OS.get_environment("PHOTO")) if OS.get_environment("PHOTO") != "" else null
	if photo:
		assert(Cutout.cut(photo) == photo, "photos are left alone")
	# Already cut: unchanged. Flatten puts it back on cream for the cartoon maker.
	assert(Cutout.cut(out) == out)
	var flat := Cutout.flatten(out)
	assert(flat.get_pixel(2, 2).is_equal_approx(Cutout.CREAM))
	print("CUTOUT OK: %dx%d in %d ms, %.0f%% background cleared" % [w, h, ms, share * 100])
	quit()


## A stand-in cartoon: a face with a dark outline on a plain cream background.
func _sample() -> Image:
	var img := Image.create_empty(600, 600, false, Image.FORMAT_RGBA8)
	img.fill(Color("#f7f1e3"))
	for y in 600:
		for x in 600:
			var d := Vector2(x - 300, y - 280).length()
			if d < 150: img.set_pixel(x, y, Color("#e8b48f"))
			elif d < 158: img.set_pixel(x, y, Color("#2b2b33"))
			elif y > 420 and abs(x - 300) < 230 - (600 - y) * 0.2: img.set_pixel(x, y, Color("#7a7d86"))
	return img
