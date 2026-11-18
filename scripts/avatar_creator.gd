extends Control
const PERSON_CATEGORIES := [
	["Skin", "skin", "color"], ["Face", "face", "list"], ["Face size", "face_size", "list"], ["Eyes", "eyes", "list"], ["Eye color", "eye_color", "color"],
	["Brows", "brows", "list"], ["Nose", "nose", "list"], ["Mouth", "mouth", "list"], ["Hair", "hair", "list"],
	["Hair color", "hair_color", "color"], ["Facial hair", "facial", "list"], ["Head cover", "head", "list"],
	["Cover color", "head_color", "color"], ["Hat", "hat", "list"], ["Hat color", "hat_color", "color"],
	["Glasses", "eyewear", "list"], ["Ears", "ears", "list"], ["Shirt", "shirt", "list"], ["Shirt color", "shirt_color", "color"],
	["Face details", "face_details", "toggles"], ["Jewelry", "accessory_details", "toggles"], ["Bow tie", "bowtie", "list"], ["Braces", "braces", "list"],
]
const PET_CATEGORIES := [
	["Fur", "fur", "color"], ["Pattern", "pattern", "list"], ["Pattern color", "fur2", "color"],
	["Ears", "pet_ears", "list"], ["Eyes", "pet_eye", "color"], ["Collar", "collar", "list"],
	["Collar color", "collar_color", "color"],
]

var slot := "you"
var data: Dictionary = {}
var _preview: CardView
var _name_edit: LineEdit
var _body: Control
var _cancel_button: Button
var _default_button: Button
var _completed_steps := 0
var _skin_slider: HSlider
var _face_slider: HSlider
var _face_tiles: Array[Button] = []
var _save_button: Button
var _status: Label
var _options: GridContainer
var _current := 0
var _group := 0
var _mode := "gallery"
var _own_name := ""
var _photo: Image
var _picker_pending := false
var _source_buttons: Array[Button] = []
var _manual_data: Dictionary = {}
var _portrait_data: Dictionary = {}
var _photo_data: Dictionary = {}
var _original: Image          # the photo as taken, before the cartoon
var _cartoon_busy := false
var _cartoon_note := ""       # "", "cartoon", "original", or an error message
var _kind := "me"             # whose photo: me, pet or person
var _before: Dictionary = {}  # the card as it was, for Cancel
const GROUPS := [["skin", "face", "face_size", "eyes", "eye_color", "brows", "nose", "mouth", "face_details"], ["hair", "hair_color", "facial"], ["shirt", "shirt_color", "head", "head_color", "hat", "hat_color", "bowtie"], ["eyewear", "ears", "accessory_details", "braces"]]

