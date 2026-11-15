class_name GemView
extends Control
## One gem: the painted picture, or a code-drawn placeholder if it's missing.

var kind := "ruby"


func _draw() -> void:
	var t := Art.treasure(kind)
	if t != null:
		Art.draw_fit(self, t, Rect2(Vector2.ZERO, size))
	else:
		CardView.draw_gem(self, kind, size / 2.0, minf(size.x, size.y) * 0.42)
