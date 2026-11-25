extends "res://games/war_and_piece/tests/final_showdown.gd"
func run():
 for winner in 2:
  var g := fixture(9)
  g.hand(winner).append_array(g.hand(1-winner))
  g.players[1-winner].hand=[]
  g.auto_bank(winner)
  assert(g.winner==winner and g.phase()=="over")
  assert(g.piece_actor()==-1)
  assert(g.total_cards()==52)
 WarSave.clear()
 var screen=load("res://games/war_and_piece/scenes/game.tscn").instantiate()
 root.add_child(screen)
 screen.g=fixture(9)
 screen.g.hand(0).append_array(screen.g.hand(1))
 screen.g.players[1].hand=[]
 screen.g.auto_bank(0)
 screen._build_mode()
 assert(screen._layer.has_node("GameOver"))
 await create_timer(0.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/instant-results.png")
 print("INSTANT END OK: wins, losses, no heists, results roster")
 quit()
