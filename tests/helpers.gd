extends SceneTree
## Shared harness for the SceneTree-script tests. Each test file extends this
## (by path, like every cross-feature script here), boots the real main menu,
## and overrides _tick(frame) with its own frame-numbered script of synthesized
## input and checks.
##
## One test file = one Godot process = one clean world. That split is the
## point: when everything lived in one smoke test, every section had to leave
## the game exactly as the next expected, and the bugs that produced were in
## the TEST - a combo's lunge drifting the player out of a later section's
## geometry, an enemy spawned into a still-resolving swing. Separate processes
## dissolve that whole class, and each file numbers its frames from 1, so
## inserting a check stops cascading renumbers through unrelated sections.
##
## Run one:   <godot> --headless --path . --fixed-fps 60 --script res://tests/test_<area>.gd
## Run all:   <godot> --headless --path . --script res://tests/run_all.gd
## Exits 0 when every check passes, non-zero otherwise.
##
## Anything touching user:// puts it back: settings.cfg is backed up before the
## run, cleared so the run is a clean install, and restored at the end - a test
## must never change how the developer's own game opens, and their saved zoom
## must never decide whether a check about framing passes.

const SETTINGS_PATH := "user://settings.cfg"   # keep in step with autoload/settings.gd
## autoload/net.gd's switch for the list of games - keep the two in step.
const LIST_OFF := "za/test/no_room_list"

var _f := 0
var _checks := 0
var _fails: Array[String] = []
var _mark := Vector2.ZERO
var _health_mark := 0
## Frame to keep mashing attack until. Enemies die to a three-hit combo (swing,
## rising slash, arc), and pressing every 8 frames is how a player chains one: a
## press mid-attack is buffered into the next link. The window must end on a
## release (press at %8==0, release at %8==4): a Space left held is not inert -
## the player flows into the heavy attack's charge stance, which now fires the
## heavy by itself rather than merely standing there.
var _mash_until := 0
var _settings_backup := PackedByteArray()
var _settings_existed := false


## The per-test script: a match over the frame number. Overridden by each test
## file; the last arm calls _finish().
func _tick(_frame: int) -> void:
	pass


