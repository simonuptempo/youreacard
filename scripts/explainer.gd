extends Control
## Player-paced "How to Play": 6 short steps. Every step holds until Next; all animation
## is scoped to the current step (and tab) and is cancelled before navigating or replaying.

const STEPS := [
	["YOUR NEXT GREAT HEIST", "Collect gems, bank bills, and outsmart your opponent"],
	["BE THE FIRST TO COLLECT FOUR SETS", ""],
	["START YOUR TURN", "Draw 2 cards and play up to %d cards"],
	["ACTION CARDS", "Pay for each one with bills from your bank"],
	["DEFENSE CARDS", "Move them to your vault. They spring on attack."],
	["YOU'RE A CARD", "...and you are wild"],
]
const TABS := ["Bank a bill", "Play a gem", "Move to vault", "Take an action"]
const ACTIONS := [
	["swap", "Trade your gem for one of theirs. Both must come from unfinished sets."],
	["shakedown", "Take a random card from your opponent's hand."],
	["lockpick", "Break into their vault and pick a face-down card. A Defense gets defused (discarded). Anything else is a decoy, and you keep it. Defense cards can't stop a Lockpick."],
	["swipe", "Heist: take a gem from their unfinished set."],
	["grand", "Grand Heist: take a finished set of gems, every gem in it."],
	["windfall", "Lucky you! When you draw it, you \"find\" up to 10 spent bills from the discard pile. Then draw another card.", "Plays itself when drawn"],
	["doublecross", "Uh-oh! When you draw it, someone steals up to 10 bills from your bank. Then draw another card.", "Plays itself when drawn"],
]
const DEFENSES := [
	["shield", "Blocks the action."],
	["mirror", "Bounces the action back at the player who played it. A bounced Trade gives you a free counter-trade. A bounced Grand Heist takes their best unfinished set if they have no finished one."],
	["snare", "Blocks the action, and you keep their card."],
]
const PANEL_BG := Color(0.07, 0.17, 0.17, 0.85)

