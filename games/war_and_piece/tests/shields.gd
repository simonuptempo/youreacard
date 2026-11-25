extends SceneTree
var cases: Array = []

func fixture() -> WarState:
	var g := WarState.new()
	g.setup(["Ana", "Ben"], 6)
	var deck := WarCards.build_deck()
	for p in 2:
		g.stock(p).clear()
		var ranks := [7,7,9,3,4] if p == 0 else [7,7,9,9,9,5,6]
		for rank in ranks:
			for c in deck:
				if c.rank == rank:
					g.hand(p).append(c); deck.erase(c); break
	var bank := deck.filter(func(c): return c.rank == 12)
	g.sets(1).append(bank)
	for c in bank: deck.erase(c)
	g.unclaimed = deck
	g.round_number = 2
	g.shield_draws = [[],[]]
	g.shields = [1,0]
	g.shield_pool = 1
	g._plan_heists()
	return g

func record(g: WarState, move: Dictionary) -> bool:
	var before := g.to_dict()
	var ok := g.apply(move)
	cases.append({"before":before,"move":move,"ok":ok,"after":g.to_dict()})
	assert(g.total_cards() == 52 and g.total_shields() == 2)
	return ok

func _init() -> void:
	var g := fixture()
	assert(g.heist_order == [0,1,0])
	assert(not record(g,{"t":"heist","p":1,"rank":9}))
	assert(record(g,{"t":"heist","p":0,"rank":7}))
	assert(g.pending_heist.is_empty() and g.heist_step==1)
	assert(g.hand(0).filter(func(c):return c.rank==7).size()==3)
	assert(record(g,{"t":"heist","p":1,"rank":9}))
	assert(g.pending_heist.is_empty() and g.heist_step==2)
	assert(g.shields==[0,0] and g.shields_spent==1)
	assert(g.hand(0).any(func(c):return c.rank==9))
	assert(not record(g,{"t":"defend","p":0,"block":false}))
	assert(record(g,{"t":"heist","p":0,"rank":7}))
	assert(g.sets(0).size()==1 and g.heist_step==3)
	assert(record(g,{"t":"done","p":0}))
	assert(record(g,{"t":"done","p":1}))
	assert(g.shields_spent==1 and g.total_shields()==2)
	# A version-4 game saved while waiting for a defense resolves exactly once.
	g=fixture()
	var legacy:=g.to_dict()
	legacy.rules_version=4
	legacy.pending_heist={"attacker":1,"rank":9,"suit":g.hand(0).filter(func(c):return c.rank==9)[0].suit}
	legacy.heist_step=1
	var migrated:=WarState.from_dict(legacy)
	assert(migrated.rules_version==5 and migrated.pending_heist.is_empty())
	assert(migrated.shields_spent==1 and migrated.heist_step==2)
	assert(WarState.from_dict(migrated.to_dict()).to_dict()==migrated.to_dict())
	cases.append({"legacy":legacy.duplicate(true),"after":migrated.to_dict()})
	# With no shield, a legacy pending attack succeeds automatically.
	legacy.shields=[0,0];legacy.shield_pool=2
	migrated=WarState.from_dict(legacy)
	assert(not migrated.hand(0).any(func(c):return c.rank==9))
	assert(migrated.sets(1).size()==2 and migrated.heist_step==2)
	cases.append({"legacy":legacy.duplicate(true),"after":migrated.to_dict()})
	# Two shields block two attacks, each consuming exactly one; neither returns.
	g=fixture();g.shields=[0,2];g.shield_pool=0
	assert(record(g,{"t":"heist","p":0,"rank":7}))
	assert(record(g,{"t":"pass","p":1}))
	assert(record(g,{"t":"heist","p":0,"rank":7}))
	assert(g.shields_spent==2 and g.shields==[0,0] and g.hand(0).size()==5)
	var file:=FileAccess.open("/tmp/wp_shield_cases.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(cases))
	print("AUTO SHIELDS OK: immediate block, success, two uses, discard, turn order, pending-save migration")
	quit()
