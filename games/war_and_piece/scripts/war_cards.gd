class_name WarCards
## The deck and the set rules for War and Piece.
## A card is {"id": int, "rank": 2..14 (Ace high), "suit": "S"/"H"/"D"/"C"}.

const SUITS := ["S", "H", "D", "C"]
const SUIT_NAMES := {"S": "Spades", "H": "Hearts", "D": "Diamonds", "C": "Clubs"}
const SUIT_SYMBOLS := {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}
const RED := ["H", "D"]
const DECK_SIZE := 52
const WIN_LOCKED := 30
const MIN_SET := 3
const WAR_DOWN := 3      # a tie: 3 cards face-down, then 1 face-up (four each)

## Face cards and Aces are characters you can put your own face on.
const FACE_RANKS := [11, 12, 13, 14]
const CHARACTERS := {
	11: {"name": "Pip", "title": "the Jack of all Trades", "role": "pickpocket"},
	12: {"name": "Juno", "title": "the Queen of Hearts", "role": "trickster"},
	13: {"name": "Lou", "title": "the King of the Hill", "role": "boss"},
	14: {"name": "Amara", "title": "the Ace in the Hole", "role": "mastermind"},
}


## The character on a rank (11 Jack … 14 Ace), or "" for number cards.
static func role_for_rank(rank: int) -> String:
	return str(CHARACTERS.get(rank, {}).get("role", ""))


static func build_deck() -> Array:
	var deck: Array = []
	var id := 1
	for s in SUITS:
		for r in range(2, 15):
			deck.append({"id": id, "rank": r, "suit": s})
			id += 1
	return deck


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


static func plural_rank(r: int) -> String:
	return rank_name(r) + "s"


static func card_name(c: Dictionary) -> String:
	return "%s of %s" % [rank_name(c["rank"]), SUIT_NAMES[c["suit"]]]


static func short(c: Dictionary) -> String:
	return rank_short(c["rank"]) + SUIT_SYMBOLS[c["suit"]]


static func is_red(c: Dictionary) -> bool:
	return c["suit"] in RED


## "kind" (3+ of the same rank), "run" (3+ in a row, one suit; Aces high) or "" if not a set.
static func set_type(cards: Array) -> String:
	if cards.size() < MIN_SET:
		return ""
	var r: int = cards[0]["rank"]
	var same_rank := true
	for c in cards:
		if c["rank"] != r:
			same_rank = false
	if same_rank:
		return "kind"
	var s: String = cards[0]["suit"]
	var ranks: Array = []
	for c in cards:
		if c["suit"] != s:
			return ""
		ranks.append(c["rank"])
	ranks.sort()
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i - 1] + 1:
			return ""
	return "run"


static func describe_set(cards: Array) -> String:
	var t := set_type(cards)
	if t == "kind":
		return "%s %s" % [count_word(cards.size()), plural_rank(cards[0]["rank"])]
	if t == "run":
		var ranks: Array = cards.map(func(c): return c["rank"])
		ranks.sort()
		return "%s to %s of %s" % [rank_short(ranks[0]), rank_short(ranks[-1]), SUIT_NAMES[cards[0]["suit"]]]
	return ""


static func sort_hand(cards: Array) -> Array:
	var out := cards.duplicate()
	out.sort_custom(func(a, b):
		if a["rank"] != b["rank"]:
			return a["rank"] < b["rank"]
		return SUITS.find(a["suit"]) < SUITS.find(b["suit"]))
	return out


static func count_word(n: int) -> String:
	var w := ["", "one", "two", "three", "four"]
	return w[n] if n < w.size() else str(n)
