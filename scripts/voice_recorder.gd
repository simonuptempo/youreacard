class_name VoiceRecorder
extends Control
## "Record your voice" for a card. You read that character's ten lines; when the card is
## played on this phone, it speaks in your voice (any lines you skip use the regular voice).
## Recordings stay on this device (user://voices) and are never uploaded.

signal closed

const MAX_SECONDS := 3.0
const BUS := "VoiceRecord"

var slot := "you"
var _rec: AudioEffectRecord
var _mic: AudioStreamPlayer
var _player: AudioStreamPlayer
var _recording := -1          # which line is recording, or -1
var _elapsed := 0.0
var _rows: Array = []         # [{status: Label, rec: Button, play: Button}]
var _note: Label
var _alt_btn: Button


static func path_for(s: String, i: int) -> String:
	return "user://voices/%s_%d.wav" % [s, i]


const LINE_COUNT := 10


static func recorded_count(s: String) -> int:
	var n := 0
	for i in LINE_COUNT:
		if FileAccess.file_exists(path_for(s, i)):
			n += 1
	return n


static func has_voice(s: String) -> bool:
	for i in LINE_COUNT:
		if FileAccess.file_exists(path_for(s, i)):
			return true
	return false


static func clear_voice(s: String) -> void:
	for i in LINE_COUNT:
		if FileAccess.file_exists(path_for(s, i)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(s, i)))


