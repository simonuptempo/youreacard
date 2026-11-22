@tool
class_name AvatarView
extends Control
## Procedural "paper doll" avatar. Avatars are saved as small dictionaries of option
## indices (never images). An optional role draws that card's costume on top.

const SKIN := ["#ffe8d9", "#f9dcc4", "#f3d2b3", "#edc7a4", "#e6b98f", "#ddaa80", "#d29b6e", "#c68c5f",
	"#b97b51", "#a86b45", "#96603d", "#835233", "#70452b", "#5c3822", "#4a2c1b", "#3b2215",
	"#f4ded5", "#e8c7bb", "#d4ac98", "#bd927c", "#a97d69", "#906754",
	"#775548", "#604238", "#4b332d", "#382723", "#c6a47f", "#917452"]
const HAIR_COLORS := ["#1c1c1c", "#3b2a20", "#5a3a26", "#8a5a3b", "#8e3b1f", "#b5502a", "#c98a5a", "#b8925a",
	"#e3c27a", "#efe3c0", "#9a9a9a", "#ededed", "#6e6e6e", "#f06ba8", "#3d7be0", "#3cb371", "#8e5bd9"]
const EYE_COLORS := ["#3b2416", "#6b4226", "#8e7340", "#4f8a4b", "#4a7fc1", "#7d8a96", "#b07a2a", "hetero"]
const CLOTH := ["#e04848", "#f08a2c", "#f2c53d", "#3fa65a", "#1fa3a3", "#3a7be0", "#27336b", "#8e4fd6",
	"#f07fb0", "#f4f1ea", "#8d939c", "#26262b", "#7a4e2d", "#c9a227"]

const FACE_NAMES := ["Round", "Oval", "Square", "Heart", "Long"]
const FACE_SIZE_NAMES := ["Classic", "Slender", "Fuller"]
const EYE_NAMES := ["Round", "Almond", "Monolid", "Hooded", "Downturned", "Smiling"]
const BROW_NAMES := ["Natural", "Thin", "Thick", "Arched", "Straight", "Bushy"]
const NOSE_NAMES := ["Button", "Long", "Wide"]
const MOUTH_NAMES := ["Smile", "Grin", "Gap tooth", "Braces", "Calm", "Laugh"]
const HAIR_NAMES := ["Bald", "Buzz", "Short", "Side part", "Fade", "Wavy", "Long straight", "Curly", "Coily",
	"Afro", "Locs", "Box braids", "Two puffs", "Bun", "Ponytail", "Bob", "Mohawk", "Receding"]
const FACIAL_NAMES := ["None", "Stubble", "Mustache", "Goatee", "Full beard", "Long beard"]
const HEAD_NAMES := ["None", "Hijab", "Turban", "Patka", "Kippah", "Headwrap", "Durag", "Bonnet"]
const HAT_NAMES := ["None", "Cap", "Beanie", "Sun hat", "Cowboy hat", "Bucket hat", "Crown", "Party hat"]
const EYEWEAR_NAMES := ["None", "Round glasses", "Square glasses", "Cat-eye glasses", "Sunglasses", "Eye patch"]
const EAR_NAMES := ["None", "Hearing aid", "Cochlear implant", "Earrings", "Hoops"]
const SHIRT_NAMES := ["Tee", "Hoodie", "Collar", "Sweater", "Overalls", "Jersey", "Blazer", "Henley", "Cardigan"]
const DETAILS := ["freckles", "vitiligo", "rosy", "smile_lines", "birthmark", "bindi", "nose_ring", "makeup"]
const DETAIL_NAMES := ["Freckles", "Vitiligo", "Rosy cheeks", "Smile lines", "Birthmark", "Bindi", "Nose ring", "Makeup"]

const KEYS := {
	"bowtie": ["None", "Bow tie"], "braces": ["None", "Braces"], "skin": SKIN, "face": FACE_NAMES, "face_size": FACE_SIZE_NAMES, "eyes": EYE_NAMES, "eye_color": EYE_COLORS, "brows": BROW_NAMES,
	"nose": NOSE_NAMES, "mouth": MOUTH_NAMES, "hair": HAIR_NAMES, "hair_color": HAIR_COLORS,
	"facial": FACIAL_NAMES, "head": HEAD_NAMES, "head_color": CLOTH, "hat": HAT_NAMES, "hat_color": CLOTH,
	"eyewear": EYEWEAR_NAMES, "ears": EAR_NAMES, "shirt": SHIRT_NAMES, "shirt_color": CLOTH,
}

## Pets: cats and dogs use their own small set of options.
const SPECIES_NAMES := ["Person", "Cat", "Dog"]
const FUR := ["#f4efe6", "#ffffff", "#e3c27a", "#d9a066", "#c06c2b", "#8a5a3b", "#5a3a26", "#3b2a20",
	"#2b2b2b", "#7d7d85", "#a0a8b8", "#b9a48a"]
const PATTERN_NAMES := ["Solid", "Stripes", "Spots", "Tuxedo", "Eye patch"]
const CAT_EAR_NAMES := ["Pointy", "Folded", "Tufted"]
const DOG_EAR_NAMES := ["Floppy", "Pointy", "Rounded"]
const PET_EYES := ["#7cb342", "#e0a526", "#4a90d9", "#b8662d", "#5b3a1e", "odd"]
const COLLAR_NAMES := ["None", "Collar", "Bell collar", "Bandana", "Bow tie"]
const PET_KEYS := {
	"fur": FUR, "fur2": FUR, "pattern": PATTERN_NAMES, "pet_ears": CAT_EAR_NAMES,
	"pet_eye": PET_EYES, "collar": COLLAR_NAMES, "collar_color": CLOTH,
}

## Head coverings that hide the hair completely.
const HIDES_HAIR := [1, 2, 5, 6, 7]

@export var data: Dictionary = {}:
	set(v):
		data = v
		queue_redraw()
@export var role: String = "":
	set(v):
		role = v
		queue_redraw()

const CX := 100.0
const CY := 100.0


static func random_avatar(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var d := {}
	for k in KEYS.keys():
		d[k] = rng.randi_range(0, KEYS[k].size() - 1)
	# Keep random starts friendly: fewer extreme combos.
	if rng.randf() < 0.7:
		d["head"] = 0
	if rng.randf() < 0.6:
		d["hat"] = 0
	if rng.randf() < 0.5:
		d["eyewear"] = 0
	if rng.randf() < 0.6:
		d["facial"] = 0
	if rng.randf() < 0.6:
		d["ears"] = 0
	if d["hair_color"] >= 13 and rng.randf() < 0.6:
		d["hair_color"] = rng.randi_range(0, 9)
	if d["eye_color"] == 7 and rng.randf() < 0.7:
		d["eye_color"] = 0
	d["details"] = []
	if rng.randf() < 0.35:
		d["details"].append(DETAILS[rng.randi_range(0, DETAILS.size() - 1)])
	return d


static func random_pet(species: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var d := random_avatar(rng)
	d["species"] = species
	for k in PET_KEYS.keys():
		d[k] = rng.randi_range(0, PET_KEYS[k].size() - 1)
	return d


static func normalized(src: Dictionary) -> Dictionary:
	var d := {}
	var portrait := str(src.get("portrait_path", ""))
	if portrait.begins_with("user://portraits/") or (portrait.begins_with("res://art/role-") and portrait.ends_with(".png")):
		d["portrait_path"] = portrait
		d["portrait_zoom"] = clampf(float(src.get("portrait_zoom", 1.0)), 1.0, 3.0)
		d["portrait_x"] = clampf(float(src.get("portrait_x", 0.5)), 0.0, 1.0)
		d["portrait_y"] = clampf(float(src.get("portrait_y", 0.5)), 0.0, 1.0)
	if src.has("skin_tone"): d["skin_tone"] = clampf(float(src["skin_tone"]), 0.0, 1.0)
	d["species"] = clampi(int(src.get("species", 0)), 0, 2)
	for k in PET_KEYS.keys():
		d[k] = clampi(int(src.get(k, 0)), 0, PET_KEYS[k].size() - 1)
	for k in KEYS.keys():
		d[k] = clampi(int(src.get(k, 0)), 0, KEYS[k].size() - 1)
	d["details"] = []
	for x in src.get("details", []):
		if str(x) in DETAILS:
			d["details"].append(str(x))
	return d


func _g(key: String) -> int:
	return int(data.get(key, 0))


func _has(detail: String) -> bool:
	return detail in data.get("details", [])


static func ordered_skin_colors() -> Array:
	var colors: Array = []
	for hex in SKIN: colors.append(Color(hex))
	colors.sort_custom(func(a: Color, b: Color): return a.get_luminance() > b.get_luminance())
	return colors

static func skin_color_at(value: float) -> Color:
	var colors := ordered_skin_colors()
	var position := clampf(value, 0.0, 1.0) * (colors.size()-1)
	var index := mini(int(position), colors.size()-2)
	return colors[index].lerp(colors[index+1], position-index)

func _col(list: Array, key: String) -> Color:
	if key == "skin" and data.has("skin_tone"):
		return skin_color_at(float(data["skin_tone"]))
	var i := clampi(_g(key), 0, list.size() - 1)
	return Color(list[i])


# ------------------------------------------------------------------ geometry helpers

func _ell(c: Vector2, rx: float, ry: float, n := 2.0, heart := 0.0, seg := 44) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		var ca := cos(a)
		var sa := sin(a)
		var x := signf(ca) * pow(absf(ca), 2.0 / n)
		var y := signf(sa) * pow(absf(sa), 2.0 / n)
		if heart > 0.0 and y > 0.0:
			x *= 1.0 - heart * y
		pts.append(c + Vector2(x * rx, y * ry))
	return pts


func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, seg := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / seg)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	# Vertex lighting stays inside the polygon and follows each editable layer.
	var bounds := Rect2(pts[0], Vector2.ZERO)
	for pt in pts:
		bounds = bounds.expand(pt)
	var colors := PackedColorArray()
	for pt in pts:
		var u := (pt.x - bounds.position.x) / maxf(bounds.size.x, 1.0)
		var v := (pt.y - bounds.position.y) / maxf(bounds.size.y, 1.0)
		var shade := col.lightened(0.07).lerp(col.darkened(0.14), u * 0.55 + v * 0.45)
		shade.a = col.a
		colors.append(shade)
	draw_polygon(pts, colors)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(col.darkened(0.12), col.a * 0.45), 0.6, true)


