extends Node
## Online play: accounts (Supabase Auth) and the Gem Heist server function.
## Autoloaded as "Online". Everything here is async: callers `await` the results.
##
## Every server call returns {"ok": bool, "data": Variant, "error": String}.

const URL := "https://ktomoljsvbpftptwqcqy.supabase.co"
const KEY := "sb_publishable_6yFIuxGaYiili79iym-pbQ_Xi4gYTR9"  # public by design; safe to ship
const FN := "/functions/v1/gem-heist"
const RELAY := "/functions/v1/auth-relay"
const SESSION_PATH := "user://session.json"

var server := URL               # tests point this at a local stand-in via YAC_SERVER
var session: Dictionary = {}   # access_token, refresh_token, expires_at, user_id, is_anonymous, email
var me: Dictionary = {}        # server profile: display_name, is_guest
var game_id := ""              # set just before opening the game scene for an online game
var pending_character := -1    # CAST index to play when no human is free (cycles through the cast)


func _ready() -> void:
	if OS.get_environment("YAC_SERVER") != "":
		server = OS.get_environment("YAC_SERVER")
		return  # tests start signed out
	_load_session()


func signed_in() -> bool:
	return session.has("access_token")


func is_guest() -> bool:
	return bool(session.get("is_anonymous", false))


func name_or(fallback: String) -> String:
	var n := str(me.get("display_name", ""))
	return n if n != "" and n != "Player" else fallback


# ------------------------------------------------------------------ HTTP

func _http(method: int, path: String, body: Variant = null, use_session := true) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	var headers := PackedStringArray(["apikey: " + KEY, "Content-Type: application/json"])
	if use_session and signed_in():
		headers.append("Authorization: Bearer " + str(session["access_token"]))
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(server + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "Couldn't reach the server. Check your internet connection."}
	var res: Array = await req.request_completed
	req.queue_free()
	var status: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "error": "Couldn't reach the server. Check your internet connection."}
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "data": data, "error": ""}
	var msg := "Something went wrong (%d)." % status
	if typeof(data) == TYPE_DICTIONARY:
		for k in ["error", "msg", "message", "error_description"]:
			if data.has(k) and typeof(data[k]) == TYPE_STRING:
				msg = data[k]
				break
	return {"ok": false, "status": status, "data": data, "error": _friendly(msg)}


func _friendly(msg: String) -> String:
	var m := msg.to_lower()
	if m.contains("invalid login"):
		return "That email and password don't match."
	if m.contains("email not confirmed"):
		return "Check your email and tap the confirmation link first."
	if m.contains("already registered"):
		return "That email already has an account. Try signing in."
	if m.contains("anonymous sign-ins are disabled"):
		return "Guest play isn't switched on yet. Ask the game's owner, or sign in instead."
	if m.contains("password should be"):
		return "Passwords need at least 6 characters."
	return msg


## Call the Gem Heist server. Refreshes the sign-in first if it's about to expire.
func call_fn(action: String, payload: Dictionary = {}) -> Dictionary:
	if not signed_in():
		return {"ok": false, "data": null, "error": "Please sign in first."}
	await _ensure_fresh()
	var body := payload.duplicate()
	body["action"] = action
	var r := await _http(HTTPClient.METHOD_POST, FN, body)
	if r["status"] == 401:
		# Expired or deleted account: try one refresh, then give up.
		if await _refresh():
			r = await _http(HTTPClient.METHOD_POST, FN, body)
	return r


# ------------------------------------------------------------------ cartoons

## Turn a photo into a cartoon portrait for a card (Gemini, via our server).
## kind: "me" / "person" or "pet". Returns {"ok", "image": Image, "error"}.
## The photo is only sent to make the cartoon; neither is stored on the server.
func cartoonize(photo: Image, kind: String, role: String) -> Dictionary:
	return await _cartoon_request(photo, {"kind": "pet" if kind == "pet" else "person", "role": role})


## "Change the look": redraws a card's cartoon with options from our own lists.
func cartoon_edit(picture: Image, kind: String, edits: Dictionary) -> Dictionary:
	return await _cartoon_request(picture, {"kind": "pet" if kind == "pet" else "person", "mode": "edit", "edits": edits})


## A private id for this phone or browser (only used for the daily cartoon limit).
## Browsers have no device id, so a random one is made once and kept.
func device_id() -> String:
	var id := OS.get_unique_id()
	if id == "":
		var f := FileAccess.open("user://device_id.txt", FileAccess.READ)
		if f != null:
			id = f.get_as_text().strip_edges()
		if id == "":
			id = "%d_%d" % [randi(), Time.get_ticks_usec()]
			var w := FileAccess.open("user://device_id.txt", FileAccess.WRITE)
			if w != null:
				w.store_string(id)
	return id.sha256_text().substr(0, 32)


