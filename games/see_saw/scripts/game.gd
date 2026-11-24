extends Control
## The See Saw table: get ready -> look at the cards -> answer questions -> next level.

const GREEN := Color("#3fb56b")
const WRONG := Color("#e0525d")
const DARK := Color("#2f3866")
const SHOW_RECT := Rect2(24, 196, 672, 880)    # cards while you look at them
const ASK_RECT := Rect2(24, 196, 672, 300)     # the same cards, face down, while you answer
const TAG_H := 30.0                            # space for the 1st/2nd/3rd tag under each card

var g: SeeSaw
var _layer: Control        # everything that changes between steps
var _level_lbl: Label
var _hearts: Hearts
var _bar_bg: Panel
var _bar: Panel
var _secs: Label
var _views: Array = []     # SSCardView for the round's cards
var _opts: Array = []      # option controls for the current question
var _left := 0.0           # seconds left to look
var _token := 0            # bumps whenever a step is taken, cancelling stale timers
var _over: Control
var new_best := false


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	g = SeeSaw.new()
	var s := OS.get_environment("SEESAW_SEED")
	var lv := OS.get_environment("SEESAW_LEVEL")
	g.setup(int(s) if s != "" else randi(), int(lv) if lv != "" else 1)
	var back := UI.button("‹", Vector2(16, 36), Vector2(64, 64), DARK, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://games/see_saw/scenes/main.tscn"))
	add_child(back)
	_level_lbl = UI.label("", Vector2(100, 36), Vector2(360, 64), 38, UI.ACCENT)
	_level_lbl.add_theme_font_override("font", UI.font(900))
	add_child(_level_lbl)
	_hearts = Hearts.new()
	_hearts.position = Vector2(500, 36)
	_hearts.size = Vector2(204, 64)
	add_child(_hearts)
	_bar_bg = UI.panel(Vector2(24, 124), Vector2(600, 18), Color(0, 0, 0, 0.3), 9)
	add_child(_bar_bg)
	_bar = UI.panel(Vector2(24, 124), Vector2(600, 18), UI.ACCENT, 9)
	add_child(_bar)
	_secs = UI.label("", Vector2(632, 108), Vector2(72, 50), 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_secs.add_theme_font_override("font", UI.font(900))
	add_child(_secs)
	_build_ready()


func _process(delta: float) -> void:
	if g.phase != "show":
		return
	_left -= delta
	var total := g.show_seconds()
	_bar.size.x = 600.0 * clampf(_left / total, 0.0, 1.0)
	_secs.text = str(ceili(maxf(_left, 0.0)))
	if _left <= 0.0:
		_time_up()


func _sync_top() -> void:
	_level_lbl.text = "Level %d" % g.level
	_hearts.lives = g.lives
	var showing := g.phase == "show"
	_bar_bg.visible = showing
	_bar.visible = showing
	_secs.visible = showing


func _new_layer() -> Control:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_views.clear()
	_opts.clear()
	_token += 1
	return _layer


func _later(sec: float, f: Callable) -> void:
	var t := _token
	get_tree().create_timer(sec).timeout.connect(func():
		if t == _token and is_instance_valid(self):
			f.call())


func _txt(text: String, pos: Vector2, sz: Vector2, fs: int, col := UI.TEXT, weight := 800, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UI.label(text, pos, sz, fs, col, align)
	l.add_theme_font_override("font", UI.font(weight))
	_layer.add_child(l)
	return l


func _btn(text: String, pos: Vector2, sz: Vector2, col := UI.ACCENT, fs := 34) -> Button:
	var b := UI.button(text, pos, sz, col, fs)
	b.add_theme_font_override("font", UI.font(800))
	_layer.add_child(b)
	return b


# ------------------------------------------------------------------ steps

## Get ready: the level's cards wait face down until you tap Go.
func _build_ready() -> void:
	_new_layer()
	_sync_top()
	var n := g.cards_for_level(g.level)
	var backs: Array = []
	for i in n:
		backs.append({"id": i, "rank": 2, "suit": "S"})
	_lay_out(backs, SHOW_RECT.grow_individual(0, -120, 0, -160), true, false)
	_txt("Level %d" % g.level, Vector2(20, 150), Vector2(680, 70), 52, UI.ACCENT, 900)
	var what := "%d card%s · %d second%s" % [n, "" if n == 1 else "s", int(g.show_seconds()), "" if g.show_seconds() == 1.0 else "s"]
	_txt(what, Vector2(20, 220), Vector2(680, 50), 30, UI.MUTED, 700)
	var tip := "Remember the card!" if n == 1 else "Remember every card, and where it was."
	if g.rounds_played > 0 and not g.last_result.get("cleared", true):
		tip = "New cards. You've got this."
	_txt(tip, Vector2(40, 930), Vector2(640, 50), 28, UI.TEXT, 700)
	var go := _btn("Go!", Vector2(160, 1020), Vector2(400, 110), UI.ACCENT, 44)
	go.pressed.connect(_go)


## Flip the cards face up and start the clock.
func _go() -> void:
	if g.phase != "ready":
		return
	g.start_round()
	Sfx.play("draw")
	_new_layer()
	_left = g.show_seconds()
	_sync_top()
	_lay_out(g.cards, SHOW_RECT, false, true)
	for v in _views:
		_flip_in(v)


func _time_up() -> void:
	if g.phase != "show":
		return
	g.hide_cards()
	Sfx.play("card_play")
	_build_question()


func _build_question() -> void:
	_new_layer()
	_sync_top()
	_lay_out(g.cards, ASK_RECT, true, true)
	var q := g.question()
	var count := "Question %d of %d" % [g.q_index + 1, g.questions.size()]
	_txt(count, Vector2(20, 512), Vector2(680, 40), 24, UI.MUTED, 700)
	_txt(q["text"], Vector2(30, 552), Vector2(660, 110), 38, UI.TEXT, 900)
	_build_options(q)


func _build_options(q: Dictionary) -> void:
	var opts: Array = q["options"]
	var n := opts.size()
	var top := 690.0
	match q["style"]:
		"card":
			var w := 150.0
			var gap := 20.0
			var x0 := 360.0 - (n * w + (n - 1) * gap) / 2.0
			for i in n:
				var v := SSCardView.new()
				v.position = Vector2(x0 + i * (w + gap), top + 20)
				v.size = Vector2(w, w * 1.4)
				v.setup(opts[i])
				v.tapped.connect(func(_v): _pick(i))
				_layer.add_child(v)
				_opts.append(v)
		_:
			var rects := _option_rects(n, q["style"], top)
			for i in n:
				var b := _btn("", rects[i].position, rects[i].size, DARK, 40)
				b.add_theme_color_override("font_color", Color.WHITE)
				b.pressed.connect(func(): _pick(i))
				_dress_option(b, q, i)
				_opts.append(b)


func _option_rects(n: int, style: String, top: float) -> Array:
	var out: Array = []
	if n <= 2:
		for i in n:
			out.append(Rect2(40 + i * 330, top + 40, 310, 200))
		return out
	var h := 220.0 if style in ["suit", "character"] else 170.0
	for i in n:
		out.append(Rect2(40 + (i % 2) * 330, top + (i / 2) * (h + 20), 310, h))
	return out


## What goes on an option button: a suit shape, a character portrait, or text.
func _dress_option(b: Button, q: Dictionary, i: int) -> void:
	var lab: String = q["labels"][i]
	var val = q["options"][i]
	var sz := b.size
	match q["style"]:
		"suit":
			var icon := SuitIcon.new()
			icon.suit = val
			icon.position = Vector2(sz.x / 2 - 50, 26)
			icon.size = Vector2(100, 100)
			b.add_child(icon)
			_on_button(b, lab, Vector2(0, sz.y - 70), Vector2(sz.x, 56), 30)
		"character":
			var tr := TextureRect.new()
			tr.texture = SSCardView.art(SSCards.CHARACTERS[val]["role"])
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(sz.x / 2 - 70, 12)
			tr.size = Vector2(140, 140)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
			_on_button(b, lab, Vector2(0, sz.y - 62), Vector2(sz.x, 52), 32)
		"color":
			var icon := SuitIcon.new()
			icon.pair = ["H", "D"] if val == "red" else ["S", "C"]
			icon.position = Vector2(sz.x / 2 - 60, 30)
			icon.size = Vector2(120, 80)
			b.add_child(icon)
			_on_button(b, lab, Vector2(0, sz.y - 74), Vector2(sz.x, 56), 36)
		_:
			b.text = lab


func _on_button(b: Button, text: String, pos: Vector2, sz: Vector2, fs: int) -> void:
	var l := UI.label(text, pos, sz, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UI.font(800))
	b.add_child(l)


func _pick(i: int) -> void:
	if g.phase != "ask":
		return
	var q := g.question()
	var res := g.answer(i)
	_token += 1
	_mark(i, int(res["answer"]))
	_hearts.lives = g.lives
	Sfx.play("set_complete" if res["cleared"] else ("tap" if res["correct"] else "lose"))
	if res["correct"] and not res["round_over"]:
		_txt("Right!", Vector2(20, 1170), Vector2(680, 60), 40, GREEN, 900)
		_later(0.7, _build_question)
	elif res["cleared"]:
		_txt("Level %d cleared!" % (g.level - 1), Vector2(20, 1170), Vector2(680, 60), 40, GREEN, 900)
		_later(1.1, _advance)
	else:
		# Wrong: show the cards again so you can see what you missed.
		for v in _views:
			v.face_down = false
			v.queue_redraw()
		if q["kind"] in ["nth_card", "nth_suit", "nth_rank", "nth_color", "character"]:
			_views[q["pos"]].glow = true
		elif q["kind"] == "where":
			for v in _views:
				if SSCards.same(v.card, q["card"]):
					v.glow = true
		_txt("Not quite. " + SSQuestions.reveal(q), Vector2(20, 1132), Vector2(680, 50), 28, WRONG, 800)
		var label := "See your score" if res["game_over"] else "Try Level %d again" % g.level
		var b := _btn(label, Vector2(160, 1186), Vector2(400, 80), UI.ACCENT, 30)
		b.pressed.connect(_advance)


## After a round: next level (or the same one again), or game over.
func _advance() -> void:
	if g.phase == "over":
		_game_over()
	elif g.phase == "between":
		g.next_round()
		_build_ready()


func _mark(picked: int, right: int) -> void:
	for j in _opts.size():
		var o: Control = _opts[j]
		var col := Color(0, 0, 0, 0)
		if j == right:
			col = GREEN
		elif j == picked:
			col = WRONG
		if o is SSCardView:
			o.ring = col
			o.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if col.a == 0:
				o.dimmed = true
		elif o is Button:
			o.disabled = true
			var fill := col if col.a > 0 else Color("#262c4a")
			o.add_theme_stylebox_override("disabled", UI.box(fill, 14))
			o.add_theme_color_override("font_disabled_color", Color.WHITE if col.a > 0 else UI.MUTED)


# ------------------------------------------------------------------ layout

## Lay cards out in rows, as big as they fit, numbered 1st, 2nd, 3rd... in reading order.
func _lay_out(cards: Array, area: Rect2, down: bool, tags: bool) -> void:
	var n := cards.size()
	var best_w := 0.0
	var best_cols := 1
	var gap := 14.0
	for cols in range(1, n + 1):
		var rows := ceili(float(n) / cols)
		var w := (area.size.x - gap * (cols - 1)) / cols
		var h_room := (area.size.y - gap * (rows - 1) - (TAG_H if tags else 0.0) * rows) / rows
		w = minf(w, h_room / 1.4)
		w = minf(w, 300.0)
		if w > best_w + 0.5:
			best_w = w
			best_cols = cols
	var w := floorf(best_w)
	var h := floorf(w * 1.4)
	var rows := ceili(float(n) / best_cols)
	var row_h := h + (TAG_H if tags else 0.0)
	var total_h := rows * row_h + (rows - 1) * gap
	var y0 := area.position.y + (area.size.y - total_h) / 2.0
	for i in n:
		var r := i / best_cols
		var in_row := mini(best_cols, n - r * best_cols)
		var row_w := in_row * w + (in_row - 1) * gap
		var x := area.position.x + (area.size.x - row_w) / 2.0 + (i % best_cols) * (w + gap)
		var y := y0 + r * (row_h + gap)
		var v := SSCardView.new()
		v.position = Vector2(x, y)
		v.size = Vector2(w, h)
		v.setup(cards[i], down)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.pivot_offset = v.size / 2
		_layer.add_child(v)
		_views.append(v)
		if tags and n > 1:
			_txt(SSCards.ordinal(i + 1), Vector2(x - 10, y + h + 2), Vector2(w + 20, TAG_H - 2), clampi(int(w * 0.16), 16, 24), UI.MUTED, 800)


func _flip_in(v: Control) -> void:
	v.scale = Vector2(0.05, 1)
	var t := create_tween()
	t.tween_property(v, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ game over

func _game_over() -> void:
	_new_layer()
	_sync_top()
	var score := g.score()
	new_best = SSBest.submit(score)
	var best := SSBest.get_best()
	_over = _layer
	_layer.add_child(UI.panel(Vector2(40, 220), Vector2(640, 840), UI.PANEL, 24))
	_txt("Game over", Vector2(40, 260), Vector2(640, 80), 56, UI.ACCENT, 900)
	_txt("You reached", Vector2(40, 380), Vector2(640, 50), 32, UI.MUTED, 700)
	_txt("Level %d" % score, Vector2(40, 430), Vector2(640, 130), 96, UI.TEXT, 900)
	var cleared := score - 1
	_txt("%d level%s cleared" % [cleared, "" if cleared == 1 else "s"], Vector2(40, 560), Vector2(640, 44), 28, UI.MUTED, 700)
	if new_best:
		Sfx.play("grand")
	var who := "Nice memory, %s!" % Profile.display_name if Profile.display_name != "" else "Nice memory!"
	_txt(who, Vector2(40, 710), Vector2(640, 50), 28, UI.TEXT, 700)
	if new_best:
		_txt("New best!", Vector2(40, 640), Vector2(640, 70), 46, GREEN, 900)
	else:
		_txt("Best: Level %d" % best, Vector2(40, 640), Vector2(640, 70), 36, UI.ACCENT, 800)
	var again := _btn("Play again", Vector2(160, 790), Vector2(400, 104), UI.ACCENT, 38)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	var menu := _btn("Menu", Vector2(160, 920), Vector2(400, 84), DARK, 32)
	menu.add_theme_color_override("font_color", Color.WHITE)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://games/see_saw/scenes/main.tscn"))


# ------------------------------------------------------------------ little drawings

## Lives as hearts: full ones red, lost ones as outlines.
class Hearts extends Control:
	var lives := 3:
		set(v):
			lives = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in SeeSaw.START_LIVES:
			var c := Vector2(size.x - 34 - (SeeSaw.START_LIVES - 1 - i) * 64, size.y / 2 + 2)
			var full := i < lives
			SSCardView.suit_on(self, "H", c, 24, Color("#e0525d") if full else Color(1, 1, 1, 0.16))


## A big suit shape (or a red/black pair) for option buttons.
class SuitIcon extends Control:
	var suit := "S"
	var pair: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var paper := Color("#fbf7ee")
		if pair.is_empty():
			draw_circle(size / 2, size.x * 0.5, paper)
			var col := SSCardView.RED if suit in SSCards.RED else SSCardView.BLACK
			SSCardView.suit_on(self, suit, size / 2, size.x * 0.3, col)
		else:
			var col := SSCardView.RED if pair[0] in SSCards.RED else SSCardView.BLACK
			for k in 2:
				var c := Vector2(size.x * (0.27 + 0.46 * k), size.y / 2)
				draw_circle(c, size.y * 0.5, paper)
				SSCardView.suit_on(self, pair[k], c, size.y * 0.3, col)
