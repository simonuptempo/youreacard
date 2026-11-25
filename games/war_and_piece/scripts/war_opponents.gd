extends RefCounted
## Advances only when a new local game is created. Saves retain the chosen name.
const NAMES := ["Milo", "Rascal", "Felix", "Olive", "Maggie", "Mei", "Kodi", "Rosa", "Nana Bea"]
const ANIMALS := {"Mouse":"Milo", "Raccoon":"Rascal", "Fox":"Felix", "Owl":"Olive", "Magpie":"Maggie"}
const ROLES := {"Mei":"illusionist", "Kodi":"locksmith", "Rosa":"trapper", "Nana Bea":"you"}
const PATH := "user://wp_opponents.cfg"

static func peek_next(path := PATH) -> String:
	var config := ConfigFile.new()
	config.load(path)
	return NAMES[posmod(int(config.get_value("rotation", "next", 0)), NAMES.size())]

static func take_next(path := PATH) -> String:
	var name := peek_next(path)
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("rotation", "next", (NAMES.find(name) + 1) % NAMES.size())
	if config.save(path) != OK:
		push_warning("Could not save the next animal opponent.")
	return name

static func beaten(name: String, path := PATH) -> bool:
	var config := ConfigFile.new()
	config.load(path)
	var current := display_name(name)
	var legacy := str(ANIMALS.find_key(current)) if current in ANIMALS.values() else current
	return bool(config.get_value("beaten", current, false)) or bool(config.get_value("beaten", legacy, false))

static func record_win(name: String, path := PATH) -> void:
	name = display_name(name)
	if name not in NAMES: return
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("beaten", name, true)
	if config.save(path) != OK: push_warning("Could not save opponent progress.")

static func portrait(name: String, at: Vector2, dimensions: Vector2) -> Control:
	var view: Control
	name = display_name(name)
	var index := NAMES.find(name)
	if index >= 0 and index < 5:
		var animal := TextureRect.new()
		animal.texture = Art.loot("loot%d" % (index + 1))
		animal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		animal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view = animal
	else:
		var character := TextureRect.new()
		character.texture = load("res://art/role-%s.png" % ROLES.get(name, "you"))
		character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view = character
	view.position = at
	view.size = dimensions
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func show_progress(parent: Node) -> Control:
	var overlay := Control.new()
	overlay.name = "OpponentProgress"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	overlay.add_child(UI.panel(Vector2(24, 60), Vector2(672, 1160), UI.BG, 24))
	overlay.add_child(UI.label("Your opponents", Vector2(48, 86), Vector2(624, 60), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var count := 0
	for name in NAMES:
		if beaten(name): count += 1
	overlay.add_child(UI.label("%d of 9 beaten · Next: %s" % [count, peek_next()], Vector2(40, 155), Vector2(640, 46), 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for i in NAMES.size():
		var name: String = NAMES[i]
		var won := beaten(name)
		var at := Vector2(44 + (i % 3) * 214, 230 + int(i / 3) * 260)
		overlay.add_child(UI.panel(at, Vector2(204, 240), Color("#dbe9d9") if won else Color("#ece8df"), 16))
		overlay.add_child(portrait(name, at + Vector2(47, 16), Vector2(110, 120)))
		overlay.add_child(UI.label(full_name(name), at + Vector2(5, 140), Vector2(194, 48), 21, UI.BG, HORIZONTAL_ALIGNMENT_CENTER))
		overlay.add_child(UI.label("Beaten!" if won else "Still to beat", at + Vector2(5, 190), Vector2(194, 32), 22, Color("#276444") if won else Color("#62636e"), HORIZONTAL_ALIGNMENT_CENTER))
	var close := UI.button("Back", Vector2(160, 1094), Vector2(400, 84), UI.ACCENT, 30)
	close.pressed.connect(overlay.queue_free)
	overlay.add_child(close)
	parent.add_child(overlay)
	return overlay

static func display_name(name: String) -> String:
	return str(ANIMALS.get(name, name))

static func full_name(name: String) -> String:
	name = display_name(name)
	var species = ANIMALS.find_key(name)
	return "%s the %s" % [name, species] if species != null else name

static func play_button(name: String, at: Vector2, dimensions: Vector2, compact := false) -> Button:
	var button := UI.button("", at, dimensions, UI.ACCENT, 30)
	var size := 46.0 if compact else 70.0
	button.add_child(portrait(name, Vector2(12, (dimensions.y - size) / 2), Vector2(size, size)))
	var label := UI.label(("New game\nvs " if compact else "Play against ") + name, Vector2(size + 24, 0), Vector2(dimensions.x - size - 34, dimensions.y), 24 if compact else 30, UI.BG, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_font_override("font", UI.font(800))
	button.add_child(label)
	button.tooltip_text = "Play against " + full_name(name)
	button.accessibility_name = button.tooltip_text
	return button
