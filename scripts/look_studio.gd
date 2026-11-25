extends Control
## Shared by Gem Heist, War and Piece, and See Saw. Edits and generated results
## remain drafts here; only accepted emits a portrait for persistence.
signal generate_requested(edits: Dictionary)
signal accepted(image: Image)
signal closed
const Overlay = preload("res://scripts/look_overlay.gd")
const GROUPS := ["Hair", "Face", "Outfit", "Accessories"]
const GROUP_KEYS := [["hair","hair_color","facial"],["braces","details"],["shirt","shirt_color","head","collar","collar_color"],["hat","eyewear","ears","bowtie"]]
const HAIR_MAP := [0,1,2,3,4,5,8,9,10,11,14,13,16,15]
const CLOTH_MAP := [0,1,2,3,4,5,6,7,8,12,11,9,10]
var looks: Array = []
var original: Texture2D
var saved_original: Texture2D
var card_factory: Callable
var pet := false
var edits: Dictionary = {}
var history: Array[Dictionary] = []
var group := 0
var key := "hair"
var show_original := false
var card_mode := false
var offset := Vector2(0,-0.20)
var fit := 0.85
var result: Image
var busy := false
var message := ""
var cache_key := ""

func _ready() -> void:
	saved_original=original
	size=Vector2(720,1280)
	z_index=60
	cache_key="user://portraits/studio_%d.png" % get_instance_id()
	if pet: group=3; key="hat"
	_render()

func _exit_tree() -> void:
	AvatarView.portrait_cache.erase(cache_key)

func _button(text: String, pos: Vector2, dimensions: Vector2, action: Callable, accent := false) -> Button:
	var b := UI.button(text,pos,dimensions,UI.ACCENT if accent else Color("#242e43"),20)
	b.add_theme_stylebox_override("normal",UI.box(UI.ACCENT if accent else Color("#242e43"),8,Color("#424c61") if not accent else UI.ACCENT,1))
	b.add_theme_stylebox_override("hover",UI.box(UI.ACCENT.lightened(0.1) if accent else Color("#354159"),8))
	b.add_theme_stylebox_override("pressed",UI.box(UI.ACCENT.darkened(0.1) if accent else Color("#3b4962"),8))
	b.add_theme_stylebox_override("disabled",UI.box(Color("#222b3e"),8))
	b.disabled=busy
	b.pressed.connect(action)
	add_child(b)
	return b

func _tab(text: String, pos: Vector2, dimensions: Vector2, active: bool, action: Callable) -> Button:
	var b := _button(text,pos,dimensions,action)
	b.add_theme_stylebox_override("normal",UI.box(Color.TRANSPARENT,0))
	b.add_theme_stylebox_override("hover",UI.box(Color("#303c51"),0))
	b.add_theme_stylebox_override("pressed",UI.box(Color("#36445b"),0))
	b.add_theme_color_override("font_color",UI.TEXT if active else UI.MUTED)
	if active:
		var line := UI.panel(Vector2(16,dimensions.y-3),Vector2(dimensions.x-32,2),UI.ACCENT,0)
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(line)
	return b

func _footer() -> void:
	add_child(UI.panel(Vector2(0,1150),Vector2(720,130),Color("#172031"),0))
	add_child(UI.panel(Vector2(32,1150),Vector2(656,1),Color("#394458"),0))

func _label(text: String, pos: Vector2, dimensions: Vector2, fs := 20, color := UI.TEXT) -> void:
	add_child(UI.label(text,pos,dimensions,fs,color,HORIZONTAL_ALIGNMENT_CENTER))

func _options(k: String) -> Array:
	for item in looks:
		if item[0]==k: return Array(item[2])
	return []

func _title(k: String) -> String:
	for item in looks:
		if item[0]==k: return str(item[1])
	return k

func _keys() -> Array:
	var out: Array=[]
	for k in GROUP_KEYS[group]:
		if not _options(k).is_empty(): out.append(k)
	return out

func _choose(k: String, value: String) -> void:
	history.append(edits.duplicate(true))
	if value=="Keep as is": edits.erase(k)
	else: edits[k]=value
	show_original=false
	message="Removed change" if value=="Keep as is" else "%s selected" % value
	_render()

func _undo() -> void:
	if history.is_empty(): return
	edits=history.pop_back()
	message="Last change undone"
	_render()

func _avatar_data(values: Dictionary) -> Dictionary:
	var d := {"skin":6,"hair":3,"hair_color":2,"shirt":2,"shirt_color":10,"hat_color":6,"head_color":4,"mouth":1,"species":1 if pet else 0}
	for k in values:
		var i := _options(k).find(values[k])
		if i<0: continue
		if k=="hair_color": d[k]=HAIR_MAP[i]
		elif k in ["shirt_color","collar_color"]: d[k]=CLOTH_MAP[i]
		elif k=="details": d[k]=[AvatarView.DETAILS[i]]
		else: d[k]=i
	return d

