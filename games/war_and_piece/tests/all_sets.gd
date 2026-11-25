extends SceneTree
func _init() -> void:
	var g := WarState.new()
	g.setup(["You","Computer"],9)
	var deck := WarCards.build_deck()
	for p in 2:
		g.players[p].stock=[]
		g.players[p].hand=[]
		g.players[p].sets=[]
	# Seven banks vs three: three incomplete ranks must remain playable.
	for rank in range(2,15):
		var group := deck.filter(func(c):return c.rank==rank)
		if rank<9:g.sets(0).append(group)
		elif rank<12:g.sets(1).append(group)
		else:
			g.hand(0).append_array(group.slice(0,2))
			g.hand(1).append_array(group.slice(2))
	g.round_number=2;g.heist_order=[];g.quiet_pieces=99
	g.shield_draws=[[],[]];g.shield_pool=0;g.shields_spent=2
	g.finish_piece(0);g.finish_piece(1)
	assert(g.phase()=="war" and g.round_number==3 and g.winner==-1)
	assert(g.total_cards()==52)
	# Final rank: every face-off ties; Piece must recover all four cards.
	g.players[0].stock=[];g.players[1].stock=[]
	for rank in [12,13]:g.sets(1).append(deck.filter(func(c):return c.rank==rank))
	var aces := deck.filter(func(c):return c.rank==14)
	g.players[0].stock=aces.slice(0,2);g.players[1].stock=aces.slice(2)
	g.flip()
	assert(g.phase()=="piece" and g.unclaimed.is_empty())
	assert(g.hand(0).size()==2 and g.hand(1).size()==2)
	var attempts := 0
	while g.phase()=="piece" and attempts<20:
		WarBot.play_piece(g,0);WarBot.play_piece(g,1);attempts+=1
	assert(g.phase()=="over" and g.sets(0).size()+g.sets(1).size()==13)
	assert(g.total_cards()==52 and g.total_shields()==2)
	print("ALL SETS OK: seven banks and quiet rounds continue; final-rank tie resolves; all 13 required")
	quit()
