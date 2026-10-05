extends Control
## Settings overlay, shared by the main menu and the pause menu.
##
## An overlay rather than its own screen because the pause menu cannot leave the
## scene - the game is still sitting behind it, paused. One panel serves both,
## so the two can never drift apart.
##
## It drives Display and Difficulty; the saving lives there, next to the
## applying, so a change made with F11 is remembered the same way as one made
## here, and a difficulty picked here is the one a host's screen shows.

signal closed

## The pause menu's copy says no: the difficulty is read once, when a run
## starts, so a row offering it mid-run would change nothing anybody could see.
## Hidden rather than greyed out - it is set before a run, here from the main
## menu or on the host screen.
@export var offers_difficulty := true

@onready var _mode: OptionButton = %ModeOption
@onready var _window_size: OptionButton = %WindowSizeOption
@onready var _zoom: OptionButton = %ZoomOption
@onready var _difficulty_label: Label = %DifficultyLabel
@onready var _difficulty: OptionButton = %DifficultyOption
@onready var _back_button: Button = %BackButton

## Parallel to the window-size dropdown's items.
var _sizes: Array[Vector2i] = []
## Whatever had focus when the panel opened, so closing puts it back.
var _return_focus: Control = null


func _ready() -> void:
	# The pause menu is the whole reason: it runs with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mode.item_selected.connect(_on_mode_selected)
	_window_size.item_selected.connect(_on_window_size_selected)
	_zoom.item_selected.connect(_on_zoom_selected)
	_difficulty.item_selected.connect(_on_difficulty_selected)
	_back_button.pressed.connect(close)
	_difficulty_label.visible = offers_difficulty
	_difficulty.visible = offers_difficulty


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	# Swallow it, or the pause menu would treat the same press as unpause.
	get_viewport().set_input_as_handled()
	# Closing by the Back button is a press and sounds like one; closing by
	# Escape is a back. The cue is named after what the player did.
	UiSound.back()
	close()


func is_open() -> bool:
	return visible


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_refresh()
	visible = true
	_mode.grab_focus()


func close() -> void:
	visible = false
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	closed.emit()


## Reads the live window state every time rather than trusting a cached value:
## F11 can change it while the panel is closed.
func _refresh() -> void:
	_mode.clear()
	_mode.add_item("WINDOWED", 0)
	_mode.add_item("FULLSCREEN", 1)
	_mode.select(1 if Display.is_fullscreen() else 0)

	_sizes = Display.available_window_sizes()
	var current := Display.window_size()
	# A saved size the monitor can no longer show still belongs in the list, or
	# the dropdown would silently disagree with what is stored.
	if not _sizes.has(current):
		_sizes.append(current)
		_sizes.sort()
	_window_size.clear()
	for i in _sizes.size():
		_window_size.add_item(_size_label(_sizes[i]), i)
	_window_size.select(_sizes.find(current))

	_zoom.clear()
	for i in Display.ZOOMS.size():
		_zoom.add_item(_zoom_label(Display.ZOOMS[i]), i)
	_zoom.select(maxi(Display.ZOOMS.find(Display.zoom()), 0))

	_difficulty.clear()
	for i in Difficulty.MODES.size():
		_difficulty.add_item(Difficulty.MODES[i]["name"], i)
		if Difficulty.MODES[i]["id"] == Difficulty.mode_id():
			_difficulty.select(i)

	_update_window_size_availability()


## A percentage, which is what a game exposing zoom at all conventionally shows,
## and the only labelling here that stays true. A name like "WHOLE ROOM"
## describes the zoom against the size of the room the player happens to be in,
## so it turns into a lie the first time a level is bigger than the screen -
## while the setting only ever controlled the magnification. Two extra steps sit
## between 100% and 200%, because that jump is otherwise straight from the whole
## room to a quarter of it.
##
## Derived from Display.ZOOMS rather than kept beside it, so adding a level is
## one edit and no dropdown row can go missing or land out of order.
func _zoom_label(level: float) -> String:
	return "%d%%" % roundi(level * 100.0)


## Names the whole multiple alongside the pixels. The game renders at a fixed
## internal size, so the number the player is really choosing is how many screen
## pixels one game pixel becomes - saying "3x" makes that legible.
func _size_label(size: Vector2i) -> String:
	var base: Vector2i = Display.base_size()
	var scale := size.x / maxi(base.x, 1)
	if scale > 0 and size == base * scale:
		return "%d x %d   %dx" % [size.x, size.y, scale]
	return "%d x %d" % [size.x, size.y]


## Window size means nothing in fullscreen - it follows the monitor - so the
## dropdown greys out rather than lying about having an effect.
func _update_window_size_availability() -> void:
	_window_size.disabled = Display.is_fullscreen()
	_chain_focus()


## The arrows walk the panel's own rows and nothing else. Left to Godot's
## geometric search, a Down from a row found the host's buttons first - the
## main menu's still sit behind the overlay, visible and focusable - so every
## other press vanished onto a button nobody could see, and WINDOW SIZE was the
## one skipped. Rebuilt whenever a row comes or goes: a disabled WINDOW SIZE
## (fullscreen) and a hidden DIFFICULTY (the pause menu's copy) are stepped
## over, and the ends wrap.
func _chain_focus() -> void:
	var rows: Array[Control] = []
	for c: Control in [_mode, _window_size, _zoom, _difficulty, _back_button]:
		if c.visible and not (c is BaseButton and (c as BaseButton).disabled):
			rows.append(c)
	for i in rows.size():
		var row := rows[i]
		var up := rows[i - 1].get_path()
		var down := rows[(i + 1) % rows.size()].get_path()
		row.focus_neighbor_top = up
		row.focus_previous = up
		row.focus_neighbor_bottom = down
		row.focus_next = down
		# Sideways means nothing on a column of rows, and would otherwise go
		# looking behind the overlay too.
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()


func _on_mode_selected(index: int) -> void:
	Display.set_fullscreen(index == 1)
	_update_window_size_availability()


func _on_window_size_selected(index: int) -> void:
	if index >= 0 and index < _sizes.size():
		Display.set_window_size(_sizes[index])


func _on_zoom_selected(index: int) -> void:
	if index >= 0 and index < Display.ZOOMS.size():
		Display.set_zoom(Display.ZOOMS[index])


func _on_difficulty_selected(index: int) -> void:
	if index >= 0 and index < Difficulty.MODES.size():
		Difficulty.select(Difficulty.MODES[index]["id"])