var _step := 0
var _tab := 0
var _stage: Control
var _tab_root: Control
var _tab_buttons: Array = []
var _title: Label
var _sub: Label
var _count: Label
var _practice: Button
var _next: Button
var _back: Button
var _progress: Panel
var _animations: Array[Tween] = []
var _tab_animations: Array[Tween] = []
var _in_tab := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	theme = UI.make_theme()
	add_child(Art.table_bg())
	add_child(UI.label("HOW TO PLAY GEM HEIST", Vector2(30, 24), Vector2(420, 40), 24, UI.TEXT))
	var replay := Button.new()
	replay.position = Vector2(500, 20)
	replay.size = Vector2(62, 54)
	replay.tooltip_text = "Replay animation"
	replay.add_theme_stylebox_override("normal", UI.box(Color("#314742"), 14))
	replay.add_theme_stylebox_override("hover", UI.box(Color("#3d5852"), 14))
	replay.add_theme_stylebox_override("pressed", UI.box(Color("#26383a"), 14))
	replay.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Icon.make("replay", Vector2(13, 9), Vector2(36, 36))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay.add_child(ic)
	replay.pressed.connect(func(): _show_step(_step))
	add_child(replay)
	var close := UI.button("Close", Vector2(574, 20), Vector2(116, 54), Color("#314742"), 22)
	close.pressed.connect(_exit)
	add_child(close)
	_count = UI.label("", Vector2(30, 76), Vector2(400, 36), 20, UI.MUTED)
	add_child(_count)
	add_child(UI.panel(Vector2(30, 126), Vector2(660, 6), Color("#314742"), 3))
	_progress = UI.panel(Vector2(30, 126), Vector2(1, 6), UI.ACCENT, 3)
	add_child(_progress)
	_title = UI.label("", Vector2(30, 150), Vector2(660, 76), 38, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = UI.label("", Vector2(40, 222), Vector2(640, 70), 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	add_child(_sub)
	_stage = Control.new()
	_stage.position = Vector2(0, 300)
	_stage.size = Vector2(720, 850)
	_stage.clip_contents = true
	add_child(_stage)
	_back = UI.button("Back", Vector2(44, 1170), Vector2(200, 76), Color("#314742"), 26)
	_back.pressed.connect(func(): _show_step(_step - 1))
	add_child(_back)
	_next = UI.button("Next", Vector2(264, 1170), Vector2(412, 76), UI.ACCENT, 28)
	_next.pressed.connect(_advance)
	add_child(_next)
	_practice = UI.button("Practice", Vector2(260,1170), Vector2(200,76), UI.ACCENT,26)
	_practice.pressed.connect(func():
		Profile.practice_requested = true
		Profile.rematch_first = -1
		Profile.rematch_cast = -1
		Profile.go("game"))
	add_child(_practice)
	_show_step(Profile.explainer_start)
	Profile.explainer_start = 0


# ------------------------------------------------------------------ navigation

func _stop_animations() -> void:
	for tw in _animations:
		if tw.is_valid():
			tw.kill()
	_animations.clear()
	_tab_animations.clear()


func _exit_tree() -> void:
	_stop_animations()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _show_step(index: int) -> void:
	_step = clampi(index, 0, STEPS.size() - 1)
	_stop_animations()
	_clear(_stage)
	_tab_buttons = []
	_tab_root = null
	_title.text = STEPS[_step][0]
	var sub: String = STEPS[_step][1]
	_sub.text = sub % Profile.plays_per_turn if "%d" in sub else sub
	# Leave room beneath the heading for the animated opening deal.
	var centered := _step == 0
	_title.position.y = 150.0
	_sub.position.y = 222.0
	_title.add_theme_font_size_override("font_size", 38 if centered else (32 if _title.text.length() > 24 else 38))
	_count.text = "STEP %d OF %d" % [_step + 1, STEPS.size()]
	_progress.size.x = 660.0 * float(_step + 1) / STEPS.size()
	_back.disabled = _step == 0
	var last := _step == STEPS.size() - 1
	_practice.visible = last
	_next.position.x = 476 if last else 264
	_next.size.x = 200 if last else 412
	_next.text = "Done" if last else "Next"
	if centered:
		_pop(_title)
		_pop(_sub, 0.3)
	else:
		_title.scale = Vector2.ONE
		_title.modulate.a = 1.0
		_sub.scale = Vector2.ONE
		_sub.modulate.a = 1.0
	match _step:
		0: _setup_notes()
		1: _sets()
		2: _turn()
		3: _rows(ACTIONS, false)
		4: _rows(DEFENSES, true)
		5: _wild()


func _advance() -> void:
	if _step == STEPS.size() - 1:
		_exit()
	else:
		_show_step(_step + 1)


func _exit() -> void:
	_stop_animations()
	Profile.go("settings" if Profile.explainer_return == "settings" else "main")


# ------------------------------------------------------------------ helpers

func _tween() -> Tween:
	var tw := create_tween()
	_animations.append(tw)
	if _in_tab:
		_tab_animations.append(tw)
	return tw


func _pop(node: Control, delay := 0.0) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.88, 0.88)
	node.modulate.a = 0.0
	var tw := _tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.25)


func _move(node: Control, to: Vector2, delay := 0.5, dur := 0.65) -> Tween:
	var tw := _tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "position", to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tw


func _label(parent: Node, text: String, pos: Vector2, sz: Vector2, fs := 26, color := UI.TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := UI.label(text, pos, sz, fs, color, align)
	parent.add_child(label)
	return label


func _card(parent: Node, kind: String, pos: Vector2, sz: Vector2, face := {}, down := false) -> CardView:
	var cv := CardView.new()
	cv.position = pos
	cv.size = sz
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cv)
	cv.setup({"id": 0, "kind": kind}, face, down)
	return cv


func _gem(parent: Node, color: String, pos: Vector2, sz: Vector2) -> Control:
	var gem := GemView.new()
	gem.kind = color
	gem.position = pos
	gem.size = sz
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gem)
	return gem


func _face(kind: String) -> Dictionary:
	return Profile.slot_face(CardDB.slot_for(kind))


# ------------------------------------------------------------------ step 1: getting started

