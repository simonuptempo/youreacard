extends "res://games/war_and_piece/tests/animation_flow.gd"
func _run() -> void:
 var profile=root.get_node("Profile")
 var sfx=root.get_node("Sfx")
 profile.voices="off";profile.sound_on=false;sfx.enabled=false
 await show_scene("res://games/war_and_piece/scenes/game.tscn")
 screen.g=fixture([14,2,3], [12,3,4])
 screen._build_mode()
 var voice=screen._voices
 voice.last_time=-100000
 # Guarantee an eligible caption at the reaction point, independent of random silence.
 voice.random.seed=1
 var selected=[]
 voice.reaction.connect(func(role,line,seconds):selected.append([role,line,seconds]))
 screen._on_flip()
 var tries=0
 while screen._animating:
  if screen._battle.size()>0 and screen._battle.all(func(c):return not c.face_down) and selected.is_empty():
   voice.last_time=-100000
   for attempt in 100:
    if voice.react("deal_win",["mastermind"]):break
   assert(selected.size()==1)
   assert(selected[0][0]=="mastermind")
   assert(is_instance_valid(screen._speech_bubble))
   assert(not voice.player.playing)
  await process_frame
  tries+=1;assert(tries<1000)
 assert(screen._pile_top[0].rank==14)
 assert(selected[0][1] in screen._speech_bubble.get_child(0).get_child(0).get_children()[-1].text)
 await shot("voice-caption-muted")
 profile.voices="often";profile.sound_on=true;sfx.enabled=true
 voice.last_time=-100000
 for attempt in 100:
  if voice.react("set_complete"):break
 assert(voice.player.playing)
 assert(voice.last_clip.get_file().get_basename().split("_")[0] in ["amara","juno","lou","pip"])
 print("VOICE CAPTIONS OK: muted caption, matching speaker card, collected pile top, audible reaction")
 quit()
