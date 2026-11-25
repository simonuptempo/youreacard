extends Control
## War and Piece menu (opened from the You're a Card home screen).

const RULES := """[b]Short on cards during a war?[/b]
Both players put down the same number, limited by the smaller deck. The last card is face-up. Still tied with someone out? Split the contested cards evenly when Piece begins.

[b]Tied set counts?[/b]
The first-heist advantage alternates each Piece round. Order is fixed after automatic banking.

[b]Where do shields come from?[/b]
Two shields slip into hands secretly during War. Keep an unused shield until it blocks a heist; then it leaves the game permanently. A blocked heist still uses that turn.

[b]What happens to leftover cards?[/b]
Your remaining deck and winnings become your Piece hand. After Piece, unbanked cards return to your deck. Decks shuffle before every War.

[b]One set left? Final Showdown![/b]
After Piece, draw from a separate shuffled deck. Add five cards each: higher total wins the last set. Tied? Add five more each to the running totals. J = 11, Q = 12, K = 13, A = 14. Shields do not apply.

[b]When does the game end?[/b]
Only after all 13 sets are banked—not when someone reaches seven. If needed, loose cards are redealt to keep play moving."""

var _rules: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var emblem := CardGameEmblem.new()
	emblem.kind = "war_and_piece"
	emblem.position = Vector2(84, 98)
	emblem.size = Vector2(132, 120)
	add_child(emblem)
	var t := UI.label("War and Piece", Vector2(220, 110), Vector2(470, 110), 56, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font(900))
	add_child(t)
	var sub := UI.label("a You're a Card game", Vector2(20, 210), Vector2(680, 44), 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_font_override("font", UI.font(700))
	add_child(sub)
	# A fan of the four characters
	var ranks := [11, 12, 13, 14]
	var suits := ["S", "H", "C", "D"]
	for i in 4:
		var v := WarCardView.new()
		v.size = Vector2(200, 280)
		v.pivot_offset = Vector2(100, 560)
		v.position = Vector2(260, 330)
		v.rotation = deg_to_rad(-21 + i * 14)
		v.setup({"id": 100 + i, "rank": ranks[i], "suit": suits[i]})
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
	var how := UI.label("Win cards in War. Complete ranks in Piece.\nComplete all 13 sets. Collect the most to win!", Vector2(40, 700), Vector2(640, 100), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	how.add_theme_font_override("font", UI.font(600))
	add_child(how)
	var saved := WarSave.load_game()
	var y := 830.0
	var opponents = preload("res://games/war_and_piece/scripts/war_opponents.gd")
	var height := 100.0
	var opponent_name: String = saved.nm(1) if saved != null else opponents.peek_next()
	var play: Button = opponents.play_button(opponent_name, Vector2(110, y), Vector2(500, height))
	play.name = "Continue" if saved != null else "NewGame"
	if saved != null:
		for child in play.get_children():
			if child is Label:
				child.text = "Continue against " + opponent_name
				child.add_theme_font_size_override("font_size", 27)
		play.tooltip_text = "Continue against " + opponent_name
		play.accessibility_name = play.tooltip_text
	for state in ["normal", "hover", "pressed", "focus"]:
		play.add_theme_stylebox_override(state, UI.box(Color.WHITE if state == "normal" else Color("#eeeef2"), 16))
	play.pressed.connect(continue_game if saved != null else new_game)
	add_child(play)
	y += height + 16
	var online := UI.button("Play Online", Vector2(110, y), Vector2(500, height), Color("#4c8dff"), 30)
	online.name = "PlayOnline"
	online.add_theme_font_override("font", UI.font(800))
	online.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/online.tscn"))
	add_child(online)
	y += height + 16
	var cards := UI.button("My Cards", Vector2(110, y), Vector2(242, 82), Color("#7a4fd6"), 28)
	cards.name = "YourCards"
	cards.add_theme_font_override("font", UI.font(800))
	cards.pressed.connect(func():
		Profile.edit_slot = "pickpocket"
		Profile.voice_game = "war_and_piece"
		Profile.creator_return = "home"
		Profile.go("my_cards"))
	add_child(cards)
	var help := UI.button("How to Play", Vector2(368, y), Vector2(242, 82), Color("#2f3866"), 28)
	help.name = "HowToPlay"
	help.add_theme_font_override("font", UI.font(800))
	help.pressed.connect(show_rules)
	add_child(help)
	# Back to the You're a Card home screen.
	var home := Button.new()
	home.position = Vector2(20, 24)
	home.size = Vector2(68, 68)
	home.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	home.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	home.tooltip_text = "Home"
	home.pressed.connect(func(): Profile.go("home"))
	home.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(home)


func continue_game() -> void:
	WarSave.resume_next = true
	get_tree().change_scene_to_file("res://games/war_and_piece/scenes/game.tscn")


## A new game replaces the saved one, so check first.
func new_game() -> void:
	if not WarSave.has_game():
		_start_new()
		return
	var o := Control.new()
	o.name = "ConfirmNew"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	o.add_child(UI.panel(Vector2(60, 420), Vector2(600, 400)))
	var h := UI.label("Start a new game?", Vector2(80, 450), Vector2(560, 60), 36, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_theme_font_override("font", UI.font(900))
	o.add_child(h)
	var b := UI.label("Your game in progress will be lost.", Vector2(80, 520), Vector2(560, 80), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	b.add_theme_font_override("font", UI.font(700))
	o.add_child(b)
	var yes := UI.button("Start over", Vector2(100, 620), Vector2(250, 90), Color("#c0392b"), 28)
	yes.add_theme_font_override("font", UI.font(800))
	yes.pressed.connect(_start_new)
	o.add_child(yes)
	var no := UI.button("Keep playing", Vector2(370, 620), Vector2(250, 90), UI.ACCENT, 28)
	no.add_theme_font_override("font", UI.font(800))
	no.pressed.connect(func():
		o.queue_free()
		continue_game())
	o.add_child(no)
	add_child(o)


func _start_new() -> void:
	WarSave.clear()
	WarSave.resume_next = false
	get_tree().change_scene_to_file("res://games/war_and_piece/scenes/game.tscn")


func show_rules() -> void:
	_rules = rules_overlay(self)


static func rules_overlay(parent: Control) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	o.add_child(UI.panel(Vector2(24, 60), Vector2(672, 1160)))
	var h := UI.label("How to Play", Vector2(48, 76), Vector2(624, 60), 38, UI.ACCENT)
	h.add_theme_font_override("font", UI.font(900))
	o.add_child(h)
	var subtitle := UI.label("Win cards. Build sets. Collect the most.", Vector2(48, 140), Vector2(624, 44), 25, UI.TEXT)
	o.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 200)
	scroll.size = Vector2(624, 890)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 600
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var sections := [
		["play", "1 · DEAL", "Tap [b]Deal![/b] Higher card takes the pair.
[b]Ace is highest.[/b]", "#ffce3a"],
		["replay", "TIE? GO TO WAR", "Each player adds [b]3 face-down + 1 face-up[/b]. Higher card takes the whole pile. Tie again? Another war!", "#ffb399"],
		["check", "2 · PIECE TOGETHER SETS", "When either deck runs out, Piece begins.
[b]Four suits of one rank = one safe set.[/b]
Complete sets bank automatically.", "#7cdbca"],
		["wand", "TAKE A HEIST", "Tap [b]any stack[/b], then choose a missing suit to steal.
[b]Trailing → Leading → Trailing[/b]", "#ffce3a"],
		["reference", "SHIELDS BLOCK AUTOMATICALLY", "Have a shield? It stops one heist, then disappears. The play log tells you what happened.", "#7cdbca"],
		["replay", "KEEP GOING TO WIN", "Alternate [b]War → Piece → War[/b] until all [b]13 sets[/b] are banked. Most sets wins!", "#ffce3a"]
	]
	for section in sections:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.box(Color("#303956"), 16))
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 18)
		panel.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		margin.add_child(column)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 14)
		var icon := Icon.make(section[0], Vector2.ZERO, Vector2(30, 30), Color(section[3]))
		icon.custom_minimum_size = Vector2(30, 30)
		heading.add_child(icon)
		var title := UI.label(section[1], Vector2.ZERO, Vector2.ZERO, 25, Color(section[3]))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_override("font", UI.font(900))
		heading.add_child(title)
		column.add_child(heading)
		column.add_child(_rules_text(section[2]))
		list.add_child(panel)
	var details := _rules_text(RULES)
	details.visible = false
	var more := UI.button("More rules +", Vector2.ZERO, Vector2(600, 68), Color("#394568"), 26)
	more.custom_minimum_size = Vector2(600, 68)
	more.pressed.connect(func():
		details.visible = not details.visible
		more.text = "Fewer rules −" if details.visible else "More rules +")
	list.add_child(more)
	list.add_child(details)
	var close := UI.button("Got it", Vector2(210, 1112), Vector2(300, 84), UI.ACCENT, 30)
	close.add_theme_font_override("font", UI.font(800))
	close.pressed.connect(o.queue_free)
	o.add_child(close)
	parent.add_child(o)
	return o


static func _rules_text(copy: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = copy
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 560
	text.add_theme_font_override("normal_font", UI.font(500))
	text.add_theme_font_override("bold_font", UI.font(800))
	text.add_theme_font_size_override("normal_font_size", 25)
	text.add_theme_font_size_override("bold_font_size", 25)
	text.add_theme_constant_override("line_separation", 5)
	text.add_theme_color_override("default_color", UI.TEXT)
	return text
