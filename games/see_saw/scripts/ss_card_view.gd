class_name SSCardView
extends Control
## Draws one playing card. Jacks, Queens, Kings and Aces are characters with a portrait.
## Small cards ("mini", under 90px wide) show just the rank and suit.
## (Same card drawing as War and Piece.)

signal tapped(view: SSCardView)

const RED := Color("#c8343e")
const BLACK := Color("#1e2233")
const PAPER := Color("#fbf7ee")
const BACK := Color("#7a1f2b")
const GOLD := Color("#ffc83d")

static var _art := {}

var card: Dictionary = {}
var face_down := false
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
## In a fanned-out set: rank and suit squeezed into the left edge so they show.
var stacked := false
## A coloured ring (green = right answer, red = your wrong pick). Transparent = none.
var ring := Color(0, 0, 0, 0):
	set(v):
		ring = v
		queue_redraw()
var glow := false:
	set(v):
		glow = v
		queue_redraw()


func setup(c: Dictionary, down := false) -> SSCardView:
	card = c
	face_down = down
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	return self


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		tapped.emit(self)
		accept_event()


static func art(role: String) -> Texture2D:
	if not _art.has(role):
		_art[role] = load("res://art/role-%s.png" % role)
	return _art[role]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rad := int(maxf(4.0, w * 0.08))
	var r := Rect2(Vector2.ZERO, size)
	if glow:
		draw_style_box(UI.box(Color(GOLD, 0.45), rad + 6), r.grow(6))
	if face_down:
		_draw_back(r, rad)
	else:
		_draw_face(r, rad)
	if selected:
		draw_style_box(_outline(GOLD, rad, maxi(3, int(w * 0.05))), r)
	if ring.a > 0:
		draw_style_box(_outline(ring, rad, maxi(5, int(w * 0.06))), r.grow(3))
	if dimmed:
		draw_style_box(UI.box(Color(0.08, 0.09, 0.16, 0.55), rad), r)


