class_name WarOnline
extends RefCounted
## War and Piece's own server function, called with the shared sign-in (the Online autoload).
## Kept here so the shared online.gd doesn't change: same retry-once-on-401 as Online.call_fn.

const FN := "/functions/v1/war-and-piece"

## The online game the table should open (set just before going to the game scene).
static var game_id := ""


## online: the Online autoload. Returns {"ok", "status", "data", "error"} like Online.call_fn.
static func call_fn(online: Node, action: String, payload: Dictionary = {}) -> Dictionary:
	if not online.signed_in():
		return {"ok": false, "status": 0, "data": null, "error": "Please sign in first."}
	await online._ensure_fresh()
	var body := payload.duplicate()
	body["action"] = action
	var r: Dictionary = await online._http(HTTPClient.METHOD_POST, FN, body)
	if r["status"] == 401 and await online._refresh():
		r = await online._http(HTTPClient.METHOD_POST, FN, body)
	return r
