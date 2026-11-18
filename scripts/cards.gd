class_name CardDB
extends RefCounted
## Card definitions for You're a Card. 90 cards: 29 gems, 20 bills, 41 actions.
## (In code, gems are still called "treasures" and bills "money"/"loot".)

const COLORS := ["ruby", "emerald", "sapphire", "topaz", "diamond", "amethyst"]

const TREASURES := {
	"ruby":     {"name": "Rubies",     "one": "Ruby",      "size": 2, "count": 4, "tint": Color("#e0344a")},
	"emerald":  {"name": "Emeralds",   "one": "Emerald",   "size": 3, "count": 5, "tint": Color("#25a55f")},
	"sapphire": {"name": "Sapphires",  "one": "Sapphire",  "size": 3, "count": 5, "tint": Color("#2f6fe0")},
	"topaz":    {"name": "Topazes",    "one": "Topaz",     "size": 3, "count": 5, "tint": Color("#f2b630")},
	"diamond":  {"name": "Diamonds",   "one": "Diamond",   "size": 3, "count": 5, "tint": Color("#a9c8dc")},
	"amethyst": {"name": "Amethysts",  "one": "Amethyst",  "size": 3, "count": 5, "tint": Color("#8e4fd6")},
}

const ACTIONS := {
	"wild":      {"name": "Wild", "type": "wild",  "count": 2, "role": "you",         "text": "Counts as any gem"},
	"swipe":     {"name": "Heist",          "type": "heist", "count": 7, "role": "pickpocket",  "text": "Take 1 gem from a set they haven't finished"},
	"swap":      {"name": "Trade",          "type": "heist", "count": 4, "role": "trickster",   "text": "Trade one of your gems for one of theirs"},
	"shakedown": {"name": "Shakedown",      "type": "heist", "count": 4, "role": "boss",        "text": "Take a random card from their hand"},
	"grand":     {"name": "Grand Heist",    "type": "heist", "count": 2, "role": "mastermind",  "text": "Take ALL the gems in one of their finished sets"},
	"payup":     {"name": "Pay Up!",        "type": "heist", "count": 4, "role": "boss",        "text": "They pay you 2 bills (or gems, if they have no bills)"},
	"shield":    {"name": "Shield",         "type": "trap",  "count": 5, "role": "bouncer",     "text": "Defense: blocks an action"},
	"mirror":    {"name": "Mirror",         "type": "trap",  "count": 3, "role": "illusionist", "text": "Defense: bounces an action back"},
	"snare":     {"name": "Snare",          "type": "trap",  "count": 2, "role": "trapper",     "text": "Defense: blocks an action and you keep their card"},
	"lockpick":  {"name": "Lockpick",       "type": "tool",  "count": 4, "role": "locksmith",   "text": "Steal a random card from their vault"},
	"lucky":     {"name": "Lucky Break",    "type": "tool",  "count": 4, "role": "",            "text": "Draw 2 cards"},
	"loot1":     {"name": "1 Bill",          "type": "money", "count": 6, "role": "",            "text": "Bank it to pay for Heists"},
	"loot2":     {"name": "2 Bills",        "type": "money", "count": 5, "role": "",            "text": "Bank it to pay for Heists"},
	"loot3":     {"name": "3 Bills",            "type": "money", "count": 4, "role": "",            "text": "Bank it to pay for Heists"},
	"loot4":     {"name": "4 Bills",            "type": "money", "count": 3, "role": "",            "text": "Bank it to pay for Heists"},
	"loot5":     {"name": "5 Bills",         "type": "money", "count": 2, "role": "",            "text": "Bank it to pay for Heists"},
	# Kept last so every other card keeps its id. Plays itself the moment it's drawn.
	"windfall":  {"name": "Windfall",       "type": "tool",  "count": 2, "role": "",            "text": "You \"found\" up to 10 bills from the discard pile"},
	"doublecross": {"name": "Double Crossed", "type": "tool", "count": 2, "role": "",           "text": "Someone stole up to 10 bills from your bank"},
}

