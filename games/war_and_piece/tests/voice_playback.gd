extends SceneTree
func _initialize():run.call_deferred()
func run():
 var profile=root.get_node("Profile")
 var sfx=root.get_node("Sfx")
 var old_mode=profile.voices
 var old_sound=profile.sound_on
 profile.voices="often";profile.sound_on=true;sfx.enabled=true
 var voice=load("res://games/war_and_piece/scripts/war_voice.gd").new()
 root.add_child(voice)
 var catalog=load("res://games/war_and_piece/scripts/war_voice_catalog.gd")
 assert(catalog.CLIPS.size()==80)
 var paths={}
 for clip in catalog.CLIPS:
  assert(not paths.has(clip.path));paths[clip.path]=true
  var stream=AudioStreamMP3.load_from_file(clip.path)
  assert(stream!=null and stream.get_length()>0)
  assert(clip in voice.candidates(clip.event))
 for event in ["deal_win","war_start","war_again","war_win","game_start","heist_success","shield_block","set_complete","game_win","game_complete"]:
  var success=false
  for attempt in 100:
   voice.last_time=-100000
   if voice.react(event):success=true;break
  assert(success)
  assert(not voice.react(event)) # playing: no overlap
  voice.player.stop();sfx._voice.stop()
  assert(not voice.react(event)) # cooldown still applies
  voice.last_time=-100000
 profile.voices="off"
 voice.last_time=-100000
 var silent=false
 for attempt in 100:
  if voice.react("war_win"):silent=true;break
 assert(silent and not voice.player.playing)
 profile.voices="often";profile.sound_on=false
 voice.last_time=-100000
 silent=false
 for attempt in 100:
  if voice.react("war_win"):silent=true;break
 assert(silent and not voice.player.playing)
 profile.sound_on=true
 var previous=""
 for i in 20:
  voice.last_time=-100000
  for attempt in 100:
   if voice.react("deal_win"):break
  assert(voice.last_clip!=previous)
  previous=voice.last_clip
  voice.player.stop()
 profile.voices=old_mode;profile.sound_on=old_sound
 print("VOICE PLAYBACK OK: 80 decodable clips, all events reachable, cooldown, mute, overlap guard, no immediate repeats")
 quit()
