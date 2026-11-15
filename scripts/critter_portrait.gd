class_name CritterPortrait
extends Control
## Default bill portrait: the critter (Mouse, Raccoon, Fox, Owl, Magpie) filling the oval.

var kind := "loot1"


func _draw() -> void:
	var t := Art.loot(kind)
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color("#efe6cf"))
	if t != null:
		draw_texture_rect(t, Rect2(c - Vector2(r, r) * 1.02, Vector2(r, r) * 2.04), false)
	else:
		draw_circle(c, r * 0.8, Art.COPPER)
