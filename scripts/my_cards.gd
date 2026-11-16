extends Control
## My Cards: every card with a face, exactly as it looks in the game ("Pip the Pickpocket").
## Tap one to become that card (your photo, turned into a cartoon), to put your pet or a
## friend on it, to create a character for it, or to record your own voice for it.

const SECTIONS := [
	["The crew", ["you", "pickpocket", "trickster", "boss", "mastermind", "bouncer", "illusionist", "trapper", "locksmith"]],
	["Bills", ["bill1", "bill2", "bill3", "bill4", "bill5"]],
]
const CARD := Vector2(200, 280)

var _sheet: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := Button.new()
	back.position = Vector2(20, 24)
	back.size = Vector2(68, 68)
	back.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	back.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	back.pressed.connect(func(): Profile.go("settings"))
	back.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(back)
	add_child(UI.label("My Cards", Vector2(0, 28), Vector2(720, 60), 42, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.label("Become one of the cards, or give any card a new face and voice. Tap a card to start.", Vector2(40, 96), Vector2(640, 60), 21, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 166)
	scroll.size = Vector2(720, 1114)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := Control.new()
	scroll.add_child(page)
	var y := 0.0
	for sec in SECTIONS:
		page.add_child(UI.label(sec[0], Vector2(30, y), Vector2(660, 44), 28, UI.TEXT))
		y += 50.0
		var slots: Array = sec[1]
		for i in slots.size():
			var slot: String = slots[i]
			var pos := Vector2(30 + (i % 3) * (CARD.x + 20), y + int(i / 3) * (CARD.y + 56))
			var cv := CardView.new()
			cv.position = pos
			cv.size = CARD
			page.add_child(cv)
			cv.setup({"id": i, "kind": _kind_for(slot)}, Profile.slot_face(slot))
			cv.tapped.connect(func(_v): _open(slot))
			page.add_child(UI.label(_status(slot), pos + Vector2(0, CARD.y + 4), Vector2(CARD.x, 40), 17,
				UI.ACCENT if Profile.is_custom(slot) or VoiceRecorder.has_voice(slot) else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		y += ceili(slots.size() / 3.0) * (CARD.y + 56) + 24.0
	page.custom_minimum_size = Vector2(720, y + 40)


func _status(slot: String) -> String:
	var parts: Array = []
	parts.append("Customized" if Profile.is_custom(slot) else "Original")
	if VoiceRecorder.has_voice(slot):
		parts.append("your voice")
	return " · ".join(parts)


func _kind_for(slot: String) -> String:
	if slot == "you":
		return "wild"
	if slot.begins_with("bill"):
		return "loot" + slot.substr(4)
	for k in CardDB.ACTIONS.keys():
		if CardDB.ACTIONS[k]["role"] == slot:
			return k
	return "wild"


## The original character's name: "Pip", "Nana Bea", or the bill's critter.
func _original_name(slot: String) -> String:
	if Profile.CRITTER_NAMES.has(slot):
		return "the " + str(Profile.CRITTER_NAMES[slot])
	return str(Profile.cast_for_role(slot)["name"])


# ------------------------------------------------------------------ one card

func _open(slot: String) -> void:
	_close()
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	_sheet.add_child(UI.panel(Vector2(24, 40), Vector2(672, 1200), UI.PANEL, 24))
	var cv := CardView.new()
	cv.position = Vector2(225, 64)
	cv.size = Vector2(270, 378)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(cv)
	cv.setup({"id": -1, "kind": _kind_for(slot)}, Profile.slot_face(slot))
	var y := 462.0
	_sheet.add_child(UI.label("Make this card yours", Vector2(24, y), Vector2(672, 40), 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	y += 48.0
	var options := [
		["Be this card: use my photo", _customize.bind(slot, "photo", "me"), UI.ACCENT],
		["Use my pet's photo", _customize.bind(slot, "photo", "pet"), Color("#3a4166")],
		["Use a friend's or family member's photo", _customize.bind(slot, "photo", "person"), Color("#3a4166")],
		["Create a character", _customize.bind(slot, "builder", "me"), Color("#3a4166")],
	]
	if VoiceRecorder.speaks(slot):
		var n := VoiceRecorder.recorded_count(slot)
		var label := "Record your voice" if n == 0 else "Your voice: %d of %d lines recorded" % [n, VoiceRecorder.LINE_COUNT]
		options.append([label, _record.bind(slot), Color("#c0392b")])
	if Profile.is_custom(slot):
		options.append(["Change back to %s" % _original_name(slot), _reset.bind(slot), Color("#2f3866")])
	for o in options:
		var b := UI.button(o[0], Vector2(60, y), Vector2(600, 70), o[2], 23)
		if o[2] == UI.ACCENT:
			b.add_theme_color_override("font_color", Color("#1b2038"))
		b.pressed.connect(o[1])
		_sheet.add_child(b)
		y += 80.0
	_sheet.add_child(UI.label("Photos become cartoons. They're sent securely to make the cartoon and aren't kept.", Vector2(60, y), Vector2(600, 56), 16, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var close := UI.button("Close", Vector2(60, 1152), Vector2(600, 68), Color("#3a4166"), 24)
	close.pressed.connect(_close)
	_sheet.add_child(close)


func _close() -> void:
	if is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


func _customize(slot: String, mode: String, kind: String) -> void:
	Profile.edit_slot = slot
	Profile.creator_return = "my_cards"
	Profile.creator_mode = mode
	Profile.photo_kind = kind
	Profile.go("avatar_creator")


func _reset(slot: String) -> void:
	Profile.clear_slot(slot)
	get_tree().reload_current_scene()


func _record(slot: String) -> void:
	_close()
	var r := VoiceRecorder.new()
	r.slot = slot
	r.closed.connect(func(): get_tree().reload_current_scene())
	add_child(r)
