extends Control
## The game table: you (bottom) against a bot (top). The bot's turn is shown as a replay,
## the same way an async opponent's move will be shown once online play exists.

const COL_W := 118.0
const CHIP := Vector2(112, 34)
const SLOT := Vector2(52, 73)

const OPP_COLL_Y := 140.0
const MY_COLL_Y := 436.0
const HAND_Y := 624.0
const BAR_Y := 0.0

const TABLE_PANEL := Color("#102d2a")
var _turn_label: Label
var _collection_popup: Control
var _detail_card: Dictionary = {}
var _practice := false
var _practice_completed := 0
var _practice_panel: Control
const PRACTICE_TIPS := [
	"Tap a card to see what you can do. Try banking a bill or collecting a gem.",
	"Banked bills pay for heists. Banking a bill uses one play.",
	"Build matching gem sets. The dots show how many you need.",
	"Try a heist when you can afford its cost. Tap a highlighted target.",
	"Hide a twist in your vault to protect yourself on the bot's turn.",
	"Wild cards can count as any gem. Tap one to see its choices.",
	"Watch the bot's replay to see what changed and why.",
	"Moving your Wilds and taking back vault cards are free actions.",
	"You may finish your turn early. Discard down to the hand limit when asked.",
	"Try combining what you've learned: bank, collect, and plan your next move."
]
var g: GameState
var _online := false          # an online game against a real person (moves go to the server)
var _online_game := ""
var _online_seq := 0          # last server move this screen has caught up to
var _waiting := false
var bot_name := "Juno"
var bot_face: Dictionary = {}

var mode := "play"          # play | target | discard | busy | over
var selected_id := -1
var target_moves: Array = []
var swap_step := 0
var swap_mine := -1
var events_seen := 0

var board: Control
var bar: Control
var msg: Label
var info_lbl: Label
var end_btn: Button
var overlay: Control
var replay_queue: Array = []
var _replay_token := 0


func _ready() -> void:
	_practice = Profile.practice_requested
	Profile.practice_requested = false
	var saved := {}
	if Profile.resume_game:
		Profile.resume_game = false
		saved = Profile.saved_game()
	var online_id := Online.game_id
	Online.game_id = ""
	_online = online_id != "" and not _practice
	theme = UI.make_theme()
	add_child(Art.table_bg())
	# Pick a bot identity from the default cast.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cast_index := rng.randi_range(1, Profile.CAST.size() - 1)
	var first := rng.randi_range(0, 1)
	if Online.pending_character > 0:
		# "Play a character" from the online menu, cycling through the cast.
		cast_index = Online.pending_character
		Online.pending_character = -1
	var rematch := Profile.rematch_first >= 0 and Profile.rematch_cast > 0
	if rematch:
		cast_index = Profile.rematch_cast
		first = Profile.rematch_first
	Profile.rematch_first = -1
	Profile.rematch_cast = -1
	if saved.has("state"):
		cast_index = clampi(int(saved.get("cast_index", cast_index)), 1, Profile.CAST.size() - 1)
	_cast_index = cast_index
	var cast: Dictionary = Profile.CAST[cast_index]
	bot_name = cast["name"]
	bot_face = {"portrait_path": "res://art/role-%s.png" % cast["role"]}

	# Quiet panels let the felt remain visible without sitting behind small text.
	add_child(UI.panel(Vector2(16,16),Vector2(688,112),TABLE_PANEL,20))
	add_child(UI.panel(Vector2(16,308),Vector2(688,116),TABLE_PANEL,20))
	add_child(UI.panel(Vector2(0,1160),Vector2(720,120),Color("#102421"),0))
	board = Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	# Turn status and messages live in the bottom bar.
	_turn_label=UI.label("",Vector2(24,1166),Vector2(440,32),22,UI.ACCENT)
	add_child(_turn_label)
	msg = UI.label("",Vector2(24,1200),Vector2(444,70),17,UI.TEXT)
	add_child(msg)
	end_btn=UI.button("End Turn",Vector2(478,1180),Vector2(222,68),Color("#314742"),25)
	end_btn.pressed.connect(_on_end_pressed)
	add_child(end_btn)
	info_lbl=UI.label("",Vector2(24,1174),Vector2(430,82),21,UI.MUTED)
	info_lbl.visible=false
	bar=Control.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.z_index=20
	add_child(bar)
	var recap_btn := UI.button("Replay", Vector2(620, 84), Vector2(70, 32), Color("#314742"), 15)
	recap_btn.tooltip_text = "Replay their last turn"
	recap_btn.pressed.connect(_on_recap_pressed)
	add_child(recap_btn)
	var menu:=UI.button("Menu",Vector2(620,34),Vector2(70,46),Color("#314742"),17)
	if _practice:
		menu.text = "Exit"
		menu.tooltip_text = "Leave practice anytime"
		menu.z_index = 60
	menu.pressed.connect(_leave)
	add_child(menu)

	if _online:
		_online_open(online_id)
		return
	if saved.has("state"):
		_resume(saved)
		return
	g = GameState.new()
	g.setup(["You", bot_name], randi(), 0 if _practice else first, Profile.plays_per_turn)
	mode = "busy"
	_after_change()
	_set_msg("")
	if _practice:
		_practice_prompt(false)
	elif rematch:
		_rematch_start(g.current)
	else:
		_coin_flip(g.current)


# ------------------------------------------------------------------ coin flip

var _flip: Control
var _cast_index := 1


func _flip_layer() -> Control:
	_flip = Control.new()
	_flip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flip)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flip.add_child(dim)
	return _flip


