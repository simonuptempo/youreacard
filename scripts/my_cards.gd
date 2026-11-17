extends Control
## "Are you a card? Join the crew!" One screen for every card with a face: the nine crew
## characters and the five bill critters. Tap a card to preview it big at the top, then give it
## your name, a photo (turned into a cartoon), your voice, and a new look.
## Opened from the main menu, Settings, the first-run steps and the tutorial; Profile.edit_slot
## picks the card that starts selected, Profile.creator_return where Back goes.

const SLOTS := ["you", "pickpocket", "trickster", "boss", "mastermind", "bouncer", "illusionist", "trapper", "locksmith",
	"bill1", "bill2", "bill3", "bill4", "bill5"]
const GRID_CARD := Vector2(180, 252)
const RIGHT_X := 292.0
const RIGHT_W := 400.0
const CARD_TOP := 128.0
const CARD_SIZE := Vector2(240, 336)

## "Change the look": the same options as the character builder. The server only accepts these.
const COLORS := ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Navy", "Purple", "Pink", "Brown", "Black", "White", "Gray"]
const PERSON_LOOKS := [
	["hair", "Hair", AvatarView.HAIR_NAMES],
	["hair_color", "Hair color", ["Black", "Dark brown", "Brown", "Light brown", "Auburn", "Red", "Blonde", "Platinum blonde",
		"Gray", "White", "Blue", "Pink", "Purple", "Green"]],
	["facial", "Facial hair", AvatarView.FACIAL_NAMES],
	["hat", "Hat", AvatarView.HAT_NAMES],
	["head", "Head covering", AvatarView.HEAD_NAMES],
	["eyewear", "Glasses", AvatarView.EYEWEAR_NAMES],
	["ears", "Ears", AvatarView.EAR_NAMES],
	["shirt", "Outfit", AvatarView.SHIRT_NAMES],
	["shirt_color", "Outfit color", COLORS],
	["bowtie", "Bow tie", ["None", "Bow tie"]],
	["braces", "Braces", ["None", "Braces"]],
	["details", "Face details", AvatarView.DETAIL_NAMES],
]
const PET_LOOKS := [
	["hat", "Hat", AvatarView.HAT_NAMES],
	["eyewear", "Glasses", AvatarView.EYEWEAR_NAMES],
	["collar", "Collar", AvatarView.COLLAR_NAMES],
	["collar_color", "Collar color", COLORS],
]

var _slot := "you"
var _preview: CardView
var _name_edit: LineEdit
var _camera_btn: Button
var _upload_btn: Button
var _voice_btn: Button
var _look_btn: Button
var _reset_btn: Button
var _badges := {}           # slot -> the "YOU" badge on its grid card
var _status: Label
var _heading: Label
var _scroll: ScrollContainer
var _frames := {}            # slot -> the gold frame behind its grid card
var _grid_cards := {}        # slot -> CardView
var _busy_slot := ""         # the card whose cartoon is being made
var _photo_slot := ""        # the card a photo was asked for
var _originals := {}         # slot -> the photo as taken (this visit only), to remake the cartoon
var _picker_pending := false
var _selfie := false         # the photo being taken is a selfie: that card becomes yours
var _sheet: Control
var _edits := {}             # pending look changes
var _look_cat := 0


