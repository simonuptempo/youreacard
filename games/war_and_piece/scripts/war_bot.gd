class_name WarBot
## Arranges a hand into locked sets. Used by the computer, and by the "Auto-arrange"
## button for you.

## Returns a plan: {"new": [[ids...]], "add": [[set_index, [ids...]]]} that locks as many
## cards as it can (it tries a few orders and keeps the best).
static func plan(hand: Array, locked: Array) -> Dictionary:
	var best := {"new": [], "add": [], "count": -1}
	for order in [["add", "run", "kind"], ["add", "kind", "run"], ["kind", "run", "add"], ["run", "kind", "add"]]:
		var p := _try(hand, locked, order)
		if p["count"] > best["count"]:
			best = p
	return best


static func _try(hand: Array, locked: Array, order: Array) -> Dictionary:
	var left: Array = hand.duplicate()
	var grown: Array = locked.map(func(s): return s.duplicate())
	var out := {"new": [], "add": [], "count": 0}
	for step in order:
		match step:
			"add":
				var changed := true
				while changed:
					changed = false
					for i in grown.size():
						for c in left.duplicate():
							if WarCards.set_type(grown[i] + [c]) != "":
								grown[i].append(c)
								left.erase(c)
								out["add"].append([i, [c["id"]]])
								out["count"] += 1
								changed = true
			"kind":
				for r in range(2, 15):
					var same: Array = left.filter(func(c): return c["rank"] == r)
					if same.size() >= WarCards.MIN_SET:
						for c in same:
							left.erase(c)
						out["new"].append(same.map(func(c): return c["id"]))
						grown.append(same)
						out["count"] += same.size()
			"run":
				for s in WarCards.SUITS:
					var suited: Array = left.filter(func(c): return c["suit"] == s)
					suited.sort_custom(func(a, b): return a["rank"] < b["rank"])
					var i := 0
					while i < suited.size():
						var j := i
						while j + 1 < suited.size() and suited[j + 1]["rank"] == suited[j]["rank"] + 1:
							j += 1
						if j - i + 1 >= WarCards.MIN_SET:
							var run: Array = suited.slice(i, j + 1)
							for c in run:
								left.erase(c)
							out["new"].append(run.map(func(c): return c["id"]))
							grown.append(run)
							out["count"] += run.size()
						i = j + 1
	return out


## The moves that lock as much of player p's hand as possible (without "done").
## Each is applied to g as it goes, and the ones that worked are returned.
static func arrange(g: WarState, p: int) -> Array:
	var done: Array = []
	var pl := plan(g.hand(p), g.sets(p))
	for ids in pl["new"]:
		var m := {"t": "lock", "p": p, "ids": ids}
		if g.apply(m):
			done.append(m)
	for a in pl["add"]:
		# Add steps name sets by their place in the plan; if that set moved, any set that takes the card will do.
		var m := {"t": "add", "p": p, "set": a[0], "ids": a[1]}
		if g.apply(m):
			done.append(m)
			continue
		for k in g.sets(p).size():
			m = {"t": "add", "p": p, "set": k, "ids": a[1]}
			if g.apply(m):
				done.append(m)
				break
	return done


## Play a whole Piece round for player p. Returns the moves made.
static func play_piece(g: WarState, p: int) -> Array:
	var moves := arrange(g, p)
	var d := {"t": "done", "p": p}
	if g.apply(d):
		moves.append(d)
	return moves
