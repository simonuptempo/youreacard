class_name VoiceRecorder
extends Control
## "Record your voice" for a card you've put your face on. You read that character's three
## lines; when the card is played on this phone, it speaks in your voice.
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


static func path_for(s: String, i: int) -> String:
	return "user://voices/%s_%d.wav" % [s, i]


static func has_voice(s: String) -> bool:
	for i in 3:
		if FileAccess.file_exists(path_for(s, i)):
			return true
	return false


static func clear_voice(s: String) -> void:
	for i in 3:
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
	add_child(UI.label("%s says these when the card is played. Read each one out loud, with lots of character!" % who,
		Vector2(70, 236), Vector2(580, 80), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var lines: Array = Sfx.LINES[slot]
	for i in lines.size():
		var y := 340.0 + i * 190.0
		add_child(UI.panel(Vector2(60, y), Vector2(600, 170), Color("#1d2547"), 18))
		add_child(UI.label("“%s”" % lines[i], Vector2(80, y + 12), Vector2(560, 50), 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var status := UI.label("", Vector2(80, y + 62), Vector2(560, 30), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(status)
		var rec := UI.button("● Record", Vector2(90, y + 100), Vector2(260, 56), Color("#c0392b"), 22)
		rec.pressed.connect(_toggle_record.bind(i))
		add_child(rec)
		var play := UI.button("▶ Play", Vector2(370, y + 100), Vector2(260, 56), Color("#3a4166"), 22)
		play.pressed.connect(_play.bind(i))
		add_child(play)
		_rows.append({"status": status, "rec": rec, "play": play})
	_note = UI.label("Your recordings stay on this phone. Online opponents hear the regular voices.", Vector2(60, 920), Vector2(600, 56), 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_note)
	var reset := UI.button("Use the regular voice", Vector2(60, 990), Vector2(290, 70), Color("#3a4166"), 20)
	reset.pressed.connect(_use_default)
	add_child(reset)
	var done := UI.button("Done", Vector2(370, 990), Vector2(290, 70), UI.ACCENT, 26)
	done.add_theme_color_override("font_color", Color("#1b2038"))
	done.pressed.connect(_close)
	add_child(done)
	_refresh()


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
