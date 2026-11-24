extends Control
## War and Piece menu (inside the You're a Card app).

const RULES := """[b]Two kinds of rounds, back and forth.[/b] Odd rounds are War. Even rounds are Piece.

[b]WAR[/b]
 • You each get half the deck. Flip your top cards: the higher card wins both.
 • A tie is a war: you each put down 3 cards face-down and 1 face-up. The higher face-up card takes all of them.
 • Have more locked sets than your opponent? You win ties outright, no war needed.
 • Cards you win go into your winnings pile. The round ends when someone's stock runs out, and you keep whatever is left in yours.

[b]PIECE[/b]
 • Arrange your winnings into sets and lock them away:
    – 3 or more of a kind (three 7s), or
    – 3 or more in a row of one suit (5, 6, 7 of Hearts). Aces are high.
 • You can also add cards to a set you locked earlier.
 • Locked sets are safe forever, count toward winning, and win ties in War.
 • Everything you don't lock is shuffled into your stock for the next War.

[b]WINNING[/b]
 • Lock away 30 of the 52 cards and you win.
 • If someone has no loose cards left to play War with, the game ends and whoever locked more cards wins. Same if two Piece rounds in a row go by with no new sets.
 • Strategy: locking a card keeps it safe, but it can't fight for you in War. Hang on to your Aces?

[b]You're a Card[/b]
Jacks, Queens, Kings and Aces are characters: Pip, Juno, Lou and Amara. Soon you can put your own face on them."""

var _rules: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var home := Button.new()
	home.position = Vector2(20, 24)
	home.size = Vector2(68, 68)
	home.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	home.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	home.add_theme_stylebox_override("pressed", UI.box(Color("#262d55"), 34))
	home.tooltip_text = "All games"
	home.pressed.connect(func(): Profile.go("home"))
	home.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(home)
	var t := UI.label("War and Piece", Vector2(20, 110), Vector2(680, 110), 76, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
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
	var how := UI.label("Win cards in War. Lock them into sets in Piece.\nFirst to lock away 30 of the 52 cards wins.", Vector2(40, 700), Vector2(640, 100), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	how.add_theme_font_override("font", UI.font(600))
	add_child(how)
	var play := UI.button("Play the Computer", Vector2(110, 860), Vector2(500, 100), UI.ACCENT, 34)
	play.add_theme_font_override("font", UI.font(800))
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/wp_table.tscn"))
	add_child(play)
	var rules := UI.button("How to Play", Vector2(110, 986), Vector2(500, 84), Color("#2f3866"), 30)
	rules.add_theme_font_override("font", UI.font(800))
	rules.pressed.connect(show_rules)
	add_child(rules)


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
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RULES
	rt.position = Vector2(48, 146)
	rt.size = Vector2(624, 950)
	rt.add_theme_font_override("normal_font", UI.font(500))
	rt.add_theme_font_override("bold_font", UI.font(900))
	rt.add_theme_font_size_override("normal_font_size", 24)
	rt.add_theme_font_size_override("bold_font_size", 25)
	rt.add_theme_color_override("default_color", UI.TEXT)
	o.add_child(rt)
	var close := UI.button("Got it", Vector2(210, 1112), Vector2(300, 84), UI.ACCENT, 30)
	close.add_theme_font_override("font", UI.font(800))
	close.pressed.connect(o.queue_free)
	o.add_child(close)
	parent.add_child(o)
	return o