func _outline(col: Color, rad: int, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(rad)
	sb.border_color = col
	sb.set_border_width_all(bw)
	return sb


func _draw_back(r: Rect2, rad: int) -> void:
	draw_style_box(UI.box(BACK, rad, Color("#f3d9a4"), maxi(2, int(r.size.x * 0.035))), r)
	var inner := r.grow(-r.size.x * 0.12)
	draw_style_box(_outline(Color(GOLD, 0.55), maxi(2, rad - 4), maxi(1, int(r.size.x * 0.02))), inner)
	# A diamond lattice
	var step := r.size.x * 0.19
	var col := Color(GOLD, 0.18)
	var y := inner.position.y + step * 0.5
	var row := 0
	while y < inner.end.y - step * 0.3:
		var x := inner.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < inner.end.x - step * 0.3:
			draw_suit("D", Vector2(x, y), step * 0.32, col)
			x += step
		y += step * 0.5
		row += 1
	if r.size.x >= 90:
		var f := UI.font(900)
		var fs := int(r.size.x * 0.2)
		var cen := r.get_center()
		draw_circle(cen, r.size.x * 0.26, BACK)
		draw_arc(cen, r.size.x * 0.26, 0, TAU, 48, GOLD, maxf(2, r.size.x * 0.02), true)
		draw_string(f, Vector2(r.position.x, cen.y + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, GOLD)


func _draw_face(r: Rect2, rad: int) -> void:
	var w := r.size.x
	var h := r.size.y
	draw_style_box(UI.box(PAPER, rad, Color("#d9d2c0"), maxi(1, int(w * 0.015))), r)
	var col := RED if SSCards.is_red(card) else BLACK
	var f := UI.font(900)
	var rank: String = SSCards.rank_short(card["rank"])
	var suit: String = card["suit"]
	if w < 90 and stacked:
		var fs3 := int(w * 0.34)
		draw_string(f, Vector2(w * 0.04, h * 0.3), rank, HORIZONTAL_ALIGNMENT_CENTER, w * 0.44, fs3, col)
		draw_suit(suit, Vector2(w * 0.26, h * 0.46), w * 0.13, col)
		return
	if w < 90:
		# Mini card: big rank, suit under it.
		var fs := int(w * 0.42)
		draw_string(f, Vector2(0, h * 0.44), rank, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
		draw_suit(suit, Vector2(w * 0.5, h * 0.7), w * 0.2, col)
		return
	var fs2 := int(w * 0.17)
	var cx := w * 0.13
	draw_string(f, Vector2(0, h * 0.02 + fs2 * 0.95), rank, HORIZONTAL_ALIGNMENT_CENTER, cx * 2, fs2, col)
	draw_suit(suit, Vector2(cx, h * 0.02 + fs2 * 1.45), w * 0.06, col)
	draw_string(f, Vector2(w - cx * 2, h - h * 0.02 - fs2 * 0.25), rank, HORIZONTAL_ALIGNMENT_CENTER, cx * 2, fs2, col)
	draw_suit(suit, Vector2(w - cx, h - h * 0.02 - fs2 * 1.25), w * 0.06, col)
	var ch: Dictionary = SSCards.CHARACTERS.get(int(card["rank"]), {})
	if ch.is_empty():
		_draw_pips(r, col)
		return
	var box := Rect2(w * 0.25, h * 0.12, w * 0.5, w * 0.5)
	draw_style_box(UI.box(Color(col, 0.12), int(w * 0.05)), box.grow(w * 0.02))
	var tex := art(ch["role"])
	if tex:
		draw_texture_rect(tex, box, false)
	var ns := int(w * 0.11)
	draw_string(UI.font(900), Vector2(0, box.end.y + w * 0.05 + ns), ch["name"], HORIZONTAL_ALIGNMENT_CENTER, w, ns, col)
	if w >= 160:
		var ts := int(w * 0.06)
		draw_string(UI.font(700), Vector2(w * 0.1, box.end.y + w * 0.08 + ns + ts * 1.1), ch["title"], HORIZONTAL_ALIGNMENT_CENTER, w * 0.8, ts, Color(col, 0.75))


func _draw_pips(r: Rect2, col: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	var n: int = card["rank"]
	var area := Rect2(w * 0.28, h * 0.14, w * 0.44, h * 0.72)
	var pts: Array = PIPS.get(n, [])
	var s := w * (0.085 if n > 3 else 0.11)
	for p in pts:
		var at := area.position + Vector2(p.x * area.size.x, p.y * area.size.y)
		draw_suit(card["suit"], at, s, col, p.y > 0.55)


# Pip layouts in a 0..1 box, like a real deck.
const PIPS := {
	2: [Vector2(0.5, 0.05), Vector2(0.5, 0.95)],
	3: [Vector2(0.5, 0.05), Vector2(0.5, 0.5), Vector2(0.5, 0.95)],
	4: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0, 0.95), Vector2(1, 0.95)],
	5: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0.5, 0.5), Vector2(0, 0.95), Vector2(1, 0.95)],
	6: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0, 0.95), Vector2(1, 0.95)],
	7: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0.5, 0.27), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0, 0.95), Vector2(1, 0.95)],
	8: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0.5, 0.27), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 0.73), Vector2(0, 0.95), Vector2(1, 0.95)],
	9: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0, 0.35), Vector2(1, 0.35), Vector2(0.5, 0.5), Vector2(0, 0.65), Vector2(1, 0.65), Vector2(0, 0.95), Vector2(1, 0.95)],
	10: [Vector2(0, 0.05), Vector2(1, 0.05), Vector2(0.5, 0.2), Vector2(0, 0.35), Vector2(1, 0.35), Vector2(0, 0.65), Vector2(1, 0.65), Vector2(0.5, 0.8), Vector2(0, 0.95), Vector2(1, 0.95)],
}


## Suits are drawn as shapes so they look the same on every device.
func draw_suit(suit: String, c: Vector2, s: float, col: Color, flip := false) -> void:
	suit_on(self, suit, c, s, col, flip)


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
