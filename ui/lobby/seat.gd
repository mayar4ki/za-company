extends Control
## One seat in the lobby (ui/lobby/): a player's card in the character select's
## own dress - their sprite at 3x, their name, and how they are connected - or
## an OPEN seat, drawn dashed, which is how the lobby says how many more can
## come without a number. Picked as option A from the lobby preview.
##
## It is told what to show and draws it; it never asks Net anything, so the
## lobby stays the one place that reads the roster.
##
## A host sees KICK in the far corner of every guest's seat, the YOU tag's
## mirror. A press only says so (`kick_pressed`); what it means - ask once,
## kick on the second - is the room's (room_view.gd), which `arm()`s the tag.
##
## A guest's own seat has an arrow either side of the sprite, for playing
## somebody else (net.gd's *Who plays whom*). Again a press only says which
## way (`choose_pressed`), and which character that is, is the room's to ask.

signal kick_pressed(peer: int)
signal choose_pressed(step: int)

const Roster := preload("res://game/player/characters/roster.gd")
## DESIGN.md's ping colours, shared with the run's corner and its scoreboard.
const Ping := preload("res://ui/ping.gd")

const SIZE := Vector2(128, 160)
const SPRITE_PX := 96
const WALK_FPS := 8.0
## The menu theme's colours (tools/build_ui_theme.gd), which a card draws with
## itself because a frame drawn dashed is not a stylebox.
const SURFACE := Color("3a3941")
const BORDER := Color("674949")
const ACCENT := Color("6eb39d")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")
const BG := Color("1b1119")
## Somebody whose hello has not arrived yet has no character to show: a
## silhouette of the default body, so the seat is visibly taken and visibly
## not ready.
const SILHOUETTE := Color(0.15, 0.1, 0.15, 0.7)
const RAISED := Color("45434c")
const WARM := Color("ec773d")
const KICK_SIZE := Vector2(38, 14)
const KICK_ARMED_SIZE := Vector2(44, 14)
## The choosing arrows: pixel triangles beside the sprite's body, each inside a
## bigger hit area so a finger or a mouse need not find five pixels.
const ARROW := Vector2i(5, 9)
const ARROW_INSET := 22
const ARROW_TOP := 48
const ARROW_HIT := Vector2(32, 44)

## Read by tests: "open", "connecting" or "player".
var kind := "open"
## Whose seat this is, while somebody is in it.
var peer := 0
var _mine := false
var _choosable := false
var _frames: SpriteFrames = null
var _walk := 0
var _clock := 0.0

var _sprite: TextureRect
var _you: ColorRect
var _name: Label
var _line_1: Label
var _line_2: Label
var _kick: Button
var _kick_idle: StyleBoxFlat
var _kick_hot: StyleBoxFlat
## The left arrow, then the right.
var _arrows: Array[Button] = []


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = TextureRect.new()
	_sprite.position = Vector2((SIZE.x - SPRITE_PX) / 2.0, 4)
	_sprite.size = Vector2(SPRITE_PX, SPRITE_PX)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_name = _label(104, 16)
	_name.name = "Name"
	_line_1 = _label(124, 12)
	_line_1.name = "Line1"
	_line_2 = _label(140, 12)
	_line_2.name = "Line2"
	_you = ColorRect.new()
	_you.color = ACCENT
	_you.size = Vector2(34, 14)
	_you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var you_text := Label.new()
	you_text.text = "YOU"
	you_text.theme_type_variation = &"Footer"
	you_text.add_theme_color_override(&"font_color", BG)
	you_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you_text.size = _you.size
	you_text.position = Vector2(0, -1)
	_you.add_child(you_text)
	add_child(_you)
	_kick_idle = _box(BG, BORDER, 1)
	_kick_hot = _box(RAISED, WARM, 2)
	_kick = Button.new()
	_kick.name = "Kick"
	_kick.text = "KICK"
	_kick.visible = false
	_kick.add_theme_font_size_override(&"font_size", 12)
	_kick.add_theme_constant_override(&"outline_size", 0)
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		_kick.add_theme_stylebox_override(state, _kick_idle)
	_kick.add_theme_stylebox_override(&"focus", _kick_hot)
	_kick.add_theme_color_override(&"font_color", DIM)
	_kick.add_theme_color_override(&"font_hover_color", TEXT)
	_kick.add_theme_color_override(&"font_focus_color", TEXT)
	_kick.add_theme_color_override(&"font_pressed_color", TEXT)
	_kick.pressed.connect(func() -> void: kick_pressed.emit(peer))
	add_child(_kick)
	# Never focusable: a guest's room keeps the focus on LEAVE, and left and
	# right on the keyboard press these (room_view.gd) rather than reach them.
	for step in [-1, 1]:
		var arrow := Button.new()
		arrow.name = "Prev" if step < 0 else "Next"
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.visible = false
		arrow.size = ARROW_HIT
		var centre := ARROW_INSET + ARROW.x / 2.0
		arrow.position = Vector2(
			roundf((centre if step < 0 else SIZE.x - centre) - ARROW_HIT.x / 2),
			roundf(ARROW_TOP + ARROW.y / 2.0 - ARROW_HIT.y / 2))
		for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			arrow.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		arrow.pressed.connect(func() -> void: choose_pressed.emit(step))
		arrow.mouse_entered.connect(queue_redraw)
		arrow.mouse_exited.connect(queue_redraw)
		add_child(arrow)
		_arrows.append(arrow)
	arm(false)
	show_open()