func _head() -> Dictionary:
	var h := _head_base()
	var scale_x: float = [1.0, 0.93, 1.07][clampi(_g("face_size"), 0, 2)]
	h["rx"] *= scale_x
	return h


func _head_base() -> Dictionary:
	match _g("face"):
		0: return {"rx": 54.0, "ry": 58.0, "n": 2.0, "heart": 0.0}
		1: return {"rx": 49.0, "ry": 62.0, "n": 2.0, "heart": 0.0}
		2: return {"rx": 51.0, "ry": 59.0, "n": 3.0, "heart": 0.0}
		3: return {"rx": 54.0, "ry": 60.0, "n": 2.0, "heart": 0.28}
		_: return {"rx": 46.0, "ry": 66.0, "n": 2.2, "heart": 0.0}


## Hair cap: covers the top of the head down to a hairline.
func _cap(col: Color, rx: float, ry: float, grow := 5.0, hl := 0.5, side := 0.1, lift := 0.0) -> void:
	var theta := asin(clampf((ry * side - lift) / (ry + grow), -0.9, 0.9))
	var edge_x := cos(theta) * (rx + grow)
	var pts := _arc(Vector2(CX, CY - lift), rx + grow, ry + grow, PI + theta, TAU - theta, 32)
	for i in range(1, 12):
		var t := float(i) / 12.0
		var x := lerpf(CX + edge_x, CX - edge_x, t)
		var y := CY - ry * side - ry * (hl - side) * sin(PI * t)
		pts.append(Vector2(x, y))
	_poly(pts, col)
	for k in 3:
		var inset := 4.0 + k * 4.5
		draw_polyline(_arc(Vector2(CX, CY - lift), rx + grow - inset, ry + grow - inset, PI * 1.19, PI * 1.74, 22), Color(col.lightened(0.18), 0.22), 0.8, true)


# ------------------------------------------------------------------ draw

static var portrait_cache: Dictionary = {}

static func portrait_texture(path: String) -> Texture2D:
	if portrait_cache.has(path):
		return portrait_cache[path]
	if path.begins_with("res://art/role-") and ResourceLoader.exists(path):
		portrait_cache[path] = load(path)
	elif path.begins_with("user://portraits/") and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			portrait_cache[path] = ImageTexture.create_from_image(image)
	return portrait_cache.get(path)

static func portrait_crop(image_size: Vector2, face_data: Dictionary) -> Rect2:
	var edge := minf(image_size.x, image_size.y) / clampf(float(face_data.get("portrait_zoom", 1.0)), 1.0, 3.0)
	return Rect2((image_size - Vector2.ONE * edge) * Vector2(clampf(float(face_data.get("portrait_x", 0.5)), 0.0, 1.0), clampf(float(face_data.get("portrait_y", 0.5)), 0.0, 1.0)), Vector2.ONE * edge)

## "You" before you've put yourself on a card: a plain head-and-shoulders outline.
func _draw_silhouette() -> void:
	var edge := minf(size.x, size.y)
	var c := size * 0.5
	var col := Color("#8fa6b2")
	draw_circle(c + Vector2(0, -edge * 0.12), edge * 0.2, col)
	var body := PackedVector2Array()
	var w := edge * 0.38
	var top := c.y + edge * 0.12
	for i in 25:
		var a := PI + PI * i / 24.0
		body.append(Vector2(c.x + cos(a) * w, top + edge * 0.1 + sin(a) * edge * 0.22))
	body.append(Vector2(c.x + w, c.y + edge * 0.5))
	body.append(Vector2(c.x - w, c.y + edge * 0.5))
	draw_colored_polygon(body, col)


