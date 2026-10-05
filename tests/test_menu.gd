extends "res://tests/helpers.gd"
## Menu-side test: main menu (focus, theme, quit confirm, the two online
## buttons), the character select screen, and the settings panel as hosted by
## the main menu - its DIFFICULTY row and the scaling it decides included, and
## the pause menu's copy leaving that row out. Never enters the game - the
## pause-menu host and zoom live in test_flow.gd, which owns a running world.

## The music player's object id, taken on the menu and compared after each
## scene change: the autoload exists to keep ONE of them across all three
## front-end scenes, and a restart would show up here as a new object.
var _music_id := 0


func _tick(frame: int) -> void:
	match frame:
		4:
			_check("main_scene uid resolves to the main menu",
				ResourceUID.uid_to_path("uid://baccfre32cs6j")
					== "res://ui/main_menu/main_menu.tscn")
			_check("menu: Play has keyboard focus",
				(current_scene.get_node("%PlayButton") as Button).has_focus())
			_check("menu: themed stylebox applied",
				(current_scene.get_node("%PlayButton") as Button)
					.get_theme_stylebox("normal") is StyleBoxFlat)
			# Music is an autoload because the front end is three scenes; the
			# first thing to be sure of is that the file actually loaded.
			_check("music: the menu track is playing (%s)" % _music_track(),
				_music() != null
					and _music_track() == "res://assets/music/menu_loop.wav")
			_music_id = _music().get_instance_id()
			# Sealed as a loop, and sealed to a REAL end. `loop_end` is in
			# frames and 0 does not mean "to the end": a forward loop ending on
			# frame 0 wraps before it has played anything, so the track is
			# pinned at 0.000s and the bus gets exact silence. Every track in
			# the game shipped mute that way, under a green check that only
			# looked at `loop_mode` - which was set. So both halves are checked
			# here, and the position below is checked because neither half
			# proves a sound was made.
			var wav := _music().stream as AudioStreamWAV
			_check("music: the loop flag is set on the stream",
				wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
			_check("music: and sealed to a real end, not frame 0 (loop_end %d)"
				% (0 if wav == null else wav.loop_end),
				wav != null and wav.loop_end > 0)
			# Note on what is deliberately NOT checked: that
			# `get_playback_position()` has advanced. It is the only evidence a
			# headless run can get that audio is really being mixed, and it is
			# unusable here - the audio thread mixes on the wall clock while
			# `--fixed-fps` only fixes the DELTA and never sleeps, so a hundred
			# frames pass in almost no real time and whether anything was mixed
			# is a coin flip. It was written, it flaked on the second run, and
			# a flaky check is worse than the structural one above. Advancement
			# is verified by hand with an AudioEffectCapture probe instead.
			(current_scene.get_node("%QuitButton") as Button).pressed.emit()
		8:
			_check("menu: Quit opens the confirmation dialog",
				(current_scene.get_node("%QuitConfirm") as ConfirmationDialog).visible)
			(current_scene.get_node("%QuitConfirm") as ConfirmationDialog).hide()
			# The menu's five: hosting has a button of its own beside joining,
			# and the difficulty has moved into Settings.
			var host := current_scene.get_node_or_null("%HostButton") as Button
			var join := current_scene.get_node_or_null("%JoinButton") as Button
			_check("menu: HOST ONLINE then JOIN ONLINE, under PLAY",
				host != null and join != null and host.text == "HOST ONLINE"
					and join.text == "JOIN ONLINE"
					and host.get_index() < join.get_index()
					and (current_scene.get_node("%PlayButton") as Button).get_index() < host.get_index())
			_check("menu: no MODE button any more",
				current_scene.get_node_or_null("%ModeButton") == null)
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		20:
			_check("play: opens the character select (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path
					== "res://ui/character_select/character_select.tscn")
			var row := current_scene.get_node("%Roster") as GridContainer
			_check("select: one portrait per roster character (%d)" % row.get_child_count(),
				row.get_child_count() == 10)
			# The cast outgrew one row at ten; a grid that still ran off the
			# 640x360 design viewport would hide a character with no error.
			# Measured as the whole column's MINIMUM size rather than where the
			# grid sits, which is not settled on the frame the scene arrives.
			# The column is CENTRED, so its bottom is half of it below the
			# middle, and it must clear the 28px footer hint, not just the edge.
			var need := (row.get_parent() as Control).get_combined_minimum_size()
			_check("select: the roster fits above the footer (%s)" % need,
				need.x <= 640 and 180 + need.y / 2 <= 360 - 28)
			# Focus lands on whichever character the settings file remembers, so
			# the expectation comes from the same place the screen reads.
			var expected: String = _autoload("Settings").call(
				"get_value", &"player", &"character", "mayar")
			_check("select: focus starts on the remembered character (%s)" % expected,
				(row.get_node(expected) as Button).has_focus())
			# The seam the autoload exists for: PLAY freed the menu scene, and
			# the same player is still going. A restart would show as a
			# playback position back at the top.
			_check("music: survives the change to character select (%s)"
				% _music_track(),
				_music_track() == "res://assets/music/menu_loop.wav")
			# The seam itself: the same player object, never rebuilt and never
			# re-played. A restart would be a new instance or a cleared track.
			_check("music: the same player, not a restart",
				_music().get_instance_id() == _music_id)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		26:
			_check("select: Escape backs out to the main menu (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn")
			_check("music: still the same player back on the menu",
				_music_track() == "res://assets/music/menu_loop.wav"
					and _music().get_instance_id() == _music_id)
			(current_scene.get_node("%SettingsButton") as Button).pressed.emit()
		32:
			_check("settings: opens from the main menu",
				_panel(current_scene).visible)
			# Measured against the DESIGN viewport, not the runtime one: a
			# headless window reports its own size, and 640x360 is the size the
			# panel has to survive. Guards the page as more rows are added.
			var box := _panel(current_scene).get_node(
				"CenterContainer/Panel") as Control
			_check("settings: the panel fits the 640x360 screen (%s)" % box.size,
				box.size.x <= _base_viewport().x and box.size.y <= _base_viewport().y)
			_check("settings: display dropdown offers windowed and fullscreen",
				_mode_option(current_scene).item_count == 2)
			# The main menu's buttons are still behind the overlay, visible and
			# focusable, and the arrows used to find them: every other Down
			# landed on one, and WINDOW SIZE was never reached.
			_check("settings: Down walks every row and wraps (%s)" % _walk_down(),
				_walk_down() == "ModeOption WindowSizeOption ZoomOption DifficultyOption BackButton ModeOption")
			# DIFFICULTY is the fourth row. Everything here is synchronous,
			# including an enemy's _ready reading its numbers the moment it is
			# added, so it is all checked inside this one frame.
			var difficulty := _panel(current_scene).get_node("%DifficultyOption") as OptionButton
			_check("difficulty: EASY, MEDIUM, HARD, on MEDIUM without saving (%s)"
				% difficulty.get_item_text(difficulty.selected),
				difficulty.visible and difficulty.item_count == 3
					and difficulty.get_item_text(difficulty.selected) == "MEDIUM"
					and not _autoload("Settings").call("has", &"game", &"difficulty"))
			_pick(difficulty, 2)
			_check("difficulty: picking HARD saves it",
				_autoload("Settings").call("get_value", &"game", &"difficulty", "") == "hard")
			# Difficulty scales what the world deals, never enemy health - the
			# health numbers are exact combo breakpoints on every mode.
			var hard_guard := (load("res://game/enemies/regular/regular.tscn")
				as PackedScene).instantiate()
			root.add_child(hard_guard)
			_check("difficulty: HARD guards hit half again as hard, same health (%s dmg, %s hp)"
				% [hard_guard.get("contact_damage"), hard_guard.get("max_health")],
				hard_guard.get("contact_damage") == 23
					and hard_guard.get("max_health") == 24)
			hard_guard.free()
			_pick(difficulty, 0)
			var easy_guard := (load("res://game/enemies/regular/regular.tscn")
				as PackedScene).instantiate()
			root.add_child(easy_guard)
			_check("difficulty: EASY guards hit softer, same health (%s dmg)"
				% easy_guard.get("contact_damage"),
				easy_guard.get("contact_damage") == 9 and easy_guard.get("max_health") == 24)
			easy_guard.free()
			# The pause menu's copy of the panel says no to the row: the
			# difficulty is read once, when a run starts.
			var paused := (load("res://ui/pause_menu/pause_menu.tscn") as PackedScene).instantiate()
			_check("difficulty: the pause menu's panel leaves it out",
				paused.get_node("%SettingsPanel").get("offers_difficulty") == false)
			paused.free()
			var bare := (load("res://ui/settings/settings_panel.tscn") as PackedScene).instantiate()
			bare.set("offers_difficulty", false)
			root.add_child(bare)
			_check("difficulty: and a panel that leaves it out hides the row, not greys it",
				not (bare.get_node("%DifficultyOption") as Control).visible
					and not (bare.get_node("%DifficultyLabel") as Control).visible)
			bare.free()
			# The rest of the run assumes a clean install; drop what was picked.
			_autoload("Settings").call("clear")
			_check("settings: window size dropdown is populated (%d entries)"
				% _window_size_option(current_scene).item_count,
				_window_size_option(current_scene).item_count > 0)
			_pick(_mode_option(current_scene), 1)
		38:
			_check("settings: choosing fullscreen is saved",
				_saved(&"fullscreen", false) == true)
			# Window size means nothing in fullscreen, so the dropdown has to
			# track the window rather than assert a mode of its own.
			_check("settings: window size dropdown tracks the window mode",
				_window_size_option(current_scene).disabled == _is_fullscreen())
			_check("settings: and Down steps over it while it is greyed out (%s)" % _walk_down(),
				_walk_down() == ("ModeOption ZoomOption DifficultyOption BackButton ModeOption"
					if _is_fullscreen()
					else "ModeOption WindowSizeOption ZoomOption DifficultyOption BackButton ModeOption"))
			_pick(_mode_option(current_scene), 0)
		44:
			_check("settings: switching back to windowed is saved",
				_saved(&"fullscreen", true) == false)
			_check("settings: window size dropdown is usable in windowed mode",
				not _window_size_option(current_scene).disabled)
			_pick(_window_size_option(current_scene), 0)
		50:
			_check("settings: window size choice is applied and saved (%s)"
				% _first_window_size(),
				_display_window_size() == _first_window_size()
				and _saved(&"window_size", Vector2i.ZERO) == _first_window_size())
			(_panel(current_scene).get_node("%BackButton") as Button).pressed.emit()
		56:
			_check("settings: Back closes the panel and restores focus",
				not _panel(current_scene).visible
				and (current_scene.get_node("%SettingsButton") as Button).has_focus())
			# The actual requirement: it survives a restart. Read the file back
			# cold, the way the next launch will.
			var saved := ConfigFile.new()
			var err := saved.load(SETTINGS_PATH)
			_check("settings: on disk and readable on next launch (%s)"
				% error_string(err),
				err == OK
				and saved.get_value("display", "fullscreen", true) == false
				and saved.get_value("display", "window_size", Vector2i.ZERO)
					== _first_window_size())
			_finish()


## The settings panel's rows in the order Down visits them, from WINDOW MODE
## round to wherever the chain ends - the same lookup an arrow press makes.
func _walk_down() -> String:
	var names: PackedStringArray = []
	var at: Control = _mode_option(current_scene)
	for i in 6:
		if at == null:
			break
		names.append(at.name)
		at = at.find_valid_focus_neighbor(SIDE_BOTTOM)
	return " ".join(names)
