class_name AgeGate
## A neutral age screen, shared by every You're a Card game.
##
## Asked once per device, the first time a player reaches something that sends data off
## the phone (online play, or turning a photo into a cartoon), whichever game they're in.
## The answer is kept in Profile (on this phone only, never uploaded) and every game reuses
## it, so nobody is asked twice. Players under 13 keep everything that stays on the phone:
## playing the computer, building a card by hand, using a photo as it is, recording a voice.
##
## Neutral, per the FTC's COPPA guidance: it asks for a birthday without hinting at the
## "right" answer or saying which features depend on it, and the answer can't be changed.

const MIN_AGE := 13
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]


static func known() -> bool:
	return Profile.birth_year > 0 and Profile.birth_month > 0


## Age in whole years today (-1 if not asked yet).
static func age() -> int:
	if not known():
		return -1
	var now := Time.get_date_dict_from_system()
	var a: int = int(now["year"]) - Profile.birth_year
	if int(now["month"]) < Profile.birth_month:
		a -= 1
	return a


## True only if the player told us they're 13 or older.
static func ok() -> bool:
	return age() >= MIN_AGE


## Under 13: online play is the kid-safe version (guest account, a nickname from a list,
## friends by invite code only, no photo cartoons).
static func kid() -> bool:
	return known() and age() < MIN_AGE


## Run on_ok if the player may use `feature` (asking their birthday first if needed),
## otherwise explain it's not available and run on_no. on_no also runs if they back out.
## kids_ok: players under 13 may use it too (in its kid-safe version).
static func require(parent: Node, feature: String, on_ok: Callable, on_no: Callable, kids_ok := false) -> void:
	if known():
		if ok() or kids_ok:
			on_ok.call()
		else:
			_not_available(parent, feature, on_no)
		return
	_ask(parent, func():
		if ok() or kids_ok:
			on_ok.call()
		else:
			_not_available(parent, feature, on_no), on_no)


static func _overlay(parent: Node) -> Control:
	var o := Control.new()
	o.name = "AgeGate"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.size = Vector2(720, 1280)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.z_index = 100
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = Vector2(720, 1280)
	o.add_child(dim)
	parent.add_child(o)
	return o


static func _ask(parent: Node, done: Callable, cancel: Callable) -> void:
	var o := _overlay(parent)
	o.add_child(UI.panel(Vector2(40, 300), Vector2(640, 600)))
	var t := UI.label("When's your birthday?", Vector2(70, 336), Vector2(580, 56), 36, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font(900))
	o.add_child(t)
	var sub := UI.label("We only ask once. It stays on this device.", Vector2(70, 396), Vector2(580, 40), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_font_override("font", UI.font(600))
	o.add_child(sub)
	# Month and year: tap a box to pick from a grid. (A long drop-down list can't be
	# scrolled on iPhone, so the 100 years go in a scrolling grid instead.)
	var picked := {"month": 0, "year": 0}
	var this_year: int = int(Time.get_date_dict_from_system()["year"])
	var go := UI.button("Continue", Vector2(170, 640), Vector2(380, 92), UI.ACCENT, 32)
	go.add_theme_font_override("font", UI.font(800))
	go.disabled = true
	var month_btn := UI.button("Month", Vector2(80, 480), Vector2(300, 80), Color("#2f3866"), 26)
	month_btn.name = "Month"
	var year_btn := UI.button("Year", Vector2(400, 480), Vector2(240, 80), Color("#2f3866"), 26)
	year_btn.name = "Year"
	for btn in [month_btn, year_btn]:
		btn.add_theme_font_override("font", UI.font(800))
		o.add_child(btn)
	var refresh := func():
		month_btn.text = MONTHS[picked["month"] - 1] if picked["month"] > 0 else "Month"
		year_btn.text = str(picked["year"]) if picked["year"] > 0 else "Year"
		go.disabled = picked["month"] == 0 or picked["year"] == 0
	month_btn.pressed.connect(func():
		_grid(o, "Month", MONTHS, 3, func(i: int):
			picked["month"] = i + 1
			refresh.call()))
	var years: Array = []
	for y in range(this_year, this_year - 101, -1):
		years.append(str(y))
	year_btn.pressed.connect(func():
		_grid(o, "Year", years, 4, func(i: int):
			picked["year"] = this_year - i
			refresh.call()))
	o.add_child(go)
	go.pressed.connect(func():
		Profile.birth_month = picked["month"]
		Profile.birth_year = picked["year"]
		Profile.save_profile()
		o.queue_free()
		done.call())
	var back := UI.button("Not now", Vector2(170, 760), Vector2(380, 72), Color("#2f3866"), 26)
	back.add_theme_font_override("font", UI.font(800))
	back.pressed.connect(func():
		o.queue_free()
		cancel.call())
	o.add_child(back)


## A full-screen grid of choices that scrolls with a finger drag; calls pick(index).
static func _grid(parent: Control, title: String, items: Array, columns: int, pick: Callable) -> void:
	var sheet := Control.new()
	sheet.name = "Picker"
	sheet.size = Vector2(720, 1280)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.9)
	dim.size = Vector2(720, 1280)
	sheet.add_child(dim)
	sheet.add_child(UI.panel(Vector2(30, 120), Vector2(660, 1040)))
	var t := UI.label("Pick the " + title.to_lower(), Vector2(60, 140), Vector2(600, 56), 32, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font(900))
	sheet.add_child(t)
	var scroll := ScrollContainer.new()
	UI.touch_scroll(scroll)
	scroll.position = Vector2(50, 210)
	scroll.size = Vector2(620, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var w := (600.0 - 12 * (columns - 1)) / columns
	for i in items.size():
		var b := UI.button(str(items[i]), Vector2.ZERO, Vector2(w, 76), Color("#2f3866"), 26)
		b.custom_minimum_size = Vector2(w, 76)
		b.add_theme_font_override("font", UI.font(800))
		b.mouse_filter = Control.MOUSE_FILTER_PASS   # a drag on a button still scrolls the list
		# A finger that scrolled the list isn't a pick, even if it lifts on a button.
		b.button_down.connect(func(): b.set_meta("from", scroll.scroll_vertical))
		b.pressed.connect(func():
			if absi(scroll.scroll_vertical - int(b.get_meta("from", scroll.scroll_vertical))) > 12:
				return
			sheet.queue_free()
			pick.call(i))
		grid.add_child(b)
	var cancel := UI.button("Cancel", Vector2(210, 1052), Vector2(300, 84), Color("#3a4166"), 28)
	cancel.add_theme_font_override("font", UI.font(800))
	cancel.pressed.connect(sheet.queue_free)
	sheet.add_child(cancel)
	parent.add_child(sheet)


static func _not_available(parent: Node, feature: String, done: Callable) -> void:
	var o := _overlay(parent)
	o.add_child(UI.panel(Vector2(40, 340), Vector2(640, 520)))
	var t := UI.label("Ask a grown-up", Vector2(70, 376), Vector2(580, 56), 36, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font(900))
	o.add_child(t)
	var body := UI.label("%s isn't available on this device.\n\nYou can still play against the computer, build your card by hand, and use your photos as they are." % feature,
		Vector2(80, 450), Vector2(560, 240), 25, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.add_theme_font_override("font", UI.font(600))
	o.add_child(body)
	var ok_btn := UI.button("OK", Vector2(210, 730), Vector2(300, 90), UI.ACCENT, 32)
	ok_btn.add_theme_font_override("font", UI.font(800))
	ok_btn.pressed.connect(func():
		o.queue_free()
		done.call())
	o.add_child(ok_btn)