func _draw() -> void:
	var portrait := portrait_texture(str(data.get("portrait_path", "")))
	if portrait != null:
		var edge := minf(size.x, size.y)
		var target := Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)
		draw_texture_rect_region(portrait, target, portrait_crop(portrait.get_size(), data))
		return
	if data.is_empty():
		return
	if data.get("silhouette", false):
		_draw_silhouette()
		return
	var s := minf(size.x / 200.0, size.y / 240.0)
	var off := Vector2((size.x - 200.0 * s) * 0.5, (size.y - 240.0 * s) * 0.5)
	draw_set_transform(off, 0.0, Vector2(s, s))
	if _g("species") != 0:
		_draw_pet(_g("species") == 2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var h := _head()
	var rx: float = h["rx"]
	var ry: float = h["ry"]
	var skin := _col(SKIN, "skin")
	var hair_c := _col(HAIR_COLORS, "hair_color")
	var head_cover := _g("head")
	var hair := _g("hair")
	var show_hair := not (head_cover in HIDES_HAIR)

	# 1. back layers
	if role == "illusionist":
		_poly(PackedVector2Array([Vector2(CX - 30, 150), Vector2(CX + 30, 150), Vector2(196, 240), Vector2(4, 240)]), Color("#5b2a86"))
		_poly(PackedVector2Array([Vector2(CX - 62, 175), Vector2(CX - 80, 110), Vector2(CX - 40, 165)]), Color("#5b2a86"))
		_poly(PackedVector2Array([Vector2(CX + 62, 175), Vector2(CX + 80, 110), Vector2(CX + 40, 165)]), Color("#5b2a86"))
	if head_cover == 1:
		var hc := _col(CLOTH, "head_color")
		_poly(PackedVector2Array([Vector2(CX - rx - 14, CY + 20), Vector2(CX + rx + 14, CY + 20), Vector2(178, 214), Vector2(22, 214)]), hc.darkened(0.08))
		_poly(_ell(Vector2(CX, CY + 4), rx + 16, ry + 18), hc)
	if head_cover == 6:
		var dc := _col(CLOTH, "head_color")
		_poly(PackedVector2Array([Vector2(CX + 20, CY - 20), Vector2(CX + 34, CY - 18), Vector2(CX + 40, 190), Vector2(CX + 28, 192)]), dc.darkened(0.15))
	if show_hair:
		_hair_back(hair, hair_c, rx, ry)

	# 2. body
	_poly(PackedVector2Array([Vector2(CX - 15, CY + 30), Vector2(CX + 15, CY + 30), Vector2(CX + 16, 190), Vector2(CX - 16, 190)]), skin.darkened(0.08))
	if _has("vitiligo"):
		_poly(_ell(Vector2(CX + 6, 168), 8, 6), skin.lerp(Color("#fff3ea"), 0.55))
	_shirt(skin)
	if _g("bowtie") == 1:
		var tie := _col(CLOTH, "shirt_color").darkened(0.45)
		_poly(PackedVector2Array([Vector2(100,181),Vector2(82,173),Vector2(82,190)]),tie)
		_poly(PackedVector2Array([Vector2(100,181),Vector2(118,173),Vector2(118,190)]),tie)
		draw_circle(Vector2(100,181),4,tie.lightened(0.15))

	# 3. ears + head
	if head_cover != 1:
		for sx in [-1.0, 1.0]:
			var ear := Vector2(CX + sx * (rx - 2), CY + 6)
			_poly(_ell(ear, 9, 14), skin.darkened(0.04))
			draw_polyline(_arc(ear, 4, 8, -PI * 0.7, PI * 0.6), skin.darkened(0.25), 1.2, true)
		_ears_accessory(rx)
	_face_surface(_ell(Vector2(CX, CY), rx, ry, h["n"], h["heart"]), skin)
	_details_under(skin, rx, ry)
	if role == "pickpocket":
		_poly(_ell(Vector2(CX, CY + 1), rx - 4, 15, 3.0), Color("#1d1d24"))

	# 4. face features
	var fac := _g("facial")
	if fac >= 4:
		_beard(hair_c, rx, ry, fac == 5)
	_nose(skin)
	_mouth(skin)
	_eyes(skin)
	_brows(hair_c)
	if fac == 1:
		for i in 26:
			var a := PI * 0.1 + PI * 0.8 * float(i) / 25.0
			draw_circle(Vector2(CX + cos(a) * (rx - 10), CY + 20 + sin(a) * (ry - 28)), 1.3, Color(hair_c, 0.55))
	if fac == 2 or fac == 3 or fac >= 4:
		_poly(PackedVector2Array([Vector2(CX - 20, CY + 33), Vector2(CX - 4, CY + 27), Vector2(CX, CY + 29), Vector2(CX + 4, CY + 27), Vector2(CX + 20, CY + 33), Vector2(CX + 12, CY + 31), Vector2(CX, CY + 33), Vector2(CX - 12, CY + 31)]), hair_c)
	if fac == 3:
		_poly(_ell(Vector2(CX, CY + 52), 11, 9), hair_c)

	# 5. hair front, head coverings, hats
	if show_hair:
		_hair_front(hair, hair_c, rx, ry, head_cover)
		_hair_texture(hair, hair_c, rx, ry, head_cover)
	_head_cover_front(head_cover, rx, ry)
	var role_hat := role in ["trickster", "trapper"]
	if (head_cover == 0 or head_cover == 4) and not role_hat:
		_hat(_g("hat"), rx, ry)
	elif head_cover == 0 and role_hat:
		_role_hat(rx, ry)

	# 6. eyewear + accessories
	var ew := _g("eyewear")
	if role == "bouncer":
		ew = 4
	_eyewear(ew, rx)
	if _has("bindi"):
		draw_circle(Vector2(CX, CY - 22), 3.2, Color("#c8102e"))
	if _has("nose_ring"):
		draw_arc(Vector2(CX + 7, CY + 23), 3.5, 0, TAU, 12, Color("#d4af37"), 1.6, true)

	# 7. role costume front
	_costume_front(rx, ry, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ parts

func _hair_back(style: int, col: Color, rx: float, ry: float) -> void:
	match style:
		5:
			_poly(_ell(Vector2(CX, CY + 8), rx + 12, ry + 18), col)
		6:
			_poly(PackedVector2Array([Vector2(CX - rx - 8, CY - 30), Vector2(CX + rx + 8, CY - 30), Vector2(CX + rx + 10, 205), Vector2(CX - rx - 10, 205)]), col)
			_poly(_ell(Vector2(CX, CY - 20), rx + 8, ry), col)
		7:
			for i in 16:
				var a := PI * 0.85 + PI * 1.3 * float(i) / 15.0
				draw_circle(Vector2(CX + cos(a) * (rx + 4), CY - 6 + sin(a) * (ry + 2)), 15, col)
			for y in [CY + 20, CY + 40]:
				draw_circle(Vector2(CX - rx - 6, y), 13, col)
				draw_circle(Vector2(CX + rx + 6, y), 13, col)
		8:
			for i in 22:
				var a := PI * 0.9 + PI * 1.2 * float(i) / 21.0
				draw_circle(Vector2(CX + cos(a) * (rx + 3), CY - 8 + sin(a) * (ry + 3)), 11, col)
		9:
			draw_circle(Vector2(CX, CY - 20), rx + 32, col)
		10, 11:
			var thick := 9.0 if style == 10 else 6.0
			var n := 9 if style == 10 else 13
			for i in n:
				var x := lerpf(CX - rx - 6, CX + rx + 6, float(i) / (n - 1))
				var bottom := 200.0 if style == 10 else 212.0
				draw_line(Vector2(x, CY - 30), Vector2(x * 1.04 - 4, bottom), col, thick)
				draw_circle(Vector2(x * 1.04 - 4, bottom), thick * 0.5, col)
			_poly(_ell(Vector2(CX, CY - 12), rx + 9, ry + 6), col)
		12:
			draw_circle(Vector2(CX - rx * 0.85, CY - ry * 0.78), 27, col)
			draw_circle(Vector2(CX + rx * 0.85, CY - ry * 0.78), 27, col)
		13:
			draw_circle(Vector2(CX, CY - ry - 14), 22, col)
		14:
			_poly(PackedVector2Array([Vector2(CX + rx - 6, CY - 40), Vector2(CX + rx + 18, CY - 30), Vector2(CX + rx + 14, CY + 50), Vector2(CX + rx - 2, CY + 60)]), col)
		15:
			_poly(PackedVector2Array([Vector2(CX - rx - 12, CY - 20), Vector2(CX + rx + 12, CY - 20), Vector2(CX + rx + 14, CY + 46), Vector2(CX - rx - 14, CY + 46)]), col)
			_poly(_ell(Vector2(CX, CY - 14), rx + 12, ry + 4), col)


func _hair_front(style: int, col: Color, rx: float, ry: float, head_cover: int) -> void:
	var top_ok := head_cover != 3   # patka covers the top
	match style:
		0:
			return
		1:
			if top_ok:
				_cap(Color(col, 0.6), rx, ry, 2.0, 0.62, 0.15)
		2:
			if top_ok:
				_cap(col, rx, ry, 5.0, 0.55, 0.12)
		3:
			if top_ok:
				_cap(col, rx, ry, 6.0, 0.52, 0.1)
				_poly(PackedVector2Array([Vector2(CX - 10, CY - ry - 4), Vector2(CX + rx + 2, CY - ry * 0.5), Vector2(CX + rx * 0.4, CY - ry * 0.35), Vector2(CX - 16, CY - ry * 0.75)]), col)
				draw_line(Vector2(CX - 14, CY - ry - 2), Vector2(CX - 22, CY - ry * 0.55), col.darkened(0.3), 1.5)
		4:
			_cap(Color(col, 0.45), rx, ry, 2.0, 0.55, 0.1)
			if top_ok:
				_poly(_ell(Vector2(CX, CY - ry + 4), rx * 0.75, 16), col)
		5, 6, 15:
			if top_ok:
				_cap(col, rx, ry, 6.0, 0.6 if style != 15 else 0.35, 0.05)
			_poly(PackedVector2Array([Vector2(CX - rx - 6, CY - 20), Vector2(CX - rx + 6, CY - 20), Vector2(CX - rx + 2, CY + 40), Vector2(CX - rx - 8, CY + 44)]), col)
			_poly(PackedVector2Array([Vector2(CX + rx - 6, CY - 20), Vector2(CX + rx + 6, CY - 20), Vector2(CX + rx + 8, CY + 44), Vector2(CX + rx - 2, CY + 40)]), col)
			if style == 6 and top_ok:
				draw_line(Vector2(CX, CY - ry - 5), Vector2(CX, CY - ry * 0.55), col.darkened(0.3), 1.5)
		7, 8:
			if top_ok:
				_cap(col, rx, ry, 4.0, 0.55, 0.12)
				var r := 12.0 if style == 7 else 9.0
				for i in 9:
					var t := float(i) / 8.0
					draw_circle(Vector2(lerpf(CX - rx + 4, CX + rx - 4, t), CY - ry * 0.12 - ry * 0.42 * sin(PI * t)), r, col)
		9:
			if top_ok:
				_cap(col, rx, ry, 6.0, 0.55, 0.15)
		10, 11:
			if top_ok:
				_cap(col, rx, ry, 6.0, 0.55, 0.1)
				for i in 5:
					var x := lerpf(CX - rx * 0.6, CX + rx * 0.6, float(i) / 4.0)
					draw_line(Vector2(x, CY - ry - 2), Vector2(x, CY - ry * 0.5), col.darkened(0.25), 2.0)
		12, 13, 14:
			if top_ok:
				_cap(col, rx, ry, 4.0, 0.55, 0.12)
				draw_line(Vector2(CX - rx * 0.5, CY - ry * 0.8), Vector2(CX - rx * 0.2, CY - ry * 0.55), col.darkened(0.25), 1.5)
		16:
			if top_ok:
				_poly(PackedVector2Array([Vector2(CX - 12, CY - ry * 0.4), Vector2(CX - 10, CY - ry - 22), Vector2(CX, CY - ry - 30), Vector2(CX + 10, CY - ry - 22), Vector2(CX + 12, CY - ry * 0.4)]), col)
			_cap(Color(col, 0.3), rx, ry, 1.0, 0.5, 0.1)
		17:
			_poly(PackedVector2Array([Vector2(CX - rx - 3, CY - 6), Vector2(CX - rx + 2, CY - ry * 0.75), Vector2(CX - rx * 0.55, CY - ry * 0.85), Vector2(CX - rx + 8, CY - 4)]), col)
			_poly(PackedVector2Array([Vector2(CX + rx + 3, CY - 6), Vector2(CX + rx - 8, CY - 4), Vector2(CX + rx * 0.55, CY - ry * 0.85), Vector2(CX + rx - 2, CY - ry * 0.75)]), col)


func _head_cover_front(kind: int, rx: float, ry: float) -> void:
	if kind == 0:
		return
	var c := _col(CLOTH, "head_color")
	match kind:
		1:  # hijab band over the forehead
			var pts := _arc(Vector2(CX, CY + 4), rx + 16, ry + 18, PI, TAU, 24)
			pts.append(Vector2(CX + rx + 1, CY + 4))
			for i in 13:
				var t := float(i) / 12.0
				pts.append(Vector2(lerpf(CX + rx * 0.92, CX - rx * 0.92, t), CY - ry * 0.25 - ry * 0.35 * sin(PI * t)))
			pts.append(Vector2(CX - rx - 1, CY + 4))
			_poly(pts, c)
			draw_polyline(_arc(Vector2(CX, CY - ry * 0.25), rx * 0.92, ry * 0.35, PI, TAU, 16), c.darkened(0.2), 2.0, true)
		2:  # turban
			_poly(_ell(Vector2(CX, CY - ry * 0.9), rx + 10, ry * 0.58), c)
			for k in 3:
				draw_polyline(_arc(Vector2(CX, CY - ry * 0.75 + k * 6), rx + 4 - k * 4, ry * 0.45, PI * 1.05, PI * 1.95, 14), c.darkened(0.18), 2.0, true)
			_poly(PackedVector2Array([Vector2(CX - 10, CY - ry * 0.42), Vector2(CX, CY - ry * 0.9), Vector2(CX + 10, CY - ry * 0.42)]), c.darkened(0.1))
		3:  # patka
			_cap(c, rx, ry, 4.0, 0.5, 0.35)
			draw_circle(Vector2(CX, CY - ry - 6), 14, c.darkened(0.08))
		4:  # kippah
			_poly(_ell(Vector2(CX, CY - ry + 4), 24, 10), c)
			draw_polyline(_arc(Vector2(CX, CY - ry + 4), 24, 10, 0, PI, 10), c.darkened(0.25), 1.5, true)
		5:  # headwrap / gele
			_poly(_ell(Vector2(CX, CY - ry * 0.9), rx + 16, ry * 0.6), c)
			_poly(PackedVector2Array([Vector2(CX - 30, CY - ry * 1.2), Vector2(CX - 8, CY - ry * 1.75), Vector2(CX + 4, CY - ry * 1.25), Vector2(CX + 22, CY - ry * 1.8), Vector2(CX + 34, CY - ry * 1.15)]), c.darkened(0.08))
			for i in 7:
				draw_circle(Vector2(CX - 36 + i * 12, CY - ry * 0.9 + (i % 2) * 8), 2.5, c.lightened(0.4))
		6:  # durag
			_cap(c, rx, ry, 4.0, 0.62, 0.2)
			draw_line(Vector2(CX - rx * 0.9, CY - ry * 0.58), Vector2(CX + rx * 0.9, CY - ry * 0.58), c.darkened(0.2), 3.0)
		7:  # bonnet
			_poly(_ell(Vector2(CX, CY - ry * 0.75), rx + 20, ry * 0.7), c)
			draw_polyline(_arc(Vector2(CX, CY - ry * 0.75), rx + 18, ry * 0.68, PI * 0.1, PI * 0.9, 12), c.darkened(0.2), 4.0, true)


func _hat(kind: int, rx: float, ry: float) -> void:
	if kind == 0:
		return
	var c := _col(CLOTH, "hat_color")
	var hy := CY - ry * 0.45
	match kind:
		1:  # cap
			_poly(_arc(Vector2(CX, hy), rx + 5, ry * 0.62, PI, TAU, 20), c)
			_poly(_ell(Vector2(CX + 26, hy + 1), 42, 8), c.darkened(0.15))
		2:  # beanie
			_poly(_arc(Vector2(CX, hy + 4), rx + 7, ry * 0.75, PI, TAU, 20), c)
			draw_rect(Rect2(CX - rx - 8, hy - 6, rx * 2 + 16, 14), c.darkened(0.15))
			draw_circle(Vector2(CX, CY - ry * 1.25), 11, c.lightened(0.3))
		3:  # sun hat
			_poly(_ell(Vector2(CX, hy - 2), rx + 46, 15), c)
			_poly(_arc(Vector2(CX, hy - 2), rx * 0.85, 40, PI, TAU, 18), c.lightened(0.08))
			draw_rect(Rect2(CX - rx * 0.85, hy - 10, rx * 1.7, 7), c.darkened(0.25))
		4:  # cowboy hat
			_poly(PackedVector2Array([Vector2(CX - rx - 40, hy - 18), Vector2(CX - rx, hy + 2), Vector2(CX + rx, hy + 2), Vector2(CX + rx + 40, hy - 18), Vector2(CX + rx + 20, hy + 8), Vector2(CX - rx - 20, hy + 8)]), c.darkened(0.1))
			_poly(PackedVector2Array([Vector2(CX - rx * 0.7, hy), Vector2(CX - rx * 0.6, hy - 46), Vector2(CX, hy - 36), Vector2(CX + rx * 0.6, hy - 46), Vector2(CX + rx * 0.7, hy)]), c)
		5:  # bucket hat
			_poly(PackedVector2Array([Vector2(CX - rx - 18, hy + 12), Vector2(CX - rx * 0.75, hy - 36), Vector2(CX + rx * 0.75, hy - 36), Vector2(CX + rx + 18, hy + 12)]), c)
		6:  # crown
			var gold := Color("#f2c230")
			_poly(PackedVector2Array([Vector2(CX - 40, hy), Vector2(CX - 44, hy - 40), Vector2(CX - 22, hy - 20), Vector2(CX, hy - 48), Vector2(CX + 22, hy - 20), Vector2(CX + 44, hy - 40), Vector2(CX + 40, hy)]), gold)
			draw_circle(Vector2(CX, hy - 12), 5, Color("#e0344a"))
			draw_circle(Vector2(CX - 24, hy - 9), 4, Color("#2f6fe0"))
			draw_circle(Vector2(CX + 24, hy - 9), 4, Color("#25a55f"))
		7:  # party hat
			_poly(PackedVector2Array([Vector2(CX - 30, hy - 10), Vector2(CX + 8, CY - ry - 64), Vector2(CX + 30, hy - 10)]), c)
			draw_line(Vector2(CX - 18, hy - 30), Vector2(CX + 22, hy - 24), c.lightened(0.5), 4.0)
			draw_line(Vector2(CX - 6, hy - 52), Vector2(CX + 14, hy - 48), c.lightened(0.5), 4.0)
			draw_circle(Vector2(CX + 8, CY - ry - 66), 7, Color("#ffffff"))


func _role_hat(rx: float, ry: float) -> void:
	var hy := CY - ry * 0.5
	if role == "trickster":
		draw_rect(Rect2(CX - 30, hy - 58, 60, 56), Color("#1d1d24"))
		draw_rect(Rect2(CX - 30, hy - 14, 60, 10), Color("#e04848"))
		_poly(_ell(Vector2(CX, hy - 2), 52, 8), Color("#1d1d24"))
	elif role == "trapper":
		_poly(_ell(Vector2(CX, hy), rx + 26, 10), Color("#b49a64"))
		_poly(_arc(Vector2(CX, hy), rx * 0.95, 44, PI, TAU, 20), Color("#c8ad74"))
		draw_rect(Rect2(CX - rx * 0.95, hy - 10, rx * 1.9, 7), Color("#6d5a35"))


func _shirt(skin: Color) -> void:
	var c := _col(CLOTH, "shirt_color")
	if role == "bouncer":
		c = Color("#202024")
	var style := _g("shirt")
	var body := PackedVector2Array([Vector2(10, 240), Vector2(16, 206), Vector2(40, 186), Vector2(CX - 22, 178),
		Vector2(CX, 194), Vector2(CX + 22, 178), Vector2(160, 186), Vector2(184, 206), Vector2(190, 240)])
	if style == 1:
		_poly(_ell(Vector2(CX, 182), 44, 14), c.darkened(0.18))
	_poly(body, c)
	match style:
		1:
			draw_line(Vector2(CX - 8, 194), Vector2(CX - 10, 222), Color("#ffffff"), 2.0)
			draw_line(Vector2(CX + 8, 194), Vector2(CX + 10, 222), Color("#ffffff"), 2.0)
		2:
			_poly(PackedVector2Array([Vector2(CX - 22, 177), Vector2(CX, 194), Vector2(CX - 14, 200)]), Color("#ffffff"))
			_poly(PackedVector2Array([Vector2(CX + 22, 177), Vector2(CX + 14, 200), Vector2(CX, 194)]), Color("#ffffff"))
		3:
			draw_polyline(PackedVector2Array([Vector2(CX - 22, 178), Vector2(CX, 194), Vector2(CX + 22, 178)]), c.darkened(0.25), 5.0)
		4:
			draw_rect(Rect2(CX - 34, 204, 68, 36), Color("#3a5fa0"))
			draw_line(Vector2(CX - 30, 206), Vector2(CX - 44, 184), Color("#3a5fa0"), 7.0)
			draw_line(Vector2(CX + 30, 206), Vector2(CX + 44, 184), Color("#3a5fa0"), 7.0)
			draw_circle(Vector2(CX - 26, 210), 3, Color("#f2c230"))
			draw_circle(Vector2(CX + 26, 210), 3, Color("#f2c230"))
		5:
			draw_rect(Rect2(CX - 14, 206, 28, 26), Color(1, 1, 1, 0.85), false, 3.0)
			draw_line(Vector2(40, 186), Vector2(16, 206), Color("#ffffff"), 4.0)
			draw_line(Vector2(160, 186), Vector2(184, 206), Color("#ffffff"), 4.0)
	_garment_finish(c, style)
	if role == "boss":
		var j := Color("#3a3d46")
		_poly(PackedVector2Array([Vector2(10, 240), Vector2(16, 206), Vector2(40, 186), Vector2(CX - 22, 178), Vector2(CX - 6, 240)]), j)
		_poly(PackedVector2Array([Vector2(CX + 6, 240), Vector2(CX + 22, 178), Vector2(160, 186), Vector2(184, 206), Vector2(190, 240)]), j)
		for x in [30.0, 50.0, 70.0, 130.0, 150.0, 170.0]:
			draw_line(Vector2(x, 195), Vector2(x, 240), Color(1, 1, 1, 0.25), 1.0)
	if role == "pickpocket":
		for i in 6:
			var col := Color("#e04848") if i % 2 == 0 else Color("#f4f1ea")
			draw_rect(Rect2(CX - 30 + i * 10, 176, 10, 14), col)
		_poly(PackedVector2Array([Vector2(CX + 14, 188), Vector2(CX + 26, 188), Vector2(CX + 30, 226), Vector2(CX + 18, 226)]), Color("#e04848"))


func _ears_accessory(rx: float) -> void:
	var e := _g("ears")
	var lx := CX - rx + 2
	var rxp := CX + rx - 2
	match e:
		1:
			_poly(_ell(Vector2(lx - 9, CY - 2), 4, 10), Color("#d9c3a5"))
			draw_line(Vector2(lx - 7, CY - 10), Vector2(lx - 1, CY - 2), Color("#bfa98a"), 1.5)
		2:
			draw_circle(Vector2(lx - 4, CY - 24), 7, Color("#8d939c"))
			draw_circle(Vector2(lx - 4, CY - 24), 3, Color("#5c6169"))
			draw_line(Vector2(lx - 4, CY - 17), Vector2(lx - 10, CY - 4), Color("#5c6169"), 1.5)
			_poly(_ell(Vector2(lx - 11, CY + 2), 3, 7), Color("#8d939c"))
		3:
			draw_circle(Vector2(lx - 2, CY + 22), 3.5, Color("#f2c230"))
			draw_circle(Vector2(rxp + 2, CY + 22), 3.5, Color("#f2c230"))
		4:
			draw_arc(Vector2(lx - 2, CY + 28), 8, 0, TAU, 18, Color("#f2c230"), 2.0, true)
			draw_arc(Vector2(rxp + 2, CY + 28), 8, 0, TAU, 18, Color("#f2c230"), 2.0, true)
	if role == "bouncer":
		draw_polyline(PackedVector2Array([Vector2(lx - 2, CY + 14), Vector2(lx - 6, CY + 26), Vector2(lx + 2, CY + 32), Vector2(lx - 4, CY + 40), Vector2(lx, 180)]), Color("#cfd3da"), 1.5)


func _details_under(skin: Color, rx: float, ry: float) -> void:
	if _has("vitiligo"):
		var light := skin.lerp(Color("#fff3ea"), 0.55)
		_poly(_ell(Vector2(CX - 24, CY - 4), 14, 11), light)
		_poly(_ell(Vector2(CX + 10, CY + 52), 12, 7), light)
	if _has("rosy"):
		_soft_oval(Vector2(CX - 30, CY + 20), 13, 9, Color(0.8, 0.22, 0.25, 0.24))
		_soft_oval(Vector2(CX + 30, CY + 20), 13, 9, Color(0.8, 0.22, 0.25, 0.24))
	if _has("freckles"):
		var fc := Color(skin.darkened(0.35), 0.8)
		for p in [Vector2(-30, 14), Vector2(-24, 18), Vector2(-34, 20), Vector2(-27, 24), Vector2(-20, 13),
				Vector2(30, 14), Vector2(24, 18), Vector2(34, 20), Vector2(27, 24), Vector2(20, 13), Vector2(-4, 14), Vector2(4, 15)]:
			draw_circle(Vector2(CX, CY) + p, 1.4, fc)
	if _has("smile_lines"):
		var lc := skin.darkened(0.22)
		draw_polyline(_arc(Vector2(CX - 22, CY + 30), 6, 12, PI * 0.6, PI * 1.3, 8), lc, 1.5, true)
		draw_polyline(_arc(Vector2(CX + 22, CY + 30), 6, 12, -PI * 0.3, PI * 0.4, 8), lc, 1.5, true)
		draw_line(Vector2(CX - 14, CY - ry * 0.55), Vector2(CX + 14, CY - ry * 0.55), lc, 1.2)
	if _has("birthmark"):
		draw_circle(Vector2(CX + 26, CY + 30), 2.4, skin.darkened(0.45))


func _beard(col: Color, rx: float, ry: float, long: bool) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(CX - rx + 2, CY + 6))
	var depth := ry + (34.0 if long else 8.0)
	for i in 17:
		var a := PI * float(i) / 16.0
		pts.append(Vector2(CX - cos(a) * (rx - 1), CY + 10 + sin(a) * (depth - 10)))
	pts.append(Vector2(CX + rx - 2, CY + 6))
	pts.append(Vector2(CX + rx - 14, CY + 22))
	pts.append(Vector2(CX + 16, CY + 30))
	pts.append(Vector2(CX, CY + 46))
	pts.append(Vector2(CX - 16, CY + 30))
	pts.append(Vector2(CX - rx + 14, CY + 22))
	_poly(pts, col)
	# Short curved strokes stay within the chin portion of the beard.
	for i in 19:
		var x := lerpf(-rx * 0.68, rx * 0.68, float(i) / 18.0)
		var lower := CY + 10 + sqrt(maxf(0.0, 1.0 - pow(x / (rx - 1), 2))) * (depth - 10)
		var upper := CY + 47 + absf(x) * 0.12
		if lower > upper + 5:
			draw_polyline(PackedVector2Array([Vector2(CX + x, upper), Vector2(CX + x * 0.96, (upper + lower) * 0.5), Vector2(CX + x * 0.93, lower - 4)]), Color(col.lightened(0.3), 0.4), 0.8, true)


func _nose(skin: Color) -> void:
	var c := skin.darkened(0.24)
	var nw := 9.0 if _g("nose") == 2 else 5.0
	_poly(_ell(Vector2(CX + 2, CY + 16), nw, 6), skin.darkened(0.06))
	draw_polyline(PackedVector2Array([Vector2(CX - 2, CY + 4), Vector2(CX - 3, CY + 15), Vector2(CX, CY + 18)]), Color(skin.lightened(0.22), 0.55), 1.4, true)
	match _g("nose"):
		0:
			draw_polyline(_arc(Vector2(CX, CY + 18), 6, 4, PI * 0.15, PI * 0.85, 8), c, 2.0, true)
		1:
			draw_polyline(PackedVector2Array([Vector2(CX - 2, CY + 2), Vector2(CX + 4, CY + 20), Vector2(CX - 4, CY + 23)]), c, 2.0, true)
		2:
			draw_polyline(_arc(Vector2(CX, CY + 18), 10, 5, PI * 0.05, PI * 0.95, 10), c, 2.2, true)


func _mouth(skin: Color) -> void:
	var m := Vector2(CX, CY + 38)
	var lip := Color("#a02a4a") if _has("makeup") else skin.darkened(0.45)
	var dark := Color("#5a1f24")
	match 3 if _g("braces") == 1 else _g("mouth"):
		0:
			draw_polyline(_arc(m + Vector2(0, -6), 13, 8, PI * 0.15, PI * 0.85, 12), lip, 3.0, true)
		1, 2, 3:
			var pts := _arc(m + Vector2(0, -4), 15, 11, 0, PI, 14)
			_poly(pts, dark)
			draw_rect(Rect2(m.x - 11, m.y - 4, 22, 5), Color("#ffffff"))
			if _g("mouth") == 2:
				draw_line(Vector2(m.x, m.y - 4), Vector2(m.x, m.y + 1), dark, 2.0)
			if _g("mouth") == 3 or _g("braces") == 1:
				draw_line(Vector2(m.x - 11, m.y - 2), Vector2(m.x + 11, m.y - 2), Color("#9aa3ad"), 1.5)
			draw_polyline(pts, lip, 2.0, true)
		4:
			draw_line(m + Vector2(-10, -2), m + Vector2(10, -2), lip, 3.0)
		5:
			var pts2 := _arc(m + Vector2(0, -6), 16, 15, 0, PI, 14)
			_poly(pts2, dark)
			_poly(_ell(m + Vector2(0, 4), 8, 4), Color("#e86b7a"))
			draw_rect(Rect2(m.x - 12, m.y - 6, 24, 4), Color("#ffffff"))


func _eyes(skin: Color) -> void:
	var style := _g("eyes")
	var ec_i := _g("eye_color")
	for side in [-1, 1]:
		var c := Vector2(CX + side * 20, CY + 2)
		var iris := Color(EYE_COLORS[0])
		if ec_i == 7:
			iris = Color("#4a7fc1") if side < 0 else Color("#6b4226")
		elif ec_i < 7:
			iris = Color(EYE_COLORS[ec_i])
		if style == 5:
			draw_polyline(_arc(c + Vector2(0, 3), 8, 6, PI * 1.1, PI * 1.9, 10), Color("#2a1a14"), 2.5, true)
			continue
		var ry := 5.0
		var rxe := 8.5
		match style:
			1, 4:
				ry = 5.2
				rxe = 9.0
			2:
				ry = 4.2
				rxe = 8.5
			3:
				ry = 5.5
				rxe = 8.0
		_poly(_ell(c, rxe, ry), Color("#f3eee5"))
		draw_circle(c + Vector2(0, 0.5), minf(ry, 4.8), iris)
		draw_arc(c + Vector2(0, 0.5), minf(ry, 4.8), 0, TAU, 24, iris.darkened(0.42), 0.75, true)
		draw_circle(c + Vector2(0, 0.5), 2.0, Color("#171a20"))
		draw_polyline(_arc(c + Vector2(0, 1.0), rxe, ry, 0.15, PI - 0.15), skin.darkened(0.18), 0.8, true)
		draw_circle(c + Vector2(1.6, -1.2), 1.1, Color("#ffffff"))
		var lid := Color("#2a1a14")
		match style:
			2:
				_poly(PackedVector2Array([c + Vector2(-rxe - 1, -ry - 2), c + Vector2(rxe + 1, -ry - 2), c + Vector2(rxe + 1, -1), c + Vector2(-rxe - 1, -1.5)]), skin)
				draw_line(c + Vector2(-rxe, -1.5), c + Vector2(rxe, -1), lid, 2.0)
			3:
				_poly(_arc(c + Vector2(0, -1), rxe + 1, ry + 1, PI, TAU, 10), skin.darkened(0.06))
				draw_polyline(_arc(c + Vector2(0, -1), rxe + 1, 2.5, 0, PI, 8), lid, 1.6, true)
			4:
				draw_polyline(PackedVector2Array([c + Vector2(-rxe * side, -ry * 0.6), c + Vector2(0, -ry - 1), c + Vector2(rxe * side, ry * 0.2)]), lid, 2.0, true)
			_:
				draw_polyline(_arc(c, rxe, ry, PI, TAU, 10), lid, 2.0, true)
		if _has("makeup"):
			draw_line(c + Vector2(side * rxe, -ry * 0.4), c + Vector2(side * (rxe + 5), -ry - 2), lid, 2.0)


func _brows(hair_c: Color) -> void:
	var style := _g("brows")
	var col := hair_c.darkened(0.1)
	if _g("hair") == 0:
		col = Color("#3b2a20")
	for side in [-1.0, 1.0]:
		var c := Vector2(CX + side * 20, CY - 13)
		match style:
			0: draw_polyline(_arc(c + Vector2(0, 4), 10, 5, PI * 1.15, PI * 1.85, 8), col, 3.0, true)
			1: draw_polyline(_arc(c + Vector2(0, 4), 10, 5, PI * 1.15, PI * 1.85, 8), col, 1.6, true)
			2: draw_polyline(_arc(c + Vector2(0, 4), 11, 5, PI * 1.1, PI * 1.9, 8), col, 4.5, true)
			3: draw_polyline(PackedVector2Array([c + Vector2(-side * 10, 3), c + Vector2(side * 2, -3), c + Vector2(side * 10, 1)]), col, 2.8, true)
			4: draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), col, 3.2)
			5: draw_line(c + Vector2(-11, 0), c + Vector2(11, -1), col, 6.0)


