class_name WarSave
extends RefCounted
## The game against the Computer is saved after every move, so closing the app (even
## swiping it away) never loses it. The menu offers Continue while one is saved.

const PATH := "user://war_game.json"
const VERSION := 1

## Set by the menu just before opening the table: pick up the saved game.
static var resume_next := false


static func save(g: WarState) -> void:
	if g.winner >= 0:
		if g.winner == 0:
			preload("res://games/war_and_piece/scripts/war_opponents.gd").record_win(g.nm(1))
		clear()
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"v": VERSION, "saved_at": int(Time.get_unix_time_from_system()), "state": g.to_dict()}))


## The saved game, or null if there isn't one (or it can't be read).
static func load_game() -> WarState:
	if not FileAccess.file_exists(PATH):
		return null
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return null
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != VERSION or typeof(data.get("state")) != TYPE_DICTIONARY:
		return null
	var g := WarState.from_dict(data["state"])
	if g.winner >= 0 or g.total_cards() != WarCards.DECK_SIZE:
		return null
	var old_name := g.nm(1)
	var new_name: String = preload("res://games/war_and_piece/scripts/war_opponents.gd").display_name(old_name)
	if old_name != new_name:
		g.players[1]["name"] = new_name
		for event in g.events:
			for key in ["text", "text1"]:
				event[key] = str(event.get(key, "")).replace(old_name, new_name)
	return g


static func has_game() -> bool:
	return load_game() != null


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## One line for the Continue button: "Round 5 · War · sets 3 to 2".
static func describe(g: WarState) -> String:
	return "Round %d · %s · sets %d to %d" % [g.round_number, "War" if g.phase() == "war" else "Piece", g.sets(0).size(), g.sets(1).size()]
