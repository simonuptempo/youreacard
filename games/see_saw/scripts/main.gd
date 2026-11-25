extends Control
## See Saw menu (opened from the You're a Card home screen).

const RULES := """[b]Look. Remember. Answer.[/b]

 • [b]Level 1[/b] shows 1 card for 3 seconds. [b]Level 2[/b] shows 2 cards for 6 seconds. [b]Level 3[/b]: 3 cards, 9 seconds. And so on.
 • Then the cards flip face down and you answer a few quick questions: What was the 2nd card? What suit was it? Was there a red card? Which card was NOT shown? Who was on the 3rd card?
 • Cards are numbered in reading order: left to right, top row first.

[b]POINTS[/b]
 • Each correct answer: 10 × your level. Clear a level: +50.
 • Every 5 consecutive correct answers: +100. A miss resets the streak, but never removes earned points.
 • After clearing Levels 4, 6, 8…: a bonus question about the successful attempt two levels earlier. Correct: +50. No counterweight lost for a miss. Bonus answers count toward your streak.

[b]STAY IN THE AIR[/b]
 • Three counterweights keep your seesaw seat up. Each regular miss removes one and lowers you.
 • Answer every question correctly to advance; a miss gives you new cards at the same level.
 • At zero counterweights, you land. Spend 250 points to restore one and keep playing, or finish your run.
 • You can also restore a counterweight between levels, up to three. Spending subtracts from your score.
 • [b]Lou's counterweight:[/b] clear Level 4, and every level after it, to earn an extra counterweight (an extra life).

[b]You're a Card[/b]
Every card from 2 to Ace has a character on it, and Lou is on the counterweight. Put yourself, your friends or your pets on any of them. Tap a preview card or My Cards, then take a photo or upload one and cartoonify it. Your faces and names appear in the game and its memory questions. These cards are shared with your other games."""


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var home := UI.button("‹", Vector2(16, 36), Vector2(64, 64), Color("#2f3866"), 40)
	home.tooltip_text = "Home"
	home.pressed.connect(func(): Profile.go("home"))
	add_child(home)
	var emblem := CardGameEmblem.new()
	emblem.kind = "see_saw"
	emblem.position = Vector2(84, 98)
	emblem.size = Vector2(132, 120)
	add_child(emblem)
	var t := UI.label("See Saw", Vector2(220, 110), Vector2(450, 120), 76, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font(900))
	add_child(t)
	var sub := UI.label("a You're a Card game", Vector2(20, 224), Vector2(680, 44), 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_font_override("font", UI.font(700))
	add_child(sub)
	# A fan of the four characters
	var ranks := [11, 12, 13, 14]
	var suits := ["S", "H", "C", "D"]
	for i in 4:
		var v := SSCardView.new()
		v.size = Vector2(200, 280)
		v.pivot_offset = Vector2(100, 560)
		v.position = Vector2(260, 330)
		v.rotation = deg_to_rad(-21 + i * 14)
		v.setup({"id": 100 + i, "rank": ranks[i], "suit": suits[i]})
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		var role: String = SSCards.CHARACTERS[ranks[i]]["role"]
		v.tooltip_text = "Customize " + SSCards.rank_name(ranks[i])
		v.tapped.connect(func(_card): _customize(role))
		add_child(v)
	var how := UI.label("Remember the cards. Recognize your crew.\nTap a face above to make it yours!", Vector2(40, 690), Vector2(640, 100), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	how.add_theme_font_override("font", UI.font(600))
	add_child(how)
	var best := SSBest.get_best()
	var best_lbl := UI.label("Best: %d points" % best if best > 0 else "", Vector2(20, 800), Vector2(680, 50), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	best_lbl.add_theme_font_override("font", UI.font(900))
	best_lbl.name = "Best"
	add_child(best_lbl)
	var play := UI.button("Play", Vector2(110, 880), Vector2(500, 110), UI.ACCENT, 40)
	play.add_theme_font_override("font", UI.font(800))
	play.pressed.connect(func():
		Sfx.play("tap")
		get_tree().change_scene_to_file("res://games/see_saw/scenes/game.tscn"))
	add_child(play)
	var rules := UI.button("How to Play", Vector2(368, 1016), Vector2(242, 84), Color("#2f3866"), 30)
	rules.add_theme_font_override("font", UI.font(800))
	rules.pressed.connect(show_rules)
	add_child(rules)
	var customize := UI.button("My Cards", Vector2(110, 1016), Vector2(242, 84), Color("#7a4fd6"), 30)
	customize.name = "MyCards"
	customize.add_theme_font_override("font", UI.font(800))
	customize.pressed.connect(_customize.bind("pickpocket"))
	add_child(customize)
	add_child(UI.label("Your face, your friends, your pets.\nTake a photo or upload one in My Cards.", Vector2(50, 1120), Vector2(620, 86), 25, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func show_rules() -> Control:
	var o := Control.new()
	o.name = "Rules"
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
	var subtitle := UI.label("Look. Remember. Answer. Stay in the air.", Vector2(48, 140), Vector2(624, 44), 25, UI.TEXT)
	o.add_child(subtitle)
	var scroll := ScrollContainer.new()
	UI.touch_scroll(scroll)
	scroll.position = Vector2(48, 200)
	scroll.size = Vector2(624, 890)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 600
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var sections := [
		["play", "1 · TAKE A GOOD LOOK", "[b]Level 1:[/b] 1 card · 3 seconds\n[b]Level 2:[/b] 2 cards · 6 seconds\n[b]Level 3:[/b] 3 cards · 9 seconds.\nYou get [b]3 seconds per card[/b].", "#ffce3a"],
		["reference", "2 · REMEMBER & ANSWER", "Cards turn face down. Answer questions about their [b]ranks, suits, order and faces[/b].\nGet every question right to advance.", "#7cdbca"],
		["check", "MAKE EVERY ANSWER COUNT", "[b]Correct answer[/b]  ·  10 × your level\n[b]Level cleared[/b]  ·  +50 points\n[b]5 correct in a row[/b]  ·  +100 points", "#ffce3a"],
		["replay", "A BLAST FROM TWO LEVELS BACK", "After Levels [b]4, 6, 8…[/b], try a bonus question about the level two earlier.\n[b]+50 if correct.[/b] Miss? No counterweight lost.", "#ffb399"],
		["replay", "KEEP YOUR SEAT IN THE AIR", "Start with [b]3 counterweights[/b]. Each regular miss removes one: you sink and retry the level.\nLanded? Finish, or spend [b]250 points[/b] to restore one and keep going.", "#7cdbca"],
		["check", "LOU'S COUNTERWEIGHT", "Clear [b]Level 4[/b], and every level after it, to earn an extra counterweight: [b]one more life[/b].", "#ff9f43"],
		["camera", "MAKE THE CARDS YOURS", "Open [b]My Cards[/b] or tap a face on the menu. Every card from [b]2 to Ace[/b] has a character, and [b]Lou[/b] is the counterweight. Put yourself, friends or pets on any of them.\nYour faces and names become part of the questions!", "#ffce3a"]
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
	var details := _rules_text("[b]A few handy details[/b]\n\nCards read left to right, top row first. Ace is highest.\n\nA miss resets your streak, but keeps earned points. Bonus answers count toward your streak too.\n\nBonus questions use the successful attempt two levels earlier.\n\nYou can buy a counterweight between levels, up to three. The 250 points come out of your score.\n\nYour personalized cards are shared across games.")
	details.visible = false
	var more := UI.button("A few details +", Vector2.ZERO, Vector2(600, 68), Color("#394568"), 26)
	more.custom_minimum_size = Vector2(600, 68)
	more.pressed.connect(func():
		details.visible = not details.visible
		more.text = "Hide details −" if details.visible else "A few details +")
	list.add_child(more)
	list.add_child(details)
	var close := UI.button("Got it", Vector2(210, 1112), Vector2(300, 84), UI.ACCENT, 30)
	close.add_theme_font_override("font", UI.font(800))
	close.pressed.connect(o.queue_free)
	o.add_child(close)
	add_child(o)
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


func _customize(role: String) -> void:
	Profile.edit_slot = role
	Profile.voice_game = "see_saw"
	Profile.creator_return = "res://games/see_saw/scenes/main.tscn"
	Profile.go("my_cards")