class IntroCoin:
	extends Control
	var progress := 0.0:
		set(value):
			progress=value
			queue_redraw()
	func _draw() -> void:
		var center:=size/2.0
		var radius:=size.x*0.46
		var lift:=sin(progress*PI)*80.0
		# Ground shadow stays on the felt while the coin rises.
		draw_set_transform(Vector2(center.x, size.y+10),0,Vector2(1.0-lift/240.0,0.16))
		draw_circle(Vector2.ZERO,radius,Color(0,0,0,0.28-lift/1000.0))
		var turn:=progress*TAU*3.0
		var width:=maxf(0.055,absf(cos(turn)))
		draw_set_transform(center-Vector2(0,lift),sin(progress*PI)*0.13,Vector2(width,1))
		draw_circle(Vector2(3,4),radius,Color("#85531d"))
		draw_circle(Vector2.ZERO,radius,Color("#dca53b"))
		draw_circle(Vector2(-1,-2),radius*0.91,Color("#ffe3a0"))
		draw_circle(Vector2.ZERO,radius*0.8,Color("#d3a24a"))
		for i in 36:
			var angle:=TAU*i/36
			var direction:=Vector2(cos(angle),sin(angle))
			draw_line(direction*radius*0.84,direction*radius*0.91,Color("#9c702b"),1.3,true)
		var art:=Art.treasure("ruby") if cos(turn)>=0 else Art.treasure("diamond")
		if art!=null:
			Art.draw_fit(self,art,Rect2(-radius*.61,-radius*.61,radius*1.22,radius*1.22))
		draw_arc(Vector2.ZERO,radius*.95,PI*1.08,PI*1.7,24,Color("#fff5cf"),2.0,true)
		draw_set_transform(Vector2.ZERO)

func _setup_notes() -> void:
	# Deal exactly five backs into a shallow fan, one after another.
	for i in 5:
		var card:=_card(_stage,"wild",Vector2(286,-235),Vector2(148,207),{},true)
		card.name="OpeningCard%d" % (i+1)
		card.pivot_offset=card.size/2.0
		card.modulate.a=0
		var offset:=float(i-2)
		var target:=Vector2(110+i*88,24+absf(offset)*13)
		var deal:=_tween()
		deal.tween_interval(0.25+i*0.19)
		deal.tween_property(card,"modulate:a",1.0,0.08)
		deal.parallel().tween_property(card,"position",target,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		deal.parallel().tween_property(card,"rotation",deg_to_rad(offset*6.0),0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var coin:=IntroCoin.new()
	coin.name="OpeningCoin"
	coin.position=Vector2(300,340)
	coin.size=Vector2(120,120)
	coin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	coin.modulate.a=0
	_stage.add_child(coin)
	var caption:=_label(_stage,"Flip to see who starts",Vector2(90,478),Vector2(540,36),23,UI.ACCENT)
	caption.modulate.a=0
	var flip:=_tween()
	flip.tween_interval(1.6)
	flip.tween_property(coin,"modulate:a",1.0,0.15)
	flip.tween_property(coin,"progress",1.0,1.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip.tween_property(caption,"modulate:a",1.0,0.25)
	var box:=UI.panel(Vector2(60,550),Vector2(600,220),PANEL_BG,20)
	_stage.add_child(box)
	_label(_stage,"GETTING STARTED",Vector2(60,565),Vector2(600,30),18,UI.MUTED)
	_label(_stage,"Each player starts with 5 cards. A coin flip decides who goes first, and that player draws just 1 card on their first turn. In a rematch, whoever lost goes first.",Vector2(90,607),Vector2(540,145),24)


# ------------------------------------------------------------------ step 2: four sets

func _sets() -> void:
	var colors: Array = CardDB.COLORS
	for i in colors.size():
		var color: String = colors[i]
		var x := 18.0 + i * 114.0
		_stage.add_child(UI.panel(Vector2(x, 10), Vector2(104, 380), PANEL_BG, 18))
		_label(_stage, CardDB.display_name(color), Vector2(x - 6, 22), Vector2(116, 34), 18, CardDB.tint(color).lightened(0.45))
		for j in CardDB.set_size(color):
			_pop(_gem(_stage, color, Vector2(x + 10, 68 + j * 102), Vector2(84, 84)), i * 0.12 + j * 0.1)
	_pop(_label(_stage, "Every gem set needs 3 of a kind\n(except rubies, which need 2)", Vector2(40, 430), Vector2(640, 90), 28), 1.0)


# ------------------------------------------------------------------ step 3: your turn (tabbed)

func _turn() -> void:
	_card(_stage, "lucky", Vector2(150, 0), Vector2(110, 154), {}, true)
	var a := _card(_stage, "emerald", Vector2(150, 0), Vector2(110, 154))
	var b := _card(_stage, "loot2", Vector2(150, 0), Vector2(110, 154), _face("loot2"))
	var top := _card(_stage, "lucky", Vector2(150, 0), Vector2(110, 154), {}, true)
	_label(_stage, "Deck", Vector2(150, 156), Vector2(110, 26), 18, UI.MUTED)
	a.modulate.a = 0.0
	b.modulate.a = 0.0
	for pair in [[a, Vector2(350, 0), 0.3], [b, Vector2(470, 0), 0.65]]:
		var cv: CardView = pair[0]
		var tw := _tween()
		tw.tween_interval(pair[2])
		tw.tween_property(cv, "modulate:a", 1.0, 0.05)
		tw.tween_property(cv, "position", pair[1], 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	top.move_to_front()
	_label(_stage, "Your hand", Vector2(350, 156), Vector2(230, 26), 18, UI.MUTED)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]
		tb.position = Vector2(20 + i * 172, 200)
		tb.size = Vector2(164, 56)
		tb.add_theme_font_size_override("font_size", 19)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.pressed.connect(_show_tab.bind(i))
		_stage.add_child(tb)
		_tab_buttons.append(tb)
	_stage.add_child(UI.panel(Vector2(20, 264), Vector2(680, 580), PANEL_BG, 20))
	_tab_root = Control.new()
	_tab_root.position = Vector2(20, 264)
	_tab_root.size = Vector2(680, 580)
	_stage.add_child(_tab_root)
	_show_tab(_tab)


func _show_tab(i: int) -> void:
	_tab = i
	for j in _tab_buttons.size():
		var on := j == i
		var tb: Button = _tab_buttons[j]
		var bg: Color = UI.ACCENT if on else Color("#314742")
		tb.add_theme_stylebox_override("normal", UI.box(bg, 12))
		tb.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.1), 12))
		tb.add_theme_stylebox_override("pressed", UI.box(bg.darkened(0.1), 12))
		var fc: Color = Color("#1b2038") if on else UI.TEXT
		for prop in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			tb.add_theme_color_override(prop, fc)
	if _tab_root == null:
		return
	# Cancel only the previous tab's animations; the deal at the top keeps playing.
	for tw in _tab_animations:
		if tw.is_valid():
			tw.kill()
	_tab_animations.clear()
	_clear(_tab_root)
	_in_tab = true
	match i:
		0: _tab_bank()
		1: _tab_gem()
		2: _tab_vault()
		3: _tab_action()
	_in_tab = false


