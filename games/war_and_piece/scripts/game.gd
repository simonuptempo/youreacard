extends Control
## The table: War rounds (flip!) and Piece rounds (lock your winnings into sets).
## Plays the Computer (saved after every move), or an online game (WarOnline.game_id set):
## then the server holds the game, and this screen shows its view (you are always player 0).

const Opponents = preload("res://games/war_and_piece/scripts/war_opponents.gd")
const ME := 0
const BOT := 1
const CARD := Vector2(220, 308)
const OPP_CARD := Vector2(160, 224)
const PILE := Vector2(130, 182)
const OPP_Y := 232.0
const MY_Y := 574.0
const BATTLE_CENTER_X := 360.0
const STOCK_X := 36.0
const WON_X := 554.0
const MINI := Vector2(84, 118)

var g: WarState
var _showdown_played := false
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
var _reduced_motion := false
var _war_continue := false
var _animating := false
var _settings: Control
var _shield_label: Label
var _heist_picker: Control
var _bot_running := false
var _shield_voice_cursor := 0
var _voices: Node
var _speech_bubble: Control
var _speaking_card: WarCardView
var _speech_card_id := -1
var _pile_top := {}
var _last_shield_voice := -15000
var _inactive_portrait_material: ShaderMaterial
var _resumed := false        # this game was picked up from the save
# Hold Deal! for 3 seconds to fast-forward the rest of the War round.
const HOLD_SECONDS := 3.0
const FAST_ROUND_SECONDS := 10.0  # about how long a fast-forwarded round takes
var _holding := false
var _hold_t := 0.0
var _hold_fill: Control
var _fast := false
var _fast_factor := 1.0
var _skip_release := false   # the release that ends a completed hold isn't also a tap

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
	_voices = preload("res://games/war_and_piece/scripts/war_voice.gd").new()
	add_child(_voices)
	_voices.reaction.connect(_show_reaction)
	var preferences := ConfigFile.new()
	preferences.load("user://wp_preferences.cfg")
	_reduced_motion = bool(preferences.get_value("display", "reduced_motion", false))
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
		if int(r["data"].get("view", {}).get("rules_version", 1)) < 5:
			_fatal("The new Piece rules are not available online yet. Play the Computer for now.")
			return
		_adopt(r["data"])
	elif WarSave.resume_next:
		WarSave.resume_next = false
		g = WarSave.load_game()
		_resumed = g != null
	if g == null:
		g = WarState.new()
		var s := OS.get_environment("WAP_SEED")
		g.setup(["You", Opponents.take_next()], int(s) if s != "" else randi())
		WarSave.save(g)
	_make_panel(BOT, 16)
	_make_panel(ME, 1004)
	_shield_label = UI.label("", Vector2(28, 1096), Vector2(664, 26), 18, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_shield_label)
	var back := UI.button("‹", Vector2(16, 132), Vector2(60, 56), Color("#2f3866"), 36)
	back.pressed.connect(_leave)
	add_child(back)
	_banner = UI.label("", Vector2(90, 132), Vector2(470, 56), 28, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_override("font", UI.font(900))
	add_child(_banner)
	var help := UI.button("?", Vector2(644, 132), Vector2(60, 56), Color("#2f3866"), 32)
	help.add_theme_font_override("font", UI.font(900))
	help.pressed.connect(func(): load("res://games/war_and_piece/scripts/menu.gd").rules_overlay(self))
	add_child(help)
	var gear := UI.button("", Vector2(574, 132), Vector2(60, 56), Color("#2f3866"), 28)
	gear.tooltip_text = "Game settings"
	gear.accessibility_name = "Game settings"
	gear.add_child(Icon.make("gear", Vector2(12, 10), Vector2(36, 36)))
	gear.pressed.connect(_show_settings)
	add_child(gear)
	_shield_voice_cursor = g.events.size()
	_build_mode()
	if not _resumed and g.phase() == "war": _voices.react("game_start")
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
	if not r["ok"] or not is_inside_tree() or _animating or is_instance_valid(_settings) or (_busy and not rebuild):
		return false
	if int(r["data"].get("move_count", 0)) < _move_count:
		return false
	var changed := int(r["data"].get("move_count", 0)) != _move_count or int(r["data"]["view"]["winner"]) != g.winner
	if not changed and not rebuild:
		return false
	var before := g.events.size()
	var phase_before := g.phase()
	_adopt(r["data"])
	if phase_before == "war" and not g.last_faceoff.is_empty() and not rebuild and g.phase() != "over":
		_clear_battle(false)
		_main_btn.disabled = true
		await _animate_faceoff(g.last_faceoff)
		_sync_piles()
		_sync_panels()
		_main_btn.disabled = false
		_main_btn.text = "Deal!"
		if g.phase() != "war":
			_round_over_war()
	elif rebuild or g.phase() != phase_before:
		_after_opponent(before, phase_before)
	elif g.phase() == "piece":
		if _layer.get_node_or_null("Hand") == null: _build_mode()
		else: _sync_piece()
	else:
		_sync_panels()
	_mark_seen()
	return true


func _after_opponent(before: int, phase_before: String) -> void:
	var waiting := get_node_or_null("Waiting")
	if waiting:
		waiting.queue_free()
	if phase_before == "piece" and g.phase() != "piece":
		_build_mode()
	else:
		_build_mode()


## What the other player locked in the Piece round that just ended.
func _their_locks(_from: int) -> Array:
	var lines: Array = []
	var piece_round := -1
	for i in range(g.events.size() - 1, -1, -1):
		var e: Dictionary = g.events[i]
		if e["kind"] in ["lock", "heist"]:
			piece_round = e["round"]
			break
		if e["kind"] == "round" and str(e["text"]).contains("Piece"):
			piece_round = e["round"]
			break
	for e in g.events:
		if e["round"] == piece_round and e["p"] == BOT and e["kind"] in ["lock", "heist"]:
			lines.append("• " + str(e["text"]).trim_prefix(g.nm(BOT) + " banked ").trim_prefix(g.nm(BOT) + " "))
	return lines


func _poll_loop() -> void:
	if _polling:
		return
	_polling = true
	while _online and is_inside_tree():
		await get_tree().create_timer(POLL).timeout
		if not _online or not is_inside_tree():
			break
		if _busy or _animating or is_instance_valid(_settings) or _pumping or not _outbox.is_empty() or g.phase() == "over":
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
	add_child(UI.panel(Vector2(16, y + 12), Vector2(688, 80), col, 18))
	if p == ME:
		var avatar := AvatarView.new()
		avatar.position = Vector2(36, y + 31)
		avatar.size = Vector2(42, 42)
		avatar.role = Profile.me_slot
		avatar.data = Profile.face_or_default(Profile.me_slot)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(avatar)
	else:
		if not _online and g.nm(p) in Opponents.NAMES:
			var portrait := Opponents.portrait(g.nm(p), Vector2(32, y + 26), Vector2(50, 50))
			portrait.name = "AnimalOpponent"
			add_child(portrait)
		else:
			add_child(UI.panel(Vector2(36, y + 31), Vector2(42, 42), Color("#754553"), 21))
			add_child(UI.label(g.nm(p).left(1).to_upper(), Vector2(36, y + 31), Vector2(42, 42), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var name := UI.label("You" if p == ME else g.nm(p), Vector2(88, y + 30), Vector2(132, 44), 24, Color("#78d9cb") if p == ME else Color("#ffb39c"))
	name.add_theme_font_override("font", UI.font(900))
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(name)
	var dots: Array = []
	for i in 13:
		var rank: int = i + 2
		var dot := UI.button(WarCards.rank_short(rank), Vector2(242 + i * 34, y + 37), Vector2(30, 30), Color.TRANSPARENT, 17)
		dot.add_theme_font_override("font", UI.font(900))
		dot.pressed.connect(_inspect_rank_set.bind(p, rank))
		add_child(dot)
		dots.append(dot)
	_panels[p] = {"dots": dots}


func _sync_panels() -> void:
	if is_instance_valid(_shield_label):
		_shield_label.text = "Your secret shields: %d" % g.shields[ME] if g.shields[ME] > 0 else ""
	for p in 2:
		var d: Dictionary = _panels[p]
		for i in d["dots"].size():
			var rank: int = i + 2
			var owned: bool = g.sets(p).any(func(bank): return int(bank[0]["rank"]) == rank)
			var dot: Button = d["dots"][i]
			var suspense: bool = _busy and g.last_faceoff.get("reason", "") == "final_showdown"
			dot.disabled = suspense
			if suspense and p == int(g.last_faceoff.winner) and rank == int(g.sets(p)[-1][0].rank): owned = false
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				var circle := UI.box(UI.ACCENT if owned else Color.TRANSPARENT, 15, UI.ACCENT if owned else UI.MUTED, 1)
				circle.content_margin_left = 0
				circle.content_margin_right = 0
				circle.content_margin_top = 0
				circle.content_margin_bottom = 0
				dot.add_theme_stylebox_override(state, circle)
			dot.size = Vector2(30, 30)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				dot.add_theme_color_override(state, UI.BG if owned else UI.MUTED)
			dot.tooltip_text = "%s: %s" % [WarCards.plural_rank(rank), "banked by " + g.nm(p) if owned else "not banked"]
			dot.accessibility_name = dot.tooltip_text
	if is_instance_valid(_shield_label): _shield_label.visible = g.phase() != "piece"

	match g.phase():
		"war":
			_banner.text = "Round %d · WAR" % g.round_number
		"piece":
			_banner.text = "Round %d · WAR" % (g.round_number - 1) if is_instance_valid(_layer) and _layer.get_meta("display_phase", "") == "war" else "Piece your sets together"
		_:
			_banner.text = "Final Showdown" if _busy and g.last_faceoff.get("reason", "") == "final_showdown" else "Game over"


# ------------------------------------------------------------------ modes

func _build_mode() -> void:
	if not _online and g.winner < 0 and g.check_complete(): WarSave.save(g)
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
			if g.last_faceoff.get("reason", "") == "final_showdown" and not _showdown_played:
				_showdown_played = true
				_animate_showdown()
			else: _show_game_over()
	_sync_panels()


func _btn(text: String, pos: Vector2, sz: Vector2, col := UI.ACCENT, fs := 32) -> Button:
	var b := UI.button(text, pos, sz, col, fs)
	b.add_theme_font_override("font", UI.font(800))
	_layer.add_child(b)
	return b


# ------------------------------------------------------------------ War

func _build_war() -> void:
	_voices.war_reactions_enabled = true
	_layer.set_meta("display_phase", "war")
	for p in 2:
		var y := OPP_Y if p == BOT else MY_Y + CARD.y - PILE.y
		var lbl_y := y + PILE.y + 4 if p == BOT else y - 54
		var st := UI.label("", Vector2(STOCK_X, lbl_y), Vector2(PILE.x, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		st.name = "StockLabel%d" % p
		_layer.add_child(st)
		var wl := UI.label("", Vector2(WON_X, lbl_y), Vector2(PILE.x, 32), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		wl.name = "WonLabel%d" % p
		_layer.add_child(wl)
	_event = UI.label("", Vector2(30, 912), Vector2(660, 80), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_event.add_theme_font_override("font", UI.font(700))
	_layer.add_child(_event)
	_event.text = _last_round_text()
	if _resumed and not g.last_faceoff.is_empty() and g.events[-1]["kind"] in ["flip", "war"]:
		# Picking up a saved game: the last face-off is still on the table.
		_show_faceoff(g.last_faceoff, false)
		_event.text = g.events[-1]["text"]
	_resumed = false
	_main_btn = _btn("Deal!", Vector2(36, 1126), Vector2(648, 112), UI.ACCENT, 40)
	_main_btn.pressed.connect(_on_flip)
	# Holding fills the button left to right; full after 3 seconds = fast-forward.
	_hold_fill = UI.panel(Vector2.ZERO, Vector2(0, 112), Color(1, 1, 1, 0.38), 18)
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_btn.add_child(_hold_fill)
	_main_btn.button_down.connect(func():
		if g.phase() == "war" and not _animating and not _busy and not _fast:
			_holding = true
			_hold_t = 0.0)
	_main_btn.button_up.connect(func():
		_holding = false
		if not _fast and is_instance_valid(_hold_fill): _hold_fill.size.x = 0)
	var hold_tip := UI.label("Tip: hold Deal! to fast-forward the round", Vector2(20, 1241), Vector2(680, 30), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hold_tip.name = "HoldTip"
	_layer.add_child(hold_tip)
	_side_btn = null
	for p in 2:
		var yy := OPP_Y - 38 if p == BOT else MY_Y - 38
		var who := "OPPONENT'S CARD" if p == BOT else "YOUR CARD"
		var tag := UI.label(who, Vector2(BATTLE_CENTER_X - 145, yy), Vector2(290, 32), 19, Color("#ffb39c") if p == BOT else Color("#78d9cb"), HORIZONTAL_ALIGNMENT_CENTER)
		tag.add_theme_font_override("font", UI.font(900))
		_layer.add_child(tag)
	var unclaimed := UI.label("", Vector2(20, 882), Vector2(680, 28), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	unclaimed.name = "Unclaimed"
	_layer.add_child(unclaimed)
	_sync_piles()


func _last_round_text() -> String:
	for i in range(g.events.size() - 1, -1, -1):
		if g.events[i]["kind"] == "round":
			return g.events[i]["text"] + "\nTap Deal!"
	return ""


func _card_size(p: int) -> Vector2:
	return OPP_CARD if p == BOT else CARD


func _card_position(p: int) -> Vector2:
	return Vector2(BATTLE_CENTER_X - _card_size(p).x / 2, OPP_Y if p == BOT else MY_Y)


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
			var top: Dictionary = _pile_top.get(p, {})
			t.setup(top if not top.is_empty() and won.any(func(c): return c.get("id", -1) == top.get("id", -2)) else won[-1])
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.set_meta("pile", true)
			_layer.add_child(t)
			if is_instance_valid(_speech_bubble) and int(t.card.get("id", -2)) == _speech_card_id:
				_speaking_card = t
		else:
			var empty := UI.panel(Vector2(WON_X, y), PILE, Color(1, 1, 1, 0.05), 14)
			empty.set_meta("pile", true)
			_layer.add_child(empty)
		var sl: Label = _layer.get_node_or_null("StockLabel%d" % p)
		if sl:
			sl.text = ("Your deck %d" if p == ME else "Their deck %d") % n
		var wl: Label = _layer.get_node_or_null("WonLabel%d" % p)
		if wl:
			wl.text = ("Your wins %d" if p == ME else "Their wins %d") % won.size()
	var unclaimed: Label = _layer.get_node_or_null("Unclaimed")
	if unclaimed:
		unclaimed.text = "Unclaimed · %d cards set aside" % g.unclaimed.size() if not g.unclaimed.is_empty() else ""


func _on_flip() -> void:
	if _skip_release:
		_skip_release = false
		return
	if _fast:
		return
	if _animating:
		if _main_btn.text in ["Go to war!", "Yet another war!"]:
			_war_continue = true
		return
	if _busy:
		return
	if g.phase() != "war":
		_abort_war_quotes()
		_build_mode()
		return
	_clear_battle(false)
	_main_btn.disabled = true
	if _online:
		if not await _online_move({"t": "flip"}):
			_main_btn.disabled = false
			return
	elif not _do({"t": "flip"}):
		_main_btn.disabled = false
		return
	await _animate_faceoff(g.last_faceoff)
	_sync_piles()
	_sync_panels()
	_main_btn.disabled = false
	_main_btn.text = "Deal!"
	if g.phase() != "war":
		_round_over_war()


## Held Deal! for 3 seconds: deal out the rest of this War round in fast motion
## (about 10 seconds), wars included, without stopping for "Go to war!".
func _fast_forward() -> void:
	if g.phase() != "war" or _fast:
		return
	_fast = true
	_abort_war_quotes()
	# Each face-off uses at least one card per side; spread the round over ~10 seconds.
	var left := mini(g.stock(0).size(), g.stock(1).size())
	_fast_factor = clampf(left * 1.45 / FAST_ROUND_SECONDS, 2.5, 12.0)
	_main_btn.disabled = true
	_main_btn.text = "Fast-forwarding…"
	var tip: Label = _layer.get_node_or_null("HoldTip")
	if tip: tip.text = ""
	while g.phase() == "war" and is_inside_tree():
		_clear_battle(false)
		if _online:
			if not await _online_move({"t": "flip"}):
				break
		elif not _do({"t": "flip"}):
			break
		await _animate_faceoff(g.last_faceoff)
		_sync_piles()
		_sync_panels()
		if is_instance_valid(_hold_fill) and _hold_fill.is_inside_tree():
			_hold_fill.size.x = _main_btn.size.x  # stays full while it runs
	_fast = false
	_fast_factor = 1.0
	if not is_inside_tree():
		return
	if is_instance_valid(_hold_fill): _hold_fill.size.x = 0
	if is_instance_valid(_main_btn):
		_main_btn.disabled = false
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _skip_release = false
		_main_btn.text = "Deal!"
	if g.phase() != "war":
		_round_over_war()


## The rules resolve atomically for saves/networking; this replays each visible stage.
func _animate_faceoff(r: Dictionary) -> void:
	_animating = true
	_busy = true
	var cards: Array = r["cards"]
	var n: int = cards[0].size()
	# Older server deployments can return unequal short-war contributions.
	if cards[1].size() != n:
		_show_faceoff(r, false)
		_event.text = g.events[-1]["text"]
		_animating = false
		_busy = false
		return
	for i in n:
		var up := i % 4 == 0 or i == n - 1
		if i > 0 and (i - 1) % 4 == 0:
			var tie_roles: Array = []
			for card in _battle:
				if card is WarCardView and not card.face_down:
					var role := WarCards.role_for_rank(int(card.card.get("rank", 0)))
					if role != "" and role not in tie_roles: tie_roles.append(role)
			if not tie_roles.is_empty() and not _fast: _voices.react("war_start" if i == 1 else "war_again", tie_roles)
			_event.text = "Tie! %d cards at stake. Both add %d." % [i * 2, mini(4, n - i)]
			if not _fast:   # fast-forward goes straight into the war
				_main_btn.text = "Go to war!" if i == 1 else "Yet another war!"
				_main_btn.disabled = false
				_war_continue = false
				while not _war_continue:
					await get_tree().process_frame
				_main_btn.disabled = true
				_main_btn.text = "Dealing…"
		else:
			_event.text = "Flipping…" if up else "War · %d cards at stake" % ((i + 1) * 2)
		var newest: Array = []
		var deal := create_tween().set_parallel(true)
		for p in 2:
			# Collapse the old cards into a compact, readable stack behind the new card.
			for j in _battle.size():
				var old: Control = _battle[j]
				if old.get_meta("owner", -1) == p:
					var age := i - int(old.get_meta("index", 0))
					deal.tween_property(old, "position", _card_position(p) - Vector2(mini(age, 6) * 8, 0), _duration(0.22))
			var v := WarCardView.new()
			v.size = _card_size(p) if _reduced_motion else PILE
			v.position = _card_position(p) if _reduced_motion else Vector2(STOCK_X, _pile_y(p))
			v.setup(cards[p][i], true)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.set_meta("owner", p)
			v.set_meta("index", i)
			_layer.add_child(v)
			_battle.append(v)
			newest.append(v)
			deal.tween_property(v, "position", _card_position(p), _duration(0.28)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			deal.tween_property(v, "size", _card_size(p), _duration(0.28))
		await deal.finished
		if up:
			var turn := create_tween().set_parallel(true)
			for v: WarCardView in newest:
				v.pivot_offset = v.size / 2
				turn.tween_property(v, "scale:x", 0.02 if not _reduced_motion else 1.0, _duration(0.13))
			await turn.finished
			for p in 2:
				newest[p].setup(cards[p][i])
				newest[p].mouse_filter = Control.MOUSE_FILTER_IGNORE
			var reveal := create_tween().set_parallel(true)
			for v: WarCardView in newest:
				reveal.tween_property(v, "scale:x", 1.0, _duration(0.16)).set_trans(Tween.TRANS_SINE)
			await reveal.finished
			Sfx.play("wp_card_deal", -4.0)
			await get_tree().create_timer(_duration(0.45)).timeout
	var w := int(r.get("winner", -1))
	_battle_winner = w
	_event.text = "Still tied! %d cards set aside." % r["pot"] if w < 0 else ("You win %d cards!" % r["pot"] if w == ME else "%s wins %d cards!" % [g.nm(BOT), r["pot"]])
	if r.get("reason", "") == "sets":
		_event.text += " More banked sets wins the tie."
	if w >= 0:
		var leader: WarCardView = _battle[(n - 1) * 2 + w]
		leader.glow = true
		_layer.move_child(leader, -1)
	if w >= 0: _pile_top.erase(w)
	if not _fast: _speak(r)
	if is_instance_valid(_speaking_card) and _speaking_card in _battle:
		_layer.move_child(_speaking_card, -1)
		_pile_top[w] = _speaking_card.card.duplicate()
	await get_tree().create_timer(_duration(0.65)).timeout
	# Gather behind the winning card, then carry the complete stack to its owner.
	var center := _card_position(w)
	var gather := create_tween().set_parallel(true)
	for v: Control in _battle:
		gather.tween_property(v, "position", center, _duration(0.26))
		gather.tween_property(v, "size", _card_size(w), _duration(0.26))
	await gather.finished
	var collect := create_tween().set_parallel(true)
	for v: Control in _battle:
		v.pivot_offset = Vector2.ZERO
		if _reduced_motion:
			collect.tween_property(v, "modulate:a", 0.0, 0.12)
		else:
			collect.tween_property(v, "position", Vector2(WON_X, _pile_y(w)) if w >= 0 else Vector2(320, 884), _duration(0.38)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			collect.tween_property(v, "size", PILE if w >= 0 else Vector2(36, 50), _duration(0.38))
	await collect.finished
	_clear_battle(false)
	_animating = false
	_busy = false


func _duration(seconds: float) -> float:
	return 0.05 if _reduced_motion else seconds / 1.55 / (_fast_factor if _fast else 1.0)


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
			tw.tween_property(v, "position", Vector2(WON_X, _pile_y(_battle_winner)), _duration(0.18))
			tw.parallel().tween_property(v, "size", PILE, _duration(0.18))
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
		var left := _card_position(p).x - step * (n - 1) * 0.5
		for i in n:
			var c: Dictionary = cards[i]
			var up := i % 4 == 0 or i == n - 1
			var v := WarCardView.new()
			v.size = _card_size(p)
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
				tw.tween_interval(_duration(i * 0.03))
				tw.tween_property(v, "position", to, _duration(0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(v, "size", _card_size(p), _duration(0.2))
			else:
				v.position = to


func _flip_sound(r: Dictionary) -> void:
	Sfx.play("wp_card_deal", -4.0)
	_speak(r)


## When a Jack, Queen, King or Ace wins, that character sometimes says something
## (in your recorded voice, if you made one for that card).
func _speak(r: Dictionary) -> void:
	# The cast cheers for the player; opponents remain silent.
	if int(r.get("winner", -1)) != ME: return
	var roles: Array = []
	for card in _battle:
		if card is WarCardView and not card.face_down:
			var role := WarCards.role_for_rank(int(card.card.get("rank", 0)))
			if role != "" and role not in roles: roles.append(role)
	if roles.is_empty(): return
	_voices.react("war_win" if int(r.get("pot", 2)) > 2 else "deal_win", roles)


func _abort_war_quotes() -> void:
	_voices.war_reactions_enabled = false
	_voices.stop_quotes()
	if is_instance_valid(_speech_bubble):
		_speech_bubble.hide()
		_speech_bubble.queue_free()
	_speech_bubble = null
	_speaking_card = null
	_speech_card_id = -1


func _process(_delta: float) -> void:
	if _holding:
		if g.phase() != "war" or _animating or _busy or not is_instance_valid(_main_btn):
			_holding = false
		else:
			_hold_t += _delta
			if is_instance_valid(_hold_fill):
				_hold_fill.size.x = _main_btn.size.x * minf(_hold_t / HOLD_SECONDS, 1.0)
			if _hold_t >= HOLD_SECONDS:
				_holding = false
				_skip_release = true
				_fast_forward()
	if not is_instance_valid(_speech_bubble): return
	var tail: Polygon2D = _speech_bubble.get_node("Tail")
	tail.visible = is_instance_valid(_speaking_card)
	if is_instance_valid(_speaking_card):
		var target: Vector2 = get_global_transform().affine_inverse() * (_speaking_card.get_global_transform() * Vector2(_speaking_card.size.x / 2, 0))
		_speech_bubble.position = Vector2(clampf(target.x - 240, 24, 216), maxf(205, target.y - _speech_bubble.size.y - 22))
		var tip := target - _speech_bubble.position
		var base_x := clampf(tip.x, 24, _speech_bubble.size.x - 24)
		var bottom := _speech_bubble.size.y
		tail.polygon = PackedVector2Array([Vector2(base_x - 14, bottom - 2), Vector2(base_x + 14, bottom - 2), tip])
		var fill: Polygon2D = tail.get_node("Fill")
		fill.polygon = PackedVector2Array([Vector2(base_x - 10, bottom - 3), Vector2(base_x + 10, bottom - 3), tip - Vector2(0, 5)])
	move_child(_speech_bubble, -1)


func _show_reaction(role: String, line: String, seconds: float) -> void:
	if is_instance_valid(_speech_bubble): _speech_bubble.queue_free()
	_speaking_card = null
	_speech_card_id = -1
	for card in _battle:
		if card is WarCardView and not card.face_down and WarCards.role_for_rank(int(card.card.get("rank", 0))) == role:
			_speaking_card = card
			_speech_card_id = int(card.card.get("id", -1))
			break
	var bubble := PanelContainer.new()
	bubble.name = "CharacterSpeech"
	bubble.position = Vector2(120, 850)
	bubble.custom_minimum_size = Vector2(480, 0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", UI.box(Color("#fffaf0"), 18, UI.ACCENT, 3))
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 18)
	bubble.add_child(margin)
	var text := Label.new()
	text.name = "Quote"
	text.custom_minimum_size.x = 438
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "“%s”" % line
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("font", UI.font(800))
	text.add_theme_font_size_override("font_size", 23)
	text.add_theme_color_override("font_color", UI.BG)
	margin.add_child(text)
	var tail := Polygon2D.new()
	tail.name = "Tail"
	tail.color = UI.ACCENT
	bubble.add_child(tail)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color("#fffaf0")
	tail.add_child(fill)
	add_child(bubble)
	_speech_bubble = bubble
	var tween := bubble.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tween.tween_callback(bubble.queue_free)


## The character whose card won a face-off, or "" (number cards don't talk).
static func _speaker(faceoff: Dictionary) -> String:
	var w := int(faceoff.get("winner", -1))
	if w < 0 or faceoff.get("ups", []).size() < 2 or faceoff["ups"][w] == null:
		return ""
	return WarCards.role_for_rank(int(faceoff["ups"][w]["rank"]))


func _round_over_war() -> void:
	if g.phase() == "over":
		_build_mode()
		return
	_main_btn.text = "On to the Piece round"
	_main_btn.add_theme_font_size_override("font_size", 32)
	if is_instance_valid(_side_btn):
		_side_btn.visible = false
	if g.last_faceoff.get("reason", "") == "unclaimed":
		_event.text = "A tie—but a deck is empty, so there are no cards for another war.\nThe tied cards are split evenly for Piece."
	else:
		_event.text = "War round complete. Your complete sets are banked.\nOn to Piece: group your cards and try a heist."


func _skip_war() -> void:
	if _busy or _animating:
		return
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
	_abort_war_quotes()
	_layer.set_meta("display_phase", "piece")
	_piece_start = g.events.size()
	_layer.add_child(UI.panel(Vector2(12, 218), Vector2(696, 776), Color("#e5e9e1"), 20))
	var status := Control.new()
	status.name = "PieceStatus"
	status.position = Vector2(28, 232)
	_layer.add_child(status)
	_hint = UI.label("", Vector2.ZERO, Vector2.ZERO, 22)
	_hint.visible = false
	_layer.add_child(_hint)
	var hs := ScrollContainer.new()
	hs.name = "Hand"
	hs.position = Vector2(24, 310)
	hs.size = Vector2(672, 530)
	hs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layer.add_child(hs)
	_layer.add_child(UI.panel(Vector2(24, 852), Vector2(672, 128), Color("#f5f5ee"), 12))
	var log := ScrollContainer.new()
	log.name = "PieceLog"
	log.position = Vector2(36, 862)
	log.size = Vector2(648, 108)
	log.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layer.add_child(log)

	# Retained as an internal compatibility hook for automated playthroughs.
	_lock_btn = Button.new()
	_lock_btn.visible = false
	_layer.add_child(_lock_btn)
	_main_btn = _btn("Ready for War", Vector2(36, 1126), Vector2(648, 112), UI.ACCENT, 34)
	_main_btn.pressed.connect(_done_piece)
	_sync_piece()


func _sync_piece() -> void:
	if g.phase() == "over":
		_build_mode()
		return
	var hs: ScrollContainer = _layer.get_node("Hand")
	for child in hs.get_children():
		hs.remove_child(child)
		child.queue_free()
	var groups := GridContainer.new()
	groups.columns = 3
	groups.add_theme_constant_override("h_separation", 12)
	groups.add_theme_constant_override("v_separation", 12)
	hs.add_child(groups)
	var ranks: Array = []
	for rank in range(2, 15):
		if g.hand(ME).any(func(c): return int(c["rank"]) == rank):
			ranks.append(rank)
	# Heist opportunities come first, then larger groups, then rank order.
	ranks.sort_custom(func(a, b):
		if g.can_heist(ME, a) != g.can_heist(ME, b): return g.can_heist(ME, a)
		var na: int = g.hand(ME).filter(func(c): return int(c["rank"]) == a).size()
		var nb: int = g.hand(ME).filter(func(c): return int(c["rank"]) == b).size()
		return na > nb if na != nb else a < b)
	for rank in ranks:
		groups.add_child(_rank_group(rank))
	if ranks.is_empty():
		var empty := UI.label("All your cards are banked.
Ready to see the result?", Vector2.ZERO, Vector2(650, 180), 28, Color("#27312e"), HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size = Vector2(650, 180)
		groups.add_child(empty)
	_sync_piece_avatars()
	_sync_piece_log()
	_play_shield_voice()
	var actor := g.piece_actor()
	_main_btn.disabled = false
	if actor < 0:
		_hint.text = "Heists complete. Your banked sets are safe."
		_main_btn.text = "Ready for War" if not g.piece_done[ME] else "Waiting for opponent…"
		_main_btn.disabled = g.piece_done[ME]
	else:
		_main_btn.text = ("Tap a stack for your heist" if not g.heist_options(ME).is_empty() else "No heist available · Continue") if actor == ME else "Opponent's turn…"
		_main_btn.disabled = actor != ME
	_sync_panels()
	if not _online and actor == BOT and not _bot_running:
		_run_computer.call_deferred()


func _sync_piece_log() -> void:
	var log: ScrollContainer = _layer.get_node("PieceLog")
	var entries: Array = [{"text": "Trailing player gets the first heist.", "kind": "intro"}]
	for event in g.events:
		if int(event.get("round", 0)) == g.round_number and event.get("kind", "") in ["heist_start", "heist", "shield", "pass", "lock"]:
			entries.append(event)
	if g.piece_actor() < 0: entries.append({"text": "Heists complete. Ready for War.", "kind": "done"})
	var signature := JSON.stringify(entries)
	if log.get_meta("entries", "") == signature: return
	log.set_meta("entries", signature)
	for child in log.get_children():
		log.remove_child(child)
		child.queue_free()
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 620
	list.add_theme_constant_override("separation", 8)
	log.add_child(list)
	for event in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := UI.label(str(event["text"]), Vector2.ZERO, Vector2.ZERO, 23, Color("#285746"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.y = 44
		row.add_child(label)
		var thumbnail: Control = null
		if event.get("kind", "") == "shield":
			thumbnail = UI.panel(Vector2.ZERO, Vector2(58, 82), Color("#faf7ed"), 6)
			var dev := TextureRect.new()
			dev.texture = load("res://art/role-bouncer.png")
			dev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			dev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dev.position = Vector2(4, 18)
			dev.size = Vector2(50, 60)
			thumbnail.add_child(dev)
			var shield := TextureRect.new()
			shield.texture = _symbol_texture("shield", true, Color("#b08718"))
			shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shield.position = Vector2(4, 2)
			shield.size = Vector2(20, 20)
			thumbnail.add_child(shield)
			thumbnail.tooltip_text = "Shield used"
		elif event.get("kind", "") == "heist":
			# Match canonical card names so existing saves and online logs also work.
			for card in WarCards.build_deck():
				if ("the " + WarCards.card_name(card) + ".") in str(event["text"]):
					var view := WarCardView.new()
					view.setup(card)
					thumbnail = view
					thumbnail.tooltip_text = WarCards.card_name(card)
					break
		elif event.get("kind", "") == "lock":
			for rank in range(2, 15):
				var suffix := " banked four " + WarCards.plural_rank(rank) + "."
				if not str(event["text"]).ends_with(suffix): continue
				var who := str(event["text"]).trim_suffix(suffix)
				var rank_text := (str(rank) + "'s") if rank <= 10 else WarCards.plural_rank(rank)
				label.text = who + " completed a set of " + rank_text + "."
				var set_icons := HBoxContainer.new()
				set_icons.add_theme_constant_override("separation", 4)
				for suit in ["S", "D", "C", "H"]:
					var card := WarCardView.new()
					card.setup({"rank": rank, "suit": suit})
					card.custom_minimum_size = Vector2(46, 65)
					card.size = Vector2(46, 65)
					card.mouse_filter = Control.MOUSE_FILTER_IGNORE
					set_icons.add_child(card)
				row.add_child(set_icons)
				break
		if thumbnail != null:
			thumbnail.custom_minimum_size = Vector2(58, 82)
			thumbnail.size = Vector2(58, 82)
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(thumbnail)
		list.add_child(row)
	_scroll_piece_log.call_deferred(log)


func _scroll_piece_log(log: ScrollContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(log): log.scroll_vertical = int(log.get_v_scroll_bar().max_value)


func _gray_portrait(node: CanvasItem) -> void:
	if _inactive_portrait_material == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){ float g = dot(COLOR.rgb, vec3(0.299,0.587,0.114)); COLOR = vec4(vec3(g), COLOR.a * 0.5); }"
		_inactive_portrait_material = ShaderMaterial.new()
		_inactive_portrait_material.shader = shader
	node.material = _inactive_portrait_material
	for child in node.get_children():
		if child is CanvasItem: _gray_portrait(child)


func _heist_avatar(p: int) -> Control:
	if p == ME:
		var avatar := AvatarView.new()
		avatar.role = Profile.me_slot
		avatar.data = Profile.face_or_default(Profile.me_slot)
		avatar.size = Vector2(56, 56)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return avatar
	if not _online and Opponents.display_name(g.nm(BOT)) in Opponents.NAMES:
		return Opponents.portrait(g.nm(BOT), Vector2.ZERO, Vector2(56, 56))
	var avatar := UI.panel(Vector2.ZERO, Vector2(56, 56), Color("#754553"), 28)
	avatar.add_child(UI.label(g.nm(BOT).left(1), Vector2.ZERO, Vector2(56, 56), 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return avatar


func _sync_piece_avatars() -> void:
	var status: Control = _layer.get_node("PieceStatus")
	for child in status.get_children():
		status.remove_child(child)
		child.queue_free()
	status.add_child(UI.label("Heists:", Vector2(0, 10), Vector2(82, 40), 22, Color("#27312e")))
	for i in g.heist_order.size():
		var avatar := _heist_avatar(int(g.heist_order[i]))
		avatar.name = "Heist%d" % i
		avatar.position = Vector2(88 + i * 70, 0)
		var complete := i < g.heist_step
		if not complete: _gray_portrait(avatar)
		if i == g.heist_step:
			var outline := UI.panel(avatar.position - Vector2(3, 3), Vector2(62, 62), Color.TRANSPARENT, 12)
			outline.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT, 12, Color("#b08718"), 2))
			status.add_child(outline)
		avatar.tooltip_text = "%s: %s" % ["You" if g.heist_order[i] == ME else g.nm(BOT), "heist used" if complete else ("current heist" if i == g.heist_step else "heist to come")]
		avatar.mouse_filter = Control.MOUSE_FILTER_PASS
		status.add_child(avatar)
	status.add_child(UI.label("Shields:", Vector2(366, 10), Vector2(100, 40), 22, Color("#27312e")))
	for i in 2:
		var dev := TextureRect.new()
		dev.name = "Shield%d" % i
		dev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dev.texture = load("res://art/role-bouncer.png")
		dev.position = Vector2(474 + i * 70, 0)
		dev.size = Vector2(56, 56)
		dev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i >= g.shields[ME]: _gray_portrait(dev)
		dev.tooltip_text = "Shield ready" if i < g.shields[ME] else "No shield in this slot"
		status.add_child(dev)


func _rank_group(rank: int) -> Control:
	var cards: Array = WarCards.sort_hand(g.hand(ME).filter(func(c): return int(c["rank"]) == rank))
	var can_steal := g.piece_actor() == ME and g.can_heist(ME, rank)
	var button := UI.button("", Vector2.ZERO, Vector2(210, 260), UI.BG, 22)
	button.name = "Rank%d" % rank
	button.custom_minimum_size = Vector2(210, 260)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, UI.box(Color("#dce3d8") if state in ["normal", "disabled"] else Color("#cedbc9"), 14, Color("#b6c4b4"), 2))
	button.accessibility_name = "%s, %d of four%s" % [WarCards.plural_rank(rank), cards.size(), ", steal available" if can_steal else ""]
	button.pressed.connect(_inspect_group.bind(rank))
	button.disabled = g.piece_actor() != ME
	for i in cards.size():
		var card := WarCardView.new()
		card.size = Vector2(138, 193)
		card.position = Vector2(14 + i * 17, 10 + i * 8)
		card.setup(cards[i])
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(card)
	var owned_suits: Array = ["S", "D", "C", "H"].filter(func(suit): return cards.any(func(c): return c["suit"] == suit))
	for i in owned_suits.size():
		var suit: String = owned_suits[i]
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = _symbol_texture(suit, true, Color("#c92e45") if suit in ["H", "D"] else Color("#202431"))
		icon.position = Vector2((210 - owned_suits.size() * 40) / 2.0 + i * 40, 222)
		icon.size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
	return button


func _inspect_group(rank: int) -> void:
	if _busy or g.piece_actor() != ME : return
	if is_instance_valid(_heist_picker):
		_heist_picker.get_parent().remove_child(_heist_picker)
		_heist_picker.queue_free()
	var stack: Control = _layer.get_node("Hand").get_child(0).get_node("Rank%d" % rank)
	var panel := UI.panel(Vector2.ZERO, Vector2(210, 260), Color("#f7f5e9"), 14)
	panel.name = "StackHeist"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_heist_picker = panel
	stack.add_child(panel)
	panel.add_child(UI.label("Steal...", Vector2(8, 8), Vector2(194, 38), 23, Color("#202431"), HORIZONTAL_ALIGNMENT_CENTER))
	var options := g.heist_options(ME, rank)
	if options.is_empty():
		panel.add_child(UI.label("No missing suit available from your opponent.", Vector2(12, 52), Vector2(186, 130), 22, Color("#202431"), HORIZONTAL_ALIGNMENT_CENTER))
	for i in options.size():
		var option: Dictionary = options[i]
		var pill_width := minf(150.0, (194.0 - (options.size() - 1) * 8.0) / options.size())
		var total_width := options.size() * pill_width + (options.size() - 1) * 8
		var choice := UI.button("", Vector2((210 - total_width) / 2 + i * (pill_width + 8), 50), Vector2(pill_width, 132), UI.ACCENT, 22)
		choice.name = "Suit" + str(option["suit"])
		choice.tooltip_text = "Steal " + WarCards.card_name(option)
		choice.accessibility_name = choice.tooltip_text
		for state in ["normal", "hover", "pressed", "focus"]:
			choice.add_theme_stylebox_override(state, UI.box(UI.ACCENT if state == "normal" else Color("#ffe28a"), 26))
		var card := WarCardView.new()
		var card_width := minf(80.0, pill_width - 12)
		card.size = Vector2(card_width, card_width * 1.4)
		card.position = (Vector2(pill_width, 132) - card.size) / 2
		card.setup(option)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(card)
		choice.pressed.connect(func():
			panel.queue_free()
			_heist_rank(rank, str(option["suit"])))
		panel.add_child(choice)
	var cancel := UI.button("Cancel", Vector2(8, 194), Vector2(194, 56), Color("#dce3d8"), 22)
	cancel.name = "Cancel"
	cancel.pressed.connect(panel.queue_free)
	panel.add_child(cancel)


func _inspect_rank_set(p: int, rank: int) -> void:
	for bank in g.sets(p):
		if int(bank[0]["rank"]) == rank:
			_inspect_banked(bank, p)
			return


func _symbol_texture(symbol: String, filled: bool, color: Color) -> Texture2D:
	var paths := {
		"H": "M16 27 C12 23 3 17 3 10 C3 2 12 1 16 8 C20 1 29 2 29 10 C29 17 20 23 16 27 Z",
		"D": "M16 2 L28 16 L16 30 L4 16 Z",
		"S": "M16 2 C12 7 3 12 3 19 C3 26 12 26 15 21 L11 30 L21 30 L17 21 C20 26 29 26 29 19 C29 12 20 7 16 2 Z",
		"C": "M13 20 C5 29 0 20 4 15 C6 12 10 12 12 14 C4 4 15 -2 20 4 C23 8 21 11 20 14 C29 8 33 20 26 24 C22 26 19 23 18 21 L21 30 L11 30 Z",
		"shield": "M16 2 L28 7 L27 18 Q25 26 16 30 Q7 26 5 18 L4 7 Z"
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><path d="%s" fill="%s" stroke="#%s" stroke-width="1.7" stroke-linejoin="round"/></svg>' % [paths[symbol], "#" + color.to_html(false) if filled else "none", color.to_html(false)]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


func _heist_rank(rank: int, suit := "") -> void:
	await _piece_action({"t": "heist", "p": ME, "rank": rank, "suit": suit})


func _piece_action(move: Dictionary) -> void:
	if _busy or g.phase() != "piece": return
	if _online:
		var sent := move.duplicate()
		sent.erase("p")
		if not await _online_move(sent): return
	elif not _do(move): return
	Sfx.play("tap")
	if g.phase() == "piece": _sync_piece()
	else: _build_mode()


func _play_shield_voice() -> void:
	var reaction := ""
	for i in range(_shield_voice_cursor, g.events.size()):
		var event: Dictionary = g.events[i]
		if int(event.get("p", -1)) != ME: continue
		match event.get("kind", ""):
			"heist":
				if reaction == "": reaction = "heist_success"
			"shield": reaction = "shield_block"
			"lock": reaction = "set_complete"
	_shield_voice_cursor = g.events.size()
	if reaction != "": _voices.react(reaction)


func _choose_heist() -> void:
	if _busy or g.piece_actor() != ME: return
	var options := g.heist_options(ME)
	if options.is_empty(): return
	var stack: Control = _layer.get_node("Hand").get_child(0).get_node("Rank%d" % int(options[0]["rank"]))
	_layer.get_node("Hand").ensure_control_visible(stack)
	_inspect_group(int(options[0]["rank"]))


func _run_computer() -> void:
	if _bot_running or _online or not is_inside_tree(): return
	_bot_running = true
	while g.phase() == "piece" and g.piece_actor() == BOT:
		_busy = true
		await get_tree().create_timer(1.3 if not _reduced_motion else 0.08).timeout
		var move := WarBot.next_move(g, BOT)
		_busy = false
		if move.is_empty() or not _do(move): break
		_sync_piece()
	_bot_running = false


func _inspect_banked(cards: Array, owner: int) -> void:
	var title := ("Your " if owner == ME else "Opponent's ") + WarCards.plural_rank(int(cards[0]["rank"]))
	var o := _overlay_box(title, "All four suits. This set is banked and cannot be stolen.", "Got it")
	for i in cards.size():
		var card := WarCardView.new()
		card.position = Vector2(80 + i * 145, 490)
		card.size = Vector2(125, 175)
		card.setup(cards[i])
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.add_child(card)


func _auto_arrange() -> void:
	if _busy: return
	var move := WarBot.next_move(g, ME)
	if not move.is_empty(): _piece_action(move)


func _done_piece() -> void:
	if _busy or g.phase() != "piece": return
	if g.piece_actor() == ME and g.pending_heist.is_empty():
		if g.heist_options(ME).is_empty(): await _piece_action({"t": "pass", "p": ME})
		else: _choose_heist()
		return
	if g.piece_actor() >= 0: return
	if not _online:
		g.apply({"t": "done", "p": BOT})
	await _piece_action({"t": "done", "p": ME})


## Online: you're done arranging; the other player isn't yet.
func _show_waiting() -> void:
	_sync_panels()
	var o := _overlay_box("Your sets are banked", "Waiting for %s to finish their Piece round.\n\nYou can leave this screen: the game will be waiting under Your games." % g.nm(BOT), "Back to Your games")
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


# ------------------------------------------------------------------ game over

func _animate_showdown() -> void:
	_busy = true
	var w: int = g.last_faceoff.winner
	var prize: Array = g.sets(w)[-1]   # the last set, which the showdown decides
	var tied: bool = g.sets(w).size() - 1 == g.sets(1 - w).size()
	var prize_name := WarCards.describe_set(prize)
	if prize_name == "":
		prize_name = "the last set"
	var stage := UI.panel(Vector2(24, 210), Vector2(672, 800), Color("#262d4d"), 24)
	_layer.add_child(stage)
	# Say why this round is happening.
	var title := UI.label("It's tied! Final showdown!" if tied else "One set left! Final showdown!", Vector2(16, 22), Vector2(640, 60), 38, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_override("font", UI.font(900))
	stage.add_child(title)
	if not _reduced_motion:
		title.pivot_offset = title.size / 2
		title.scale = Vector2(0.8, 0.8)
		var entrance := create_tween()
		entrance.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var message := UI.label("Five cards each. The highest total wins the last set.", Vector2(24, 84), Vector2(624, 70), 25, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(message)
	# Rows: the opponent on top (smaller cards), you at the bottom (bigger cards), like the table.
	var card_size := {BOT: Vector2(88, 123), ME: Vector2(114, 160)}
	var card_y := {BOT: 200.0, ME: 490.0}
	var score_y := {BOT: 156.0, ME: 446.0}
	var gap := {BOT: 14.0, ME: 12.0}
	var scores := {}
	for p in [BOT, ME]:
		var score := UI.label(("You" if p == ME else g.nm(BOT)) + " · 0", Vector2(28, score_y[p]), Vector2(616, 40), 28 if p == ME else 24, Color("#7cdbca") if p == ME else Color("#ffb399"), HORIZONTAL_ALIGNMENT_CENTER)
		score.add_theme_font_override("font", UI.font(800))
		stage.add_child(score)
		scores[p] = score
	# What's at stake, in the middle: the last set, named so it's clear why it's there.
	var stake := UI.label("Up for grabs: %s" % prize_name, Vector2(24, 338), Vector2(624, 34), 21, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stage.add_child(stake)
	var minis: Array = []
	var mini_w := 44.0
	var mini_left := 336.0 - (prize.size() * (mini_w + 8) - 8) / 2.0
	for j in prize.size():
		var small := WarCardView.new()
		small.size = Vector2(mini_w, 62)
		small.position = Vector2(mini_left + j * (mini_w + 8), 376)
		small.setup(prize[j])
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(small)
		minis.append(small)
	# The face-card values go under your cards.
	stage.add_child(UI.label("J = 11   Q = 12   K = 13   A = 14", Vector2(20, 664), Vector2(632, 36), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var action := UI.button("Reveal showdown cards", Vector2(36, 1126), Vector2(648, 112), UI.ACCENT, 30)
	action.name = "ShowdownReveal"
	_layer.add_child(action)
	var totals := [0, 0]
	var draws: Array = g.last_faceoff.cards
	for batch in int(draws[0].size() / 5):
		var cards: Array = [[], []]
		for p in [BOT, ME]:
			var sz: Vector2 = card_size[p]
			var left: float = 336.0 - (5 * sz.x + 4 * gap[p]) / 2.0
			for i in 5:
				var card := WarCardView.new()
				card.size = sz
				card.position = Vector2(left + i * (sz.x + gap[p]), card_y[p])
				card.pivot_offset = card.size / 2
				card.setup(draws[p][batch * 5 + i], true)
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stage.add_child(card)
				cards[p].append(card)
		action.text = "Reveal showdown cards" if batch == 0 else "Reveal five more cards"
		action.disabled = false
		await action.pressed
		action.disabled = true
		message.text = "Let the cards decide!"
		for i in 5:
			var flip := create_tween().set_parallel(true)
			for p in 2: flip.tween_property(cards[p][i], "scale:x", 1.0 if _reduced_motion else 0.02, 0.12)
			await flip.finished
			for p in 2:
				var data: Dictionary = draws[p][batch * 5 + i]
				cards[p][i].setup(data)
				totals[p] += int(data.rank)
				scores[p].text = ("You" if p == ME else g.nm(BOT)) + " · " + str(totals[p])
			var reveal := create_tween().set_parallel(true)
			for p in 2: reveal.tween_property(cards[p][i], "scale:x", 1.0, 0.18)
			await reveal.finished
			Sfx.play("wp_card_deal", -4.0)
			await get_tree().create_timer(0.12 if _reduced_motion else 0.3).timeout
		if batch < int(draws[0].size() / 5) - 1:
			message.text = "Still tied at %d! Five more cards each." % totals[0]
			await get_tree().create_timer(0.8).timeout
			for p in 2:
				for card in cards[p]: card.queue_free()
		else:
			message.text = ("You win" if w == ME else g.nm(BOT) + " wins") + " the showdown, %d to %d!" % [totals[w], totals[1 - w]]
			stake.text = "%s %s!" % ["You take" if w == ME else g.nm(BOT) + " takes", prize_name]
			for card in cards[w]:
				card.glow = true
				card.queue_redraw()
			for small in minis:
				small.glow = true
				small.queue_redraw()
			action.text = "See final results"
			action.disabled = false
			await action.pressed
	action.queue_free()
	stage.queue_free()
	_busy = false
	_show_game_over()


func _show_game_over() -> void:
	_voices.react("game_win" if g.winner == ME else "game_complete")
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
	var big := UI.label(title, Vector2(20, 170), Vector2(680, 130), 60, UI.ACCENT if g.winner != BOT else Color("#ff8a7a"), HORIZONTAL_ALIGNMENT_CENTER)
	big.add_theme_font_override("font", UI.font(900))
	o.add_child(big)
	var summary := "You completed %d sets and %s got %d." % [g.sets(ME).size(), g.nm(BOT), g.sets(BOT).size()]
	var why := UI.label(summary, Vector2(60, 285), Vector2(600, 110), 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	why.add_theme_font_override("font", UI.font(700))
	o.add_child(why)
	if not _online and g.nm(BOT) in Opponents.NAMES:
		var portrait := Opponents.portrait(g.nm(BOT), Vector2(285, 410), Vector2(150, 150))
		portrait.name = "OpponentReaction"
		portrait.pivot_offset = Vector2(75, 75)
		o.add_child(portrait)
		var reaction := "Victory dance!" if g.winner == BOT else ("You got me. Rematch?" if g.winner == ME else "A worthy match!")
		o.add_child(UI.label(reaction, Vector2(90, 565), Vector2(540, 50), 27, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		if not _reduced_motion:
			var dance := portrait.create_tween()
			if g.winner == BOT:
				for i in 3:
					dance.tween_property(portrait, "position:y", 382.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					dance.parallel().tween_property(portrait, "rotation", -0.12 if i % 2 == 0 else 0.12, 0.18)
					dance.tween_property(portrait, "position:y", 410.0, 0.22).set_trans(Tween.TRANS_BOUNCE)
				dance.tween_property(portrait, "rotation", 0.0, 0.15)
			else:
				dance.tween_property(portrait, "rotation", -0.18, 0.18)
				dance.tween_property(portrait, "rotation", 0.18, 0.18)
				dance.tween_property(portrait, "rotation", -0.12, 0.18)
				dance.tween_property(portrait, "rotation", 0.0, 0.18)
				dance.tween_property(portrait, "scale", Vector2(1.08, 0.86), 0.2)
				dance.tween_property(portrait, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		var best: Dictionary = {}
		if g.winner < 2:
			for bank in g.sets(g.winner):
				for card in bank:
					if best.is_empty() or card["rank"] > best["rank"]: best = card
		if not best.is_empty():
			var card := WarCardView.new()
			card.position = Vector2(300, 410)
			card.size = Vector2(120, 168)
			card.setup(best)
			o.add_child(card)
	var again := UI.button("Play again" if not _online else "Your games", Vector2(110, 1030), Vector2(500, 96), UI.ACCENT, 34)
	again.add_theme_font_override("font", UI.font(800))
	again.pressed.connect(func(): get_tree().reload_current_scene() if not _online else _leave())
	o.add_child(again)
	var menu := UI.button("Main menu", Vector2(110, 1140), Vector2(500, 80), Color("#2f3866"), 30)
	menu.add_theme_font_override("font", UI.font(800))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/main.tscn"))
	o.add_child(menu)
	if not _online:
		for i in Opponents.NAMES.size():
			var name: String = Opponents.NAMES[i]
			var won: bool = Opponents.beaten(name) or (g.winner == ME and name == g.nm(BOT))
			var column := i if i < 5 else i - 5
			var at := Vector2((50 if i < 5 else 112) + column * 124, 680 if i < 5 else 840)
			var face := Opponents.portrait(name, at + Vector2(22, 0), Vector2(76, 76))
			if not won: _gray_portrait(face)
			o.add_child(face)
			o.add_child(UI.label(name, at + Vector2(0, 80), Vector2(120, 32), 19, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			if won: o.add_child(Icon.make("check", at + Vector2(90, 52), Vector2(24, 24), Color("#49cf75")))
	_layer.add_child(o)
	_over = o


# ------------------------------------------------------------------ settings
func _show_settings() -> void:
	if _busy or _animating or _pumping or not _outbox.is_empty() or is_instance_valid(_settings):
		return
	_settings = _overlay_box("Game settings", "", "Keep playing")
	var o := _settings
	var sound := UI.button("Sound: On" if Profile.sound_on else "Sound: Off", Vector2(100, 370), Vector2(520, 68), Color("#2f3866"), 26)
	sound.pressed.connect(func():
		Profile.sound_on = not Profile.sound_on
		Sfx.enabled = Profile.sound_on
		Profile.save_profile()
		sound.text = "Sound: On" if Profile.sound_on else "Sound: Off")
	o.add_child(sound)
	var motion := UI.button("Reduced motion: On" if _reduced_motion else "Reduced motion: Off", Vector2(100, 450), Vector2(520, 68), Color("#2f3866"), 26)
	motion.pressed.connect(func():
		_reduced_motion = not _reduced_motion
		var preferences := ConfigFile.new()
		preferences.set_value("display", "reduced_motion", _reduced_motion)
		preferences.save("user://wp_preferences.cfg")
		motion.text = "Reduced motion: On" if _reduced_motion else "Reduced motion: Off")
	o.add_child(motion)
	var cards := UI.button("Personalize cards", Vector2(100, 530), Vector2(520, 68), Color("#7a4fd6"), 26)
	cards.pressed.connect(func():
		if _online:
			WarOnline.game_id = _game_id
			_online = false
		else:
			WarSave.save(g)
			WarSave.resume_next = true
		Profile.voice_game = "war_and_piece"
		Profile.creator_return = "res://games/war_and_piece/scenes/game.tscn"
		Profile.go("my_cards"))
	o.add_child(cards)
	var leave := UI.button("Save & leave", Vector2(100, 610), Vector2(520, 68), Color("#2f3866"), 26)
	leave.pressed.connect(_leave)
	o.add_child(leave)
	var end := UI.button("End game…", Vector2(100, 690), Vector2(520, 68), Color("#963d49"), 26)
	end.pressed.connect(func():
		o.queue_free()
		_confirm_end())
	o.add_child(end)


func _confirm_end() -> void:
	var o := _overlay_box("End this game?", "Your opponent will win. You can save and leave instead to continue later.", "Keep playing")
	_settings = o
	var end := UI.button("End game", Vector2(150, 700), Vector2(420, 80), Color("#963d49"), 28)
	end.pressed.connect(func():
		end.disabled = true
		if _online:
			var result := await WarOnline.call_fn(Online, "resign", {"game_id": _game_id})
			if not result["ok"]:
				end.text = "Try again"
				end.disabled = false
				return
		g.resign(ME)
		if not _online:
			WarSave.save(g)
		o.queue_free()
		_build_mode())
	o.add_child(end)


class MissingCard extends WarCardView:
	func _draw() -> void:
		draw_style_box(UI.box(Color("#1c233b"), 8), Rect2(Vector2.ZERO, size))
		draw_string(UI.font(700), Vector2(0, 28), "Missing", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UI.MUTED)
		draw_suit(card["suit"], Vector2(size.x * 0.5, 63), 12, Color("#9b9fb5"))