func _eyewear(kind: int, rx: float) -> void:
	var frame := Color("#26262b")
	var l := Vector2(CX - 20, CY + 2)
	var r := Vector2(CX + 20, CY + 2)
	match kind:
		1:
			draw_arc(l, 13, 0, TAU, 24, frame, 2.4, true)
			draw_arc(r, 13, 0, TAU, 24, frame, 2.4, true)
			draw_line(l + Vector2(13, 0), r - Vector2(13, 0), frame, 2.0)
		2:
			draw_rect(Rect2(l - Vector2(15, 11), Vector2(30, 22)), frame, false, 2.4)
			draw_rect(Rect2(r - Vector2(15, 11), Vector2(30, 22)), frame, false, 2.4)
			draw_line(l + Vector2(15, 0), r - Vector2(15, 0), frame, 2.0)
		3:
			for side in [-1.0, 1.0]:
				var c := Vector2(CX + side * 20, CY + 2)
				draw_polyline(PackedVector2Array([c + Vector2(-side * 13, -4), c + Vector2(side * 4, -10), c + Vector2(side * 17, -14),
					c + Vector2(side * 14, 6), c + Vector2(-side * 6, 9), c + Vector2(-side * 13, -4)]), Color("#8e2a4f"), 2.6, true)
			draw_line(l + Vector2(13, -2), r - Vector2(13, 2), Color("#8e2a4f"), 2.0)
		4:
			for c in [l, r]:
				draw_rect(Rect2(c - Vector2(15, 9), Vector2(30, 18)), Color("#15151a"))
				draw_line(c + Vector2(-9, -5), c + Vector2(-3, -5), Color(1, 1, 1, 0.5), 2.0)
			draw_line(l + Vector2(15, -4), r - Vector2(15, 4), Color("#15151a"), 3.0)
		5:
			_poly(_ell(r, 12, 10), Color("#15151a"))
			draw_line(r + Vector2(-8, -8), Vector2(CX - rx + 4, CY - 30), Color("#15151a"), 2.0)
			draw_line(r + Vector2(10, -4), Vector2(CX + rx - 2, CY - 8), Color("#15151a"), 2.0)
	if role == "mastermind":
		draw_arc(r, 13, 0, TAU, 24, Color("#d4af37"), 2.6, true)
		draw_polyline(PackedVector2Array([r + Vector2(10, 9), r + Vector2(22, 40), r + Vector2(16, 76)]), Color("#d4af37"), 1.4, true)


