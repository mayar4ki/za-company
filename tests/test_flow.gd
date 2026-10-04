extends "res://tests/helpers.gd"
## Flow test: the journey through ONE room, and the end of a run. Select ->
## game -> movement -> pause -> zoom from the pause menu -> attack animation ->
## a blow -> heart -> death and respawn -> wall collision -> back to the menu ->
## a second run that spends every life and ends at the death screen.
##
## Zoom lives here rather than in test_menu because it needs what only a run
## has: a camera framing a level behind a paused tree.
##
## The doors are not here. The walk up the building, every room checked as it
## is passed, is tests/test_chain.gd's - its own suite, so a floor inserted
## into the building moves nothing in this one.

## Floor 1's own, and the only track in the building below the finale that is a
## FLOOR's rather than a boss's - so what the menu hands the first room is this
## and not the building's bed. The door out of the lobby, where it is handed on
## in turn, is tests/test_chain.gd's.
const LOBBY := "res://assets/music/lobby_loop.wav"


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		14:
			# Pick someone who is NOT the default, so the frame swap is provable.
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		26:
			_check("play: reaches game scene (got %s)" % current_scene.scene_file_path,
				current_scene.scene_file_path == "res://game/game.tscn")
			_check("select: chosen character is saved",
				_autoload("Settings").call("get_value", &"player", &"character", "")
					== "reem")
			_check("select: player wears the chosen character's frames (got %s)"
				% _sprite().sprite_frames.resource_path,
				_sprite().sprite_frames.resource_path.ends_with("reem_frames.tres"))
			_check("game: player sprite frames load (32x32)",
				_sprite().sprite_frames.get_frame_texture("walk_down", 0).get_size()
					== Vector2(32, 32))
			_check("level: the lobby loads first (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Lobby")
			# Floor 1 is deliberately the one room with nothing in it: the first
			# thing a new player does is walk, and the lobby is where they learn
			# that safely. Anything spawning here is a placement mistake - and
			# so is a `reinforcements` key, since a beat is cued by kills and a
			# room with nobody in it can never reach one.
			_check("level: the lobby is empty of enemies (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_check("level: and so has no beat, which could never fire here",
				_level().get_node_or_null("Reinforcements") == null)
			# Empty of enemies is not the same as empty. The furniture is what
			# says this is an office rather than a dungeon with the lights on,
			# and it is the fragile half: re-running build_levels.gd overwrites a
			# level's dressing, so a run with stale data would ship a bare box
			# and every other check here would still pass.
			var dressing := ["Reception1", "Cooler1", "Desk1", "Sofa1", "Banner1"]
			var missing: Array = dressing.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the lobby is dressed as an office lobby (missing %s)"
				% [missing], missing.is_empty())
			# The title card names the room on arrival, and arriving at the start
			# of a run counts - the lobby gets announced like anywhere else.
			_check("title: the room announces itself on arrival (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "THE LOBBY" and _title().modulate.a == 1.0)
			_check("level: player spawned on the level's start marker (%s)"
				% _player().global_position,
				_player().global_position == Vector2(272, 240))
			# A fresh install opens at 150%, so the default framing is a part of
			# the room with the camera following - the whole-room case is proved
			# below, where the player picks 100% back.
			_check("camera: a clean install opens at the default 150%% (got %s)"
				% _camera().zoom, _camera().zoom == Vector2(1.5, 1.5))
			_check("camera: the level is wider than the view at that zoom (%s vs %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x < _level().bounds().size.x)
			_check("level: doorway is a real gap in the wall ring, sealed by the door",
				(_level().get_node("Walls") as TileMapLayer)
					.get_cell_source_id(Vector2i(16, 0)) == -1
				and _level().get_node("Props/Exit/Seal") is StaticBody2D)
			_mark = _player().global_position
			_key(KEY_W, true)
		56:
			_check("move: W moves the player up", _player().global_position.y < _mark.y - 5.0)
			_check("move: walk_up animation (got %s)" % _sprite().animation,
				_sprite().animation == "walk_up")
			_key(KEY_W, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		62:
			_check("pause: Escape pauses and shows the overlay",
				paused and _pause_menu().get_node("Root").visible)
			_check("pause: Continue has keyboard focus",
				(_pause_menu().get_node("%ContinueButton") as Button).has_focus())
			_mark = _player().global_position
			_key(KEY_W, true)
		92:
			_check("pause: player is frozen (moved %.2f px)"
				% _player().global_position.distance_to(_mark),
				_player().global_position.distance_to(_mark) < 0.01)
			_key(KEY_W, false)
			(_pause_menu().get_node("%SettingsButton") as Button).pressed.emit()
		98:
			_check("settings: opens from the pause menu, still paused",
				_panel(_pause_menu()).visible and paused)
			_check("settings: window mode dropdown takes focus",
				(_panel(_pause_menu()).get_node("%ModeOption") as OptionButton)
					.has_focus())
			# Off the centre line first, or following and centring would put the
			# camera in the same place and the next check would prove nothing.
			_player().global_position = Vector2(100, 200)
			# Zoom in from the pause menu. It has to take effect immediately,
			# with the tree paused, or the player cannot see what they picked.
			_pick(_zoom_option(_pause_menu()), _zooms().find(2.0))
		101:
			_check("zoom: 200%% takes effect while still paused (zoom %s)"
				% _camera().zoom, _camera().zoom == Vector2(2, 2) and paused)
			_check("zoom: the view is now smaller than the level (%s vs %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x < _level().bounds().size.x)
			_check("zoom: camera follows the player instead of centring (%s)"
				% _camera().global_position,
				_camera().global_position.x != _level().bounds().get_center().x)
			_check("zoom: choice is saved", _saved(&"zoom", 0) == 2)
			# Labelled by percentage, not by how much of a room it happens to
			# show: a name like "WHOLE ROOM" stops being true once a level is
			# bigger than the screen.
			_check("zoom: every level in Display.ZOOMS is offered, as a percentage",
				_zoom_option(_pause_menu()).item_count == _zooms().size()
				and _zoom_option(_pause_menu())
					.get_item_text(_zooms().find(1.5)) == "150%")
			# The jump straight from the whole room to a quarter of it was too big.
			var between: Array = _zooms().filter(func(z): return z > 1.0 and z < 2.0)
			_check("zoom: two steps sit between 100%% and 200%% (%s)" % [between],
				between.size() == 2)
			_pick(_zoom_option(_pause_menu()), 0)
		103:
			_check("zoom: back to 100%% re-centres on the level (%s)"
				% _camera().global_position,
				_camera().zoom == Vector2(1, 1)
					and _camera().global_position == _level().bounds().get_center())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		104:
			# The interesting case: Escape has to back out of settings without
			# also unpausing the game underneath it.
			_check("settings: Escape closes the panel but does NOT unpause",
				not _panel(_pause_menu()).visible and paused)
			_check("settings: focus returns to the button that opened it",
				(_pause_menu().get_node("%SettingsButton") as Button).has_focus())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		110:
			_check("pause: Escape resumes", not paused)
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		114:
			_check("attack: animation plays (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("attack"))
			# The menu track carried over the scene load, faded out under the
			# lobby's fade-in, and handed the floor the bed it asked for. 88
			# frames after entering at 26, comfortably past Music.FADE_SECONDS -
			# a fade that never completed, or a handoff that never fired, would
			# leave the menu track sitting here instead.
			_check("music: the menu hands the lobby its own track (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == LOBBY)
			# Sealed to a real end, not to frame 0 - see test_menu.gd. Checked
			# on whatever is playing rather than on one named file, so both beds
			# are covered by the one check: this is the lobby's, and the
			# building's is the same check at the hub, in tests/test_chain.gd.
			var bed := null if _music() == null else _music().stream as AudioStreamWAV
			_check("music: the lobby's track is a loop with a real end (%d)"
				% (0 if bed == null else bed.loop_end),
				bed != null and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD
					and bed.loop_end > 0)
		153:
			_check("attack: releases back to idle (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("idle"))
			# Health: take one blow, stand on the heart, then die outright. One
			# landing is one tick - the player's grace window is the meter.
			#
			# The blow is dealt directly rather than walked into, because floor
			# 1 no longer has anything to walk into: the lobby's hazard is gone
			# and a tutorial room is not allowed one. Hazards are checked up the
			# building, on the hub in tests/test_chain.gd, which is the room
			# that has one and nobody in it.
			_check("hud: health bar starts full (%s)" % _player().get("health"),
				_player().get("health") == 100 and _fill().size.x == 66.0
					and _percent().text == "100%")
			_check("hud: three full hearts to start (%s lives, %d icons)"
				% [_lives(), _hearts().get_child_count()],
				_lives() == 3 and _hearts().get_child_count() == 3
					and _heart_tex(0) == _heart_tex(2))
			_check("level: floor 1 has nothing in it that hurts",
				_level().get_node_or_null("Props/Torch") == null)
			_player().call("take_damage", 18)
		166:
			_check("blow: take_damage() costs health (%s)"
				% _player().get("health"), _player().get("health") < 100)
			_check("hud: the bar tracks the hit (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x < 66.0
					and _percent().text == "%d%%" % int(_player().get("health")))
			_check("blow: the amount flies up off the player (%s)" % str(_damage_numbers()),
				_damage_numbers() == ["-18"])
			# A drain shows too, but its ticks share one number while it is
			# fresh: two ticks are one "-3", not a "-1" and a "-2". Dealt
			# BEFORE the mark is taken, so the heart below is still measured
			# against what it actually healed.
			_player().call("drain", 1)
			_player().call("drain", 2)
			_check("drain: ticks add up on one number beside the blow's (%s)"
				% str(_damage_numbers()), _damage_numbers() == ["-18", "-3"])
			_health_mark = _player().get("health")
			_player().global_position = Vector2(424, 152)
		176:
			_check("heart: healed on touch (%d -> %s)"
				% [_health_mark, _player().get("health")],
				int(_player().get("health")) > _health_mark)
			_check("heart: consumed on pickup",
				_level().get_node_or_null("Props/Health") == null)
		206:
			# The blow's 0.8 s is up; the drain's number, 40 frames old, is
			# still on screen but fading - so the next tick starts its own.
			_player().call("drain", 1)
			_check("blow: the number is gone, and a fading drain number takes no more (%s)"
				% str(_damage_numbers()), _damage_numbers() == ["-3", "-1"])
			# Waited out that blow's grace window, so this lethal hit lands.
			_player().call("take_damage", 9999)
		256:
			_check("death: respawns at the level's start with full health (%s at %s)"
				% [_player().get("health"), _player().global_position],
				_player().get("health") == 100
					and _player().global_position.distance_to(Vector2(272, 240)) < 1.0)
			_check("death: hud bar refilled (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x == 66.0 and _percent().text == "100%")
			_check("death: one life spent, hud dims the last heart (%s left)"
				% _lives(),
				_lives() == 2
					and _heart_tex(0) == _heart_tex(1)
					and _heart_tex(2) != _heart_tex(0))
			_check("death: fade cleared",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_player().global_position = Vector2(40, 180)
			_key(KEY_A, true)
			# THE WINDOW COSTS ITS BIGGEST BLOW, NOT ITS FIRST. A torch's 10
			# opens it and a scrubber's 6 inside it is swallowed, as ever...
			_player().call("take_damage", 10)
			_player().call("take_damage", 6)
		266:
			# ...but a guard's 15 ten frames in lands the 5 the 10 left owing -
			# the cheap hit is no shelter from the dear one - and a second 15
			# is swallowed, because two blows of one size still cost one.
			var window: float = _player().get("_grace_window")
			_player().call("take_damage", 15)
			_player().call("take_damage", 15)
			_check("grace: the window costs its biggest blow, not its first (%s)"
				% _player().get("health"), _player().get("health") == 85)
			_check("grace: and runs on rather than restarting (%.2f of %.2f)"
				% [float(_player().get("_grace")), window],
				float(_player().get("_grace")) < window - 0.1)
		346:
			_check("collision: tiled left wall blocks the player (x=%.1f)"
				% _player().global_position.x,
				_player().global_position.x > 16.0)
			# Three seconds and a fade later the card is gone on its own. Checked
			# this late rather than at the 204 frames it costs, because the tree
			# was paused for the settings section and a paused tween does not
			# count down.
			_check("title: the card takes itself away (%.2f)" % _title().modulate.a,
				_title().modulate.a == 0.0)
			_key(KEY_A, false)
			# The walk north out of this room is tests/test_chain.gd's. This run
			# goes back out the way a player leaves one: the pause menu.
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		352:
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		364:
			_check("pause: Main Menu returns to the menu, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			# Second run: spend every life and prove the run actually ends.
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		376:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		388:
			_check("lives: a new run starts with all three again (%s)"
				% _lives(),
				current_scene.scene_file_path == "res://game/game.tscn"
					and _lives() == 3)
			_player().call("take_damage", 9999)
		441:
			_check("lives: first death respawns with two left (%s, health %s)"
				% [_lives(), _player().get("health")],
				_lives() == 2 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		491:
			_check("lives: second death respawns with one left (%s)"
				% _lives(),
				_lives() == 1 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		541:
			_check("game over: the last death raises the death screen, paused",
				paused and _pause_menu().get_node("Root").visible)
			_check("game over: heading reads YOU DIED (got '%s')"
				% (_pause_menu().get_node("%Heading") as Label).text,
				(_pause_menu().get_node("%Heading") as Label).text == "YOU DIED")
			_check("game over: CONTINUE is disabled, MAIN MENU has focus",
				(_pause_menu().get_node("%ContinueButton") as Button).disabled
					and (_pause_menu().get_node("%MainMenuButton") as Button)
						.has_focus())
			# Escape must not dismiss a finished run - there is nothing to
			# resume back into.
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		547:
			_check("game over: Escape cannot dismiss the death screen",
				paused and _pause_menu().get_node("Root").visible)
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		559:
			_check("game over: MAIN MENU leaves the run, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			_finish()


## What every damage number over the player currently says, oldest first.
## Found by script: a number is in no group and nothing looks one up.
func _damage_numbers() -> Array:
	var said := []
	var script := load("res://game/player/damage_number.gd")
	for child in _player().get_children():
		if child.get_script() == script and not child.is_queued_for_deletion():
			said.append(child.get("text"))
	return said
