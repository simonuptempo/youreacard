extends SceneTree
var screen: Control
var out := OS.get_environment("OUT")
func _initialize() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await create_timer(0.12).timeout
	if out=="": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func settle() -> void:
	await process_frame
	while screen._bot_running or screen._busy: await process_frame
func fixture() -> WarState:
	var g:=WarState.new();g.setup(["You","Computer"],6)
	var deck:=WarCards.build_deck()
	for p in 2:
		g.stock(p).clear()
		for rank in ([7,7,9,3,4] if p==0 else [7,7,9,9,9,5,6]):
			for c in deck:
				if c.rank==rank:g.hand(p).append(c);deck.erase(c);break
	var bank:=deck.filter(func(c):return c.rank==12);g.sets(1).append(bank)
	for c in bank:deck.erase(c)
	g.unclaimed=deck;g.round_number=2;g.shield_draws=[[],[]];g.shields=[1,0];g.shield_pool=1;g._plan_heists()
	return g
func _run() -> void:
	screen=load("res://games/war_and_piece/scenes/game.tscn").instantiate();root.add_child(screen)
	screen.g=fixture();screen._reduced_motion=true;screen._build_mode()
	await shot("auto-heist-board")
	assert(screen._main_btn.text=="Tap a stack for your heist")
	screen._main_btn.pressed.emit()
	await shot("auto-heist-picker")
	assert(screen._layer.get_node("Hand").get_child(0).columns == 3)
	assert(screen._heist_picker.size == Vector2(210, 260))
	screen._heist_picker.get_node("Cancel").pressed.emit()
	await process_frame
	assert(screen.g.heist_step == 0)
	screen._inspect_group(7)
	var choices = screen._heist_picker.get_children().filter(func(c):return c is Button and c.name != "Cancel")
	choices[0].pressed.emit();await settle()
	assert(screen.g.heist_step==2 and screen.g.pending_heist.is_empty())
	assert(screen.g.shields_spent==1 and screen.g.shields[0]==0)
	assert(screen._layer.get_node("PieceStatus/Heist0").material == null)
	assert(screen._layer.get_node("PieceStatus/Heist2").material != null)
	assert(screen._layer.get_node("PieceStatus/Shield0").material != null)
	assert("shield" in str(screen._layer.get_node("PieceLog").get_meta("entries")).to_lower())
	await shot("auto-shield-blocked")
	var saved:Dictionary=screen.g.to_dict();screen.queue_free();await process_frame
	WarSave.resume_next=true
	screen=load("res://games/war_and_piece/scenes/game.tscn").instantiate();root.add_child(screen)
	screen._reduced_motion=true
	assert(screen.g.to_dict()==saved and screen._main_btn.text=="Tap a stack for your heist")
	screen._heist_rank(7);await settle()
	assert(screen.g.heist_step==3 and screen.g.sets(0).size()==1)
	await shot("auto-heists-complete")
	screen._done_piece();await process_frame
	assert(screen.g.total_cards()==52 and screen.g.total_shields()==2)
	assert(screen.g.phase() == "war")
	assert(screen.get_node_or_null("Summary") == null)
	assert(screen._main_btn.text == "Deal!")
	print("AUTO HEIST UI OK: picker, automatic shield, result messages, resume, third turn, next War")
	quit()
