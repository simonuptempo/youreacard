extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var screen=load("res://games/see_saw/scenes/game.tscn").instantiate()
 root.add_child(screen)
 var g := SeeSaw.new().setup(81)
 while not g.bonus_active:
  if g.phase=="ready":g.start_round();g.hide_cards()
  elif g.phase=="ask":g.answer(g.question().answer)
  else:g.next_round()
 screen.g=g
 screen._build_question()
 await create_timer(0.5).timeout
 await shot("seesaw-bonus")
 var points := g.points
 var lives := g.lives
 screen._pick(g.question().answer)
 assert(g.points==points+50 and g.lives==lives)
 await create_timer(0.5).timeout
 await shot("seesaw-bonus-earned")
 screen._advance()
 g.lives=2
 screen._build_ready()
 await create_timer(0.6).timeout
 await shot("seesaw-restore")
 var cf:=ConfigFile.new()
 cf.load(SSBest.PATH)
 cf.set_value("score","best_level",8)
 cf.save(SSBest.PATH)
 SSBest.submit(9999)
 cf.load(SSBest.PATH)
 assert(cf.get_value("score","best_level")==8 and SSBest.get_best()==9999)
 print("BONUS UI AND LEGACY BEST OK")
 quit()
func shot(name: String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("OUT")+"/"+name+".png")