func _cartoon_request(photo: Image, extra: Dictionary) -> Dictionary:
	var img := photo.duplicate() as Image
	var longest := maxi(img.get_width(), img.get_height())
	if longest > 1024:
		var k := 1024.0 / longest
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RGB8 and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var body := {"image": Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.88)), "mime": "image/jpeg",
		"device": device_id()}
	body.merge(extra)
	var req := HTTPRequest.new()
	req.timeout = 90.0
	add_child(req)
	var headers := PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY, "Content-Type: application/json"])
	var err := req.request(server + "/functions/v1/cartoonize", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "Couldn't reach the cartoon maker. Check your internet connection."}
	var res: Array = await req.request_completed
	req.queue_free()
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Couldn't reach the cartoon maker. Check your internet connection."}
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "The cartoon maker didn't answer. Please try again."}
	if not data.has("image"):
		return {"ok": false, "error": str(data.get("error", "Couldn't make a cartoon. Please try again."))}
	var bytes := Marshalls.base64_to_raw(str(data["image"]))
	var out := Image.new()
	var ok := out.load_png_from_buffer(bytes) if str(data.get("mime", "")) == "image/png" else out.load_jpg_from_buffer(bytes)
	if ok != OK:
		ok = out.load_png_from_buffer(bytes)
		if ok != OK:
			ok = out.load_jpg_from_buffer(bytes)
	if ok != OK or out.is_empty():
		return {"ok": false, "error": "The cartoon came back damaged. Please try again."}
	return {"ok": true, "image": out, "error": ""}


# ------------------------------------------------------------------ accounts

func sign_up_email(email: String, password: String, first_name: String) -> String:
	var r := await _http(HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": email.strip_edges(), "password": password, "data": {"display_name": first_name.strip_edges()}}, false)
	if not r["ok"]:
		return r["error"]
	if typeof(r["data"]) == TYPE_DICTIONARY and r["data"].has("access_token"):
		_store(r["data"])
		await refresh_profile()
		return ""
	return "CONFIRM"  # account made; email confirmation is switched on


func sign_in_email(email: String, password: String) -> String:
	var r := await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password}, false)
	if not r["ok"]:
		return r["error"]
	_store(r["data"])
	await refresh_profile()
	return ""


## A quick guest account for someone joining with an invite code.
func sign_in_guest(first_name: String) -> String:
	var r := await _http(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {"display_name": first_name}}, false)
	if not r["ok"]:
		return r["error"]
	_store(r["data"])
	await refresh_profile()
	return ""


## Apple, Google or Facebook: opens the browser, then waits for the sign-in to come back.
## The browser lands on our relay page, which holds the one-time code for this phone.
var _oauth_cancel := false

func sign_in_with(provider: String) -> String:
	_oauth_cancel = false
	var verifier := _random_token(48)
	var challenge := Marshalls.raw_to_base64(verifier.sha256_buffer()).replace("+", "-").replace("/", "_").replace("=", "")
	var lid := _random_token(24)
	var back := server + RELAY + "?lid=" + lid
	var url := "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		server, provider, back.uri_encode(), challenge]
	OS.shell_open(url)
	# Wait up to 5 minutes for the player to finish in the browser.
	for i in 150:
		if _oauth_cancel:
			return "CANCELLED"
		await get_tree().create_timer(2.0).timeout
		var r := await _http(HTTPClient.METHOD_GET, RELAY + "?poll=" + lid, null, false)
		if r["ok"] and typeof(r["data"]) == TYPE_DICTIONARY and str(r["data"].get("code", "")) != "":
			var t := await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=pkce",
				{"auth_code": r["data"]["code"], "code_verifier": verifier}, false)
			if not t["ok"]:
				return t["error"]
			_store(t["data"])
			await refresh_profile()
			return ""
	return "Sign-in timed out. Please try again."


func cancel_sign_in() -> void:
	_oauth_cancel = true


func refresh_profile() -> void:
	var r := await call_fn("me")
	if r["ok"]:
		me = r["data"].get("profile", {})
		# Keep the local nickname and the online name in step.
		if Profile.display_name == "" and name_or("") != "":
			Profile.display_name = name_or("")
			Profile.save_profile()


func set_display_name(n: String) -> String:
	var r := await call_fn("update_profile", {"display_name": n})
	if r["ok"]:
		me = r["data"].get("profile", me)
	return r["error"]


func sign_out() -> void:
	if signed_in():
		await _http(HTTPClient.METHOD_POST, "/auth/v1/logout", {})
	_clear()


func delete_account() -> String:
	var r := await call_fn("delete_account")
	if not r["ok"]:
		return r["error"]
	_clear()
	return ""


# ------------------------------------------------------------------ session storage

func _store(data: Dictionary) -> void:
	var user: Dictionary = data.get("user", {}) if typeof(data.get("user")) == TYPE_DICTIONARY else {}
	session = {
		"access_token": data.get("access_token", ""),
		"refresh_token": data.get("refresh_token", ""),
		"expires_at": Time.get_unix_time_from_system() + float(data.get("expires_in", 3600)),
		"user_id": user.get("id", ""),
		"is_anonymous": bool(user.get("is_anonymous", false)),
		"email": str(user.get("email", "")) if user.get("email") != null else "",
	}
	_save_session()


func _ensure_fresh() -> void:
	if signed_in() and float(session.get("expires_at", 0)) - Time.get_unix_time_from_system() < 120:
		await _refresh()


func _refresh() -> bool:
	if not session.has("refresh_token"):
		return false
	var r := await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": session["refresh_token"]}, false)
	if not r["ok"]:
		if r["status"] >= 400 and r["status"] < 500:
			_clear()  # the sign-in is no longer valid (e.g. account deleted)
		return false
	_store(r["data"])
	return true


func _clear() -> void:
	session = {}
	me = {}
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(session))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(data) == TYPE_DICTIONARY and data.has("access_token"):
		session = data


func _random_token(n: int) -> String:
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(n)
	var out := ""
	for b in bytes:
		out += chars[b % chars.length()]
	return out
