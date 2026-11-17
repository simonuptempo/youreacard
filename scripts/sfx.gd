extends Node
## Sound effects and character voices. Autoloaded as "Sfx".
##
## Effects live in res://audio/sfx/<name>.wav and voices in res://audio/voice/<role>_<n>.wav
## (made by tools/make_audio.py). To use real recorded voices later, drop files named the
## same way into res://audio/voice_real/ (.wav, .ogg or .mp3): they're used instead.

## Ten lines per character. Lines 0-2 were recorded first; the rest play once their
## recordings are in res://audio/voice_real/<role>_<n>.ogg. Only recorded lines are used.
const LINES := {
	"you": ["I'm wild!", "Any gem you like!", "Count me in!", "Wild card, coming through!", "I fit right in.",
		"Call me whatever you need.", "Surprise!", "I go with everything.", "Did somebody need a gem?", "Deal me in!"],
	"pickpocket": ["Finders keepers!", "Mine now!", "Didn't see that coming!", "Thanks, I'll take that.", "Sticky fingers!",
		"Now it's in MY pocket.", "Oops, did I take that?", "Too slow!", "Easy pickings.", "Yoink!"],
	"trickster": ["Let's make a deal!", "Fair trade... ish!", "Swapsies!", "Trust me, it's a bargain.", "You'll thank me later.",
		"Everybody wins! Mostly me.", "A little switcheroo!", "No take-backs!", "Pleasure doing business.", "What a steal... I mean deal!"],
	"boss": ["Empty those pockets!", "Pay up, pal!", "Time to settle up.", "Let's see what you're hiding.", "Turn out those pockets.",
		"I'll just help myself.", "Nothing personal.", "You owe me.", "Cash on the table, please.", "The Boss always collects."],
	"mastermind": ["All according to plan.", "The whole set? Don't mind if I do.", "Checkmate.", "I planned this ten moves ago.", "Exactly as I predicted.",
		"Thank you for collecting these for me.", "Brilliant, if I do say so.", "Every piece in its place.", "You never stood a chance.", "The grand finale!"],
	"bouncer": ["Not on my watch!", "Nope. Blocked.", "You're not getting past me.", "Not tonight.", "Name's not on the list.",
		"Back it up.", "Denied.", "Nice try.", "This area's off limits.", "Move along."],
	"illusionist": ["Right back at you!", "Mirror, mirror!", "Now you see it...", "Ta-da!", "Look again!",
		"The trick's on you!", "Abracadabra!", "Was that meant for me?", "Return to sender!", "Smoke and mirrors!"],
	"trapper": ["Gotcha!", "Caught you red-handed!", "Snap!", "Walked right into it!", "Hook, line and sinker!",
		"Mine now, thank you!", "Watch your step!", "I set that trap ages ago.", "Caught one!", "Nobody escapes the Trapper!"],
	"locksmith": ["Click! It's open.", "No lock can stop me.", "Let's see what's inside.", "Child's play.", "Every lock has a key.",
		"Open sesame!", "Easy as one, two, click.", "What have we got here?", "Don't mind me.", "Locked? Not anymore."],
}
## The Boss has two cards; each gets its own lines.
const BOSS_LINES := {"shakedown": [0, 3, 4, 5, 6], "payup": [1, 2, 7, 8, 9]}
## The voice each character is recorded in, and its alternate (files named <role>_alt_<n>).
const VOICE := {"you": "", "pickpocket": "boy", "trickster": "woman", "boss": "man", "mastermind": "woman",
	"bouncer": "man", "illusionist": "woman", "trapper": "woman", "locksmith": "woman"}
const ALT_VOICE := {"boy": "girl", "girl": "boy", "woman": "man", "man": "woman"}
## How often characters speak (Settings: Often / Sometimes / Off).
const CHANCE := {"often": [0.75, 1.0], "sometimes": [0.35, 0.8], "off": [0.0, 0.0]}
const GEMS := ["ruby", "emerald", "sapphire", "topaz", "diamond", "amethyst"]

var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _cache := {}
var _last := {}
var _bags := {}          # role -> line numbers not used yet (no repeats until all are heard)
var _last_line := {}
var _last_speaker := ""
var _heard := {}         # characters who have spoken since the app opened


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