func _costume_front(rx: float, ry: float, skin: Color) -> void:
	match role:
		"trickster":
			for i in 3:
				var base := Vector2(34 + i * 9, 214 - i * 4)
				draw_set_transform_matrix(_base_xf() * Transform2D(deg_to_rad(-25 + i * 18), base))
				draw_rect(Rect2(-9, -13, 18, 26), Color("#ffffff"))
				draw_rect(Rect2(-9, -13, 18, 26), Color("#cccccc"), false, 1.0)
				draw_circle(Vector2(0, 0), 4, Color("#e04848"))
			_reset_xf()
		"mastermind":
			_reset_xf()
			_poly(PackedVector2Array([Vector2(146, 196), Vector2(186, 186), Vector2(192, 222), Vector2(152, 232)]), Color("#2f6fe0"))
			for k in 3:
				draw_line(Vector2(154, 204 + k * 8), Vector2(184, 196 + k * 8), Color(1, 1, 1, 0.7), 1.2)
		"illusionist":
			_reset_xf()
			for p in [Vector2(30, 200), Vector2(170, 196), Vector2(160, 226)]:
				_star(p, 7, Color("#ffd84a"))
		"trapper":
			_reset_xf()
			for k in 3:
				draw_arc(Vector2(158, 214), 12 + k * 4, 0, TAU, 20, Color("#a57b45"), 2.5, true)
		"locksmith":
			_reset_xf()
			var gold := Color("#e0b23a")
			draw_arc(Vector2(160, 192), 11, 0, TAU, 20, gold, 5.0, true)
			draw_line(Vector2(152, 200), Vector2(122, 236), gold, 6.0)
			draw_line(Vector2(130, 226), Vector2(138, 232), gold, 5.0)
			draw_line(Vector2(124, 233), Vector2(131, 239), gold, 5.0)


