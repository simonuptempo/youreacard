extends SceneTree
func _initialize():run.call_deferred()
func run():
 var menu=load("res://games/see_saw/scenes/main.tscn").instantiate()
 root.add_child(menu)
 assert(menu.has_node("MyCards"))
 var faces=menu.get_children().filter(func(c):return c.get_script() != null and c.get_script().resource_path.ends_with("ss_card_view.gd"))
 assert(faces.size()==4)
 for card in faces: assert(card.mouse_filter==Control.MOUSE_FILTER_STOP and card.tapped.get_connections().size()==1)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("OUT")+"/seesaw-customize.png")
 menu._customize("mastermind")
 assert(root.get_node("Profile").edit_slot=="mastermind" and root.get_node("Profile").creator_return=="res://games/see_saw/scenes/main.tscn")
 await process_frame
 await process_frame
 var editor=current_scene
 assert(editor.scene_file_path.ends_with("my_cards.tscn"))
 editor._leave()
 await process_frame
 await process_frame
 assert(current_scene.scene_file_path.ends_with("see_saw/scenes/main.tscn"))
 var profile=root.get_node("Profile")
 var old=profile.slots.duplicate(true)
 profile.slots["pickpocket"]={"name":"Mochi","avatar":profile.default_face("pickpocket")}
 var screen=load("res://games/see_saw/scenes/game.tscn").instantiate()
 root.add_child(screen)
 screen.g.phase="ask"
 screen.g.cards=[{"id":1,"rank":11,"suit":"H"}]
 screen.g.questions=[{"kind":"character","style":"character","text":"Who was on the card?","pos":0,"options":[11,12,13,14],"labels":["Pip","Juno","Lou","Amara"],"answer":0}]
 screen.g.q_index=0
 screen._build_question()
 assert(screen.g.question().labels[0]=="Mochi")
 assert("Mochi" in SSQuestions.reveal(screen.g.question()))
 profile.slots=old
 print("SEE SAW CUSTOMIZATION OK: four tappable faces, editor slot, return navigation")
 quit()
