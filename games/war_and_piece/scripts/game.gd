extends Control
## The table: War rounds (flip!) and Piece rounds (lock your winnings into sets).
## Plays the Computer (saved after every move), or an online game (WarOnline.game_id set):
## then the server holds the game, and this screen shows its view (you are always player 0).

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
var _resumed := false        # this game was picked up from the save

# Online games
const POLL := 4.0
const SEEN_PATH := "user://wp_seen.json"
var _online := false
var _game_id := ""
var _move_count := -1
var _outbox: Array = []      # your Piece moves, sent in order (they show at once)
var _pumping := false
var _polling := false


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if WarOnline.game_id != "":
		_online = true
		_game_id = WarOnline.game_id
		WarOnline.game_id = ""
		var loading := UI.label("Loading your game…", Vector2(0, 560), Vector2(720, 80), 32, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(loading)
		var r := await WarOnline.call_fn(Online, "state", {"game_id": _game_id})
		loading.queue_free()
		if not r["ok"]:
			_fatal(r["error"])
			return
		_adopt(r["data"])
	elif WarSave.resume_next:
		WarSave.resume_next = false
		g = WarSave.load_game()
		_resumed = g != null
	if g == null:
		g = WarState.new()
		var s := OS.get_environment("WAP_SEED")
		g.setup(["You", "Computer"], int(s) if s != "" else randi())
		WarSave.save(g)
	_make_panel(BOT, 16)
	_make_panel(ME, 1004)
	var back := UI.button("‹", Vector2(16, 132), Vector2(60, 56), Color("#2f3866"), 36)
	back.pressed.connect(_leave)
	add_child(back)
	_banner = UI.label("", Vector2(90, 132), Vector2(540, 56), 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_override("font", UI.font(900))
	add_child(_banner)
	var help := UI.button("?", Vector2(644, 132), Vector2(60, 56), Color("#2f3866"), 32)
	help.add_theme_font_override("font", UI.font(900))
	help.pressed.connect(func(): load("res://games/war_and_piece/scripts/menu.gd").rules_overlay(self))
	add_child(help)
	_build_mode()
	if _online:
		_catch_up()
		_poll_loop()


func _leave() -> void:
	if _online:
		_mark_seen()
		_online = false   # stops polling
		get_tree().change_scene_to_file("res://games/war_and_piece/scenes/online.tscn")
	else:
		get_tree().change_scene_to_file("res://games/war_and_piece/scenes/main.tscn")


func _fatal(msg: String) -> void:
	add_child(UI.label(msg, Vector2(40, 520), Vector2(640, 120), 28, Color("#ff9f8f"), HORIZONTAL_ALIGNMENT_CENTER))
	var back := UI.button("Back", Vector2(210, 700), Vector2(300, 84), UI.ACCENT, 30)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/online.tscn"))
	add_child(back)


# ------------------------------------------------------------------ moves

## Every change you make goes through here: the rules check it, and the game is saved.
## Online, Piece moves show at once and go to the server in order; flips and Done are
## sent straight away by their buttons (_on_flip, _skip_war, _done_piece).
func _do(m: Dictionary) -> bool:
	if _online:
		if not m["t"] in ["lock", "add"] or not g.apply(m):
			return false
		var out := m.duplicate()
		out.erase("p")   # the server knows which player you are
		_outbox.append(out)
		_pump()
		return true
	if not g.apply(m):
		return false
	_after_move()
	return true


# ------------------------------------------------------------------ online

## Take the server's view of the game (you are player 0 in it).
func _adopt(data: Dictionary) -> void:
	g = WarState.from_dict(data["view"])
	g.players[1]["name"] = str(data.get("opponent", {}).get("name", g.players[1]["name"]))
	_move_count = int(data.get("move_count", 0))


func _send(m: Dictionary) -> Dictionary:
	return await WarOnline.call_fn(Online, "act", {"game_id": _game_id, "move": m})


## Sends queued Piece moves one at a time. If the server says no, reload its view.
func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while not _outbox.is_empty() and is_inside_tree():
		var r := await _send(_outbox[0])
		_outbox.pop_front()
		if r["ok"]:
			_move_count = int(r["data"].get("move_count", _move_count))
		else:
			_outbox.clear()
			_say(r["error"], true)
			await _refresh(true)
	_pumping = false


## Fetch the game again; rebuild the screen if it moved on (or if asked to).
func _refresh(rebuild := false) -> bool:
	var r := await WarOnline.call_fn(Online, "state", {"game_id": _game_id})
	if not r["ok"] or not is_inside_tree():
		return false
	var changed := int(r["data"].get("move_count", 0)) != _move_count
	if not changed and not rebuild:
		return false
	var before := g.events.size()
	var phase_before := g.phase()
	_adopt(r["data"])
	if rebuild or g.phase() != phase_before:
		_after_opponent(before, phase_before)
	elif g.phase() == "war":
		# They flipped while you watched: show their face-off.
		_clear_battle(false)
		if not g.last_faceoff.is_empty():
			_show_faceoff(g.last_faceoff, false)
		_event.text = "%s flipped: %s" % [g.nm(BOT), g.events[-1]["text"]] if g.events[-1]["kind"] in ["flip", "war"] else g.events[-1]["text"]
		_sync_piles()
		_sync_panels()
	else:
		_sync_panels()
	_mark_seen()
	return true


func _after_opponent(before: int, phase_before: String) -> void:
	var waiting := get_node_or_null("Waiting")
	if waiting:
		waiting.queue_free()
	if phase_before == "piece" and g.phase() != "piece":
		_summary(_their_locks(before))
	else:
		_build_mode()


## What the other player locked in the Piece round that just ended.
func _their_locks(_from: int) -> Array:
	var lines: Array = []
	var piece_round := -1
	for i in range(g.events.size() - 1, -1, -1):
		var e: Dictionary = g.events[i]
		if e["kind"] == "lock":
			piece_round = e["round"]
			break
		if e["kind"] == "round" and str(e["text"]).contains("Piece"):
			piece_round = e["round"]
			break
	for e in g.events:
		if e["round"] == piece_round and e["p"] == BOT and e["kind"] == "lock":
			lines.append("• " + str(e["text"]).trim_prefix(g.nm(BOT) + " locked away ").trim_prefix(g.nm(BOT) + " "))
	return lines


func _poll_loop() -> void:
	if _polling:
		return
	_polling = true
	while _online and is_inside_tree():
		await get_tree().create_timer(POLL).timeout
		if not _online or not is_inside_tree():
			break
		if _busy or _pumping or not _outbox.is_empty() or g.phase() == "over":
			continue
		await _refresh()
	_polling = false


func _say(text: String, error := false) -> void:
	if is_instance_valid(_event) and g.phase() == "war":
		_event.text = text
	elif is_instance_valid(_hint):
		_hint.text = text
	if error:
		push_warning(text)


## Events you haven't seen yet (the other player's flips and sets while you were away).
func _seen() -> Dictionary:
	var f := FileAccess.open(SEEN_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _mark_seen() -> void:
	if not _online:
		return
	var d := _seen()
	d[_game_id] = g.events.size()
	var f := FileAccess.open(SEEN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _catch_up() -> void:
	var seen := int(_seen().get(_game_id, -1))
	if seen < 0 or seen >= g.events.size():
		_mark_seen()
		return
	var lines: Array = []
	for i in range(seen, g.events.size()):
		var e: Dictionary = g.events[i]
		if e["p"] == BOT or e["kind"] in ["round", "over"]:
			lines.append(str(e["text"]))
	_mark_seen()
	if lines.is_empty():
		return
	if lines.size() > 9:
		lines = ["…and %d more before this." % (lines.size() - 8)] + lines.slice(lines.size() - 8)
	var o := _overlay_box("While you were away", "\n".join(lines), "Got it")
	o.name = "CatchUp"


func _after_move() -> void:
	WarSave.save(g)


# ------------------------------------------------------------------ panels

func _make_panel(p: int, y: float) -> void:
	var col := Color("#2b3358") if p == ME else Color("#3a2740")
	add_child(UI.panel(Vector2(16, y), Vector2(688, 104), col, 18))
	var name := UI.label("You" if p == ME else g.nm(p), Vector2(36, y + 8), Vector2(300, 44), 30, UI.TEXT)
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
	_event.text = _last_round_text()
	if _resumed and not g.last_faceoff.is_empty() and g.events[-1]["kind"] in ["flip", "war"]:
		# Picking up a saved game: the last face-off is still on the table.
		_show_faceoff(g.last_faceoff, false)
		_event.text = "Welcome back! " + g.events[-1]["text"]
	_resumed = false
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
	if _online:
		if not await _online_move({"t": "flip"}):
			return
	elif not _do({"t": "flip"}):
		return
	_show_faceoff(g.last_faceoff, true)
	_flip_sound(g.last_faceoff)
	_event.text = g.events[-1]["text"]
	_sync_piles()
	_sync_panels()
	if g.phase() != "war":
		_round_over_war()


## Sends a flip (or Done) and takes the server's answer. False if it didn't happen.
func _online_move(m: Dictionary) -> bool:
	_busy = true
	while _pumping or not _outbox.is_empty():
		await get_tree().process_frame
	var r := await _send(m)
	_busy = false
	if not is_inside_tree():
		return false
	if not r["ok"]:
		_say(r["error"], true)
		await _refresh(true)
		return false
	_adopt(r["data"])
	_mark_seen()
	return true


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


func _flip_sound(r: Dictionary) -> void:
	Sfx.play("coin_flip" if r.get("wars", 0) > 0 else "card_play", -2.0)
	_speak(r)


## When a Jack, Queen, King or Ace wins, that character sometimes says something
## (in your recorded voice, if you made one for that card).
func _speak(r: Dictionary) -> void:
	var role := _speaker(r)
	var own := role != "" and VoiceRecorder.has_voice(role)
	if role == "" or not Sfx.should_speak(role, {}, own):
		return
	var line := Sfx.say(role, "", own, bool(Profile.voice_alt.get(role, false)))
	if line == "":
		return
	var w: int = r["winner"]
	var y := (OPP_Y + CARD.y + 8) if w == BOT else (MY_Y - 78)
	var bubble := PanelContainer.new()
	bubble.name = "Speech"
	bubble.add_theme_stylebox_override("panel", UI.box(Color("#fffdf6"), 18, UI.ACCENT, 3))
	var l := Label.new()
	l.text = "%s: “%s”" % [Profile.face_name(role), line]
	l.add_theme_font_override("font", UI.font(800))
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UI.BG)
	bubble.add_child(l)
	bubble.position = Vector2(190, y)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bubble)
	_battle.append(bubble)
	var tw := bubble.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)


## The character whose card won a face-off, or "" (number cards don't talk).
static func _speaker(faceoff: Dictionary) -> String:
	var w := int(faceoff.get("winner", -1))
	if w < 0 or faceoff.get("ups", []).size() < 2 or faceoff["ups"][w] == null:
		return ""
	return WarCards.role_for_rank(int(faceoff["ups"][w]["rank"]))


func _round_over_war() -> void:
	_main_btn.text = "On to the Piece round"
	_main_btn.add_theme_font_size_override("font_size", 32)
	_side_btn.visible = false
	_event.text = g.events[-2]["text"] + "\n" + g.events[-1]["text"] if g.events.size() >= 2 else g.events[-1]["text"]


func _skip_war() -> void:
	if g.phase() != "war":
		return
	_clear_battle(false)
	if _online:
		if not await _online_move({"t": "flip_all"}):
			return
	elif not _do({"t": "flip_all"}):
		return
	_show_faceoff(g.last_faceoff, false)
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
	Sfx.play("tap", -6.0)
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
		ok = _do({"t": "lock", "p": ME, "ids": _sel.duplicate()})
	else:
		var k := _add_target()
		ok = k >= 0 and _do({"t": "add", "p": ME, "set": k, "ids": _sel.duplicate()})
	if ok:
		Sfx.play("set_complete")
		_sel.clear()
		_sync_piece()


func _add_to(index: int) -> void:
	if not _sel.is_empty() and _do({"t": "add", "p": ME, "set": index, "ids": _sel.duplicate()}):
		_sel.clear()
		_sync_piece()


func _auto_arrange() -> void:
	# Work it out on a copy, then make the moves for real.
	for m in WarBot.arrange(WarState.from_dict(g.to_dict()), ME):
		_do(m)
	_sel.clear()
	_sync_piece()


func _done_piece() -> void:
	if _busy:
		return
	if _online:
		_main_btn.disabled = true
		if not await _online_move({"t": "done"}):
			_main_btn.disabled = false
			return
		if g.phase() == "piece":
			_show_waiting()
		else:
			_summary(_their_locks(0))
		return
	WarBot.arrange(g, BOT)
	var lines: Array = []
	for i in range(_piece_start, g.events.size()):
		var e: Dictionary = g.events[i]
		if e["p"] == BOT and e["kind"] == "lock":
			lines.append("• " + e["text"].trim_prefix("Computer locked away ").trim_prefix("Computer "))
	g.apply({"t": "done", "p": BOT})
	_do({"t": "done", "p": ME})
	_summary(lines)


## Online: you're done arranging; the other player isn't yet.
func _show_waiting() -> void:
	_sync_panels()
	var o := _overlay_box("Your sets are locked in", "Waiting for %s to finish their Piece round.\n\nYou can leave this screen: the game will be waiting under Your games." % g.nm(BOT), "Back to Your games")
	o.name = "Waiting"
	var btn: Button = o.get_meta("button")
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c["callable"])
	btn.pressed.connect(_leave)


