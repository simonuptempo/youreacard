extends Control
## You're a Card home: your card, and the games you can play with it.

const GAMES := [
	{"id": "gem_heist", "name": "Gem Heist", "tag": "Collect gems, steal theirs, guard your vault.", "ready": true},
	# War and Piece: playable; lives in games/war_and_piece/ and opens its own menu scene.
	{"id": "war_and_piece", "name": "War and Piece", "tag": "Win cards in War, then lock them into sets.", "ready": true,
		"scene": "res://games/war_and_piece/scenes/main.tscn"},
	# See Saw: playable; lives in games/see_saw/ and opens its own menu scene.
	{"id": "see_saw", "name": "See Saw", "tag": "One quick look. What did you see?", "ready": true,
		"scene": "res://games/see_saw/scenes/main.tscn"},
]


func _ready() -> void:
	if not Profile.onboarded:
		Profile.onboarding_step = 0
		Profile.go.call_deferred("onboarding")
		return
	# Opening the app: go straight back to the game you were in, even if the app was closed.
	if not Profile.launch_checked:
		Profile.launch_checked = true
		var online: Dictionary = Profile.saved_game(Profile.ONLINE_SAVE)
		var local: Dictionary = Profile.saved_game()
		if online.has("online") and Online.signed_in() and AgeGate.ok():
			Online.game_id = str(online["online"])
			Profile.go.call_deferred("game")
			return
		if local.has("state") and bool(local.get("open", true)):
			Profile.resume_game = true
			Profile.go.call_deferred("game")
			return
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var gear := Button.new()
	gear.position = Vector2(632, 24)
	gear.size = Vector2(68, 68)
	gear.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	gear.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	gear.add_theme_stylebox_override("pressed", UI.box(Color("#262d55"), 34))
	gear.tooltip_text = "Settings"
	gear.pressed.connect(func():
		Profile.settings_return = "home"
		Profile.go("settings"))
	gear.add_child(Icon.make("gear", Vector2(14, 14), Vector2(40, 40)))
	add_child(gear)

	var hello := "Hi, %s!" % Profile.display_name if Profile.display_name != "" else ""
	add_child(UI.label(hello, Vector2(24, 34), Vector2(560, 50), 26, UI.MUTED))
	add_child(Art.logo(Vector2(160, 96), Vector2(400, 175)))

	# Your card, which stars in every game
	var card := CardView.new()
	card.position = Vector2(268, 284)
	card.size = Vector2(184, 258)
	add_child(card)
	card.setup(Profile.me_card(), Profile.me_face())
	card.placeholder = Profile.me_placeholder()
	card.editable = not card.placeholder
	if card.placeholder:
		card.pivot_offset = card.size / 2.0
		var pulse := card.create_tween().set_loops()
		pulse.tween_interval(1.4)
		pulse.tween_property(card, "scale", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	card.tapped.connect(func(_v):
		Profile.edit_slot = Profile.me_slot
		Profile.creator_return = "home"
		Profile.go("my_cards"))
	var under := "Tap to put yourself on a card" if card.placeholder else "You star in every game"
	var ul := UI.label(under, Vector2(40, 552), Vector2(640, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ul.add_theme_font_override("font", UI.font(700))
	add_child(ul)

	var pick := UI.label("Pick a game", Vector2(40, 600), Vector2(640, 44), 30, UI.TEXT)
	pick.add_theme_font_override("font", UI.font(900))
	add_child(pick)
	for i in GAMES.size():
		_tile(GAMES[i], Vector2(28, 654 + i * 196))


func _tile(game: Dictionary, pos: Vector2) -> void:
	var ready: bool = game["ready"]
	var b := Button.new()
	b.position = pos
	b.size = Vector2(664, 178)
	var col := Color("#2b3358") if ready else Color("#232945")
	b.add_theme_stylebox_override("normal", UI.box(col, 22, UI.ACCENT if ready else Color(0, 0, 0, 0), 3 if ready else 0))
	b.add_theme_stylebox_override("hover", UI.box(col.lightened(0.08), 22, UI.ACCENT if ready else Color(0, 0, 0, 0), 3 if ready else 0))
	b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.1), 22, UI.ACCENT if ready else Color(0, 0, 0, 0), 3 if ready else 0))
	b.add_theme_stylebox_override("disabled", UI.box(col, 22))
	b.disabled = not ready
	b.accessibility_name = game["name"]
	if ready:
		# A game with its own "scene" (e.g. See Saw) opens that; Gem Heist opens its menu.
		b.pressed.connect(func():
			if game.has("scene"):
				get_tree().change_scene_to_file(game["scene"])
			else:
				Profile.go("main"))
	add_child(b)
	var art := GameArt.new()
	art.kind = game["id"]
	art.position = Vector2(18, 14)
	art.size = Vector2(186, 150)
	art.modulate.a = 1.0 if ready else 0.55
	b.add_child(art)
	var name := UI.label(game["name"], Vector2(222, 22), Vector2(430, 52), 36, UI.ACCENT if ready else UI.TEXT)
	name.add_theme_font_override("font", UI.font(900))
	b.add_child(name)
	var tag := UI.label(game["tag"], Vector2(222, 74), Vector2(420, 62), 21, UI.MUTED)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tag.add_theme_font_override("font", UI.font(600))
	b.add_child(tag)
	var status := "Play" if ready else "Coming soon"
	if ready and game["id"] == "gem_heist" and Profile.saved_game().has("state"):
		status = "Continue your game"
	if ready and game["id"] == "war_and_piece" and WarSave.has_game():  # War and Piece: a game in progress
		status = "Continue your game"
	var st := UI.label(status + ("  ›" if ready else ""), Vector2(222, 132), Vector2(420, 34), 22, Color("#3cb97a") if ready else Color("#8890b0"))
	st.add_theme_font_override("font", UI.font(800))
	b.add_child(st)


## Small artwork for each game's tile.
class GameArt extends Control:
	var kind := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "gem_heist":
			var t := Art.tex("gem-heist-logo")
			if t:
				var r := TextureRect.new()
				r.texture = t
				r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				r.size = size
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(r)

	func _draw() -> void:
		# War and Piece and See Saw use their own emblems (the same marks as their menus and card backs).
		if kind in ["war_and_piece", "see_saw"]:
			CardGameEmblem.draw_mark(self, Rect2(Vector2.ZERO, size), kind)
