class_name BillOverlay
extends Control
## Draws a bill on top of its portrait: the bill art (or a drawn fallback) with an
## oval window, the value in the four corners, and the face's name on the banner.
## Layout matches the bill art prompt: oval centered at (300,360), 360x400 on a 600x840 card.

const TINTS := [Color("#8fb89a"), Color("#7fb2e0"), Color("#e9a64a"), Color("#a993d6"), Color("#e08497")]
const OVAL_C := Vector2(0.5, 360.0 / 840.0)
const OVAL_R := Vector2(180.0 / 600.0, 200.0 / 840.0)

var value := 1
var name_text := ""
var card: Control   # the CardView this sits on (for selected / highlight / dimmed)


static func oval_rect(sz: Vector2) -> Rect2:
	var c := Vector2(sz.x * OVAL_C.x, sz.y * OVAL_C.y)
	var r := Vector2(sz.x * OVAL_R.x, sz.y * OVAL_R.y)
	return Rect2(c - r, r * 2.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var tex := Art.tex("bill-%d" % value)
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		_draw_fallback(w, h)
	var font := ThemeDB.fallback_font
	var ink := Color("#2b2233")
	var fs := int(w * 0.105)
	for p in [Vector2(75, 75), Vector2(525, 75), Vector2(75, 765), Vector2(525, 765)]:
		var c := Vector2(p.x / 600.0 * w, p.y / 840.0 * h)
		var pos := Vector2(c.x - w * 0.1, c.y + fs * 0.36)
		draw_string_outline(font, pos, str(value), HORIZONTAL_ALIGNMENT_CENTER, w * 0.2, fs, maxi(2, int(w * 0.012)), Color(1, 1, 1, 0.9))
		draw_string(font, pos, str(value), HORIZONTAL_ALIGNMENT_CENTER, w * 0.2, fs, ink)
	if w >= 90.0:
		var nfs := int(w * 0.075)
		var ny := h * (640.0 / 840.0) + nfs * 0.36
		draw_string_outline(font, Vector2(w * 0.2, ny), name_text, HORIZONTAL_ALIGNMENT_CENTER, w * 0.6, nfs, maxi(2, int(w * 0.01)), Color(1, 1, 1, 0.85))
		draw_string(font, Vector2(w * 0.2, ny), name_text, HORIZONTAL_ALIGNMENT_CENTER, w * 0.6, nfs, ink)
		var bfs := int(w * 0.06)
		var by := h * 0.9 + bfs * 0.36
		var label := CardDB.bills(value).to_upper()
		draw_string_outline(font, Vector2(0, by), label, HORIZONTAL_ALIGNMENT_CENTER, w, bfs, maxi(2, int(w * 0.01)), Color(1, 1, 1, 0.85))
		draw_string(font, Vector2(0, by), label, HORIZONTAL_ALIGNMENT_CENTER, w, bfs, ink)
	if card != null:
		var r := Rect2(Vector2.ZERO, size)
		if card.get("dimmed"):
			_rounded(r, Color(0, 0, 0, 0.35), w * 0.07)
		if card.get("selected") or card.get("highlight"):
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.set_corner_radius_all(int(w * 0.07))
			sb.set_border_width_all(5)
			sb.border_color = Color.WHITE if card.get("selected") else Color("#ffe14a")
			draw_style_box(sb, r)


func _draw_fallback(w: float, h: float) -> void:
	var tint: Color = TINTS[clampi(value - 1, 0, 4)]
	var paper := tint.lerp(Color("#f6f1e2"), 0.55)
	var o := oval_rect(size)
	var oc := o.get_center()
	var orx := o.size.x / 2.0
	var ory := o.size.y / 2.0
	var cr := w * 0.07
	var left := PackedVector2Array()
	left.append(Vector2(oc.x, 0))
	for k in 7:
		var a := -PI / 2.0 - PI / 2.0 * k / 6.0
		left.append(Vector2(cr, cr) + Vector2(cos(a), sin(a)) * cr)
	for k in 7:
		var a := PI + (-PI / 2.0) * k / 6.0
		left.append(Vector2(cr, h - cr) + Vector2(cos(a), sin(a)) * cr)
	left.append(Vector2(oc.x, h))
	for k in 25:
		var a := PI / 2.0 + PI * k / 24.0
		left.append(Vector2(oc.x + cos(a) * orx, oc.y + sin(a) * ory))
	var right := PackedVector2Array()
	for pt in left:
		right.append(Vector2(w - pt.x, pt.y))
	draw_colored_polygon(left, paper)
	draw_colored_polygon(right, paper)
	# engraving
	var ink := tint.darkened(0.35)
	var inset := w * 0.045
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(int(cr * 0.8))
	sb.set_border_width_all(maxi(1, int(w * 0.012)))
	sb.border_color = ink
	draw_style_box(sb, Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0))
	var ring := PackedVector2Array()
	for k in 49:
		var a := TAU * k / 48.0
		ring.append(oc + Vector2(cos(a) * orx, sin(a) * ory))
	draw_polyline(ring, ink, maxf(1.5, w * 0.012), true)
	for p in [Vector2(75, 75), Vector2(525, 75), Vector2(75, 765), Vector2(525, 765)]:
		var c := Vector2(p.x / 600.0 * w, p.y / 840.0 * h)
		draw_circle(c, w * 0.075, tint.lerp(Color.WHITE, 0.7))
		draw_arc(c, w * 0.075, 0, TAU, 24, ink, maxf(1.0, w * 0.008), true)
	var banner := Rect2(w * 0.2, h * (600.0 / 840.0), w * 0.6, h * (80.0 / 840.0))
	draw_rect(banner, tint.lerp(Color.WHITE, 0.7))
	draw_rect(banner, ink, false, maxf(1.0, w * 0.008))


func _rounded(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
