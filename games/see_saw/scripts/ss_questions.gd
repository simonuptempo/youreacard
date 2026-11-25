class_name SSQuestions
## Makes the multiple-choice questions asked after the cards are hidden.
##
## A question is a Dictionary:
##   kind     what is being asked (see KINDS)
##   text     the question shown to the player
##   style    how options are drawn: card, suit, rank, color, yesno, character, number, position
##   options  the option values (a card, a suit letter, a rank, true/false, a position...)
##   labels   a readable label for each option
##   answer   index of the right option
## plus whatever the kind needs (pos, prop, card), so is_correct() can check any
## option against the shown cards without trusting the answer index.

## kind -> [smallest number of cards it needs, weight on easy levels (1-4), weight later]
const KINDS := {
	"nth_card": [1, 3, 4],
	"nth_suit": [1, 2, 2],
	"nth_rank": [1, 2, 2],
	"nth_color": [1, 1, 0],
	"yes_no": [1, 2, 1],
	"character": [1, 3, 2],
	"which_shown": [2, 2, 2],
	"not_shown": [2, 2, 3],
	"extreme": [2, 1, 2],
	"where": [3, 0, 3],
	"count": [3, 0, 2],
}


static func questions_for_level(level: int) -> int:
	return 2 if level <= 2 else 3


## Questions for one round. Never asks the same kind twice in a round.
static func make_round(cards: Array, level: int, rng: RandomNumberGenerator, count := -1) -> Array:
	if count < 0:
		count = questions_for_level(level)
	var out: Array = []
	var used := {}
	var tries := 0
	while out.size() < count and tries < 60:
		tries += 1
		var kind := _pick_kind(cards, level, rng, used)
		if kind == "":
			used.clear()  # every kind used: allow repeats
			continue
		used[kind] = true
		# "Who was on it?" and "What rank was it?" can give the same answer away.
		if kind in ["character", "nth_rank"]:
			used["character"] = true
			used["nth_rank"] = true
		var q := make(kind, cards, rng)
		if not q.is_empty():
			out.append(q)
	return out


static func _pick_kind(cards: Array, level: int, rng: RandomNumberGenerator, used: Dictionary) -> String:
	var n := cards.size()
	var pool: Array = []
	var total := 0
	for k in KINDS:
		var spec: Array = KINDS[k]
		var w: int = spec[1] if level <= 4 else spec[2]
		if n < spec[0] or w <= 0 or used.has(k):
			continue
		if k == "character" and _face_positions(cards).is_empty():
			continue
		pool.append([k, w])
		total += w
	if total == 0:
		return ""
	var roll := rng.randi_range(1, total)
	for e in pool:
		roll -= e[1]
		if roll <= 0:
			return e[0]
	return pool[-1][0]


