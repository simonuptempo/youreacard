extends SceneTree
## Birthday screen: the year grid reaches the oldest year, scrolling while a finger is down
## cancels button presses (so a drag isn't a pick), and a plain tap picks.
var host: Control
func _initialize() -> void:
	run.call_deferred()

func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new(); e.position = pos; e.global_position = pos
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)
	root.push_input(e)

func run() -> void:
	var fails := 0
	var P = root.get_node("Profile")
	P.birth_year = 0; P.birth_month = 0
	host = Control.new(); host.size = Vector2(720, 1280); root.add_child(host)
	load("res://scripts/age_gate.gd").require(host, "Online play", func(): pass, func(): pass)
	await process_frame
	var ag := host.find_child("AgeGate", true, false)
	(ag.find_child("Year", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	var picker := host.find_child("Picker", true, false)
	var scroll: ScrollContainer
	for c in picker.get_children(): if c is ScrollContainer: scroll = c
	var grid: GridContainer = scroll.get_child(0)
	var first: Button = grid.get_child(0)
	if first.mouse_filter != Control.MOUSE_FILTER_PASS: fails += 1; print("FAIL: buttons should pass touches to the list")
	# Finger down on a year, the list scrolls: that press must not pick.
	var c0 := first.get_global_rect().get_center()
	mouse(c0, true); await process_frame
	scroll.scroll_vertical = 300; await process_frame; await process_frame
	if not first.disabled: fails += 1; print("FAIL: a drag should cancel the press")
	mouse(c0, false); await process_frame; await process_frame; await process_frame
	if host.find_child("Picker", true, false) == null: fails += 1; print("FAIL: a drag picked a year")
	if first.disabled: fails += 1; print("FAIL: buttons should work again after the drag")
	# The list goes all the way down to the oldest year.
	scroll.scroll_vertical = 100000; await process_frame; await process_frame
	var last: Button = grid.get_child(grid.get_child_count() - 1)
	var r := last.get_global_rect()
	if not scroll.get_global_rect().encloses(r): fails += 1; print("FAIL: the oldest year isn't reachable")
	mouse(r.get_center(), true); await process_frame
	mouse(r.get_center(), false); await process_frame; await process_frame
	var this_year: int = int(Time.get_date_dict_from_system()["year"])
	var says := (ag.find_child("Year", true, false) as Button).text
	if says != str(this_year - 100): fails += 1; print("FAIL: year shows ", says)
	P.birth_year = 0; P.birth_month = 0
	print("AGE PICKER OK" if fails == 0 else "AGE PICKER FAILED (%d)" % fails)
	quit()