func _ready() -> void:
	theme = UI.make_theme()
	_slot = Profile.edit_slot if Profile.edit_slot in SLOTS else "you"
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := Button.new()
	back.position = Vector2(20, 24)
	back.size = Vector2(68, 68)
	back.add_theme_stylebox_override("normal", UI.box(Color("#2f3866"), 34))
	back.add_theme_stylebox_override("hover", UI.box(Color("#3a4580"), 34))
	back.pressed.connect(_leave)
	back.add_child(Icon.make("back", Vector2(16, 16), Vector2(36, 36)))
	add_child(back)
	add_child(UI.label("Are you a card?  Join the crew!", Vector2(96, 28), Vector2(600, 60), 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	_preview = CardView.new()
	_preview.position = Vector2(28, CARD_TOP)
	_preview.size = CARD_SIZE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)

	_heading = UI.label("Make this your card", Vector2(RIGHT_X, CARD_TOP), Vector2(RIGHT_W, 40), 27, UI.ACCENT)
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_heading)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(RIGHT_X, 154)
	_name_edit.size = Vector2(RIGHT_W, 64)
	_name_edit.max_length = 14
	_name_edit.add_theme_font_size_override("font_size", 26)
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("#f4f1ea"), 12))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("#ffffff"), 12, UI.ACCENT, 2))
	_name_edit.add_theme_color_override("font_color", UI.BG)
	_name_edit.add_theme_color_override("font_placeholder_color", Color("#777785"))
	_name_edit.text_changed.connect(_name_changed)
	_name_edit.text_submitted.connect(func(_t): _name_edit.release_focus())
	add_child(_name_edit)

	_camera_btn = _icon_button("camera", "Take a selfie", Vector2(RIGHT_X, 230))
	_camera_btn.pressed.connect(_take_photo)
	_upload_btn = _icon_button("photos", "Upload a photo", Vector2(RIGHT_X + RIGHT_W / 2 + 6, 230))
	_upload_btn.pressed.connect(_choose_photo)

	_voice_btn = UI.button("", Vector2(RIGHT_X, 346), Vector2(RIGHT_W, 56), Color("#c0392b"), 21)
	_voice_btn.pressed.connect(_record_voice)
	_voice_btn.add_child(Icon.make("mic", Vector2(14, 10), Vector2(36, 36)))
	add_child(_voice_btn)
	_look_btn = UI.button("     Change the look", Vector2(28, 0), Vector2(326, 52), Color("#7a4fd6"), 21)
	_look_btn.pressed.connect(_open_look)
	_look_btn.add_child(Icon.make("wand", Vector2(14, 10), Vector2(36, 36)))
	add_child(_look_btn)
	_reset_btn = UI.button("", Vector2(366, 0), Vector2(326, 52), Color("#2f3866"), 19)
	_reset_btn.pressed.connect(_reset_card)
	add_child(_reset_btn)

	_status = UI.label("", Vector2(28, 526), Vector2(664, 36), 19, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := Control.new()
	scroll.add_child(page)
	var gap := (720.0 - 3 * GRID_CARD.x) / 4.0
	for i in SLOTS.size():
		var s: String = SLOTS[i]
		var pos := Vector2(gap + (i % 3) * (GRID_CARD.x + gap), 12 + int(i / 3) * (GRID_CARD.y + 22))
		var frame := UI.panel(pos - Vector2(7, 7), GRID_CARD + Vector2(14, 14), UI.ACCENT, 18)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(frame)
		_frames[s] = frame
		var cv := CardView.new()
		cv.position = pos
		cv.size = GRID_CARD
		page.add_child(cv)
		cv.tapped.connect(func(_v): _select(s))
		_grid_cards[s] = cv
		var badge := UI.panel(pos + Vector2(-10, -12), Vector2(66, 30), Color("#e84d8a"), 15)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bl := UI.label("YOU", Vector2.ZERO, Vector2(66, 30), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(bl)
		page.add_child(badge)
		_badges[s] = badge
		_refresh_grid_card(s)
	page.custom_minimum_size = Vector2(720, 12 + ceili(SLOTS.size() / 3.0) * (GRID_CARD.y + 22) + 40)
	_select(_slot)


func _icon_button(icon: String, text: String, pos: Vector2) -> Button:
	var w := RIGHT_W / 2 - 6
	var b := UI.button("", pos, Vector2(w, 104), UI.PANEL, 18)
	b.add_child(Icon.make(icon, Vector2(w / 2 - 27, 10), Vector2(54, 54)))
	var l := UI.label(text, Vector2(0, 66), Vector2(w, 32), 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.set_meta("label", l)
	add_child(b)
	return b


# ------------------------------------------------------------------ which card

func kind_for(slot: String) -> String:
	return Profile.slot_kind(slot)


func _is_pet(slot: String) -> bool:
	return slot.begins_with("bill")


## The original character's name: "Pip", "Nana Bea", or the bill's critter.
func _original_name(slot: String) -> String:
	if Profile.CRITTER_NAMES.has(slot):
		return "the " + str(Profile.CRITTER_NAMES[slot])
	return str(Profile.cast_for_role(slot)["name"])


func _has_photo(slot: String) -> bool:
	return str(Profile.slot_face(slot).get("portrait_path", "")).begins_with("user://")


func _select(slot: String) -> void:
	_slot = slot
	Profile.edit_slot = slot
	for s in _frames:
		_frames[s].visible = s == slot
	var custom_name := str(Profile.slots.get(slot, {}).get("name", ""))
	if slot == Profile.me_slot and custom_name == "":
		custom_name = Profile.display_name
	_name_edit.set_block_signals(true)
	_name_edit.text = custom_name
	_name_edit.set_block_signals(false)
	_name_edit.placeholder_text = "Your pet's name" if _is_pet(slot) else ("Your name" if slot == Profile.me_slot else "Name (or keep %s)" % _original_name(slot))
	if _busy_slot == "":
		_status.text = ""
	_refresh()


## Everything on the top half, for the selected card.
func _refresh() -> void:
	var busy := _busy_slot != ""
	_camera_btn.get_meta("label").text = "Take a photo" if _is_pet(_slot) else "Take a selfie"
	_camera_btn.disabled = busy
	_upload_btn.disabled = busy
	_voice_btn.visible = VoiceRecorder.speaks(_slot)
	if _voice_btn.visible:
		var n := VoiceRecorder.recorded_count(_slot)
		_voice_btn.text = "     Record your voice" if n == 0 else "     Your voice: %d of %d lines" % [n, VoiceRecorder.LINE_COUNT]
	_look_btn.visible = _has_photo(_slot)
	_look_btn.disabled = busy
	_reset_btn.visible = Profile.is_custom(_slot) and _busy_slot != _slot
	_reset_btn.text = "Change back to %s" % _original_name(_slot)
	for b in _badges:
		_badges[b].visible = b == Profile.me_slot
	_layout()
	_refresh_preview()


## The right-hand rows fill exactly the card's height (top of the heading to the bottom of the
## last row). Change the look / Change back sit in one row under the card, then the status line,
## then the grid of cards.
func _layout() -> void:
	var rows: Array = [_heading, _name_edit, _camera_btn]
	if _voice_btn.visible:
		rows.append(_voice_btn)
	var used := 0.0
	for r in rows:
		used += r.size.y
	var gap := minf(40.0, (CARD_SIZE.y - used) / (rows.size() - 1))
	var y := CARD_TOP
	if gap == 40.0:
		y += (CARD_SIZE.y - used - gap * (rows.size() - 1)) / 2.0   # fewer rows: centered beside the card
	for r in rows:
		r.position.y = y
		if r == _camera_btn:
			_upload_btn.position.y = y
		y += r.size.y + gap
	y = CARD_TOP + CARD_SIZE.y + 22.0
	var extras: Array = [_look_btn, _reset_btn].filter(func(b): return b.visible)
	for k in extras.size():
		var b: Button = extras[k]
		b.position = Vector2(28 + k * 338, y)
		b.size.x = 664.0 if extras.size() == 1 else 326.0
	if not extras.is_empty():
		y += 52.0 + 12.0
	if _status.text != "":
		_status.position.y = y
		_status.size.y = 32.0
		y += 36.0
	y += 16.0   # breathing room above the first row of cards
	_scroll.position = Vector2(0, y)
	_scroll.size = Vector2(720, 1280 - y)


func _card_name(slot: String, typed: String) -> String:
	var role := CardDB.role_of(kind_for(slot))
	if role != "" and role != "you":
		var title: String = CardDB.ROLE_TITLES[role]
		return title if typed == "" else "%s the %s" % [typed, title.trim_prefix("The ")]
	return typed


func _refresh_preview() -> void:
	var typed := _name_edit.text.strip_edges()
	_preview.preview_name = _card_name(_slot, typed) if typed != "" else ""
	if _slot == "you" and not Profile.is_custom("you"):
		_preview.preview_name = ""   # the regular Wild is Nana Bea until it has your photo
	_preview.setup({"id": 0, "kind": kind_for(_slot)}, Profile.slot_face(_slot))
	if _preview._overlay != null and _is_pet(_slot):
		_preview._overlay.name_text = typed
		_preview._overlay.queue_redraw()


func _refresh_grid_card(slot: String) -> void:
	var cv: CardView = _grid_cards[slot]
	cv.setup({"id": SLOTS.find(slot), "kind": kind_for(slot)}, Profile.slot_face(slot))
	cv.editable = true


# ------------------------------------------------------------------ name

func _name_changed(text: String) -> void:
	var typed := text.strip_edges()
	if Profile.is_custom(_slot):
		Profile.set_slot(_slot, Profile.slot_face(_slot), typed)
		_refresh_grid_card(_slot)
	if _slot == Profile.me_slot:
		Profile.display_name = typed
		Profile.save_profile()
	_refresh_preview()


# ------------------------------------------------------------------ photos

func _native() -> Object:
	if Engine.has_singleton("NativePhotos"):
		var n := Engine.get_singleton("NativePhotos")
		if n.call("is_available"):
			if not n.is_connected("photo_ready", _native_photo):
				n.connect("photo_ready", _native_photo)
				n.connect("photo_failed", _native_failed)
			return n
	return null


func _take_photo() -> void:
	_photo_slot = _slot
	_selfie = not _is_pet(_slot)
	var n := _native()
	if n != null:
		# People: the selfie camera. Pets: the camera on the back.
		n.call("take_photo", not _is_pet(_slot))
		return
	if OS.has_feature("web"):
		_web_photo_picker("environment" if _is_pet(_slot) else "user")
		return
	var camera := preload("res://scripts/selfie_capture.gd").new()
	camera.size = Vector2(720, 1280)
	add_child(camera)
	camera.captured.connect(func(image: Image): _got_photo(image))


func _choose_photo() -> void:
	_photo_slot = _slot
	_selfie = false
	var n := _native()
	if n != null:
		n.call("pick_photo")
		return
	if OS.has_feature("web"):
		_web_photo_picker("")
		return
	if _picker_pending:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_say("Uploading photos isn't available here. Try Take a selfie.", true)
		return
	_picker_pending = true
	var error := DisplayServer.file_dialog_show(
		"Choose a photo", OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Photos;image/png,image/jpeg,image/webp"]),
		_picker_finished, get_window().get_window_id())
	if error != OK:
		_picker_pending = false
		_say("Couldn't open your photos. Try Take a selfie.", true)


## In a browser: the page's own photo picker. capture "user" opens the selfie camera on a
## phone, "environment" the back camera; "" lets you choose a photo.
var _web_callback = null

func _web_photo_picker(capture: String) -> void:
	if _web_callback == null:
		_web_callback = JavaScriptBridge.create_callback(_web_photo_ready)
		var window = JavaScriptBridge.get_interface("window")
		window.gemHeistPhoto = _web_callback
	JavaScriptBridge.eval("""
		(function (capture) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*';
			if (capture) input.setAttribute('capture', capture);
			input.onchange = function () {
				var file = input.files && input.files[0];
				if (!file) return;
				var reader = new FileReader();
				reader.onload = function () {
					var data = String(reader.result);
					window.gemHeistPhoto(data.substring(data.indexOf(',') + 1), file.type || '');
				};
				reader.readAsDataURL(file);
			};
			input.click();
		})(%s);
	""" % JSON.stringify(capture))


func _web_photo_ready(args: Array) -> void:
	if args.size() < 1:
		return
	var bytes := Marshalls.base64_to_raw(str(args[0]))
	var mime := str(args[1]) if args.size() > 1 else ""
	if bytes.size() > 25 * 1024 * 1024:
		_say("Please choose a photo smaller than 25 MB.", true)
		return
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if mime.contains("png"):
		err = img.load_png_from_buffer(bytes)
	elif mime.contains("webp"):
		err = img.load_webp_from_buffer(bytes)
	else:
		err = img.load_jpg_from_buffer(bytes)
	if err != OK:
		for loader in [img.load_jpg_from_buffer, img.load_png_from_buffer, img.load_webp_from_buffer]:
			if loader.call(bytes) == OK:
				err = OK
				break
	if err != OK or img.is_empty():
		_say("Couldn't open that photo. Try a JPG or PNG (iPhone HEIC photos can't be read here).", true)
		return
	_got_photo(img)


func _picker_finished(selected: bool, paths: PackedStringArray, _filter: int) -> void:
	_picker_pending = false
	if not selected or paths.is_empty():
		return
	if FileAccess.get_file_as_bytes(paths[0]).size() > 25 * 1024 * 1024:
		_say("Please choose a photo smaller than 25 MB.", true)
		return
	var image := Image.load_from_file(paths[0])
	if image == null or image.is_empty():
		_say("Couldn't open that photo. Try PNG, JPG or WebP.", true)
		return
	_got_photo(image)


func _native_photo(jpeg: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(jpeg) != OK or img.is_empty():
		_say("Couldn't open that photo. Please try another.", true)
		return
	_got_photo(img)


func _native_failed(reason: String) -> void:
	_say(reason, true)


func _got_photo(image: Image) -> void:
	var slot := _photo_slot if _photo_slot != "" else _slot
	if maxi(image.get_width(), image.get_height()) > 2048:
		var k := 2048.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, int(image.get_width() * k)), maxi(1, int(image.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	_originals[slot] = image
	if _selfie and slot != Profile.me_slot:
		_make_me(slot)
	_selfie = false
	_cartoon(slot, image, {})


## Makes the cartoon (from a photo), or redraws it with look changes, and puts it on the card.
func _cartoon(slot: String, image: Image, edits: Dictionary) -> void:
	if _busy_slot != "":
		return
	_busy_slot = slot
	_refresh()
	var what := "Making your cartoon" if edits.is_empty() else "Changing the look"
	_say("%s… about 10 seconds." % what, false, true)
	var kind := "pet" if _is_pet(slot) else "me"
	var r: Dictionary
	if edits.is_empty():
		r = await Online.cartoonize(image, kind, slot if Sfx.LINES.has(slot) else "")
	else:
		r = await Online.cartoon_edit(image, kind, edits)
	if not is_inside_tree():
		return
	_busy_slot = ""
	if r["ok"]:
		_put_on_card(slot, r["image"])
		_say("Done! Tap Change the look to swap hair, hats, outfits and more.", false)
	else:
		_say(str(r["error"]), true)
	_refresh()


## Saves a square picture for a card (512 px) and shows it.
func _put_on_card(slot: String, image: Image) -> void:
	var img := image.duplicate() as Image
	var edge := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - edge) / 2, (img.get_height() - edge) / 2, edge, edge))
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://portraits")
	var path := "user://portraits/%s_%d.png" % [slot, Time.get_ticks_usec()]
	if img.save_png(path) != OK:
		_say("Couldn't save the picture. Please try again.", true)
		return
	AvatarView.portrait_cache[path] = ImageTexture.create_from_image(img)
	var old := str(Profile.slot_face(slot).get("portrait_path", ""))
	var label := str(Profile.slots.get(slot, {}).get("name", ""))
	if slot == _slot:
		label = _name_edit.text.strip_edges()
	elif slot == Profile.me_slot and label == "":
		label = Profile.display_name
	Profile.set_slot(slot, {"portrait_path": path, "portrait_zoom": 1.0, "portrait_x": 0.5, "portrait_y": 0.5}, label)
	if old.begins_with("user://portraits/") and old != path:
		DirAccess.remove_absolute(old)
		AvatarView.portrait_cache.erase(old)
	_refresh_grid_card(slot)


func _say(text: String, error: bool, pulse := false) -> void:
	if _status.has_meta("tween"):
		var old: Tween = _status.get_meta("tween")
		if old and old.is_valid():
			old.kill()
		_status.remove_meta("tween")
	_status.text = text
	_layout()
	_status.add_theme_color_override("font_color", Color("#ff9f8f") if error else UI.ACCENT)
	_status.modulate.a = 1.0
	if pulse:
		var tw := _status.create_tween().set_loops()
		tw.tween_property(_status, "modulate:a", 0.45, 0.6)
		tw.tween_property(_status, "modulate:a", 1.0, 0.6)
		_status.set_meta("tween", tw)


func _reset_card() -> void:
	var old := str(Profile.slot_face(_slot).get("portrait_path", ""))
	Profile.clear_slot(_slot)
	if old.begins_with("user://portraits/"):
		DirAccess.remove_absolute(old)
		AvatarView.portrait_cache.erase(old)
	_originals.erase(_slot)
	_refresh_grid_card(_slot)
	_select(_slot)


## You are this card (after a selfie on it): it shows as yours on the main menu and next to
## your name in games, with a YOU badge here.
func _make_me(slot: String) -> void:
	var old: String = Profile.me_slot
	# The card you were keeps your name, if it has your photo.
	if Profile.is_custom(old) and str(Profile.slots[old].get("name", "")) == "" and Profile.display_name != "":
		Profile.slots[old]["name"] = Profile.display_name
		_refresh_grid_card(old)
	Profile.me_slot = slot
	Profile.save_profile()
	_select(_slot)


# ------------------------------------------------------------------ voice

func _record_voice() -> void:
	var r := VoiceRecorder.new()
	r.slot = _slot
	r.closed.connect(_refresh)
	add_child(r)


# ------------------------------------------------------------------ change the look

func _looks() -> Array:
	return PET_LOOKS if _is_pet(_slot) else PERSON_LOOKS


func _open_look() -> void:
	_edits = {}
	_look_cat = 0
	_show_look()


func _show_look() -> void:
	_close_look()
	_sheet = Control.new()
	_sheet.position = Vector2.ZERO
	_sheet.size = Vector2(720, 1280)
	add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.size = Vector2(720, 1280)
	_sheet.add_child(dim)
	_sheet.add_child(UI.panel(Vector2(20, 40), Vector2(680, 1200), UI.PANEL, 24))
	var cv := CardView.new()
	cv.position = Vector2(48, 64)
	cv.size = Vector2(160, 224)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(cv)
	cv.setup({"id": 0, "kind": kind_for(_slot)}, Profile.slot_face(_slot))
	_sheet.add_child(UI.label("Change the look", Vector2(228, 64), Vector2(450, 50), 32, UI.ACCENT))
	var looks := _looks()
	var picked: Array = []
	for l in looks:
		if _edits.has(l[0]):
			picked.append("%s: %s" % [l[1], _edits[l[0]]])
	var summary := "Pick anything you'd like to change, then tap Apply. Your cartoon is redrawn with the changes." if picked.is_empty() else "Changes: " + ", ".join(picked)
	_sheet.add_child(UI.label(summary, Vector2(228, 118), Vector2(450, 170), 19, UI.TEXT if not picked.is_empty() else UI.MUTED))

	# Categories: a scrolling row of tabs.
	var tabs := ScrollContainer.new()
	tabs.position = Vector2(40, 306)
	tabs.size = Vector2(640, 70)
	tabs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(tabs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tabs.add_child(row)
	for i in looks.size():
		var on := i == _look_cat
		var t := Button.new()
		t.text = "  %s%s  " % [looks[i][1], " ✓" if _edits.has(looks[i][0]) else ""]
		t.custom_minimum_size = Vector2(0, 56)
		t.add_theme_font_size_override("font_size", 19)
		t.add_theme_stylebox_override("normal", UI.box(UI.ACCENT if on else Color("#2f3866"), 12))
		t.add_theme_stylebox_override("hover", UI.box(UI.ACCENT if on else Color("#3a4580"), 12))
		t.add_theme_stylebox_override("pressed", UI.box(UI.ACCENT, 12))
		t.add_theme_color_override("font_color", UI.BG if on else UI.TEXT)
		t.add_theme_color_override("font_hover_color", UI.BG if on else UI.TEXT)
		t.pressed.connect(func(): _look_cat = i; _show_look())
		row.add_child(t)
	# Options for the chosen category.
	var look: Array = looks[_look_cat]
	var key: String = look[0]
	var options: Array = ["Keep as is"] + Array(look[2])
	var list := ScrollContainer.new()
	list.position = Vector2(40, 390)
	list.size = Vector2(640, 640)
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(list)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for i in options.size():
		var value := str(options[i])
		var on := (i == 0 and not _edits.has(key)) or (str(_edits.get(key, "")) == value)
		var b := Button.new()
		b.text = ("Add " + value.to_lower()) if key == "details" and i > 0 else value
		b.custom_minimum_size = Vector2(206, 70)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_stylebox_override("normal", UI.box(Color("#efe7d7") if on else Color("#1d2547"), 12, UI.ACCENT, 3 if on else 0))
		b.add_theme_stylebox_override("hover", UI.box(Color("#efe7d7") if on else Color("#283260"), 12, UI.ACCENT, 3 if on else 0))
		b.add_theme_stylebox_override("pressed", UI.box(Color("#efe7d7"), 12, UI.ACCENT, 3))
		b.add_theme_color_override("font_color", UI.BG if on else UI.TEXT)
		b.add_theme_color_override("font_hover_color", UI.BG if on else UI.TEXT)
		b.pressed.connect(func():
			if i == 0:
				_edits.erase(key)
			else:
				_edits[key] = value
			_show_look())
		grid.add_child(b)
	# Bottom rows.
	if _originals.has(_slot):
		var again := UI.button("New cartoon from my photo", Vector2(40, 1046), Vector2(312, 56), Color("#3a4166"), 18)
		again.pressed.connect(func(): _close_look(); _cartoon(_slot, _originals[_slot], {}))
		_sheet.add_child(again)
		var plain := UI.button("Use my original photo", Vector2(368, 1046), Vector2(312, 56), Color("#3a4166"), 18)
		plain.pressed.connect(func(): _close_look(); _put_on_card(_slot, _originals[_slot]); _refresh())
		_sheet.add_child(plain)
	var cancel := UI.button("Cancel", Vector2(40, 1116), Vector2(240, 74), Color("#3a4166"), 24)
	cancel.pressed.connect(_close_look)
	_sheet.add_child(cancel)
	var apply := UI.button("Apply changes" if not _edits.is_empty() else "Pick a change first", Vector2(296, 1116), Vector2(384, 74), UI.ACCENT.darkened(0.02), 24)
	apply.disabled = _edits.is_empty()
	apply.pressed.connect(_apply_look)
	_sheet.add_child(apply)


func _close_look() -> void:
	if is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


func _apply_look() -> void:
	var tex := AvatarView.portrait_texture(str(Profile.slot_face(_slot).get("portrait_path", "")))
	if tex == null:
		_close_look()
		_say("Couldn't find this card's picture. Take or upload a photo first.", true)
		return
	var edits := _edits.duplicate()
	_close_look()
	_cartoon(_slot, tex.get_image(), edits)


# ------------------------------------------------------------------ leaving

func _leave() -> void:
	if _name_edit.has_focus():
		_name_edit.release_focus()
	match Profile.creator_return:
		"onboarding":
			Profile.onboarding_step = 2
			Profile.go("onboarding")
		"explainer":
			Profile.explainer_start = 5   # back to the tutorial's "you are wild" step
			Profile.go("explainer")
		"main":
			Profile.go("main")
		_:
			Profile.go("settings")
