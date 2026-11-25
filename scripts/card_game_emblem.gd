class_name CardGameEmblem
extends Control
## Small, scalable character-card mark shared by menus, tiles and card backs.
static var _textures := {}
var kind := "war_and_piece"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_mark(self, Rect2(Vector2.ZERO, size), kind)

static func draw_mark(ci: CanvasItem, rect: Rect2, game: String) -> void:
	var sc := minf(rect.size.x / 180.0, rect.size.y / 150.0)
	var origin := rect.get_center() - Vector2(90, 75) * sc
	if game == "see_saw":
		ci.draw_set_transform(origin, 0, Vector2.ONE * sc)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(75, 144), Vector2(90, 116), Vector2(105, 144)]), Color("#3cb371"))
		ci.draw_line(Vector2(15, 121), Vector2(165, 104), Color("#78d9cb"), 8, true)
	for i in 2:
		var at := Vector2(57 + i * 65, 69 - i * 8)
		ci.draw_set_transform(origin + at * sc, -0.16 if i == 0 else 0.16, Vector2.ONE * sc)
		ci.draw_style_box(UI.box(Color("#fbf7ee"), 10, Color("#ffc83d"), 3), Rect2(-37, -53, 74, 106))
		var role := "boss" if i == 0 else "trickster"
		if not _textures.has(role):
			_textures[role] = load("res://art/role-%s.png" % role)
		var tex: Texture2D = _textures[role]
		if tex:
			ci.draw_texture_rect(tex, Rect2(-31, -31, 62, 62), false)
		ci.draw_string(UI.font(900), Vector2(-29, -34), "K" if i == 0 else "Q", HORIZONTAL_ALIGNMENT_LEFT, 60, 17, Color("#c8343e"))
		if game == "war_and_piece":
			# Crown and peace symbol: a legible mark even without a wordmark.
			if i == 0:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, 44), Vector2(-16, 32), Vector2(-5, 37), Vector2(0, 28), Vector2(5, 37), Vector2(16, 32), Vector2(12, 44)]), Color("#c8343e"))
			else:
				ci.draw_arc(Vector2(0, 38), 10, 0, TAU, 32, Color("#278878"), 2, true)
				ci.draw_line(Vector2(0, 28), Vector2(0, 48), Color("#278878"), 2, true)
				ci.draw_line(Vector2(0, 38), Vector2(-7, 45), Color("#278878"), 2, true)
				ci.draw_line(Vector2(0, 38), Vector2(7, 45), Color("#278878"), 2, true)
	ci.draw_set_transform(Vector2.ZERO)
