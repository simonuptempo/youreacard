extends SceneTree
## Rules + question checks, no UI:
##  1. Thousands of generated questions: options are all different, and exactly one
##     option is right when judged from the shown cards (SSQuestions.is_correct).
##  2. A perfect player never loses a life; a random player always ends the game.
##  3. Same seed, same game.

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		if fails < 30:
			push_error(msg)


func _init() -> void:
	var kinds := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var total := 0
	for i in 6000:
		var n := 1 + (i % 16)
		var deck := SSCards.build_deck()
		SSQuestions._shuffle(deck, rng)
		var cards := deck.slice(0, n)
		for q in SSQuestions.make_round(cards, n, rng, 3):
			total += 1
			kinds[q["kind"]] = kinds.get(q["kind"], 0) + 1
			var opts: Array = q["options"]
			check(opts.size() >= 2 and opts.size() == q["labels"].size(), "option count %s" % q)
			var seen := {}
			for l in q["labels"]:
				check(not seen.has(l), "duplicate option %s in %s" % [l, q["text"]])
				seen[l] = true
			var right := 0
			for j in opts.size():
				if SSQuestions.is_correct(q, cards, opts[j]):
					right += 1
					check(j == q["answer"], "answer index wrong: %s" % q["text"])
			check(right == 1, "%d right answers for '%s' cards=%s labels=%s" % [right, q["text"], cards.map(SSCards.card_name), q["labels"]])
			check(q["text"].length() < 60, "long text " + q["text"])
	print("questions checked: %d  by kind: %s" % [total, kinds])

	# Perfect player: climbs and never loses a life.
	var g := SeeSaw.new().setup(7)
	while g.level <= 20:
		g.start_round()
		check(g.cards.size() == g.level, "card count")
		check(g.questions.size() == SSQuestions.questions_for_level(g.level), "question count at level %d" % g.level)
		g.hide_cards()
		while g.phase == "ask":
			g.answer(g.question()["answer"])
		g.next_round()
	check(g.lives == 3, "perfect player lost a life")
	print("perfect player reached level %d with %d lives" % [g.level, g.lives])

	# Random player: game always ends, lives never negative.
	var scores: Array = []
	for s in 500:
		var r := SeeSaw.new().setup(s)
		var safety := 0
		while r.phase != "over" and safety < 1000:
			safety += 1
			if r.phase in ["ready", "between"]:
				if r.phase == "between":
					r.next_round()
				r.start_round()
				r.hide_cards()
			var q := r.question()
			r.answer(r.rng.randi_range(0, q["options"].size() - 1))
		check(r.phase == "over" and r.lives == 0, "random game %d didn't end" % s)
		scores.append(r.score())
	print("random player: avg level %.2f, max %d" % [scores.reduce(func(a, b): return a + b) / float(scores.size()), scores.max()])

	# Determinism
	var a := SeeSaw.new().setup(99, 5)
	var b := SeeSaw.new().setup(99, 5)
	a.start_round(); b.start_round()
	check(str(a.cards) == str(b.cards) and str(a.questions) == str(b.questions), "not deterministic")

	print("SIM %s (%d problems)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(0 if fails == 0 else 1)
