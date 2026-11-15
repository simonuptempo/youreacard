class_name CoinView
extends Control
## A mini bill for bank displays: a tinted portrait-shaped note with its value.
## (Kept the old name so existing callers keep working.)

var kind := "loot1"


static func make(k: String, pos: Vector2, d: float) -> CoinView:
	var c := CoinView.new()
	c.kind = k
	c.position = pos
	c.size = Vector2(d * 5.0 / 7.0, d)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void:
	var v := CardDB.value(kind)
	var tint: Color = BillOverlay.TINTS[clampi(v - 1, 0, 4)]
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.lerp(Color("#f6f1e2"), 0.35)
	sb.set_corner_radius_all(int(size.x * 0.12))
	sb.border_color = tint.darkened(0.4)
	sb.set_border_width_all(1)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := size / 2.0
	var o := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		o.append(c + Vector2(cos(a) * size.x * 0.3, sin(a) * size.y * 0.3))
	draw_colored_polygon(o, Color(1, 1, 1, 0.55))
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.5)
	draw_string(font, Vector2(0, c.y + fs * 0.36), str(v), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("#2b2233"))