## Seconds left in the character line that's playing now (0 if none).
func voice_left() -> float:
	if _voice == null or not _voice.playing or _voice.stream == null:
		return 0.0
	return maxf(0.0, _voice.stream.get_length() - _voice.get_playback_position())


## Should this character speak now? Not every card gets a line, or it gets tiring:
## big moments (twists firing, a Grand Heist, your own recorded voice) usually do,
## everyday plays only sometimes, and the same character rarely twice in a row.
func should_speak(role: String, e: Dictionary, own_voice := false) -> bool:
	if role == "":
		return false
	# With voices off, characters still "speak" in speech bubbles, just silently.
	var mode := str(Profile.voices) if Profile.voices != "off" else "sometimes"
	var card := str(e.get("card", ""))
	var big := own_voice or card in CardDB.TRAPS or card == "grand"
	var chance: float = CHANCE.get(mode, CHANCE["sometimes"])[1 if big else 0]
	if not _heard.has(role):
		chance = 1.0  # everyone gets to introduce themselves once
	elif role == _last_speaker:
		chance *= 0.4
	return randf() < chance


## A character speaks: picks one of their lines, plays it, and returns it for the bubble.
## own_voice: the card shows your face and you recorded yourself (see VoiceRecorder).
## alt: use the character's other voice (<role>_alt_<n>), when those recordings exist.
func say(role: String, action := "", own_voice := false, alt := false) -> String:
	var i := pick_line(role, action, own_voice, alt)
	if i < 0:
		return ""
	play_line(role, i, own_voice, alt)
	return LINES[role][i]


## Choose which line a character says next (no sound). -1 if the role has no lines.
func pick_line(role: String, action := "", own_voice := false, alt := false, nana := false) -> int:
	if not LINES.has(role):
		return -1
	var allowed: Array = BOSS_LINES.get(action, range(LINES[role].size())) if role == "boss" else range(LINES[role].size())
	var pick_from: Array = []
	for src in _sources(role, own_voice, alt, nana):
		pick_from = allowed.filter(func(i): return src.call(i) != "")
		if not pick_from.is_empty():
			break
	if pick_from.is_empty():
		pick_from = allowed.filter(func(i): return i < 3)  # babble placeholders
	var i := _next_line(role + ("_alt" if alt else ""), pick_from)
	_heard[role] = true
	_last_speaker = role
	return i


## Play a chosen line out loud, unless voices are off in Settings.
func play_line(role: String, i: int, own_voice := false, alt := false, nana := false) -> void:
	if Profile.voices == "off" or i < 0:
		return
	var s: AudioStream = null
	for src in _sources(role, own_voice, alt, nana):
		var path: String = src.call(i)
		if path != "":
			s = AudioStreamWAV.load_from_file(path) if path.begins_with("user://") else _load(path)
			break
	if s == null:
		s = _load("res://audio/voice/%s_%d.wav" % [role, i])
	if s != null:
		_voice.stream = s
		_voice.play()


## Where a line's recording can come from, best first: your own voice, Nana Bea (when the
## Wild shows her), the character's other voice, then their regular voice (for the Wild, the
## androgynous one). Each returns the file path, or "" if missing.
func _sources(role: String, own_voice: bool, alt: bool, nana := false) -> Array:
	var out: Array = []
	if own_voice:
		out.append(func(i): var p := "user://voices/%s_%d.wav" % [role, i]; return p if FileAccess.file_exists(p) else "")
	if nana and role == "you":
		out.append(func(i): return _real_path("you_nana_%d" % i))
	if alt:
		out.append(func(i): return _real_path("%s_alt_%d" % [role, i]))
	out.append(func(i): return _real_path("%s_%d" % [role, i]))
	return out


## The recorded file for a line in res://audio/voice_real, or "" if it isn't there.
func _real_path(stem: String) -> String:
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://audio/voice_real/%s.%s" % [stem, ext]
		if _load(p) != null:
			return p
	return ""


## Deal lines from a shuffled bag so none repeats until the others have been heard.
func _next_line(key: String, options: Array) -> int:
	var bag: Array = _bags.get(key, []).filter(func(i): return i in options)
	if bag.is_empty():
		bag = options.duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag[0] == _last_line.get(key, -1):
			bag.reverse()
	var i: int = bag.pop_front()
	_bags[key] = bag
	_last_line[key] = i
	return i


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