## Cards that talk: your wild and the eight characters (bills don't speak).
static func speaks(s: String) -> bool:
	return Sfx.LINES.has(s)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_audio()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	add_child(UI.panel(Vector2(30, 150), Vector2(660, 980), UI.PANEL, 24))
	var who := Profile.face_name(slot)
	add_child(UI.label("Your voice", Vector2(30, 176), Vector2(660, 54), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.label("%s says one of these when the card is played. Read them with lots of character! Skip any you like." % who,
		Vector2(60, 232), Vector2(600, 84), 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var lines: Array = Sfx.LINES[slot]
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50, 326)
	scroll.size = Vector2(620, 524)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(610, 0)
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for i in lines.size():
		var row := Control.new()
		row.custom_minimum_size = Vector2(600, 150)
		list.add_child(row)
		row.add_child(UI.panel(Vector2(0, 0), Vector2(600, 150), Color("#1d2547"), 18))
		row.add_child(UI.label("%d.  “%s”" % [i + 1, lines[i]], Vector2(16, 8), Vector2(568, 44), 25, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var status := UI.label("", Vector2(16, 50), Vector2(568, 28), 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		row.add_child(status)
		var rec := UI.button("● Record", Vector2(30, 84), Vector2(260, 54), Color("#c0392b"), 21)
		rec.pressed.connect(_toggle_record.bind(i))
		row.add_child(rec)
		var play := UI.button("▶ Play", Vector2(310, 84), Vector2(260, 54), Color("#3a4166"), 21)
		play.pressed.connect(_play.bind(i))
		row.add_child(play)
		_rows.append({"status": status, "rec": rec, "play": play})
	# Without your own recordings, the card can use the character's other voice instead.
	var regular: String = Sfx.VOICE.get(slot, "")
	if Sfx.ALT_VOICE.has(regular):
		_alt_btn = UI.button("", Vector2(60, 860), Vector2(600, 56), Color("#2f3866"), 20)
		_alt_btn.pressed.connect(_toggle_alt)
		add_child(_alt_btn)
		_update_alt()
	_note = UI.label("Your recordings stay on this phone. Online opponents hear the regular voices.", Vector2(60, 924), Vector2(600, 56), 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_note)
	var reset := UI.button("Use the regular voice", Vector2(60, 990), Vector2(290, 70), Color("#3a4166"), 20)
	reset.pressed.connect(_use_default)
	add_child(reset)
	var done := UI.button("Done", Vector2(370, 990), Vector2(290, 70), UI.ACCENT, 26)
	done.add_theme_color_override("font_color", Color("#1b2038"))
	done.pressed.connect(_close)
	add_child(done)
	_refresh()


func _toggle_alt() -> void:
	if Profile.voice_alt.get(slot, false):
		Profile.voice_alt.erase(slot)
	else:
		Profile.voice_alt[slot] = true
	Profile.save_profile()
	_update_alt()


func _update_alt() -> void:
	var regular: String = Sfx.VOICE.get(slot, "")
	var using: String = Sfx.ALT_VOICE[regular] if Profile.voice_alt.get(slot, false) else regular
	_alt_btn.text = "Regular voice: %s's  ·  tap to switch" % using.capitalize()


func _setup_audio() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.add_bus_effect(idx, AudioEffectRecord.new())
		AudioServer.set_bus_mute(idx, true)  # record the mic without playing it back
	_rec = AudioServer.get_bus_effect(idx, 0) as AudioEffectRecord
	_mic = AudioStreamPlayer.new()
	_mic.bus = BUS
	add_child(_mic)
	_player = AudioStreamPlayer.new()
	add_child(_player)


func _refresh() -> void:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var have := FileAccess.file_exists(path_for(slot, i))
		var rec: Button = r["rec"]
		var play: Button = r["play"]
		if _recording == i:
			rec.text = "■ Stop"
			r["status"].text = "Recording… %.1f s" % maxf(0.0, MAX_SECONDS - _elapsed)
		else:
			rec.text = "● Record again" if have else "● Record"
			r["status"].text = "Recorded ✓" if have else "Not recorded yet"
		rec.disabled = _recording >= 0 and _recording != i
		play.disabled = not have or _recording >= 0


func _toggle_record(i: int) -> void:
	if _recording == i:
		_stop()
		return
	_player.stop()
	_recording = i
	_elapsed = 0.0
	_mic.stream = AudioStreamMicrophone.new()
	_mic.play()
	_rec.set_recording_active(true)
	_refresh()


func _process(delta: float) -> void:
	if _recording < 0:
		return
	_elapsed += delta
	if _elapsed >= MAX_SECONDS:
		_stop()
	else:
		_refresh()


func _stop() -> void:
	var i := _recording
	_recording = -1
	_rec.set_recording_active(false)
	var wav: AudioStreamWAV = _rec.get_recording()
	_mic.stop()
	if wav == null or wav.data.size() < 4000 or not _clean(wav):
		_note.text = "Didn't hear anything. Check that Gem Heist is allowed to use the microphone, then try again."
		_note.add_theme_color_override("font_color", Color("#ff9f8f"))
		_refresh()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://voices"))
	wav.save_to_wav(path_for(slot, i))
	_refresh()
	_play(i)


## Trims the silence at both ends and evens out the volume. Returns false if it's all silence.
func _clean(wav: AudioStreamWAV) -> bool:
	if wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return true
	var ch := 2 if wav.stereo else 1
	var d := wav.data
	var n := d.size() / 2
	var peak := 0
	for k in n:
		peak = maxi(peak, absi(d.decode_s16(k * 2)))
	if peak < 600:
		return false
	var gate := int(peak * 0.08)
	var first := 0
	while first < n and absi(d.decode_s16(first * 2)) < gate:
		first += 1
	var last := n - 1
	while last > first and absi(d.decode_s16(last * 2)) < gate:
		last -= 1
	var pad := int(wav.mix_rate * 0.06) * ch
	first = maxi(0, first - pad)
	last = mini(n - 1, last + pad)
	first -= first % ch
	var gain := minf(4.0, 29000.0 / peak)
	var out := PackedByteArray()
	out.resize((last - first + 1) * 2)
	for k in range(first, last + 1):
		out.encode_s16((k - first) * 2, clampi(int(d.decode_s16(k * 2) * gain), -32767, 32767))
	wav.data = out
	return true


func _play(i: int) -> void:
	var s := AudioStreamWAV.load_from_file(path_for(slot, i))
	if s:
		_player.stream = s
		_player.play()


func _use_default() -> void:
	clear_voice(slot)
	_note.text = "Back to the regular voice."
	_refresh()


func _close() -> void:
	if _recording >= 0:
		_stop()
	closed.emit()
	queue_free()