## A dimmed box with a title, some text and one button (which closes it unless rewired).
func _overlay_box(title: String, body: String, button: String) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	o.add_child(UI.panel(Vector2(40, 260), Vector2(640, 700)))
	var h := UI.label(title, Vector2(70, 280), Vector2(580, 60), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_theme_font_override("font", UI.font(900))
	o.add_child(h)
	var b := UI.label(body, Vector2(80, 350), Vector2(560, 480), 23, UI.TEXT)
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_override("font", UI.font(700))
	o.add_child(b)
	var go := UI.button(button, Vector2(150, 850), Vector2(420, 88), UI.ACCENT, 28)
	go.add_theme_font_override("font", UI.font(800))
	go.pressed.connect(o.queue_free)
	o.add_child(go)
	o.set_meta("button", go)
	add_child(o)
	return o


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
	var h := UI.label("%s's Piece round" % ("The Computer" if not _online else g.nm(BOT)), Vector2(70, 320), Vector2(580, 60), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_theme_font_override("font", UI.font(900))
	o.add_child(h)
	var it := "It" if not _online else g.nm(BOT)
	var body := ("%s didn't lock anything this round." % it) if lines.is_empty() else ("%s locked away:\n" % it) + "\n".join(lines)
	body += "\n\nLocked so far: you %d, %s %d (of %d to win)." % [g.locked_count(ME), g.nm(BOT), g.locked_count(BOT), WarCards.WIN_LOCKED]
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
	Sfx.play("win" if g.winner == ME else "lose")
	var o := Control.new()
	o.name = "GameOver"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var title := "You win!" if g.winner == ME else ("%s wins" % g.nm(BOT) if g.winner == BOT else "It's a draw")
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
	var again := UI.button("Play again" if not _online else "Your games", Vector2(110, 900), Vector2(500, 96), UI.ACCENT, 34)
	again.add_theme_font_override("font", UI.font(800))
	again.pressed.connect(func(): get_tree().reload_current_scene() if not _online else _leave())
	o.add_child(again)
	var menu := UI.button("Main menu", Vector2(110, 1012), Vector2(500, 80), Color("#2f3866"), 30)
	menu.add_theme_font_override("font", UI.font(800))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/main.tscn"))
	o.add_child(menu)
	_layer.add_child(o)
	_over = o