func _tab_bank() -> void:
	for v in 5:
		var kind := "loot%d" % (v + 1)
		_pop(_card(_tab_root, kind, Vector2(14 + v * 132, 40), Vector2(124, 174), _face(kind)), v * 0.12)
	_label(_tab_root, "Bills are worth 1 to 5. Banking one uses a play, and only banked bills can pay for actions.", Vector2(30, 250), Vector2(620, 110), 24)
	_label(_tab_root, "Tip: put family, friends and pets on your bills in Settings → My Cards.", Vector2(30, 400), Vector2(620, 80), 20, UI.MUTED)


func _tab_gem() -> void:
	_label(_tab_root, "YOUR COLLECTION", Vector2(60, 24), Vector2(240, 30), 18, UI.MUTED)
	_card(_tab_root, "emerald", Vector2(110, 64), Vector2(130, 182))
	_label(_tab_root, "FROM YOUR HAND", Vector2(410, 24), Vector2(220, 30), 18, UI.MUTED)
	var played := _card(_tab_root, "emerald", Vector2(450, 64), Vector2(130, 182))
	_move(played, Vector2(140, 104), 0.6, 0.75)
	_label(_tab_root, "Add a gem to a set of the same kind. Finish the set to lock it in. Add another gem to a finished set and your opponent pays you 2 bills (3 for the next one).\nNeed cash? Pawn a gem from your hand or collection: 1 bill (Rubies and Diamonds: 2).", Vector2(30, 320), Vector2(620, 150), 23)


