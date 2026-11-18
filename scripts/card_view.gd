class_name CardView
extends Control
## Draws one card. Full cards show art + rules text; "chip" mode is the small
## tile used inside collections. Character cards embed an AvatarView.

signal tapped(view: CardView)

var card: Dictionary = {}
var face_down := false
var chip := false
var preview_name := ""
var face: Dictionary = {}          # avatar data for character cards
## Your own uncustomized wild in menus: "Your Face Here" with an edit badge, instead of Nana Bea.
var placeholder := false:
	set(v):
		placeholder = v
		_sync_avatar()
		queue_redraw()
## Menus: a small pencil badge saying "tap to customize this card".
var editable := false:
	set(v):
		editable = v
		_sync_edit_badge()
var _edit_badge: Control
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
		for c in get_children():
			if c is CanvasItem:
				c.queue_redraw()

var _avatar: AvatarView
var _portrait: Control
var _overlay: BillOverlay


func setup(c: Dictionary, avatar_face: Dictionary = {}, is_face_down := false, is_chip := false) -> CardView:
	card = c
	face = avatar_face
	face_down = is_face_down
	chip = is_chip
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_avatar()
	queue_redraw()
	return self


func _ready() -> void:
	resized.connect(_sync_avatar)
	_sync_avatar()


func _kind() -> String:
	return str(card.get("kind", ""))


func _role() -> String:
	return CardDB.role_of(_kind())


## Builds the card's face children. Faces come from `face` (a custom avatar) or,
## when it's empty, the default: painted role art, the cast character, or the bill's critter.
func _sync_avatar() -> void:
	for n in [_avatar, _portrait, _overlay]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_avatar = null
	_portrait = null
	_overlay = null
	if face_down or card.is_empty():
		_sync_edit_badge()
		return
	var kind := _kind()
	var role := _role()
	if CardDB.is_money(kind) and not chip:
		var o := BillOverlay.oval_rect(size)
		if not face.is_empty():
			_avatar = _make_avatar(face, "")
			_avatar.position = Vector2(o.position.x, o.position.y + o.size.y * 0.04)
			_avatar.size = o.size
		else:
			var crit := CritterPortrait.new()
			crit.kind = kind
			crit.position = o.position
			crit.size = o.size
			crit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(crit)
			_portrait = crit
		_overlay = BillOverlay.new()
		_overlay.value = CardDB.value(kind)
		_overlay.name_text = Profile.face_name(CardDB.slot_for(kind)) if not face.is_empty() else str(Profile.CRITTER_NAMES.get(CardDB.slot_for(kind), ""))
		_overlay.card = self
		_overlay.size = size
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_overlay)
		_sync_edit_badge()
		return
	if role == "" or placeholder:
		_sync_edit_badge()
		return
	var f := face
	if f.is_empty():
		if not chip and Art.tex("role-" + role) != null:
			_sync_edit_badge()
			return  # the painted cast art is drawn by _draw_full_art
		f = Profile.default_face(role)
	_avatar = _make_avatar(f, role)
	if chip:
		var hh := size.y - 6
		_avatar.position = Vector2(3, 3)
		_avatar.size = Vector2(hh * 0.85, hh)
	else:
		_avatar.position = Vector2(size.x * 0.1, size.y * 0.17)
		_avatar.size = Vector2(size.x * 0.8, size.y * (0.46 if kind == "wild" else 0.5))
	_sync_edit_badge()


func _make_avatar(f: Dictionary, role: String) -> AvatarView:
	var a := AvatarView.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.data = f
	a.role = role
	add_child(a)
	return a


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)
		accept_event()