func _base_xf() -> Transform2D:
	var s := minf(size.x / 200.0, size.y / 240.0)
	var off := Vector2((size.x - 200.0 * s) * 0.5, (size.y - 240.0 * s) * 0.5)
	return Transform2D(0.0, Vector2(s, s), 0.0, off)


func _reset_xf() -> void:
	var s := minf(size.x / 200.0, size.y / 240.0)
	var off := Vector2((size.x - 200.0 * s) * 0.5, (size.y - 240.0 * s) * 0.5)
	draw_set_transform(off, 0.0, Vector2(s, s))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_poly(pts, col)


## Smooth radial lighting with an off-center highlight; preserves the chosen skin hue.
func _face_surface(outline: PackedVector2Array, skin: Color) -> void:
	var center := Vector2(CX - 12, CY - 19)
	var pts := PackedVector2Array([center])
	var colors := PackedColorArray([skin.lightened(0.12)])
	for pt in outline:
		pts.append(pt)
		var t := clampf((pt.x - CX + 60) / 120.0 * 0.45 + (pt.y - CY + 65) / 130.0 * 0.55, 0.0, 1.0)
		colors.append(skin.lightened(0.035).lerp(skin.darkened(0.25), t))
	for i in outline.size():
		var j := (i + 1) % outline.size()
		draw_polygon(PackedVector2Array([pts[0], pts[i + 1], pts[j + 1]]), PackedColorArray([colors[0], colors[i + 1], colors[j + 1]]))
	var edge := outline.duplicate()
	edge.append(outline[0])
	draw_polyline(edge, Color(skin.darkened(0.3), 0.5), 0.85, true)