func _ready() -> void:
	# The menu's small type, which a Button is not given by the theme.
	_kick.add_theme_font_override(&"font", get_theme_font(&"font", &"Footer"))


## Nobody here yet.
func show_open() -> void:
	kind = "open"
	peer = 0
	_kick.visible = false
	_mine = false
	_set_choosable(false)
	_frames = null
	_sprite.texture = null
	_you.visible = false
	_name.text = ""
	_line_1.text = "OPEN SEAT"
	_line_1.position.y = 70
	_line_1.add_theme_color_override(&"font_color", DIM)
	_line_2.text = ""
	queue_redraw()


## A row of Net's roster. `mine` is this machine's player, whose card walks;
## `kickable` puts KICK on it, which the room asks for on a host's screen, and
## `choosable` the arrows, which it asks for on a guest's own seat.
func show_row(row: Dictionary, mine: bool, kickable := false, choosable := false) -> void:
	peer = int(row.get("peer", 0))
	_kick.visible = kickable
	_mine = mine
	_you.visible = mine
	_name.text = String(row.get("name", "")).to_upper()
	_line_1.position.y = 124
	var character := String(row.get("character", ""))
	var route := String(row.get("route", ""))
	kind = "connecting" if route == "..." or character == "" else "player"
	var path := Roster.frames_path(character)
	_frames = load(path if path != "" else Roster.frames_path(Roster.DEFAULT_ID))
	_sprite.modulate = SILHOUETTE if kind == "connecting" else Color.WHITE
	_set_choosable(choosable and kind == "player")
	_walk = 0
	_sprite.texture = _frames.get_frame_texture("idle_down", 0) if _frames != null else null
	if kind == "connecting":
		_set_line(_line_1, "CONNECTING...", DIM)
		_set_line(_line_2, "", DIM)
	elif route == "HOST":
		_set_line(_line_1, "HOST", ACCENT)
		_set_line(_line_2, "", DIM)
	else:
		var ping := int(row.get("ping", -1))
		_set_line(_line_1, "..." if ping < 0 else "%d MS" % ping, Ping.colour(ping))
		_set_line(_line_2, route, Ping.MID if route == "RELAY" else DIM)
	queue_redraw()


## KICK asking "are you sure": wider, in the focus colour whether focused or
## not, so the question stays on screen while the player looks at the line
## under the seats that asks it in words.
func arm(asking: bool) -> void:
	_kick.text = "KICK?" if asking else "KICK"
	var size := KICK_ARMED_SIZE if asking else KICK_SIZE
	_kick.size = size
	_kick.custom_minimum_size = size
	_kick.position = Vector2(SIZE.x - size.x - 3, 3)
	_kick.add_theme_stylebox_override(&"normal", _kick_hot if asking else _kick_idle)
	_kick.add_theme_color_override(&"font_color", TEXT if asking else DIM)


## Read by tests.
func kick_button() -> Button:
	return _kick


## The arrow `step` points (-1 left, 1 right): what the keyboard presses, and
## what a test reads.
func arrow(step: int) -> Button:
	return _arrows[0 if step < 0 else 1]


func _set_choosable(on: bool) -> void:
	_choosable = on
	for each in _arrows:
		each.visible = on


func _process(delta: float) -> void:
	if not _mine or _frames == null or kind != "player":
		return
	_clock += delta
	if _clock < 1.0 / WALK_FPS:
		return
	_clock = 0.0
	_walk = (_walk + 1) % _frames.get_frame_count("walk_down")
	_sprite.texture = _frames.get_frame_texture("walk_down", _walk)


## Solid for a player - in the accent, two pixels wide, for this machine's -
## and dashed for an open seat. Whole pixels: filled rects, never lines.
func _draw() -> void:
	if kind == "open":
		for x in range(0, int(SIZE.x), 4):
			draw_rect(Rect2(x, 0, 2, 1), BORDER)
			draw_rect(Rect2(x, SIZE.y - 1, 2, 1), BORDER)
		for y in range(0, int(SIZE.y), 4):
			draw_rect(Rect2(0, y, 1, 2), BORDER)
			draw_rect(Rect2(SIZE.x - 1, y, 1, 2), BORDER)
		return
	var edge := 2 if _mine else 1
	draw_rect(Rect2(Vector2.ZERO, SIZE), ACCENT if _mine else BORDER)
	draw_rect(Rect2(Vector2(edge, edge), SIZE - Vector2(edge, edge) * 2), SURFACE)
	if _choosable:
		_draw_arrow(ARROW_INSET, -1)
		_draw_arrow(int(SIZE.x) - ARROW_INSET - ARROW.x, 1)


## A triangle pointing `step`'s way, a row at a time: one pixel at each end,
## `ARROW.x` across the middle. In the text colour while the mouse is on it.
func _draw_arrow(x: int, step: int) -> void:
	var colour := TEXT if arrow(step).is_hovered() else ACCENT
	var middle := ARROW.y / 2
	for i in ARROW.y:
		var width := ARROW.x - absi(middle - i)
		var left := x if step > 0 else x + ARROW.x - width
		draw_rect(Rect2(left, ARROW_TOP + i, width, 1), colour)


static func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_content_margin_all(0)
	return box


func _label(y: float, font_size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Footer" if font_size == 12 else &""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(4, y)
	label.size = Vector2(SIZE.x - 8, font_size + 4)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size == 16:
		label.add_theme_color_override(&"font_color", TEXT)
	add_child(label)
	return label


func _set_line(label: Label, text: String, colour: Color) -> void:
	label.text = text
	label.add_theme_color_override(&"font_color", colour)
