class_name SSCardView
extends WarCardView
## Shared personalized portraits and rank layout; See Saw adds its answer ring.
var ring := Color.TRANSPARENT:
	set(v):
		ring = v
		queue_redraw()

func _draw() -> void:
	super._draw()
	if ring.a > 0:
		draw_style_box(_outline(ring, int(maxf(4, size.x * 0.08)), maxi(5, int(size.x * 0.06))), Rect2(Vector2.ZERO, size).grow(3))

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
