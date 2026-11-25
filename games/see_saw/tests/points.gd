extends SceneTree
func _initialize(): run.call_deferred()
func right(g: SeeSaw): return g.answer(g.question().answer)
func start(g: SeeSaw):
 g.start_round()
 g.hide_cards()
func run():
 var g := SeeSaw.new().setup(7)
 start(g)
 assert(right(g).points == 10)
 assert(right(g).points == 60)
 assert(g.points == 70 and g.level == 2)
 g.next_round(); start(g)
 right(g);right(g)
 assert(g.points == 160)
 var remembered = g.history[2].duplicate(true)
 g.next_round();start(g)
 assert(right(g).points == 130)
 right(g);right(g)
 assert(g.points == 400)
 g.next_round();start(g)
 right(g);right(g);right(g)
 assert(g.points == 670 and g.bonus_pending)
 g.next_round()
 assert(g.bonus_active and g.bonus_level==2 and g.cards==remembered)
 var before := g.points
 var wrong: int = (int(g.question().answer)+1)%g.question().options.size()
 var res = g.answer(wrong)
 assert(res.bonus and g.lives==3 and g.points==before and g.streak==0)
 g.next_round();assert(g.phase=="ready" and g.level==5)
 assert(not g.restore_counterweight())
 start(g);g.answer((int(g.question().answer)+1)%g.question().options.size());g.next_round()
 assert(g.lives==2 and g.restore_counterweight() and g.points==420 and g.lives==3)
 g.points=249;g.lives=0;g.phase="over";assert(not g.restore_counterweight())
 g.points=250;assert(g.restore_counterweight() and g.points==0 and g.lives==1 and g.phase=="ready")
 # Every subsequent even level recalls exactly two levels ago.
 g=SeeSaw.new().setup(12)
 var callbacks: Array=[]
 while g.level<=9:
  if g.phase=="ready":start(g)
  elif g.phase=="ask":
   if g.bonus_active:
    callbacks.append(g.bonus_level)
    var points := g.points
    res=right(g)
    assert(res.points==50 or res.points==150)
    assert(g.points==points+res.points)
   else:right(g)
  else:g.next_round()
 assert(callbacks==[2,4,6])
 var screen=load("res://games/see_saw/scenes/game.tscn").instantiate()
 root.add_child(screen)
 screen.g=g
 screen._build_ready()
 await create_timer(0.6).timeout
 await shot("seesaw-points-ready")
 screen.g.lives=0;screen.g.phase="over";screen._game_over()
 await create_timer(0.6).timeout
 await shot("seesaw-points-landed")
 assert(screen.g.restore_counterweight())
 screen._build_ready()
 print("SEE SAW POINTS OK: scoring, streaks, callback levels, no-risk bonus, purchase limits and revival")
 quit()
func shot(name: String):
 if OS.get_environment("OUT")=="":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("OUT")+"/"+name+".png")
