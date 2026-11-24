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


## Play a whole Piece round for player p.
static func play_piece(g: WarState, p: int) -> void:
	var pl := plan(g.hand(p), g.sets(p))
	# Additions refer to set indexes as they were before new sets were added, so do them
	# against the original sets first when the plan started with "add"; otherwise after.
	var base := g.sets(p).size()
	for ids in pl["new"]:
		g.lock_set(p, ids)
	for a in pl["add"]:
		var idx: int = a[0]
		if not g.add_to_set(p, idx, a[1]):
			# Index shifted: find any set that takes it.
			for k in g.sets(p).size():
				if g.add_to_set(p, k, a[1]):
					break
	g.finish_piece(p)
	void_unused(base)


static func void_unused(_x) -> void:
	pass