func _initialize() -> void:
	_snapshot_settings()
	# The development level select, held off for every suite whatever the
	# developer has switched on in project.godot - otherwise picking a character
	# would land a suite on a floor picker it never asked for. In memory only:
	# nothing here calls ProjectSettings.save(). test_level_select.gd switches
	# it back on for itself.
	ProjectSettings.set_setting("za/dev/level_select", false)
	# And the lobby's list of games is never asked of the real service: a suite
	# must not reach the internet, and one that wants a list hands it to Net's
	# `rooms_listed` itself (test_lobby.gd). In memory only, as above.
	ProjectSettings.set_setting(LIST_OFF, true)
	var menu := (load("res://ui/main_menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu


func _process(_delta: float) -> bool:
	_f += 1
	if _f == 1:
		# From here the run is a clean install: whatever the developer has
		# picked for themselves - a zoom of 2 will do it - must not decide
		# whether a check about framing or window size passes.
		# _restore_settings() hands their own file back at the end.
		#
		# Frame 1 rather than _initialize: setting current_scene is not enough
		# to make an autoload reachable by absolute path, and the null that
		# comes back there fails quietly.
		_autoload("Settings").call("clear")
	if _f <= _mash_until:
		if _f % 8 == 0:
			_key(KEY_SPACE, true)
		elif _f % 8 == 4:
			_key(KEY_SPACE, false)
	_tick(_f)
	return false


func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  PASS  " if cond else "  FAIL  "), label)
	if not cond:
		_fails.append(label)


func _finish() -> void:
	_restore_settings()
	print("\n%d checks, %d failed" % [_checks, _fails.size()])
	print("RESULT: ", "PASS" if _fails.is_empty() else "FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)


## Sets BOTH keycode and physical_keycode: this project's actions match on
## physical_keycode, Godot's built-in ui_* actions match on keycode.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _player() -> CharacterBody2D:
	return current_scene.get_node("Player")


func _sprite() -> AnimatedSprite2D:
	return current_scene.get_node("Player/AnimatedSprite2D")


## The party's lives. game.gd's rather than the player's: they are one pool
## however many are playing.
func _lives() -> Variant:
	return current_scene.get("lives")


func _camera() -> Camera2D:
	return current_scene.get_node("Camera2D")


## The red part of the HUD health bar; its width is the readout players get.
func _fill() -> ColorRect:
	return current_scene.get_node("HUD/Hud").get_node("%Fill")


func _percent() -> Label:
	return current_scene.get_node("HUD/Hud").get_node("%Percent")


func _hearts() -> HBoxContainer:
	return current_scene.get_node("HUD/Hud").get_node("%Hearts")


## The boss bar. Its own `visible` is the readout of whether there is a boss
## in the room; %Fill's width is how much of him is left, out of 240.
func _boss_bar() -> Control:
	return current_scene.get_node("HUD/Hud").get_node("%BossBar")


func _boss_name() -> String:
	return (_boss_bar().get_node("%BossName") as Label).text


func _boss_fill() -> ColorRect:
	return _boss_bar().get_node("%Fill")


## The pale block trailing the fill, standing where a blow just landed.
func _boss_chip() -> ColorRect:
	return _boss_bar().get_node("%Chip")


## What a boss is shouting. Its own alpha shows and hides it, like the level
## card below, so a check reads showing() rather than `visible`.
func _subtitle() -> Control:
	return current_scene.get_node("Subtitle/BossSubtitle")


func _subtitle_line() -> String:
	return (_subtitle().get_node("%Line") as Label).text


func _subtitle_speaker() -> String:
	return (_subtitle().get_node("%Speaker") as Label).text


## The level-name card. Its own alpha is what shows and hides it, so a check
## reads `modulate.a` rather than `visible`.
func _title() -> Control:
	return current_scene.get_node("Title/LevelTitle")


func _title_text() -> String:
	return (_title().get_node("%Name") as Label).text


func _heart_tex(i: int) -> Texture2D:
	return (_hearts().get_child(i) as TextureRect).texture


## How much world the camera actually shows, which is what decides whether a
## level is framed whole or scrolled.
func _view_size() -> Vector2:
	return root.get_visible_rect().size / _camera().zoom


## An autoload's constants are not properties, so get() cannot reach them.
func _zooms() -> Array:
	return _autoload("Display").get_script().get_script_constant_map()["ZOOMS"]


## The conversation runner, and the box it drives. Both are reached by node
## path rather than by group, because game.tscn owns exactly one of each.
func _dialogue() -> Node:
	return current_scene.get_node("Dialogue")


func _box() -> Control:
	return current_scene.get_node("Dialogue/Layer/DialogueBox")


## Where a beat's `show` scene is parented; empty unless one is up.
func _overlay() -> Control:
	return current_scene.get_node("Dialogue/Layer/Overlay")


func _line() -> Label:
	return _box().get_node("%Line")


func _speaker() -> String:
	return (_box().get_node("%Speaker") as Label).text


func _choices() -> VBoxContainer:
	return _box().get_node("%Options")


## The music autoload's one player. Reached through /root like every autoload -
## Music is not an identifier in a --script file.
func _music() -> AudioStreamPlayer:
	var m := _autoload("Music")
	return null if m == null else m.get_node_or_null("Player") as AudioStreamPlayer


## What Music says it is playing. Deliberately its own readout rather than
## AudioStreamPlayer.playing: a headless run has a dummy audio driver, under
## which `playing` is false even while a stream is assigned and looping.
func _music_track() -> String:
	var m := _autoload("Music")
	return "" if m == null else String(m.call("track"))


func _pause_menu() -> CanvasLayer:
	return current_scene.get_node("PauseMenu")


## game.tscn swaps one Level child in and out; its node name identifies the map.
##
## Null-safe at BOTH ends, and the first one is easy to trip over: a suite that
## polls for a level every frame - waiting to be told the room it asked for has
## arrived - is polling across two `change_scene_to_file` calls, and
## `current_scene` is briefly null inside each of them. That is a script error
## every frame of a scene change rather than the "no level yet" this already
## answers everywhere else.
func _level() -> Node2D:
	if current_scene == null:
		return null
	for child in current_scene.get_children():
		if child is Node2D and child.has_method("spawn_position"):
			return child
	return null


## The room beaten the short way, for a suite that has to walk out of it and is
## not testing the fight in it. A room's doors are shut until it is beaten
## (game/levels/room_clear.gd): every enemy gone, every boss conceded, and no
## beat still to come - so the beats go too, with the node that would send them.
## So do the friendly arrivals that a beaten room cues, because a 64 px Ivan
## walking in at the door somebody is about to walk out of is a body in the way
## of a walk that is not about him.
##
## Freed at once rather than queued: a door asks for the node by name, and one
## queued to free is still there to be asked until the frame ends.
func _clear_room() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if enemy.is_in_group("bosses"):
			enemy.call("take_damage", 99999)
		else:
			enemy.queue_free()
	for beat: String in ["Reinforcements", "Relief", "Briefing", "Reward"]:
		var node := _level().get_node_or_null(beat)
		if node != null:
			node.free()


## Autoloads are reached through /root rather than by name: the script given to
## --script is compiled before the autoload list is available to the compiler,
## so `Settings` and `Display` are not identifiers here the way they are in
## ordinary game scripts. Calls go through call() for the same reason.
func _autoload(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)


func _panel(host: Node) -> Control:
	return host.get_node("%SettingsPanel")


func _mode_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%ModeOption")


## The size the UI is designed against, which is not what a headless run's
## viewport reports.
func _base_viewport() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360))


func _zoom_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%ZoomOption")


func _window_size_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%WindowSizeOption")


## select() alone does not emit item_selected; a real click does both.
func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _saved(key: StringName, default: Variant) -> Variant:
	return _autoload("Settings").call("get_value", &"display", key, default)


func _is_fullscreen() -> bool:
	return _autoload("Display").call("is_fullscreen")


func _display_window_size() -> Vector2i:
	return _autoload("Display").call("window_size")


func _first_window_size() -> Vector2i:
	return _autoload("Display").call("available_window_sizes")[0]


func _snapshot_settings() -> void:
	_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	if _settings_existed:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)


func _restore_settings() -> void:
	if _settings_existed:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		f.store_buffer(_settings_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