static func make(kind: String, cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var q: Dictionary
	match kind:
		"nth_card": q = _nth_card(cards, rng)
		"nth_suit": q = _nth_suit(cards, rng)
		"nth_rank": q = _nth_rank(cards, rng)
		"nth_color": q = _nth_color(cards, rng)
		"yes_no": q = _yes_no(cards, rng)
		"character": q = _character(cards, rng)
		"which_shown": q = _which_shown(cards, rng)
		"not_shown": q = _not_shown(cards, rng)
		"extreme": q = _extreme(cards, rng)
		"where": q = _where(cards, rng)
		"count": q = _count(cards, rng)
	if q.is_empty():
		return q
	q["kind"] = kind
	_shuffle_options(q, rng)
	return q


## Is this option value the right answer, judged from the shown cards alone?
static func is_correct(q: Dictionary, cards: Array, value) -> bool:
	match q["kind"]:
		"nth_card":
			return SSCards.same(cards[q["pos"]], value)
		"nth_suit":
			return cards[q["pos"]]["suit"] == value
		"nth_rank", "character":
			return int(cards[q["pos"]]["rank"]) == int(value)
		"nth_color":
			return _color(cards[q["pos"]]) == value
		"yes_no":
			return has(cards, q["prop"]) == value
		"which_shown":
			return _contains(cards, value)
		"not_shown":
			return not _contains(cards, value)
		"extreme":
			var ranks: Array = cards.map(func(c): return int(c["rank"]))
			return int(value) == (ranks.max() if q["high"] else ranks.min())
		"where":
			return SSCards.same(cards[int(value)], q["card"])
		"count":
			return count_of(cards, q["prop"]) == int(value)
	return false


## A sentence saying what the right answer was ("It was the 7 of Clubs.").
static func reveal(q: Dictionary) -> String:
	var lab: String = q["labels"][q["answer"]]
	match q["style"]:
		"yesno":
			return "The answer was %s." % lab
		"position":
			return "It was the %s card." % lab
		"card":
			return "It was the %s." % lab
		"number":
			return "There were %s." % lab
	return "It was %s." % lab


# ------------------------------------------------------------------ properties

## A property is {"type": "color"/"suit"/"face"/"rank", "v": ...}.
static func matches(c: Dictionary, prop: Dictionary) -> bool:
	match prop["type"]:
		"color": return _color(c) == prop["v"]
		"suit": return c["suit"] == prop["v"]
		"face": return SSCards.is_face(c)
		"rank": return int(c["rank"]) == int(prop["v"])
	return false


static func has(cards: Array, prop: Dictionary) -> bool:
	return count_of(cards, prop) > 0


static func count_of(cards: Array, prop: Dictionary) -> int:
	var n := 0
	for c in cards:
		if matches(c, prop):
			n += 1
	return n


static func _prop_a(prop: Dictionary) -> String:
	match prop["type"]:
		"color": return "a %s card" % prop["v"]
		"suit": return "a %s" % SSCards.SUIT_ONE[prop["v"]]
		"face": return "a character card"
		"rank":
			var r: int = prop["v"]
			return ("an " if r == 14 or r == 8 else "a ") + SSCards.rank_name(r)
	return ""


static func _prop_plural(prop: Dictionary) -> String:
	match prop["type"]:
		"color": return "%s cards" % prop["v"]
		"suit": return SSCards.SUIT_NAMES[prop["v"]]
		"face": return "character cards"
		"rank": return SSCards.rank_name(prop["v"]) + "s"
	return ""


# ------------------------------------------------------------------ builders

static func _which(cards: Array, pos: int) -> String:
	return "the card" if cards.size() == 1 else "the %s card" % SSCards.ordinal(pos + 1)


static func _nth_card(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := rng.randi_range(0, cards.size() - 1)
	var t: Dictionary = cards[pos]
	var opts: Array = [t]
	# Another shown card makes a sneaky wrong answer: right card, wrong spot.
	if cards.size() > 1 and rng.randf() < 0.6:
		var other: Dictionary = cards[(pos + rng.randi_range(1, cards.size() - 1)) % cards.size()]
		opts.append(other)
	_fill_near(opts, t, 4, [], rng)
	var text := "What was the card?" if cards.size() == 1 else "What was the %s card?" % SSCards.ordinal(pos + 1)
	return _q(text, "card", opts, 0, {"pos": pos})


static func _nth_suit(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := rng.randi_range(0, cards.size() - 1)
	var opts: Array = SSCards.SUITS.duplicate()
	var labels: Array = opts.map(func(s): return SSCards.SUIT_NAMES[s])
	return _q("What suit was %s?" % _which(cards, pos), "suit", opts, opts.find(cards[pos]["suit"]), {"pos": pos}, labels)


static func _nth_rank(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := rng.randi_range(0, cards.size() - 1)
	var r: int = cards[pos]["rank"]
	var opts: Array = [r]
	while opts.size() < 4:
		var d := rng.randi_range(-3, 3)
		var x := clampi(r + d, 2, 14)
		if rng.randf() < 0.25:
			x = rng.randi_range(2, 14)
		if not x in opts:
			opts.append(x)
	var labels: Array = opts.map(func(v): return SSCards.rank_name(v))
	var all_numbers := opts.all(func(v): return v <= 10)
	var text := ("What number was %s?" if all_numbers else "What rank was %s?") % _which(cards, pos)
	return _q(text, "rank", opts, 0, {"pos": pos}, labels)


static func _nth_color(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := rng.randi_range(0, cards.size() - 1)
	var opts: Array = ["red", "black"]
	return _q("What color was %s?" % _which(cards, pos), "color", opts, opts.find(_color(cards[pos])), {"pos": pos}, ["Red", "Black"])


static func _yes_no(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var want := rng.randf() < 0.5
	var props: Array = [{"type": "color", "v": "red"}, {"type": "color", "v": "black"}, {"type": "face"}, {"type": "rank", "v": 14}]
	for s in SSCards.SUITS:
		props.append({"type": "suit", "v": s})
	for c in cards:
		props.append({"type": "rank", "v": c["rank"]})
		props.append({"type": "rank", "v": clampi(int(c["rank"]) + (1 if rng.randf() < 0.5 else -1), 2, 14)})
	var good: Array = props.filter(func(p): return has(cards, p) == want)
	if good.is_empty():
		want = not want
		good = props.filter(func(p): return has(cards, p) == want)
	var prop: Dictionary = good[rng.randi_range(0, good.size() - 1)]
	var text := ("Was it %s?" if cards.size() == 1 else "Was there %s?") % _prop_a(prop)
	var opts: Array = [true, false]
	var q := _q(text, "yesno", opts, 0 if want else 1, {"prop": prop}, ["Yes", "No"])
	q["keep_order"] = true
	return q


static func _character(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var faces := _face_positions(cards)
	if faces.is_empty():
		return {}
	var pos: int = faces[rng.randi_range(0, faces.size() - 1)]
	var text: String
	if cards.size() == 1:
		text = "Who was on the card?"
	elif faces.size() == 1:
		text = "Who was on the character card?"
	else:
		text = "Who was on the %s card?" % SSCards.ordinal(pos + 1)
	var opts: Array = SSCards.FACE_RANKS.duplicate()
	var labels: Array = opts.map(func(r): return SSCards.CHARACTERS[r]["name"])
	var q := _q(text, "character", opts, opts.find(int(cards[pos]["rank"])), {"pos": pos}, labels)
	q["keep_order"] = true
	return q


static func _which_shown(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = cards[rng.randi_range(0, cards.size() - 1)]
	var opts: Array = [t]
	_fill_unseen(opts, cards, 4, rng)
	if opts.size() < 2:
		return {}
	return _q("Which of these cards did you see?", "card", opts, 0, {})


static func _not_shown(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var shown := cards.duplicate()
	_shuffle(shown, rng)
	var opts: Array = []
	_fill_unseen(opts, cards, 1, rng)
	if opts.is_empty():
		return {}
	for c in shown.slice(0, mini(3, shown.size())):
		opts.append(c)
	return _q("Which card was NOT shown?", "card", opts, 0, {})


static func _extreme(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var ranks: Array = cards.map(func(c): return int(c["rank"]))
	var high := rng.randf() < 0.6
	var r: int = ranks.max() if high else ranks.min()
	var opts: Array = [r]
	var others: Array = []
	for x in ranks:
		if x != r and not x in others:
			others.append(x)
	_shuffle(others, rng)
	for x in others:
		if opts.size() < 3:
			opts.append(x)
	# Fill up with ranks that would be wrong (never a better answer than the real one).
	var worse: Array = []
	for x in range(2, 15):
		if (x < r if high else x > r) and not x in opts:
			worse.append(x)
	worse.sort_custom(func(a, b): return absi(a - r) < absi(b - r))
	worse = worse.slice(0, 5)
	_shuffle(worse, rng)
	for x in worse:
		if opts.size() < 4:
			opts.append(x)
	if opts.size() < 2:
		return {}
	var text := "What was the highest card?" if high else "What was the lowest card?"
	var labels: Array = opts.map(func(v): return SSCards.rank_name(v))
	return _q(text, "rank", opts, 0, {"high": high}, labels)


static func _where(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := rng.randi_range(0, cards.size() - 1)
	var t: Dictionary = cards[pos]
	var opts: Array = [pos]
	var rest: Array = range(cards.size())
	rest.erase(pos)
	_shuffle(rest, rng)
	for p in rest:
		if opts.size() < 4:
			opts.append(p)
	opts.sort()
	var labels: Array = opts.map(func(p): return SSCards.ordinal(p + 1))
	var q := _q("Where was the %s?" % SSCards.card_name(t), "position", opts, opts.find(pos), {"card": t}, labels)
	q["keep_order"] = true
	return q


static func _count(cards: Array, rng: RandomNumberGenerator) -> Dictionary:
	var props: Array = [{"type": "color", "v": "red"}, {"type": "color", "v": "black"}, {"type": "face"}]
	for s in SSCards.SUITS:
		props.append({"type": "suit", "v": s})
	var prop: Dictionary = props[rng.randi_range(0, props.size() - 1)]
	var c := count_of(cards, prop)
	var n := cards.size()
	var lo := clampi(c - rng.randi_range(0, 3), 0, maxi(0, n - 3))
	var opts: Array = []
	for v in range(lo, mini(lo + 4, n + 1)):
		opts.append(v)
	var labels: Array = opts.map(func(v): return str(v))
	var q := _q("How many %s were there?" % _prop_plural(prop), "number", opts, opts.find(c), {"prop": prop}, labels)
	q["keep_order"] = true
	return q


# ------------------------------------------------------------------ helpers

static func _q(text: String, style: String, opts: Array, answer: int, extra: Dictionary, labels: Array = []) -> Dictionary:
	if labels.is_empty():
		labels = opts.map(func(o): return SSCards.card_name(o) if o is Dictionary else str(o))
	var q := {"text": text, "style": style, "options": opts, "labels": labels, "answer": answer}
	q.merge(extra)
	return q


static func _color(c: Dictionary) -> String:
	return "red" if SSCards.is_red(c) else "black"


static func _contains(cards: Array, c: Dictionary) -> bool:
	for x in cards:
		if SSCards.same(x, c):
			return true
	return false


static func _face_positions(cards: Array) -> Array:
	var out: Array = []
	for i in cards.size():
		if SSCards.is_face(cards[i]):
			out.append(i)
	return out


## Near misses for a card: same rank other suit, or same suit a rank or two away.
static func _near(t: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < 0.5:
		var s: String = SSCards.SUITS[rng.randi_range(0, 3)]
		return SSCards.make(t["rank"], s)
	var r := clampi(int(t["rank"]) + [-2, -1, 1, 2][rng.randi_range(0, 3)], 2, 14)
	return SSCards.make(r, t["suit"])


## Add near-miss cards (not already in opts or exclude) until opts has n cards.
static func _fill_near(opts: Array, t: Dictionary, n: int, exclude: Array, rng: RandomNumberGenerator) -> void:
	var tries := 0
	while opts.size() < n and tries < 200:
		tries += 1
		var c := _near(t, rng) if tries < 120 else SSCards.make(rng.randi_range(2, 14), SSCards.SUITS[rng.randi_range(0, 3)])
		if not _contains(opts, c) and not _contains(exclude, c):
			opts.append(c)


## Add cards that were NOT shown (near misses of shown ones) until opts has n cards.
static func _fill_unseen(opts: Array, cards: Array, n: int, rng: RandomNumberGenerator) -> void:
	var tries := 0
	while opts.size() < n and tries < 300:
		tries += 1
		var base: Dictionary = cards[rng.randi_range(0, cards.size() - 1)]
		var c := _near(base, rng) if tries < 200 else SSCards.make(rng.randi_range(2, 14), SSCards.SUITS[rng.randi_range(0, 3)])
		if not _contains(opts, c) and not _contains(cards, c):
			opts.append(c)


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Shuffle the options (unless their order means something) and keep `answer` pointing right.
static func _shuffle_options(q: Dictionary, rng: RandomNumberGenerator) -> void:
	if q.get("keep_order", false):
		return
	var idx: Array = range(q["options"].size())
	if q["style"] == "rank":
		# Ranks read best in order: 2, 5, 9, Queen.
		idx.sort_custom(func(a, b): return q["options"][a] < q["options"][b])
	else:
		_shuffle(idx, rng)
	var o: Array = []
	var l: Array = []
	for i in idx:
		o.append(q["options"][i])
		l.append(q["labels"][i])
	q["answer"] = idx.find(q["answer"])
	q["options"] = o
	q["labels"] = l