func _ready() -> void:
	theme = UI.make_theme()
	slot = Profile.edit_slot
	# Until it's customized, a card shows its own character (Pip on Heist, and so on).
	var own_art := "res://art/role-%s.png" % (slot if slot in CardDB.ROLES else "you")
	data = Profile.slot_face(slot).duplicate(true) if Profile.is_custom(slot) else {"portrait_path": own_art}
	_manual_data = AvatarView.normalized(Profile.default_face(slot))
	if not data.has("portrait_path"):
		_mode = "builder"
		_manual_data = data.duplicate(true)
	elif str(data["portrait_path"]).begins_with("user://"):
		_mode = "photo"
		_photo_data = data.duplicate(true)
	else:
		_portrait_data = data.duplicate(true)
	_kind = Profile.photo_kind if Profile.creator_mode != "" else "me"
	_before = Profile.slots.get(slot, {}).duplicate(true)   # put back on Cancel
	# My Cards may have chosen how to customize: a photo (yours, a pet's or a friend's) or Create.
	var wanted := Profile.creator_mode
	Profile.creator_mode = ""
	add_child(UI.panel(Vector2.ZERO, Vector2(720, 1280), UI.BG, 0))
	var title := "Create your Wild card" if slot == "you" else "Make this card yours"
	if Profile.creator_via_crew:
		title = "Create a character"
	var sub := "You're part of the crew. Choose how you'll appear."
	if wanted == "photo":
		title = {"me": "Put yourself on this card", "pet": "Put your pet on this card", "person": "Put someone you know on this card"}.get(_kind, title)
		sub = "Take or choose a photo, and we'll turn it into a cartoon."
	add_child(UI.label(title, Vector2(24, 16), Vector2(672, 54), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.label(sub, Vector2(24, 72), Vector2(672, 40), 21, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_preview = CardView.new()
	_preview.position = Vector2(239, 122)
	_preview.size = Vector2(242, 339)
	add_child(_preview)
	add_child(UI.label("NAME ON YOUR CARD", Vector2(28, 476), Vector2(664, 28), 16, UI.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(28, 508)
	_name_edit.size = Vector2(664, 52)
	_name_edit.max_length = 14
	_name_edit.placeholder_text = {"pet": "Your pet's name", "person": "Their first name"}.get(_kind, "Your name (optional)")
	_name_edit.text = str(Profile.slots.get(slot, {}).get("name", Profile.display_name if slot == "you" else ""))
	if wanted == "photo" and not str(data.get("portrait_path", "")).begins_with("user://"):
		_name_edit.text = Profile.display_name if _kind == "me" else ""
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("#f4f1ea"), 12))
	_name_edit.add_theme_color_override("font_color", UI.BG)
	_name_edit.add_theme_stylebox_override("read_only", UI.box(Color("#e5e0d4"), 12))
	_name_edit.add_theme_color_override("font_uneditable_color", UI.BG)
	_name_edit.add_theme_color_override("font_placeholder_color", Color("#777785"))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("#ffffff"), 12, UI.ACCENT, 2))
	_own_name = _name_edit.text
	_name_edit.text_changed.connect(func(_value): _refresh_preview())
	add_child(_name_edit)
	for i in 3:
		var b := UI.button(["My Photo", "Character", "Create"][i], Vector2(28+i*224, 578), Vector2(216, 64), UI.PANEL, 20)
		b.pressed.connect(_set_mode.bind(["photo", "gallery", "builder"][i]))
		add_child(b)
		_source_buttons.append(b)
		b.visible = not Profile.creator_via_crew   # photos live on the crew screen
	_body = Control.new()
	_body.position = Vector2(28, 660)
	_body.size = Vector2(664, 490)
	add_child(_body)
	_status = UI.label("", Vector2(28, 1148), Vector2(664, 32), 18, UI.ACCENT)
	add_child(_status)
	var back := UI.button("Back" if Profile.creator_return == "onboarding" else "Cancel", Vector2(28, 1190), Vector2(180, 64), UI.PANEL, 22)
	_cancel_button = back
	back.pressed.connect(_cancel)
	add_child(back)
	var reset := UI.button("Use default", Vector2(220, 1190), Vector2(180, 64), UI.PANEL, 20)
	_default_button = reset
	reset.pressed.connect(_use_default)
	add_child(reset)
	var save := UI.button("Use this card", Vector2(412, 1190), Vector2(280, 64), UI.ACCENT, 25)
	_save_button = save
	save.pressed.connect(_save)
	add_child(save)
	if wanted != "" and wanted != _mode:
		_set_mode(wanted)
	else:
		_render_mode()

func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _set_mode(mode: String) -> void:
	if _mode != "gallery": _own_name = _name_edit.text
	if mode != "gallery": _name_edit.text = _own_name
	if mode == "builder" and _mode != "builder":
		_completed_steps = 0
		_group = 0
		_current = 0
	if _mode == "builder": _manual_data = data.duplicate(true)
	elif _mode == "gallery": _portrait_data = data.duplicate(true)
	elif str(data.get("portrait_path", "")).begins_with("user://"): _photo_data = data.duplicate(true)
	_mode = mode
	if mode == "builder": data = _manual_data.duplicate(true)
	elif mode == "gallery": data = _portrait_data.duplicate(true) if not _portrait_data.is_empty() else {"portrait_path": "res://art/role-you.png"}
	elif not _photo_data.is_empty(): data = _photo_data.duplicate(true)
	_render_mode()

func _render_mode() -> void:
	_sync_footer()
	_save_button.disabled = (_mode == "photo" and not str(data.get("portrait_path", "")).begins_with("user://portraits/")) or _cartoon_busy
	_name_edit.editable = _mode != "gallery"
	if _mode == "gallery":
		var role := str(data.get("portrait_path", "res://art/role-you.png")).get_file().trim_prefix("role-").trim_suffix(".png")
		_name_edit.text = str(Profile.cast_for_role(role)["name"])
	_clear_body()
	for i in 3:
		var on: bool = ["photo", "gallery", "builder"][i] == _mode
		_source_buttons[i].add_theme_stylebox_override("normal", UI.box(UI.ACCENT if on else UI.PANEL, 12))
		_source_buttons[i].add_theme_color_override("font_color", UI.BG if on else UI.TEXT)
	_status.text = ""
	match _mode:
		"gallery": _show_gallery()
		"photo": _show_photo()
		"builder": _show_builder()
	_refresh_preview()

func _show_gallery() -> void:
	_body.add_child(UI.label("Pick a painted portrait for your card", Vector2.ZERO, Vector2(664, 36), 22))
	for i in Profile.CAST.size():
		var cast: Dictionary = Profile.CAST[i]
		var path := "res://art/role-%s.png" % cast["role"]
		var on := str(data.get("portrait_path", "")) == path
		var b := UI.button("", Vector2((i%3)*224, 46+(i/3)*142), Vector2(216, 132), Color("#eee6d6") if on else UI.PANEL)
		b.tooltip_text = str(cast["name"])
		var t := AvatarView.new()
		t.data = {"portrait_path": path}
		t.position = Vector2(52, 4)
		t.size = Vector2(112, 100)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
		b.add_child(UI.label(str(cast["name"]), Vector2(0,104), Vector2(216,26), 17, UI.BG if on else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		b.pressed.connect(_choose_character.bind(path, str(cast["name"])))
		_body.add_child(b)

func _choose_character(path: String, character_name: String) -> void:
	data = {"portrait_path": path}
	_name_edit.text = character_name
	_render_mode()

func _show_photo() -> void:
	var who: String = {"me": "yourself", "pet": "your pet", "person": "them"}.get(_kind, "yourself")
	_body.add_child(UI.label("Add a photo of %s" % who, Vector2.ZERO, Vector2(664, 40), 23))
	var hint := "A clear, well-lit photo of a face works best. We'll turn it into a cartoon for your card."
	if _kind == "person":
		hint = "Only use a photo of someone who's happy to be on your card. We'll turn it into a cartoon."
	elif _kind == "pet":
		hint = "A clear photo of your pet's face works best. We'll turn it into a cartoon for your card."
	_body.add_child(UI.label(hint, Vector2(0, 44), Vector2(664, 64), 19, UI.MUTED))
	var camera := UI.button("Take a selfie" if _kind == "me" else "Take a photo", Vector2(0, 116), Vector2(326, 58), UI.ACCENT, 23)
	camera.pressed.connect(_take_selfie)
	camera.disabled = _cartoon_busy
	_body.add_child(camera)
	var choose := UI.button("Choose from Photos", Vector2(338, 116), Vector2(326, 58), UI.PANEL, 23)
	choose.pressed.connect(_open_photo_picker)
	choose.disabled = _cartoon_busy
	_body.add_child(choose)
	if _cartoon_busy:
		var busy := UI.label("Making your cartoon… this takes about 10 seconds.", Vector2(0, 200), Vector2(664, 80), 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		_body.add_child(busy)
		var tw := busy.create_tween().set_loops()
		tw.tween_property(busy, "modulate:a", 0.4, 0.6)
		tw.tween_property(busy, "modulate:a", 1.0, 0.6)
		return
	if str(data.get("portrait_path", "")).begins_with("user://"):
		for i in 3:
			var key: String = ["portrait_zoom", "portrait_x", "portrait_y"][i]
			_body.add_child(UI.label(["Zoom", "Left / right", "Up / down"][i], Vector2(0, 194+i*60), Vector2(160, 40), 20))
			var slider := HSlider.new()
			slider.position = Vector2(174, 202+i*60)
			slider.size = Vector2(480, 32)
			slider.min_value = 1.0 if i == 0 else 0.0
			slider.max_value = 3.0 if i == 0 else 1.0
			slider.step = 0.01
			slider.value = float(data.get(key, 1.0 if i == 0 else 0.5))
			slider.value_changed.connect(func(value): data[key] = value; _refresh_preview())
			_body.add_child(slider)
	if _original != null:
		# Cartoon or original photo: your choice.
		var note := ""
		match _cartoon_note:
			"cartoon": note = "Here's your cartoon! Not quite right?"
			"original": note = "Using your original photo."
			_: note = _cartoon_note
		_body.add_child(UI.label(note, Vector2(0, 384), Vector2(664, 34), 19, UI.TEXT if _cartoon_note in ["cartoon", "original"] else Color("#ff9f8f")))
		var again := UI.button("Make a new cartoon" if _cartoon_note == "cartoon" else "Make it a cartoon", Vector2(0, 420), Vector2(326, 54), Color("#7a4fd6"), 20)
		again.pressed.connect(_make_cartoon)
		_body.add_child(again)
		if _cartoon_note == "cartoon":
			var plain := UI.button("Use my original photo", Vector2(338, 420), Vector2(326, 54), UI.PANEL, 20)
			plain.pressed.connect(_use_original)
			_body.add_child(plain)

func _import_photo(path: String) -> void:
	if FileAccess.get_file_as_bytes(path).size() > 25 * 1024 * 1024:
		_status.text = "Please choose an image smaller than 25 MB."
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_status.text = "Couldn't open that image. Try PNG, JPG or WebP."
		return
	if maxi(image.get_width(), image.get_height()) > 2048:
		var scale := 2048.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, int(image.get_width()*scale)), maxi(1, int(image.get_height()*scale)), Image.INTERPOLATE_LANCZOS)
	_accept_image(image)

func _accept_image(image: Image) -> void:
	_original = image
	_cartoon_note = ""
	_use_photo(image)
	_make_cartoon()


func _use_original() -> void:
	if _original == null:
		return
	_cartoon_note = "original"
	_use_photo(_original)


## Send the photo to the cartoon maker (Gemini, through our server) and show the result.
func _make_cartoon() -> void:
	if _original == null or _cartoon_busy:
		return
	_cartoon_busy = true
	_render_mode()
	var r: Dictionary = await Online.cartoonize(_original, _kind, slot if Sfx.LINES.has(slot) else "")
	if not is_inside_tree():
		return
	_cartoon_busy = false
	if r["ok"]:
		_cartoon_note = "cartoon"
		_use_photo(r["image"])
	else:
		_cartoon_note = str(r["error"])
		_render_mode()


func _use_photo(image: Image) -> void:
	_photo = image
	var destination := "user://portraits/portrait_%d_%d.png" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	AvatarView.portrait_cache[destination] = ImageTexture.create_from_image(image)
	data = {"portrait_path": destination, "portrait_zoom": 1.0, "portrait_x": 0.5, "portrait_y": 0.5}
	_render_mode()

func _species() -> int:
	return int(data.get("species", 0))

func _categories() -> Array:
	if _species() != 0:
		var keys: Array = [[], ["pet_ears", "pet_eye"], ["fur", "pattern", "fur2"], ["collar_color"], ["collar"]][_group]
		return PET_CATEGORIES.filter(func(c): return c[1] in keys)
	if _group == 2:
		return [["Hair color", "hair_color", "color"], ["Style", "hair", "list"], ["Facial hair", "facial", "list"]]
	return PERSON_CATEGORIES.filter(func(c): return c[1] in GROUPS[maxi(0,_group-1)])

func _show_builder() -> void:
	_sync_footer()
	_clear_body()
	var titles := ["Person, Cat or Dog", "Face & Skin", "Hair", "Outfit", "Accessories"]
	if _species() != 0:
		titles[1] = "Face"
		titles[2] = "Fur Color & Pattern"
	_body.add_child(UI.label("Step %d of 5 · %s" % [_group+1, titles[_group]], Vector2.ZERO, Vector2(664, 36), 24, UI.ACCENT))
	for i in 5:
		_body.add_child(UI.panel(Vector2(i*134,44),Vector2(126,4),UI.ACCENT if i<=_group else UI.PANEL,2))
	if _group == 0:
		_show_species_step()
	elif _group == 1 and _species() == 0:
		_show_face_sliders()
		return
	else:
		var cats := _categories()
		_current = clampi(_current,0,cats.size()-1)
		if _group == 2:
			for i in cats.size():
				var tab := UI.button(cats[i][0],Vector2(i*224,58),Vector2(216,46),UI.ACCENT if i==_current else UI.PANEL,20)
				tab.pressed.connect(func(): _current=i; _show_builder())
				_body.add_child(tab)
		else:
			var category := OptionButton.new()
			category.position=Vector2(0,58)
			category.size=Vector2(664,46)
			for c in cats: category.add_item(c[0])
			category.select(_current)
			category.item_selected.connect(func(i): _current=i; _build_options())
			_body.add_child(category)
		var scroll := ScrollContainer.new()
		scroll.position=Vector2(0,118)
		scroll.size=Vector2(664,290)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		_body.add_child(scroll)
		_options=GridContainer.new()
		_options.add_theme_constant_override("h_separation",8)
		_options.add_theme_constant_override("v_separation",8)
		scroll.add_child(_options)
		_build_options()
	_step_navigation()

func _show_species_step() -> void:
	_body.add_child(UI.label("Who will star on your card?",Vector2(0,70),Vector2(664,50),25,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	for i in 3:
		var selected := i == _species()
		var button := UI.button("",Vector2(i*224,142),Vector2(216,220),UI.PANEL)
		button.add_theme_stylebox_override("normal",UI.box(UI.PANEL,16,UI.ACCENT,3 if selected else 0))
		var avatar := AvatarView.new()
		var sample := data.duplicate(true)
		sample["species"]=i
		avatar.data=AvatarView.normalized(sample)
		avatar.position=Vector2(28,10)
		avatar.size=Vector2(160,156)
		avatar.clip_contents=true
		avatar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(avatar)
		button.add_child(UI.label(AvatarView.SPECIES_NAMES[i],Vector2(0,176),Vector2(216,36),24,UI.ACCENT if selected else UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
		button.pressed.connect(_set_species.bind(i))
		_body.add_child(button)

func _step_navigation() -> void:
	if _group > 0:
		var previous := UI.button("Previous",Vector2(0,426),Vector2(210,50),UI.PANEL,21)
		previous.pressed.connect(_go_step.bind(-1))
		_body.add_child(previous)
	var label: String = "Save" if _group == 4 else "Next: " + ["Face", "Hair", "Outfit", "Accessories"][_group]
	var next := UI.button(label,Vector2(0 if _group==0 else 224,426),Vector2(664 if _group==0 else 440,50),UI.ACCENT,23)
	next.pressed.connect(_finish_create if _group==4 else _go_step.bind(1))
	_body.add_child(next)

func _go_step(direction: int) -> void:
	if direction > 0: _completed_steps |= 1 << _group
	_group = clampi(_group+direction,0,4)
	_current=0
	_show_builder()

func _finish_create() -> void:
	if _group != 4 or (_completed_steps & 15) != 15: return
	_completed_steps |= 16
	_save()

func _build_options() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	var c: Array = _categories()[_current]
	var key: String = c[1]
	var mode: String = c[2]
	_options.columns = 8 if mode == "color" else 3
	var detail_keys: Array = ["nose_ring"] if key == "accessory_details" else ["freckles", "vitiligo", "rosy", "smile_lines", "birthmark", "bindi", "makeup"]
	var choices: Array = []
	if mode == "toggles":
		for d in detail_keys: choices.append(AvatarView.DETAIL_NAMES[AvatarView.DETAILS.find(d)])
	else: choices = _list_for(key)
	for i in choices.size():
		if key == "mouth" and i == 3: continue # Braces now live in Accessories.
		var selected := false
		if mode != "toggles": selected = int(data.get(key,0))==i
		if mode == "toggles": selected = detail_keys[i] in data.get("details", [])
		var b := Button.new()
		b.tooltip_text = str(choices[i])
		if mode == "color":
			b.custom_minimum_size=Vector2(74,74)
			var col := Color(choices[i]) if str(choices[i]).begins_with("#") else Color("#927761")
			b.add_theme_stylebox_override("normal", UI.box(col, 37, Color.WHITE, 4 if selected else 0))
			if str(choices[i]) in ["hetero", "odd"]: b.text="Two"
		else:
			b.custom_minimum_size=Vector2(210,146)
			b.add_theme_stylebox_override("normal", UI.box(Color("#efe7d7") if selected else UI.PANEL, 12, UI.ACCENT, 3 if selected else 0))
			var thumb := AvatarView.new()
			var sample := data.duplicate(true)
			if mode == "toggles":
				var details: Array = sample.get("details", []).duplicate()
				if not detail_keys[i] in details: details.append(detail_keys[i])
				sample["details"]=details
			else: sample[key]=i
			thumb.data=sample
			thumb.position=Vector2(54,4)
			thumb.size=Vector2(102,110)
			thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(thumb)
			b.add_child(UI.label(str(choices[i]),Vector2(3,114),Vector2(204,28),17,UI.BG if selected else UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
		if mode == "toggles": b.pressed.connect(_toggle_detail.bind(detail_keys[i]))
		else: b.pressed.connect(_set_option.bind(key,i))
		_options.add_child(b)

func _preview_kind() -> String:
	if slot == "you":
		return "wild"
	if slot.begins_with("bill"):
		return "loot" + slot.substr(4)
	for k in CardDB.ACTIONS.keys():
		if CardDB.ACTIONS[k]["role"] == slot:
			return k
	return "wild"


func _refresh_preview() -> void:
	var card_name := _name_edit.text.strip_edges()
	if _mode == "gallery":
		var path := str(data.get("portrait_path", ""))
		card_name = str(Profile.cast_for_role(path.get_file().trim_prefix("role-").trim_suffix(".png"))["name"])
	# Character cards read "Sam the Pickpocket"; the wild just shows the name.
	var role := CardDB.role_of(_preview_kind())
	if role != "" and role != "you":
		var title: String = CardDB.ROLE_TITLES[role]
		card_name = title if card_name == "" else "%s the %s" % [card_name, title.trim_prefix("The ")]
	_preview.preview_name = card_name if card_name != "" else "You"
	_preview.setup({"id": 0, "kind": _preview_kind()}, data.duplicate(true))
	if _preview._overlay != null:
		_preview._overlay.name_text = _name_edit.text
		_preview._overlay.queue_redraw()


func _list_for(key: String) -> Array:
	if key == "pet_ears":
		return AvatarView.DOG_EAR_NAMES if _species() == 2 else AvatarView.CAT_EAR_NAMES
	if AvatarView.PET_KEYS.has(key):
		return AvatarView.PET_KEYS[key]
	return AvatarView.KEYS[key]


func _set_species(i: int) -> void:
	if i == _species():
		return
	if i != 0 and not bool(data.get("pet_set", false)):
		var pet := AvatarView.random_pet(i)
		for k in AvatarView.PET_KEYS.keys():
			data[k] = pet[k]
		data["pet_set"] = true
	data["species"] = i
	_show_builder()
	_refresh_preview()


func _set_option(key: String, idx: int) -> void:
	data[key] = idx
	if key == "head" and idx != 0 and idx != 4:
		data["hat"] = 0
	_refresh_preview()
	_build_options()


func _toggle_detail(d: String) -> void:
	var list: Array = data.get("details", []).duplicate()
	if d in list:
		list.erase(d)
	else:
		list.append(d)
	data["details"] = list
	_refresh_preview()
	_build_options()


func _save() -> void:
	if _mode == "builder" and (_group != 4 or _completed_steps != 31): return
	if _mode == "photo" and not str(data.get("portrait_path", "")).begins_with("user://portraits/"): return
	if _photo != null and str(data.get("portrait_path", "")).begins_with("user://portraits/"):
		var crop := AvatarView.portrait_crop(Vector2(_photo.get_size()), data)
		var result := _photo.get_region(Rect2i(crop))
		result.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute("user://portraits")
		var path := str(data["portrait_path"])
		if result.save_png(path) != OK:
			_status.text = "Couldn't save your photo. Please try again."
			return
		AvatarView.portrait_cache[path] = ImageTexture.create_from_image(result)
		data["portrait_zoom"] = 1.0
		data["portrait_x"] = 0.5
		data["portrait_y"] = 0.5
	var label := _name_edit.text.strip_edges()
	Profile.set_slot(slot, data, label)
	if slot == "you" and label != "" and _mode != "gallery":
		Profile.display_name = label
		Profile.save_profile()
	_leave(true)


func _use_default() -> void:
	Profile.clear_slot(slot)
	_leave(true)


func _cancel() -> void:
	# Put the card back exactly as it was before you started.
	if _before.is_empty():
		Profile.clear_slot(slot)
	else:
		Profile.slots[slot] = _before.duplicate(true)
		Profile.save_profile()
	_leave(false)


func _leave(saved: bool) -> void:
	if Profile.creator_via_crew:
		Profile.creator_via_crew = false
		Profile.go("my_cards")
		return
	match Profile.creator_return:
		"onboarding":
			# Your wild card leads on to the bills step; bills return to it.
			if slot == "you" and not saved:
				Profile.onboarding_step = 1
			else:
				Profile.onboarding_step = 2
			Profile.go("onboarding")
		"my_cards":
			Profile.go("my_cards")
		"explainer":
			# Back to the tutorial's "you are wild" step.
			Profile.explainer_start = 5
			Profile.go("explainer")
		_:
			Profile.go("main")

## The iPhone's own camera and Photos picker (addons/native_photos), when available.
func _native() -> Object:
	if Engine.has_singleton("NativePhotos"):
		var n := Engine.get_singleton("NativePhotos")
		if n.call("is_available"):
			if not n.is_connected("photo_ready", _native_photo):
				n.connect("photo_ready", _native_photo)
				n.connect("photo_failed", _native_failed)
			return n
	return null


func _native_photo(jpeg: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(jpeg) != OK or img.is_empty():
		_status.text = "Couldn't open that photo. Please try another."
		return
	_accept_image(img)


func _native_failed(reason: String) -> void:
	_status.text = reason


func _take_selfie() -> void:
	var n := _native()
	if n != null:
		n.call("take_photo", _kind == "me")
		return
	var camera := preload("res://scripts/selfie_capture.gd").new()
	camera.size = Vector2(720,1280)
	add_child(camera)
	camera.captured.connect(func(image: Image): _accept_image(image))


func _open_photo_picker() -> void:
	if _picker_pending: return
	var n := _native()
	if n != null:
		n.call("pick_photo")
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_photo_picker_unavailable()
		return
	_picker_pending = true
	var error := DisplayServer.file_dialog_show(
		"Choose your photo", OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Photos;image/png,image/jpeg,image/webp"]),
		_photo_picker_finished, get_window().get_window_id())
	if error != OK:
		_picker_pending = false
		_photo_picker_unavailable()

func _photo_picker_finished(selected: bool, paths: PackedStringArray, _filter: int) -> void:
	_picker_pending = false
	if selected and not paths.is_empty(): _import_photo(paths[0])

func _photo_picker_unavailable() -> void:
	# Never fall back to the engine's developer-style filesystem dialog.
	_clear_body()
	_body.add_child(UI.label("Let's open your photos",Vector2(0,16),Vector2(664,50),28,UI.ACCENT,HORIZONTAL_ALIGNMENT_CENTER))
	var explanation := "Photo selection isn't available in this build yet. You can use Take a selfie instead."
	if OS.get_name() == "macOS" and OS.has_feature("editor"):
		explanation = "The photo picker needs the game in its own window. Turn off Embed Game on Play in Godot's Game panel, then run the game again."
	_body.add_child(UI.label(explanation,Vector2(32,88),Vector2(600,160),23,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	var back := UI.button("Back to My Photo",Vector2(112,290),Vector2(440,64),UI.ACCENT,24)
	back.pressed.connect(_render_mode)
	_body.add_child(back)


func _sync_footer() -> void:
	var creating := _mode == "builder"
	_default_button.visible = not creating
	_save_button.visible = not creating
	_cancel_button.text = "Cancel"
	_cancel_button.position.x = 28
	_cancel_button.size.x = 664 if creating else 180

func _show_face_sliders() -> void:
	_body.add_child(UI.label("Skin tone",Vector2(0,62),Vector2(664,36),24))
	_body.add_child(UI.label("Slide to find your shade",Vector2(0,99),Vector2(664,30),18,UI.MUTED))
	var colors := AvatarView.ordered_skin_colors()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	var offsets := PackedFloat32Array()
	for i in colors.size(): offsets.append(float(i)/(colors.size()-1))
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=620
	texture.height=30
	texture.fill_from=Vector2(0,0)
	texture.fill_to=Vector2(1,0)
	var ramp := TextureRect.new()
	ramp.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	ramp.texture=texture
	ramp.position=Vector2(16,145)
	ramp.size=Vector2(632,30)
	ramp.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_body.add_child(ramp)
	_skin_slider=_make_slider(Vector2(0,130),Vector2(664,60),0.001)
	_skin_slider.add_theme_stylebox_override("slider",StyleBoxEmpty.new())
	_skin_slider.add_theme_stylebox_override("grabber_area",StyleBoxEmpty.new())
	_skin_slider.add_theme_stylebox_override("grabber_area_highlight",StyleBoxEmpty.new())
	var current := Color(AvatarView.SKIN[int(data.get("skin",0))])
	_skin_slider.value=float(data.get("skin_tone", float(colors.find(current))/(colors.size()-1)))
	_skin_slider.value_changed.connect(_skin_changed)
	_body.add_child(_skin_slider)
	_body.add_child(UI.label("Lightest",Vector2(0,188),Vector2(220,30),17,UI.MUTED))
	_body.add_child(UI.label("Darkest",Vector2(444,188),Vector2(220,30),17,UI.MUTED,HORIZONTAL_ALIGNMENT_RIGHT))
	_body.add_child(UI.label("Face shape",Vector2(0,232),Vector2(664,34),24))
	_face_tiles=[]
	for i in AvatarView.FACE_NAMES.size():
		var button:=UI.button("",Vector2(i*134,274),Vector2(126,96),UI.PANEL)
		button.pressed.connect(func(): _face_slider.value=i)
		var avatar:=AvatarView.new()
		var sample:=data.duplicate(true)
		sample["face"]=i
		sample["hair"]=0
		sample["head"]=0
		sample["hat"]=0
		sample["eyewear"]=0
		avatar.data=sample
		avatar.position=Vector2(34,0)
		avatar.size=Vector2(58,70)
		avatar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(avatar)
		button.add_child(UI.label(AvatarView.FACE_NAMES[i],Vector2(0,70),Vector2(126,24),16,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
		_body.add_child(button)
		_face_tiles.append(button)
	_face_slider=_make_slider(Vector2(0,372),Vector2(664,42),1.0)
	_face_slider.max_value=AvatarView.FACE_NAMES.size()-1
	_face_slider.value=int(data.get("face",0))
	_face_slider.tick_count=AvatarView.FACE_NAMES.size()
	_face_slider.value_changed.connect(_face_changed)
	_body.add_child(_face_slider)
	_face_changed(_face_slider.value)
	_step_navigation()

func _make_slider(pos: Vector2, dimensions: Vector2, increment: float) -> HSlider:
	var slider:=HSlider.new()
	slider.position=pos
	slider.size=dimensions
	slider.min_value=0
	slider.max_value=1
	slider.step=increment
	var thumb:=GradientTexture2D.new()
	thumb.width=32
	thumb.height=32
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)])
	gradient.offsets=PackedFloat32Array([0,0.80,0.88])
	thumb.gradient=gradient
	thumb.fill=GradientTexture2D.FILL_RADIAL
	thumb.fill_from=Vector2(0.5,0.5)
	thumb.fill_to=Vector2(1,0.5)
	slider.add_theme_icon_override("grabber",thumb)
	slider.add_theme_icon_override("grabber_highlight",thumb)
	slider.add_theme_stylebox_override("slider",UI.box(UI.PANEL,6))
	slider.add_theme_stylebox_override("grabber_area",UI.box(UI.ACCENT,6))
	return slider

func _skin_changed(value: float) -> void:
	data["skin_tone"]=value
	for button in _face_tiles:
		if not is_instance_valid(button): continue
		var avatar: AvatarView=button.get_child(0)
		var sample:=avatar.data.duplicate(true)
		sample["skin_tone"]=value
		avatar.data=sample
	_refresh_preview()

func _face_changed(value: float) -> void:
	data["face"]=int(value)
	for i in _face_tiles.size():
		_face_tiles[i].add_theme_stylebox_override("normal",UI.box(UI.PANEL,12,UI.ACCENT,3 if i==int(value) else 0))
	_refresh_preview()