func _bg_color() -> Color:
	var kind := _kind()
	if CardDB.is_treasure(kind):
		return CardDB.tint(kind).lerp(Color.WHITE, 0.72)
	return CardDB.TYPE_COLORS[CardDB.card_type(kind)].lerp(Color.WHITE, 0.55)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, size)
	var radius := minf(size.x, size.y) * 0.09
	if face_down:
		var back := Art.card_back()
		if back != null:
			draw_texture_rect(back, r, false)
			_outline(r, radius, false)
			if dimmed:
				_rounded(r, Color(0, 0, 0, 0.35), radius)
			return
		_rounded(r, Color("#1f2a55"), radius)
		_rounded(r.grow(-size.x * 0.07), Color("#2c3c78"), radius * 0.7)
		var fs := int(size.x * 0.2)
		draw_string(font, Vector2(0, size.y * 0.55), "YaC", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("#ffc83d"))
		_outline(r, radius)
		return
	var kind := _kind()
	var typ := CardDB.card_type(kind)
	if CardDB.is_money(kind) and not chip:
		_rounded(r, Color("#f6f1e2"), radius)
		return
	if not chip and Art.frame(typ) != null:
		_draw_full_art(font, kind, typ)
		_outline(r, radius, false)
		if dimmed:
			_rounded(r, Color(0, 0, 0, 0.35), radius)
		return
	_rounded(r, _bg_color(), radius)
	if chip:
		_draw_chip(font, kind, typ)
	else:
		_draw_full(font, kind, typ)
	_outline(r, radius)
	if dimmed:
		_rounded(r, Color(0, 0, 0, 0.35), radius)


func _draw_full(font: Font, kind: String, typ: String) -> void:
	var w := size.x
	var hgt := size.y
	var band := CardDB.TYPE_COLORS.get(typ, CardDB.tint(kind) if CardDB.is_treasure(kind) else Color.GRAY) as Color
	_rounded(Rect2(0, 0, w, hgt * 0.15), band, w * 0.09)
	draw_rect(Rect2(0, hgt * 0.08, w, hgt * 0.07), band)
	var title := CardDB.display_name(kind)
	var tfs := int(w * (0.12 if title.length() < 11 else 0.1))
	draw_string(font, Vector2(0, hgt * 0.105), title, HORIZONTAL_ALIGNMENT_CENTER, w, tfs, Color.WHITE if typ != "wild" else Color("#3a2a00"))
	if CardDB.is_treasure(kind):
		_treasure_icon(kind, Vector2(w * 0.5, hgt * 0.43), w * 0.26)
		return
	var role := _role()
	if role == "":
		_no_character_art(kind, w, hgt)
	elif face.is_empty():
		draw_circle(Vector2(w * 0.5, hgt * 0.42), w * 0.22, Color(1, 1, 1, 0.5))
	if role != "":
		draw_string(font, Vector2(0, hgt * 0.715), _role_label(role), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.085), Color("#333333"))
	var lines := _wrap(font, CardDB.ACTIONS[kind]["text"], w * 0.88, int(w * 0.082))
	var y := hgt * 0.8
	for line in lines:
		draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.082), Color("#222222"))
		y += w * 0.095
	draw_string(font, Vector2(w * 0.07, hgt * 0.975), CardDB.type_label(typ), HORIZONTAL_ALIGNMENT_LEFT, w, int(w * 0.065), Color("#555555"))


