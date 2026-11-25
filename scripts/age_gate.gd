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
	var month := OptionButton.new()
	month.position = Vector2(80, 480)
	month.size = Vector2(300, 80)
	month.add_theme_font_size_override("font_size", 26)
	month.add_item("Month")
	for m in MONTHS:
		month.add_item(m)
	month.get_popup().add_theme_font_size_override("font_size", 28)
	o.add_child(month)
	var year := OptionButton.new()
	year.position = Vector2(400, 480)
	year.size = Vector2(240, 80)
	year.add_theme_font_size_override("font_size", 26)
	year.add_item("Year")
	var this_year: int = int(Time.get_date_dict_from_system()["year"])
	for y in range(this_year, this_year - 101, -1):
		year.add_item(str(y))
		year.set_item_metadata(year.item_count - 1, y)
	year.get_popup().add_theme_font_size_override("font_size", 28)
	o.add_child(year)
	var go := UI.button("Continue", Vector2(170, 640), Vector2(380, 92), UI.ACCENT, 32)
	go.add_theme_font_override("font", UI.font(800))
	go.disabled = true
	o.add_child(go)
	var refresh := func(_i := 0):
		go.disabled = month.selected <= 0 or year.selected <= 0
	month.item_selected.connect(refresh)
	year.item_selected.connect(refresh)
	go.pressed.connect(func():
		Profile.birth_month = month.selected
		Profile.birth_year = int(year.get_item_metadata(year.selected))
		Profile.save_profile()
		o.queue_free()
		done.call())
	var back := UI.button("Not now", Vector2(170, 760), Vector2(380, 72), Color("#2f3866"), 26)
	back.add_theme_font_override("font", UI.font(800))
	back.pressed.connect(func():
		o.queue_free()
		cancel.call())
	o.add_child(back)


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
