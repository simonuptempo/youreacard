class_name SSCards
## The deck for See Saw: a standard 52-card deck.
## A card is {"id": int, "rank": 2..14 (Ace high), "suit": "S"/"H"/"D"/"C"}.

const SUITS := ["S", "H", "D", "C"]
const SUIT_NAMES := {"S": "Spades", "H": "Hearts", "D": "Diamonds", "C": "Clubs"}
const SUIT_ONE := {"S": "Spade", "H": "Heart", "D": "Diamond", "C": "Club"}
const RED := ["H", "D"]

## Every rank has a You're a Card character on it (13 of the 14 cards in My Cards).
## "role" is the shared Profile slot, so a face you put on that character shows here too.
const FACE_RANKS := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const CHARACTERS := {
	2: {"name": "Mouse", "role": "bill1"},
	3: {"name": "Raccoon", "role": "bill2"},
	4: {"name": "Fox", "role": "bill3"},
	5: {"name": "Owl", "role": "bill4"},
	6: {"name": "Magpie", "role": "bill5"},
	7: {"name": "Dev", "role": "bouncer"},
	8: {"name": "Mei", "role": "illusionist"},
	9: {"name": "Rosa", "role": "trapper"},
	10: {"name": "Kodi", "role": "locksmith"},
	11: {"name": "Pip", "title": "the Jack of all Trades", "role": "pickpocket"},
	12: {"name": "Juno", "title": "the Queen of Hearts", "role": "trickster"},
	13: {"name": "Nana Bea", "title": "the King of the Hill", "role": "you"},
	14: {"name": "Amara", "title": "the Ace in the Hole", "role": "mastermind"},
}
## The 14th card: Lou's counterweight. You earn one for clearing level 4 and every
## level after it, and it goes on your side of the seesaw as an extra life.
const COUNTERWEIGHT := {"counterweight": true, "id": 99, "name": "Lou", "role": "boss"}


## The card each My Cards slot shows in See Saw (a Spade of its rank, or the counterweight).
static func card_for_slot(slot: String) -> Dictionary:
	if slot == COUNTERWEIGHT["role"]:
		return COUNTERWEIGHT.duplicate()
	for r in CHARACTERS:
		if CHARACTERS[r]["role"] == slot:
			return make(r, "S")
	return {}


## My Cards order in See Saw: 2 … Ace, then the counterweight.
static func slot_order() -> Array:
	var out: Array = []
	for r in FACE_RANKS:
		out.append(CHARACTERS[r]["role"])
	out.append(COUNTERWEIGHT["role"])
	return out


static func build_deck() -> Array:
	var deck: Array = []
	var id := 1
	for s in SUITS:
		for r in range(2, 15):
			deck.append({"id": id, "rank": r, "suit": s})
			id += 1
	return deck


static func make(rank: int, suit: String) -> Dictionary:
	return {"id": SUITS.find(suit) * 13 + rank - 1, "rank": rank, "suit": suit}


static func rank_name(r: int) -> String:
	match r:
		11: return "Jack"
		12: return "Queen"
		13: return "King"
		14: return "Ace"
	return str(r)


static func rank_short(r: int) -> String:
	match r:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
	return str(r)


static func card_name(c: Dictionary) -> String:
	return "%s of %s" % [rank_name(c["rank"]), SUIT_NAMES[c["suit"]]]


static func is_red(c: Dictionary) -> bool:
	return c["suit"] in RED


static func is_face(c: Dictionary) -> bool:
	return int(c["rank"]) in FACE_RANKS


static func character(c: Dictionary) -> Dictionary:
	return CHARACTERS.get(int(c["rank"]), {})


static func same(a: Dictionary, b: Dictionary) -> bool:
	return a["rank"] == b["rank"] and a["suit"] == b["suit"]


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]
