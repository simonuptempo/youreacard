extends Control
## The table: War rounds (flip!) and Piece rounds (lock your winnings into sets).

const ME := 0
const BOT := 1
const CARD := Vector2(220, 308)
const PILE := Vector2(130, 182)
const OPP_Y := 200.0
const MY_Y := 540.0
const BATTLE_X := 250.0
const STOCK_X := 36.0
const WON_X := 554.0
const MINI := Vector2(84, 118)

var g: WarState
var _layer: Control          # everything that changes between War and Piece
var _panels := {}            # p -> {name, line, bar, count}
var _banner: Label
var _event: Label
var _main_btn: Button
var _side_btn: Button
var _lock_btn: Button
var _hint: Label
var _battle: Array = []      # WarCardView on the table
var _battle_winner := -1
var _sel: Array = []         # selected card ids (Piece)
var _sort_by_suit := false
var _busy := false
var _over: Control
var _piece_start := 0        # event index when the Piece round began


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	g = WarState.new()
	var s := OS.get_environment("WAP_SEED")
	g.setup(["You", "Computer"], int(s) if s != "" else randi())
	_make_panel(BOT, 16)
	_make_panel(ME, 1004)
	var back := UI.button("‹", Vector2(16, 132), Vector2(60, 56), Color("#2f3866"), 36)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/wp_menu.tscn"))
	add_child(back)
	_banner = UI.label("", Vector2(90, 132), Vector2(540, 56), 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_override("font", UI.font(900))
	add_child(_banner)
	var help := UI.button("?", Vector2(644, 132), Vector2(60, 56), Color("#2f3866"), 32)
	help.add_theme_font_override("font", UI.font(900))
	help.pressed.connect(func(): load("res://games/war_and_piece/wp_menu.gd").rules_overlay(self))
	add_child(help)
	_build_mode()


# ------------------------------------------------------------------ panels

func _make_panel(p: int, y: float) -> void:
	var col := Color("#2b3358") if p == ME else Color("#3a2740")
	add_child(UI.panel(Vector2(16, y), Vector2(688, 104), col, 18))
	var name := UI.label(g.nm(p), Vector2(36, y + 8), Vector2(300, 44), 30, UI.TEXT)
	name.add_theme_font_override("font", UI.font(900))
	add_child(name)
	var line := UI.label("", Vector2(36, y + 52), Vector2(340, 40), 22, UI.MUTED)
	line.add_theme_font_override("font", UI.font(700))
	add_child(line)
	var count := UI.label("", Vector2(380, y + 8), Vector2(304, 44), 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	count.add_theme_font_override("font", UI.font(900))
	add_child(count)
	add_child(UI.panel(Vector2(400, y + 62), Vector2(284, 20), Color(0, 0, 0, 0.3), 10))
	var bar := UI.panel(Vector2(400, y + 62), Vector2(0, 20), UI.ACCENT, 10)
	add_child(bar)
	_panels[p] = {"line": line, "count": count, "bar": bar}


func _sync_panels() -> void:
	for p in 2:
		var d: Dictionary = _panels[p]
		var parts: Array = []
		if g.phase() == "war":
			parts.append("Stock %d" % g.stock(p).size())
			parts.append("Won %d" % g.players[p]["won"].size())
		else:
			parts.append("%d to arrange" % g.hand(p).size())
		var ns: int = g.sets(p).size()
		parts.append("%d set%s" % [ns, "" if ns == 1 else "s"])
		d["line"].text = "  ·  ".join(parts)
		var lc := g.locked_count(p)
		d["count"].text = "Locked %d / %d" % [lc, WarCards.WIN_LOCKED]
		d["bar"].size.x = 284.0 * minf(1.0, float(lc) / WarCards.WIN_LOCKED)
	match g.phase():
		"war":
			_banner.text = "Round %d · WAR" % g.round_number
		"piece":
			_banner.text = "Round %d · PIECE" % g.round_number
		_:
			_banner.text = "Game over"


# ------------------------------------------------------------------ modes

func _build_mode() -> void:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_battle.clear()
	_sel.clear()
	match g.phase():
		"war":
			_build_war()
		"piece":
			_build_piece()
		_:
			_show_game_over()
	_sync_panels()


func _btn(text: String, pos: Vector2, sz: Vector2, col := UI.ACCENT, fs := 32) -> Button:
	var b := UI.button(text, pos, sz, col, fs)
	b.add_theme_font_override("font", UI.font(800))
	_layer.add_child(b)
	return b


# ------------------------------------------------------------------ War

func _build_war() -> void:
	for p in 2:
		var y := OPP_Y if p == BOT else MY_Y + CARD.y - PILE.y
		var lbl_y := y + PILE.y + 4 if p == BOT else y - 36
		var st := UI.label("", Vector2(STOCK_X, lbl_y), Vector2(PILE.x, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		st.name = "StockLabel%d" % p
		_layer.add_child(st)
		var wl := UI.label("", Vector2(WON_X, lbl_y), Vector2(PILE.x, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		wl.name = "WonLabel%d" % p
		_layer.add_child(wl)
	_event = UI.label("", Vector2(30, 862), Vector2(660, 130), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_event.add_theme_font_override("font", UI.font(700))
	_layer.add_child(_event)
	_event.text = _last_round_text() if g.round_number == 1 else _last_round_text()
	_main_btn = _btn("Flip!", Vector2(36, 1126), Vector2(430, 112), UI.ACCENT, 40)
	_main_btn.pressed.connect(_on_flip)
	_side_btn = _btn("Skip to end\nof round", Vector2(484, 1126), Vector2(200, 112), Color("#2f3866"), 24)
	_side_btn.pressed.connect(_skip_war)
	_sync_piles()


func _last_round_text() -> String:
	for i in range(g.events.size() - 1, -1, -1):
		if g.events[i]["kind"] == "round":
			return g.events[i]["text"] + "\nTap Flip!"
	return ""


func _pile_y(p: int) -> float:
	return OPP_Y if p == BOT else MY_Y + CARD.y - PILE.y


func _sync_piles() -> void:
	for n in _layer.get_children():
		if n.has_meta("pile"):
			n.queue_free()
	for p in 2:
		var y := _pile_y(p)
		var n := g.stock(p).size()
		for k in mini(4, n):
			var v := WarCardView.new()
			v.size = PILE
			v.position = Vector2(STOCK_X + k * 3, y - k * 3)
			v.setup({"id": 0, "rank": 2, "suit": "S"}, true)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.set_meta("pile", true)
			_layer.add_child(v)
		var won: Array = g.players[p]["won"] if g.phase() == "war" else g.hand(p)
		if not won.is_empty():
			var t := WarCardView.new()
			t.size = PILE
			t.position = Vector2(WON_X, y)
			t.setup(won[-1])
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.set_meta("pile", true)
			_layer.add_child(t)
		else:
			var empty := UI.panel(Vector2(WON_X, y), PILE, Color(1, 1, 1, 0.05), 14)
			empty.set_meta("pile", true)
			_layer.add_child(empty)
		var sl: Label = _layer.get_node_or_null("StockLabel%d" % p)
		if sl:
			sl.text = "Stock: %d" % n
		var wl: Label = _layer.get_node_or_null("WonLabel%d" % p)
		if wl:
			wl.text = "Won: %d" % won.size()


func _on_flip() -> void:
	if _busy:
		return
	if g.phase() != "war":
		_build_mode()
		return
	_clear_battle(true)
	var r := g.flip()
	_show_faceoff(r, true)
	_event.text = g.events[-1]["text"]
	_sync_piles()
	_sync_panels()
	if g.phase() != "war":
		_round_over_war()


func _clear_battle(animate: bool) -> void:
	for v: Control in _battle:
		if not is_instance_valid(v):
			continue
		if animate and _battle_winner >= 0:
			var tw: Tween = v.create_tween()
			tw.tween_property(v, "position", Vector2(WON_X, _pile_y(_battle_winner)), 0.18)
			tw.parallel().tween_property(v, "size", PILE, 0.18)
			tw.tween_callback(v.queue_free)
		else:
			v.queue_free()
	_battle.clear()


func _show_faceoff(r: Dictionary, animate: bool) -> void:
	_battle_winner = r.get("winner", -1)
	for p in 2:
		var cards: Array = r["cards"][p]
		var y := OPP_Y if p == BOT else MY_Y
		var n := cards.size()
		var step := minf(18.0, 160.0 / maxf(1.0, n - 1))
		var left := BATTLE_X - step * (n - 1) * 0.5
		for i in n:
			var c: Dictionary = cards[i]
			var up := i % 4 == 0 or i == n - 1
			var v := WarCardView.new()
			v.size = CARD
			v.setup(c, not up)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var to := Vector2(left + i * step, y)
			if i == n - 1 and p == _battle_winner:
				v.glow = true
			_layer.add_child(v)
			_battle.append(v)
			if animate:
				v.position = Vector2(STOCK_X, _pile_y(p))
				v.size = PILE
				var tw: Tween = v.create_tween()
				tw.tween_interval(i * 0.03)
				tw.tween_property(v, "position", to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(v, "size", CARD, 0.2)
			else:
				v.position = to
	if r.get("wars", 0) > 0 or r.get("reason", "") == "sets":
		var tag := UI.label("WAR!" if r.get("reason", "") != "sets" else "SETS WIN THE TIE", Vector2(BATTLE_X - 120, MY_Y - 34), Vector2(CARD.x + 240, 30), 26, Color("#ff7a59"), HORIZONTAL_ALIGNMENT_CENTER)
		tag.add_theme_font_override("font", UI.font(900))
		_layer.add_child(tag)
		_battle.append(tag)


func _round_over_war() -> void:
	_main_btn.text = "On to the Piece round"
	_main_btn.add_theme_font_size_override("font_size", 32)
	_side_btn.visible = false
	_event.text = g.events[-2]["text"] + "\n" + g.events[-1]["text"] if g.events.size() >= 2 else g.events[-1]["text"]


func _skip_war() -> void:
	if g.phase() != "war":
		return
	_clear_battle(false)
	var last := {}
	while g.phase() == "war":
		last = g.flip()
	_show_faceoff(last, false)
	_sync_piles()
	_sync_panels()
	_round_over_war()


# ------------------------------------------------------------------ Piece

func _build_piece() -> void:
	_piece_start = g.events.size()
	_hint = UI.label("", Vector2(30, 194), Vector2(660, 70), 23, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_font_override("font", UI.font(700))
	_layer.add_child(_hint)
	var sets_title := UI.label("Your locked sets", Vector2(30, 268), Vector2(400, 32), 22, UI.MUTED)
	sets_title.add_theme_font_override("font", UI.font(800))
	_layer.add_child(sets_title)
	var ss := ScrollContainer.new()
	ss.name = "Sets"
	ss.position = Vector2(20, 302)
	ss.size = Vector2(680, 170)
	ss.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layer.add_child(ss)
	var hand_title := UI.label("", Vector2(30, 482), Vector2(400, 32), 22, UI.MUTED)
	hand_title.name = "HandTitle"
	hand_title.add_theme_font_override("font", UI.font(800))
	_layer.add_child(hand_title)
	var sort := _btn("", Vector2(470, 478), Vector2(220, 42), Color("#2f3866"), 20)
	sort.name = "Sort"
	sort.pressed.connect(func():
		_sort_by_suit = not _sort_by_suit
		_sync_piece())
	var hs := ScrollContainer.new()
	hs.name = "Hand"
	hs.position = Vector2(20, 528)
	hs.size = Vector2(680, 466)
	hs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layer.add_child(hs)
	var auto := _btn("Auto", Vector2(36, 1126), Vector2(150, 112), Color("#2f3866"), 28)
	auto.pressed.connect(_auto_arrange)
	_lock_btn = _btn("Lock set", Vector2(200, 1126), Vector2(300, 112), UI.ACCENT, 28)
	_lock_btn.pressed.connect(_lock_selected)
	_main_btn = _btn("Done", Vector2(514, 1126), Vector2(170, 112), Color("#3cb371"), 30)
	_main_btn.pressed.connect(_done_piece)
	_sync_piece()


func _sync_piece() -> void:
	var ss: ScrollContainer = _layer.get_node("Sets")
	for c in ss.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	ss.add_child(row)
	var my_sets: Array = g.sets(ME)
	if my_sets.is_empty():
		var none := UI.label("None yet. Sets you lock are safe for the rest of the game.", Vector2.ZERO, Vector2(640, 120), 22, UI.MUTED)
		none.custom_minimum_size = Vector2(640, 120)
		row.add_child(none)
	for i in my_sets.size():
		row.add_child(_set_widget(my_sets[i], i))
	var hand: Array = g.hand(ME).duplicate()
	if _sort_by_suit:
		hand.sort_custom(func(a, b):
			if a["suit"] != b["suit"]:
				return WarCards.SUITS.find(a["suit"]) < WarCards.SUITS.find(b["suit"])
			return a["rank"] < b["rank"])
	else:
		hand = WarCards.sort_hand(hand)
	var hs: ScrollContainer = _layer.get_node("Hand")
	for c in hs.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	hs.add_child(grid)
	for c in hand:
		var v := WarCardView.new()
		v.custom_minimum_size = MINI
		v.setup(c)
		v.selected = c["id"] in _sel
		v.tapped.connect(_toggle.bind(c["id"]))
		grid.add_child(v)
	(_layer.get_node("HandTitle") as Label).text = "Your winnings: %d cards" % hand.size()
	(_layer.get_node("Sort") as Button).text = "Sort by rank" if _sort_by_suit else "Sort by suit"
	_sync_selection()
	_sync_panels()


func _set_widget(cards: Array, index: int) -> Control:
	var n := cards.size()
	var step := 34.0
	var w := MINI.x + step * (n - 1)
	var box := Control.new()
	box.custom_minimum_size = Vector2(w, 164)
	for i in n:
		var v := WarCardView.new()
		v.size = MINI
		v.position = Vector2(i * step, 0)
		v.stacked = i < n - 1
		v.setup(cards[i])
		v.tapped.connect(func(_v): _add_to(index))
		box.add_child(v)
	var l := UI.label(WarCards.describe_set(cards), Vector2(-20, 122), Vector2(w + 40, 36), 19, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UI.font(800))
	box.add_child(l)
	return box


func _toggle(_v, id: int) -> void:
	if id in _sel:
		_sel.erase(id)
	else:
		_sel.append(id)
	var hs: ScrollContainer = _layer.get_node("Hand")
	for v in hs.get_child(0).get_children():
		v.selected = v.card["id"] in _sel
	_sync_selection()


func _selected_cards() -> Array:
	return g.hand(ME).filter(func(c): return c["id"] in _sel)


func _add_target() -> int:
	for k in g.sets(ME).size():
		if g.can_add(ME, k, _sel):
			return k
	return -1


func _sync_selection() -> void:
	var cards := _selected_cards()
	var t := WarCards.set_type(cards)
	var add := _add_target()
	_lock_btn.disabled = true
	_lock_btn.text = "Lock set"
	if cards.is_empty():
		_hint.text = "Tap cards to make a set: 3+ of a kind, or 3+ in a row of one suit. Then lock it away."
	elif t != "":
		var ds := WarCards.describe_set(cards)
		_hint.text = "%s. Lock it away for good!" % (ds.left(1).to_upper() + ds.substr(1))
		_lock_btn.disabled = false
	elif add >= 0:
		var grown: Array = g.sets(ME)[add] + cards
		_hint.text = "These go on your %s, making %s." % [WarCards.describe_set(g.sets(ME)[add]), WarCards.describe_set(grown)]
		_lock_btn.text = "Add to set"
		_lock_btn.disabled = false
	else:
		_hint.text = "Not a set yet. You need 3+ of a kind, or 3+ in a row of one suit (Aces high)."


func _lock_selected() -> void:
	var ok := false
	if WarCards.set_type(_selected_cards()) != "":
		ok = g.lock_set(ME, _sel.duplicate())
	else:
		var k := _add_target()
		ok = k >= 0 and g.add_to_set(ME, k, _sel.duplicate())
	if ok:
		_sel.clear()
		_sync_piece()


func _add_to(index: int) -> void:
	if not _sel.is_empty() and g.add_to_set(ME, index, _sel.duplicate()):
		_sel.clear()
		_sync_piece()


func _auto_arrange() -> void:
	var pl := WarBot.plan(g.hand(ME), g.sets(ME))
	for ids in pl["new"]:
		g.lock_set(ME, ids)
	for a in pl["add"]:
		if not g.add_to_set(ME, a[0], a[1]):
			for k in g.sets(ME).size():
				if g.add_to_set(ME, k, a[1]):
					break
	_sel.clear()
	_sync_piece()


func _done_piece() -> void:
	if _busy:
		return
	WarBot.play_piece(g, BOT)
	var lines: Array = []
	for i in range(_piece_start, g.events.size()):
		var e: Dictionary = g.events[i]
		if e["p"] == BOT and e["kind"] == "lock":
			lines.append("• " + e["text"].trim_prefix("Computer locked away ").trim_prefix("Computer "))
	g.finish_piece(ME)
	_summary(lines)


func _summary(lines: Array) -> void:
	var o := Control.new()
	o.name = "Summary"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	o.add_child(UI.panel(Vector2(40, 300), Vector2(640, 620)))
	var h := UI.label("The Computer's Piece round", Vector2(70, 320), Vector2(580, 60), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_theme_font_override("font", UI.font(900))
	o.add_child(h)
	var body := "It didn't lock anything this round." if lines.is_empty() else "It locked away:\n" + "\n".join(lines)
	body += "\n\nLocked so far: you %d, Computer %d (of %d to win)." % [g.locked_count(ME), g.locked_count(BOT), WarCards.WIN_LOCKED]
	var b := UI.label(body, Vector2(80, 390), Vector2(560, 400), 25, UI.TEXT)
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_override("font", UI.font(700))
	o.add_child(b)
	var go := UI.button("See who won" if g.phase() == "over" else "Next: War!", Vector2(170, 806), Vector2(380, 92), UI.ACCENT, 32)
	go.add_theme_font_override("font", UI.font(800))
	go.pressed.connect(func():
		o.queue_free()
		_build_mode())
	o.add_child(go)
	add_child(o)


# ------------------------------------------------------------------ game over

func _show_game_over() -> void:
	_sync_panels()
	var o := Control.new()
	o.name = "GameOver"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var title := "You win!" if g.winner == ME else ("Computer wins" if g.winner == BOT else "It's a draw")
	var big := UI.label(title, Vector2(20, 300), Vector2(680, 130), 84, UI.ACCENT if g.winner != BOT else Color("#ff8a7a"), HORIZONTAL_ALIGNMENT_CENTER)
	big.add_theme_font_override("font", UI.font(900))
	o.add_child(big)
	var why := UI.label(g.events[-1]["text"], Vector2(60, 440), Vector2(600, 150), 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	why.add_theme_font_override("font", UI.font(700))
	o.add_child(why)
	# The winner's best character card, for a bit of ceremony
	if g.winner < 2:
		var best: Dictionary = {}
		for s in g.sets(g.winner):
			for c in s:
				if best.is_empty() or c["rank"] > best["rank"]:
					best = c
		if not best.is_empty():
			var v := WarCardView.new()
			v.size = Vector2(200, 280)
			v.position = Vector2(260, 610)
			v.setup(best)
			v.glow = true
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			o.add_child(v)
	var again := UI.button("Play again", Vector2(110, 900), Vector2(500, 96), UI.ACCENT, 34)
	again.add_theme_font_override("font", UI.font(800))
	again.pressed.connect(func(): get_tree().reload_current_scene())
	o.add_child(again)
	var menu := UI.button("Main menu", Vector2(110, 1012), Vector2(500, 80), Color("#2f3866"), 30)
	menu.add_theme_font_override("font", UI.font(800))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/wp_menu.tscn"))
	o.add_child(menu)
	_layer.add_child(o)
	_over = o