## Card face built from the painted frame: ivory base → frame → native title, art and rules.
func _draw_full_art(font: Font, kind: String, typ: String) -> void:
	var w := size.x
	var hgt := size.y
	var ink: Color = Art.INK_FOR_TYPE.get(typ, Color("#2b2233"))
	var body := Color("#2b2233")
	_rounded(Rect2(w * 0.012, hgt * 0.009, w * 0.976, hgt * 0.982), Art.CARD_IVORY, w * 0.07)
	draw_texture_rect(Art.frame(typ), Rect2(Vector2.ZERO, size), false)
	var title := CardDB.display_name(kind)
	var tfs := int(w * (0.115 if title.length() < 11 else 0.095))
	draw_string(font, Vector2(0, hgt * 0.135), title, HORIZONTAL_ALIGNMENT_CENTER, w, tfs, ink)
	draw_line(Vector2(w * 0.24, hgt * 0.165), Vector2(w * 0.76, hgt * 0.165), Color(ink, 0.35), maxf(1.0, w * 0.008))
	var small := w < 110.0
	if CardDB.is_money(kind):
		var v := CardDB.value(kind)
		draw_circle(Vector2(w * 0.5, hgt * 0.45), w * 0.33, Art.COPPER.lerp(Art.CARD_IVORY, 0.8))
		Art.draw_coin(self, kind, Vector2(w * 0.5, hgt * 0.45), w * 0.3)
		if not small:
			draw_string(font, Vector2(0, hgt * 0.78), CardDB.bills(v), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.11), body)
			draw_string(font, Vector2(0, hgt * 0.855), "Bank it to pay for Heists", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.062), Color(body, 0.8))
		draw_string(font, Vector2(0, hgt * 0.93), "COIN", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.065), Color(ink, 0.8))
		return
	if CardDB.is_treasure(kind):
		var glow := CardDB.tint(kind).lerp(Art.CARD_IVORY, 0.78)
		draw_circle(Vector2(w * 0.5, hgt * 0.45), w * 0.3, glow)
		var t := Art.treasure(kind)
		if t != null:
			Art.draw_fit(self, t, Rect2(w * 0.2, hgt * 0.45 - w * 0.3, w * 0.6, w * 0.6))
		else:
			_treasure_icon(kind, Vector2(w * 0.5, hgt * 0.45), w * 0.26)
		if not small:
			draw_string(font, Vector2(0, hgt * 0.84), "Pawn value: %s" % CardDB.bills(CardDB.pawn_value(kind)), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.075), Color(body, 0.75))
		return
	var role := _role()
	draw_circle(Vector2(w * 0.5, hgt * 0.43), w * 0.3, ink.lerp(Art.CARD_IVORY, 0.86))
	if placeholder:
		_draw_placeholder(font, w, hgt, ink, typ)
		return
	if role != "" and face.is_empty() and Art.tex("role-" + role) != null:
		Art.draw_fit(self, Art.tex("role-" + role), Rect2(w * 0.1, hgt * 0.175, w * 0.8, hgt * 0.46))
	if role == "":
		_no_character_art(kind, w, hgt)
	var cost := CardDB.cost(kind)
	if cost > 0:
		Art.draw_badge(self, Vector2(w * 0.8, hgt * 0.24), w * 0.095, cost)
	if small:
		draw_string(font, Vector2(0, hgt * 0.9), CardDB.type_label(typ), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.09), Color(ink, 0.8))
		return
	if kind == "wild":
		draw_string(font, Vector2(0, hgt * 0.715), _role_label(role), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.09), ink)
		draw_string(font, Vector2(0, hgt * 0.795), "Counts as any gem", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.075), body)
		var gem_size := w * 0.095
		for i in CardDB.COLORS.size():
			var gem := Art.treasure(CardDB.COLORS[i])
			if gem != null:
				Art.draw_fit(self, gem, Rect2(w * 0.16 + i * w * 0.116, hgt * 0.835, gem_size, gem_size))
		return
	if role != "":
		# "Pip the Pickpocket": shrink long names to fit the card.
		var label := _role_label(role)
		var lfs := int(w * 0.085)
		while lfs > 8 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > w * 0.9:
			lfs -= 1
		draw_string(font, Vector2(0, hgt * 0.715), label, HORIZONTAL_ALIGNMENT_CENTER, w, lfs, Color(ink, 0.9))
	var rules: String = CardDB.ACTIONS[kind]["text"]
	if cost > 0:
		rules = "Costs %s. %s" % [CardDB.bills(cost), rules]
	var fs := int(w * 0.08)
	var lines := _wrap(font, rules, w * 0.76, fs)
	if w >= 300.0:
		# Big preview card: use the full width and keep the text large.
		lines = _wrap(font, rules, w * 0.84, fs)
		if lines.size() > 3:
			fs = int(w * 0.072)
			lines = _wrap(font, rules, w * 0.84, fs)
	elif lines.size() > 2:
		fs = int(w * 0.07)
		lines = _wrap(font, rules, w * 0.8, fs)
	if lines.size() > 3:
		fs = int(w * 0.062)
		lines = _wrap(font, rules, w * 0.82, fs)
	var y := hgt * (0.78 if lines.size() <= 2 else 0.765)
	for line in lines:
		draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, fs, body)
		y += fs * 1.15
	if y < hgt * 0.9:
		draw_string(font, Vector2(0, hgt * 0.925), CardDB.type_label(typ), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.062), Color(ink, 0.8))


