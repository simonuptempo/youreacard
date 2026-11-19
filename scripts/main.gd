extends Control
## Main menu. Sends first-time players to the "make your card" onboarding.

const RULES := """[b]Goal:[/b] Complete 4 sets of gems before anyone else. 2 rubies are a complete set. All other sets need 3 of a kind.

[b]On your turn:[/b] Draw 2 cards, then play up to %d cards. You can...
 • Add a gem to your collection or a bill to your bank
 • Play an action or tool (if you have enough bills to afford it)
 • Move any card to one of the two slots in your vault (your opponent sees it face-down)

[b]Costs[/b]
 • 0 bills: Defense cards, Pay Up!
 • 1 bill: Trade, Shakedown
 • 2 bills: Heist, Lockpick
 • 5 bills: Grand Heist

[b]Other considerations:[/b]
 • End each hand with 7 or fewer cards
 • Taking a vault card back or moving a wild between sets does not count as one of your %d moves per turn
 • Windfall plays itself when you draw it: you "find" up to 10 bills in the discard pile, then draw another card.
 • Double Crossed plays itself when you draw it: someone steals up to 10 bills from your bank, then you draw another card.
 • A Heist takes one gem from a set they haven't finished. A Grand Heist takes all the gems in a finished set.
 • Add an extra gem to a finished set and your opponent pays you 2 bills (3 bills for a second extra).
 • Need cash? Pawn a gem from your hand or your collection into your bank: 1 bill each (Rubies and Diamonds: 2). Gems a finished set needs, and wilds, can't be pawned.
 • Payments make change when they can. Out of bills? They pay with gems from unfinished sets (at pawn value), then owe the rest from the next bills they get.
 • Shields, Mirrors, and Snares sit face-down and fire automatically when you are targeted.
 • A Mirror that bounces a Trade earns you a free counter-trade on your next turn.
 • A Mirror that bounces a Grand Heist takes their best unfinished set if they have no finished one.
 • A Lockpick breaks into their vault and picks a face-down card: a Defense gets defused (discarded); a decoy, you keep.
 • You're a Card is wild - it can be any gem"""

var _rules_overlay: Control
var _reference_button: Button


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
		if online.has("online") and Online.signed_in():
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
	gear.pressed.connect(func(): Profile.go("settings"))
	gear.add_child(Icon.make("gear", Vector2(14, 14), Vector2(40, 40)))
	add_child(gear)
	_reference_button = Button.new()
	_reference_button.position = Vector2(548, 24)
	_reference_button.size = Vector2(68, 68)
	_reference_button.tooltip_text = "Quick Reference"
	_reference_button.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	_reference_button.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	_reference_button.add_theme_stylebox_override("pressed", UI.box(Color("#262d55"), 34))
	_reference_button.add_theme_stylebox_override("focus", UI.box(Color(0,0,0,0), 34, UI.ACCENT, 2))
	_reference_button.add_child(Icon.make("reference", Vector2(14,14), Vector2(40,40)))
	_reference_button.pressed.connect(_show_rules)
	add_child(_reference_button)

	var hello := "Hi, %s!" % Profile.display_name if Profile.display_name != "" else ""
	add_child(UI.label(hello, Vector2(24, 34), Vector2(508, 50), 26, UI.MUTED))
	add_child(Art.logo(Vector2(140, 176), Vector2(440, 192)))
	add_child(UI.label("GEM HEIST", Vector2(40, 362), Vector2(640, 48), 38, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.label("Collect. Steal. Defend. Star in your own deck.", Vector2(40, 410), Vector2(640, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var card := CardView.new()
	card.position = Vector2(250, 452)
	card.size = Vector2(220, 308)
	add_child(card)
	card.setup(Profile.me_card(), Profile.me_face())
	card.placeholder = Profile.me_placeholder()
	card.editable = not card.placeholder
	if card.placeholder:
		# A gentle pulse invites the tap.
		card.pivot_offset = card.size / 2.0
		var pulse := card.create_tween().set_loops()
		pulse.tween_interval(1.4)
		pulse.tween_property(card, "scale", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	card.tapped.connect(func(_v):
		Profile.edit_slot = Profile.me_slot
		Profile.creator_return = "main"
		Profile.go("my_cards"))

	var online := UI.button("Play Online", Vector2(160, 790), Vector2(400, 88), UI.ACCENT, 36)
	online.pressed.connect(func(): Profile.go("online"))
	add_child(online)
	var saved: Dictionary = Profile.saved_game()
	var resumable := saved.has("state")
	var play := UI.button("Continue vs %s" % str(saved.get("bot_name", "")) if resumable else "Play a Character", Vector2(160, 896), Vector2(400, 76), Color("#3cb97a"), 28)
	play.pressed.connect(_continue_game if resumable else _play_character)
	add_child(play)
	var watch := UI.button("Learn to Play", Vector2(160, 990), Vector2(400, 74), Color("#4c8dff"), 28)
	watch.pressed.connect(_watch)
	add_child(watch)
	if resumable:
		var fresh := UI.button("Start a new game instead", Vector2(200, 1082), Vector2(320, 46), Color("#2f3866"), 18)
		fresh.pressed.connect(func():
			Profile.clear_saved_game()
			_play_character())
		add_child(fresh)
	else:
		add_child(UI.label("Beat all 8 characters, then take on your friends.", Vector2(60, 1084), Vector2(600, 40), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _continue_game() -> void:
	Profile.resume_game = true
	Profile.go("game")


## Takes on the next character you haven't beaten yet.
func _play_character() -> void:
	Online.pending_character = Profile.next_character()
	Profile.go("game")


func _watch() -> void:
	Profile.explainer_return = "main"
	Profile.go("explainer")


func _show_rules() -> void:
	_close_rules()
	_rules_overlay = Control.new()
	_rules_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_overlay.add_child(dim)
	var p := UI.panel(Vector2(30, 90), Vector2(660, 1060), UI.PANEL)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_rules_overlay.add_child(p)
	_rules_overlay.add_child(UI.label("Quick Reference", Vector2(30, 110), Vector2(660, 60), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RULES % [Profile.plays_per_turn, Profile.plays_per_turn]
	rt.position = Vector2(60, 180)
	rt.size = Vector2(600, 830)
	rt.add_theme_font_size_override("normal_font_size", 24)
	rt.add_theme_font_size_override("bold_font_size", 24)
	rt.add_theme_color_override("default_color", UI.TEXT)
	_rules_overlay.add_child(rt)
	var close := UI.button("Got it", Vector2(220, 1040), Vector2(280, 72))
	close.pressed.connect(_close_rules)
	_rules_overlay.add_child(close)
	add_child(_rules_overlay)
	close.grab_focus()


func _close_rules() -> void:
	if _rules_overlay:
		_rules_overlay.queue_free()
		_rules_overlay = null
		if is_instance_valid(_reference_button): _reference_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if _rules_overlay != null and event.is_action_pressed("ui_cancel"):
		_close_rules()
		get_viewport().set_input_as_handled()