func _has_overlay() -> bool:
	for k in ["hat","eyewear","ears","bowtie"]:
		if edits.has(k) and edits[k]!="None": return true
	return false

func _portrait(pos: Vector2, dimensions: Vector2, texture: Texture2D, overlays: bool) -> void:
	var host := Control.new()
	host.position=pos
	host.size=dimensions
	host.clip_contents=true
	add_child(host)
	var target: Control=host
	if card_mode and card_factory.is_valid():
		AvatarView.portrait_cache[cache_key]=texture
		var card: Control=card_factory.call(cache_key)
		card.position=Vector2((dimensions.x-dimensions.y/1.4)/2,0)
		card.size=Vector2(dimensions.y/1.4,dimensions.y)
		host.add_child(card)
		# Card views create their portrait during setup. Use its bounds for the try-on.
		var avatar = card.get("_avatar")
		if avatar is Control:
			target=Control.new()
			target.position=avatar.position
			target.size=avatar.size
			card.add_child(target)
		else: overlays=false
	else:
		var picture := TextureRect.new()
		picture.texture=texture
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size=dimensions
		host.add_child(picture)
	if overlays and _has_overlay():
		var layer := Overlay.new()
		layer.size=target.size
		layer.data=_avatar_data(edits)
		layer.edits=edits
		layer.offset=offset
		layer.fit=fit
		layer.moved.connect(func(value): offset=value)
		target.add_child(layer)

func _render() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	add_child(UI.panel(Vector2.ZERO,Vector2(720,1280),Color("#1b2436"),0))
	_label("Review portrait" if result!=null else "Portrait studio",Vector2(36,24),Vector2(648,50),28,UI.TEXT)
	if result!=null:
		_review()
		return
	add_child(UI.panel(Vector2(32,88),Vector2(656,390),Color("#202b3d"),12))
	_portrait(Vector2(180,96),Vector2(360,320),saved_original if show_original else original,not show_original)
	# One continuous toolbar, aligned with the editing panel below.
	add_child(UI.panel(Vector2(32,420),Vector2(656,58),Color("#253146"),0))
	_tab("Portrait",Vector2(32,420),Vector2(164,58),not card_mode,func(): card_mode=false; _render())
	_tab("On card",Vector2(196,420),Vector2(164,58),card_mode,func(): card_mode=true; _render())
	_tab("Original" if not show_original else "Try-on",Vector2(360,420),Vector2(164,58),show_original,func(): show_original=not show_original; _render())
	var undo := _tab("Undo",Vector2(524,420),Vector2(164,58),false,_undo)
	undo.disabled=busy or history.is_empty()
	if _has_overlay() and not show_original:
		_label("Rough try-on · drag to fit",Vector2(32,486),Vector2(270,28),17,UI.MUTED)
		var slider := HSlider.new()
		slider.position=Vector2(330,490); slider.size=Vector2(260,28)
		slider.min_value=0.5; slider.max_value=1.6; slider.step=0.05; slider.value=fit
		slider.editable=not busy
		slider.value_changed.connect(func(value): fit=value; _update_overlay(self))
		add_child(slider)
	else:
		_label("Approximate try-on · Generate to see hair and outfit changes.",Vector2(32,486),Vector2(656,28),17,UI.MUTED)
	var available: Array=[]
	for i in GROUPS.size():
		for k in GROUP_KEYS[i]:
			if not _options(k).is_empty(): available.append(i); break
	add_child(UI.panel(Vector2(32,536),Vector2(656,56),Color("#263247"),8))
	for i in available.size():
		var gi: int=available[i]
		var w := 656.0/available.size()
		_tab(GROUPS[gi],Vector2(32+i*w,536),Vector2(w,56),group==gi,func(): group=gi; key=_keys()[0]; _render())
	var keys := _keys()
	if not key in keys: key=keys[0]
	for i in keys.size():
		var k: String=keys[i]
		var width:=656.0/keys.size()
		_tab("Style" if k=="hair" else "Color" if k.ends_with("color") else _title(k),Vector2(32+i*width,602),Vector2(width,48),k==key,func(): key=k; _render())
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(32,664); scroll.size=Vector2(656,348)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new(); grid.columns=4
	grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for value in ["Keep as is"]+_options(key):
		_tile(grid,str(value))
	# Removable chips make pending changes explicit, without changing the saved image.
	var chips := HBoxContainer.new()
	var chip_scroll := ScrollContainer.new()
	chip_scroll.position=Vector2(32,1028); chip_scroll.size=Vector2(656,56)
	chip_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(chip_scroll); chip_scroll.add_child(chips)
	for k in edits:
		var chip:=UI.button("%s: %s ×" % [_title(k),edits[k]],Vector2.ZERO,Vector2(0,42),Color("#263247"),16)
		chip.custom_minimum_size=Vector2(150,42); chip.disabled=busy
		chip.pressed.connect(func(): _choose(k,"Keep as is")); chips.add_child(chip)
	_label("Generating preview… Your saved look is safe." if busy else message,Vector2(32,1090),Vector2(656,50),18,UI.MUTED)
	_footer()
	_button("Cancel",Vector2(32,1170),Vector2(180,72),func(): closed.emit())
	var generate := _button("Generate preview",Vector2(228,1170),Vector2(460,72),func(): generate_requested.emit(edits.duplicate(true)),true)
	generate.disabled=busy or edits.is_empty()