func _tab_vault() -> void:
	_label(_tab_root, "YOUR VAULT", Vector2(50, 24), Vector2(290, 30), 18, UI.MUTED)
	for s in 2:
		_tab_root.add_child(UI.panel(Vector2(50 + s * 150, 64), Vector2(130, 182), Color(1, 1, 1, 0.08), 12))
	_label(_tab_root, "FROM YOUR HAND", Vector2(410, 24), Vector2(220, 30), 18, UI.MUTED)
	var c := _card(_tab_root, "shield", Vector2(450, 64), Vector2(130, 182))
	c.pivot_offset = c.size / 2.0
	var tw := _tween()
	tw.tween_interval(0.6)
	tw.tween_property(c, "scale:x", 0.0, 0.16)
	tw.tween_callback(func(): c.setup({"id": 0, "kind": "shield"}, {}, true))
	tw.tween_property(c, "scale:x", 1.0, 0.16)
	tw.tween_property(c, "position", Vector2(50, 64), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_label(_tab_root, "Move any card to your vault. Your opponent only sees its back, so it could be a Defense card... or a bluff. Move it back to your hand any time for free.", Vector2(30, 330), Vector2(620, 120), 24)


func _tab_action() -> void:
	var kinds := ["swipe", "swap", "grand"]
	for i in kinds.size():
		var cv := _card(_tab_root, kinds[i], Vector2(120 + i * 150, 40), Vector2(140, 196), _face(kinds[i]))
		cv.pivot_offset = cv.size / 2.0
		cv.rotation = deg_to_rad(-8 + i * 8)
		_pop(cv, i * 0.12)
	_label(_tab_root, "Spend banked bills to steal, trade and more.", Vector2(30, 300), Vector2(620, 60), 24)
	_label(_tab_root, "Explained on the next step.", Vector2(30, 362), Vector2(620, 40), 22, UI.ACCENT)


# ------------------------------------------------------------------ steps 4–5: card rows

func _rows(list: Array, free: bool) -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(720, 850)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(700, 0)
	scroll.add_child(box)
	for i in list.size():
		var kind: String = list[i][0]
		var row := Control.new()
		row.custom_minimum_size = Vector2(700, 216)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(row)
		var bg := UI.panel(Vector2(16, 0), Vector2(668, 216), PANEL_BG, 18)
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(bg)
		var cv := CardView.new()
		cv.position = Vector2(30, 12)
		cv.size = Vector2(137, 192)
		cv.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(cv)
		cv.setup({"id": i, "kind": kind}, _face(kind))
		row.add_child(UI.label(CardDB.display_name(kind), Vector2(190, 14), Vector2(470, 44), 30, UI.ACCENT))
		var cost := CardDB.cost(kind)
		var cost_text := "Free" if free or cost == 0 else "Costs " + CardDB.bills(cost)
		if list[i].size() > 2:
			cost_text = list[i][2]
		row.add_child(UI.label(cost_text, Vector2(190, 58), Vector2(470, 34), 22, Color("#f0b27a")))
		row.add_child(UI.label(list[i][1], Vector2(190, 96), Vector2(470, 110), 22, UI.TEXT))
		_pop(row, i * 0.1)
	box.add_child(Control.new())  # small tail so the last row clears the edge
	box.get_child(box.get_child_count() - 1).custom_minimum_size = Vector2(0, 8)


# ------------------------------------------------------------------ step 6: you're wild

func _wild() -> void:
	var cv := _card(_stage, "wild", Vector2(195, 10), Vector2(330, 462), Profile.slot_face("you"))
	cv.editable = true
	# Tap the card to put your face on it right here.
	cv.mouse_filter = Control.MOUSE_FILTER_STOP
	cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cv.tapped.connect(func(_v): _edit_wild())
	_pop(cv)
	_pop(_label(_stage, "A wild card counts as a gem of any color.", Vector2(40, 490), Vector2(640, 60), 28), 0.4)
	var custom := Profile.is_custom("you")
	var edit := UI.button("Change your card" if custom else "Tap to make it you", Vector2(185, 556), Vector2(350, 64), UI.ACCENT, 24)
	edit.pressed.connect(_edit_wild)
	_stage.add_child(edit)
	_pop(edit, 0.7)
	if not custom:
		# A gentle pulse invites the tap.
		cv.pivot_offset = cv.size / 2.0
		var pulse := _tween().set_loops()
		pulse.tween_interval(1.2)
		pulse.tween_property(cv, "scale", Vector2(1.04, 1.04), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(cv, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func _edit_wild() -> void:
	_stop_animations()
	Profile.edit_slot = "you"
	Profile.creator_return = "explainer"
	Profile.go("my_cards")