## Windfall: the most bills (by value) it can take from the discard pile.
## Double Crossed: the most bills it can take from your bank.
const WINDFALL_CAP := 10

## Bills each card costs to play, paid automatically from your bank.
const COSTS := {"swipe": 2, "swap": 1, "shakedown": 1, "grand": 5, "lockpick": 2}
const CRITTERS := {"loot1": "mouse", "loot2": "raccoon", "loot3": "fox", "loot4": "owl", "loot5": "magpie"}

const ROLE_TITLES := {
	"you": "You", "pickpocket": "The Pickpocket", "trickster": "The Trickster", "boss": "The Boss",
	"mastermind": "The Mastermind", "bouncer": "The Bouncer", "illusionist": "The Illusionist",
	"trapper": "The Trapper", "locksmith": "The Locksmith",
}
const ROLES := ["you", "pickpocket", "trickster", "boss", "mastermind", "bouncer", "illusionist", "trapper", "locksmith"]

const HEISTS := ["swipe", "swap", "shakedown", "grand", "payup"]

## What a card type is called on the card and in menus.
static func type_label(typ: String) -> String:
	match typ:
		"heist": return "ACTION"
		"trap": return "DEFENSE"
	return typ.to_upper()
const TRAPS := ["shield", "mirror", "snare"]

const TYPE_COLORS := {
	"heist": Color("#ff7a59"), "trap": Color("#4c8dff"), "tool": Color("#3cb97a"), "wild": Color("#ffc83d"),
	"money": Color("#c8794a"),
}


static func is_treasure(kind: String) -> bool:
	return TREASURES.has(kind)


static func card_type(kind: String) -> String:
	if TREASURES.has(kind):
		return "treasure"
	return ACTIONS.get(kind, {"type": "hidden"})["type"]


static func display_name(kind: String) -> String:
	if TREASURES.has(kind):
		return TREASURES[kind]["name"]
	return ACTIONS.get(kind, {"name": "a card"})["name"]  # "hidden": an online opponent's card


static func one_name(color: String) -> String:
	return TREASURES[color]["one"]


static func role_of(kind: String) -> String:
	if ACTIONS.has(kind):
		return ACTIONS[kind]["role"]
	return ""


## "1 bill", "3 bills": every player-facing amount goes through here.
static func bills(n: int) -> String:
	return "%d bill%s" % [n, "" if n == 1 else "s"]


## The customizable slot that a card's face comes from ("you", "bill3", "bouncer"...).
static func slot_for(kind: String) -> String:
	if CRITTERS.has(kind):
		return "bill" + kind.substr(4)
	return role_of(kind)


static func is_money(kind: String) -> bool:
	return CRITTERS.has(kind)


## What a gem is worth if you pawn it into your bank instead of collecting it.
const PAWN := {"ruby": 2, "diamond": 2}


static func pawn_value(kind: String) -> int:
	return PAWN.get(kind, 1) if is_treasure(kind) else 0


## Bill value of a card sitting in a bank (bills, or gems that were pawned).
static func value(kind: String) -> int:
	if CRITTERS.has(kind):
		return int(kind.substr(4))
	return pawn_value(kind)


static func cost(kind: String) -> int:
	return COSTS.get(kind, 0)


static func set_size(color: String) -> int:
	return TREASURES[color]["size"]


static func tint(color: String) -> Color:
	return TREASURES[color]["tint"]


static func build_deck() -> Array:
	var deck: Array = []
	var next_id := 1
	for color in COLORS:
		for i in TREASURES[color]["count"]:
			deck.append({"id": next_id, "kind": color})
			next_id += 1
	for kind in ACTIONS.keys():
		for i in ACTIONS[kind]["count"]:
			deck.append({"id": next_id, "kind": kind})
			next_id += 1
	return deck