func _update_overlay(node: Node) -> void:
	for child in node.get_children():
		if child.get_script()==Overlay: child.fit=fit; child.queue_redraw()
		_update_overlay(child)

func _tile(grid: GridContainer, value: String) -> void:
	var selected: bool = (value=="Keep as is" and not edits.has(key)) or edits.get(key,"")==value
	var b:=Button.new(); b.custom_minimum_size=Vector2(154,146); b.disabled=busy
	b.add_theme_stylebox_override("normal",UI.box(Color("#303e52") if selected else Color("#232f42"),6,UI.ACCENT if selected else Color("#354155"),2 if selected else 1))
	b.add_theme_stylebox_override("hover",UI.box(Color("#344257"),6,Color("#607088"),1))
	b.add_theme_stylebox_override("pressed",UI.box(Color("#3b4b60"),6,UI.ACCENT,2))
	grid.add_child(b)
	if value=="Keep as is" or value=="None":
		var symbol:=UI.label("↶" if value=="Keep as is" else "−",Vector2(12,12),Vector2(130,80),48,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
		b.add_child(symbol)
	elif key.ends_with("color"):
		var d:=_avatar_data({key:value})
		var color:=Color(AvatarView.HAIR_COLORS[d[key]] if key=="hair_color" else AvatarView.CLOTH[d[key]])
		b.add_child(UI.panel(Vector2(43,20),Vector2(68,68),color,34))
	else:
		var avatar:=AvatarView.new(); avatar.position=Vector2(35,6); avatar.size=Vector2(84,101)
		avatar.data=_avatar_data({key:value}); b.add_child(avatar)
	var caption:=UI.label(value,Vector2(4,108),Vector2(146,32),16,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
	b.add_child(caption)
	if selected: b.add_child(UI.label("✓",Vector2(126,6),Vector2(24,26),20,UI.ACCENT))
	for child in b.get_children(): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_choose.bind(key,value))

func set_busy(value: bool) -> void:
	busy=value
	_render()

func show_result(image: Image) -> void:
	busy=false; result=image; show_original=false; message=""; _render()

func show_error(error: String) -> void:
	busy=false; message=error; _render()

func _review() -> void:
	_label("Nothing is saved until you choose Use this look.",Vector2(32,84),Vector2(656,56),21,UI.MUTED)
	_portrait(Vector2(100,160),Vector2(520,520),saved_original if show_original else ImageTexture.create_from_image(result),false)
	add_child(UI.panel(Vector2(32,710),Vector2(656,56),Color("#263247"),8))
	_tab("Before",Vector2(32,710),Vector2(218,56),show_original,func(): show_original=true; _render())
	_tab("After",Vector2(250,710),Vector2(218,56),not show_original,func(): show_original=false; _render())
	_tab("On card" if not card_mode else "Portrait",Vector2(468,710),Vector2(220,56),card_mode,func(): card_mode=not card_mode; _render())
	_label("Like the result? Keep it, or adjust your choices and generate another preview.",Vector2(64,890),Vector2(592,100),23,UI.TEXT)
	_label(message,Vector2(32,1000),Vector2(656,64),19,UI.ACCENT)
	_button("Adjust",Vector2(32,1080),Vector2(656,62),func(): original=ImageTexture.create_from_image(result); result=null; edits.clear(); history.clear(); show_original=false; message="Adjusting the draft • nothing saved yet"; _render())
	_footer()
	_button("Keep original",Vector2(32,1170),Vector2(260,72),func(): closed.emit())
	_button("Use this look",Vector2(308,1170),Vector2(380,72),func(): accepted.emit(result),true)
