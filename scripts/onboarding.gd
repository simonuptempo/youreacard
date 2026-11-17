extends Control
## First-time setup: welcome → name → your You're a Card! face (optional) → faces on bills (optional) → done.

const ROLE_CARDS := {
	"pickpocket": "swipe", "trickster": "swap", "boss": "shakedown", "mastermind": "grand",
	"bouncer": "shield", "illusionist": "mirror", "trapper": "snare", "locksmith": "lockpick",
}

var _root: Control
var _name_edit: LineEdit
var _cycle_token := 0


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	match Profile.onboarding_step:
		1: _step_name()
		2: _step_bills()
		3: _step_reveal()
		_: _step_welcome()


func _reset() -> void:
	_cycle_token += 1
	for c in _root.get_children():
		c.queue_free()


func _dots(active: int) -> void:
	for i in 3:
		var on := i == active
		var d := UI.panel(Vector2(312 + i * 36, 1220), Vector2(24 if on else 14, 14), UI.ACCENT if on else Color("#3a4166"), 7)
		_root.add_child(d)


# ------------------------------------------------------------------ step 0: welcome

func _step_welcome() -> void:
	_reset()
	_root.add_child(UI.label("Welcome to", Vector2(0, 90), Vector2(720, 50), 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(Art.logo(Vector2(150, 128), Vector2(420, 184)))

	var card := CardView.new()
	card.size = Vector2(270, 378)
	card.position = Vector2(225, 326)
	card.pivot_offset = card.size / 2
	_root.add_child(card)
	card.setup(Profile.me_card(), Profile.me_face())
	card.placeholder = Profile.me_placeholder()
	card.editable = not card.placeholder
	card.tapped.connect(func(_v): _step_name())
	var pulse := create_tween().set_loops()
	pulse.tween_property(card, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(card, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	_root.add_child(UI.label("In this game you don't just play cards.\nYou ARE one.", Vector2(40, 720), Vector2(640, 100), 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.label("Make a cartoon you (or your pet!) and star on your own wild card.", Vector2(60, 824), Vector2(600, 70), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var go := UI.button("Make my card", Vector2(140, 920), Vector2(440, 92), UI.ACCENT, 36)
	go.pressed.connect(_step_name)
	_root.add_child(go)
	var skip := UI.button("Skip and start playing", Vector2(140, 1034), Vector2(440, 64), Color("#3a4166"), 21)
	skip.pressed.connect(_skip)
	_root.add_child(skip)
	_dots(0)


func _flip_in(card: CardView) -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(card):
		return
	var tw := create_tween()
	tw.tween_property(card, "scale:x", 0.0, 0.18)
	await tw.finished
	if not is_instance_valid(card):
		return
	card.setup({"id": 0, "kind": "wild"}, _random_face())
	var tw2 := create_tween()
	tw2.tween_property(card, "scale:x", 1.0, 0.18)
	# Cycle through random faces: "who will you be?"
	var token := _cycle_token
	while is_inside_tree() and token == _cycle_token and is_instance_valid(card):
		await get_tree().create_timer(0.9).timeout
		if token != _cycle_token or not is_instance_valid(card):
			return
		card.setup({"id": 0, "kind": "wild"}, _random_face())


func _random_face() -> Dictionary:
	var r := randf()
	if r < 0.15:
		return AvatarView.random_pet(1)
	if r < 0.3:
		return AvatarView.random_pet(2)
	return AvatarView.normalized(AvatarView.random_avatar())


func _skip() -> void:
	# Skip everything: default cast and critters, straight to the menu.
	Profile.onboarded = true
	Profile.onboarding_step = 0
	Profile.save_profile()
	Profile.go("main")


# ------------------------------------------------------------------ step 1: name

func _step_name() -> void:
	_reset()
	Profile.onboarding_step = 1
	_root.add_child(UI.label("Step 1 of 2", Vector2(0, 120), Vector2(720, 40), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.label("What should we call you?", Vector2(0, 170), Vector2(720, 70), 40, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(110, 290)
	_name_edit.size = Vector2(500, 90)
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "First name or nickname"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text = Profile.display_name
	_name_edit.add_theme_font_size_override("font_size", 36)
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("#f4f1ea"), 18))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("#ffffff"), 18, UI.ACCENT, 4))
	_name_edit.add_theme_color_override("font_color", Color("#1b2038"))
	_name_edit.add_theme_color_override("font_placeholder_color", Color("#8a8fa8"))
	_name_edit.text_submitted.connect(func(_t): _name_next())
	_root.add_child(_name_edit)
	_root.add_child(UI.label("Friends see this when you play. A nickname is great; no last names needed.", Vector2(90, 396), Vector2(540, 70), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var preview := CardView.new()
	preview.size = Vector2(220, 308)
	preview.position = Vector2(250, 500)
	_root.add_child(preview)
	preview.setup(Profile.me_card(), Profile.me_face())
	preview.placeholder = Profile.me_placeholder()
	preview.editable = not preview.placeholder
	_root.add_child(UI.label("Next, pick the card you'll be and put your face on it.", Vector2(80, 820), Vector2(560, 60), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var next := UI.button("Next: make my face", Vector2(140, 920), Vector2(440, 92), UI.ACCENT, 32)
	next.pressed.connect(_name_next)
	_root.add_child(next)
	var back := UI.button("Back", Vector2(140, 1034), Vector2(440, 64), Color("#3a4166"), 22)
	back.pressed.connect(_step_welcome)
	_root.add_child(back)
	_dots(1)
	_name_edit.grab_focus.call_deferred()


func _name_next() -> void:
	var n := _name_edit.text.strip_edges()
	Profile.display_name = n if n != "" else "Player"
	Profile.save_profile()
	_edit(Profile.me_slot)


func _edit(slot: String) -> void:
	Profile.edit_slot = slot
	Profile.creator_return = "onboarding"
	Profile.go("my_cards")


# ------------------------------------------------------------------ step 2: faces on bills

func _step_bills() -> void:
	_reset()
	Profile.onboarding_step = 2
	_root.add_child(UI.label("Step 2 of 2 · optional", Vector2(0, 40), Vector2(720, 40), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.label("Put more faces on your bills?", Vector2(20, 84), Vector2(680, 60), 38, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.label("Family, friends, the cat, the dog. Tap any bill to add a face, or skip: the critters are happy to fill in.", Vector2(50, 146), Vector2(620, 80), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var spots := [Vector2(40, 250), Vector2(260, 250), Vector2(480, 250), Vector2(150, 590), Vector2(370, 590)]
	for i in 5:
		var slot := "bill%d" % (i + 1)
		var cv := CardView.new()
		cv.size = Vector2(200, 280)
		cv.position = spots[i]
		_root.add_child(cv)
		cv.setup({"id": i, "kind": "loot%d" % (i + 1)}, Profile.slot_face(slot))
		cv.editable = true
		cv.tapped.connect(func(_v): _edit(slot))
		var tag := "Custom ✓" if Profile.is_custom(slot) else "Tap to add a face"
		_root.add_child(UI.label(tag, spots[i] + Vector2(0, 284), Vector2(200, 30), 18, UI.ACCENT if Profile.is_custom(slot) else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.label("You can change any card later in Settings → My Cards, including the characters.", Vector2(60, 920), Vector2(600, 70), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var label := "Done" if Profile.custom_count() > 1 else "Skip for now"
	var done := UI.button(label, Vector2(140, 1010), Vector2(440, 92), UI.ACCENT, 32)
	done.pressed.connect(_step_reveal)
	_root.add_child(done)
	_dots(2)


# ------------------------------------------------------------------ step 3: ready

func _step_reveal() -> void:
	_reset()
	Profile.onboarded = true
	Profile.onboarding_step = 0
	Profile.save_profile()
	var who := Profile.display_name if Profile.display_name != "" else "card"
	_root.add_child(UI.label("Your cards are ready, %s!" % who, Vector2(0, 40), Vector2(720, 70), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	var big := CardView.new()
	big.size = Vector2(250, 350)
	big.position = Vector2(235, 130)
	big.pivot_offset = big.size / 2
	big.scale = Vector2.ZERO
	_root.add_child(big)
	big.setup(Profile.me_card(), Profile.me_face())
	big.placeholder = Profile.me_placeholder()
	big.editable = not big.placeholder
	big.tapped.connect(func(_v): _edit(Profile.me_slot))
	var tw := create_tween()
	tw.tween_property(big, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in 5:
		var cv := CardView.new()
		cv.size = Vector2(124, 174)
		var target := Vector2(18 + i * 138, 540)
		cv.position = Vector2(298, 1300)
		cv.pivot_offset = cv.size / 2
		cv.rotation = deg_to_rad(-12 + i * 5)
		_root.add_child(cv)
		cv.setup({"id": i + 1, "kind": "loot%d" % (i + 1)}, Profile.slot_face("bill%d" % (i + 1)))
		var t2 := create_tween()
		t2.tween_interval(0.35 + i * 0.09)
		t2.tween_property(cv, "position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(cv, "rotation", 0.0, 0.4)
	_root.add_child(UI.label("Your card and your bills. Any card you haven't customized is played by the default cast.", Vector2(50, 740), Vector2(620, 90), 21, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var watch := UI.button("Learn to play · step by step", Vector2(40, 900), Vector2(640, 80), Color("#4c8dff"), 28)
	watch.pressed.connect(func():
		Profile.explainer_return = "main"
		Profile.go("explainer"))
	_root.add_child(watch)
	var play := UI.button("Let's play!", Vector2(40, 996), Vector2(640, 92), UI.ACCENT, 34)
	play.pressed.connect(func(): Profile.go("main"))
	_root.add_child(play)
