class_name Icon
extends Control
## Tiny vector icons (so we don't depend on emoji glyphs in the font).

@export var kind := "gear"
@export var color := Color("#f4f1ea")


static func make(k: String, pos: Vector2, sz: Vector2, col := Color("#f4f1ea")) -> Icon:
	var i := Icon.new()
	i.kind = k
	i.color = col
	i.position = pos
	i.size = sz
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5
	match kind:
		"reference":
			var bounds := Rect2(c + Vector2(-r*0.65,-r*0.8),Vector2(r*1.3,r*1.6))
			draw_rect(bounds,color,false,maxf(2.0,r*0.12))
			for row in 3:
				var y := c.y-r*0.4+row*r*0.4
				draw_line(Vector2(c.x-r*0.38,y),Vector2(c.x+r*0.38,y),color,maxf(2.0,r*0.1),true)
		"replay":
			draw_arc(c, r * 0.62, deg_to_rad(-60), deg_to_rad(250), 24, color, maxf(2.0, r * 0.16), true)
			var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * r * 0.62
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.32, -r * 0.1), tip + Vector2(r * 0.12, -r * 0.34), tip + Vector2(r * 0.12, r * 0.2)]), color)
		"gear":
			for t in 8:
				var a := TAU * t / 8.0
				var dir := Vector2(cos(a), sin(a))
				var perp := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([
					c + dir * r * 0.55 + perp * r * 0.16, c + dir * r * 0.95 + perp * r * 0.12,
					c + dir * r * 0.95 - perp * r * 0.12, c + dir * r * 0.55 - perp * r * 0.16]), color)
			draw_circle(c, r * 0.68, color)
			draw_circle(c, r * 0.28, Color("#1b2038"))
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.6), c + Vector2(r * 0.6, 0), c + Vector2(-r * 0.4, r * 0.6)]), color)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.3, -r * 0.6), c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.3, r * 0.6)]), color, r * 0.22, true)
		"bell":
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.55, color)
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.55)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.75, r * 0.4), Vector2(r * 1.5, r * 0.15)), color)
			draw_circle(c + Vector2(0, r * 0.7), r * 0.15, color)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.55, 0), c + Vector2(-r * 0.15, r * 0.45), c + Vector2(r * 0.6, -r * 0.5)]), color, r * 0.25, true)
		"camera":
			var body := Rect2(c + Vector2(-r * 0.9, -r * 0.45), Vector2(r * 1.8, r * 1.2))
			draw_rect(Rect2(c + Vector2(-r * 0.32, -r * 0.68), Vector2(r * 0.64, r * 0.3)), color)
			draw_rect(body, color)
			draw_circle(c + Vector2(0, r * 0.15), r * 0.42, Color("#1b2038"))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.28, color)
			draw_circle(c + Vector2(r * 0.62, -r * 0.25), r * 0.08, Color("#1b2038"))
		"photos":
			var back := Rect2(c + Vector2(-r * 0.7, -r * 0.85), Vector2(r * 1.55, r * 1.2))
			draw_rect(back, color, false, maxf(2.0, r * 0.1))
			var front := Rect2(c + Vector2(-r * 0.9, -r * 0.55), Vector2(r * 1.55, r * 1.25))
			draw_rect(front, color)
			draw_circle(front.position + Vector2(r * 0.45, r * 0.38), r * 0.16, Color("#1b2038"))
			draw_colored_polygon(PackedVector2Array([front.position + Vector2(r * 0.1, front.size.y - r * 0.1),
				front.position + Vector2(r * 0.7, r * 0.55), front.position + Vector2(front.size.x - r * 0.1, front.size.y - r * 0.1)]), Color("#1b2038"))
		"mic":
			draw_rect(Rect2(c + Vector2(-r * 0.26, -r * 0.85), Vector2(r * 0.52, r * 1.0)), color)
			draw_circle(c + Vector2(0, -r * 0.6), r * 0.26, color)
			draw_circle(c + Vector2(0, r * 0.15), r * 0.26, color)
			draw_arc(c + Vector2(0, r * 0.05), r * 0.5, 0.0, PI, 16, color, maxf(2.0, r * 0.1), true)
			draw_line(c + Vector2(0, r * 0.55), c + Vector2(0, r * 0.85), color, maxf(2.0, r * 0.1))
			draw_line(c + Vector2(-r * 0.3, r * 0.85), c + Vector2(r * 0.3, r * 0.85), color, maxf(2.0, r * 0.1))
		"wand":
			draw_line(c + Vector2(-r * 0.75, r * 0.75), c + Vector2(r * 0.3, -r * 0.3), color, maxf(3.0, r * 0.16), true)
			for t in 4:
				var a := TAU * t / 4.0 + PI / 4.0
				draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(r * 0.5, -r * 0.5) + Vector2(cos(a), sin(a)) * r * 0.38, color, maxf(2.0, r * 0.09), true)
		"face":
			draw_circle(c, r * 0.82, color)
			draw_circle(c + Vector2(-r * 0.3, -r * 0.18), r * 0.11, Color("#1b2038"))
			draw_circle(c + Vector2(r * 0.3, -r * 0.18), r * 0.11, Color("#1b2038"))
			draw_arc(c + Vector2(0, r * 0.05), r * 0.38, 0.35, PI - 0.35, 14, Color("#1b2038"), maxf(2.0, r * 0.1), true)
			draw_arc(c + Vector2(0, -r * 0.15), r * 0.86, PI + 0.25, TAU - 0.25, 18, Color("#1b2038"), maxf(3.0, r * 0.2), true)