## Rematch: no coin flip. Whoever lost the last game starts.
func _rematch_start(first: int) -> void:
	_flip_layer()
	var mine := first == 0
	_flip.add_child(UI.label("REMATCH", Vector2(0, 300), Vector2(720, 60), 44, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var a := AvatarView.new()
	a.data = _player_portrait() if mine else bot_face
	a.position = Vector2(270, 400)
	a.size = Vector2(180, 214)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip.add_child(a)
	_flip.add_child(UI.label("You lost last game, so you go first." if mine else "%s lost last game, so %s goes first." % [bot_name, bot_name], Vector2(40, 650), Vector2(640, 90), 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var go := UI.button("Start my turn" if mine else "Watch %s's turn" % bot_name, Vector2(170, 780), Vector2(380, 84), UI.ACCENT, 28)
	go.pressed.connect(_end_coin_flip.bind(first))
	_flip.add_child(go)


## Formal start of every game: a coin with your face on one side and the opponent's on
## the other is tossed, lands on the winner, and the winner taps to begin.
func _coin_flip(winner: int) -> void:
	Sfx.play("coin_flip")
	_flip_layer()
	_flip.add_child(UI.label("COIN FLIP", Vector2(0, 250), Vector2(720, 56), 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_flip.add_child(UI.label("Your face: you go first  ·  %s's face: %s goes first" % [bot_name, bot_name], Vector2(40, 312), Vector2(640, 64), 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var faces := [_player_portrait(), bot_face]
	var names := ["You", bot_name]
	var coin := Panel.new()
	coin.size = Vector2(240, 240)
	coin.position = Vector2(240, 470)
	coin.pivot_offset = coin.size / 2.0
	coin.add_theme_stylebox_override("panel", UI.box(Color("#e9b949"), 120, Color("#fff1b8"), 10))
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip.add_child(coin)
	var inner := Panel.new()
	inner.position = Vector2(26, 26)
	inner.size = Vector2(188, 188)
	inner.add_theme_stylebox_override("panel", UI.box(Color("#c98f1e"), 94, Color("#a8741a"), 4))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_child(inner)
	var face := AvatarView.new()
	face.position = Vector2(40, 30)
	face.size = Vector2(160, 190)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_child(face)
	var side_lbl := UI.label("", Vector2(0, 730), Vector2(720, 44), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_flip.add_child(side_lbl)
	var show_side := func(i: int):
		face.data = faces[i]
		face.queue_redraw()
		side_lbl.text = names[i]
	show_side.call(0)
	# Each half-turn swaps the side; an even count lands back on "You".
	var halves := 13 if winner == 1 else 14
	var tw := _flip.create_tween()
	tw.tween_property(coin, "position:y", 330.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(coin, "scale", Vector2(0.8, 0.8), 0.55)
	tw.tween_property(coin, "position:y", 470.0, 0.75).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(coin, "scale", Vector2.ONE, 0.75)
	var spin := _flip.create_tween()
	for h in halves:
		var d := 0.035 + 0.006 * h
		spin.tween_property(coin, "scale:y", 0.05, d)
		spin.tween_callback(show_side.bind((h + 1) % 2))
		spin.tween_property(coin, "scale:y", 1.0, d)
	await spin.finished
	if tw.is_running():
		await tw.finished
	if not is_instance_valid(_flip):
		return
	var won := winner == 0
	var verdict := UI.label("You won the coin flip!" if won else "%s won the coin flip." % bot_name, Vector2(0, 800), Vector2(720, 56), 36, UI.ACCENT if won else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var sub := UI.label("You go first, drawing just 1 card this turn." if won else "%s goes first." % bot_name, Vector2(0, 858), Vector2(720, 40), 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var go := UI.button("Start my turn" if won else "Watch %s's turn" % bot_name, Vector2(170, 930), Vector2(380, 84), UI.ACCENT, 28)
	for n in [verdict, sub, go]:
		n.modulate.a = 0.0
		_flip.add_child(n)
		_flip.create_tween().tween_property(n, "modulate:a", 1.0, 0.3)
	coin.pivot_offset = coin.size / 2.0
	var pulse := _flip.create_tween()
	pulse.tween_property(coin, "scale", Vector2(1.12, 1.12), 0.18)
	pulse.tween_property(coin, "scale", Vector2.ONE, 0.22)
	go.pressed.connect(_end_coin_flip.bind(winner))


func _end_coin_flip(winner: int) -> void:
	if is_instance_valid(_flip):
		_flip.queue_free()
	_flip = null
	if winner == 1:
		if _online:
			_online_wait()
		else:
			_run_bot_turn()
	else:
		mode = "play"
		_mark_my_turn()
		refresh()
		_set_msg("You're up first! Tap a card in your hand.")


# ------------------------------------------------------------------ faces

## The custom face for a card slot ("you", "bill3", "bouncer"...), or {} for its default.
## The bot only has a custom face on its You're a Card! wild.
func face_for(p: int, slot: String) -> Dictionary:
	if p == 0:
		return Profile.slot_face(slot)
	return bot_face if slot == "you" else {}


# ------------------------------------------------------------------ rendering

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _player_portrait() -> Dictionary:
	return Profile.me_portrait()

func refresh() -> void:
	_close_collection()
	_clear(board)
	_draw_header(1,Vector2(26,24))
	_draw_header(0,Vector2(26,316))
	_draw_vault(1,Vector2(492,38))
	_draw_vault(0,Vector2(566,328))
	_draw_gem_row(1, OPP_COLL_Y)
	_draw_gem_row(0, MY_COLL_Y)
	_draw_flashes()
	_draw_hand()
	var my_turn:=g.current==0 and g.winner<0
	end_btn.disabled=not my_turn or mode in ["busy","over","target"]
	end_btn.text="Discard" if mode=="discard" else "End Turn"
	_turn_label.text="Your turn · %d play%s left" % [g.plays_left,"" if g.plays_left==1 else "s"] if my_turn else "%s's turn" % bot_name
	if _replaying: _turn_label.text="Replaying %s's turn" % bot_name
	if mode=="target": _turn_label.text="Choose a highlighted target"
	if mode=="discard": _turn_label.text="Choose cards to discard"
	info_lbl.text="Tap a card to see your options" if my_turn else "Waiting for %s…" % bot_name
	if my_turn and g.plays_left==0: info_lbl.text="No plays left · End your turn"
	if mode=="target": info_lbl.text="Tap a highlighted gem or vault card"
	if mode in ["play","discard"]: _build_bar()

func _draw_header(p: int, pos: Vector2) -> void:
	var avatar:=AvatarView.new()
	avatar.data=_player_portrait() if p==0 else bot_face
	avatar.position=pos
	avatar.size=Vector2(78,88)
	avatar.clip_contents=true
	avatar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	board.add_child(avatar)
	board.add_child(UI.label("You" if p==0 else bot_name,pos+Vector2(90,0),Vector2(206,34),26,UI.ACCENT if p==g.current else UI.TEXT))
	board.add_child(UI.label("%d of %d sets complete" % [g.complete_count(p),GameState.SETS_TO_WIN],pos+Vector2(90,37),Vector2(300,28),20,UI.TEXT))
	board.add_child(UI.label("%d cards in hand" % g.hand(p).size(),pos+Vector2(90,66),Vector2(220,24),17,UI.MUTED))
	_draw_bank(p,pos+Vector2(322,7),132)
	board.add_child(UI.label("Vault",Vector2(492 if p==1 else 566,pos.y-4),Vector2(112,22),15,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER))

func _draw_bank(p: int,pos: Vector2,_max_w: float) -> void:
	board.add_child(UI.label("BANK",pos,Vector2(130,22),15,UI.MUTED))
	board.add_child(UI.label(CardDB.bills(g.bank_total(p)),pos+Vector2(0,24),Vector2(138,38),25,Color("#f3ca89")))
	if g.owes[p]>0:
		board.add_child(UI.label("owes %s" % CardDB.bills(g.owes[p]),pos+Vector2(0,60),Vector2(160,22),15,Color("#ff8a7a")))

func _draw_vault(p: int,pos: Vector2) -> void:
	for slot in 2:
		var spot:=pos+Vector2(slot*(SLOT.x+8),12)
		var card=g.vault(p)[slot]
		if card==null:
			var empty:=UI.panel(spot,SLOT,Color("#183e35"),8)
			empty.add_theme_stylebox_override("panel",UI.box(Color("#183e35"),8,Color("#55766b"),1))
			board.add_child(empty)
			board.add_child(UI.label("—",spot,SLOT,24,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER))
			continue
		var view:=CardView.new()
		view.position=spot
		view.size=SLOT
		board.add_child(view)
		view.setup(card,face_for(p,CardDB.slot_for(card["kind"])) if p==0 else {},p==1)
		if p==1:
			view.highlight=mode=="target" and _target_has("slot",slot)
			view.tapped.connect(_on_opp_vault_tapped.bind(slot))
		else: view.tapped.connect(_on_my_vault_tapped.bind(slot))

func _draw_collection(p: int,y: float) -> void:
	for i in CardDB.COLORS.size():
		var color: String=CardDB.COLORS[i]
		var cards:=g.set_cards(p,color)
		var done:=g.is_complete(p,color)
		var target:=false
		for card in cards:
			if mode=="target" and _chip_is_target(p,card["id"],color): target=true
		var tile:=UI.button("",Vector2(18+(i%3)*230,y+(i/3)*86),Vector2(224,80),TABLE_PANEL)
		tile.name="Collection_%d_%s" % [p,color]
		tile.add_theme_stylebox_override("normal",UI.box(Color("#254738") if done else TABLE_PANEL,12,UI.ACCENT if done or target else Color("#34534b"),3 if target else (2 if done else 1)))
		var gem:=GemView.new()
		gem.kind=color
		gem.position=Vector2(10,15)
		gem.size=Vector2(48,48)
		gem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tile.add_child(gem)
		var name_text:=CardDB.one_name(color)
		if done: name_text+=" ✓"
		tile.add_child(UI.label(name_text,Vector2(68,7),Vector2(150,28),20,UI.ACCENT if done else UI.TEXT))
		var dots:=""
		for n in CardDB.set_size(color): dots+=("● " if n<cards.size() else "○ ")
		tile.add_child(UI.label(dots,Vector2(68,39),Vector2(96,28),20,CardDB.tint(color).lightened(.3)))
		tile.add_child(UI.label("%d/%d" % [cards.size(),CardDB.set_size(color)],Vector2(169,40),Vector2(48,26),17,UI.MUTED))
		tile.pressed.connect(_inspect_collection.bind(p,color))
		board.add_child(tile)

## A player's gems in one row: a column per gem type, most complete on the left.
## Each column shows a gray outline for every gem the set needs; collected ones are filled in.
func _draw_gem_row(p: int, y: float) -> void:
	var order: Array = CardDB.COLORS.duplicate()
	order.sort_custom(func(a, b):
		var fa := float(g.set_cards(p, a).size()) / CardDB.set_size(a)
		var fb := float(g.set_cards(p, b).size()) / CardDB.set_size(b)
		if fa != fb:
			return fa > fb
		return CardDB.COLORS.find(a) < CardDB.COLORS.find(b))
	var col_w := 112.0
	var col_h := 132.0
	for i in order.size():
		var color: String = order[i]
		var cards := g.set_cards(p, color)
		var need := CardDB.set_size(color)
		var done := g.is_complete(p, color)
		var target := false
		for card in cards:
			if mode == "target" and _chip_is_target(p, card["id"], color):
				target = true
		var col := Button.new()
		col.position = Vector2(18 + i * (col_w + 4), y)
		col.size = Vector2(col_w, col_h)
		col.name = "Collection_%d_%s" % [p, color]
		var border: Color = UI.ACCENT if done or target else Color("#2c4a43")
		var bg: Color = Color("#254738") if done else TABLE_PANEL
		col.add_theme_stylebox_override("normal", UI.box(bg, 12, border, 3 if target else (2 if done else 1)))
		col.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.05), 12, border, 3 if target else (2 if done else 1)))
		col.add_theme_stylebox_override("pressed", UI.box(bg, 12, border, 2))
		col.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		# A shown-off set holds one extra gem, so squeeze the stack to fit the same box.
		var slots := maxi(need, cards.size())
		var gem := minf(36.0, (col_h - 12.0 - (slots - 1) * 3.0) / slots)
		var stack_h := slots * gem + (slots - 1) * 3.0
		var top := (col_h - stack_h) / 2.0
		for n in slots:
			var gv := GemView.new()
			gv.kind = color
			gv.position = Vector2((col_w - gem) / 2.0, top + n * (gem + 3.0))
			gv.size = Vector2(gem, gem)
			gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Filled from the top down; empty spots are a faint gray outline of the gem.
			var filled := n < cards.size()
			if not filled:
				gv.modulate = Color(0.55, 0.62, 0.6, 0.22)
			col.add_child(gv)
			if filled and cards[n]["kind"] == "wild":
				# A Wild is a clear gem that slowly shimmers through every gem color,
				# so it never looks like one of the six real gems.
				gv.kind = "diamond"
				var tints: Array = []
				for c in CardDB.COLORS:
					if c != "diamond":
						tints.append(CardDB.tint(c).lightened(0.25))
				gv.modulate = tints[0]
				var tw := gv.create_tween().set_loops()
				for k in range(1, tints.size() + 1):
					tw.tween_property(gv, "modulate", tints[k % tints.size()], 0.6)
		col.pressed.connect(_inspect_collection.bind(p, color))
		board.add_child(col)
		_flash_rects["coll_%d_%s" % [p, color]] = Rect2(col.position, col.size)


func _draw_piles() -> void:
	var deck:=CardView.new()
	deck.position=Vector2(550,300)
	deck.size=Vector2(56,78)
	board.add_child(deck)
	deck.setup({"id":-1,"kind":"wild"},{},true)
	deck.mouse_filter=Control.MOUSE_FILTER_IGNORE
	board.add_child(UI.label(str(g.deck.size()),Vector2(550,368),Vector2(56,24),15,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	if not g.discard.is_empty():
		var view:=CardView.new()
		view.position=Vector2(626,300)
		view.size=Vector2(56,78)
		board.add_child(view)
		view.setup(g.discard.back(),{})
		view.tapped.connect(func(_card): _inspect_discard())
	else: board.add_child(UI.panel(Vector2(626,300),Vector2(56,78),Color("#27403f"),6))

class HandCard:
	extends CardView
	var pressed_at:=Vector2.ZERO
	var held:=false
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed_at=event.global_position
				held=true
			else:
				if held and pressed_at.distance_to(event.global_position)<12:
					tapped.emit(self)
				held=false

func _draw_hand() -> void:
	var cards:=g.hand(0)
	board.add_child(UI.label("YOUR HAND · %d cards" % cards.size(),Vector2(22,580),Vector2(360,34),21,UI.TEXT))
	board.add_child(UI.label("Tap a card to flip",Vector2(382,582),Vector2(316,30),18,UI.MUTED,HORIZONTAL_ALIGNMENT_RIGHT))
	var area:=Vector2(684,1150.0-HAND_Y)
	var gap:=10.0
	var columns:=1
	var card_width:=0.0
	# Choose the largest complete cards that fit, with no overlap or scrolling.
	for candidate in range(1,cards.size()+1):
		var rows:=ceili(float(cards.size())/candidate)
		var width:=minf((area.x-gap*(candidate-1))/candidate,(area.y-gap*(rows-1))/rows/1.4)
		if width>card_width:
			card_width=width
			columns=candidate
	card_width=floorf(minf(card_width,230.0))
	var card_size:=Vector2(card_width,card_width*1.4)
	for i in cards.size():
		var card: Dictionary=cards[i]
		var row:=i/columns
		var count:=mini(columns,cards.size()-row*columns)
		var start_x:=18+(area.x-count*card_size.x-(count-1)*gap)/2
		var view:=HandCard.new()
		view.name="HandCard_%d" % card["id"]
		view.position=Vector2(start_x+(i%columns)*(card_size.x+gap),HAND_Y+row*(card_size.y+gap))
		view.size=card_size
		board.add_child(view)
		view.setup(card,face_for(0,CardDB.slot_for(card["kind"])))
		view.selected=card["id"]==selected_id
		view.tapped.connect(_on_hand_tapped.bind(card["id"]))
		# Cards you can't afford yet are grayed out with a red "needs" tag.
		var need:=CardDB.cost(card["kind"])
		if need>g.bank_total(0) and (card["kind"] in CardDB.HEISTS or card["kind"]=="lockpick"):
			view.dimmed=true
			var tag:=UI.label("Needs %s" % CardDB.bills(need),Vector2(view.position.x+card_size.x*0.08,view.position.y+card_size.y*0.42),Vector2(card_size.x*0.84,30),16,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
			tag.autowrap_mode=TextServer.AUTOWRAP_OFF
			tag.add_theme_font_size_override("font_size",15 if card_size.x<170 else 18)
			tag.add_theme_stylebox_override("normal",UI.box(Color("#b5452f"),10,Color("#ffd2c4"),2))
			tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
			board.add_child(tag)
	if cards.is_empty():
		board.add_child(UI.label("Your hand is empty. You'll draw 5 next turn.",Vector2(30,HAND_Y+100),Vector2(660,60),23,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER))

func _close_collection() -> void:
	if is_instance_valid(_collection_popup):
		_collection_popup.queue_free()
	_collection_popup=null

func _inspect_collection(p: int,color: String) -> void:
	if mode=="busy" or mode=="over": return
	_close_collection()
	# Trade: choosing which of YOUR gems to give is one tap, straight from the table.
	if mode=="target" and p==0:
		var mine: Array = g.set_cards(0,color).duplicate()
		mine.sort_custom(func(x, y): return x["kind"]=="wild" and y["kind"]!="wild")
		if not mine.is_empty() and _chip_is_target(0,int(mine[-1]["id"]),color):
			_on_chip_tapped(null,0,int(mine[-1]["id"]),color)
			return
	_collection_popup=Control.new()
	_collection_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_collection_popup.z_index=30
	add_child(_collection_popup)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tapping outside the popup closes it (so a tap meant for the table isn't lost).
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_collection.call_deferred())
	_collection_popup.add_child(dim)
	_collection_popup.add_child(UI.panel(Vector2(24,230),Vector2(672,790),TABLE_PANEL,22))
	_collection_popup.add_child(UI.label("%s · %s" % ["Your collection" if p==0 else bot_name,CardDB.one_name(color)],Vector2(44,252),Vector2(632,50),27,UI.ACCENT,HORIZONTAL_ALIGNMENT_CENTER))
	_collection_popup.add_child(UI.label("Tap the stack to choose it." if mode=="target" else ("Tap a gem to pawn it, or a Wild to move it." if p==0 else "Cards in this set are visible to both players."),Vector2(44,310),Vector2(632,48),21,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER))
	# The set is shown as one stack, each card a little offset, so you can count it at a glance.
	var cards: Array = g.set_cards(p,color).duplicate()
	cards.sort_custom(func(x, y): return x["kind"]=="wild" and y["kind"]!="wild")  # real gems on top
	var n:=cards.size()
	var step:=Vector2(34,30)
	var card_sz:=Vector2(214,300)
	var origin:=Vector2(360-(card_sz.x+(n-1)*step.x)/2.0,380)
	var targeting:=mode=="target" and n>0
	var top_id:=int(cards[n-1]["id"]) if n>0 else -1
	var stack_is_target:=targeting and _chip_is_target(p,top_id,color)
	for i in n:
		var card: Dictionary = cards[i]
		var view:=CardView.new()
		view.position=origin+step*i
		view.size=card_sz
		_collection_popup.add_child(view)
		view.setup(card,face_for(int(card.get("face",p)),"you") if card["kind"]=="wild" else {})
		view.highlight=stack_is_target and i==n-1
		# When targeting, any tap on the stack picks its top card.
		var pick: Dictionary = cards[n-1] if targeting else card
		view.tapped.connect(func(v):
			_detail_card=pick
			_close_collection()
			_on_chip_tapped(v,p,int(pick["id"]),color))
	if n>0:
		var count_text:="%d %s" % [n,CardDB.display_name(color)] if n!=1 else "1 %s" % CardDB.one_name(color)
		var how:=""
		if stack_is_target:
			var taking_all:=false
			for m in target_moves:
				if m.get("as","")=="grand": taking_all=true
			how="  ·  Tap the stack to take %s" % ("all %d" % n if taking_all and n>1 else ("it" if n==1 else "1 (the top card)"))
		_collection_popup.add_child(UI.label(count_text+how,Vector2(44,origin.y+card_sz.y+(n-1)*step.y+16),Vector2(632,40),23,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	if g.set_cards(p,color).is_empty():
		_collection_popup.add_child(UI.label("No gems in this set yet.",Vector2(60,450),Vector2(600,100),26,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER))
	if stack_is_target:
		# A clear button for it too, not just tapping the stack.
		var verb:="Take"
		for m in target_moves:
			if m.get("as","")=="swap" and p==0: verb="Give"
		var all:=false
		for m in target_moves:
			if m.get("as","")=="grand": all=true
		var what:=("all %d" % n) if all and n>1 else ("1 " + CardDB.one_name(color))
		var take:=UI.button("%s %s" % [verb, what],Vector2(366,916),Vector2(310,66),UI.ACCENT,24)
		var top: Dictionary = cards[n-1]
		take.pressed.connect(func():
			_detail_card=top
			_close_collection()
			_on_chip_tapped(null,p,int(top["id"]),color))
		_collection_popup.add_child(take)
		var back:=UI.button("Back to table",Vector2(44,916),Vector2(310,66),Color("#3a4166"),22)
		back.pressed.connect(_close_collection)
		_collection_popup.add_child(back)
	else:
		var close:=UI.button("Back to table",Vector2(180,916),Vector2(360,66),UI.ACCENT,24)
		close.pressed.connect(_close_collection)
		_collection_popup.add_child(close)

func _inspect_discard() -> void:
	if mode not in ["play","discard"] or g.discard.is_empty(): return
	_detail_card=g.discard.back()
	_bar_buttons([["Back to table",_cancel_selection,UI.ACCENT]])


func _playable_ids() -> Array:
	var ids: Array = []
	if g.current != 0:
		return ids
	for m in g.legal_moves(0):
		if m.has("card") and m["type"] in ["collect", "heist", "tool", "bank"]:
			ids.append(m["card"])
		elif m["type"] == "vault":
			var k: String = g.find_hand_card(0, m["card"])["kind"]
			if k in CardDB.TRAPS:
				ids.append(m["card"])
	return ids


# ------------------------------------------------------------------ action bar

func _clear_bar() -> void:
	_clear(bar)


func _bar_buttons(items: Array) -> void:
	_clear_bar()
	if mode=="target":
		for i in items.size():
			var button:=UI.button(items[i][0],Vector2(140,1080-(items.size()-1-i)*70),Vector2(440,62),Color("#314742"),22)
			button.pressed.connect(items[i][1])
			bar.add_child(button)
		return
	var card:=g.find_hand_card(0,selected_id) if selected_id>=0 else _detail_card
	# Big readable card on the left, a narrow column of actions on the right.
	var panel_h:=1150.0-HAND_Y
	var panel:=UI.panel(Vector2(18,HAND_Y),Vector2(684,panel_h),TABLE_PANEL,18)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	bar.add_child(panel)
	# The card fills the panel's full height so its text is readable on a phone.
	var card_h:=panel_h-20.0
	var card_w:=card_h*5.0/7.0
	if not card.is_empty():
		var preview:=CardView.new()
		preview.position=Vector2(10,10)
		preview.size=Vector2(card_w,card_h)
		panel.add_child(preview)
		preview.setup(card,face_for(0,CardDB.slot_for(card["kind"])))
		preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var col_x:=card_w+24.0 if not card.is_empty() else 16.0
	var col_w:=684.0-col_x-14.0
	panel.add_child(UI.label("What do you want to do?",Vector2(col_x,14),Vector2(col_w,30),18,UI.MUTED))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(col_x,52)
	scroll.size=Vector2(col_w,panel_h-64.0)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var choices:=VBoxContainer.new()
	choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation",10)
	scroll.add_child(choices)
	for item in items:
		var button_h:=58.0 if ThemeDB.fallback_font.get_string_size(item[0],HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<col_w-30.0 else 84.0
		var button:=UI.button(item[0],Vector2.ZERO,Vector2(col_w-6.0,button_h),item[2] if item.size()>2 else UI.ACCENT,18)
		button.custom_minimum_size=Vector2(col_w-6.0,button_h)
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if item[1].is_valid():
			button.pressed.connect(item[1])
		else:
			button.disabled = true  # an explanation, not an action
			button.add_theme_color_override("font_disabled_color", Color("#ffd9d0"))
			button.add_theme_stylebox_override("disabled", UI.box(item[2], 12))
		choices.add_child(button)
	# Turn the selected front over, then unfold its action side in the hand area.
	var source:=board.get_node_or_null("HandCard_%d" % selected_id)
	if source!=null and not card.is_empty():
		panel.scale.x=0.01
		panel.pivot_offset=Vector2(342,panel_h/2.0)
		panel.modulate.a=0.0
		var front:=CardView.new()
		front.position=source.position
		front.size=source.size
		front.pivot_offset=source.size/2
		bar.add_child(front)
		front.setup(card,face_for(0,CardDB.slot_for(card["kind"])))
		front.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var flip:=panel.create_tween()
		flip.tween_property(front,"scale:x",0.01,0.12)
		flip.tween_callback(front.queue_free)
		flip.tween_property(panel,"modulate:a",1.0,0.01)
		flip.tween_property(panel,"scale:x",1.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_bar() -> void:
	_clear_bar()
	if g.current != 0 or g.winner >= 0:
		return
	if mode == "discard":
		return
	if selected_id < 0:
		return
	var card := g.find_hand_card(0, selected_id)
	if card.is_empty():
		selected_id = -1
		return
	var items: Array = []
	var moves := g.legal_moves(0).filter(func(m): return m.get("card", -1) == selected_id)
	var seen := {}
	var pawn_items: Array = []
	for m in moves:
		match m["type"]:
			"bank":
				if CardDB.is_treasure(card["kind"]):
					pawn_items.append(["Pawn it (+%s)" % CardDB.bills(CardDB.value(card["kind"])), _apply_and_clear.bind(m), Art.COPPER])
				else:
					items.append(["Bank it (+%s)" % CardDB.bills(CardDB.value(card["kind"])), _apply_and_clear.bind(m), Art.COPPER])
			"collect":
				if card["kind"] == "wild":
					items.append(["Wild as %s" % CardDB.one_name(m["color"]), _apply_and_clear.bind(m), CardDB.tint(m["color"])])
				else:
					if g.is_complete(0, m["color"]):
						var n: int = g.set_cards(0, m["color"]).size() + 1
						var pay := GameState.extra_gem_pay(n - CardDB.set_size(m["color"]))
						items.append(["Add a %s %s (they pay you %s)" % [GameState.ordinal(n), CardDB.one_name(m["color"]), CardDB.bills(pay)], _apply_and_clear.bind(m), UI.ACCENT])
					else:
						items.append(["Add to collection", _apply_and_clear.bind(m), UI.ACCENT])
			"heist":
				var as_kind: String = m["as"]
				if seen.has(as_kind):
					continue
				seen[as_kind] = true
				var label := ("Copy " if card["kind"] == "wild" else "Play ") + CardDB.display_name(as_kind)
				if CardDB.cost(as_kind) > 0:
					label += " (%s)" % CardDB.bills(CardDB.cost(as_kind))
				if as_kind in ["shakedown", "payup"]:
					items.append([label, _apply_and_clear.bind(m), CardDB.TYPE_COLORS["heist"]])
				else:
					items.append([label + "…", _start_target.bind(as_kind), CardDB.TYPE_COLORS["heist"]])
			"tool":
				if card["kind"] == "lucky":
					items.append(["Play Lucky Break (draw 2)", _apply_and_clear.bind(m), CardDB.TYPE_COLORS["tool"]])
				elif not seen.has("lockpick"):
					seen["lockpick"] = true
					items.append(["Steal a random card from their vault (2 bills)", _lockpick_random, CardDB.TYPE_COLORS["tool"]])
			"vault":
				items.append(["Move to vault", _apply_and_clear.bind(m), Color("#4c8dff")])
	if g.plays_left <= 0:
		_set_msg("No plays left this turn. Tap End Turn.")
	else:
		var need := CardDB.cost(card["kind"])
		if card["kind"] in CardDB.HEISTS or card["kind"] == "lockpick" or card["kind"] == "wild":
			var short := need > g.bank_total(0)
			if short:
				_set_msg("%s costs %s. Your bank has %s. Bank some bills first!" % [CardDB.display_name(card["kind"]), CardDB.bills(need), CardDB.bills(g.bank_total(0))])
				items.push_front(["Needs %s to play (you have %d)" % [CardDB.bills(need), g.bank_total(0)], Callable(), Color("#7a3b3b")])
			elif items.size() <= 1 and card["kind"] != "wild":
				_set_msg("%s has no target right now. You can still move it to your vault." % CardDB.display_name(card["kind"]))
	items.append_array(pawn_items)  # collecting a gem comes first; pawning is the fallback
	items.append(["Cancel", _cancel_selection, Color("#3a4166")])
	_bar_buttons(items)


# ------------------------------------------------------------------ input

func _on_hand_tapped(_v: CardView, id: int) -> void:
	if mode in ["busy","over"]: return
	if g.current != 0 or g.winner >= 0:
		return
	if mode == "discard" and _online:
		_online_discard(id)
		return
	if mode == "discard":
		_apply({"type": "discard", "card": id})
		if g.hand(0).size() <= GameState.HAND_LIMIT:
			mode = "play"
			_on_end_pressed()
		else:
			_set_msg("Discard %d more." % (g.hand(0).size() - GameState.HAND_LIMIT))
			refresh()
		return
	if g.find_hand_card(0, id).is_empty():
		return
	if mode == "target":
		_cancel_selection()
	mode = "play"
	selected_id = -1 if selected_id == id else id
	Sfx.play("tap", -6.0)
	if selected_id >= 0:
		var k: String = g.find_hand_card(0, id)["kind"]
		var cost_txt := " Costs %s." % CardDB.bills(CardDB.cost(k)) if CardDB.cost(k) > 0 else ""
		_set_msg("%s: %s%s" % [CardDB.display_name(k), CardDB.ACTIONS[k]["text"] if CardDB.ACTIONS.has(k) else "Collect %d to complete the set." % CardDB.set_size(k), cost_txt])
	refresh()


func _on_chip_tapped(_v: CardView, p: int, id: int, color: String) -> void:
	if g.current != 0 or g.winner >= 0:
		return
	if mode == "target":
		for m in target_moves:
			if not m["type"] in ["heist", "counter"]:
				continue
			if m["as"] == "swipe" and p == 1 and m["their"] == id:
				_apply_and_clear(m)
				return
			if m["as"] == "grand" and p == 1 and m["color"] == color:
				_apply_and_clear(m)
				return
			if m["as"] == "swap":
				if swap_step == 0 and p == 0 and m["mine"] == id:
					swap_mine = id
					swap_step = 1
					var gave := g.find_collection_card(0, id)
					var gave_name := CardDB.one_name(color) if color != "" else (CardDB.display_name(gave[1]["kind"]) if not gave.is_empty() else "that gem")
					_set_msg("Giving your %s. Now tap one of %s glowing gems to take in return." % [gave_name, bot_name + "'s"])
					refresh()
					return
				if swap_step == 1 and p == 1 and m["mine"] == swap_mine and m["their"] == id:
					_apply_and_clear(m)
					return
		return
	# Free action: move a wild in your own collection.
	if mode == "play" and p == 0:
		var items: Array = []
		var can_pawn := false
		for m in g.legal_moves(0):
			if m["type"] == "move_wild" and m["card"] == id:
				items.append(["Move wild to %s" % CardDB.one_name(m["color"]), _apply_and_clear.bind(m), CardDB.tint(m["color"])])
			elif m["type"] == "pawn" and m["card"] == id:
				can_pawn = true
				items.append(["Pawn for %s (uses a play)" % CardDB.bills(CardDB.pawn_value(color)), _apply_and_clear.bind(m), Color("#c9a227")])
		if items.is_empty() and color != "":
			var found := g.find_collection_card(0, id)
			var is_wild: bool = not found.is_empty() and found[1]["kind"] == "wild"
			var why := "Wilds can't be pawned." if is_wild else ("No plays left this turn." if g.plays_left <= 0 else "A finished set needs this gem, so it can't be pawned.")
			items.append([why, Callable(), Color("#3a4166")])
		if not items.is_empty():
			selected_id = -1
			items.append(["Cancel", _cancel_selection, Color("#3a4166")])
			_set_msg("Pawn this gem for bills? It leaves your collection." if can_pawn else "Move your wild to another set (free, doesn't use a play).")
			refresh()
			_bar_buttons(items)


func _on_opp_vault_tapped(_v: CardView, slot: int) -> void:
	if mode == "target":
		for m in target_moves:
			if m.get("slot", -1) == slot and m["type"] == "tool":
				_apply_and_clear(m)
				return
	else:
		_set_msg("A face-down card. A twist… or a bluff? A Lockpick would tell you.")


func _on_my_vault_tapped(_v: CardView, slot: int) -> void:
	_detail_card = g.vault(0)[slot] if g.vault(0)[slot] != null else {}
	if g.current != 0 or mode != "play":
		return
	selected_id = -1
	refresh()
	_set_msg("Take this card back into your hand? (Free, doesn't use a play.)")
	_bar_buttons([["Move back to hand (free)", _apply_and_clear.bind({"type": "reclaim", "slot": slot}), Color("#4c8dff")], ["Cancel", _cancel_selection, Color("#3a4166")]])


## Their vault cards are face down, so a Lockpick just picks one at random.
func _lockpick_random() -> void:
	var options: Array = []
	for m in g.legal_moves(0):
		if m["type"] == "tool" and m.get("card", -1) == selected_id and m.has("slot"):
			options.append(m)
	if options.is_empty():
		return
	_apply_and_clear(options[randi() % options.size()])


func _start_target(as_kind: String) -> void:
	target_moves = []
	for m in g.legal_moves(0):
		if m.get("card", -1) != selected_id:
			continue
		if as_kind == "lockpick" and m["type"] == "tool":
			target_moves.append(m)
		elif m["type"] == "heist" and m["as"] == as_kind:
			target_moves.append(m)
	mode = "target"
	swap_step = 0
	swap_mine = -1
	match as_kind:
		"swipe": _set_msg("Tap a glowing gem to steal it.")
		"swap": _set_msg("Tap one of YOUR glowing gems to give away.")
		"grand": _set_msg("Tap a complete set to steal it all!")
		"lockpick": _set_msg("Tap one of their vault cards to steal it.")
	refresh()
	_bar_buttons([["Cancel", _cancel_selection, Color("#3a4166")]])


func _chip_is_target(p: int, id: int, color: String) -> bool:
	for m in target_moves:
		if not m["type"] in ["heist", "counter"]:
			continue
		match m["as"]:
			"swipe":
				if p == 1 and m["their"] == id:
					return true
			"grand":
				if p == 1 and m["color"] == color:
					return true
			"swap":
				if swap_step == 0 and p == 0 and m["mine"] == id:
					return true
				if swap_step == 1 and p == 1 and m["mine"] == swap_mine and m["their"] == id:
					return true
	return false


func _target_has(key: String, value) -> bool:
	for m in target_moves:
		if m.get(key, null) == value:
			return true
	return false


func _cancel_selection() -> void:
	_detail_card={}
	mode = "play"
	selected_id = -1
	target_moves = []
	swap_step = 0
	_set_msg("Tap a card in your hand.")
	refresh()


func _apply_and_clear(m: Dictionary) -> void:
	_detail_card={}
	selected_id = -1
	target_moves = []
	swap_step = 0
	mode = "play"
	_apply(m)


func _apply(m: Dictionary) -> void:
	if _online:
		_online_act(m)
		return
	if not g.apply(m):
		_set_msg("That move isn't allowed right now.")
		refresh()
		return
	_after_change()


func _on_end_pressed() -> void:
	if g == null or g.current != 0 or g.winner >= 0:
		return
	if g.hand(0).size() > GameState.HAND_LIMIT:
		mode = "discard"
		selected_id = -1
		_clear_bar()
		_set_msg("Too many cards! Tap %d card(s) to discard." % (g.hand(0).size() - GameState.HAND_LIMIT))
		refresh()
		return
	mode = "busy"
	selected_id = -1
	_clear_bar()
	if _show_my_recap():
		return   # "Got it" carries on with _finish_end_turn()
	_finish_end_turn()


func _finish_end_turn() -> void:
	_my_before = {}
	_my_first_event = -1
	_turn_before = _snapshot()   # recap compares against the board as you left it
	_turn_first_event = g.events.size()
	if _practice: _practice_completed += 1
	if _online:
		_online_end()
		return
	g.apply({"type": "end"})
	_after_change()
	_run_bot_turn()


func _run_bot_turn() -> void:
	mode = "busy"
	_set_msg("%s is taking their turn…" % bot_name)
	refresh()
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	if _turn_before.is_empty():
		_turn_before = _snapshot()
		_turn_first_event = g.events.size()
	# Play their turn one move at a time, keeping a copy of the table after each move.
	_frames = [{"state": g.clone(), "events": g.events.slice(_turn_first_event)}]
	var guard := 0
	while g.winner < 0 and g.current == 1 and guard < 40:
		guard += 1
		var mark := g.events.size()
		var move := Bot.choose_move(g, 1)
		if move.is_empty() or not g.apply(move):
			break
		var evs := g.events.slice(mark)
		if move["type"] == "end":
			# Their turn is over; your draw belongs to your turn, not the replay.
			_frames.append({"state": g.clone(), "events": [], "end": true})
		else:
			_frames.append({"state": g.clone(), "events": evs})
	_recap = _build_recap(_turn_before, _snapshot(), g.events.slice(_turn_first_event))
	_turn_before = {}
	events_seen = g.events.size()  # the replay shows these, not the one-at-a-time popups
	_replay_pending = true
	_save_game()
	_start_replay()


# ------------------------------------------------------------------ events + replay

func _after_change() -> void:
	_save_game()
	var new_events := g.events.slice(events_seen)
	events_seen = g.events.size()
	for e in new_events:
		Sfx.play_event(e)
		if e["big"] or (e["p"] == 1 and not str(e["text"]).contains(" drew ")):
			replay_queue.append(e)
		_set_msg(e["text"])
	refresh()
	if not replay_queue.is_empty() and overlay == null:
		_play_next_replay()
	elif replay_queue.is_empty():
		_finish_replays()


func _play_next_replay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	if replay_queue.is_empty():
		_finish_replays()
		return
	var e: Dictionary = replay_queue.pop_front()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_overlay_input)
	overlay.add_child(dim)
	var kind: String = e["card"]
	if kind != "":
		var cv := CardView.new()
		cv.size = Vector2(260, 364)
		cv.position = Vector2(230, 250)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(cv)
		var f := {}
		if CardDB.slot_for(kind) != "":
			var who: int = e["face"] if e["face"] >= 0 else e["p"]
			f = face_for(who, CardDB.slot_for(kind))
		cv.setup({"id": -1, "kind": kind}, f)
		cv.pivot_offset = cv.size / 2
		cv.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.tween_property(cv, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_speak(cv, e, overlay, Vector2(250, 120), 420)
	var who_label := "%s's turn" % bot_name if e["p"] == 1 else ""
	if who_label != "":
		overlay.add_child(UI.label(who_label, Vector2(0, 60), Vector2(720, 50), 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	overlay.add_child(UI.label(e["text"], Vector2(40, 640 if kind != "" else 520), Vector2(640, 140), 32, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	overlay.add_child(UI.label("tap to continue", Vector2(0, 800), Vector2(720, 40), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(overlay)
	_replay_token += 1
	var token := _replay_token
	var wait := 2.4 if e["big"] else 1.0
	await get_tree().create_timer(wait).timeout
	if token == _replay_token and is_inside_tree():
		_play_next_replay()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_replay_token += 1
		_play_next_replay()


func _finish_replays() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	if _practice and _practice_completed >= 10 and (g.current == 0 or g.winner >= 0):
		_practice_prompt(true)
		return
	if g.winner >= 0:
		_show_game_over()
		return
	if g.current == 0 and mode == "busy":
		Sfx.play("your_turn", -4.0)
		mode = "play"
		_mark_my_turn()
		var last := ""
		for i in range(g.events.size() - 1, -1, -1):
			if g.events[i]["p"] == 0:
				last = g.events[i]["text"]
				break
		_set_msg(PRACTICE_TIPS[mini(_practice_completed,9)] if _practice else "Your turn! " + last)
		refresh()
		if g.counter_owed[0]:
			_start_counter()


## A Mirror bounced their Trade: pick a free trade before doing anything else this turn.
func _start_counter() -> void:
	target_moves = g.legal_moves(0).filter(func(m): return m["type"] == "counter")
	selected_id = -1
	swap_step = 0
	swap_mine = -1
	mode = "target"
	_set_msg("Counter-trade! Tap one of YOUR glowing gems to give away (free).")
	refresh()
	_bar_buttons([["Skip counter-trade", _apply_and_clear.bind({"type": "counter_skip"}), Color("#3a4166")]])


func _show_game_over() -> void:
	if _practice:
		if g.current == 0: _practice_completed += 1
		_practice_prompt(_practice_completed >= 10)
		return
	mode = "over"
	refresh()
	_clear_bar()
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var won := g.winner == 0
	o.add_child(UI.label("You win!" if won else "%s wins!" % bot_name, Vector2(0, 150), Vector2(720, 90), 64, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var cv := CardView.new()
	cv.size = Vector2(280, 392)
	cv.position = Vector2(220, 270)
	o.add_child(cv)
	cv.setup({"id": -1, "kind": "wild"}, face_for(g.winner, "you"))
	o.add_child(UI.label("Finished in %d turns each." % ceili(g.turn_number / 2.0), Vector2(0, 690), Vector2(720, 40), 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not _online and g.winner == 0:
		Profile.mark_beaten(bot_name)
	_save_game()  # a finished game isn't reopened
	if _online:
		var back := UI.button("Back to your games", Vector2(160, 790), Vector2(400, 80), UI.ACCENT, 28)
		back.pressed.connect(_leave)
		o.add_child(back)
		add_child(o)
		return
	var loser := 1 - g.winner
	var again := UI.button("Rematch", Vector2(160, 760), Vector2(400, 80), UI.ACCENT, 32)
	again.pressed.connect(_on_rematch.bind(loser))
	o.add_child(UI.label("You'll go first" if loser == 0 else "%s will go first" % bot_name, Vector2(0, 842), Vector2(720, 30), 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	o.add_child(again)
	var menu := UI.button("Menu", Vector2(160, 884), Vector2(400, 70), Color("#3a4166"), 26)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	o.add_child(menu)
	add_child(o)


func _set_msg(t: String) -> void:
	if msg:
		msg.text = t


func _on_rematch(loser: int) -> void:
	Profile.rematch_first = loser
	Profile.rematch_cast = _cast_index
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ turn recap

var _recap: Dictionary = {}
var _recap_pending := false
var _recap_layer: Control
var _turn_before: Dictionary = {}
var _turn_first_event := 0


func _on_recap_pressed() -> void:
	if _frames.is_empty():
		_set_msg("No turn to replay yet.")
	elif mode in ["play", "discard"] and not _replaying:
		_cancel_selection()
		_start_replay()


## Where every card is: id -> [owner, zone, kind, color]. Zones: coll, bank, hand, vault.
func _snapshot(st: GameState = null) -> Dictionary:
	var gs: GameState = st if st != null else g
	var out := {}
	for p in 2:
		for color in CardDB.COLORS:
			for c in gs.set_cards(p, color):
				out[c["id"]] = [p, "coll", c["kind"], color]
		for c in gs.bank(p):
			out[c["id"]] = [p, "bank", c["kind"], ""]
		for c in gs.hand(p):
			out[c["id"]] = [p, "hand", c["kind"], ""]
		for c in gs.vault(p):
			if c != null:
				out[c["id"]] = [p, "vault", c["kind"], ""]
	return out


func _thing(info: Array, public_only: bool) -> String:
	var kind: String = info[2]
	match info[1]:
		"coll":
			var gem := CardDB.one_name(info[3])
			return ("Wild (as %s)" % gem) if kind == "wild" else gem
		"bank":
			return CardDB.bills(CardDB.value(kind))
		"vault":
			return "a face-down vault card" if public_only else "%s (from your vault)" % CardDB.display_name(kind)
	return "a card" if public_only else CardDB.display_name(kind)


## Turns a before/after snapshot of the opponent's turn into plain lists.
func _build_recap(before: Dictionary, after: Dictionary, evs: Array) -> Dictionary:
	var lost: Array = []
	var you_gained: Array = []
	var they_gained: Array = []
	var bills_lost := 0
	var bills_gained := 0
	var they_drew := 0
	for id in before:
		var b: Array = before[id]
		var a = after.get(id)
		if b[0] == 0:
			if a == null or a[0] != 0:
				if b[1] == "bank":
					bills_lost += CardDB.value(b[2])
				elif b[1] == "vault":
					var how := " (used up)" if a == null else " (stolen from your vault)"
					lost.append("Your " + CardDB.display_name(b[2]) + how)
				else:
					lost.append(_thing(b, false) + (" (from your hand)" if b[1] == "hand" else ""))
		elif a != null and a[0] == 0 and a[1] != "hand":
			you_gained.append(_thing(a, false))  # e.g. a gem your Mirror bounced your way
	for id in after:
		var a: Array = after[id]
		var b = before.get(id)
		if a[0] == 1:
			if b == null:
				if a[1] == "hand":
					they_drew += 1
					continue
			if b != null and b[0] == 1 and b[1] == a[1]:
				continue
			if a[1] == "bank":
				bills_gained += CardDB.value(a[2])
			elif a[1] == "coll":
				they_gained.append(_thing(a, true) + (" (from you)" if b != null and b[0] == 0 else ""))
			elif a[1] == "vault":
				they_gained.append("a face-down card in their vault")
			elif a[1] == "hand" and b != null and b[0] == 0:
				they_gained.append("your %s (into their hand)" % CardDB.display_name(a[2]))
		elif a[0] == 0 and b == null:
			pass  # your own draw, shown elsewhere
	if bills_lost > 0:
		lost.append(CardDB.bills(bills_lost) + " from your bank")
	if bills_gained > 0:
		they_gained.append(CardDB.bills(bills_gained) + " in their bank")
	var did: Array = []
	var twists: Array = []
	for e in evs:
		var t := str(e["text"])
		if e["card"] in ["shield", "mirror", "snare"] and e["p"] == 0:
			twists.append(t)
			if e.has("kept"):
				you_gained.append("Their %s card (into your hand, from your Snare)" % CardDB.display_name(e["kept"]))
		elif e["p"] == 1 or e["card"] != "":
			did.append(t)
	return {"did": did, "lost": lost, "you_gained": you_gained, "they_gained": they_gained, "twists": twists}


func _show_recap() -> void:
	if is_instance_valid(_recap_layer):
		_recap_layer.queue_free()
	_recap_layer = Control.new()
	_recap_layer.z_index = 40
	_recap_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_recap_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recap_layer.add_child(dim)
	_recap_layer.add_child(UI.panel(Vector2(30, 90), Vector2(660, 1040), Color("#1d2a2c"), 22))
	_recap_layer.add_child(UI.label("%s'S TURN" % bot_name.to_upper(), Vector2(30, 110), Vector2(660, 50), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(56, 176)
	scroll.size = Vector2(608, 830)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recap_layer.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(590, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var section := func(title: String, lines: Array, color: Color, empty: String):
		var h := Label.new()
		h.text = title
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", color)
		box.add_child(h)
		var items: Array = lines if not lines.is_empty() else [empty]
		for line in items:
			var l := Label.new()
			l.text = ("•  " + str(line)) if not lines.is_empty() else str(line)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(590, 0)
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", UI.TEXT if not lines.is_empty() else UI.MUTED)
			box.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 14)
		box.add_child(gap)
	section.call("YOU LOST", _recap["lost"], Color("#ff8a7a"), "Nothing. You're all good.")
	section.call("%s GAINED" % bot_name.to_upper(), _recap["they_gained"], Color("#f0b27a"), "Nothing you can see.")
	if not _recap["you_gained"].is_empty():
		section.call("YOU GAINED", _recap["you_gained"], Color("#8fe3a0"), "")
	if not _recap["twists"].is_empty():
		section.call("YOUR TWISTS", _recap["twists"], Color("#b9a7ff"), "")
	section.call("EVERYTHING THEY DID", _recap["did"], UI.MUTED, "They just drew cards.")
	var armed := 0
	for c in g.vault(0):
		if c != null and c["kind"] in CardDB.TRAPS:
			armed += 1
	var note := "Twists can't undo a turn that already happened. They fire on their own, mid-turn, if they're hidden in your vault beforehand."
	if armed > 0:
		note += " You have %d twist%s set for %s's next turn." % [armed, "" if armed == 1 else "s", bot_name]
	else:
		note += " Right now you have no twists set for their next turn."
	_recap_layer.add_child(UI.label(note, Vector2(56, 1012), Vector2(608, 30), 17, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UI.button("Got it — my turn", Vector2(170, 1150), Vector2(380, 80), UI.ACCENT, 28)
	ok.pressed.connect(_close_recap)
	_recap_layer.add_child(ok)


# ------------------------------------------------------------------ your turn's recap

var _my_before: Dictionary = {}   # the board when your turn began
var _my_first_event := -1         # first event of your turn


func _mark_my_turn() -> void:
	_my_before = _snapshot()
	_my_first_event = g.events.size()


## Your turn's events: from when it began, or (after resuming a saved game) this turn's number.
func _my_turn_events() -> Array:
	if _my_first_event >= 0 and _my_first_event <= g.events.size():
		return g.events.slice(_my_first_event)
	return g.events.filter(func(e): return int(e.get("turn", -1)) == g.turn_number)


## Turns your turn into plain lists: what you gained, what they lost, their twists, and so on.
func _build_my_recap(before: Dictionary, after: Dictionary, evs: Array) -> Dictionary:
	var you_gained: Array = []
	var they_lost: Array = []
	var you_lost: Array = []
	var they_gained: Array = []
	var banked := 0
	var bills_taken := 0
	var bills_lost := 0
	if not before.is_empty():
		for id in after:
			var a: Array = after[id]
			var b = before.get(id)
			if a[0] == 0 and a[1] != "hand":
				if b != null and b[0] == 0 and b[1] == a[1]:
					continue
				var from_them: bool = b != null and b[0] == 1
				match a[1]:
					"bank":
						if from_them:
							bills_taken += CardDB.value(a[2])
						else:
							banked += CardDB.value(a[2])
					"coll":
						you_gained.append(_thing(a, false) + (" (from %s)" % bot_name if from_them else ""))
					"vault":
						if from_them:
							you_gained.append("%s from %s's vault (into your vault)" % [CardDB.display_name(a[2]), bot_name])
						else:
							you_gained.append("%s set face-down in your vault" % CardDB.display_name(a[2]))
			elif a[0] == 0 and a[1] == "hand" and b != null and b[0] == 1:
				you_gained.append("%s from %s (into your hand)" % [CardDB.display_name(a[2]), bot_name])
			elif a[0] == 1 and b != null and b[0] == 0 and a[1] != "hand":
				they_gained.append(_thing(a, true))
		for id in before:
			var b: Array = before[id]
			var a = after.get(id)
			if b[0] == 1 and (a == null or a[0] != 1):
				match b[1]:
					"bank": pass   # counted as bills taken
					"coll": they_lost.append(_thing(b, true))
					"hand": they_lost.append("a card from their hand")
					"vault": they_lost.append("a face-down card from their vault" if a != null else "a vault card (used up)")
			elif b[0] == 0 and b[1] in ["coll", "bank"] and a != null and a[0] == 1:
				if b[1] == "bank":
					bills_lost += CardDB.value(b[2])
				else:
					you_lost.append(_thing(b, false))
	if banked > 0:
		you_gained.append(CardDB.bills(banked) + " banked")
	if bills_taken > 0:
		you_gained.append(CardDB.bills(bills_taken) + " from %s's bank" % bot_name)
		they_lost.append(CardDB.bills(bills_taken) + " from their bank")
	if bills_lost > 0:
		you_lost.append(CardDB.bills(bills_lost) + " from your bank")
	var did: Array = []
	var twists: Array = []
	var quotes: Array = []
	for e in evs:
		var t := str(e["text"])
		if e["card"] in ["shield", "mirror", "snare"] and e["p"] == 1:
			twists.append(t)
		elif e["p"] == 0 and not t.contains(" drew "):
			did.append(t)
		if str(e.get("said", "")) != "":
			quotes.append(e)
	return {"you_gained": you_gained, "they_lost": they_lost, "you_lost": you_lost, "they_gained": they_gained,
		"twists": twists, "did": did, "quotes": quotes}


## After End Turn: a recap of your turn. Returns false (nothing shown) if you didn't play anything.
func _show_my_recap() -> bool:
	var r := _build_my_recap(_my_before, _snapshot(), _my_turn_events())
	if r["did"].is_empty() and r["twists"].is_empty():
		return false
	if is_instance_valid(_recap_layer):
		_recap_layer.queue_free()
	_recap_layer = Control.new()
	_recap_layer.z_index = 40
	_recap_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_recap_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recap_layer.add_child(dim)
	_recap_layer.add_child(UI.panel(Vector2(30, 90), Vector2(660, 1040), Color("#1d2a2c"), 22))
	_recap_layer.add_child(UI.label("YOUR TURN", Vector2(30, 110), Vector2(660, 50), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(56, 176)
	scroll.size = Vector2(608, 940)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recap_layer.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(590, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var section := func(title: String, lines: Array, color: Color, empty: String):
		if lines.is_empty() and empty == "":
			return
		var h := Label.new()
		h.text = title
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", color)
		box.add_child(h)
		var items: Array = lines if not lines.is_empty() else [empty]
		for line in items:
			var l := Label.new()
			l.text = ("•  " + str(line)) if not lines.is_empty() else str(line)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(590, 0)
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", UI.TEXT if not lines.is_empty() else UI.MUTED)
			box.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 14)
		box.add_child(gap)
	var who := bot_name.to_upper()
	var known := not _my_before.is_empty()   # after resuming a saved game, only the plays are known
	section.call("YOU GAINED", r["you_gained"], Color("#8fe3a0"), "Nothing new this turn." if known else "")
	section.call("%s LOST" % who, r["they_lost"], Color("#f0b27a"), "Nothing." if known else "")
	section.call("%s'S TWISTS" % who, r["twists"], Color("#b9a7ff"), "")
	section.call("YOU LOST", r["you_lost"], Color("#ff8a7a"), "")
	section.call("%s GAINED" % who, r["they_gained"], Color("#f0b27a"), "")
	section.call("EVERYTHING YOU DID", r["did"], UI.MUTED, "")
	# Who said what: each character's face with their line in a bubble.
	var quotes: Array = r["quotes"]
	if not quotes.is_empty():
		var h := Label.new()
		h.text = "WHO SAID WHAT"
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", Color("#f3ca89"))
		box.add_child(h)
		for e in quotes.slice(maxi(0, quotes.size() - 6)):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var face := AvatarView.new()
			face.data = _speaker_face(e)
			face.custom_minimum_size = Vector2(60, 70)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(face)
			var bubble := PanelContainer.new()
			var style := UI.box(Color("#fffaf0"), 14, Color("#1b2038"), 2)
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			bubble.add_theme_stylebox_override("panel", style)
			bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var l := Label.new()
			l.text = "“%s”" % str(e["said"])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(470, 0)
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", Color("#1b2038"))
			bubble.add_child(l)
			row.add_child(bubble)
			box.add_child(row)
	var ok := UI.button("Got it — %s's turn" % bot_name, Vector2(150, 1150), Vector2(420, 80), UI.ACCENT, 28)
	ok.pressed.connect(func():
		_close_recap_layer_only()
		_finish_end_turn())
	_recap_layer.add_child(ok)
	return true


func _close_recap_layer_only() -> void:
	if is_instance_valid(_recap_layer):
		_recap_layer.queue_free()
	_recap_layer = null


func _close_recap() -> void:
	if is_instance_valid(_recap_layer):
		_recap_layer.queue_free()
	_recap_layer = null
	if g.counter_owed[0] and mode == "play":
		_start_counter()


# ------------------------------------------------------------------ turn replay on the board

var _frames: Array = []          # [{state, events}] one per opponent move; [0] is the start of their turn
var _replaying := false
var _real_g: GameState
var _flash: Dictionary = {}      # board areas that changed in the step being shown
var _flash_rects: Dictionary = {}
var _replay_panel: Control
var _replay_lines: Array = []
var _replay_card: Control
var _replay_skip := 0
var _replay_from_mode := "busy"


func _header_pos(p: int) -> Vector2:
	return Vector2(26, 24) if p == 1 else Vector2(26, 316)


func _zone_key(info: Array) -> String:
	match info[1]:
		"coll": return "coll_%d_%s" % [info[0], info[3]]
		"bank": return "bank_%d" % info[0]
		"vault": return "vault_%d" % info[0]
	return "hand_%d" % info[0]


func _changed_zones(a: GameState, b: GameState) -> Dictionary:
	var sa := _snapshot(a)
	var sb := _snapshot(b)
	var keys := {}
	for id in sa:
		if not sb.has(id) or _zone_key(sb[id]) != _zone_key(sa[id]):
			keys[_zone_key(sa[id])] = true
			if sb.has(id):
				keys[_zone_key(sb[id])] = true
	for id in sb:
		if not sa.has(id):
			keys[_zone_key(sb[id])] = true
	return keys


## Gold glow around every board area that changed in the step being replayed.
func _draw_flashes() -> void:
	var rects := _flash_rects.duplicate()
	for p in 2:
		var hp := _header_pos(p)
		rects["bank_%d" % p] = Rect2(hp + Vector2(312, -2), Vector2(150, 72))
		rects["hand_%d" % p] = Rect2(hp + Vector2(82, 60), Vector2(230, 32))
		rects["vault_%d" % p] = Rect2((Vector2(492, 38) if p == 1 else Vector2(566, 328)) + Vector2(-6, 6), Vector2(132, 85))
	for key in _flash:
		if not rects.has(key):
			continue
		var r: Rect2 = rects[key]
		var glow := Panel.new()
		glow.position = r.position - Vector2(4, 4)
		glow.size = r.size + Vector2(8, 8)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", UI.box(Color(1, 0.8, 0.25, 0.10), 14, UI.ACCENT, 4))
		board.add_child(glow)
		var tw := glow.create_tween().set_loops(3)
		tw.tween_property(glow, "modulate:a", 0.35, 0.22)
		tw.tween_property(glow, "modulate:a", 1.0, 0.22)


func _start_replay() -> void:
	if _frames.size() < 2 and _frames.size() > 0 and _frames[0]["events"].is_empty():
		_end_replay_now()
		return
	_replay_from_mode = mode if mode in ["play", "discard"] else "busy"
	_replaying = true
	for step in _replay_steps():
		for e in step[2]:
			_decide_line(e)
	_set_msg("Watch what %s did. Tap the panel to skip ahead." % bot_name)
	mode = "busy"
	_real_g = g
	_close_replay_panel()
	_clear_bar()
	_build_replay_panel()
	_run_replay()


func _replay_steps() -> Array:
	# Each step: [state before, state after, lines]
	var steps: Array = []
	var first: Dictionary = _frames[0]
	var lines0: Array = []
	for e in first["events"]:
		lines0.append(e)
	if not lines0.is_empty():
		steps.append([first["state"], first["state"], lines0, {"hand_1": true}])
	for i in range(1, _frames.size()):
		var f: Dictionary = _frames[i]
		if f.get("end", false):
			continue
		steps.append([_frames[i - 1]["state"], f["state"], f["events"], {}])
	return steps


func _build_replay_panel() -> void:
	_replay_panel = Control.new()
	_replay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_panel.z_index = 25
	add_child(_replay_panel)
	var y := HAND_Y - 46.0
	var bg := Panel.new()
	bg.position = Vector2(16, y)
	bg.size = Vector2(688, 1150 - y)
	bg.add_theme_stylebox_override("panel", UI.box(Color("#14302c"), 18, UI.ACCENT, 2))
	bg.gui_input.connect(_on_replay_panel_input)
	_replay_panel.add_child(bg)
	_replay_panel.add_child(UI.label("%s'S TURN" % bot_name.to_upper(), Vector2(36, y + 12), Vector2(420, 36), 26, UI.ACCENT))
	_replay_panel.add_child(UI.label("tap to skip ahead", Vector2(36, y + 46), Vector2(420, 24), 15, UI.MUTED))
	_replay_scroll = ScrollContainer.new()
	_replay_scroll.position = Vector2(36, y + 80)
	_replay_scroll.size = Vector2(448, 1150 - y - 180)
	_replay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_replay_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_panel.add_child(_replay_scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_scroll.add_child(box)
	_replay_box = box
	_replay_lines = []
	for step in _replay_steps():
		var group: Array = []
		for e in step[2]:
			var l := Label.new()
			l.text = "•  " + str(e["text"])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(440, 0)
			l.add_theme_font_size_override("font_size", 19)
			l.add_theme_color_override("font_color", UI.MUTED)
			l.modulate.a = 0.35
			box.add_child(l)
			group.append(l)
		_replay_lines.append(group)
	_replay_card = Control.new()
	_replay_card.position = Vector2(494, y + 70)
	_replay_card.size = Vector2(190, 266)
	_replay_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_panel.add_child(_replay_card)


func _show_step_card(evs: Array) -> void:
	_clear(_replay_card)
	# Each character who acts in this step gets a turn on screen (e.g. their Grand Heist,
	# then your Bouncer's Shield). Steps with no character just show the card played.
	var shown: Array = []
	for e in evs:
		if Sfx.speaker(e) != "":
			shown.append(e)
	if shown.is_empty():
		for e in evs:
			if e["card"] != "":
				shown.append(e)
				break
	var token := _replay_skip
	for k in shown.size():
		if k > 0:
			# Let the previous character finish their line before the next one speaks.
			await get_tree().create_timer(maxf(1.25, Sfx.voice_left() + 0.2)).timeout
			if token != _replay_skip or not is_instance_valid(_replay_card):
				return
			_clear(_replay_card)
			for b in _replay_panel.get_children():
				if b.z_index == 30:
					b.queue_free()
		var e: Dictionary = shown[k]
		var kind: String = e["card"]
		var cv := CardView.new()
		cv.size = _replay_card.size
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_card.add_child(cv)
		var f := {}
		if CardDB.slot_for(kind) != "":
			var who: int = e["face"] if e["face"] >= 0 else e["p"]
			f = face_for(who, CardDB.slot_for(kind))
		cv.setup({"id": -1, "kind": kind}, f)
		cv.pivot_offset = cv.size / 2.0
		cv.scale = Vector2(0.7, 0.7)
		cv.create_tween().tween_property(cv, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play_event(e)
		_speak(cv, e, _replay_panel, Vector2(_replay_card.position.x - 150, _replay_card.position.y - 92), 330)


func _step_speakers(evs: Array) -> int:
	var n := 0
	for e in evs:
		if Sfx.speaker(e) != "":
			n += 1
	return n


func _run_replay() -> void:
	var steps := _replay_steps()
	for i in steps.size():
		if not _replaying or not is_inside_tree():
			return
		var step: Array = steps[i]
		g = step[1]
		_flash = step[3] if not step[3].is_empty() else _changed_zones(step[0], step[1])
		refresh()
		for j in _replay_lines.size():
			for l in _replay_lines[j]:
				l.modulate.a = 1.0 if j <= i else 0.35
				l.add_theme_color_override("font_color", UI.TEXT if j == i else UI.MUTED)
		for se in step[2]:
			if Sfx.speaker(se) == "":
				Sfx.play_event(se)  # characters' own sounds play as each one appears
		_show_step_card(step[2])
		var token := _replay_skip
		var t := 0.0
		var hold := 1.6 + 1.25 * maxi(0, _step_speakers(step[2]) - 1)
		while (t < hold or Sfx.voice_left() > 0.0) and token == _replay_skip and _replaying:
			if not is_inside_tree():
				return  # you left the table mid-replay
			await get_tree().process_frame
			t += get_process_delta_time()
	if not _replaying or not is_inside_tree():
		return
	g = _real_g
	_flash = {}
	refresh()
	_replay_summary()


func _replay_summary() -> void:
	_clear(_replay_card)
	for b in _replay_panel.get_children():
		if b.z_index == 30:
			b.queue_free()  # the last step's big speech bubble
	for group in _replay_lines:
		for l in group:
			l.modulate.a = 1.0
			l.add_theme_color_override("font_color", UI.TEXT)
	var y := HAND_Y - 46.0
	var lost: Array = _recap.get("lost", [])
	var gained: Array = _recap.get("they_gained", [])
	var text := "You lost: " + (", ".join(lost) if not lost.is_empty() else "nothing")
	text += "\n%s gained: " % bot_name + (", ".join(gained) if not gained.is_empty() else "nothing you can see")
	# Who said what this turn: each character's face with their line in a bubble.
	var quotes: Array = []
	for step in _replay_steps():
		for e in step[2]:
			if str(e.get("said", "")) != "":
				quotes.append(e)
	if quotes.is_empty():
		_replay_panel.add_child(UI.label(text, Vector2(494, y + 76), Vector2(196, 260), 17, Color("#f3ca89")))
	else:
		var sep := HSeparator.new()
		sep.custom_minimum_size = Vector2(440, 10)
		_replay_box.add_child(sep)
		var sum := UI.label(text, Vector2.ZERO, Vector2(440, 0), 18, Color("#f3ca89"))
		sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sum.custom_minimum_size = Vector2(440, 0)
		_replay_box.add_child(sum)
		_replay_scroll.mouse_filter = Control.MOUSE_FILTER_PASS  # scroll if it runs long
		_show_quotes(quotes.slice(maxi(0, quotes.size() - 4)), Vector2(492, y + 70))
	var again := UI.button("Watch again", Vector2(40, 1150 - 82), Vector2(250, 62), Color("#314742"), 21)
	again.pressed.connect(_watch_again)
	_replay_panel.add_child(again)
	var done := UI.button("Start my turn" if _replay_from_mode == "busy" else "Back to my turn", Vector2(310, 1150 - 82), Vector2(370, 62), UI.ACCENT, 23)
	if _practice and _practice_completed >= 10: done.text = "Finish practice"
	done.pressed.connect(_end_replay_now)
	_replay_panel.add_child(done)


## Up to four little faces down the right side, each with what they said.
func _show_quotes(quotes: Array, at: Vector2) -> void:
	var y := at.y
	for e in quotes:
		var face := AvatarView.new()
		face.data = _speaker_face(e)
		face.position = Vector2(at.x, y + 4)
		face.size = Vector2(56, 66)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_panel.add_child(face)
		var lbl := UI.label(str(e["said"]), Vector2(at.x + 76, y + 8), Vector2(118, 0), 16, Color("#1b2038"), HORIZONTAL_ALIGNMENT_CENTER)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var font := lbl.get_theme_font("font")
		var text_h := font.get_multiline_string_size(str(e["said"]), HORIZONTAL_ALIGNMENT_CENTER, 118, 16).y
		var h := maxf(48.0, text_h + 18.0)
		var bubble := Panel.new()
		bubble.position = Vector2(at.x + 68, y)
		bubble.size = Vector2(134, h)
		bubble.add_theme_stylebox_override("panel", UI.box(Color("#fffaf0"), 14, Color("#1b2038"), 2))
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_panel.add_child(bubble)
		var tail := Polygon2D.new()
		tail.polygon = PackedVector2Array([Vector2(at.x + 70, y + 16), Vector2(at.x + 70, y + 34), Vector2(at.x + 56, y + 30)])
		tail.color = Color("#fffaf0")
		_replay_panel.add_child(tail)
		lbl.size = Vector2(118, h - 14)
		lbl.position = Vector2(at.x + 76, y + 7)
		_replay_panel.add_child(lbl)
		for n in [face, bubble, tail, lbl]:
			n.modulate.a = 0.0
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.25).set_delay(0.12 * quotes.find(e))
		y += maxf(h, 70.0) + 12.0


func _on_replay_panel_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_replay_skip += 1


func _watch_again() -> void:
	_close_replay_panel()
	_replaying = false
	g = _real_g
	mode = _replay_from_mode
	_start_replay()


func _close_replay_panel() -> void:
	if is_instance_valid(_replay_panel):
		_replay_panel.queue_free()
	_replay_panel = null


func _end_replay_now() -> void:
	if _real_g != null:
		g = _real_g
	_replaying = false
	_replay_pending = false
	_save_game()
	_flash = {}
	_close_replay_panel()
	if _replay_from_mode in ["play", "discard"]:
		mode = _replay_from_mode
		refresh()
	else:
		mode = "busy"
		_finish_replays()


# Practice uses the normal rules and bot; its progress lives only in this scene.
func _practice_prompt(complete: bool) -> void:
	mode = "over" if complete else "busy"
	_clear_bar()
	refresh()
	if is_instance_valid(_practice_panel): _practice_panel.queue_free()
	_practice_panel = Control.new()
	_practice_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_panel.z_index = 50
	add_child(_practice_panel)
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_panel.add_child(dim)
	_practice_panel.add_child(UI.panel(Vector2(40,340),Vector2(640,580),TABLE_PANEL,22))
	var title := "Practice complete!" if complete else ("Let's practice" if _practice_completed == 0 else "Keep practicing")
	_practice_panel.add_child(UI.label(title,Vector2(64,370),Vector2(592,70),36,UI.ACCENT,HORIZONTAL_ALIGNMENT_CENTER))
	var note := "That was a 10-turn tutorial against the bot. You've learned the basics and you're ready to play!" if complete else "Try cards, watch the bot, and learn at your own pace. Tap Exit anytime when you feel ready to play."
	if not complete and _practice_completed > 0:
		note = "That deal is finished. Continue practicing with a fresh hand, or leave whenever you feel ready."
	_practice_panel.add_child(UI.label(note,Vector2(72,460),Vector2(576,170),26,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	var go := UI.button("Play for real" if complete else "Start practice" if _practice_completed == 0 else "Continue practice",Vector2(100,680),Vector2(520,76),UI.ACCENT,27)
	go.pressed.connect(func():
		if complete:
			Profile.practice_requested = false
			Profile.rematch_first = -1
			Profile.rematch_cast = -1
			get_tree().reload_current_scene()
		else:
			_practice_panel.queue_free()
			_practice_panel = null
			if g.winner >= 0:
				g.setup(["You",bot_name],randi(),0,Profile.plays_per_turn)
				events_seen = g.events.size()
				replay_queue.clear()
				_frames.clear()
				_recap.clear()
			mode = "play"
			_mark_my_turn()
			selected_id = -1
			_set_msg(PRACTICE_TIPS[mini(_practice_completed,9)])
			refresh())
	_practice_panel.add_child(go)
	var done := UI.button("Done" if complete else "Back to menu",Vector2(100,780),Vector2(520,68),Color("#314742"),25)
	done.pressed.connect(func(): Profile.go("main"))
	_practice_panel.add_child(done)



# ------------------------------------------------------------------ online games

func _leave() -> void:
	_waiting = false
	_left = true
	_save_game()
	get_tree().change_scene_to_file("res://scenes/online.tscn" if _online else "res://scenes/main.tscn")


func _online_load(d: Dictionary) -> void:
	var opp: Dictionary = d.get("opponent", {})
	bot_name = str(opp.get("name", "Opponent"))
	var av = opp.get("avatar", {})
	# Opponents only ever send cartoon avatar settings; with none, they get the default card art.
	bot_face = AvatarView.normalized(av) if typeof(av) == TYPE_DICTIONARY and not av.is_empty() else {"portrait_path": "res://art/role-you.png"}
	g = GameState.from_view(d["view"])
	_online_seq = int(d.get("move_count", 0))


func _online_open(id: String) -> void:
	_online_game = id
	_save_game()
	mode = "busy"
	_set_msg("Loading your game…")
	var r := await Online.call_fn("state", {"game_id": id, "since_seq": 1000000})
	if not is_inside_tree():
		return
	if not r["ok"]:
		_set_msg(r["error"] + " Tap Menu to go back.")
		return
	_online_load(r["data"])
	events_seen = g.events.size()
	refresh()
	if g.winner >= 0:
		_show_game_over()
	elif _online_seq == 0 and g.turn_number <= 1:
		_coin_flip(g.current)  # both players see the same, already-settled coin flip
	elif g.current == 0:
		_finish_replays()
	else:
		_online_wait()


func _online_act(m: Dictionary) -> void:
	mode = "busy"
	_clear_bar()
	var r := await Online.call_fn("act", {"game_id": _online_game, "move": m})
	if not is_inside_tree():
		return
	if not r["ok"]:
		_set_msg(r["error"])
		await _online_resync()
		return
	_online_load(r["data"])
	mode = "play"
	_after_change()


func _online_discard(id: int) -> void:
	await _online_act({"type": "discard", "card": id})
	if g.hand(0).size() <= GameState.HAND_LIMIT:
		mode = "play"
		_on_end_pressed()
	else:
		mode = "discard"
		_set_msg("Discard %d more." % (g.hand(0).size() - GameState.HAND_LIMIT))
		refresh()


func _online_end() -> void:
	_set_msg("Sending your turn…")
	var r := await Online.call_fn("act", {"game_id": _online_game, "move": {"type": "end"}})
	if not is_inside_tree():
		return
	if not r["ok"]:
		_set_msg(r["error"])
		await _online_resync()
		return
	_online_load(r["data"])
	events_seen = g.events.size()
	refresh()
	if g.winner >= 0:
		_show_game_over()
	else:
		_online_wait()


## Their turn: check the server every few seconds. When they finish, replay their moves.
func _online_wait() -> void:
	mode = "busy"
	_waiting = true
	var before := g.clone()
	_set_msg("Waiting for %s to play. You can leave; your game is saved and you'll find it under Your games." % bot_name)
	refresh()
	var every := 0.4 if OS.get_environment("YAC_SERVER") != "" else 4.0
	while _waiting and is_inside_tree():
		await get_tree().create_timer(every).timeout
		if not is_inside_tree() or not _waiting:
			return
		var r := await Online.call_fn("state", {"game_id": _online_game, "since_seq": _online_seq})
		if not is_inside_tree() or not _waiting:
			return
		if not r["ok"]:
			continue
		var v: Dictionary = r["data"]["view"]
		if int(v.get("current", 1)) != 0 and int(v.get("winner", -1)) < 0:
			continue  # still their turn (they may be mid-turn)
		_waiting = false
		_online_replay(before, r["data"])
		return


func _online_replay(before: GameState, d: Dictionary) -> void:
	_frames = [{"state": before, "events": []}]
	var evs: Array = []
	for m in d.get("moves", []):
		if m.get("mine", false):
			continue
		var st := GameState.from_view(m["view"])
		st.players[1]["name"] = bot_name
		if int(m["view"].get("current", 1)) == 0 and int(m["view"].get("winner", -1)) < 0:
			_frames.append({"state": st, "events": [], "end": true})  # their End Turn; your draw isn't part of it
		else:
			_frames.append({"state": st, "events": st.events})
			evs.append_array(st.events)
	var before_snap := _snapshot(before)
	_online_load(d)
	_recap = _build_recap(before_snap, _snapshot(), evs)
	events_seen = g.events.size()
	_start_replay()


func _online_resync() -> void:
	var r := await Online.call_fn("state", {"game_id": _online_game, "since_seq": 1000000})
	if not is_inside_tree():
		return
	if r["ok"]:
		_online_load(r["data"])
		events_seen = g.events.size()
	if g.winner >= 0:
		_show_game_over()
	elif g.current == 0:
		mode = "play"
		_mark_my_turn()
		refresh()
	else:
		_online_wait()



# ------------------------------------------------------------------ talking cards

## When a character's card is played, they say their line: the card wobbles like it's
## talking and a speech bubble pops up. Voices come from Sfx (one voice per character).
## Decide once whether this event's character speaks, and which line (stored on the event
## so the replay, "Watch again" and the recap all agree). Not every play gets a line.
func _decide_line(e: Dictionary) -> void:
	if e.has("said"):
		return
	var role := Sfx.speaker(e)
	e["said"] = ""
	if role == "":
		return
	var who: int = e["face"] if int(e.get("face", -1)) >= 0 else int(e.get("p", 0))
	var mine := Profile.is_custom(role) and (role != "you" or who == 0)
	var own := mine and VoiceRecorder.has_voice(role)
	if not Sfx.should_speak(role, e, own):
		return
	var alt := mine and bool(Profile.voice_alt.get(role, false))
	# The Wild speaks as Nana Bea when it shows her; any other face gets the androgynous voice.
	var nana := false
	if role == "you":
		var f := face_for(who, "you")
		nana = f.is_empty() or str(f.get("portrait_path", "")) == "res://art/role-you.png"
	var i := Sfx.pick_line(role, str(e.get("card", "")), own, alt, nana)
	if i < 0:
		return
	e["said"] = Sfx.LINES[role][i]
	e["said_i"] = i
	e["said_role"] = role
	e["said_who"] = who
	e["said_voice"] = [own, alt, nana]


## The face of whoever said an event's line (your custom face, the bot's, or the character art).
func _speaker_face(e: Dictionary) -> Dictionary:
	var role: String = e.get("said_role", "")
	var f := face_for(int(e.get("said_who", 0)), CardDB.slot_for(str(e.get("card", ""))))
	if f.is_empty() and role == "you":
		f = _player_portrait() if int(e.get("said_who", 0)) == 0 else bot_face
	return f if not f.is_empty() else {"portrait_path": "res://art/role-%s.png" % role}


func _speak(card: Control, e: Dictionary, parent: Control, at: Vector2, width: float) -> void:
	if not is_instance_valid(parent):
		return
	_decide_line(e)
	var line: String = e.get("said", "")
	if line == "":
		return  # characters don't comment on every single play
	# The bubble always shows; the voice plays only if voices are on (Settings).
	var v: Array = e.get("said_voice", [false, false, false])
	Sfx.play_line(str(e["said_role"]), int(e["said_i"]), bool(v[0]), bool(v[1]), v.size() > 2 and bool(v[2]))
	card.pivot_offset = card.size / 2.0
	var wob := card.create_tween()
	wob.tween_interval(0.2)
	for a in [-7.0, 6.0, -4.0, 3.0, 0.0]:
		wob.tween_property(card, "rotation_degrees", a, 0.09).set_trans(Tween.TRANS_SINE)
	var talk := card.create_tween().set_loops(4)
	talk.tween_property(card, "scale:y", 1.035, 0.08)
	talk.tween_property(card, "scale:y", 1.0, 0.08)
	var bubble := Control.new()
	bubble.position = at
	bubble.z_index = 30
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := UI.label(line, Vector2(18, 10), Vector2(width - 36, 0), 26, Color("#1b2038"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_font_size_override("font_size", 26)
	var h := maxf(58.0, lbl.get_minimum_size().y + 20.0)
	var box := Panel.new()
	box.size = Vector2(width, h)
	box.add_theme_stylebox_override("panel", UI.box(Color("#fffaf0"), 22, Color("#1b2038"), 3))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(box)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(width * 0.42, h - 3), Vector2(width * 0.58, h - 3), Vector2(width * 0.47, h + 26)])
	tail.color = Color("#fffaf0")
	bubble.add_child(tail)
	lbl.size = Vector2(width - 36, h - 20)
	bubble.add_child(lbl)
	parent.add_child(bubble)
	bubble.pivot_offset = Vector2(width * 0.5, h)
	bubble.scale = Vector2(0.2, 0.2)
	bubble.modulate.a = 0.0
	var pop := bubble.create_tween()
	pop.tween_interval(0.15)
	pop.tween_property(bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(bubble, "modulate:a", 1.0, 0.15)


# ------------------------------------------------------------------ saving a game in progress

var _replay_scroll: ScrollContainer
var _replay_box: VBoxContainer
var _replay_pending := false   # their turn was played but you haven't watched the replay yet
var _left := false             # you tapped Menu: keep the game for Continue, don't reopen it at launch


## Saved after every move and when the app goes to the background, so swiping the app
## away never loses a game. Practice isn't saved; finished games are cleared.
func _save_game() -> void:
	if _practice:
		return
	if _online:
		if _online_game != "":
			if _left or mode == "over":
				Profile.clear_saved_game(Profile.ONLINE_SAVE)
			else:
				Profile.save_game({"online": _online_game}, Profile.ONLINE_SAVE)
		return
	var st: GameState = _real_g if _replaying and _real_g != null else g
	if st == null:
		return
	if st.winner >= 0:
		Profile.clear_saved_game()
		return
	var frames: Array = []
	for f in _frames:
		frames.append({"state": f["state"].to_dict(false), "events": f["events"], "end": f.get("end", false)})
	Profile.save_game({"version": 1, "cast_index": _cast_index, "bot_name": bot_name, "open": not _left,
		"state": st.to_dict(), "frames": frames, "recap": _recap, "replay_pending": _replay_pending})


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if is_inside_tree() and (g != null or _online):
			_save_game()


## Pick up a saved game exactly where it was.
func _resume(saved: Dictionary) -> void:
	g = GameState.from_dict(saved["state"])
	events_seen = g.events.size()
	_frames = []
	for f in saved.get("frames", []):
		var evs: Array = GameState.from_view({"events": f.get("events", [])}).events
		_frames.append({"state": GameState.from_dict(f["state"]), "events": evs, "end": bool(f.get("end", false))})
	_recap = saved.get("recap", {})
	mode = "busy"
	refresh()
	if g.winner >= 0:
		_finish_replays()
	elif g.current == 1:
		_run_bot_turn()           # the app closed before their turn was played
	elif bool(saved.get("replay_pending", false)) and _frames.size() > 1:
		_replay_pending = true
		_start_replay()           # show what they did while you were away
	else:
		_finish_replays()
		_set_msg("Welcome back! Your turn.")