func _draw_chip(font: Font, kind: String, typ: String) -> void:
	var h := size.y
	var label := ""
	if kind == "wild":
		label = "Wild"
	elif CardDB.is_treasure(kind):
		var t := Art.treasure(kind)
		if t != null:
			Art.draw_fit(self, t, Rect2(h * 0.12, h * 0.08, h * 0.84, h * 0.84))
		else:
			_treasure_icon(kind, Vector2(h * 0.55, h * 0.5), h * 0.34)
		label = CardDB.one_name(kind)
	else:
		label = CardDB.display_name(kind)
	var x := h * 1.05
	draw_string(font, Vector2(x, h * 0.64), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 4, int(h * 0.42), Color("#222222"))


func _wrap(font: Font, text: String, max_w: float, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


func _rounded(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _outline(r: Rect2, radius: float, subtle_border := true) -> void:
	if not subtle_border and not highlight and not selected:
		return
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(int(radius))
	var bw := 2
	var col := Color(0, 0, 0, 0.35)
	if highlight:
		col = Color("#ffe14a")
		bw = 5
	if selected:
		col = Color("#ffffff")
		bw = 5
	sb.set_border_width_all(bw)
	sb.border_color = col
	draw_style_box(sb, r)


func _treasure_icon(kind: String, c: Vector2, r: float) -> void:
	draw_gem(self, kind, c, r)


## Code-drawn gem, used when a gem picture is missing.
static func draw_gem(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var col := CardDB.tint(kind)
	match kind:
		"ruby":
			var pts := PackedVector2Array()
			for i in 6:
				var a := PI / 6.0 + TAU * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.3), c + Vector2(r * 0.4, -r * 0.3), c + Vector2(0, r * 0.5)]), col.lightened(0.3))
		"emerald":
			var pts := PackedVector2Array([c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.5, -r), c + Vector2(r * 0.8, -r * 0.6),
				c + Vector2(r * 0.8, r * 0.6), c + Vector2(r * 0.5, r), c + Vector2(-r * 0.5, r), c + Vector2(-r * 0.8, r * 0.6), c + Vector2(-r * 0.8, -r * 0.6)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.6), Vector2(r * 0.9, r * 1.2)), col.lightened(0.25))
		"sapphire":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, 0), c + Vector2(0, r), c + Vector2(-r * 0.85, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.4, 0), c + Vector2(0, r * 0.5), c + Vector2(-r * 0.4, 0)]), col.lightened(0.3))
		"topaz":
			ci.draw_colored_polygon(CardView.oval(c, r * 0.72, r * 0.95), col)
			ci.draw_colored_polygon(CardView.oval(c, r * 0.42, r * 0.6), col.lightened(0.3))
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.25), c + Vector2(-r * 0.55, -r * 0.7), c + Vector2(r * 0.55, -r * 0.7),
				c + Vector2(r, -r * 0.25), c + Vector2(0, r)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.25), c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(r * 0.3, -r * 0.6),
				c + Vector2(r * 0.55, -r * 0.25), c + Vector2(0, r * 0.5)]), col.lightened(0.45))
		"amethyst":
			var pts := PackedVector2Array([c + Vector2(0, -r)])
			var bc := c + Vector2(0, r * 0.28)
			for k in 17:
				var a := -PI / 3.0 + (PI + 2.0 * PI / 3.0) * k / 16.0
				pts.append(bc + Vector2(cos(a), sin(a)) * r * 0.66)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(bc, r * 0.34, col.lightened(0.3))


