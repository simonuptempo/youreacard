extends Node
## Sound effects and character voices. Autoloaded as "Sfx".
##
## Effects live in res://audio/sfx/<name>.wav and voices in res://audio/voice/<role>_<n>.wav
## (made by tools/make_audio.py). To use real recorded voices later, drop files named the
## same way into res://audio/voice_real/ (.wav, .ogg or .mp3): they're used instead.

const LINES := {
	"you": ["I'm wild!", "Any gem you like!", "Count me in!"],
	"pickpocket": ["Finders keepers!", "Mine now!", "Didn't see that coming!"],
	"trickster": ["Let's make a deal!", "Fair trade... ish!", "Swapsies!"],
	"boss": ["Empty those pockets!", "Pay up, pal!", "Time to settle up."],
	"mastermind": ["All according to plan.", "The whole set? Don't mind if I do.", "Checkmate."],
	"bouncer": ["Not on my watch!", "Nope. Blocked.", "You're not getting past me."],
	"illusionist": ["Right back at you!", "Mirror, mirror!", "Now you see it..."],
	"trapper": ["Gotcha!", "Caught you red-handed!", "Snap!"],
	"locksmith": ["Click! It's open.", "No lock can stop me.", "Let's see what's inside."],
}
## The Boss has two cards; each gets its own lines.
const BOSS_LINES := {"shakedown": [0], "payup": [1, 2]}
const GEMS := ["ruby", "emerald", "sapphire", "topaz", "diamond", "amethyst"]

var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _cache := {}
var _last := {}


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	add_child(_voice)
	enabled = Profile.sound_on


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = s
	return s


## Play an effect by name. The same effect won't stack on itself within 60 ms.
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled or name == "":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 60:
		return
	_last[name] = now
	var s := _load("res://audio/sfx/%s.wav" % name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	_players[0].stream = s
	_players[0].play()


## A character speaks: plays their voice and returns the line to show in a speech bubble.
## own_voice: the card shows your face and you recorded yourself (see VoiceRecorder).
func say(role: String, action := "", own_voice := false) -> String:
	if not LINES.has(role):
		return ""
	var options: Array = BOSS_LINES.get(action, [0, 1, 2]) if role == "boss" else [0, 1, 2]
	var i: int = options[randi() % options.size()]
	if enabled:
		var s: AudioStream = null
		var mine := "user://voices/%s_%d.wav" % [role, i]
		if own_voice and FileAccess.file_exists(mine):
			s = AudioStreamWAV.load_from_file(mine)  # not cached, so re-recordings take effect
		for ext in ["wav", "ogg", "mp3"]:
			if s != null:
				break
			s = _load("res://audio/voice_real/%s_%d.%s" % [role, i, ext])
			if s != null:
				break
		if s == null:
			s = _load("res://audio/voice/%s_%d.wav" % [role, i])
		if s != null:
			_voice.stream = s
			_voice.play()
	return LINES[role][i]


## The effect that fits a game event (from GameState.events).
func for_event(e: Dictionary, viewer := 0) -> String:
	var text := str(e.get("text", ""))
	var card := str(e.get("card", ""))
	if text.ends_with("and won!"):
		return "win" if int(e.get("p", 0)) == viewer else "lose"
	if text.contains("Set complete!"):
		return "set_complete"
	if card in GEMS:
		if text.contains(" pawned "):
			return "pawn"
		if text.contains(" added a"):
			return "payup"
		return "gem"
	if card.begins_with("loot"):
		return "bank"
	match card:
		"wild": return "wild"
		"swipe": return "steal"
		"swap": return "trade"
		"shakedown", "payup", "grand", "shield", "mirror", "snare", "lockpick", "lucky":
			return card
	if text.contains(" paid ") or text.contains("Paying what's owed"):
		return "pay"
	if text.contains(" drew "):
		return "draw"
	if text.contains("to the vault") or text.contains("back from the vault"):
		return "vault"
	if text.contains("discarded"):
		return "draw"
	return ""


func play_event(e: Dictionary, viewer := 0) -> void:
	play(for_event(e, viewer))


## Which character speaks for an event, or "" for none. A character speaks when their card
## is played: heists, twists, Lockpick, and a Wild going into a set.
func speaker(e: Dictionary) -> String:
	var card := str(e.get("card", ""))
	var text := str(e.get("text", ""))
	if card == "wild":
		return "you" if text.contains("played a Wild") else ""
	if not e.get("big", false):
		return ""
	if card in CardDB.HEISTS:
		# Heists make two events (the play, then the result); speak on the play only.
		return CardDB.role_of(card) if text.contains(" played ") else ""
	if card in CardDB.TRAPS or card == "lockpick":
		return CardDB.role_of(card)
	return ""
