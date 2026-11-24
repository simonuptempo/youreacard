extends Control
## War and Piece menu (opened from the You're a Card home screen).

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
Jacks, Queens, Kings and Aces are characters: Pip, Juno, Lou and Amara. Tap Your Cards to put your own face (or anyone's) on them, and even record their lines in your voice."""

var _rules: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	var saved := WarSave.load_game()
	var y := 830.0
	if saved != null:
		var cont := UI.button("", Vector2(110, y), Vector2(500, 110), UI.ACCENT, 34)
		cont.name = "Continue"
		cont.pressed.connect(continue_game)
		add_child(cont)
		var big := UI.label("Continue", Vector2(0, 8), Vector2(500, 56), 36, UI.BG, HORIZONTAL_ALIGNMENT_CENTER)
		big.add_theme_font_override("font", UI.font(900))
		cont.add_child(big)
		var info := UI.label(WarSave.describe(saved), Vector2(0, 62), Vector2(500, 34), 21, UI.BG, HORIZONTAL_ALIGNMENT_CENTER)
		info.add_theme_font_override("font", UI.font(700))
		cont.add_child(info)
		y += 126
	if saved == null:
		var play := UI.button("Play the Computer", Vector2(110, y), Vector2(500, 100), UI.ACCENT, 34)
		play.name = "NewGame"
		play.add_theme_font_override("font", UI.font(800))
		play.pressed.connect(new_game)
		add_child(play)
		y += 116
	# The rest in two columns.
	var more: Array = []
	if saved != null:
		more.append(["NewGame", "New Game", Color("#3cb371"), new_game])
	more.append(["PlayOnline", "Play Online", Color("#4c8dff"), func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/online.tscn")])
	more.append(["YourCards", "Your Cards", Color("#7a4fd6"), func():
		Profile.edit_slot = "pickpocket"
		Profile.creator_return = "home"
		Profile.go("my_cards")])
	more.append(["HowToPlay", "How to Play", Color("#2f3866"), show_rules])
	for i in more.size():
		var m: Array = more[i]
		var wide := i == more.size() - 1 and more.size() % 2 == 1
		var b := UI.button(m[1], Vector2(110 + (i % 2) * 258, y + int(i / 2) * 96), Vector2(500 if wide else 242, 82), m[2], 28)
		b.name = m[0]
		b.add_theme_font_override("font", UI.font(800))
		b.pressed.connect(m[3])
		add_child(b)
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
