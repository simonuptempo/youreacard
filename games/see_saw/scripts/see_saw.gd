class_name SeeSaw
extends RefCounted
## The rules engine for See Saw. No UI in here, so tests can play whole games.
##
## Level N shows N cards for N seconds, then asks a few questions about them.
## Answer them all right and you move up a level. A wrong answer costs a life
## and you try the same level again with new cards. Lose all your lives and the
## game is over. Your score is the highest level you reached.
##
## Phases: "ready" (about to show a level), "show" (cards face up),
## "ask" (answering), "between" (round finished, see last_result), "over".

const START_LIVES := 3

var rng := RandomNumberGenerator.new()
var level := 1
var lives := START_LIVES
var phase := "ready"
var cards: Array = []          # the cards shown this round, in order
var questions: Array = []
var q_index := 0
var rounds_played := 0
## After a round: {"cleared": bool, "question": q, "picked": int} (picked = -1 if cleared)
var last_result := {}


func setup(seed_value: int, start_level := 1) -> SeeSaw:
	rng.seed = seed_value
	level = start_level
	lives = START_LIVES
	phase = "ready"
	return self


func cards_for_level(lv: int) -> int:
	return mini(lv, 52)


func show_seconds() -> float:
	return float(level)


## Deal this level's cards face up.
func start_round() -> void:
	assert(phase == "ready" or phase == "between")
	var deck := SSCards.build_deck()
	SSQuestions._shuffle(deck, rng)
	cards = deck.slice(0, cards_for_level(level))
	questions = SSQuestions.make_round(cards, level, rng)
	q_index = 0
	last_result = {}
	rounds_played += 1
	phase = "show"


## Time's up: hide the cards and start asking.
func hide_cards() -> void:
	assert(phase == "show")
	phase = "ask"


func question() -> Dictionary:
	return questions[q_index] if phase == "ask" else {}


## Answer the current question. Returns {"correct", "answer", "round_over", "cleared", "game_over"}.
func answer(i: int) -> Dictionary:
	assert(phase == "ask")
	var q: Dictionary = questions[q_index]
	var ok := i == int(q["answer"])
	var res := {"correct": ok, "answer": q["answer"], "round_over": false, "cleared": false, "game_over": false}
	if ok:
		q_index += 1
		if q_index >= questions.size():
			res["round_over"] = true
			res["cleared"] = true
			last_result = {"cleared": true, "question": q, "picked": -1}
			level += 1
			phase = "between"
	else:
		lives -= 1
		res["round_over"] = true
		last_result = {"cleared": false, "question": q, "picked": i}
		if lives <= 0:
			res["game_over"] = true
			phase = "over"
		else:
			phase = "between"
	return res


func next_round() -> void:
	assert(phase == "between")
	phase = "ready"


## Highest level reached (the level you were on when the game ended, or are on now).
func score() -> int:
	return level
