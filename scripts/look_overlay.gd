extends AvatarView
## Temporary vector accessories only. Never modifies the portrait or AI input.
var edits: Dictionary = {}
var offset := Vector2.ZERO
var fit := 1.0
var dragging := false
signal moved(value: Vector2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		offset += event.relative / size
		offset = offset.clamp(Vector2(-0.4,-0.4),Vector2(0.4,0.4))
		moved.emit(offset)
		queue_redraw()

func _draw() -> void:
	var s := minf(size.x/200.0,size.y/240.0) * fit
	var origin := size/2 - Vector2(100,120)*s + offset*size
	draw_set_transform(origin,0,Vector2(s,s))
	if edits.has("hat"): _hat(_g("hat"),54,58)
	if edits.has("eyewear"): _eyewear(_g("eyewear"),54)
	if edits.has("ears"): _ears_accessory(54)
	if edits.get("bowtie","") == "Bow tie":
		_poly(PackedVector2Array([Vector2(100,184),Vector2(77,172),Vector2(77,196)]),Color("#c44959"))
		_poly(PackedVector2Array([Vector2(100,184),Vector2(123,172),Vector2(123,196)]),Color("#c44959"))
		draw_circle(Vector2(100,184),5,Color("#853342"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