func _hair_texture(style: int, col: Color, rx: float, ry: float, cover: int) -> void:
	if cover == 3 or style == 0:
		return
	var ink := Color(col.lightened(0.28), 0.42)
	if style in [7, 8, 9]:
		# Texture on the upper silhouette, never across the face.
		for i in 17:
			var a := PI * 1.12 + PI * 0.76 * float(i) / 16.0
			var c := Vector2(CX + cos(a) * (rx - 2), CY - 8 + sin(a) * (ry + 2))
			draw_polyline(_arc(c, 4.0 if style == 7 else 2.5, 3.5, 0.0, PI * 1.5, 10), ink, 0.9, true)
	if style in [5, 6, 15]:
		for side in [-1.0, 1.0]:
			for i in 3:
				var x: float = CX + side * (rx + i * 2.5 - 3)
				draw_polyline(PackedVector2Array([Vector2(x, CY - 17), Vector2(x + side * 1.5, CY + 8), Vector2(x + side * 1.0, CY + 36)]), ink, 0.8, true)
	if style in [10, 11]:
		var n := 9 if style == 10 else 13
		for i in n:
			var x := lerpf(CX - rx - 6, CX + rx + 6, float(i) / (n - 1))
			# Side locks only: center locks are hidden by the head.
			if absf(x - CX) > rx - 5:
				for k in 9:
					var y := CY + 36 + k * 7
					draw_line(Vector2(x - 2, y), Vector2(x + 2, y + 3), ink, 0.8, true)


func _garment_finish(c: Color, style: int) -> void:
	var seam := Color(c.darkened(0.4), 0.5)
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(CX + side * 60, 190), Vector2(CX + side * 50, 211), Vector2(CX + side * 54, 237)]), seam, 1.3, true)
		draw_line(Vector2(CX + side * 56, 213), Vector2(CX + side * 69, 232), Color(c.lightened(0.2), 0.4), 1.2, true)
	if style == 0 or style == 5:
		draw_polyline(PackedVector2Array([Vector2(78, 178), Vector2(89, 191), Vector2(100, 196), Vector2(111, 191), Vector2(122, 178)]), c.darkened(0.28), 2.2, true)
	if style == 1:
		draw_polyline(PackedVector2Array([Vector2(78, 225), Vector2(73, 238), Vector2(127, 238), Vector2(122, 225)]), seam, 1.2, true)
	if style in [2, 7]:
		draw_line(Vector2(CX, 197), Vector2(CX, 239 if style == 2 else 220), seam, 1.1, true)
		for y in [203, 214, 225] if style == 2 else [203, 213]:
			draw_circle(Vector2(CX + 3, y), 1.5, Color("#ddd3bc"))
	if style == 3:
		for i in 24:
			var x := 27.0 + i * 6.0
			draw_line(Vector2(x, 230), Vector2(x, 239), Color(c.darkened(0.25), 0.35), 0.7, true)
	if style in [6, 8]:
		_poly(PackedVector2Array([Vector2(78, 178), Vector2(100, 194), Vector2(122, 178), Vector2(100, 233)]), Color("#e7dfcf"))
		for side in [-1.0, 1.0]:
			var lapel := PackedVector2Array([Vector2(CX + side * 22, 178), Vector2(CX + side * 36, 191), Vector2(CX + side * 25, 200), Vector2(CX + side * 31, 207), Vector2(CX, 235)])
			_poly(lapel, c.darkened(0.12) if style == 6 else c)
		if style == 6:
			draw_line(Vector2(131, 214), Vector2(154, 211), seam, 1.5, true)
		for y in [229, 238]:
			draw_circle(Vector2(CX + 3, y), 2, Color("#b99b60"))


func _soft_oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var edge := _ell(c, rx, ry)
	for i in edge.size():
		draw_polygon(PackedVector2Array([c, edge[i], edge[(i + 1) % edge.size()]]), PackedColorArray([col, Color(col, 0.0), Color(col, 0.0)]))


# ------------------------------------------------------------------ pets

