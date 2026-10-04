extends RefCounted
## A player's HANDS: the stick, the attack button and the dodge, nothing else. A
## player asks this, never `Input`, and this one - the one every player gets
## unless it is handed another - answers off the keyboard exactly as player.gd
## used to read it itself.
##
## The seam is DESIGN.md's Multiplayer, M1. A second body in the same room
## cannot also be driven by the one keyboard, so whatever answers these four
## questions can move a player: a test's synthesized hands
## (`virtual_input.gd`), and later the wire.
##
## They are asked LIVE rather than sampled once a frame, because that is
## how the player asked `Input` before, and the answers differ in the one place
## that matters: the button is also read when an attack animation ends, which
## is an idle-frame callback rather than a physics frame, and an answer sampled
## at the last physics frame would be stale there - and decide whether a held
## button flows into the heavy's charge or a released one ends the combo.
##
## Preloaded by path like every other cross-feature script here - global class
## names live in an editor-written cache a fresh headless checkout does not have.

## Whether a keyboard source has looked at the platform yet - see browser_keys().
static var _checked := false


func _init() -> void:
	if not _checked:
		_checked = true
		if OS.has_feature("web"):
			browser_keys()


## Ctrl taken back out of the dodge, leaving K. In a browser Ctrl+W closes the
## tab and no page can stop it, so a dodge on Ctrl is a dodge that now and then
## quits the game - and, for a host, ends it for the whole party. Once per run,
## by the first keyboard source made; public so a suite can try it on a desktop.
static func browser_keys() -> void:
	for ev in InputMap.action_get_events(&"dodge"):
		if ev is InputEventKey and (ev.physical_keycode == KEY_CTRL or ev.keycode == KEY_CTRL):
			InputMap.action_erase_event(&"dodge", ev)


## Where the stick points, at most 1 long.
func move() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Whether the attack button is down.
func attack_held() -> bool:
	return Input.is_action_pressed("attack")


## Whether the attack button went down on THIS physics frame - true for the one
## frame, even if it has already come back up.
func attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack")


## Whether the dodge went down on THIS physics frame, on the attack button's
## terms. A press only: the roll is over in a third of a second, so there is
## nothing to hold.
func dodge_pressed() -> bool:
	return Input.is_action_just_pressed("dodge")


## Once at the top of every physics frame, before anything is asked. Nothing to
## do here - Input keeps its own frames - and the hook a source with no Input
## underneath it uses to date a press.
func tick() -> void:
	pass
