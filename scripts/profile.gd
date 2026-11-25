extends Node
## Autoload "Profile": the player's customized cards, settings, and the default cast.

const SAVE_PATH := "user://profile.json"

## Customizable card "slots". Each holds {"avatar": {...}, "name": "..."} once customized;
## anything missing uses its default (the cast character, or the bill's critter).
const SLOTS := ["you", "bill1", "bill2", "bill3", "bill4", "bill5",
	"pickpocket", "trickster", "boss", "mastermind", "bouncer", "illusionist", "trapper", "locksmith"]
const CRITTER_NAMES := {"bill1": "Mouse", "bill2": "Raccoon", "bill3": "Fox", "bill4": "Owl", "bill5": "Magpie"}
var slots: Dictionary = {}
var edit_slot := "you"                 # which slot the avatar creator is editing
var plays_per_turn := 3
var sound_on := true
var voices := "sometimes"     # how often characters speak: often | sometimes | off
var voice_alt := {}           # slot -> true: your card speaks in the character's other voice
var onboarded := false
var display_name := ""
var birth_year := 0              # asked once by AgeGate (stays on this phone); 0 = not asked
var birth_month := 0
var nickname := ""                # under 13: the online nickname picked from Nicknames
var me_slot := "you"            # the card you are: the Wild by default, or any crew card or bill
var beaten: Array = []           # names of characters you have beaten (cycles you through the cast)

## Navigation hints (not saved): where the avatar creator / explainer return to,
## and which onboarding step to show.
var creator_via_crew := false     # Create on the crew screen: the builder returns there
var creator_return := "main"       # where the crew screen (my_cards) goes back to: main | settings | onboarding | explainer
var creator_mode := ""         # open the card maker on "photo", "builder" or "gallery"
var photo_kind := "me"          # whose photo: "me", "pet" or "person" (a friend or family member)
var settings_return := "home"     # home | main: where Settings goes back to
var explainer_return := "main"     # main | onboarding | settings
var explainer_start := 0           # step to open the tutorial on (e.g. back from editing your Wild)
var onboarding_step := 0
var practice_requested := false  # One-shot navigation flag; never saved.
var rematch_first := -1           # set by Rematch: the loser of the last game starts (not saved)
var rematch_cast := -1            # keeps the same opponent for a rematch

