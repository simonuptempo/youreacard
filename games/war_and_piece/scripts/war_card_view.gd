class_name WarCardView
extends Control
## Draws one playing card. Jacks, Queens, Kings and Aces are characters with a portrait.
## Small cards ("mini", under 90px wide) show just the rank and suit.

signal tapped(view: WarCardView)

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
var glow := false:
	set(v):
		glow = v
		queue_redraw()
## Custom faces come from the shared Profile (made in the app's My Cards screen).
## A face to show instead of the saved one (a preview).
var face: Dictionary = {}
## A name to show instead of the saved one (the card maker's preview).
var preview_name := ""
## Shown in My Cards (no extra badge here; kept so Gem Heist's screens can set it).
var editable := false
var _avatar: AvatarView


func setup(c: Dictionary, down := false, face_override: Dictionary = {}) -> WarCardView:
	card = c
	face_down = down
	face = face_override
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_avatar()
	queue_redraw()
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_avatar()


## The character's role on this card, or "" for number cards.
func role() -> String:
	if card.is_empty():
		return ""
	return str(WarCards.CHARACTERS.get(int(card.get("rank", 0)), {}).get("role", ""))


## The face this card shows: the preview, your saved face, or {} for the painted character.
func shown_face() -> Dictionary:
	var r := role()
	if r == "":
		return {}
	if not face.is_empty():
		return face
	return Profile.slot_face(r)


func shown_name() -> String:
	if preview_name != "":
		return preview_name
	var r := role()
	return Profile.face_name(r) if r != "" else ""


func _portrait_box() -> Rect2:
	var w := size.x
	return Rect2(w * 0.25, size.y * 0.12, w * 0.5, w * 0.5)


## Custom faces are drawn by an AvatarView (a cartoon from a photo, or one you built).
func _sync_avatar() -> void:
	var f := shown_face()
	var show := not f.is_empty() and not face_down and size.x >= 90 and not card.is_empty()
	if not show:
		if _avatar:
			_avatar.queue_free()
			_avatar = null
		return
	if _avatar == null:
		_avatar = AvatarView.new()
		_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_avatar)
	_avatar.role = role()
	_avatar.data = f
	var b := _portrait_box()
	_avatar.position = b.position
	_avatar.size = b.size


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
	if dimmed:
		draw_style_box(UI.box(Color(0.08, 0.09, 0.16, 0.55), rad), r)
	if _avatar:
		_avatar.modulate = Color(0.5, 0.5, 0.55) if dimmed else Color.WHITE


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
		draw_string(f, Vector2(r.position.x, cen.y + fs * 0.36), "W&P", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, GOLD)


func _draw_face(r: Rect2, rad: int) -> void:
	var w := r.size.x
	var h := r.size.y
	draw_style_box(UI.box(PAPER, rad, Color("#d9d2c0"), maxi(1, int(w * 0.015))), r)
	var col := RED if WarCards.is_red(card) else BLACK
	var f := UI.font(900)
	var rank: String = WarCards.rank_short(card["rank"])
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
	var ch: Dictionary = WarCards.CHARACTERS.get(int(card["rank"]), {})
	if ch.is_empty():
		_draw_pips(r, col)
		return
	var box := _portrait_box()
	draw_style_box(UI.box(Color(col, 0.12), int(w * 0.05)), box.grow(w * 0.02))
	if _avatar == null:
		var tex := art(ch["role"])
		if tex:
			draw_texture_rect(tex, box, false)
	var ns := int(w * 0.11)
	var who := shown_name()
	if who.length() > 9:
		ns = int(ns * 9.0 / who.length())
	draw_string(UI.font(900), Vector2(0, box.end.y + w * 0.05 + int(w * 0.11)), who, HORIZONTAL_ALIGNMENT_CENTER, w, ns, col)
	if w >= 160:
		var ts := int(w * 0.06)
		draw_string(UI.font(700), Vector2(w * 0.1, box.end.y + w * 0.08 + int(w * 0.11) + ts * 1.1), ch["title"], HORIZONTAL_ALIGNMENT_CENTER, w * 0.8, ts, Color(col, 0.75))


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
	var d := -1.0 if flip else 1.0
	match suit:
		"D":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.72, 0), c + Vector2(0, s), c + Vector2(-s * 0.72, 0)]), col)
		"H":
			draw_circle(c + Vector2(-s * 0.45, -s * 0.3 * d), s * 0.5, col)
			draw_circle(c + Vector2(s * 0.45, -s * 0.3 * d), s * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.15 * d), c + Vector2(s * 0.93, -s * 0.15 * d), c + Vector2(0, s * d)]), col)
		"S":
			draw_circle(c + Vector2(-s * 0.45, s * 0.2 * d), s * 0.48, col)
			draw_circle(c + Vector2(s * 0.45, s * 0.2 * d), s * 0.48, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.91, s * 0.08 * d), c + Vector2(s * 0.91, s * 0.08 * d), c + Vector2(0, -s * d)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.3 * d), c + Vector2(s * 0.3, s * d), c + Vector2(-s * 0.3, s * d)]), col)
		"C":
			draw_circle(c + Vector2(0, -s * 0.45 * d), s * 0.42, col)
			draw_circle(c + Vector2(-s * 0.48, s * 0.12 * d), s * 0.42, col)
			draw_circle(c + Vector2(s * 0.48, s * 0.12 * d), s * 0.42, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.1 * d), c + Vector2(s * 0.3, s * d), c + Vector2(-s * 0.3, s * d)]), col)
