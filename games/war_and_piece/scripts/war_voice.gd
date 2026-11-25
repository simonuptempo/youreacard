extends Node
## One voice channel per game, no queued stale reactions, no immediate repeats.
signal reaction(role: String, text: String, seconds: float)
const Catalog = preload("res://games/war_and_piece/scripts/war_voice_catalog.gd")
var player: AudioStreamPlayer
var last_time := -100000
var recent: Array = []
var last_role := ""
var last_clip := ""
var war_reactions_enabled := true
var random := RandomNumberGenerator.new()

func _ready() -> void:
 random.randomize()
 player = AudioStreamPlayer.new()
 player.volume_db = 0.0
 add_child(player)

func _process(_delta: float) -> void:
 if player.playing and (not Sfx.enabled or not Profile.sound_on or Profile.voices == "off"):
  player.stop()
 if last_clip == "dev" and (not Sfx.enabled or not Profile.sound_on or Profile.voices == "off") and Sfx.voice_left() > 0:
  Sfx._voice.stop()

func stop_quotes() -> void:
 player.stop()
 if last_clip == "dev" and Sfx.voice_left() > 0:
  Sfx._voice.stop()

func candidates(event: String) -> Array:
 return Catalog.CLIPS.filter(func(c): return c.caption_ready and (c.event == event or (event == "game_win" and c.event == "game_complete")))

func react(event: String, allowed_roles: Array = []) -> bool:
 if not war_reactions_enabled and event in ["game_start", "deal_win", "war_start", "war_again", "war_win"]: return false
 var audible: bool = Sfx.enabled and Profile.sound_on and Profile.voices != "off"
 if player.playing or Sfx.voice_left() > 0: return false
 var often: bool = Profile.voices == "often"
 var now := Time.get_ticks_msec()
 if now - last_time < (8000 if often else 12000): return false
 var big := event in ["war_win", "set_complete", "shield_block", "game_win", "game_complete"]
 var chance := (0.9 if big else 0.6) if often else (0.7 if big else 0.3)
 if random.randf() >= chance: return false
 # Keep Dev in the shield rotation, alongside the four new character reactions.
 if event == "shield_block" and random.randf() < 0.25:
  var own := VoiceRecorder.has_voice("bouncer")
  var alt := bool(Profile.voice_alt.get("bouncer", false))
  var index: int = Sfx.pick_line("bouncer", "", own, alt)
  if index < 0: return false
  var said: String = Sfx.LINES["bouncer"][index]
  if audible: Sfx.play_line("bouncer", index, own, alt)
  if said == "": return false
  last_time = now
  last_role = "bouncer"
  last_clip = "dev"
  reaction.emit("bouncer", said, maxf(3.5, Sfx.voice_left()))
  return true
 var pool := candidates(event)
 if not allowed_roles.is_empty(): pool = pool.filter(func(c): return c.role in allowed_roles)
 var fresh := pool.filter(func(c): return c.path not in recent)
 if fresh.is_empty(): fresh = pool.filter(func(c): return c.path != last_clip)
 if fresh.is_empty(): return false
 var other := fresh.filter(func(c): return c.role != last_role)
 if not other.is_empty(): fresh = other
 var clip: Dictionary = fresh[random.randi_range(0, fresh.size()-1)]
 # Custom War-and-Piece recordings must use the event-specific filename.
 # Never substitute Gem Heist prompts for a different game's situation.
 var custom := "user://voices/war_and_piece/" + str(clip.path).get_file().get_basename() + ".wav"
 var stream: AudioStream
 if FileAccess.file_exists(custom): stream = AudioStreamWAV.load_from_file(custom)
 elif ResourceLoader.exists(clip.path): stream = load(clip.path)
 else: stream = AudioStreamMP3.load_from_file(clip.path)
 if stream == null: return false
 player.stream = stream
 if audible: player.play()
 last_time = now
 last_role = clip.role
 last_clip = clip.path
 reaction.emit(clip.role, clip.text, maxf(stream.get_length(), clampf(clip.text.length() / 15.0, 3.5, 7.0)))
 recent.append(clip.path)
 if recent.size() > 10: recent.pop_front()
 return true
