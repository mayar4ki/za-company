extends "res://game/player/input_source.gd"
## Hands set by code: a stick you point, a button you hold and a dodge you
## press, for a body no keyboard drives. A party on one machine (DESIGN.md's
## Multiplayer, M1) is two bodies and one keyboard, so the second is moved by
## this - the suites' synthesized player, and the shape the wire will fill in
## later.
##
## A press is DATED, which is the only part with any thought in it. `Input`'s
## just-pressed is true for exactly one physics frame, the one after the key
## went down, even if it came back up before that frame ran; a test that holds
## and lets go between two frames still gets its swing. So `hold(true)` only
## marks a press as owed, and `tick()` - which the player calls at the top of
## every physics frame - stamps it with that frame's number. A press made while
## the body is mid-charge is spent on that frame and gone, exactly as a key's.

## Where the stick points. Longer than 1 is clamped, as a real stick's is.
var stick := Vector2.ZERO

var _held := false
var _owed := false
var _pressed_on := -1
var _dodge_owed := false
var _dodged_on := -1


## Put the button down or let it up. Going down is a press; staying down is
## not another one.
func hold(down: bool) -> void:
	if down and not _held:
		_owed = true
	_held = down


func move() -> Vector2:
	return stick.limit_length(1.0)


func attack_held() -> bool:
	return _held


func attack_pressed() -> bool:
	return _pressed_on == Engine.get_physics_frames()


## Press the dodge: owed, and dated by the next tick() like the button's press.
func dodge() -> void:
	_dodge_owed = true


func dodge_pressed() -> bool:
	return _dodged_on == Engine.get_physics_frames()


func tick() -> void:
	if _owed:
		_owed = false
		_pressed_on = Engine.get_physics_frames()
	if _dodge_owed:
		_dodge_owed = false
		_dodged_on = Engine.get_physics_frames()