func _draw_pet(dog: bool) -> void:
	var fur := _col(FUR, "fur")
	var fur2 := _col(FUR, "fur2")
	var pattern := _g("pattern")
	var ears := _g("pet_ears")
	var light := fur.lerp(Color.WHITE, 0.45)
	var dark := fur.darkened(0.35)
	var head_c := Vector2(CX, CY + (2.0 if dog else 6.0))
	var hrx := 58.0 if dog else 62.0
	var hry := 56.0 if dog else 52.0

	# Body / chest
	_poly(_ell(Vector2(CX, 236), 78, 62), fur)
	if pattern == 3:
		_poly(_ell(Vector2(CX, 236), 30, 58), Color("#f7f3ec"))

	# Back ears
	if not dog:
		if ears == 1:
			for sx in [-1.0, 1.0]:
				_poly(PackedVector2Array([head_c + Vector2(sx * 30, -40), head_c + Vector2(sx * 56, -38), head_c + Vector2(sx * 46, -18)]), fur)
		else:
			for sx in [-1.0, 1.0]:
				_poly(PackedVector2Array([head_c + Vector2(sx * 18, -42), head_c + Vector2(sx * 46, -84), head_c + Vector2(sx * 58, -16)]), fur)
				_poly(PackedVector2Array([head_c + Vector2(sx * 26, -42), head_c + Vector2(sx * 44, -70), head_c + Vector2(sx * 50, -28)]), Color("#f2a7b3"))
				if ears == 2:
					draw_line(head_c + Vector2(sx * 46, -84), head_c + Vector2(sx * 52, -98), dark, 3.0)
	else:
		if ears == 1:
			for sx in [-1.0, 1.0]:
				_poly(PackedVector2Array([head_c + Vector2(sx * 20, -40), head_c + Vector2(sx * 44, -92), head_c + Vector2(sx * 60, -22)]), fur)
				_poly(PackedVector2Array([head_c + Vector2(sx * 28, -40), head_c + Vector2(sx * 43, -76), head_c + Vector2(sx * 52, -30)]), fur.darkened(0.15))
		elif ears == 2:
			for sx in [-1.0, 1.0]:
				_poly(_ell(head_c + Vector2(sx * 42, -44), 20, 22), fur.darkened(0.08))

	# Head
	_poly(_ell(head_c, hrx, hry), fur)

	# Coat patterns on the face
	match pattern:
		1:
			for k in 3:
				var x := -12.0 + k * 12.0
				draw_line(head_c + Vector2(x, -hry + 6), head_c + Vector2(x * 0.6, -hry + 26), dark, 4.0)
			for sx in [-1.0, 1.0]:
				draw_line(head_c + Vector2(sx * (hrx - 4), 2), head_c + Vector2(sx * (hrx - 20), 8), dark, 4.0)
				draw_line(head_c + Vector2(sx * (hrx - 4), 14), head_c + Vector2(sx * (hrx - 18), 18), dark, 4.0)
		2:
			for pnt in [Vector2(-34, -24), Vector2(30, -32), Vector2(40, 12), Vector2(-42, 18), Vector2(8, -40)]:
				_poly(_ell(head_c + pnt, 9, 7), fur2)
		3:
			_poly(_ell(head_c + Vector2(0, 26), 34, 28), Color("#f7f3ec"))
			_poly(PackedVector2Array([head_c + Vector2(-8, -hry + 4), head_c + Vector2(8, -hry + 4), head_c + Vector2(12, 4), head_c + Vector2(-12, 4)]), Color("#f7f3ec"))
		4:
			_poly(_ell(head_c + Vector2(-22, -6), 22, 20), fur2)

	# Dog snout / cat muzzle
	if dog:
		_poly(_ell(head_c + Vector2(0, 26), 30, 24), light if pattern != 3 else Color("#f7f3ec"))
	else:
		_poly(_ell(head_c + Vector2(-9, 22), 13, 10), light)
		_poly(_ell(head_c + Vector2(9, 22), 13, 10), light)

	# Eyes
	var eye_i := _g("pet_eye")
	for sx in [-1.0, 1.0]:
		var ec := Color(PET_EYES[0])
		if PET_EYES[eye_i] == "odd":
			ec = Color("#4a90d9") if sx < 0 else Color("#e0a526")
		else:
			ec = Color(PET_EYES[eye_i])
		var e := head_c + Vector2(sx * 22, -6 if dog else -4)
		if dog:
			draw_circle(e, 9, Color("#2a1a12"))
			draw_circle(e, 7.5, ec.darkened(0.2))
			draw_circle(e, 4.5, Color("#120c08"))
			draw_circle(e + Vector2(2.5, -2.5), 2.2, Color.WHITE)
			draw_line(e + Vector2(-8, -14), e + Vector2(6, -16), dark, 3.0)
		else:
			_poly(_ell(e, 12, 10), ec)
			_poly(_ell(e, 3, 8.5), Color("#111111"))
			draw_circle(e + Vector2(3.5, -3.5), 2.2, Color.WHITE)
			draw_polyline(_arc(e, 12.5, 10.5, PI, TAU, 10), Color("#2a1a12"), 1.6, true)

	# Front ears for floppy dogs
	if dog and ears == 0:
		for sx in [-1.0, 1.0]:
			var ep := PackedVector2Array()
			for k in 20:
				var a := TAU * k / 20.0
				ep.append(head_c + Vector2(sx * (hrx - 2), -14) + Vector2(cos(a) * 16, sin(a) * 36).rotated(sx * 0.25))
			_poly(ep, fur.darkened(0.2))

	# Nose, mouth, whiskers
	if dog:
		_poly(_ell(head_c + Vector2(0, 14), 12, 8), Color("#1e1716"))
		draw_circle(head_c + Vector2(-3, 11), 2.5, Color(1, 1, 1, 0.5))
		draw_line(head_c + Vector2(0, 22), head_c + Vector2(0, 32), Color("#1e1716"), 2.0)
		draw_polyline(_arc(head_c + Vector2(-9, 32), 9, 6, 0, PI, 8), Color("#1e1716"), 2.0, true)
		draw_polyline(_arc(head_c + Vector2(9, 32), 9, 6, 0, PI, 8), Color("#1e1716"), 2.0, true)
		_poly(_ell(head_c + Vector2(0, 44), 8, 9), Color("#e8707f"))
	else:
		_poly(PackedVector2Array([head_c + Vector2(-6, 13), head_c + Vector2(6, 13), head_c + Vector2(0, 20)]), Color("#e88a9a"))
		draw_polyline(_arc(head_c + Vector2(-5, 24), 5, 4, 0, PI, 6), Color("#3a2a24"), 1.6, true)
		draw_polyline(_arc(head_c + Vector2(5, 24), 5, 4, 0, PI, 6), Color("#3a2a24"), 1.6, true)
		for sx in [-1.0, 1.0]:
			for k in 3:
				draw_line(head_c + Vector2(sx * 16, 20 + k * 4), head_c + Vector2(sx * 52, 12 + k * 8), Color(1, 1, 1, 0.75), 1.2)

	# Collar
	var collar := _g("collar")
	var cc := _col(CLOTH, "collar_color")
	var ny := CY + hry + 4.0
	match collar:
		1, 2:
			_poly(PackedVector2Array([Vector2(CX - 44, ny - 4), Vector2(CX + 44, ny - 4), Vector2(CX + 42, ny + 8), Vector2(CX - 42, ny + 8)]), cc)
			if collar == 2:
				draw_circle(Vector2(CX, ny + 14), 8, Color("#e0b23a"))
				draw_line(Vector2(CX - 6, ny + 16), Vector2(CX + 6, ny + 16), Color("#8a6a1a"), 1.5)
			else:
				draw_circle(Vector2(CX, ny + 12), 6, Color("#c9ced6"))
		3:
			_poly(PackedVector2Array([Vector2(CX - 46, ny - 6), Vector2(CX + 46, ny - 6), Vector2(CX, ny + 38)]), cc)
			for k in 4:
				draw_circle(Vector2(CX - 18 + k * 12, ny + 4 + (k % 2) * 8), 2.5, Color(1, 1, 1, 0.8))
		4:
			_poly(PackedVector2Array([Vector2(CX, ny + 4), Vector2(CX - 22, ny - 8), Vector2(CX - 22, ny + 16)]), cc)
			_poly(PackedVector2Array([Vector2(CX, ny + 4), Vector2(CX + 22, ny - 8), Vector2(CX + 22, ny + 16)]), cc)
			draw_circle(Vector2(CX, ny + 4), 6, cc.darkened(0.2))