## Default cast: one character per role, used when the player hasn't made an avatar,
## and as the bot opponents' identities.
const CAST := [
	{"role": "you", "name": "Nana Bea", "avatar": {"skin": 10, "face": 0, "eyes": 5, "eye_color": 0, "brows": 1, "nose": 2, "mouth": 1, "hair": 8, "hair_color": 11, "facial": 0, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 1, "ears": 3, "shirt": 3, "shirt_color": 8, "details": ["smile_lines"]}},
	{"role": "pickpocket", "name": "Pip", "avatar": {"skin": 6, "face": 0, "eyes": 0, "eye_color": 2, "brows": 0, "nose": 0, "mouth": 2, "hair": 7, "hair_color": 4, "facial": 0, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 0, "shirt": 1, "shirt_color": 1, "details": ["freckles"]}},
	{"role": "trickster", "name": "Juno", "avatar": {"skin": 13, "face": 1, "eyes": 1, "eye_color": 0, "brows": 3, "nose": 0, "mouth": 0, "hair": 11, "hair_color": 0, "facial": 0, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 4, "shirt": 0, "shirt_color": 4, "details": ["vitiligo"]}},
	{"role": "boss", "name": "Lou", "avatar": {"skin": 2, "face": 2, "eyes": 3, "eye_color": 4, "brows": 5, "nose": 1, "mouth": 4, "hair": 17, "hair_color": 10, "facial": 2, "head": 4, "head_color": 6, "hat": 0, "hat_color": 0, "eyewear": 1, "ears": 1, "shirt": 2, "shirt_color": 9, "details": ["smile_lines"]}},
	{"role": "mastermind", "name": "Amara", "avatar": {"skin": 11, "face": 1, "eyes": 1, "eye_color": 1, "brows": 3, "nose": 0, "mouth": 0, "hair": 6, "hair_color": 0, "facial": 0, "head": 1, "head_color": 4, "hat": 0, "hat_color": 0, "eyewear": 3, "ears": 0, "shirt": 3, "shirt_color": 6, "details": ["makeup"]}},
	{"role": "bouncer", "name": "Dev", "avatar": {"skin": 8, "face": 2, "eyes": 0, "eye_color": 0, "brows": 2, "nose": 1, "mouth": 4, "hair": 2, "hair_color": 0, "facial": 4, "head": 2, "head_color": 6, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 0, "shirt": 0, "shirt_color": 11, "details": []}},
	{"role": "illusionist", "name": "Mei", "avatar": {"skin": 1, "face": 3, "eyes": 2, "eye_color": 0, "brows": 1, "nose": 0, "mouth": 0, "hair": 15, "hair_color": 0, "facial": 0, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 3, "shirt": 3, "shirt_color": 7, "details": ["makeup", "rosy"]}},
	{"role": "trapper", "name": "Rosa", "avatar": {"skin": 5, "face": 0, "eyes": 4, "eye_color": 3, "brows": 0, "nose": 0, "mouth": 1, "hair": 5, "hair_color": 4, "facial": 0, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 1, "shirt": 4, "shirt_color": 5, "details": ["rosy"]}},
	{"role": "locksmith", "name": "Kodi", "avatar": {"skin": 14, "face": 2, "eyes": 0, "eye_color": 0, "brows": 2, "nose": 2, "mouth": 1, "hair": 4, "hair_color": 0, "facial": 3, "head": 0, "head_color": 0, "hat": 0, "hat_color": 0, "eyewear": 0, "ears": 3, "shirt": 5, "shirt_color": 3, "details": []}},
]


func _ready() -> void:
	load_profile()


func cast_for_role(role: String) -> Dictionary:
	for c in CAST:
		if c["role"] == role:
			return c
	return CAST[0]


# ------------------------------------------------------------------ slots

func is_custom(slot: String) -> bool:
	return slots.has(slot)


## The customized avatar for a slot, or {} if it uses its default.
func slot_face(slot: String) -> Dictionary:
	if slots.has(slot):
		return slots[slot]["avatar"]
	return {}


## Default face for a slot: the cast character for "you" and roles; {} for bills (critter).
func default_face(slot: String) -> Dictionary:
	if slot.begins_with("bill"):
		return {}
	return cast_for_role(slot)["avatar"]


## Custom face if set, otherwise the default. Always non-empty for people slots.
func face_or_default(slot: String) -> Dictionary:
	var f := slot_face(slot)
	return f if not f.is_empty() else default_face(slot)


## The name shown with a face: the player's label, or the default character/critter name.
func face_name(slot: String) -> String:
	if slots.has(slot) and str(slots[slot].get("name", "")) != "":
		return slots[slot]["name"]
	if slot == me_slot and slots.has(slot):
		return display_name if display_name != "" else "You"
	if CRITTER_NAMES.has(slot):
		return CRITTER_NAMES[slot]
	return cast_for_role(slot)["name"]


## The card kind that shows a slot's face: "wild", "loot3", or the crew character's action.
func slot_kind(slot: String) -> String:
	if slot == "you":
		return "wild"
	if slot.begins_with("bill"):
		return "loot" + slot.substr(4)
	for k in CardDB.ACTIONS.keys():
		if CardDB.ACTIONS[k]["role"] == slot:
			return k
	return "wild"


## Your card, ready for a CardView: setup(me_card(), me_face()).
func me_card() -> Dictionary:
	return {"id": 0, "kind": slot_kind(me_slot)}


func me_face() -> Dictionary:
	return slot_face(me_slot)


## Until your card has your photo, menus show it as "This could be you!" to invite you in.
func me_placeholder() -> bool:
	return not is_custom(me_slot) and not me_slot.begins_with("bill")


