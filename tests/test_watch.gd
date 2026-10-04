extends "res://tests/helpers.gd"
## Down is a seat in the stands (game.gd's _watch): while this machine's player
## is down, its camera follows somebody still standing rather than staying
## parked on a body that cannot move - the 2026-10-03 playtest's "the screen
## froze".
##
## A party of three on one machine - the keyboard's player and two on
## synthesized hands - because moving the watch on needs two to choose between:
##
## - Standing, the camera is your own and there is no line.
## - Down, it goes to whoever is NEAREST the body that fell, says so along the
##   bottom with the key that moves it on, and really frames them.
## - The attack button moves it on to the next one standing.
## - The one being watched going down moves it on by itself, and with one left
##   the line stops offering the key - which then does nothing.
## - Getting up takes the camera straight back, and the line down.
## - With nobody standing it stays on the last fight there was.
##
## The lobby at 400% zoom, so the room is bigger than the view and the camera
## really has somewhere to go. Nobody leaves the doorway with an enemy in the
## room - there is none - so nothing here is about the fight.
##
## Frame budget: 60 fps. A get-up is GET_UP_SECONDS (3 s, 180 frames).

const VirtualInput := preload("res://game/player/virtual_input.gd")

var _hands_a := VirtualInput.new()
var _hands_b := VirtualInput.new()
var _centre := Vector2.ZERO


func _tick(frame: int) -> void:
	match frame:
		2:
			# Loaded here and not preloaded: game.gd names autoloads, and a
			# --script file is compiled before they exist.
			var game_script: GDScript = load("res://game/game.gd")
			game_script.next_party = [{}, {"character": "anas", "input": _hands_a},
				{"character": "mayar", "input": _hands_b}]
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_autoload("Display").call("set_zoom", 4.0)
			_centre = (_level().call("bounds") as Rect2).get_center()
			# Anas nearer the player than Mayar, and both far enough inside the
			# walls that the camera need not stop short of them.
			_player().global_position = _centre + Vector2(-20, 0)
			_anas().global_position = _centre + Vector2(60, 10)
			_mayar().global_position = _centre + Vector2(-110, -20)
		34:
			_check("standing: the camera is this machine's player's",
				current_scene.call("watched") == _player())
			_check("standing: and there is no watching line",
				_hud().call("watching_text") == "")
			_player().call("drain", 999)
		36:
			_check("down: this machine's player is down, not faded",
				_player().call("is_down") and _fade_alpha() == 0.0)
			_check("down: the camera goes to whoever is nearest the fall",
				current_scene.call("watched") == _anas())
			_check("down: and says so, with the key that moves it on (%s)"
				% _hud().call("watching_text"),
				_hud().call("watching_text") == "WATCHING ANAS   SPACE: NEXT")
		90:
			_check("down: the camera really frames them (%s against %s)"
				% [_camera().get_screen_center_position(), _anas().global_position],
				_camera().get_screen_center_position().distance_to(_anas().global_position) < 2.0)
			_key(KEY_SPACE, true)
		92:
			_key(KEY_SPACE, false)
			_check("next: the attack button moves it on to the next one standing",
				current_scene.call("watched") == _mayar())
			_check("next: and the line follows (%s)" % _hud().call("watching_text"),
				_hud().call("watching_text") == "WATCHING MAYAR   SPACE: NEXT")
		94:
			_check("next: one press moves it on once",
				current_scene.call("watched") == _mayar())
			_mayar().call("drain", 999)
		96:
			_check("watched down: the camera moves on by itself",
				current_scene.call("watched") == _anas())
			_check("watched down: one left, so no key offered (%s)"
				% _hud().call("watching_text"),
				_hud().call("watching_text") == "WATCHING ANAS")
			_key(KEY_SPACE, true)
		98:
			_key(KEY_SPACE, false)
			_check("watched down: and the key does nothing with nobody to move to",
				current_scene.call("watched") == _anas())
		# The player went down at 34 and gets up at the door 180 frames on.
		220:
			_check("up: getting up takes the camera straight back",
				not _player().call("is_down") and current_scene.call("watched") == _player())
			_check("up: and the line down", _hud().call("watching_text") == "")
			# The last life: up again at 400. Mayar is still down until 274.
			_player().call("drain", 999)
		222:
			_check("again: down, it picks the one standing",
				current_scene.call("watched") == _anas())
			_anas().call("drain", 999)
		224:
			_check("nobody standing: the camera stays on the last fight there was",
				current_scene.call("watched") == _anas()
					and _hud().call("watching_text") == "WATCHING ANAS")
			_check("nobody standing: but two are getting up, so the run goes on (%s lives)"
				% _lives(), _lives() == 0 and not paused)
		# Mayar up at 94 + 180.
		280:
			_check("back up: somebody standing again, and the camera goes to them",
				not _mayar().call("is_down") and current_scene.call("watched") == _mayar()
					and _hud().call("watching_text") == "WATCHING MAYAR")
		# Up at 220 + 180, the last life having paid for it.
		404:
			_check("last: up again, and the camera is theirs",
				not _player().call("is_down") and current_scene.call("watched") == _player()
					and _hud().call("watching_text") == "")
			_finish()


func _anas() -> CharacterBody2D:
	return current_scene.get_node("Player2")


func _mayar() -> CharacterBody2D:
	return current_scene.get_node("Player3")


func _hud() -> Control:
	return current_scene.get_node("HUD/Hud")


func _fade_alpha() -> float:
	return (current_scene.get_node("Transition/Fade") as ColorRect).color.a
