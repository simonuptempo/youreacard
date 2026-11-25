extends SceneTree
func _initialize(): run.call_deferred()
func fixture(seed_value: int) -> WarState:
 var g := WarState.new()
 g.setup(["You", "Rascal"], seed_value)
 for p in 2:
  g.stock(p).clear()
 var deck := WarCards.build_deck()
 var owner := 0
 for rank in range(2,15):
  var group := deck.filter(func(c): return c.rank == rank)
  if rank == 11:
   g.hand(0).append_array(group.slice(0,2))
   g.hand(1).append_array(group.slice(2))
  else:
   g.sets(owner % 2).append(group)
   owner += 1
 g.round_number = 4
 g.heist_order = [0,1,0]
 g.heist_step = 3
 return g
func run():
 var wins := [0,0]
 var ties := 0
 for seed_value in range(1,201):
  var g := fixture(seed_value)
  g._start_war_round()
  assert(g.winner in [0,1] and g.total_cards() == 52)
  assert(g.sets(0).size()+g.sets(1).size() == 13)
  assert(g.sets(g.winner).size() == 7)
  var totals := [0,0]
  for i in g.last_faceoff.cards[0].size():
   for player in 2: totals[player] += g.last_faceoff.cards[player][i].rank
   if (i+1)%5 == 0 and i+1 < g.last_faceoff.cards[0].size(): assert(totals[0] == totals[1])
  assert(totals[g.winner] > totals[1-g.winner])
  assert(g.last_faceoff.cards[0].size()%5 == 0)
  wins[g.winner] += 1
  ties += g.last_faceoff.wars
 assert(wins[0]>0 and wins[1]>0 and ties>0)
 # Not tied at 12 sets (8-4, 7-5): no showdown, the leader simply wins.
 for lead in [[8,4],[4,8],[7,5]]:
  var g2 := fixture(3)
  var all: Array = g2.sets(0) + g2.sets(1)
  g2.players[0].sets = all.slice(0, lead[0])
  g2.players[1].sets = all.slice(lead[0])
  g2.last_faceoff = {}
  g2._start_war_round()
  assert(g2.phase() == "over" and g2.winner == (0 if lead[0] > lead[1] else 1))
  assert(g2.last_faceoff.get("reason", "") != "final_showdown")
  assert(g2.sets(0).size() + g2.sets(1).size() == 12)
 WarSave.clear()
 var screen = load("res://games/war_and_piece/scenes/game.tscn").instantiate()
 root.add_child(screen)
 screen.g = fixture(7)
 screen.g._start_war_round()
 screen._build_mode()
 await create_timer(1.0).timeout
 var button = screen._layer.get_node("ShowdownReveal")
 assert(not button.disabled and button.text == "Reveal showdown cards")
 if OS.get_environment("OUT") != "":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/five-showdown.png")
 for batch in int(screen.g.last_faceoff.cards[0].size()/5):
  button.pressed.emit()
  await create_timer(4).timeout
  assert(not button.disabled)
 assert(button.text == "See final results")
 button.pressed.emit()
 await process_frame
 assert(screen._layer.has_node("GameOver"))
 print("FINAL SHOWDOWN OK: 200 seeds, both winners, ties redraw, 52 cards, 13 sets, animation completes")
 quit()
