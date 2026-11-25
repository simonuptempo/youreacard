extends SceneTree
## Kid-safe online play against a local server (YAC_SERVER). FN env: the function path.
## Checks the app refuses grown-up sign-ins and typed names for under-13s, and that the
## server itself refuses strangers and typed names for a kid account.
var fails := 0

func check(what: String, cond: bool) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	await process_frame
	var P = root.get_node("Profile")
	var O = root.get_node("Online")
	var fn := OS.get_environment("FN")
	P.birth_year = 2016; P.birth_month = 3
	check("email sign-in refused", (await O.sign_in_email("a@b.c", "pw123456")) != "")
	check("Google sign-in refused", (await O.sign_in_with("google")) != "")
	check("typed name refused", (await O.sign_in_guest("Simon")) != "")
	check("nickname guest sign-in works", (await O.sign_in_guest("Sneaky Fox")) == "")
	await O.refresh_profile()
	check("server marked the account kid", bool(O.me.get("kid", false)))
	check("kid session ok", O.kid_session_ok())
	var r: Dictionary = await O._http(HTTPClient.METHOD_POST, fn, {"action": "find_match"})
	check("app refuses find_match", not r["ok"])
	# Pretend the app check was bypassed: the server must still say no.
	P.birth_year = 1990
	r = await O._http(HTTPClient.METHOD_POST, fn, {"action": "find_match"})
	check("server refuses find_match for a kid account", not r["ok"] and r["status"] == 403)
	r = await O._http(HTTPClient.METHOD_POST, fn, {"action": "update_profile", "display_name": "Bob Smith"})
	check("server refuses a typed name for a kid account", not r["ok"])
	r = await O._http(HTTPClient.METHOD_POST, fn, {"action": "update_profile", "display_name": "Lucky Otter"})
	check("server accepts another nickname", r["ok"])
	r = await O._http(HTTPClient.METHOD_POST, fn, {"action": "create_invite"})
	check("kid can make an invite code", r["ok"])
	# Leave no kid birthday saved on this machine for the other tests.
	P.birth_year = 0; P.birth_month = 0; P.save_profile()
	O.sign_out()
	print("KID ONLINE ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
