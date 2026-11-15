class_name Art
extends RefCounted
## Loads the painted art from res://art/. Every caller falls back to the
## code-drawn version when a file is missing, so art can be swapped in piecemeal.

static var _cache := {}

const FRAME_FOR_TYPE := {
	"treasure": "frame-treasure", "heist": "frame-heist", "trap": "frame-trap",
	"tool": "frame-tool", "wild": "frame-wild", "money": "frame-money",
}
## Title ink per card type, matched to each frame's accent stripe.
const INK_FOR_TYPE := {
	"treasure": Color("#7a5310"), "heist": Color("#8e1b2c"), "trap": Color("#5b2a86"),
	"tool": Color("#1f4f9a"), "wild": Color("#1f7a45"), "money": Color("#8a4a22"),
}
const COPPER := Color("#c8794a")
const CARD_IVORY := Color("#f7f0e1")


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_cache[name] = t
	return t


static func treasure(color: String) -> Texture2D:
	return tex("treasure-" + color)


static func loot(kind: String) -> Texture2D:
	return tex("loot-" + str(CardDB.CRITTERS.get(kind, "")))


## A coin: the critter art, or a plain copper coin with its value.
static func draw_coin(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var t := loot(kind)
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		# A native value badge on the coin stays crisp at bank-chip and card sizes.
		draw_badge(ci, c + Vector2(0, r * 0.55), r * 0.34, CardDB.value(kind))
		return
	ci.draw_circle(c, r, COPPER)
	ci.draw_circle(c, r * 0.8, Color("#f3e3c8"))
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.1)
	ci.draw_string(font, c + Vector2(-r, fs * 0.35), str(CardDB.value(kind)), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color("#8a4a22"))


## Small copper badge with a number (coin cost or value).
static func draw_badge(ci: CanvasItem, c: Vector2, r: float, n: int) -> void:
	ci.draw_circle(c, r, Color("#6e3a1a"))
	ci.draw_circle(c, r * 0.86, COPPER)
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.15)
	ci.draw_string(font, c + Vector2(-r, fs * 0.36), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)


static func frame(card_type: String) -> Texture2D:
	return tex(FRAME_FOR_TYPE.get(card_type, "frame-treasure"))


## The card back with its corners cut round, so it sits cleanly on the table.
static func card_back() -> Texture2D:
	if _cache.has("_card_back_round"):
		return _cache["_card_back_round"]
	var src := tex("card-back")
	var out: Texture2D = null
	if src != null:
		var img := src.get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var w := img.get_width()
			var h := img.get_height()
			var r := int(w * 0.07)
			for cy in [r, h - r - 1]:
				for cx in [r, w - r - 1]:
					var x0: int = 0 if cx == r else w - r
					var y0: int = 0 if cy == r else h - r
					for y in range(y0, y0 + r):
						for x in range(x0, x0 + r):
							var d := Vector2(x - cx, y - cy).length()
							if d > r:
								img.set_pixel(x, y, Color(0, 0, 0, 0))
							elif d > r - 1.5:
								var c := img.get_pixel(x, y)
								c.a *= clampf(r - d, 0.0, 1.0)
								img.set_pixel(x, y, c)
			out = ImageTexture.create_from_image(img)
	_cache["_card_back_round"] = out
	return out


## Draw a texture inside rect, keeping its aspect ratio (contain).
static func draw_fit(ci: CanvasItem, t: Texture2D, rect: Rect2, modulate := Color.WHITE) -> void:
	var ts := t.get_size()
	var s := minf(rect.size.x / ts.x, rect.size.y / ts.y)
	var sz := ts * s
	ci.draw_texture_rect(t, Rect2(rect.position + (rect.size - sz) / 2.0, sz), false, modulate)


## A TextureRect for the logo, or a plain label if the logo file is missing.
static func logo(pos: Vector2, sz: Vector2) -> Control:
	var t := tex("logo")
	if t == null:
		return UI.label("You're a Card", pos, sz, int(sz.y * 0.55), UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture = t
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Full-screen felt table, or a flat color if missing.
static func table_bg() -> Control:
	var t := tex("table-background")
	if t == null:
		var c := ColorRect.new()
		c.color = UI.BG
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		return c
	var r := TextureRect.new()
	r.texture = t
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
