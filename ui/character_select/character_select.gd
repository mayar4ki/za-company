extends Control
## Pick who to play. Sits between the main menu's Play button and the game:
## one focusable portrait per roster character, left/right to browse, Enter or
## a click to choose. The choice is saved through Settings so the next visit
## starts on the same character, then the game scene loads - or, while the
## development switch is on, the level select (ui/level_select/) does, and on
## the way to online play the lobby does (`next_scene`). It asks no name on
## that way either: online you are called what your character is called, and
## no two players in a room play the same one (autoload/net.gd's *Who plays
## whom*).

const GAME_SCENE := "res://game/game.tscn"
const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
## The development floor picker, which comes next only while it is switched on.
const LevelSelect := preload("res://ui/level_select/level_select.gd")
const LEVEL_SELECT_SCENE := "res://ui/level_select/level_select.tscn"

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")

## Where picking somebody goes instead of the game, when the screen that sent
## the player here asked for it: the main menu's HOST ONLINE and JOIN ONLINE set
## the lobby, so the pick is made once and online play reuses this screen.
## Spent on use - or on backing out - like game.gd's `next_start`.
static var next_scene := ""

## 32px frames drawn at a whole multiple, matching the game's pixel scale rules.
const PORTRAIT_PX := 64
const WALK_FPS := 8.0

## Two rows of five rather than one row: ten 72px portraits side by side are
## 774px, which is wider than the 640px viewport.
@onready var _row: GridContainer = %Roster
@onready var _back_button: Button = %BackButton
@onready var _hint: Label = %Hint

## Button -> {"icon": TextureRect, "frames": SpriteFrames}
var _portraits := {}
var _focused: Button = null
var _walk_frame := 0


func _ready() -> void:
	_back_button.pressed.connect(_go_back)
	if _online():
		_hint.text = "ARROWS SELECT   ENTER GO ONLINE   ESC BACK"

	# The menu is already playing this; asking again is a no-op and keeps the
	# track unbroken across the scene change. It only actually starts anything
	# when this screen is entered directly, which is what the tests do.
	Music.play(Music.MENU)

	var saved: String = Settings.get_value(&"player", &"character", Roster.DEFAULT_ID)
	var first: Button = null
	var focus_target: Button = null
	for entry in Roster.CHARACTERS:
		var button := _make_portrait(entry)
		_row.add_child(button)
		if first == null:
			first = button
		if entry["id"] == saved:
			focus_target = button
	(focus_target if focus_target != null else first).grab_focus()

	# The focused portrait walks in place; everyone else stands still.
	var timer := Timer.new()
	timer.wait_time = 1.0 / WALK_FPS
	timer.autostart = true
	timer.timeout.connect(_animate_focused)
	add_child(timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Said here rather than in `_go_back()`, which the Back BUTTON also
		# calls - and a button press already makes its own noise.
		UiSound.back()
		_go_back()


func _go_back() -> void:
	next_scene = ""
	get_tree().change_scene_to_file(MENU_SCENE)


func _make_portrait(entry: Dictionary) -> Button:
	var frames := load(entry["frames"]) as SpriteFrames

	var button := Button.new()
	button.name = entry["id"]
	button.custom_minimum_size = Vector2(72, 92)

	# The button is the one control here; its children must not eat the mouse.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = frames.get_frame_texture("idle_down", 0)
	box.add_child(icon)

	var label := Label.new()
	label.text = String(entry["name"]).to_upper()
	label.theme_type_variation = &"Footer"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	button.add_child(box)
	button.pressed.connect(_choose.bind(entry["id"]))
	button.focus_entered.connect(_on_portrait_focused.bind(button))

	_portraits[button] = {"icon": icon, "frames": frames}
	return button


## On the way to the lobby, rather than to a run of your own.
static func _online() -> bool:
	return next_scene != ""


func _choose(id: String) -> void:
	Settings.set_value(&"player", &"character", id)
	var next := next_scene
	next_scene = ""
	if next == "":
		next = LEVEL_SELECT_SCENE if LevelSelect.enabled() else GAME_SCENE
	get_tree().change_scene_to_file(next)


func _on_portrait_focused(button: Button) -> void:
	if _focused != null and _portraits.has(_focused):
		var prev: Dictionary = _portraits[_focused]
		prev["icon"].texture = prev["frames"].get_frame_texture("idle_down", 0)
	_focused = button
	_walk_frame = 0


func _animate_focused() -> void:
	if _focused == null or not _portraits.has(_focused):
		return
	var portrait: Dictionary = _portraits[_focused]
	_walk_frame = (_walk_frame + 1) % portrait["frames"].get_frame_count("walk_down")
	portrait["icon"].texture = portrait["frames"].get_frame_texture("walk_down", _walk_frame)
