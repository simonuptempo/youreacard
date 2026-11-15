extends Control
## My Cards: every customizable card in one place. Tap one to put a face on it
## (a person, cat or dog), or to change it back to its default.

const SECTIONS := [
	["Your wild", ["you"]],
	["Bills", ["bill1", "bill2", "bill3", "bill4", "bill5"]],
	["Characters", ["pickpocket", "trickster", "boss", "mastermind", "bouncer", "illusionist", "trapper", "locksmith"]],
]
const CARD := Vector2(150, 210)


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
	add_child(UI.label("Tap a card to put a face on it. Cards with your face can use your voice, too.", Vector2(40, 96), Vector2(640, 50), 21, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 156)
	scroll.size = Vector2(720, 1124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := Control.new()
	scroll.add_child(page)
	var y := 0.0
	for sec in SECTIONS:
		page.add_child(UI.label(sec[0], Vector2(28, y), Vector2(660, 44), 28, UI.TEXT))
		y += 50.0
		var slots: Array = sec[1]
		for i in slots.size():
			var slot: String = slots[i]
			var pos := Vector2(28 + (i % 4) * (CARD.x + 18), y + int(i / 4) * (CARD.y + 66))
			var cv := CardView.new()
			cv.position = pos
			cv.size = CARD
			page.add_child(cv)
			cv.setup({"id": i, "kind": _kind_for(slot)}, Profile.slot_face(slot))
			cv.placeholder = slot == "you" and not Profile.is_custom("you")
			cv.tapped.connect(func(_v): _edit(slot))
			var custom := Profile.is_custom(slot)
			var label := "Not set yet" if slot == "you" and not custom else Profile.face_name(slot)
			page.add_child(UI.label(label, pos + Vector2(0, CARD.y + 2), Vector2(CARD.x, 28), 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			if custom and VoiceRecorder.speaks(slot):
				# Cards with your face can talk in your voice, too.
				var has := VoiceRecorder.has_voice(slot)
				var mic := UI.button("Your voice ✓" if has else "+ Your voice", pos + Vector2(0, CARD.y + 28), Vector2(CARD.x, 34), Color("#3cb97a") if has else Color("#c0392b"), 15)
				mic.pressed.connect(_record.bind(slot))
				page.add_child(mic)
			else:
				page.add_child(UI.label("Custom ✓" if custom else "Default", pos + Vector2(0, CARD.y + 28), Vector2(CARD.x, 26), 16, UI.ACCENT if custom else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		y += ceili(slots.size() / 4.0) * (CARD.y + 66) + 20.0
	page.custom_minimum_size = Vector2(720, y + 40)


func _kind_for(slot: String) -> String:
	if slot == "you":
		return "wild"
	if slot.begins_with("bill"):
		return "loot" + slot.substr(4)
	for k in CardDB.ACTIONS.keys():
		if CardDB.ACTIONS[k]["role"] == slot:
			return k
	return "wild"


func _record(slot: String) -> void:
	var r := VoiceRecorder.new()
	r.slot = slot
	r.closed.connect(func(): get_tree().reload_current_scene())
	add_child(r)


func _edit(slot: String) -> void:
	Profile.edit_slot = slot
	Profile.creator_return = "my_cards"
	Profile.go("avatar_creator")