## Your picture during a game: your card's face, or its character art.
## You're none of the cards until you put yourself on one, so until then: a plain outline.
func me_portrait() -> Dictionary:
	if is_custom(me_slot):
		var face := slot_face(me_slot)
		if not face.is_empty():
			return face
	return {"silhouette": true}


## What the slot is, for screen titles.
func slot_title(slot: String) -> String:
	if slot == "you":
		return "Your You're a Card! card"
	if slot.begins_with("bill"):
		var v := int(slot.substr(4))
		return "The %d-bill" % v
	return CardDB.ROLE_TITLES.get(slot, slot)


func set_slot(slot: String, avatar: Dictionary, label: String) -> void:
	slots[slot] = {"avatar": AvatarView.normalized(avatar), "name": label.strip_edges()}
	save_profile()


func clear_slot(slot: String) -> void:
	slots.erase(slot)
	save_profile()


func custom_count() -> int:
	return slots.size()


# ------------------------------------------------------------------ save / load

func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"slots": slots, "plays_v3": plays_per_turn,
		"onboarded": onboarded, "display_name": display_name, "beaten": beaten, "sound_on": sound_on,
		"voices": voices, "voice_alt": voice_alt, "me_slot": me_slot,
		"birth_year": birth_year, "birth_month": birth_month, "nickname": nickname}))


func load_profile() -> void:
	slots = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	if typeof(data.get("slots")) == TYPE_DICTIONARY:
		for k in data["slots"].keys():
			var v = data["slots"][k]
			if str(k) in SLOTS and typeof(v) == TYPE_DICTIONARY and typeof(v.get("avatar")) == TYPE_DICTIONARY:
				slots[str(k)] = {"avatar": AvatarView.normalized(v["avatar"]), "name": str(v.get("name", ""))}
	elif bool(data.get("has_custom", false)) and typeof(data.get("avatar")) == TYPE_DICTIONARY:
		# Older saves had one avatar: it becomes your You're a Card! face.
		slots["you"] = {"avatar": AvatarView.normalized(data["avatar"]), "name": ""}
	plays_per_turn = int(data.get("plays_v3", 3))
	onboarded = bool(data.get("onboarded", false))
	display_name = str(data.get("display_name", ""))
	me_slot = str(data.get("me_slot", "you"))
	birth_year = int(data.get("birth_year", 0))
	birth_month = int(data.get("birth_month", 0))
	nickname = str(data.get("nickname", ""))
	if not me_slot in SLOTS:
		me_slot = "you"
	sound_on = bool(data.get("sound_on", true))
	voices = str(data.get("voices", "sometimes"))
	if not voices in ["often", "sometimes", "off"]:
		voices = "sometimes"
	voice_alt = data["voice_alt"] if typeof(data.get("voice_alt")) == TYPE_DICTIONARY else {}
	beaten = []
	if typeof(data.get("beaten")) == TYPE_ARRAY:
		for n in data["beaten"]:
			beaten.append(str(n))


func mark_beaten(character: String) -> void:
	if not character in beaten:
		beaten.append(character)
		save_profile()


## The next character to take on: the first one you haven't beaten yet. After you've
## beaten everyone, it starts over (a fresh run, so the cycle keeps going).
func next_character() -> int:
	for i in range(1, CAST.size()):
		if not CAST[i]["name"] in beaten:
			return i
	beaten = []
	save_profile()
	return 1


# ------------------------------------------------------------------ game in progress
# A game against a character is saved after every move, so closing the app (even
# swiping it away) never loses it. Online games live on the server; we just remember
# which one was open.

const GAME_SAVE := "user://saved_game.json"
var resume_game := false      # the game screen should pick up the saved game
var launch_checked := false   # reopen the last game only once, when the app starts


const ONLINE_SAVE := "user://open_online_game.json"


func save_game(data: Dictionary, path := GAME_SAVE) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func saved_game(path := GAME_SAVE) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f != null else null
	return data if typeof(data) == TYPE_DICTIONARY else {}


func clear_saved_game(path := GAME_SAVE) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func go(scene: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


## Opponent identity for previews (explainer, onboarding).
func rival() -> Dictionary:
	return CAST[2]
