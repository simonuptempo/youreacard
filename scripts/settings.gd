extends Control
## Settings: your cards (My Cards), name, playtest options, replay setup.

var _name_edit: LineEdit
var _plays_btn: Button
var _status: Label
var _sound_btn: Button
var _voices_btn: Button


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
	back.pressed.connect(func(): Profile.go("main"))
	back.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(back)
	add_child(UI.label("Settings", Vector2(0, 28), Vector2(720, 60), 42, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	# Your card
	add_child(UI.panel(Vector2(20, 116), Vector2(680, 420), UI.PANEL, 20))
	var card := CardView.new()
	card.position = Vector2(44, 140)
	card.size = Vector2(264, 370)
	add_child(card)
	card.setup(Profile.me_card(), Profile.me_face())
	card.placeholder = Profile.me_placeholder()
	add_child(UI.label("Your cards", Vector2(332, 140), Vector2(350, 44), 30, UI.TEXT))
	add_child(UI.label("Name", Vector2(332, 196), Vector2(350, 30), 20, UI.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(332, 228)
	_name_edit.size = Vector2(344, 64)
	_name_edit.max_length = 16
	_name_edit.text = Profile.display_name
	_name_edit.placeholder_text = "Nickname"
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("#f4f1ea"), 12))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("#ffffff"), 12, UI.ACCENT, 3))
	_name_edit.add_theme_color_override("font_color", Color("#1b2038"))
	_name_edit.text_changed.connect(_on_name_changed)
	add_child(_name_edit)
	var edit := UI.button("My Cards", Vector2(332, 316), Vector2(344, 72), UI.ACCENT, 28)
	edit.pressed.connect(func():
		Profile.edit_slot = Profile.me_slot
		Profile.creator_return = "settings"
		Profile.go("my_cards"))
	add_child(edit)
	add_child(UI.label("%d of 14 cards customized: 9 characters and 5 bills. Pick the card that's you." % Profile.custom_count(), Vector2(332, 396), Vector2(344, 70), 18, UI.MUTED))
	add_child(UI.label("Saved only on this device.", Vector2(332, 474), Vector2(344, 30), 17, UI.MUTED))

	# Game
	add_child(UI.label("Game", Vector2(30, 560), Vector2(660, 40), 26, UI.MUTED))
	var watch := UI.button("Learn to play · step by step", Vector2(20, 606), Vector2(680, 76), Color("#4c8dff"), 26)
	watch.pressed.connect(func():
		Profile.explainer_return = "settings"
		Profile.go("explainer"))
	add_child(watch)
	_sound_btn = UI.button("", Vector2(20, 698), Vector2(330, 76), Color("#3a4166"), 22)
	_sound_btn.pressed.connect(_toggle_sound)
	add_child(_sound_btn)
	_voices_btn = UI.button("", Vector2(370, 698), Vector2(330, 76), Color("#3a4166"), 22)
	_voices_btn.pressed.connect(_cycle_voices)
	add_child(_voices_btn)
	_update_voices()
	_update_sound()

	# Testing
	add_child(UI.label("For testing", Vector2(30, 800), Vector2(660, 40), 26, UI.MUTED))
	_plays_btn = UI.button("", Vector2(370, 846), Vector2(330, 76), Color("#3a4166"), 19)
	_plays_btn.pressed.connect(_toggle_plays)
	add_child(_plays_btn)
	_update_plays()
	var replay := UI.button("Replay first-time setup", Vector2(20, 846), Vector2(330, 76), Color("#3a4166"), 20)
	replay.pressed.connect(func():
		Profile.onboarded = false
		Profile.onboarding_step = 0
		Profile.save_profile()
		Profile.go("onboarding"))
	add_child(replay)
	_status = UI.label("", Vector2(20, 932), Vector2(680, 40), 20, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	_build_account()


func _on_name_changed(t: String) -> void:
	Profile.display_name = t.strip_edges()
	Profile.save_profile()
	_status.text = "Name saved."


func _toggle_plays() -> void:
	Profile.plays_per_turn = 3 if Profile.plays_per_turn == 2 else 2
	Profile.save_profile()
	_update_plays()


func _update_plays() -> void:
	_plays_btn.text = "Playtest: %d plays/turn" % Profile.plays_per_turn


func _toggle_sound() -> void:
	Profile.sound_on = not Profile.sound_on
	Profile.save_profile()
	Sfx.enabled = Profile.sound_on
	_update_sound()
	Sfx.play("gem")


func _update_sound() -> void:
	_sound_btn.text = "Sound effects: On" if Profile.sound_on else "Sound effects: Off"


## Character voices: Often -> Sometimes -> Off.
func _cycle_voices() -> void:
	var order := ["sometimes", "often", "off"]
	Profile.voices = order[(order.find(Profile.voices) + 1) % order.size()]
	Profile.save_profile()
	_update_voices()


func _update_voices() -> void:
	_voices_btn.text = "Voices: %s" % Profile.voices.capitalize()



# ------------------------------------------------------------------ account

var _account: Control
var _confirm: Control


func _build_account() -> void:
	if is_instance_valid(_account):
		_account.queue_free()
	_account = Control.new()
	_account.set_anchors_preset(Control.PRESET_FULL_RECT)
	_account.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_account)
	_account.add_child(UI.label("Account", Vector2(30, 972), Vector2(660, 40), 26, UI.MUTED))
	if not Online.signed_in():
		_account.add_child(UI.label("Not signed in. Sign in to play friends online.", Vector2(30, 1012), Vector2(660, 34), 20, UI.MUTED))
		var sign := UI.button("Sign in to play online", Vector2(20, 1052), Vector2(680, 76), UI.ACCENT, 26)
		sign.add_theme_color_override("font_color", Color("#1b2038"))
		sign.pressed.connect(func(): Profile.go("online"))
		_account.add_child(sign)
		return
	var who := "a guest" if Online.is_guest() else str(Online.session.get("email", ""))
	if who == "":
		who = Online.name_or("your account")
	_account.add_child(UI.label("Signed in as %s" % who, Vector2(30, 1012), Vector2(660, 34), 20, UI.TEXT))
	var out := UI.button("Sign out", Vector2(20, 1052), Vector2(330, 76), Color("#3a4166"), 24)
	out.pressed.connect(_sign_out)
	_account.add_child(out)
	var del := UI.button("Delete my account", Vector2(370, 1052), Vector2(330, 76), Color("#9b3a32"), 24)
	del.pressed.connect(_ask_delete)
	_account.add_child(del)


func _sign_out() -> void:
	await Online.sign_out()
	_status.text = "Signed out."
	_build_account()


func _ask_delete() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	_confirm.add_child(UI.panel(Vector2(50, 360), Vector2(620, 500), UI.PANEL, 22))
	_confirm.add_child(UI.label("Delete your account?", Vector2(70, 396), Vector2(580, 50), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_confirm.add_child(UI.label("This permanently deletes your online account, your name, and your place in any online games. It can't be undone.\n\nYour cards and settings on this phone stay.", Vector2(80, 460), Vector2(560, 200), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var yes := UI.button("Delete my account", Vector2(100, 680), Vector2(520, 76), Color("#9b3a32"), 26)
	yes.pressed.connect(_do_delete)
	_confirm.add_child(yes)
	var no := UI.button("Keep my account", Vector2(100, 768), Vector2(520, 70), Color("#3a4166"), 24)
	no.pressed.connect(_close_confirm)
	_confirm.add_child(no)
	add_child(_confirm)


func _close_confirm() -> void:
	if is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null


func _do_delete() -> void:
	_close_confirm()
	_status.text = "Deleting your account…"
	var err := await Online.delete_account()
	_status.text = err if err != "" else "Your account has been deleted."
	_build_account()
