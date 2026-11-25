class_name Cutout
## Makes the plain background of a cartoon portrait transparent, so cartoons sit on cards
## and coins without a white square around them.
##
## The cartoon maker is asked for a plain, flat background. This finds that color around the
## border and flood-fills inward from the edges, so only background connected to the edge
## goes (a cream shirt in the middle stays). Photos, whose borders aren't one plain color,
## are left alone.

const TOLERANCE := 38.0        # how far (0-255 per channel) a color can be and still count as background
const PLAIN_BORDER := 0.6      # share of the border that must match for it to be a plain background
const STRICT_BORDER := 0.9     # for pictures that might be photos (older portraits): be sure it's plain
const WORK_SIZE := 512         # the mask is worked out at this size, then smoothly scaled up
const CREAM := Color("#f6f0e1")


## A copy of `src` with its plain background made transparent, or `src` unchanged when
## its background isn't plain (a photo) or is already transparent.
static func cut(src: Image, plain_border := PLAIN_BORDER) -> Image:
	if src == null or src.is_empty():
		return src
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if img.get_pixel(0, 0).a < 0.1 and img.get_pixel(w - 1, h - 1).a < 0.1:
		return src   # already cut out

	# Work out the mask on a small copy (fast, and the scale-up softens the edge).
	var small := img.duplicate() as Image
	var k := minf(1.0, float(WORK_SIZE) / maxi(w, h))
	var sw := maxi(8, int(w * k))
	var sh := maxi(8, int(h * k))
	small.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var px := small.get_data()

	var bg := _border_color(px, sw, sh, plain_border)
	if bg.is_empty():
		return src   # not a plain background: leave it (a photo)
	var br: int = bg[0]
	var bgg: int = bg[1]
	var bb: int = bg[2]
	var tol2 := int(TOLERANCE * TOLERANCE)

	var n := sw * sh
	var mask := PackedByteArray()
	mask.resize(n)   # 1 = background
	var queue := PackedInt32Array()
	queue.resize(n)
	var head := 0
	var tail := 0
	for x in sw:
		for y in [0, sh - 1]:
			var i: int = y * sw + x
			if mask[i] == 0 and _close(px, i, br, bgg, bb, tol2):
				mask[i] = 1
				queue[tail] = i
				tail += 1
	for y in sh:
		for x in [0, sw - 1]:
			var i: int = y * sw + x
			if mask[i] == 0 and _close(px, i, br, bgg, bb, tol2):
				mask[i] = 1
				queue[tail] = i
				tail += 1
	while head < tail:
		var i := queue[head]
		head += 1
		var x := i % sw
		var y := i / sw
		if x > 0 and mask[i - 1] == 0 and _close(px, i - 1, br, bgg, bb, tol2):
			mask[i - 1] = 1
			queue[tail] = i - 1
			tail += 1
		if x < sw - 1 and mask[i + 1] == 0 and _close(px, i + 1, br, bgg, bb, tol2):
			mask[i + 1] = 1
			queue[tail] = i + 1
			tail += 1
		if y > 0 and mask[i - sw] == 0 and _close(px, i - sw, br, bgg, bb, tol2):
			mask[i - sw] = 1
			queue[tail] = i - sw
			tail += 1
		if y < sh - 1 and mask[i + sw] == 0 and _close(px, i + sw, br, bgg, bb, tol2):
			mask[i + sw] = 1
			queue[tail] = i + sw
			tail += 1
	if tail > n * 0.97:
		return src   # everything matched: something's off, keep the picture as it was

	# Alpha: background 0, the rest 255, and a soft step on the border pixels next to the
	# background (anti-aliased outline pixels that are partly background color).
	var alpha := PackedByteArray()
	alpha.resize(n)
	for i in n:
		if mask[i] == 1:
			alpha[i] = 0
			continue
		var x := i % sw
		var y := i / sw
		var edge := (x > 0 and mask[i - 1] == 1) or (x < sw - 1 and mask[i + 1] == 1) \
			or (y > 0 and mask[i - sw] == 1) or (y < sh - 1 and mask[i + sw] == 1)
		if edge:
			var dr := int(px[i * 4]) - br
			var dg := int(px[i * 4 + 1]) - bgg
			var db := int(px[i * 4 + 2]) - bb
			var d := sqrt(float(dr * dr + dg * dg + db * db))
			alpha[i] = int(clampf(d / (TOLERANCE * 2.5), 0.35, 1.0) * 255.0)
		else:
			alpha[i] = 255
	var a_img := Image.create_from_data(sw, sh, false, Image.FORMAT_L8, alpha)
	a_img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var a := a_img.get_data()
	var full := img.get_data()
	for i in w * h:
		var v := a[i]
		if v < full[i * 4 + 3]:
			full[i * 4 + 3] = v
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, full)


## For sending a cut-out cartoon back to the cartoon maker (JPEG has no transparency):
## the picture on the plain cream background it was drawn on.
static func flatten(src: Image, background := CREAM) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if not img.detect_alpha():
		return img
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(background)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return out


static func _close(px: PackedByteArray, i: int, r: int, g: int, b: int, tol2: int) -> bool:
	var dr := int(px[i * 4]) - r
	var dg := int(px[i * 4 + 1]) - g
	var db := int(px[i * 4 + 2]) - b
	return dr * dr + dg * dg + db * db <= tol2


## The background color if most of the border is one plain color, else [].
static func _border_color(px: PackedByteArray, w: int, h: int, plain_border: float) -> Array:
	var rs: Array = []
	var gs: Array = []
	var bs: Array = []
	var idx: Array = []
	var step := maxi(1, int(w / 64))
	for x in range(0, w, step):
		idx.append(x)
		idx.append((h - 1) * w + x)
	for y in range(0, h, step):
		idx.append(y * w)
		idx.append(y * w + w - 1)
	for i in idx:
		rs.append(int(px[i * 4]))
		gs.append(int(px[i * 4 + 1]))
		bs.append(int(px[i * 4 + 2]))
	rs.sort()
	gs.sort()
	bs.sort()
	var m := rs.size() / 2
	var bg := [rs[m], gs[m], bs[m]]
	var tol2 := int(TOLERANCE * TOLERANCE)
	var hits := 0
	for i in idx:
		if _close(px, i, bg[0], bg[1], bg[2], tol2):
			hits += 1
	return bg if float(hits) / idx.size() >= plain_border else []
