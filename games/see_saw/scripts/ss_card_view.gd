class_name SSCardView
extends WarCardView
## Shared personalized portraits and rank layout; See Saw adds its answer ring.
## In See Saw every rank has a character on it (SSCards.CHARACTERS), and there's one
## extra card: Nana Bea's counterweight ({"counterweight": true}), worth an extra life.
var ring := Color.TRANSPARENT:
	set(v):
		ring = v
		queue_redraw()

func _draw() -> void:
	super._draw()
	if ring.a > 0:
		draw_style_box(_outline(ring, int(maxf(4, size.x * 0.08)), maxi(5, int(size.x * 0.06))), Rect2(Vector2.ZERO, size).grow(3))

static var _ss_art := {}


## The painted portrait for a Profile slot (crew roles, Nana Bea, or a bill critter).
static func ss_art(slot: String) -> Texture2D:
	if not _ss_art.has(slot):
		# Bill critters (Mouse, Raccoon…) use their loot portraits; everyone else their role art.
		_ss_art[slot] = Art.loot("loot" + slot.substr(4)) if slot.begins_with("bill") else load("res://art/role-%s.png" % slot)
	return _ss_art[slot]


func is_counterweight() -> bool:
	return bool(card.get("counterweight", false))


func role() -> String:
	if card.is_empty():
		return ""
	if is_counterweight():
		return "you"
	return str(SSCards.CHARACTERS.get(int(card.get("rank", 0)), {}).get("role", ""))


func _draw_face(r: Rect2, rad: int) -> void:
	var w := r.size.x
	var h := r.size.y
	if is_counterweight():
		_draw_counterweight(r, rad)
		return
	if w < 90:
		super._draw_face(r, rad)   # small cards: just rank and suit
		return
	draw_style_box(UI.box(PAPER, rad, Color("#d9d2c0"), maxi(1, int(w * 0.015))), r)
	var col := RED if SSCards.is_red(card) else BLACK
	var f := UI.font(900)
	var rank: String = SSCards.rank_short(card["rank"])
	var suit: String = card["suit"]
	var fs2 := int(w * 0.17)
	var cx := w * 0.13
	draw_string(f, Vector2(0, h * 0.02 + fs2 * 0.95), rank, HORIZONTAL_ALIGNMENT_CENTER, cx * 2, fs2, col)
	draw_suit(suit, Vector2(cx, h * 0.02 + fs2 * 1.45), w * 0.06, col)
	draw_string(f, Vector2(w - cx * 2, h - h * 0.02 - fs2 * 0.25), rank, HORIZONTAL_ALIGNMENT_CENTER, cx * 2, fs2, col)
	draw_suit(suit, Vector2(w - cx, h - h * 0.02 - fs2 * 1.25), w * 0.06, col)
	_draw_portrait(col)


func _draw_portrait(col: Color) -> void:
	var w := size.x
	var box := _portrait_box()
	draw_style_box(UI.box(Color(col, 0.12), int(w * 0.05)), box.grow(w * 0.02))
	if _avatar == null:
		var tex := ss_art(role())
		if tex:
			draw_texture_rect(tex, box, false)
	var ns := int(w * 0.11)
	var who := shown_name()
	if who.length() > 9:
		ns = int(ns * 9.0 / who.length())
	draw_string(UI.font(900), Vector2(0, box.end.y + w * 0.05 + int(w * 0.11)), who, HORIZONTAL_ALIGNMENT_CENTER, w, ns, col)


func shown_name() -> String:
	if preview_name != "":
		return preview_name
	if is_counterweight() and not Profile.is_custom("you"):
		return "Nana Bea"
	return super.shown_name()


## Nana Bea's counterweight: gold, "+1" in the corners, and a little weight under her name.
func _draw_counterweight(r: Rect2, rad: int) -> void:
	var w := r.size.x
	var h := r.size.y
	var col := Color("#8a5a00")
	draw_style_box(UI.box(Color("#fff3c4"), rad, GOLD, maxi(2, int(w * 0.03))), r)
	var f := UI.font(900)
	if w < 90:
		draw_string(f, Vector2(0, h * 0.5), "+1", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.36), col)
		return
	var fs2 := int(w * 0.14)
	draw_string(f, Vector2(w * 0.04, h * 0.02 + fs2), "+1", HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs2, col)
	draw_string(f, Vector2(w * 0.56, h - h * 0.03), "+1", HORIZONTAL_ALIGNMENT_RIGHT, w * 0.4, fs2, col)
	_draw_portrait(col)
	if w >= 150:
		var ts := int(w * 0.05)
		draw_string(UI.font(800), Vector2(w * 0.25, h * 0.02 + fs2 * 0.85), "COUNTERWEIGHT", HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, ts, Color(col, 0.8))


func _draw_back(r: Rect2, rad: int) -> void:
	draw_style_box(UI.box(Color("#244f67"), rad, GOLD, 3), r)
	CardGameEmblem.draw_mark(self, Rect2(r.size.x * 0.08, r.size.y * 0.24, r.size.x * 0.84, r.size.y * 0.52), "see_saw")

## Draw a suit shape on any control (hearts for lives, suit buttons...).
static func suit_on(ci: CanvasItem, suit: String, c: Vector2, s: float, col: Color, flip := false) -> void:
	var d := -1.0 if flip else 1.0
	match suit:
		"D":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.72, 0), c + Vector2(0, s), c + Vector2(-s * 0.72, 0)]), col)
		"H":
			ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.3 * d), s * 0.5, col)
			ci.draw_circle(c + Vector2(s * 0.45, -s * 0.3 * d), s * 0.5, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.15 * d), c + Vector2(s * 0.93, -s * 0.15 * d), c + Vector2(0, s * d)]), col)
		"S":
			ci.draw_circle(c + Vector2(-s * 0.45, s * 0.2 * d), s * 0.48, col)
			ci.draw_circle(c + Vector2(s * 0.45, s * 0.2 * d), s * 0.48, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.91, s * 0.08 * d), c + Vector2(s * 0.91, s * 0.08 * d), c + Vector2(0, -s * d)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.3 * d), c + Vector2(s * 0.3, s * d), c + Vector2(-s * 0.3, s * d)]), col)
		"C":
			ci.draw_circle(c + Vector2(0, -s * 0.45 * d), s * 0.42, col)
			ci.draw_circle(c + Vector2(-s * 0.48, s * 0.12 * d), s * 0.42, col)
			ci.draw_circle(c + Vector2(s * 0.48, s * 0.12 * d), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.1 * d), c + Vector2(s * 0.3, s * d), c + Vector2(-s * 0.3, s * d)]), col)
