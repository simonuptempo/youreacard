class_name SeeSaw
extends RefCounted
## The rules engine for See Saw. No UI in here, so tests can play whole games.
##
## Level N shows N cards for 3N seconds, then asks a few questions about them.
## Answer them all right and you move up a level. A wrong answer costs a life
## and you try the same level again with new cards. Lose all your lives and the
## game is over. Your score is accumulated points minus counterweight purchases.
##
## Phases: "ready" (about to show a level), "show" (cards face up),
## "ask" (answering), "between" (round finished, see last_result), "over".

const START_LIVES := 3
const COUNTERWEIGHT_FROM := 4   # clearing this level (and every one after) earns a counterweight

var points := 0
var streak := 0
var best_streak := 0
var history := {}
var bonus_level := 0
var bonus_pending := false
var bonus_active := false
const RESTORE_COST := 250

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
	points = 0
	streak = 0
	best_streak = 0
	history = {}
	bonus_level = 0
	bonus_pending = false
	bonus_active = false
	rounds_played = 0
	rng.seed = seed_value
	level = start_level
	lives = START_LIVES
	phase = "ready"
	return self


func cards_for_level(lv: int) -> int:
	return mini(lv, 52)


func show_seconds() -> float:
	return 3.0 * cards_for_level(level)


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
	var earned := 0
	if ok:
		streak += 1
		best_streak = maxi(best_streak, streak)
		earned = 50 if bonus_active else level * 10
		if streak % 5 == 0: earned += 100
	else:
		streak = 0
	res["streak_bonus"] = ok and streak % 5 == 0
	res["bonus"] = bonus_active
	if bonus_active:
		points += earned
		res["points"] = earned
		res["round_over"] = true
		last_result = {"cleared": true, "bonus": true, "correct": ok, "question": q, "picked": i}
		bonus_active = false
		phase = "between"
		return res
	if ok:
		q_index += 1
		if q_index >= questions.size():
			res["round_over"] = true
			res["cleared"] = true
			last_result = {"cleared": true, "question": q, "picked": -1}
			earned += 50
			history[level] = cards.duplicate(true)
			# Level 4 and every level after it earns Nana Bea's counterweight: an extra life.
			if level >= COUNTERWEIGHT_FROM:
				lives += 1
				res["counterweight"] = true
				last_result["counterweight"] = true
			bonus_pending = level >= 4 and level % 2 == 0 and history.has(level - 2)
			if bonus_pending: bonus_level = level - 2
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
	points += earned
	res["points"] = earned
	return res


func next_round() -> void:
	assert(phase == "between")
	if bonus_pending:
		bonus_pending = false
		bonus_active = true
		cards = history[bonus_level].duplicate(true)
		questions = SSQuestions.make_round(cards, bonus_level, rng, 1)
		q_index = 0
		phase = "ask"
	else:
		phase = "ready"


func can_restore() -> bool:
	return lives < START_LIVES and points >= RESTORE_COST and phase in ["ready", "over"]


func restore_counterweight() -> bool:
	if not can_restore(): return false
	points -= RESTORE_COST
	lives += 1
	if phase == "over": phase = "ready"
	return true


## Current spendable points, also the final score when the player ends the run.
func score() -> int:
	return points
