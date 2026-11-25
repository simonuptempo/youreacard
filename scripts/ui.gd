class_name UI
extends RefCounted
## Small helpers for building the (code-made) UI.

const BG := Color("#1b2038")
const PANEL := Color("#252c4d")
const ACCENT := Color("#ffc83d")
const TEXT := Color("#f4f1ea")
const MUTED := Color("#aab0cc")


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", Color("#1b2038"))
	t.set_color("font_hover_color", "Button", Color("#1b2038"))
	t.set_color("font_pressed_color", "Button", Color("#1b2038"))
	t.set_color("font_focus_color", "Button", Color("#1b2038"))
	t.set_color("font_disabled_color", "Button", Color("#6b7090"))
	t.set_stylebox("normal", "Button", box(ACCENT, 14))
	t.set_stylebox("hover", "Button", box(ACCENT.lightened(0.15), 14))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.15), 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", box(Color("#3a4166"), 14))
	return t


static func box(col: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


static func button(text: String, pos: Vector2, sz: Vector2, col := ACCENT, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font_size)
	if col != ACCENT:
		b.add_theme_stylebox_override("normal", box(col, 14))
		b.add_theme_stylebox_override("hover", box(col.lightened(0.12), 14))
		b.add_theme_stylebox_override("pressed", box(col.darkened(0.12), 14))
		var fc := Color.WHITE if col.get_luminance() < 0.55 else Color("#1b2038")
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, fc)
	return b


static func label(text: String, pos: Vector2, sz: Vector2, font_size := 24, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before size, or long text widens the box
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(pos: Vector2, sz: Vector2, col := PANEL, radius := 16) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", box(col, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static var _fonts := {}

## The rounded UI font (Nunito) at a given weight: 400 regular, 600 semibold, 800 extra bold.
## Falls back to the default font if the file is missing.
static func font(weight := 600) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base = load("res://fonts/Nunito.ttf")
	if base == null:
		return ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = fv
	return fv



## Makes a ScrollContainer scroll by finger on a phone even when its content is full of
## buttons and rows: anything that would swallow the touch passes it on to the scroller,
## and a finger that scrolls the list doesn't also press the button it started on.
## Call it once, right after creating the ScrollContainer (content can be added later).
static func touch_scroll(scroll: ScrollContainer) -> void:
	var start := {"v": 0.0, "h": 0.0, "off": false}
	var relax := func(node: Node, recurse: Callable) -> void:
		for c in node.get_children():
			if c is Control and not (c is ScrollBar) and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
			recurse.call(c, recurse)
	scroll.sort_children.connect(func(): relax.call(scroll, relax))
	var set_buttons := func(node: Node, off: bool, recurse: Callable) -> void:
		for c in node.get_children():
			if c is BaseButton and not (c is ScrollBar):
				if off and not c.disabled:
					c.disabled = true
					c.set_meta("_scroll_off", true)
				elif not off and c.has_meta("_scroll_off"):
					c.disabled = false
					c.remove_meta("_scroll_off")
			recurse.call(c, off, recurse)
	var moved := func(_v: float) -> void:
		if start["off"]:
			return
		if absf(scroll.scroll_vertical - start["v"]) < 12 and absf(scroll.scroll_horizontal - start["h"]) < 12:
			return
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return   # scrolled by wheel or code, not a finger
		# The finger is dragging the list: cancel the press on whatever button it started on.
		start["off"] = true
		set_buttons.call(scroll, true, set_buttons)
		while scroll.is_inside_tree() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			await scroll.get_tree().process_frame
		if not is_instance_valid(scroll):
			return
		await scroll.get_tree().process_frame
		set_buttons.call(scroll, false, set_buttons)
		start["off"] = false
	scroll.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			start["v"] = scroll.scroll_vertical
			start["h"] = scroll.scroll_horizontal)
	scroll.get_v_scroll_bar().value_changed.connect(moved)
	scroll.get_h_scroll_bar().value_changed.connect(moved)
