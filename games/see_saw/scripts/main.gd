extends Control
## See Saw menu (opened from the You're a Card home screen).

const RULES := """[b]Look. Remember. Answer.[/b]

 • [b]Level 1[/b] shows 1 card for 1 second. [b]Level 2[/b] shows 2 cards for 2 seconds. [b]Level 3[/b]: 3 cards, 3 seconds. And so on.
 • Then the cards flip face down and you answer a few quick questions: What was the 2nd card? What suit was it? Was there a red card? Which card was NOT shown? Who was on the character card?
 • Cards are numbered in reading order: left to right, top row first.

[b]LIVES[/b]
 • You have 3 lives (the hearts at the top).
 • Answer every question right to move up a level.
 • A wrong answer costs a life, and you try that level again with new cards.
 • Lose all 3 and it's game over. Your score is the highest level you reached.

[b]You're a Card[/b]
Jacks, Queens, Kings and Aces are characters: Pip, Juno, Lou and Amara. Soon you can put your own face on them."""


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
	var t := UI.label("See Saw", Vector2(20, 110), Vector2(680, 120), 96, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
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
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
	var how := UI.label("1 card for 1 second. Then 2 for 2. Then 3 for 3...\nHow far can you remember?", Vector2(40, 690), Vector2(640, 100), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	how.add_theme_font_override("font", UI.font(600))
	add_child(how)
	var best := SSBest.get_best()
	var best_lbl := UI.label("Best: Level %d" % best if best > 0 else "", Vector2(20, 800), Vector2(680, 50), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	best_lbl.add_theme_font_override("font", UI.font(900))
	best_lbl.name = "Best"
	add_child(best_lbl)
	var play := UI.button("Play", Vector2(110, 880), Vector2(500, 110), UI.ACCENT, 40)
	play.add_theme_font_override("font", UI.font(800))
	play.pressed.connect(func():
		Sfx.play("tap")
		get_tree().change_scene_to_file("res://games/see_saw/scenes/game.tscn"))
	add_child(play)
	var rules := UI.button("How to Play", Vector2(110, 1016), Vector2(500, 84), Color("#2f3866"), 30)
	rules.add_theme_font_override("font", UI.font(800))
	rules.pressed.connect(show_rules)
	add_child(rules)


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
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RULES
	rt.position = Vector2(48, 146)
	rt.size = Vector2(624, 950)
	rt.add_theme_font_override("normal_font", UI.font(500))
	rt.add_theme_font_override("bold_font", UI.font(900))
	rt.add_theme_font_size_override("normal_font_size", 26)
	rt.add_theme_font_size_override("bold_font_size", 27)
	rt.add_theme_color_override("default_color", UI.TEXT)
	o.add_child(rt)
	var close := UI.button("Got it", Vector2(210, 1112), Vector2(300, 84), UI.ACCENT, 30)
	close.add_theme_font_override("font", UI.font(800))
	close.pressed.connect(o.queue_free)
	o.add_child(close)
	add_child(o)
	return o
