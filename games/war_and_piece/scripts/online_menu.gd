extends Control
## Play Online: sign in, invite a friend (you confirm who joins), join with a code,
## find a player, and your list of games. Adapted from Gem Heist's online_menu.gd: the same
## accounts (shared Online autoload), but War and Piece's own server function (WarOnline).

const POLL := 3.0

var _body: Control
var _status: Label
var _flow := 0          # bumps whenever the screen changes, so old polling loops stop
var _overlay: Control
var _f_email: LineEdit
var _f_pw: LineEdit
var _f_first: LineEdit
var _f_code: LineEdit
var _signup := false
var _invite_code := ""


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The shared age screen comes first (asked once for all the games).
	if not AgeGate.known():
		AgeGate.require(self, "Online play", func(): get_tree().reload_current_scene(), func(): get_tree().change_scene_to_file("res://games/war_and_piece/scenes/main.tscn"), true)
		return
	var back := Button.new()
	back.position = Vector2(20, 24)
	back.size = Vector2(68, 68)
	back.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	back.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	back.pressed.connect(_back)
	back.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(back)
	add_child(UI.label("Play Online", Vector2(0, 30), Vector2(720, 56), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't cover the back arrow
	add_child(_body)
	_status = UI.label("", Vector2(40, 1190), Vector2(640, 70), 20, Color("#ff9f8f"), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	if Online.signed_in():
		_show_home()
	else:
		_show_signin()


func _back() -> void:
	_flow += 1
	Online.cancel_sign_in()
	get_tree().change_scene_to_file("res://games/war_and_piece/scenes/main.tscn")


# ------------------------------------------------------------------ helpers

func _reset() -> int:
	_flow += 1
	_close_overlay()
	for c in _body.get_children():
		c.queue_free()
	_status.text = ""
	return _flow


func _add(n: Control) -> Control:
	_body.add_child(n)
	return n


func _text(t: String, y: float, fs := 24, color := UI.TEXT, h := 40.0) -> Label:
	return _add(UI.label(t, Vector2(50, y), Vector2(620, h), fs, color, HORIZONTAL_ALIGNMENT_CENTER))


func _button(t: String, y: float, color: Color, cb: Callable, h := 80.0, fs := 28, font_color := Color.WHITE) -> Button:
	var b := UI.button(t, Vector2(110, y), Vector2(500, h), color, fs)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_hover_color", font_color)
	b.pressed.connect(cb)
	_add(b)
	return b


func _field(placeholder: String, y: float, secret := false, value := "") -> LineEdit:
	var e := LineEdit.new()
	e.position = Vector2(110, y)
	e.size = Vector2(500, 70)
	e.placeholder_text = placeholder
	e.text = value
	e.secret = secret
	e.add_theme_font_size_override("font_size", 28)
	e.add_theme_stylebox_override("normal", UI.box(Color("#f4f1ea"), 12))
	e.add_theme_stylebox_override("focus", UI.box(Color("#ffffff"), 12, UI.ACCENT, 3))
	e.add_theme_color_override("font_color", Color("#1b2038"))
	e.add_theme_color_override("font_placeholder_color", Color("#8a8fa8"))
	_add(e)
	return e


func _busy(on: bool, text := "") -> void:
	for c in _body.get_children():
		if c is Button:
			c.disabled = on
	if text != "":
		_status.add_theme_color_override("font_color", UI.MUTED)
		_status.text = text


func _error(t: String) -> void:
	_busy(false)
	_status.add_theme_color_override("font_color", Color("#ff9f8f"))
	_status.text = t


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _open_game(id: String) -> void:
	_flow += 1
	WarOnline.game_id = id
	get_tree().change_scene_to_file("res://games/war_and_piece/scenes/game.tscn")


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


# ------------------------------------------------------------------ sign in

func _show_signin() -> void:
	if AgeGate.kid():
		_show_kid_signin()
		return
	_reset()
	_text("Play friends and family, or find a new rival.", 130, 26)
	_text("Opponents see your first name. Your photos and voice recordings stay on this phone. Already play Gem Heist? Use the same sign-in.", 176, 20, UI.MUTED, 60)
	_button("Continue with Apple", 270, Color("#000000"), _oauth.bind("apple"))
	_button("Continue with Google", 366, Color("#ffffff"), _oauth.bind("google"), 80, 28, Color("#1f1f1f"))
	_button("Continue with Facebook", 462, Color("#1877f2"), _oauth.bind("facebook"))
	_button("Use email", 558, Color("#3a4166"), _show_email.bind(false))
	_add(UI.panel(Vector2(110, 676), Vector2(500, 2), Color("#3a4166"), 1))
	_text("Got an invite code from a friend?", 700, 24)
	_button("Join a friend's game", 750, UI.ACCENT, _show_join, 80, 28, Color("#1b2038"))
	_text("No account needed to join a friend.", 840, 18, UI.MUTED)


# ------------------------------------------------------------------ under 13

## The nickname this phone plays under (picked once, can be re-rolled before signing in).
func _kid_nickname() -> String:
	if not Nicknames.valid(Profile.nickname):
		Profile.nickname = Nicknames.random()
		Profile.save_profile()
	return Profile.nickname


func _show_kid_signin() -> void:
	_reset()
	_text("Play with friends and family", 130, 30, UI.ACCENT)
	_text("You'll play online with a nickname. Your name, photos and voice stay on this phone.", 180, 20, UI.MUTED, 60)
	_text("Your nickname", 286, 22, UI.MUTED)
	var nick := _text(_kid_nickname(), 322, 44, UI.TEXT, 64)
	nick.add_theme_font_override("font", UI.font(900))
	_button("New nickname", 404, Color("#3a4166"), func():
		Profile.nickname = Nicknames.random()
		Profile.save_profile()
		nick.text = Profile.nickname, 64, 22)
	_button("Start playing", 520, UI.ACCENT, _kid_start, 84, 30, Color("#1b2038"))
	_add(UI.panel(Vector2(110, 650), Vector2(500, 2), Color("#3a4166"), 1))
	_text("Got an invite code from a friend?", 674, 24)
	_button("Join a friend's game", 724, Color("#4c8dff"), _show_join, 80, 28)
	_text("You can play friends who share a code with you. There's no chat.", 820, 18, UI.MUTED, 60)


func _kid_start() -> void:
	_busy(true, "Getting ready…")
	var err := await Online.sign_in_guest(_kid_nickname())
	if err != "":
		_error(err)
		return
	_show_home()


func _oauth(provider: String) -> void:
	var flow := _reset()
	_text("Finish signing in in your browser,", 300, 28)
	_text("then come back here.", 344, 28)
	_button("Cancel", 460, Color("#3a4166"), _cancel_oauth)
	var err := await Online.sign_in_with(provider)
	if flow != _flow:
		return
	if err == "":
		_show_home()
	elif err != "CANCELLED":
		_show_signin()
		_error(err)


func _cancel_oauth() -> void:
	Online.cancel_sign_in()
	_show_signin()


func _show_email(signup: bool) -> void:
	_reset()
	_text("Create your account" if signup else "Sign in with email", 140, 30, UI.ACCENT)
	_signup = signup
	var y := 210.0
	_f_first = null
	if signup:
		_f_first = _field("First name", y, false, Profile.display_name)
		_f_first.max_length = 16
		y += 90
	_f_email = _field("Email", y)
	_f_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_f_pw = _field("Password (6+ characters)", y + 90, true)
	_button("Create account" if signup else "Sign in", y + 200, UI.ACCENT, _submit_email, 80, 28, Color("#1b2038"))
	_button("I'm new: create an account" if not signup else "I already have an account", y + 300, Color("#3a4166"), _show_email.bind(not signup), 70, 22)
	_button("Back", y + 390, Color("#2f3866"), _show_signin, 70, 22)


func _submit_email() -> void:
	_busy(true, "One moment…")
	var err := ""
	if _signup:
		err = await Online.sign_up_email(_f_email.text, _f_pw.text, _f_first.text)
	else:
		err = await Online.sign_in_email(_f_email.text, _f_pw.text)
	if err == "CONFIRM":
		_show_email(false)
		_status.add_theme_color_override("font_color", UI.MUTED)
		_status.text = "Check your email and tap the link, then sign in here."
	elif err != "":
		_error(err)
	else:
		_show_home()


# ------------------------------------------------------------------ home

func _show_home() -> void:
	var flow := _reset()
	await Online.refresh_profile()
	if flow != _flow:
		return
	if Online.signed_in() and not Online.kid_session_ok():
		await Online.sign_out()
		if flow != _flow:
			return
	if not Online.signed_in():
		_show_signin()
		return
	# Use the nickname from this phone if the account doesn't have a first name yet.
	if Online.name_or("") == "" and Profile.display_name != "" and not AgeGate.kid():
		await Online.set_display_name(Profile.display_name)
	_text("Hi, %s!" % Online.name_or("there"), 120, 32, UI.TEXT, 48)
	_button("Invite a friend", 190, UI.ACCENT, _show_invite, 84, 30, Color("#1b2038"))
	_button("Join with a code", 290, Color("#4c8dff"), _show_join, 76)
	if not AgeGate.kid():   # under 13: friends only, never strangers
		_button("Find a player", 382, Color("#3cb97a"), _show_find, 76)
	_text("YOUR GAMES", 486, 20, UI.MUTED, 30)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 524)
	scroll.size = Vector2(600, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.custom_minimum_size = Vector2(600, 0)
	scroll.add_child(list)
	_add(scroll)
	var loading := UI.label("Loading…", Vector2.ZERO, Vector2(600, 40), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	list.add_child(loading)
	if Online.is_guest() and not AgeGate.kid():
		_text("Playing as a guest. Sign in on the website later to keep your games.", 1100, 18, UI.MUTED, 60)
	var r := await WarOnline.call_fn(Online, "my_games")
	if flow != _flow:
		return
	loading.queue_free()
	if not r["ok"]:
		_error(r["error"])
		return
	var games: Array = r["data"].get("games", [])
	if games.is_empty():
		list.add_child(UI.label("No games yet. Invite a friend or find a player!", Vector2.ZERO, Vector2(600, 60), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for gm in games:
		var label := "vs %s" % gm["opponent"]
		var note := ""
		var color := Color("#2f3866")
		if gm["status"] == "active":
			if str(gm.get("phase", "")) == "war":
				note = "Round %d · War" % int(gm.get("round", 1))
			else:
				note = "Round %d · %s" % [int(gm.get("round", 2)), "Your Piece round!" if gm["my_turn"] else "Waiting on them"]
			if gm["my_turn"]:
				color = Color("#4a3d14")
			var lk: Array = gm.get("locked", [0, 0])
			note += "  ·  %d–%d" % [int(lk[0]), int(lk[1])]
		else:
			note = "You won" if gm["won"] == true else ("You lost" if gm["won"] == false else "Draw")
		var b := UI.button("%s   ·   %s" % [label, note], Vector2.ZERO, Vector2(600, 72), color, 24)
		b.custom_minimum_size = Vector2(600, 72)
		b.pressed.connect(_open_game.bind(str(gm["game_id"])))
		list.add_child(b)


# ------------------------------------------------------------------ invite a friend

func _show_invite() -> void:
	var flow := _reset()
	_text("Invite a friend", 130, 32, UI.ACCENT)
	_busy(true, "Making your code…")
	var r := await WarOnline.call_fn(Online, "create_invite")
	if flow != _flow:
		return
	if not r["ok"]:
		_show_home()
		_error(r["error"])
		return
	_busy(false)
	_status.text = ""
	var code: String = r["data"]["code"]
	_text("Your code", 200, 22, UI.MUTED)
	var big := _text(" ".join(code.split("")), 236, 72, UI.ACCENT, 96)
	big.add_theme_constant_override("outline_size", 0)
	_invite_code = code
	_button("Copy code", 350, Color("#4c8dff"), _copy_code, 70, 24)
	_text("Tell them: open War and Piece, tap Play Online, then Join a friend's game, and enter this code.", 440, 22, UI.TEXT, 70)
	var waiting := _text("Waiting for your friend to enter it…", 540, 22, UI.MUTED)
	_button("Cancel invite", 1060, Color("#3a4166"), _cancel_invite, 70, 22)
	while flow == _flow:
		await _wait(POLL)
		if flow != _flow:
			return
		var s := await WarOnline.call_fn(Online, "invite_status", {"code": code})
		if flow != _flow or not s["ok"]:
			continue
		if s["data"]["status"] == "pending":
			waiting.text = "%s entered your code." % s["data"]["guest_name"]
			var yes: bool = await _confirm_guest(str(s["data"]["guest_name"]))
			if flow != _flow:
				return
			var rr := await WarOnline.call_fn(Online, "respond_invite", {"code": code, "accept": yes})
			if not rr["ok"]:
				_error(rr["error"])
				continue
			if yes:
				_open_game(str(rr["data"]["game_id"]))
				return
			waiting.text = "Waiting for your friend to enter it…"


func _copy_code() -> void:
	DisplayServer.clipboard_set("Play War and Piece with me! Open the app, tap Play Online, then Join a friend's game, and enter code %s" % _invite_code)
	_status.add_theme_color_override("font_color", UI.MUTED)
	_status.text = "Copied. Paste it into a text to your friend."


func _cancel_invite() -> void:
	WarOnline.call_fn(Online, "cancel_invite", {"code": _invite_code})
	_show_home()


## The host decides whether the person who entered the code joins.
func _confirm_guest(guest_name: String) -> bool:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	_overlay.add_child(UI.panel(Vector2(60, 380), Vector2(600, 420), UI.PANEL, 22))
	_overlay.add_child(UI.label("%s wants to join" % guest_name, Vector2(80, 420), Vector2(560, 50), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_overlay.add_child(UI.label("Should %s join your game?" % guest_name, Vector2(80, 490), Vector2(560, 80), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_answer = -1
	var yes := UI.button("Yes, let's play!", Vector2(110, 600), Vector2(500, 80), UI.ACCENT, 28)
	yes.add_theme_color_override("font_color", Color("#1b2038"))
	yes.pressed.connect(_set_answer.bind(1))
	_overlay.add_child(yes)
	var no := UI.button("No, that's not who I invited", Vector2(110, 696), Vector2(500, 70), Color("#3a4166"), 22)
	no.pressed.connect(_set_answer.bind(0))
	_overlay.add_child(no)
	add_child(_overlay)
	while _answer < 0 and is_inside_tree():
		await get_tree().process_frame
	_close_overlay()
	return _answer == 1


var _answer := -1

func _set_answer(a: int) -> void:
	_answer = a


# ------------------------------------------------------------------ join with a code

func _show_join() -> void:
	_reset()
	_text("Join a friend's game", 130, 32, UI.ACCENT)
	_text("Enter the code your friend sent you.", 190, 22, UI.MUTED)
	_f_code = _field("Invite code", 250)
	_f_code.max_length = 8
	_f_code.text_changed.connect(_upper_code)
	if AgeGate.kid():
		# Under 13: a nickname from our list, never typed.
		_f_first = _field("Nickname", 340, false, Online.name_or(_kid_nickname()) if Online.signed_in() else _kid_nickname())
		_f_first.editable = false
	else:
		_f_first = _field("Your first name", 340, false, Online.name_or(Profile.display_name))
		_f_first.max_length = 16
	_button("Join", 450, UI.ACCENT, _submit_join, 80, 30, Color("#1b2038"))
	_button("Back", 550, Color("#3a4166"), (_show_home if Online.signed_in() else _show_signin), 70, 22)


func _upper_code(t: String) -> void:
	var up := t.to_upper()
	if up != t:
		_f_code.text = up
		_f_code.caret_column = up.length()


func _submit_join() -> void:
	_join(_f_code.text, _f_first.text)


func _join(code: String, first_name: String) -> void:
	code = code.strip_edges().to_upper()
	first_name = first_name.strip_edges()
	if code.length() < 6:
		_error("Codes are 6 letters and numbers.")
		return
	if first_name == "":
		_error("Please enter your first name.")
		return
	_busy(true, "Joining…")
	if not Online.signed_in():
		var err := await Online.sign_in_guest(first_name)
		if err != "":
			_error(err)
			return
	var r := await WarOnline.call_fn(Online, "join_invite", {"code": code, "name": first_name})
	if not r["ok"]:
		_error(r["error"])
		return
	if Profile.display_name == "" and not AgeGate.kid():
		Profile.display_name = first_name
		Profile.save_profile()
	var host: String = r["data"].get("host_name", "your friend")
	var flow := _reset()
	_text("Almost there!", 300, 34, UI.ACCENT)
	_text("Waiting for %s to let you in…" % host, 370, 26, UI.TEXT, 80)
	_button("Cancel", 600, Color("#3a4166"), _show_join, 70, 22)
	while flow == _flow:
		await _wait(POLL)
		if flow != _flow:
			return
		var s := await WarOnline.call_fn(Online, "invite_status", {"code": code})
		if flow != _flow:
			return
		if not s["ok"]:
			# The host said no (the code was reopened for someone else).
			_show_join()
			_error("%s didn't let this one through. Double-check the code with them." % host)
			return
		if s["data"]["status"] == "accepted" and s["data"].get("game_id") != null:
			_open_game(str(s["data"]["game_id"]))
			return


# ------------------------------------------------------------------ find a player

func _show_find() -> void:
	var flow := _reset()
	_text("Finding a player…", 200, 34, UI.ACCENT)
	var info := _text("Looking for someone who's ready to play.", 260, 24, UI.MUTED, 70)
	var r := await WarOnline.call_fn(Online, "find_match")
	if flow != _flow:
		return
	if not r["ok"]:
		_show_home()
		_error(r["error"])
		return
	if r["data"].get("game_id") != null:
		_open_game(str(r["data"]["game_id"]))
		return
	var offered := false
	var started := Time.get_ticks_msec()
	_button("Stop looking", 1060, Color("#3a4166"), _stop_looking, 70, 22)
	while flow == _flow:
		await _wait(POLL)
		if flow != _flow:
			return
		var s := await WarOnline.call_fn(Online, "match_status")
		if flow != _flow:
			return
		if s["ok"] and s["data"].get("game_id") != null:
			_open_game(str(s["data"]["game_id"]))
			return
		if not offered and Time.get_ticks_msec() - started > 8000:
			offered = true
			info.text = "No one's free right now. We'll keep looking, and your match will show up under Your games."
			_text("Or play the Computer while you wait.", 720, 24, UI.TEXT)
			_button("Play the Computer", 780, UI.ACCENT, _play_computer, 80, 28, Color("#1b2038"))
			_text("This stops the search for a person.", 872, 18, UI.MUTED)


func _stop_looking() -> void:
	WarOnline.call_fn(Online, "cancel_match")
	_show_home()


func _play_computer() -> void:
	WarOnline.call_fn(Online, "cancel_match")
	_flow += 1
	WarSave.resume_next = WarSave.has_game()
	get_tree().change_scene_to_file("res://games/war_and_piece/scenes/game.tscn")