static func oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Cards without a character: Windfall shows a heap of coins, Lucky Break a clover.
func _no_character_art(kind: String, w: float, hgt: float) -> void:
	if kind == "windfall":
		Art.draw_coin(self, "loot2", Vector2(w * 0.36, hgt * 0.47), w * 0.15)
		Art.draw_coin(self, "loot3", Vector2(w * 0.64, hgt * 0.47), w * 0.15)
		Art.draw_coin(self, "loot5", Vector2(w * 0.5, hgt * 0.37), w * 0.17)
	else:
		_clover(Vector2(w * 0.5, hgt * 0.42), w * 0.18)


func _clover(c: Vector2, r: float) -> void:
	var g := Color("#2e9e58")
	for a in [0.0, PI / 2, PI, PI * 1.5]:
		draw_circle(c + Vector2(cos(a + PI / 4), sin(a + PI / 4)) * r * 0.55, r * 0.5, g)
	draw_line(c, c + Vector2(r * 0.4, r * 1.3), g, r * 0.15)


## The name under the art. For the wild it's whose face it is (Nana Bea by default).
func _role_label(role: String) -> String:
	if preview_name != "":
		return preview_name
	if role != "you":
		# Each character has a name and a nickname: "Pip the Pickpocket", or "Sam the
		# Pickpocket" once you've put Sam's face on that card.
		var who := ""
		if face.is_empty():
			who = str(Profile.cast_for_role(role)["name"])
		elif face == Profile.slot_face(role):
			who = str(Profile.slots[role].get("name", ""))
		# The card you are carries your name.
		if role == Profile.me_slot and Profile.display_name != "" and (face.is_empty() or face == Profile.slot_face(role)) \
				and str(Profile.slots.get(role, {}).get("name", "")) == "":
			who = Profile.display_name
		var title: String = CardDB.ROLE_TITLES[role]
		return title if who == "" else "%s the %s" % [who, title.trim_prefix("The ")]
	if face.is_empty():
		return Profile.cast_for_role("you")["name"]
	var path := str(face.get("portrait_path", ""))
	if path.begins_with("res://art/role-"):
		return Profile.cast_for_role(path.get_file().trim_prefix("role-").trim_suffix(".png"))["name"]
	if face == Profile.slot_face("you"):
		var n := Profile.face_name("you")
		return n if n != "" else "You"
	for c in Profile.CAST:
		if c["avatar"] == face:
			return c["name"]
	return "You"


func _draw_placeholder(font: Font, w: float, hgt: float, ink: Color, typ := "wild") -> void:
	var c := Vector2(w * 0.5, hgt * 0.42)
	var r := w * 0.3
	draw_circle(c, r, Color("#fff7dd"))
	# dashed ring
	var n := 28
	for i in n:
		if i % 2 == 0:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			draw_arc(c, r, a0, a1, 4, ink, maxf(2.0, w * 0.012), true)
	# silhouette
	var sil := Color(ink, 0.28)
	draw_circle(c + Vector2(0, -r * 0.22), r * 0.32, sil)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(c + Vector2(cos(a) * r * 0.58, r * 0.72 + sin(a) * r * 0.5))
	draw_colored_polygon(body, sil)
	# edit badge (pencil)
	var bc := Vector2(w * 0.76, hgt * 0.24)
	var br := w * 0.1
	draw_circle(bc, br, UI.ACCENT)
	draw_arc(bc, br, 0, TAU, 24, Color("#7a5a00"), maxf(1.5, w * 0.008), true)
	var d := Vector2(1, -1).normalized()
	var p := Vector2(-d.y, d.x)
	var tip := bc - d * br * 0.6
	var tail := bc + d * br * 0.55
	var hw := br * 0.17
	draw_colored_polygon(PackedVector2Array([tail + p * hw, tail - p * hw, tip + d * br * 0.25 - p * hw, tip + d * br * 0.25 + p * hw]), Color("#2b2233"))
	draw_colored_polygon(PackedVector2Array([tip + d * br * 0.25 + p * hw, tip + d * br * 0.25 - p * hw, tip]), Color("#2b2233"))
	# a little camera on the silhouette: "your photo goes here"
	var cam := c + Vector2(0, r * 0.12)
	var cw := r * 0.62
	draw_rect(Rect2(cam + Vector2(-cw * 0.5, -cw * 0.3), Vector2(cw, cw * 0.62)), Color("#2b2233"))
	draw_rect(Rect2(cam + Vector2(-cw * 0.17, -cw * 0.42), Vector2(cw * 0.34, cw * 0.14)), Color("#2b2233"))
	draw_circle(cam + Vector2(0, cw * 0.01), cw * 0.2, Color("#fff7dd"))
	draw_circle(cam + Vector2(0, cw * 0.01), cw * 0.12, Color("#2b2233"))
	var fs := int(w * 0.1)
	draw_string(font, Vector2(0, hgt * 0.72), "This could be you!", HORIZONTAL_ALIGNMENT_CENTER, w, fs, ink)
	draw_string(font, Vector2(0, hgt * 0.8), "Tap to add your photo", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.075), Color("#2b2233"))
	draw_string(font, Vector2(0, hgt * 0.865), "and join the crew", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.075), Color("#2b2233"))
	draw_string(font, Vector2(0, hgt * 0.94), CardDB.type_label(typ), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.062), Color(ink, 0.8))


func _sync_edit_badge() -> void:
	if not editable or face_down or card.is_empty():
		if _edit_badge != null and is_instance_valid(_edit_badge):
			_edit_badge.queue_free()
		_edit_badge = null
		return
	if _edit_badge == null or not is_instance_valid(_edit_badge):
		_edit_badge = Control.new()
		_edit_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_badge.draw.connect(_draw_edit_badge)
		add_child(_edit_badge)
	var w := size.x
	var r := w * 0.095
	# Bills: top middle, between the corner values. Characters: top left, opposite the cost.
	var c := Vector2(w * 0.5, size.y * 0.085) if CardDB.is_money(_kind()) else Vector2(w * 0.2, size.y * 0.24)
	_edit_badge.position = c - Vector2(r, r) * 1.15
	_edit_badge.size = Vector2(r, r) * 2.3
	move_child(_edit_badge, -1)
	_edit_badge.queue_redraw()


func _draw_edit_badge() -> void:
	var b := _edit_badge
	var bc := b.size / 2.0
	var br := b.size.x / 2.3
	b.draw_circle(bc, br, UI.ACCENT)
	b.draw_arc(bc, br, 0, TAU, 24, Color("#7a5a00"), maxf(1.5, br * 0.1), true)
	var d := Vector2(1, -1).normalized()
	var p := Vector2(-d.y, d.x)
	var tip := bc - d * br * 0.6
	var tail := bc + d * br * 0.55
	var hw := br * 0.17
	b.draw_colored_polygon(PackedVector2Array([tail + p * hw, tail - p * hw, tip + d * br * 0.25 - p * hw, tip + d * br * 0.25 + p * hw]), Color("#2b2233"))
	b.draw_colored_polygon(PackedVector2Array([tip + d * br * 0.25 + p * hw, tip + d * br * 0.25 - p * hw, tip]), Color("#2b2233"))
